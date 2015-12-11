local utils     = require("src/base/utils")
local constants = require("src/base/constants")


local _SRT_SUBTITLE_IDX_START       = 0
local _SRT_SEP_SUBTITLE             = constants.STR_EMPTY
local _SRT_PATTERN_SUBTITLE_IDX     = "^(%d+)$"
local _SRT_PATTERN_TIME             = "(%d+):(%d+):(%d+),(%d+)"
local _SRT_PATTERN_TIME_SPAN        = _SRT_PATTERN_TIME .. " %-%-%> " .. _SRT_PATTERN_TIME
local _STR_PATTERN_DANMAKU_ID       = "_srt_%s_%d"

local __readSubtitleIdxOrEmptyLines = nil
local __readSubtitleTimeSpan        = nil
local __readSubtitleContent         = nil


local function __readLine(f)
    return f:read(constants.READ_MODE_LINE_NO_EOL)
end


__readSubtitleIdxOrEmptyLines = function(cfg, pool, f, line, subID, subIdx)
    if not line
    then
        -- 允许以空行结尾，但不允许只有空行的文件
        return subIdx > _SRT_SUBTITLE_IDX_START
    end

    if line == _SRT_SEP_SUBTITLE
    then
        -- 继续读空行
        line = __readLine(f)
        return __readSubtitleIdxOrEmptyLines(cfg, pool, f, line, subID, subIdx)
    else
        local nextIdx = line:match(_SRT_PATTERN_SUBTITLE_IDX)
        if not nextIdx
        then
            -- 没有起始的字幕编号
            return false
        else
            nextIdx = tonumber(nextIdx)
            if subIdx + 1 ~= nextIdx
            then
                --TODO 字幕编号不连续，需要直接返回？
            end

            line = __readLine(f)
            return __readSubtitleTimeSpan(cfg, pool, f, line, subID, nextIdx)
        end
    end
end


__readSubtitleTimeSpan = function(cfg, pool, f, line, subID, subIdx)
    if not line
    then
        -- 只有字幕编号没有时间段
        return false
    else
        local h1, m1, s1, ms1, h2, m2, s2, ms2 = line:match(_SRT_PATTERN_TIME_SPAN)
        if not h1
        then
            return false
        end

        local startTime = utils.convertHHMMSSToTime(h1, m1, s1, ms1)
        local endTime = utils.convertHHMMSSToTime(h2, m2, s2, ms2)
        local lifeTime = math.max(endTime - startTime, 0)

        line = __readLine(f)
        return __readSubtitleContent(cfg, pool, f, line, subID, subIdx, startTime, lifeTime)
    end
end


__readSubtitleContent = function(cfg, pool, f, line, subID, subIdx, startTime, lifeTime)
    if not line
    then
        return false
    else
        local text = line
        local hasMoreLine = false
        while true
        do
            line = __readLine(f)
            hasMoreLine = line ~= nil
            if not line or line == _SRT_SEP_SUBTITLE
            then
                break
            end

            -- 有些字幕会换行
            text = text .. constants.STR_NEWLINE .. line
        end


        local color = cfg.subtitleFontColor
        local size = cfg.subtitleFontSize
        local danmakuID = string.format(_STR_PATTERN_DANMAKU_ID, subID, subIdx)
        pool:addDanmaku(startTime, lifeTime, color, size, danmakuID, text)

        line = hasMoreLine and __readLine(f) or nil
        return __readSubtitleIdxOrEmptyLines(cfg, pool, f, line, subID, subIdx)
    end
end


local function parseSRTFile(cfg, pool, f, subtitleID)
    local line = __readLine(f)
    local startIdx = _SRT_SUBTITLE_IDX_START
    return __readSubtitleIdxOrEmptyLines(cfg, pool, f, line, subtitleID, startIdx)
end


return
{
    parseSRTFile    = parseSRTFile,
}