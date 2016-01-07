local utils     = require("src/base/utils")
local constants = require("src/base/constants")


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


__readSubtitleIdxOrEmptyLines = function(cfg, pool,
                                         f, line,
                                         source, subIdx)
    if not line
    then
        -- 允许以空行结尾，但不允许只有空行的文件
        return subIdx > _SRT_SUBTITLE_IDX_START
    end

    if line == _SRT_SEP_SUBTITLE
    then
        -- 继续读空行
        line = __readLine(f)
        return __readSubtitleIdxOrEmptyLines(cfg, pool,
                                             f, line,
                                             source, subIdx)
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
            return __readSubtitleTimeSpan(cfg, pool,
                                          f, line,
                                          source, nextIdx)
        end
    end
end


__readSubtitleTimeSpan = function(cfg, pool, f, line, source, subIdx)
    if not line
    then
        -- 只有字幕编号没有时间段
        return false
    else
        local h1, m1, s1, ms1,
              h2, m2, s2, ms2 = line:match(_SRT_PATTERN_TIME_SPAN)

        if not h1
        then
            return false
        end

        local startTime = utils.convertHHMMSSToTime(h1, m1, s1, ms1)
        local endTime = utils.convertHHMMSSToTime(h2, m2, s2, ms2)
        local lifeTime = math.max(endTime - startTime, 0)

        line = __readLine(f)
        return __readSubtitleContent(cfg, pool, f, line,
                                     source, subIdx,
                                     startTime, lifeTime)
    end
end


__readSubtitleContent = function(cfg, pool, f, line,
                                 source, subIdx,
                                 startTime, lifeTime)
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
        pool:addDanmaku(startTime, lifeTime,
                        color, size,
                        source, subIdx,
                        text)

        line = hasMoreLine and __readLine(f) or nil
        return __readSubtitleIdxOrEmptyLines(cfg, pool,
                                             f, line,
                                             source, subIdx)
    end
end


local function parseSRTFile(cfg, pool, f, source)
    local line = __readLine(f)
    local startIdx = _SRT_SUBTITLE_IDX_START
    return __readSubtitleIdxOrEmptyLines(cfg, pool,
                                         f, line,
                                         source, startIdx)
end


return
{
    parseSRTFile    = parseSRTFile,
}