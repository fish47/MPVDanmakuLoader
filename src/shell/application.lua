local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local stringfile    = require("src/base/stringfile")
local unportable    = require("src/base/unportable")
local danmakupool   = require("src/core/danmakupool")
local pluginbase    = require("src/plugins/pluginbase")
local srt           = require("src/plugins/srt")
local acfun         = require("src/plugins/acfun")
local bilibili      = require("src/plugins/bilibili")
local dandanplay    = require("src/plugins/dandanplay")
local config        = require("src/shell/config")


local _APP_MD5_BYTE_COUNT       = 32 * 1024 * 1024
local _APP_ASS_FILE_SUFFIX      = ".ass"

local _TAG_LOG_WIDTH            = 14
local _TAG_PLUGIN               = "plugin"
local _TAG_NETWORK              = "network"
local _TAG_FILESYSTEM           = "filesystem"
local _TAG_SUBTITLE             = "subtitle"
local _TAG_EXT_COMMAND          = "extcommand"


local _MPV_CMD_ADD_SUBTITLE             = "sub-add"
local _MPV_CMD_DELETE_SUBTITLE          = "sub-remove"
local _MPV_PROP_PAUSE                   = "pause"
local _MPV_PROP_MAIN_SUBTITLE_ID        = "sid"
local _MPV_PROP_SECONDARY_SUBTITLE_ID   = "secondary-sid"
local _MPV_PROP_TRACK_COUNT             = "track-list/count"
local _MPV_PROP_TRACK_ID                = "track-list/%d/id"
local _MPV_ARG_READDIR_ONLY_FILES       = "files"
local _MPV_ARG_READDIR_ONLY_DIRS        = "dirs"
local _MPV_ARG_ADDSUB_AUTO              = "auto"
local _MPV_CONST_NO_SUBTITLE_ID         = "no"
local _MPV_CONST_MEMORY_FILE_PREFFIX    = "memory://"


local MPVDanmakuLoaderApp =
{
    _mConfiguration         = classlite.declareTableField(),
    _mDanmakuPools          = classlite.declareClassField(danmakupool.DanmakuPools),
    _mNetworkConnection     = classlite.declareClassField(unportable.NetworkConnection),
    _mPyScriptCmdExecutor   = classlite.declareClassField(unportable.PyScriptCommandExecutor),
    _mDanmakuSourcePlugins  = classlite.declareTableField(),
    _mUniquePathGenerator   = classlite.declareClassField(unportable.UniquePathGenerator),
    _mLogFunction           = classlite.declareConstantField(nil),
    _mStringFilePool        = classlite.declareClassField(stringfile.StringFilePool),

    __mVideoFileMD5         = classlite.declareConstantField(nil),
    __mVideoFilePath        = classlite.declareConstantField(nil),
    __mCurrentDirPath       = classlite.declareConstantField(nil),
    __mMemorySubtitleID     = classlite.declareConstantField(nil),
    __mCfgSchemeTable       = classlite.declareTableField(),

    __mSubprocessArguments  = classlite.declareTableField(),
}

function MPVDanmakuLoaderApp:new()
    local cmdExecutor = self._mPyScriptCmdExecutor
    cmdExecutor:setApplication(self)
    self._mNetworkConnection:setPyScriptCommandExecutor(cmdExecutor)

    -- 在这些统一做 monkey patch 可以省一些的重复代码，例如文件操作那堆 Log
    self:_initDanmakuSourcePlugins()
    self:__attachMethodLoggingHooks()
    self:__initConfigurationSchemeTable()
end

function MPVDanmakuLoaderApp:__initConfigurationSchemeTable()
    local scheme = self.__mCfgSchemeTable
    for _, k in config.iterateConfigurationKeys()
    do
        scheme[k] = true
    end
end

