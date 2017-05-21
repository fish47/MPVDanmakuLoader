local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
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
    _mConfiguration                     = classlite.declareTableField(),
    _mDanmakuPools                      = classlite.declareClassField(danmakupool.DanmakuPools),
    _mNetworkConnection                 = classlite.declareClassField(unportable.CURLNetworkConnection),
    _mDanmakuSourcePlugins              = classlite.declareTableField(),
    _mUniquePathGenerator               = classlite.declareClassField(unportable.UniquePathGenerator),
    _mLogFunction                       = classlite.declareConstantField(nil),

    __mVideoFileMD5                     = classlite.declareConstantField(nil),
    __mVideoFilePath                    = classlite.declareConstantField(nil),
    __mCurrentDirPath                   = classlite.declareConstantField(nil),
    __mAddedMemorySubtitleID            = classlite.declareConstantField(nil),
    __mConfigurationSchemeTable         = classlite.declareTableField(),


    new = function(self)
        -- 在这些统一做 monkey patch 可以省一些的重复代码，例如文件操作那堆 Log
        self:_initDanmakuSourcePlugins()
        self:__attachMethodLoggingHooks()
        self:__initConfigurationSchemeTable()
    end,

    __initConfigurationSchemeTable = function(self)
        local scheme = self.__mConfigurationSchemeTable
        for _, k in config.iterateConfigurationKeys()
        do
            scheme[k] = true
        end
    end,

    __attachMethodLoggingHooks = function(self)
        local function __patchFunction(orgFunc, patchFunc)
            local ret = function(...)
                utils.invokeSafely(patchFunc, ...)
                return utils.invokeSafely(orgFunc, ...)
            end
            return ret
        end

        local function __createPatchedFSFunction(orgFunc, subTag)
            local ret = function(self, arg1, ...)
                local ret = orgFunc(self, arg1, ...)
                local arg1Str = arg1 or constants.STR_EMPTY
                arg1Str = types.isString(arg1) and string.format("%q", arg1Str) or arg1Str
                self:_printLog(_TAG_FILESYSTEM, "%s(%s) -> %s", subTag, arg1Str, tostring(ret))
                return ret
            end
            return ret
        end

        local clzApp = self:getClass()
        self.readFile       = __createPatchedFSFunction(clzApp.readFile,        "readFile")
        self.readUTF8File   = __createPatchedFSFunction(clzApp.readUTF8File,    "readUTF8File")
        self.writeFile      = __createPatchedFSFunction(clzApp.writeFile,       "writeFile")
        self.closeFile      = __createPatchedFSFunction(clzApp.closeFile,       "closeFile")
        self.createDir      = __createPatchedFSFunction(clzApp.createDir,       "createDir")
        self.deleteTree     = __createPatchedFSFunction(clzApp.deleteTree,      "deleteTree")
        self.createTempFile = __createPatchedFSFunction(clzApp.createTempFile,  "createTempFile")

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
            local orgSearchFunc = plugin:getClass().search
            plugin.search = function(plugin, keyword, ...)
                local ret = orgSearchFunc(plugin, keyword, ...)
                if ret
                then
                    self:_printLog(_TAG_PLUGIN, "search(%q) -> %s", keyword, plugin:getName())
                end
                return ret
            end
        end
    end,

    setLogFunction = function(self, func)
        self._mLogFunction = types.chooseValue(types.isFunction(func), func)
    end,

    _printLog = function(self, tag, fmt, ...)
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
    end,

    init = function(self, filePath)
        local dir = filePath and unportable.splitPath(filePath)
        self.__mCurrentDirPath = types.toValueOrNil(dir)
        self.__mVideoFileMD5 = nil
        self.__mVideoFilePath = filePath
        self.__mAddedMemorySubtitleID = nil
        self._mNetworkConnection:reset()
        self._mDanmakuPools:clear()
    end,

    _getCurrentDirPath = function(self)
        return self.__mCurrentDirPath
    end,

    _updateConfiguration = function(self, cfg)
        local path = self:_getCurrentDirPath()
        local options = mp.options.read_options(self.__mConfigurationSchemeTable)
        config.updateConfiguration(self, path, cfg, options)
    end,

    updateConfiguration = function(self)
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
    end,

    getPluginByName = function(self, name)
        for _, plugin in self:iterateDanmakuSourcePlugins()
        do
            if plugin:getName() == name
            then
                return plugin
            end
        end
    end,

    _addDanmakuSourcePlugin = function(self, plugin)
        if classlite.isInstanceOf(plugin, pluginbase.IDanmakuSourcePlugin)
            and not self:getPluginByName(plugin:getName())
        then
            table.insert(self._mDanmakuSourcePlugins, plugin)
            plugin:setApplication(self)
        end
    end,

    _initDanmakuSourcePlugins = function(self)
        local plugins = utils.clearTable(self._mDanmakuSourcePlugins)
        self:_addDanmakuSourcePlugin(srt.SRTDanmakuSourcePlugin:new())
        self:_addDanmakuSourcePlugin(acfun.AcfunDanmakuSourcePlugin:new())
        self:_addDanmakuSourcePlugin(bilibili.BiliBiliDanmakuSourcePlugin:new())
        self:_addDanmakuSourcePlugin(dandanplay.DanDanPlayDanmakuSourcePlugin:new())
    end,

    iterateDanmakuSourcePlugins = function(self)
        return utils.iterateArray(self._mDanmakuSourcePlugins)
    end,

    getConfiguration = function(self)
        return self._mConfiguration
    end,

    getDanmakuPools = function(self)
        return self._mDanmakuPools
    end,

    getNetworkConnection = function(self)
        return self._mNetworkConnection
    end,

    __doAddSubtitle = function(self, arg)
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
    end,

    addSubtitleFile = function(self, path)
        if self:isExistedFile(path)
        then
            return self:__doAddSubtitle(path)
        end
    end,

    addSubtitleData = function(self, data)
        local function __unsetSID(propName, sid)
            if mp.get_property(propName) == sid
            then
                mp.set_property(propName, _MPV_CONST_NO_SUBTITLE_ID)
            end
        end

        if types.isNilOrEmpty(data)
        then
            return
        end

        local newSID = self:__doAddSubtitle(_MPV_CONST_MEMORY_FILE_PREFFIX .. data)
        if newSID
        then
            -- 只保留一个内存字幕
            local memorySID = self.__mAddedMemorySubtitleID
            if memorySID
            then
                __unsetSID(_MPV_PROP_MAIN_SUBTITLE_ID, memorySID)
                __unsetSID(_MPV_PROP_SECONDARY_SUBTITLE_ID, memorySID)
                mp.commandv(_MPV_CMD_DELETE_SUBTITLE, memorySID)
            end

            self.__mAddedMemorySubtitleID = newSID
            return newSID
        end
    end,

    setMainSubtitleByID = function(self, sid)
        if types.isString(sid)
        then
            mp.set_property(_MPV_PROP_MAIN_SUBTITLE_ID, sid)
        end
    end,

    setSecondarySubtitleByID = function(self, sid)
        if types.isString(sid)
        then
            mp.set_property(_MPV_PROP_SECONDARY_SUBTITLE_ID, sid)
        end
    end,

    getMainSubtitleID = function(self)
        local sid = mp.get_property(_MPV_PROP_MAIN_SUBTITLE_ID)
        return sid ~= _MPV_CONST_NO_SUBTITLE_ID and sid
    end,

    isVideoPaused = function(self)
        return mp.get_property_native(_MPV_PROP_PAUSE)
    end,

    setVideoPaused = function(self, val)
        mp.set_property_native(_MPV_PROP_PAUSE, types.toBoolean(val))
    end,

    listFiles = function(self, dir, outList)
        local files = mp.utils.readdir(dir, _MPV_ARG_READDIR_ONLY_FILES)
        utils.clearTable(outList)
        utils.appendArrayElements(outList, files)
    end,

    createDir = function(self, dir)
        return types.isString(dir) and unportable.createDir(dir)
    end,

    deleteTree = function(self, fullPath)
        if types.isString(fullPath)
        then
            local trashDirPath = self._mConfiguration.trashDirPath
            return types.isString(trashDirPath)
                and unportable.moveTree(fullPath, trashDirPath, true)
                or unportable.deleteTree(fullPath)
        end
    end,

    createTempFile = function(self)
        return io.tmpfile()
    end,

    readFile = function(self, fullPath)
        return types.isString(fullPath) and io.read(fullPath)
    end,

    readUTF8File = function(self, fullPath)
        return types.isString(fullPath) and unportable.readUTF8File(fullPath)
    end,

    writeFile = function(self, fullPath, mode)
        mode = mode or constants.FILE_MODE_WRITE_ERASE
        return types.isString(fullPath) and io.open(fullPath, mode)
    end,

    closeFile = function(self, file)
        utils.closeSafely(file)
    end,

    isExistedDir = function(self, fullPath)
        local ret = false
        if types.isString(fullPath)
        then
            local parentDir, dir = unportable.splitPath(fullPath)
            local dirs = mp.utils.readdir(parentDir, _MPV_ARG_READDIR_ONLY_DIRS)
            ret = utils.linearSearchArray(dirs, dir)
        end
        return ret
    end,

    isExistedFile = function(self, fullPath)
        local file = nil
        if types.isString(fullPath)
        then
            file = io.open(fullPath)
            utils.closeSafely(file)
        end
        return types.toBoolean(file)
    end,

    getUniqueFilePath = function(self, dir, prefix, suffix)
        local function __isExistedPath(app, fullPath)
            return app:isExistedFile(fullPath) or app:isExistedDir(fullPath)
        end

        local generator = self._mUniquePathGenerator
        return generator:getUniquePath(dir, prefix, suffix, __isExistedPath, self)
    end,

    getVideoFileMD5 = function(self)
        local md5 = self.__mVideoFileMD5
        if md5
        then
            return md5
        end

        local fullPath = self.__mVideoFilePath
        md5 = fullPath and unportable.calcFileMD5(fullPath, _APP_MD5_BYTE_COUNT)
        self.__mVideoFileMD5 = md5
        return md5
    end,

    __doGetConfigurationFullPath = function(self, relPath)
        local path = self:_getCurrentDirPath()
        local dirName = self:getConfiguration().privateDataDirName
        return path and dirName and unportable.joinPath(path, dirName)
    end,

    getDanmakuSourceRawDataDirPath = function(self)
        local relPath = self:getConfiguration().rawDataDirName
        return self:__doGetConfigurationFullPath(name)
    end,

    getDanmakuSourceMetaDataFilePath = function(self)
        local relPath = self:getConfiguration().metaDataFileName
        return self:__doGetConfigurationFullPath(relPath)
    end,

    getGeneratedASSFilePath = function(self)
        if self:getConfiguration().saveGeneratedASS
        then
            local videoFilePath = self.__mVideoFilePath
            return videoFilePath and videoFilePath .. _APP_ASS_FILE_SUFFIX
        end
    end,

    getCurrentDateTime = function(self)
        return os.time()
    end,

    executeExternalCommand = function(self, cmds)
        --TODOl
    end,
}

classlite.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderApp         = MPVDanmakuLoaderApp,
}