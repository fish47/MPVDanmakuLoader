local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local configuration = require("src/shell/configuration")
local srt           = require("src/plugins/srt")
local acfun         = require("src/plugins/acfun")
local bilibili      = require("src/plugins/bilibili")
local dandanplay    = require("src/plugins/dandanplay")


local _APP_MD5_BYTE_COUNT   = 32 * 1024 * 1024

local MPVDanmakuLoaderApp =
{
    _mConfiguration         = classlite.declareConstantField(nil),
    _mDanmakuPools          = classlite.declareClassField(danmaku.DanmakuPools),
    _mNetworkConnection     = classlite.declareClassField(unportable.CURLNetworkConnection),
    _mDanmakuSourcePlugins  = classlite.declareTableField(),
    _mUniquePathGenerator   = classlite.declareClassField(unportable.UniquePathGenerator),

    __mVideoFileMD5         = classlite.declareConstantField(nil),
    __mVideoFilePath        = classlite.declareConstantField(nil),


    new = function(self)
        self:_initDanmakuSourcePlugins()
    end,

    init = function(self, cfg, filePath)
        self._mConfiguration = cfg
        self.__mVideoFilePath = filePath
        self.__mVideoFileMD5 = nil
        self._mDanmakuPools:clear()
        self._mNetworkConnection:reset()

        for _, pool in self._mDanmakuPools:iteratePools()
        do
            pool:setAddDanmakuHook(cfg.addDanmakuHook)
        end
    end,

    _initDanmakuSourcePlugins = function(self)
        local plugins = utils.clearTable(self._mDanmakuSourcePlugins)
--        table.insert(plugins, srt.SRTDanmakuSourcePlugin:new())
--        table.insert(plugins, acfun.AcfunDanmakuSourcePlugin:new())
--        table.insert(plugins, bilibili.BiliBiliDanmakuSourcePlugin:new())
--        table.insert(plugins, dandanplay.DanDanPlayDanmakuSourcePlugin:new())

        local function __setApplication(plugin, app)
            plugin:setApplication(app)
        end
        utils.forEachArrayElement(plugins, __setApplication, self)
    end,

    iterateDanmakuSourcePlugin = function(self)
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
        mp.commandv("sub_add ", path)
    end,

    setSubtitleData = function(self, data)
        mp.commandv("sub_add", "memory://" .. data)
    end,

    listFiles = function(self, dir, outList)
        local files = mp.utils.readdir(dir, "files")
        utils.clearTable(outList)
        utils.appendArrayElements(outList, files)
    end,

    createDir = function(self, dir)
        return types.isString(dir) and unportable.createDir(dir)
    end,

    deleteTree = function(self, dir)
        return types.isString(dir) and unportable.deleteTree(dir)
    end,

    createTempFile = function(self)
        return io.tmpfile()
    end,

    readFile = function(self, fullPath)
        return types.isString(fullPath) and io.read(fullPath)
    end,

    readUTF8File = function(self, fullPath)
        --TODO
    end,

    writeFile = function(self, fullPath, mode)
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
        if types.iString(fullPath)
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

    getVideoMD5 = function(self)
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

    getCurrentDateTime = function(self)
        return os.time()
    end,

    getVideoWidth = function(self)
        return mp.get_property_number("width", nil)
    end,

    getVideoHeight = function(self)
        return mp.get_property_number("height", nil)
    end,
}

classlite.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderApp     = MPVDanmakuLoaderApp,
}