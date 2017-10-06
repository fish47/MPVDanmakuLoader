local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmakupool   = require("src/core/danmakupool")
local pluginbase    = require("src/plugins/pluginbase")


local _PLUGIN_NAME          = "BiliBili"

local _PATTERN_DANMAKU      = '<d%s+p="'
                                .. "([%d%.]+),"       -- 起始时间
                                .. "(%d+),"           -- 移动类型
                                .. "(%d+),"           -- 字体大小
                                .. "(%d+),"           -- 字体颜色
                                .. "[^>]+,"
                                .. "[^>]+,"           -- 据说是 弹幕池 ID ，但一般都是 0
                                .. "[^>]+,"
                                .. "(%d+)"            -- 弹幕 ID
                                .. '">([^<]+)</d>'

local _PATTERN_TITLE_1P     = '<h1 title="(.-)">'
local _PATTERN_TITLE_NP     = "<option value=.-cid='(%d+)'>%d+、(.-)</option>"
local _PATTERN_CID_1P       = "EmbedPlayer%(.-cid=(%d+).-%)"
local _PATTERN_SANITIZE     = "[\x00-\x08\x0b\x0c\x0e-\x1f]"

local _FMT_SEARCH_URL_VIDEO_1P      = "http://www.bilibili.com/video/av%s/"
local _FMT_SEARCH_URL_VIDEO_NP      = "http://www.bilibili.com/video/av%s/index_%d.html"
local _FMT_SEARCH_URL_DAMAKU        = "http://comment.bilibili.com/%s.xml"
local _FMT_SEARCH_URL_BANGUMI_INFO  = "http://bangumi.bilibili.com/web_api/episode/%s.json"
local _FMT_SEARCH_TITLE_CID         = "cid-%s"

local _PATTERN_SEARCH_1P        = ".-www%.bilibili%.[^/]+/video/av(%d+)"
local _PATTERN_SEARCH_NP_1      = ".-www%.bilibili%.[^/]+/video/av(%d+)/index_(%d+)"
local _PATTERN_SEARCH_NP_2      = ".-www%.bilibili%.[^/]+/video/av(%d+)/.-#page=(%d+)"
local _PATTERN_SEARCH_BANGUMI   = ".-bangumi.bilibili.[^/]+/anime/%d+/play#(%d+)"
local _PATTERN_SEARCH_AVID      = "bili:av(%d+)"
local _PATTERN_SEARCH_CID       = "bili:cid(%d+)"

local _CONST_STR_NEWLINE            = "/n"
local _CONST_JSON_BANGUMI_CID       = "longTitle"
local _CONST_JSON_BANGUMI_TITLE     = "danmaku"

local _CONST_VIDEO_INDEX_DEFAULT    = 1
local _CONST_FACTOR_TIME_STAMP      = 1000
local _CONST_FACTOR_FONT_SIZE       = 25

-- 暂时不处理神弹幕
local _POS_TO_LAYER_MAP =
{
    [6] = danmakupool.LAYER_MOVING_L2R,
    [1] = danmakupool.LAYER_MOVING_R2L,
    [5] = danmakupool.LAYER_STATIC_TOP,
    [4] = danmakupool.LAYER_STATIC_BOTTOM,
}


local function __sanitizeString(str)
    local ret = str:gsub(_PATTERN_SANITIZE, constants.STR_EMPTY)
    return ret
end


local BiliBiliPlugin = {}

function BiliBiliPlugin:getName()
    return _PLUGIN_NAME
end

function BiliBiliPlugin:_startExtractDanmakus(rawData)
    return rawData:gmatch(_PATTERN_DANMAKU)
end

function BiliBiliPlugin:_extractDanmaku(iterFunc, cfg, danmakuData)
    local startTime, layer, fontSize, fontColor, danmakuID, text = iterFunc()
    if not startTime
    then
        return
    end

    local size = tonumber(fontSize) / _CONST_FACTOR_FONT_SIZE * cfg.danmakuFontSize
    local text = utils.unescapeXMLString(__sanitizeString(text))
    text = text:gsub(_CONST_STR_NEWLINE, constants.STR_NEWLINE)
    danmakuData.fontSize = math.floor(size)
    danmakuData.fontColor = tonumber(fontColor)
    danmakuData.startTime = tonumber(startTime) * _CONST_FACTOR_TIME_STAMP
    danmakuData.danmakuID = tonumber(danmakuID)
    danmakuData.danmakuText = text
    return _POS_TO_LAYER_MAP[tonumber(layer)] or danmakupool.LAYER_SKIPPED
