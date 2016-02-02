local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local srt           = require("src/plugins/srt")
local bilibili      = require("src/plugins/bilibili")
local dandanplay    = require("src/plugins/dandanplay")


local MPVDanmakuLoaderCfg =
{
    bottomReservedHeight    = 0,                -- 弹幕底部预留空间
    danmakuFontSize         = 34,               -- 弹幕默认字体大小
    danmakuFontName         = "sans-serif",     -- 弹幕默认字体名
    danmakuFontColor        = 0x33FFFFFF,       -- 弹幕默认颜色 BBGGRR
    subtitleFontSize        = 34,               -- 字幕默认字体大小
    subtitleFontName        = "mono",           -- 字幕默认字体名
    subtitleFontColor       = 0xFFFFFFFF,       -- 字幕默认颜色 BBGGRR
    movingDanmakuLifeTime   = 8000,             -- 滚动弹幕存活时间
    staticDanmakuLIfeTime   = 5000,             -- 固定位置弹幕存活时间
}

classlite.declareClass(MPVDanmakuLoaderCfg)


local _UNIQUE_PATH_FMT_FILE_NAME    = "%s%s%03d%s"
local _UNIQUE_PATH_FMT_TIME_PREFIX  = "%y%m%d%H%M"


local MPVDanmakuLoaderApp =
{
    _mConfiguration         = classlite.declareClassField(MPVDanmakuLoaderCfg),
    _mDanmakuPools          = classlite.declareClassField(danmaku.DanmakuPools),
    _mNetworkConnection     = classlite.declareClassField(unportable.CURLNetworkConnection),
    _mDanmakuSourcePlugins  = classlite.declareTableField(),
    __mUniqueFilePathID     = classlite.declareConstantField(0),


    new = function(self)
        self:_initDanmakuSourcePlugins()
    end,

    _onLoadFile = function(self)
        --TODO
    end,

    _initDanmakuSourcePlugins = function(self)
--        local plugins = utils.clearTable(self._mDanmakuSourcePlugins)
--        table.insert(plugins, bilibili.BiliBiliDanmakuSourcePlugin:new())
--        table.insert(plugins, dandanplay.DanDanPlayDanmakuSourcePlugin:new())
--        table.insert(plugins, acfun.AcfunDanmakuSourcePlugin:new())
--        table.insert(plugins, srt.SRTDanmakuSourcePlugin:new()))
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

    setSubtitle = function(self, path)
        mp.commandv("sub_add ", path)
    end,

    listFiles = function(self, dir, outList)
        local files = mp.utils.readdir(dir, "files")
        utils.clearTable(outList)
        utils.appendArrayElements(outList, files)
    end,

    getUniqueFilePath = function(self, dir, preffix, suffix)
        preffix = types.isString(preffix) and preffix or constants.STR_EMPTY
        suffix = types.isString(suffix) and suffix or constants.STR_EMPTY

        local time = self:getCurrentDateTime()
        local timeStr = os.date(_UNIQUE_PATH_FMT_TIME_PREFIX, time)
        while true
        do
            local pathID = self.__mUniqueFilePathID
            self.__mUniqueFilePathID = pathID + 1

            local fileName = string.format(_UNIQUE_PATH_FMT_FILE_NAME,
                                           preffix, timeStr, pathID, suffix)


            local fullPath = unportable.joinPath(dir, fileName)
            if not self:isExistedFile(fullPath)
            then
                return fullPath
            end
        end
    end,

    getVideoMD5 = function(self)
        --TODO
    end,

    getCurrentDateTime = function(self)
        return os.time()
    end,

    getVideoFilePath = function(self)
        return mp.get_property("path", nil)
    end,

    getVideoWidth = function(self)
        return mp.get_property_number("width", nil)
    end,

    getVideoHeight = function(self)
        return mp.get_property_number("height", nil)
    end,

    _getPrivateDirPath = function(self)
        local dir = unportable.splitPath(self:getVideoFilePath())
        return unportable.joinPath(dir, ".danmakuloader")
    end,

    getLocalDanamakuSourceDirPath = function(self)
        local dir = unportable.splitPath(self:getVideoFilePath())
        return dir
    end,

    getDanmakuSourceRawDataDirPath = function(self)
        return unportable.joinPath(self:_getPrivateDirPath(), "rawdata")
    end,

    getDanmakuSourceMetaFilePath = function(self)
        return unportable.joinPath(self:_getPrivateDirPath(), "meta.lua")
    end,
}

classlite.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderCfg     = MPVDanmakuLoaderCfg,
    MPVDanmakuLoaderApp     = MPVDanmakuLoaderApp,
}