function MPVDanmakuLoaderApp:__attachMethodLoggingHooks()
    local function __patchFunction(orgFunc, patchFunc)
        local ret = function(...)
            utils.invokeSafely(patchFunc, ...)
            return utils.invokeSafely(orgFunc, ...)
        end
        return ret
    end

    local function __patchFS(orgFunc, subTag)
        local retFunc = function(fs, arg1, ...)
            local ret = orgFunc(fs, arg1, ...)
            local arg1Str = arg1 or constants.STR_EMPTY
            arg1Str = types.isString(arg1) and string.format("%q", arg1Str) or arg1Str
            self:_printLog(_TAG_FILESYSTEM, "%s(%s) -> %s", subTag, arg1Str, tostring(ret))
            return ret
        end
        return retFunc
    end

    local function __patchPlugin(orgFunc)
        local retFunc = function(plugin, keyword, ...)
            local ret = orgFunc(plugin, keyword, ...)
            if ret
            then
                self:_printLog(_TAG_PLUGIN, "search(%q) -> %s", keyword, plugin:getName())
            end
        end
        return retFunc
    end

    local clzApp = self:getClass()
    self.readFile           = __patchFS(clzApp.readFile,            "readFile")
    self.readUTF8File       = __patchFS(clzApp.readUTF8File,        "readUTF8File")
    self.createStringFile   = __patchFS(clzApp.createStringFile,    "createStringFile")
    self.writeFile          = __patchFS(clzApp.writeFile,           "writeFile")
    self.closeFile          = __patchFS(clzApp.closeFile,           "closeFile")
    self.createDir          = __patchFS(clzApp.createDir,           "createDir")
    self.deletePath         = __patchFS(clzApp.deletePath,          "deletePath")

    local function __printNetworkLog(_, url)
        self:_printLog(_TAG_NETWORK, "GET %s", url)
    end
    local conn = self._mNetworkConnection
    conn._createConnection = __patchFunction(conn:getClass()._createConnection, __printNetworkLog)

    local function __printSubtitleFilePath(_, path)
        self:_printLog(_TAG_SUBTITLE, "file: %s", path)
    end
    self.setSubtitleFile = __patchFunction(clzApp.setSubtitleFile, __printSubtitleFilePath)

    local function __printSubtitleData(_, data)
        self:_printLog(_TAG_SUBTITLE, "data")
    end
    self.setSubtitleData = __patchFunction(clzApp.setSubtitleData, __printSubtitleData)

    for _, plugin in self:iterateDanmakuSourcePlugins()
    do
        plugin.search = __patchPlugin(plugin:getClass().search)
    end
end

function MPVDanmakuLoaderApp:setLogFunction(func)
    self._mLogFunction = types.chooseValue(types.isFunction(func), func)
end

function MPVDanmakuLoaderApp:_printLog(tag, fmt, ...)
    local func = self._mLogFunction
    if not func
    then
        return
    end

    local wordWidth = #tag
    local maxWidth = _TAG_LOG_WIDTH
    local leadingSpaceCount = math.floor((maxWidth - wordWidth) / 2)
    local trailingSpaceCount = math.max(maxWidth - wordWidth - leadingSpaceCount, 0)
    local leadingSpaces = string.rep(constants.STR_SPACE, leadingSpaceCount)
    local trailingSpaces = string.rep(constants.STR_SPACE, trailingSpaceCount)
    func(string.format("[%s%s%s]  " .. fmt, leadingSpaces, tag, trailingSpaces, ...))
end

function MPVDanmakuLoaderApp:init(filePath)
    local dir = filePath and unportable.splitPath(filePath)
    self.__mCurrentDirPath = types.toValueOrNil(dir)
    self.__mVideoFileMD5 = nil
    self.__mVideoFilePath = filePath
    self.__mMemorySubtitleID = nil
    self._mNetworkConnection:reset()
    self._mDanmakuPools:clear()
end

function MPVDanmakuLoaderApp:_getCurrentDirPath()
    return self.__mCurrentDirPath
end

function MPVDanmakuLoaderApp:_updateConfiguration(cfg)
    local path = self:_getCurrentDirPath()
    local options = mp.options.read_options(self.__mCfgSchemeTable)
    config.updateConfiguration(self, path, cfg, options)
end

function MPVDanmakuLoaderApp:updateConfiguration()
    local cfg = self._mConfiguration
    self:_updateConfiguration(cfg)

    local pools = self._mDanmakuPools
    for _, pool in pools:iteratePools()
    do
        pool:setModifyDanmakuDataHook(cfg.modifyDanmakuDataHook)
    end
    pools:setCompareSourceIDHook(cfg.modifySourceIDHook)
    self._mNetworkConnection:setTimeout(cfg.networkTimeout)
    self:setLogFunction(cfg.enableDebugLog and print)
end

function MPVDanmakuLoaderApp:getPluginByName(name)
    for _, plugin in self:iterateDanmakuSourcePlugins()
    do
        if plugin:getName() == name
        then
            return plugin
        end
    end
end

function MPVDanmakuLoaderApp:_addDanmakuSourcePlugin(plugin)
    if classlite.isInstanceOf(plugin, pluginbase.IDanmakuSourcePlugin)
        and not self:getPluginByName(plugin:getName())
    then
        table.insert(self._mDanmakuSourcePlugins, plugin)
        plugin:setApplication(self)
    end
