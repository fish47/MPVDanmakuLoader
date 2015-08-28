local utils = require("src/utils")          --= utils utils
local network = require("src/network")
local parse = require("src/parse")


local __MPVBuiltinFunctionMixin =
{
    setSubtitle = function(self, path)
        --
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

    getVideoDuration = function(self)
        local seconds = mp.get_property_number("duration", nil)
        return seconds and utils.convertHHMMSSToTime(0, 0, seconds, 0)
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
    _mParseContext          = nil,
    _mNetworkConnection     = nil,


    dispose = function(self)
        local ctx = self._mParseContext
        if ctx
        then
            ctx:dispose()
        end

        local conn = self._mNetworkConnection
        if conn
        then
            conn:dispose()
        end

        utils.clearTable(self)
    end,


    searchDanDanPlayByVideoInfos = function(self)
        --TODO
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


    parseBiliBiliRawData = function(self, rawData)
        --
    end,

    parseDanDanPlayRawData = function(self, rawData)
        --
    end,

    parseSRTFile = function(self, f)
        --
    end,

    writeDanmakus = function(self, f)
        --
    end,
}

utils.declareClass(MPVDanmakuLoaderApp)


return
{
    MPVDanmakuLoaderApp     = MPVDanmakuLoaderApp,
}