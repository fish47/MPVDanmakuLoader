local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmakupool   = require("src/core/danmakupool")
local pluginbase    = require("src/plugins/pluginbase")


local _DDP_PLUGIN_NAME              = "DanDanPlay"

local _DDP_FMT_URL_DANMAKU          = "http://acplay.net/api/v1/comment/%s"
local _DDP_FMT_URL_SEARCH           = "http://acplay.net/api/v1/searchall/%s"

local _DDP_PATTERN_VIDEO_TITLE      = '<Anime Title="(.-)"'
local _DDP_PATTERN_EPISODE_TITLE    = '<Episode Id="(%d+)" Title="(.-)"'
local _DDP_PATTERN_SEARCH_KEYWORD   = "ddp:%s*(.-)%s*"
local _DDP_PATTERN_COMMENT          = "<Comment"
                                      .. '%s+Time="([%d.]+)"'
                                      .. '%s+Mode="(%d+)"'
                                      .. '%s+Color="(%d+)"'
                                      .. '%s+Timestamp="%d+"'
                                      .. '%s+Pool="%d+"'
                                      .. '%s+UId="%-?[%d]+"'
                                      .. '%s+CId="(%d+)"'
                                      .. "%s*>"
                                      .. "([^<]+)"
                                      .. "</Comment>"


local _DDP_FACTOR_TIME_STAMP        = 1000

local _DDP_POS_TO_LAYER_MAP =
{
    [6] = danmakupool.LAYER_MOVING_L2R,
    [1] = danmakupool.LAYER_MOVING_R2L,
    [5] = danmakupool.LAYER_STATIC_TOP,
    [4] = danmakupool.LAYER_STATIC_BOTTOM,
}


local DanDanPlayDanmakuSourcePlugin =
{
    __mVideoIDs         = classlite.declareTableField(),
    __mVideoTitles      = classlite.declareTableField(),
    __mVideoSubtitles   = classlite.declareTableField(),
    __mCaptureIndexes1  = classlite.declareTableField(),
    __mCaptureIndexes2  = classlite.declareTableField(),


    getName = function(self)
        return _DDP_PLUGIN_NAME
    end,

    _startExtractDanmakus = function(self, rawData)
        return rawData:gmatch(_DDP_PATTERN_COMMENT)
    end,

    _extractDanmaku = function(self, iterFunc, cfg, danmakuData)
        local startTime, layer, fontColor, danmakuID, text = iterFunc()
        if not startTime
        then
            return
        end

        danmakuData.startTime = tonumber(startTime) * _DDP_FACTOR_TIME_STAMP
        danmakuData.fontSize = cfg.danmakuFontSize
        danmakuData.fontColor = tonumber(fontColor)
        danmakuData.danmakuID = tonumber(danmakuID)
        danmakuData.danmakuText = utils.unescapeXMLString(text)
        return _DDP_POS_TO_LAYER_MAP[tonumber(layer)] or danmakupool.LAYER_SKIPPED
    end,


    search = function(self, input, result)
        local function __captureIndexesAndStrings(data, pattern, indexes, table1, table2)
            -- 收集匹配的字符串
            for str1, str2 in data:gmatch(pattern)
            do
                utils.pushArrayElement(table1, str1)
                utils.pushArrayElement(table2, str2)
            end

            -- 收集匹配的字符串索引
            local findStartIndex = 1
            while true
            do
                local startIdx, endIdx = data:find(pattern, findStartIndex, false)
                if not startIdx
                then
                    break
                end

                table.insert(indexes, startIdx)
                findStartIndex = endIdx + 1
            end
        end


        local keyword = input:match(_DDP_PATTERN_SEARCH_KEYWORD)
        if not keyword
        then
            return false
        end

        local conn = self._mApplication:getNetworkConnection():resetParams()
        local url = string.format(_DDP_FMT_URL_SEARCH, utils.escapeURLString(keyword))
        local data = conn:receive(url)
        if types.isNilOrEmpty(data)
        then
            return false
        end

        local videoIDs = utils.clearTable(self.__mVideoIDs)
        local titles = utils.clearTable(self.__mVideoTitles)
        local subtitles = utils.clearTable(self.__mVideoSubtitles)
        local indexes1 = utils.clearTable(self.__mCaptureIndexes1)
        local indexes2 = utils.clearTable(self.__mCaptureIndexes2)

        -- 剧集标题
        __captureIndexesAndStrings(data, _DDP_PATTERN_VIDEO_TITLE, indexes1, titles)
        utils.forEachArrayElement(titles, utils.unescapeXMLString)

        -- 分集标题
        __captureIndexesAndStrings(data, _DDP_PATTERN_EPISODE_TITLE, indexes2, videoIDs, subtitles)
        utils.forEachArrayElement(subtitles, utils.unescapeXMLString)

        -- 剧集标题比分集标题出现得早，例如
        -- <Anime Title="刀剑神域" Type="1">
        --     <Episode Id="86920001" Title="第1话 剣の世界"/>
        --     <Episode Id="86920002" Title="第2话 ビーター"/>
        local subtitleIdx = 1
        for titleIdx, title in ipairs(titles)
        do
            local subtitleCaptureIdx = indexes2[subtitleIdx]
            local nextTitleCaptureIdx = #titles > 1 and indexes1[titleIdx + 1] or math.huge
            while subtitleCaptureIdx and subtitleCaptureIdx < nextTitleCaptureIdx
            do
                table.insert(result.videoTitles, title)
                table.insert(result.videoTitles, subtitles[subtitleIdx])
                subtitleIdx = subtitleIdx + 1
                subtitleCaptureIdx = indexes2[subtitleIdx]
            end
        end

        result.isSplited = false
        result.videoTitleColumnCount = 2
        result.preferredIDIndex = 1
        return true
    end,


    _doDownloadDanmakuRawData = function(self, conn, videoID, outDatas)
        conn:resetParams()
        conn:addHeader(pluginbase._HEADER_USER_AGENT)
        conn:addHeader(pluginbase._HEADER_ACCEPT_XML)
        return string.format(_DDP_FMT_URL_DANMAKU, videoID)
    end,
}

classlite.declareClass(DanDanPlayDanmakuSourcePlugin, pluginbase._PatternBasedDanmakuSourcePlugin)


return
{
    DanDanPlayDanmakuSourcePlugin   = DanDanPlayDanmakuSourcePlugin,
}