end

function MPVDanmakuLoaderApp:_initDanmakuSourcePlugins()
    local plugins = utils.clearTable(self._mDanmakuSourcePlugins)
    self:_addDanmakuSourcePlugin(srt.SRTDanmakuSourcePlugin:new())
    self:_addDanmakuSourcePlugin(acfun.AcfunDanmakuSourcePlugin:new())
    self:_addDanmakuSourcePlugin(bilibili.BiliBiliDanmakuSourcePlugin:new())
    self:_addDanmakuSourcePlugin(dandanplay.DanDanPlayDanmakuSourcePlugin:new())
end

function MPVDanmakuLoaderApp:iterateDanmakuSourcePlugins()
    return utils.iterateArray(self._mDanmakuSourcePlugins)
end

function MPVDanmakuLoaderApp:getConfiguration()
    return self._mConfiguration
end

function MPVDanmakuLoaderApp:getDanmakuPools()
    return self._mDanmakuPools
end

function MPVDanmakuLoaderApp:getNetworkConnection()
    return self._mNetworkConnection
end

function MPVDanmakuLoaderApp:__doAddSubtitle(arg)
    local orgSID = mp.get_property(_MPV_PROP_MAIN_SUBTITLE_ID)
    local orgTrackCount = mp.get_property_number(_MPV_PROP_TRACK_COUNT, 0)
    mp.commandv(_MPV_CMD_ADD_SUBTITLE, arg)
    mp.set_property(_MPV_PROP_MAIN_SUBTITLE_ID, orgSID)

    local newTrackCount = mp.get_property_number(_MPV_PROP_TRACK_COUNT, 1)
    if newTrackCount > orgTrackCount
    then
        local prop = string.format(_MPV_PROP_TRACK_ID, newTrackCount - 1)
        return mp.get_property(prop)
    end
end

function MPVDanmakuLoaderApp:addSubtitleFile(path)
    if self:isExistedFile(path)
    then
        return self:__doAddSubtitle(path)
    end
end

function MPVDanmakuLoaderApp:addSubtitleData(data)
    local function __unsetSID(propName, sid)
        if mp.get_property(propName) == sid
        then
            mp.set_property(propName, _MPV_CONST_NO_SUBTITLE_ID)
        end
    end

    if types.isNilOrEmptyString(data)
    then
        return
    end

    local newSID = self:__doAddSubtitle(_MPV_CONST_MEMORY_FILE_PREFFIX .. data)
    if newSID
    then
        -- 只保留一个内存字幕
        local memorySID = self.__mMemorySubtitleID
        if memorySID
        then
            __unsetSID(_MPV_PROP_MAIN_SUBTITLE_ID, memorySID)
            __unsetSID(_MPV_PROP_SECONDARY_SUBTITLE_ID, memorySID)
            mp.commandv(_MPV_CMD_DELETE_SUBTITLE, memorySID)
        end

        self.__mMemorySubtitleID = newSID
        return newSID
    end
end

function MPVDanmakuLoaderApp:setMainSubtitleByID(sid)
    if types.isString(sid)
    then
        mp.set_property(_MPV_PROP_MAIN_SUBTITLE_ID, sid)
    end
end

function MPVDanmakuLoaderApp:setSecondarySubtitleByID(sid)
    if types.isString(sid)
    then
        mp.set_property(_MPV_PROP_SECONDARY_SUBTITLE_ID, sid)
    end
end

function MPVDanmakuLoaderApp:getMainSubtitleID()
    local sid = mp.get_property(_MPV_PROP_MAIN_SUBTITLE_ID)
    return sid ~= _MPV_CONST_NO_SUBTITLE_ID and sid
end

function MPVDanmakuLoaderApp:isVideoPaused()
    return mp.get_property_native(_MPV_PROP_PAUSE)
end

function MPVDanmakuLoaderApp:setVideoPaused(val)
    mp.set_property_native(_MPV_PROP_PAUSE, types.toBoolean(val))
end

function MPVDanmakuLoaderApp:listFiles(dir, outList)
    local files = mp.utils.readdir(dir, _MPV_ARG_READDIR_ONLY_FILES)
    utils.clearTable(outList)
    utils.appendArrayElements(outList, files)
end

function MPVDanmakuLoaderApp:createDir(dir)
    return self._mPyScriptCmdExecutor:createDirs(dir)
end

