local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local bilibili      = require("src/search/bilibili")
local dandanplay    = require("src/search/dandanplay")


local MPVDanmakuLoaderCfg   =
{
    bottomReservedHeight    = 0,                -- 弹幕底部预留空间
    danmakuFontSize         = 34,               -- 弹幕默认字体大小
    danmakuFontName         = "sans-serif",     -- 弹幕默认字体名
    danmakuFontColor        = 0x33FFFFFF,       -- 弹幕默认颜色 BBGGRR
    subtitleFontSize        = 34,               -- 字幕默认字体大小
    subtitleFontName        = "mono",           -- 字幕默认字体名
    subtitleFontColor       = 0xFFFFFFFF,       -- 字幕默认颜色 BBGGRR
}

classlite.declareClass(MPVDanmakuLoaderCfg)


local MPVDanmakuLoaderApp =
{
    _mDanmakuPools          = classlite.declareClassField(danmaku.DanmakuPools),
    _mConfiguration         = classlite.declareConstantField(nil),
    _mNetworkConnection     = classlite.declareConstantField(nil),

    new = function(self, cfg, conn)
        self._mConfiguration = cfg
        self._mNetworkConnection = conn
    end,

    getConfiguration = function(self)
        return self._mConfiguration
    end,

    getDanmakuPools = function(self)
        return self._mDanmakuPools
    end,

    setSubtitle = function(self, path)
        mp.commandv("sub_add ", path)
    end,

    splitPath = function(self, path)
        return mp.utils.split_path(path)
    end,

    joinPath = function(self, p1, p2)
        return mp.utils.join_path(p1, p2)
    end,

    listFiles = function(self, dir, outList)
        local files = mp.utils.readdir(dir, "files")
        utils.clearTable(outList)
        utils.extendArray(outList, files)
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
        local dir = self:splitPath(self:getVideoFilePath())
        return self:joinPath(dir, ".danmakuloader")
    end,

    getSRTFileSearchDirPath = function(self)
        local dir = self:splitPath(self:getVideoFilePath())
        return dir
    end,

    getDanmakuSourceRawDataDirPath = function(self)
        return self:joinPath(self:_getPrivateDirPath(), "rawdata")
    end,

    getDanmakuSourceMetaFilePath = function(self)
        return self:joinPath(self:_getPrivateDirPath(), "meta.lua")
    end,
}

classlite.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderCfg     = MPVDanmakuLoaderCfg,
    MPVDanmakuLoaderApp     = MPVDanmakuLoaderApp,
}