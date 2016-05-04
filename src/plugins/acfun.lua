local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmakupool   = require("src/core/danmakupool")
local pluginbase    = require("src/plugins/pluginbase")


local _ACFUN_PLUGIN_NAME                = "Acfun"

local _ACFUN_DEFAULT_DURATION           = 0
local _ACFUN_FACTOR_TIME_STAMP          = 1000

local _ACFUN_DEFAULT_VIDEO_INDEX        = 1

local _ACFUN_PATTERN_VID                = '<a%s*data-vid="([%d]+)"'
local _ACFUN_PATTERN_DURATION           = '"time"%s*:%s*([%d]+)%s*,'
local _ACFUN_PATTERN_DANMAKU_INFO_KEY   = '"c"%s*:%s*'
local _ACFUN_PATTERN_DANMAKU_TEXT_KEY   = '"m"%s*:%s*'
local _ACFUN_PATTERN_DANMAKU_INFO_VALUE = "([%d%.]+),"     -- 出现时间
                                          .. "(%d+),"      -- 颜色
                                          .. "(%d+),"      -- 弹幕类型
                                          .. "(%d+),"      -- 字体大小
                                          .. "[^,]+,"      -- 用户 ID ？
                                          .. "(%d+),"      -- 弹幕 ID ？
                                          .. "[^,]+"        -- hash ？

local _ACFUN_PATTERN_TITLE_1P           = "<h2>(.-)</h2>"
local _ACFUN_PATTERN_VID_AND_TITLE      = '<a%s+data%-vid="(%d+)".->(.-)</a>'
local _ACFUN_PATTERN_SANITIZE_TITLE     = "<i.-</i>"

local _ACFUN_PATTERN_SEARCH_URL         = "http://www.acfun.tv/v/ac([%d_]+)"
local _ACFUN_PATTERN_SEARCH_ACID        = "acfun:ac([%d_]+)"
local _ACFUN_PATTERN_SEARCH_VID         = "acfun:vid(%d+)"
local _ACFUN_PATTERN_SEARCH_PART_INDEX  = "^%d*_(%d+)$"

local _ACFUN_FMT_URL_VIDEO              = "http://www.acfun.tv/v/ac%s"
local _ACFUN_FMT_URL_DANMAKU            = "http://danmu.aixifan.com/V2/%s"
local _ACFUN_FMT_URL_VIDEO_INFO         = "http://www.acfun.tv/video/getVideo.aspx?id=%s"
local _ACFUN_FMT_SEARCH_VID_TITLE       = "vid%s"


local _ACFUN_POS_TO_LAYER_MAP   =
{
    [1] = danmakupool.LAYER_MOVING_R2L,
    [2] = danmakupool.LAYER_MOVING_R2L,
    [4] = danmakupool.LAYER_STATIC_TOP,
    [5] = danmakupool.LAYER_STATIC_BOTTOM,
}


