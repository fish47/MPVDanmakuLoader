local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")
local pluginbase    = require("src/plugins/pluginbase")


local _BILI_PLUGIN_NAME         = "BiliBili"

local _BILI_PATTERN_DANMAKU_ID  = "bili_%s_%s"
local _BILI_PATTERN_DANMAKU     = '<d%s+p="'
                                  .. "([%d%.]+),"       -- 起始时间
                                  .. "(%d+),"           -- 移动类型
                                  .. "(%d+),"           -- 字体大小
                                  .. "(%d+),"           -- 字体颜色
                                  .. "[^>]+,"
                                  .. "(%d+),"           -- ??
                                  .. "[^>]+,"
                                  .. "(%d+)"            -- ??
                                  .. '">([^<]+)</d>'

local _BILI_PATTERN_URL_1P      = "www%.bilibili%.[^/]*/video/av(%d+)"
local _BILI_PATTERN_URL_NP      = "www%.bilibili%.[^/]*/video/av(%d+)/index_(%d*).html"
local _BILI_PATTERN_ID          = "av(%d+)"
local _BILI_PATTERN_DURATION    = "<duration>(%d+):?(%d+)</duration>"
local _BILI_PATTERN_TITLE_1P    = "<title>(.-)</title>"
local _BILI_PATTERN_TITLE_NP    = "<option value=.->%d+、(.-)</option>"
local _BILI_PATTERN_CID_1       = "EmbedPlayer%(.-cid=(%d+).-%)"
local _BILI_PATTERN_CID_2       = '<iframe.-src=".-cid=(%d+).-"'
local _BILI_PATTERN_SANITIZE    = "[\x00-\x08\x0b\x0c\x0e-\x1f]"


local _BILI_FMT_URL_VIDEO_1P    = "http://www.bilibili.com/video/av%s/"
local _BILI_FMT_URL_VIDEO_NP    = "http://www.bilibili.com/video/av%s/index_%d.html"
local _BILI_FMT_URL_DAMAKU      = "http://comment.bilibili.com/%s.xml"
local _BILI_FMT_URL_VIDEO_INFO  = "http://interface.bilibili.com/player?id=cid:%s"


local _BILI_FACTOR_TIME_STAMP   = 1000
local _BILI_FACTOR_FONT_SIZE    = 25

local _BILI_DEFAULT_DURATION    = 0
local _BILI_DEFAULT_VIDEO_INDEX = 1

local _BILI_POS_MOVING_L2R      = 6
local _BILI_POS_MOVING_R2L      = 1
local _BILI_POS_STATIC_TOP      = 5
local _BILI_POS_STATIC_BOTTOM   = 4
local _BILI_POS_ADVANCED        = 7


-- 暂时不处理神弹幕
local _BILI_POS_TO_LAYER_MAP =
{
    [_BILI_POS_MOVING_L2R]      = danmaku.LAYER_MOVING_L2R,
    [_BILI_POS_MOVING_R2L]      = danmaku.LAYER_MOVING_R2L,
    [_BILI_POS_STATIC_TOP]      = danmaku.LAYER_STATIC_TOP,
    [_BILI_POS_STATIC_BOTTOM]   = danmaku.LAYER_STATIC_BOTTOM,
}


local function __sanitizeString(str)
    return str:gsub(_BILI_PATTERN_SANITIZE, constants.STR_EMPTY)
end


