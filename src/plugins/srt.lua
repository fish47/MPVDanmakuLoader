local pluginbase    = require("src/plugins/pluginbase")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")


local _SRT_PLUGIN_NAME              = "SRT"
local _SRT_SUBTITLE_IDX_START       = 0
local _SRT_SEP_SUBTITLE             = constants.STR_EMPTY
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
    return f:read(constants.READ_MODE_LINE_NO_EOL)
end


__readSubtitleIdxOrEmptyLines = function(cfg, p, f, line, src, idx, offset, tmpArray)
    if not line
    then
        -- 允许以空行结尾，但不允许只有空行的文件
        return idx > _SRT_SUBTITLE_IDX_START
    end

    if line == _SRT_SEP_SUBTITLE
    then
        -- 继续读空行
        line = __readLine(f)
        return __readSubtitleIdxOrEmptyLines(cfg, p, f, line, src, idx, offset, tmpArray)
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
            return __readSubtitleTimeSpan(cfg, p, f, line, src, nextIdx, offset, tmpArray)
        end
    end
end


__readSubtitleTimeSpan = function(cfg, p, f, line, src, idx, offset, tmpArray)
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

    local start = utils.convertHHMMSSToTime(h1, m1, s1, ms1)
    local endTime = utils.convertHHMMSSToTime(h2, m2, s2, ms2)
    local life = math.max(endTime - start, 0)
    line = __readLine(f)
    return __readSubtitleContent(cfg, p, f, line, src, idx, start, life, offset, tmpArray)
end


__readSubtitleContent = function(cfg, p, f, line, src, idx, start, life, offset, tmpArray)
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

    utils.clearTable(tmpArray)
    tmpArray[danmaku.DANMAKU_IDX_START_TIME]    = start + offset
    tmpArray[danmaku.DANMAKU_IDX_LIFE_TIME]     = life
    tmpArray[danmaku.DANMAKU_IDX_FONT_COLOR]    = cfg.subtitleFontColor
    tmpArray[danmaku.DANMAKU_IDX_FONT_SIZE]     = cfg.subtitleFontSize
    tmpArray[danmaku.DANMAKU_IDX_SOURCE_ID]     = src
    tmpArray[danmaku.DANMAKU_IDX_DANMAKU_ID]    = tostring(idx)
    tmpArray[danmaku.DANMAKU_IDX_TEXT]          = text
    p:addDanmaku(tmpArray)

    line = hasMoreLine and __readLine(f)
    return __readSubtitleIdxOrEmptyLines(cfg, p, f, line, src, idx, offset, tmpArray)
end


local function _parseSRTFile(cfg, pool, file, srcID, offset, tmpArray)
    local line = __readLine(file)
    local idx = _SRT_SUBTITLE_IDX_START
    tmpArray = types.isTable(tmpArray) and tmpArray or {}
    return __readSubtitleIdxOrEmptyLines(cfg, pool, file, line, srcID, idx, offset, tmpArray)
end


local SRTDanmakuSourcePlugin =
{
    _mTmpArray      = classlite.declareTableField(),

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
            local pool = pools:getDanmakuPoolByLayer(danmaku.LAYER_SUBTITLE)
            local tmpArray = utils.clearTable(self._mTmpArray)
            _parseSRTFile(cfg, pool, file, sourceID, timeOffset, tmpArray)
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