local _base = require("src/_network/_base")
local utils = require("src/utils")          --= utils utils

local _DDP_PATTERN_URL_GET_DANMAKU  = "http://acplay.net/api/v1/comment/%s"
local _DDP_PATTERN_URL_MATCH_VIDEO  = "http://acplay.net/api/v1/match?fileName=%s&hash=%s&length=%s&duration=%s"


local _DDP_KEY_MATCH_MATCHES        = "matches"
local _DDP_KEY_MATCH_TITLE          = "AnimeTitle"
local _DDP_KEY_MATCH_SUBTITLE       = "EpisodeTitle"
local _DDP_KEY_MATCH_COMMENT_ID     = "EpisodeId"

local _DDP_ACCEPT_CONTENT_TYPE_XML  = "Accept: application/xml"
local _DDP_ACCEPT_CONTENT_TYPE_JSON = "Accept: application/json"

local DanDanPlayVideoInfo =
{
    videoTitle      = nil,
    videoSubtitle   = nil,
    danmakuURL      = nil,
}

utils.declareClass(DanDanPlayVideoInfo)


local function searchDanDanPlayByVideoInfos(conn, fileName, md5Hash, byteCount, seconds)
    conn:resetParams()
    local url = string.format(_DDP_PATTERN_URL_MATCH_VIDEO,
                              utils.escapeURLString(fileName),
                              md5Hash,
                              tostring(byteCount),
                              tostring(seconds))

    local result = nil
    local ret = conn:doGET(url)
    local succeed, obj = utils.parseJSON(ret)
    if not succeed
    then
        return nil
    end

    local matchList = obj[_DDP_KEY_MATCH_MATCHES]
    for _, matchOBj in ipairs(matchList)
    do
        local title = matchOBj[_DDP_KEY_MATCH_TITLE]
        local subtitle = matchOBj[_DDP_KEY_MATCH_SUBTITLE]
        local danmakuID = matchOBj[_DDP_KEY_MATCH_COMMENT_ID]
        if title and subtitle and danmakuID
        then
            local info = DanDanPlayVideoInfo:new()
            info.videoTitle = title
            info.videoSubtitle = subtitle
            info.danmakuURL = string.format(_DDP_PATTERN_URL_GET_DANMAKU, tostring(danmakuID))
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



local _FILE = "/home/fish47/111/SAO/[ZERO动漫下载][SOSG&DMG][刀剑神域][18][1280x720][BIG5].mp4"
local _FILE_NAME = "[ZERO动漫下载][SOSG&DMG][刀剑神域][18][1280x720][BIG5].mp4"
local _BYTE_COUNT = 171772938
local _SECONDS = 1440
local _HASH = "feb860735d3e2be9be6ae789962c7ca8"

local conn = _base.CURLNetworkConnection:new("curl")

--searchDanDanPlay(conn, _FILE_NAME, _HASH, _BYTE_COUNT, _SECONDS)
local ret = getDanDanPlayDanmakuRawData(conn, "http://acplay.net/api/v1/comment/86920001")
local f = io.open("/tmp/123.txt", "w+")
f:write(ret)
f:close()
print(ret:find('[\x00-\x08\x0b\x0c\x0e-\x1f]', 1, false))