local AcfunDanmakuSourcePlugin =
{
    __mVideoTitles      = classlite.declareTableField(),


    getName = function(self)
        return _ACFUN_PLUGIN_NAME
    end,

    search = function(self, input, result)
        local vid = input:match(_ACFUN_PATTERN_SEARCH_VID)
        if vid
        then
            result.isSplited = false
            result.preferredIDIndex = _ACFUN_DEFAULT_DURATION
            table.insert(result.videoIDs, vid)
            table.insert(result.videoTitles, string.format(_ACFUN_FMT_SEARCH_VID_TITLE, vid))
        else
            local acid = input:match(_ACFUN_PATTERN_SEARCH_URL)
            acid = acid or input:match(_ACFUN_PATTERN_SEARCH_ACID)
            if not acid
            then
                return false
            end

            local conn = self._mApplication:getNetworkConnection()
            conn:clearHeaders()
            conn:addHeader(pluginbase._HEADER_USER_AGENT)

            local url = string.format(_ACFUN_FMT_URL_VIDEO, acid)
            local data = conn:receive(url)
            if not data
            then
                return false
            end


            local partCount = 0
            local titles = utils.clearTable(self.__mVideoTitles)
            for vid, title in data:gmatch(_ACFUN_PATTERN_VID_AND_TITLE)
            do
                title = title:gsub(_ACFUN_PATTERN_SANITIZE_TITLE, constants.STR_EMPTY)
                title = utils.unescapeXMLString(title)
                partCount = partCount + 1
                table.insert(titles, title)
                table.insert(result.videoIDs, vid)
            end

            if partCount <= 0
            then
                return false
            elseif partCount == 1
            then
                local title = data:match(_ACFUN_PATTERN_TITLE_1P)
                if not title
                then
                    return false
                end

                title = utils.unescapeXMLString(title)
                table.insert(result.videoTitles, title)
            else
                utils.appendArrayElements(result.videoTitles, titles)
            end

            local partIdx = acid:match(_ACFUN_PATTERN_SEARCH_PART_INDEX)
            partIdx = partIdx and tonumber(partIdx)
            result.isSplited = partCount > 1
            result.preferredIDIndex = partIdx or _ACFUN_DEFAULT_VIDEO_INDEX
        end

        result.videoTitleColumnCount = 1
        return true
    end,


    _startExtractDanmakus = function(self, rawData)
        -- 用闭包函数模仿 string.gmatch() 的行为
        local startIdx = 1
        local ret = function()
            local findIdx = startIdx
            local _, endIdx1 = rawData:find(_ACFUN_PATTERN_DANMAKU_INFO_KEY, findIdx, false)
            if not endIdx1
            then
                return
            end

            findIdx = endIdx1 + 1
            local posText, endIdx2 = utils.findJSONString(rawData, findIdx)
            local start, color, layer, size, id = posText:match(_ACFUN_PATTERN_DANMAKU_INFO_VALUE)
            if not endIdx2
            then
                return
            end

            findIdx = endIdx2 + 1
            local _, endIdx3 = rawData:find(_ACFUN_PATTERN_DANMAKU_TEXT_KEY, findIdx, false)
            if not endIdx3
            then
                return
            end

            findIdx = endIdx3 + 1
            local text, nextFindIdx = utils.findJSONString(rawData, findIdx)
            if not nextFindIdx
            then
                return
            end

            startIdx = nextFindIdx
            return text, start, color, layer, size, id
        end
        return ret
    end,

    _extractDanmaku = function(self, iterFunc, cfg, danmakuData)
        local text, startTime, fontColor, layer, fontSize, danmakuID = iterFunc()
        if not text
        then
            return
        end

        danmakuData.startTime = tonumber(startTime * _ACFUN_FACTOR_TIME_STAMP)
        danmakuData.fontSize = tonumber(fontSize)
        danmakuData.fontColor = tonumber(fontColor)
        danmakuData.danmakuID = tonumber(danmakuID)
        danmakuData.danmakuText = text
        return _ACFUN_POS_TO_LAYER_MAP[tonumber(layer)] or danmakupool.LAYER_SKIPPED
    end,

    __initNetworkConnection = function(self, conn)
        conn:clearHeaders()
        conn:addHeader(pluginbase._HEADER_USER_AGENT)
        conn:setCompressed(true)
    end,


    _doDownloadDanmakuRawData = function(self, conn, videoID, outDatas)
        self:__initNetworkConnection(conn)
        return string.format(_ACFUN_FMT_URL_DANMAKU, videoID)
    end,


    _doGetVideoDuration = function(self, conn, videoID, outDurations)
        local function __parseDuration(data, outDurations)
            local duration = nil
            if types.isString(data)
            then
                local seconds = data:match(_ACFUN_PATTERN_DURATION)
                duration = seconds and utils.convertHHMMSSToTime(0, 0, tonumber(seconds), 0)
            end
            duration = duration or _ACFUN_DEFAULT_DURATION
            table.insert(outDurations, duration)
        end

        local url = string.format(_ACFUN_FMT_URL_VIDEO_INFO, videoID)
        self:__initNetworkConnection(conn)
        conn:receiveLater(url, __parseDuration, outDurations)
    end,
}

classlite.declareClass(AcfunDanmakuSourcePlugin, pluginbase._PatternBasedDanmakuSourcePlugin)


return
{
    AcfunDanmakuSourcePlugin    = AcfunDanmakuSourcePlugin,
}