local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local bilibili      = require("src/search/bilibili")
local dandanplay    = require("src/search/dandanplay")


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


local MPVDanmakuLoaderApp =
{
    _mConfiguration     = classlite.declareClassField(MPVDanmakuLoaderCfg),
    _mDanmakuPools      = classlite.declareClassField(danmaku.DanmakuPools),
    _mNetworkConnection = classlite.declareClassField(unportable.CURLNetworkConnection),

    getConfiguration = function(self)
        return self._mConfiguration
    end,

    getDanmakuPools = function(self)
        return self._mDanmakuPools
    end,

    getNetworkConnection = function(self)
        return self._mNetworkConnection
    end,

    _onLoadFile = function(self)
        --TODO
    end,

    setSubtitle = function(self, path)
        mp.commandv("sub_add ", path)
    end,

    listFiles = function(self, dir, outList)
        local files = mp.utils.readdir(dir, "files")
        utils.clearTable(outList)
        utils.appendArrayElements(outList, files)
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

    getSRTFileSearchDirPath = function(self)
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