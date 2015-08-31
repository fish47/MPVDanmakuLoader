local _base = require("src/_network/_base")
local utils = require("src/utils")          --= utils utils


local _DDP_PATTERN_URL_GET_DANMAKU  = "http://acplay.net/api/v1/comment/%s"
local _DDP_PATTERN_URL_MATCH_VIDEO  = 'http://acplay.net/api/v1/match?'
                                      .. 'fileName=%s'
                                      .. '&hash=%s'
                                      .. '&length=%s'
                                      .. '&duration=%s'


local _DDP_PATTERN_MATCH_RESULTS    = '<Match'
                                      .. '%s+EpisodeId="([^"]+)"'
                                      .. '%s+AnimeTitle="([^"]+)"'
                                      .. '%s+EpisodeTitle="([^"]+)"'
                                      .. '%s+Type="[^"]+"'
                                      .. '%s+Shift="[^"]+"%s*'
                                      .. '/>'

local _DDP_ACCEPT_CONTENT_TYPE_XML  = "Accept: application/xml"


local DanDanPlayVideoInfo =
{
    videoTitle      = nil,
    videoSubtitle   = nil,
    danmakuURL      = nil,

    new = function(obj, title, subTitle, url)
        obj = utils.allocateInstance(obj)
        obj.videoTitle = title
        obj.videoSubtitle = subTitle
        obj.danmakuURL = url
        return obj
    end,
}

utils.declareClass(DanDanPlayVideoInfo)


local function searchDanDanPlayByVideoInfos(conn, fileName, md5Hash, byteCount, seconds)
    conn:resetParams()
    conn:addHeader(_DDP_ACCEPT_CONTENT_TYPE_XML)
    local url = string.format(_DDP_PATTERN_URL_MATCH_VIDEO,
                              utils.escapeURLString(fileName),
                              md5Hash,
                              tostring(byteCount),
                              tostring(seconds))

    local result = nil
    local rawData = conn:doGET(url)
    if rawData
    then
        for episodeID, title, subTitle in rawData:gmatch(_DDP_PATTERN_MATCH_RESULTS)
        do
            local info = DanDanPlayVideoInfo:new()
            info.videoTitle = title
            info.videoSubtitle = subTitle
            info.danmakuURL = string.format(_DDP_PATTERN_URL_GET_DANMAKU, episodeID)

            result = result or {}
            table.insert(result, info)
        end
    end

    return result
end


local function getDanDanPlayDanmakuRawData(conn, url)
    if not url
    then
        return nil
    end

    conn:resetParams()
    conn:addHeader(_DDP_ACCEPT_CONTENT_TYPE_XML)
    return conn:doGET(url)
end


return
{
    DanDanPlayVideoInfo             = DanDanPlayVideoInfo,
    searchDanDanPlayByVideoInfos    = searchDanDanPlayByVideoInfos,
    getDanDanPlayDanmakuRawData     = getDanDanPlayDanmakuRawData,
}