function MPVDanmakuLoaderApp:deletePath(fullPath)
    return self._mPyScriptCmdExecutor:deletePath(fullPath)
end

function MPVDanmakuLoaderApp:readFile(fullPath)
    return types.isString(fullPath)
        and io.open(fullPath)
        or nil
end

function MPVDanmakuLoaderApp:readUTF8File(fullPath)
    local content = self._mPyScriptCmdExecutor:readUTF8File(fullPath)
    return types.isString(content)
        and self._mStringFilePool:obtainReadOnlyStringFile(content)
        or nil
end

function MPVDanmakuLoaderApp:createStringFile()
    return self._mStringFilePool:obtainWriteOnlyStringFile()
end

function MPVDanmakuLoaderApp:writeFile(fullPath, isAppend)
    local mode = types.chooseValue(isAppend,
        constants.FILE_MODE_WRITE_APPEND,
        constants.FILE_MODE_WRITE_ERASE)
    return types.isString(fullPath) and io.open(fullPath, mode) or nil
end

function MPVDanmakuLoaderApp:closeFile(file)
    return utils.closeSafely(file)
end

function MPVDanmakuLoaderApp:isExistedDir(fullPath)
    local ret = false
    if types.isString(fullPath)
    then
        local parentDir, dir = unportable.splitPath(fullPath)
        local dirs = mp.utils.readdir(parentDir, _MPV_ARG_READDIR_ONLY_DIRS)
        ret = utils.linearSearchArray(dirs, dir)
    end
    return ret
end

function MPVDanmakuLoaderApp:isExistedFile(fullPath)
    local file = nil
    if types.isString(fullPath)
    then
        file = io.open(fullPath)
        utils.closeSafely(file)
    end
    return types.toBoolean(file)
end

function MPVDanmakuLoaderApp:getUniqueFilePath(dir, prefix, suffix)
    local function __isExistedPath(app, fullPath)
        return app:isExistedFile(fullPath) or app:isExistedDir(fullPath)
    end

    local generator = self._mUniquePathGenerator
    return generator:getUniquePath(dir, prefix, suffix, __isExistedPath, self)
end

function MPVDanmakuLoaderApp:getVideoFileMD5()
    local md5 = self.__mVideoFileMD5
    if not md5
    then
        local fullPath = self.__mVideoFilePath
        local executor = self._mPyScriptCmdExecutor
        md5 = executor:calculateFileMD5(fullPath, _APP_MD5_BYTE_COUNT)
        self.__mVideoFileMD5 = md5
    end
    return md5
end

function MPVDanmakuLoaderApp:__doGetConfigurationFullPath(relPath)
    local path = self:_getCurrentDirPath()
    local dirName = self:getConfiguration().privateDataDirName
    return path and dirName and unportable.joinPath(path, dirName)
end

function MPVDanmakuLoaderApp:getDanmakuSourceRawDataDirPath()
    local relPath = self:getConfiguration().rawDataDirName
    return self:__doGetConfigurationFullPath(name)
end

function MPVDanmakuLoaderApp:getDanmakuSourceMetaDataFilePath()
    local relPath = self:getConfiguration().metaDataFileName
    return self:__doGetConfigurationFullPath(relPath)
end

function MPVDanmakuLoaderApp:getGeneratedASSFilePath()
    if self:getConfiguration().saveGeneratedASS
    then
        local videoFilePath = self.__mVideoFilePath
        return videoFilePath and videoFilePath .. _APP_ASS_FILE_SUFFIX
    end
end

function MPVDanmakuLoaderApp:getCurrentDateTime()
    return os.time()
end

function MPVDanmakuLoaderApp:_spawnSubprocess(cmdArgs)
    local args = utils.clearTable(self.__mSubprocessArguments)
    args.args = cmdArgs
    args.cancellable = true
    local ret = mp.utils.subprocess(args)
    local succeed = types.isTable(ret) and not ret.error and types.isNumber(ret.status)
    local retCode = types.chooseValue(succeed, ret.status)
    local stdout = types.chooseValue(succeed, ret.stdout)
    ret = nil
    utils.clearTable(args)
    return retCode, stdout
end

function MPVDanmakuLoaderApp:executeExternalCommand(cmdArgs, stdin)
    if types.isString(stdin)
    then
        local excutor = self._mPyScriptCmdExecutor
        return excutor:redirectExternalCommand(cmdArgs, stdin)
    else
        return self:_spawnSubprocess(cmdArgs)
    end
end

classlite.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderApp         = MPVDanmakuLoaderApp,
}