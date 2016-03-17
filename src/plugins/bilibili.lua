local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")
local pluginbase    = require("src/plugins/pluginbase")


local _BILI_PLUGIN_NAME         = "BiliBili"

local _BILI_PATTERN_DANMAKU     = '<d%s+p="'
                                  .. "([%d%.]+),"       -- 起始时间
                                  .. "(%d+),"           -- 移动类型
                                  .. "(%d+),"           -- 字体大小
                                  .. "(%d+),"           -- 字体颜色
                                  .. "[^>]+,"
                                  .. "[^>]+,"           -- 据说是 弹幕池 ID ，但一股都是 0
                                  .. "[^>]+,"
                                  .. "(%d+)"            -- 弹幕 ID
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

-- 暂时不处理神弹幕
local _BILI_POS_TO_LAYER_MAP =
{
    [6] = danmaku.LAYER_MOVING_L2R,
    [1] = danmaku.LAYER_MOVING_R2L,
    [5] = danmaku.LAYER_STATIC_TOP,
    [4] = danmaku.LAYER_STATIC_BOTTOM,
}


local function __sanitizeString(str)
    return str:gsub(_BILI_PATTERN_SANITIZE, constants.STR_EMPTY)
end


local BiliBiliDanmakuSourcePlugin =
{
    getName = function(self)
        return _BILI_PLUGIN_NAME
    end,

    _startExtractDanmakus = function(self, rawData)
        return rawData:gmatch(_BILI_PATTERN_DANMAKU)
    end,

    _extractDanmaku = function(self, iterFunc, cfg)
        local startTime, layer, fontSize, fontColor, danmakuID, text = iterFunc()
        if not startTime
        then
            return
        end

        layer = _BILI_POS_TO_LAYER_MAP[tonumber(layer)]
        startTime = tonumber(startTime) * _BILI_FACTOR_TIME_STAMP
        fontColor = utils.convertRGBHexToBGRString(tonumber(fontColor))
        fontSize = math.floor(tonumber(fontSize) / _BILI_FACTOR_FONT_SIZE) * cfg.danmakuFontSize
        danmakuID = tonumber(danmakuID)
        text = utils.unescapeXMLString(__sanitizeString(text))

        local lifeTime = self:_getLifeTimeByLayer(cfg, layer)
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

    __initNetworkConnection = function(self, conn)
        conn:resetParams()
        conn:addHeader(pluginbase._HEADER_USER_AGENT)
        conn:addHeader(pluginbase._HEADER_ACCEPT_XML)
        conn:setCompressed(true)
    end,


    _doDownloadDanmakuRawData = function(self, conn, videoID, outDatas)
        self:__initNetworkConnection(conn)
        return string.format(_BILI_FMT_URL_DAMAKU, videoID)
    end,


    _doGetVideoDuration = function(self, conn, videoID, outDurations)
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
            table.insert(outDurations, duration)
        end

        local url = string.format(_BILI_FMT_URL_VIDEO_INFO, videoID)
        self:__initNetworkConnection(conn)
        conn:receiveLater(url, __parseDuration, outDurations)
    end,
}

classlite.declareClass(BiliBiliDanmakuSourcePlugin, pluginbase._PatternBasedDanmakuSourcePlugin)


return
{
    BiliBiliDanmakuSourcePlugin     = BiliBiliDanmakuSourcePlugin,
}