local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local danmakupool   = require("src/core/danmakupool")
local configuration = require("src/shell/configuration")
local pluginbase    = require("src/plugins/pluginbase")
local srt           = require("src/plugins/srt")
local acfun         = require("src/plugins/acfun")
local bilibili      = require("src/plugins/bilibili")
local dandanplay    = require("src/plugins/dandanplay")


local _APP_MD5_BYTE_COUNT       = 32 * 1024 * 1024
local _APP_PRIVATE_DIR_NAME     = ".mpvdanmakuloader"
local _APP_ASS_FILE_SUFFIX      = ".ass"


local _TAG_LOG_WIDTH            = 14
local _TAG_PLUGIN               = "plugin"
local _TAG_NETWORK              = "network"
local _TAG_FILESYSTEM           = "filesystem"
local _TAG_SUBTITLE             = "subtitle"


local MPVDanmakuLoaderApp =
{
    _mConfiguration                     = classlite.declareConstantField(nil),
    _mDanmakuPools                      = classlite.declareClassField(danmakupool.DanmakuPools),
    _mNetworkConnection                 = classlite.declareClassField(unportable.CURLNetworkConnection),
    _mDanmakuSourcePlugins              = classlite.declareTableField(),
    _mUniquePathGenerator               = classlite.declareClassField(unportable.UniquePathGenerator),
    _mLogFunction                       = classlite.declareConstantField(nil),

    __mVideoFileMD5                     = classlite.declareConstantField(nil),
    __mVideoFilePath                    = classlite.declareConstantField(nil),
    __mPrivateDirPath                   = classlite.declareConstantField(nil),


    new = function(self)
        -- 在这些统一做 monkey patch 可以省一些的重复代码，例如文件操作那堆 Log
        self:_initDanmakuSourcePlugins()
        self:__attachMethodLoggingHooks()
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
        self.readFile       = __createPatchedFSFunction(clzApp.readFile,        "read")
        self.readUTF8File   = __createPatchedFSFunction(clzApp.readUTF8File,    "readUTF8")
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
        self._mLogFunction = types.isFunction(func) and func
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

    init = function(self, cfg, filePath)
        self._mConfiguration = cfg
        self._mNetworkConnection:reset()
        self._mNetworkConnection:setTimeout(cfg.networkTimeout)

        local dir = filePath and unportable.splitPath(filePath)
        self.__mPrivateDirPath = dir and unportable.joinPath(dir, _APP_PRIVATE_DIR_NAME)
        self.__mVideoFileMD5 = nil
        self.__mVideoFilePath = filePath

        local pools = self._mDanmakuPools
        pools:clear()
        for _, pool in pools:iteratePools()
        do
            pool:setAddDanmakuHook(cfg.addDanmakuHook)
        end
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

    setSubtitleFile = function(self, path)
        if self:isExistedFile(path)
        then
            mp.commandv("sub_add ", path)
        end
    end,

    setSubtitleData = function(self, data)
        if not types.isNilOrEmpty(data)
        then
            mp.commandv("sub_add", "memory://" .. data)
        end
    end,

    listFiles = function(self, dir, outList)
        local files = mp.utils.readdir(dir, "files")
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
            local dirs = mp.utils.readdir(parentDir, "dirs")
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

    _getPrivateDirPath = function(self)
        return self.__mPrivateDirPath
    end,

    __doGetConfigurationFullPath = function(self, relPath)
        local dir = self:_getPrivateDirPath()
        return dir and relPath and unportable.joinPath(dir, relPath)
    end,

    getDanmakuSourceRawDataDirPath = function(self)
        local cfg = self:getConfiguration()
        return cfg and self:__doGetConfigurationFullPath(cfg.rawDataRelDirPath)
    end,

    getDanmakuSourceMetaDataFilePath = function(self)
        local cfg = self:getConfiguration()
        return cfg and self:__doGetConfigurationFullPath(cfg.metaDataRelFilePath)
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
}

classlite.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderApp         = MPVDanmakuLoaderApp,
}