end

local function __getVideoIDAndIndex(keyword)
    local function __match(input, pattern, ...)
        if pattern
        then
            local id, idx = input:match(pattern)
            if id
            then
                return id, idx
            else
                return __match(input, ...)
            end
        end
    end

    local id, idx = __match(keyword, _PATTERN_SEARCH_NP_1, _PATTERN_SEARCH_NP_2)
    id = id or keyword:match(_PATTERN_SEARCH_1P)
    id = id or keyword:match(_PATTERN_SEARCH_AVID)
    idx = idx and types.toInt(idx) or _CONST_VIDEO_INDEX_DEFAULT
    return id, idx
end

local function __addTitleAndCID(result, title, cid)
    table.insert(result.videoIDs, cid)
    table.insert(result.videoTitles, __sanitizeString(title))
end


function BiliBiliPlugin:_searchCID(result, cid)
    local title = string.format(_FMT_SEARCH_TITLE_CID, cid)
    __addTitleAndCID(result, title, cid)
    return _CONST_VIDEO_INDEX_DEFAULT
end

function BiliBiliPlugin:_getVideoPageURL(avID, idx)
    return (idx ~= _CONST_VIDEO_INDEX_DEFAULT)
        and string.format(_FMT_SEARCH_URL_VIDEO_1P, avID)
        or string.format(_FMT_SEARCH_URL_VIDEO_NP, avID, idx)
end

function BiliBiliPlugin:_searchAV(result, avID, idx)
    local url = self:_getVideoPageURL(avID, idx)
    local data = self:_startRequestUncompressedData():receive(url)
    if not data
    then
        return
    end

    -- 可能是 np 视频
    local partCount = 0
    for cid, partName in data:gmatch(_PATTERN_TITLE_NP)
    do
        local title = utils.unescapeXMLString(partName)
        partCount = partCount + 1
        __addTitleAndCID(result, title, cid)
    end

    -- 可能是 1p 视频
    if partCount == 0
    then
        local _, __, title = data:find(_PATTERN_TITLE_1P)
        local _, __, cid = data:find(_PATTERN_CID_1P)
        if title and cid
        then
            partCount = 1
            __addTitleAndCID(result, title, cid)
        end
    end

    if partCount > 0
    then
        return idx
    end
end

function BiliBiliPlugin:_getBangumiInfoURL(bangumiID)
    return string.format(_FMT_SEARCH_URL_BANGUMI_INFO, bangumiID)
end

function BiliBiliPlugin:_searchBangumi(result, bangumiID)
    local url = self:_getBangumiInfoURL(bangumiID)
    local data = self:_startRequestUncompressedData():receive(url)
    if not data
    then
        return
    end

    local cid = utils.findJSONKeyValue(data, _CONST_JSON_BANGUMI_TITLE)
    local title = utils.findJSONKeyValue(data, _CONST_JSON_BANGUMI_CID)
    if cid and title
    then
        __addTitleAndCID(result, title, cid)
        return _CONST_VIDEO_INDEX_DEFAULT
    end
end


function BiliBiliPlugin:search(keyword, result)
    -- 直接用 cid 搜索，暂时不支持反查视频标题
    local cid = keyword:match(_PATTERN_SEARCH_CID)
    if cid
    then
        return self:_searchCID(cid)
    end

    -- 用 av 号搜索，如果是 np 视频后面还有 index_*.html
    local avID, idx = __getVideoIDAndIndex(keyword)
    if avID
    then
        return self:_searchAV(result, avID, idx)
    end

    -- 番号搜索
    local bangumiID = keyword:match(_PATTERN_SEARCH_BANGUMI)
    if bangumiID
    then
        return self:_searchBangumi(result, bangumiID)
    end
end


function BiliBiliPlugin:_prepareToDownloadDanmaku(conn, videoID)
    self:_startRequestUncompressedXML(conn)
    return string.format(_FMT_SEARCH_URL_DAMAKU, videoID)
end

classlite.declareClass(BiliBiliPlugin, pluginbase._AbstractDanmakuSourcePlugin)


return
{
    BiliBiliPlugin      = BiliBiliPlugin,
}
