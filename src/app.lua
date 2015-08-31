local utils = require("src/utils")          --= utils utils
local network = require("src/network")
local parse = require("src/parse")


local __MPVBuiltinFunctionMixin =
{
    setSubtitle = function(self, path)
        mp.commandv("sub_add ", path)
    end,

    splitPath = function(self, path)
        return mp.utils.split_path(path)
    end,

    joinPath = function(self, p1, p2)
        return mp.utils.join_path(p1, p2)
    end,

    listFiles = function(self, dir)
        return mp.utils.readdir(dir, "files")
    end,

    getVideoFilePath = function(self)
        return mp.get_property("path", nil)
    end,

    getVideoFileName = function(self)
        return mp.get_property("filename", nil)
    end,

    getVideoByteCount = function(self)
        return mp.get_property_number("file-size", nil)
    end,

    getVideoDurationSeconds = function(self)
        return mp.get_property_number("duration", nil)
    end,

    getVideoWidth = function(self)
        local width = mp.get_property("width", nil)
        return width and tonumber(width)
    end,

    getVideoHeight = function(self)
        local height = mp.get_property("height", nil)
        return height and tonumber(height)
    end,
}

utils.declareClass(__MPVBuiltinFunctionMixin)


local MPVDanmakuLoaderApp =
{
    _mDanmakuPools          = nil,
    _mAPPConfiguration      = nil,
    _mNetworkConnection     = nil,


    new = function(obj, appCfg, conn)
        obj = utils.allocateInstance(obj)
        obj._mDanmakuPools = parse.DanmakuPools:new()
        obj._mAPPConfiguration = appCfg
        obj._mNetworkConnection = conn
        return obj
    end,


    dispose = function(self)
        utils.disposeSafely(self._mDanmakuPools)
        utils.clearTable(self)
    end,


    searchDanDanPlayByVideoInfos = function(self)
        local conn = self._mNetworkConnection
        local name = self:getVideoFileName()
        local hash = nil
        local byteCount = self:getVideoByteCount()
        local seconds = self:getVideoDurationSeconds()
        return network.searchDanDanPlayByVideoInfos(conn, name, hash, byteCount, seconds)
    end,

    searchBiliBiliByKeyword = function(self, keyword, maxPageCount)
        local conn = self._mNetworkConnection
        return network.searchBiliBiliByKeyword(conn, keyword, maxPageCount)
    end,

    getBiliBiliVideoInfos = function(self, videoID)
        local conn = self._mNetworkConnection
        return network.getBiliBiliVideoInfos(conn, videoID)
    end,


    getDanDanPlayDanmakuRawData = function(self, url)
        local conn = self._mNetworkConnection
        return network.getDanDanPlayDanmakuRawData(conn, url)
    end,

    getBiliBiliDanmakuRawData = function(self, url)
        local conn = self._mNetworkConnection
        return network.getBiliBiliDanmakuRawData(conn, url)
    end,


    parseBiliBiliRawData = function(self, rawData, offset)
        local cfg = self._mAPPConfiguration
        local pools = self._mDanmakuPools
        parse.parseBiliBiliRawData(cfg, pools, rawData, offset)
    end,

    parseDanDanPlayRawData = function(self, rawData)
        local cfg = self._mAPPConfiguration
        local pools = self._mDanmakuPools
        parse.parseDanDanPlayRawData(cfg, pools, rawData)
    end,

    parseSRTFile = function(self, f)
        parse.parseSRTFile(self._mParseContext, f)
    end,

    flushToASSFile = function(self, fullPath)
        local w = self:getVideoWidth()
        local h = self:getVideoHeight()
        local cfg = self._mAPPConfiguration
        local pools = self._mDanmakuPools
        local f = io.open(fullPath, "w+")
        if f
        then
            parse.writeDanmakus(cfg, pools, w, h , f)
            f:close()
        end
        pools:clear()
    end,
}

utils.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderApp     = MPVDanmakuLoaderApp,
}