local BiliBiliDanmakuSourcePlugin =
{
    getName = function(self)
        return _BILI_PLUGIN_NAME
    end,

    _getGMatchPattern = function(self)
        return _BILI_PATTERN_DANMAKU
    end,

    _iterateAddDanmakuParams = function(self, iterFunc, cfg)
        local function __getLifeTime(cfg, pos)
            if pos == _BILI_POS_MOVING_L2R or pos == _BILI_POS_MOVING_R2L
            then
                return cfg.movingDanmakuLifeTime
            else
                return cfg.staticDanmakuLIfeTime
            end
        end

        local start, typeStr, size, color, id1, id2, txt = iterFunc()
        if not start
        then
            return
        end

        local pos = tonumber(typeStr)
        local layer = _BILI_POS_TO_LAYER_MAP[pos] or danmaku.LAYER_MOVING_L2R
        local startTime = tonumber(start) * _BILI_FACTOR_TIME_STAMP
        local lifeTime = __getLifeTime(cfg, pos)
        local fontColor = utils.convertRGBHexToBGRString(tonumber(color))
        local fontSize = math.floor(tonumber(size) / _BILI_FACTOR_FONT_SIZE) * cfg.danmakuFontSize
        local danmakuID = string.format(_BILI_PATTERN_DANMAKU_ID, id1, id2)
        local text = utils.unescapeXMLString(__sanitizeString(txt))
        return layer, startTime, lifeTime, fontColor, fontSize, danmakuID, text
    end,


    search = function(self, keyword, result)
        local function __getVideoIDAndIndex(keyword)
            local id, idx = keyword:match(_BILI_PATTERN_URL_NP)
            id = id or keyword:match(_BILI_PATTERN_URL_1P)
            id = id or keyword:match(_BILI_PATTERN_ID)
            idx = idx and tonumber(idx) or _BILI_DEFAULT_VIDEO_INDEX
            return id, idx
        end

        local function __parseCID(data, outCIDs)
            local cid = data:match(_BILI_PATTERN_CID_1)
            cid = cid or data:match(_BILI_PATTERN_CID_2)
            utils.pushArrayElement(outCIDs, cid)
        end


        local avID, index = __getVideoIDAndIndex(keyword)
        if not avID
        then
            return false
        end

        local conn = self._mApplication:getNetworkConnection()
        conn:resetParams()
        conn:addHeader(pluginbase._HEADER_USER_AGENT)
        conn:setCompressed(true)

        local data = conn:receive(string.format(_BILI_FMT_URL_VIDEO_1P, avID))
        if not data
        then
            return false
        end

        -- 分P视频
        local partIdx = 1
        for partName in data:gmatch(_BILI_PATTERN_TITLE_NP)
        do
            partName = __sanitizeString(partName)
            if partIdx == 1
            then
                __parseCID(data, result.videoIDs)
            else
                local url = string.format(_BILI_FMT_URL_VIDEO_NP, avID, partIdx)
                conn:receiveLater(url, __parseCID, result.videoIDs)
            end
            partIdx = partIdx + 1
            table.insert(result.videoTitles, partName)
        end
        conn:flushReceiveQueue()

        -- 单P视频
        if partIdx == 1
        then
            local title = data:match(_BILI_PATTERN_TITLE_1P)
            title = __sanitizeString(title)
            table.insert(result.videoTitles, title)
            __parseCID(data, result.videoIDs)
        end

        result.isSplited = true
        result.videoTitleColumnCount = 1
        result.preferredIDIndex = index
        return #result.videoIDs > 0 and #result.videoIDs == #result.videoTitles
    end,


    downloadRawDatas = function(self, videoIDs, outDatas)
        local function __addRawData(rawData, outDatas)
            utils.pushArrayElement(outDatas, rawData)
        end

        local conn = self._mApplication:getNetworkConnection()
        conn:resetParams()
        conn:addHeader(pluginbase._HEADER_USER_AGENT)
        conn:addHeader(pluginbase._HEADER_ACCEPT_XML)
        conn:setCompressed(true)
        for _, videoID in utils.iterateArray(videoIDs)
        do
            local url = string.format(_BILI_FMT_URL_DAMAKU, videoID)
            conn:receiveLater(url, __addRawData, outDatas)
        end
        conn:flushReceiveQueue()
    end,


    getVideoDurations = function(self, videoIDs, outDurations)
        local function __parseDuration(rawData, outDurations)
            local duration = _BILI_DEFAULT_DURATION
            if types.isString(rawData)
            then
                -- 时频长度一般以 "MM:SS" 表示
                -- 例如少于 1 分钟的视频，会不会用 "SS" 格式？
                local piece1, piece2 = rawData:match(_BILI_PATTERN_DURATION)
                if piece1 or piece2
                then
                    local minutes = (piece1 and piece2) and piece1 or 0
                    local seconds = piece2 or piece1
                    minutes = tonumber(minutes)
                    seconds = tonumber(seconds)
                    duration = utils.convertHHMMSSToTime(0, minutes, seconds, 0)
                end
            end
            utils.pushArrayElement(outDurations, duration)
        end

        local conn = self._mApplication:getNetworkConnection()
        conn:resetParams()
        conn:addHeader(pluginbase._HEADER_USER_AGENT)
        for _, videoID in utils.iterateArray(videoIDs)
        do
            local url = string.format(_BILI_FMT_URL_VIDEO_INFO, videoID)
            conn:receiveLater(url, __parseDuration, outDurations)
        end
        conn:flushReceiveQueue()
    end,
}

classlite.declareClass(BiliBiliDanmakuSourcePlugin, pluginbase.StringBasedDanmakuSourcePlugin)


return
{
    BiliBiliDanmakuSourcePlugin     = BiliBiliDanmakuSourcePlugin,
}