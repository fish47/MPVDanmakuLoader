local pluginbase    = require("src/plugins/pluginbase")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")
local danmakupool   = require("src/core/danmakupool")


local _SRT_PLUGIN_NAME              = "SRT"
local _SRT_SUBTITLE_IDX_START       = 0
local _SRT_SEP_SUBTITLE             = constants.STR_EMPTY
local _SRT_PATTERN_STRIP_CR         = "^\r*(.-)\r*$"
local _SRT_PATTERN_SUBTITLE_IDX     = "^(%d+)$"
local _SRT_PATTERN_TIME             = "(%d+):(%d+):(%d+),(%d+)"
local _SRT_PATTERN_TIME_SPAN        = _SRT_PATTERN_TIME
                                      .. " %-%-%> "
                                      .. _SRT_PATTERN_TIME

local __readSubtitleIdxOrEmptyLines = nil
local __readSubtitleTimeSpan        = nil
local __readSubtitleContent         = nil
local __readLine                    = nil


__readLine = function(f)
    local line = f:read(constants.READ_MODE_LINE_NO_EOL)
    return line and line:match(_SRT_PATTERN_STRIP_CR)
end


__readSubtitleIdxOrEmptyLines = function(cfg, p, f, line, src, idx, offset, danmakuData)
    if not line
    then
        -- 允许以空行结尾，但不允许只有空行的文件
        return idx > _SRT_SUBTITLE_IDX_START
    end

    if line == _SRT_SEP_SUBTITLE
    then
        -- 继续读空行
        line = __readLine(f)
        return __readSubtitleIdxOrEmptyLines(cfg, p, f, line, src, idx, offset, danmakuData)
    else
        local nextIdx = line:match(_SRT_PATTERN_SUBTITLE_IDX)
        if not nextIdx
        then
            -- 没有起始的字幕编号
            return false
        else
            -- 某些字幕文件时间段不是递增的
            nextIdx = tonumber(nextIdx)
            line = __readLine(f)
            return __readSubtitleTimeSpan(cfg, p, f, line, src, nextIdx, offset, danmakuData)
        end
    end
end


__readSubtitleTimeSpan = function(cfg, p, f, line, src, idx, offset, danmakuData)
    local function __doConvert(h, m, s, ms)
        h = tonumber(h)
        m = tonumber(m)
        s = tonumber(s)
        ms = tonumber(ms)
        return utils.convertHHMMSSToTime(h, m, s, ms)
    end

    if not line
    then
        -- 只有字幕编号没有时间段
        return false
    end

    local h1, m1, s1, ms1,
          h2, m2, s2, ms2 = line:match(_SRT_PATTERN_TIME_SPAN)

    if not h1
    then
        return false
    end

    local start = __doConvert(h1, m1, s1, ms1)
    local endTime = __doConvert(h2, m2, s2, ms2)
    local life = math.max(endTime - start, 0)
    line = __readLine(f)
    return __readSubtitleContent(cfg, p, f, line, src, idx, start, life, offset, danmakuData)
end


__readSubtitleContent = function(cfg, p, f, line, src, idx, start, life, offset, danmakuData)
    if not line
    then
        return false
    end

    local text = line
    local hasMoreLine = false
    while true
    do
        line = __readLine(f)
        hasMoreLine = types.isString(line)
        if not line or line == _SRT_SEP_SUBTITLE
        then
            break
        end

        -- 有些字幕会换行
        text = text .. constants.STR_NEWLINE .. line
    end

    danmakuData.startTime = start + offset
    danmakuData.lifeTime = life
    danmakuData.fontColor = cfg.subtitleFontColor
    danmakuData.fontSize = cfg.subtitleFontSize
    danmakuData.sourceID = src
    danmakuData.danmakuID = tonumber(idx)
    danmakuData.danmakuText = text
    p:addDanmaku(danmakuData)

    line = hasMoreLine and __readLine(f)
    return __readSubtitleIdxOrEmptyLines(cfg, p, f, line, src, idx, offset, danmakuData)
end


local function _parseSRTFile(cfg, pool, file, srcID, offset, danmakuData)
    local line = __readLine(file)
    local idx = _SRT_SUBTITLE_IDX_START
    return __readSubtitleIdxOrEmptyLines(cfg, pool, file, line, srcID, idx, offset, danmakuData)
end


local SRTDanmakuSourcePlugin =
{
    _mDanmakuData   = classlite.declareClassField(danmaku.DanmakuData),


    getName = function(self)
        return _SRT_PLUGIN_NAME
    end,

    parseFile = function(self, filePath, sourceID, timeOffset)
        local app = self._mApplication
        local file = app:readUTF8File(filePath)
        if types.isOpenedFile(file)
        then
            local cfg = app:getConfiguration()
            local pools = app:getDanmakuPools()
            local pool = pools:getDanmakuPoolByLayer(danmakupool.LAYER_SUBTITLE)
            local danmakuData = self._mDanmakuData
            _parseSRTFile(cfg, pool, file, sourceID, timeOffset, danmakuData)
            app:closeFile(file)
        end
    end,
}

classlite.declareClass(SRTDanmakuSourcePlugin, pluginbase.IDanmakuSourcePlugin)


return
{
    _parseSRTFile           = _parseSRTFile,
    SRTDanmakuSourcePlugin  = SRTDanmakuSourcePlugin,
}