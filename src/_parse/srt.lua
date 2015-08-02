local _base = require('src/_parse/_base')
local utils = require('src/utils')          --= utils utils
local asswriter = require('src/asswriter')  --= asswriter asswriter


local _SRT_SUBTITLE_IDX_START   = 1
local _SRT_SEP_SUBTITLE         = ""
local _SRT_PATTERN_SUBTITLE_IDX = "^(%d+)$"
local _SRT_PATTERN_TIME         = "(%d+):(%d+):(%d+),(%d+)"
local _SRT_PATTERN_TIME_SPAN    = _SRT_PATTERN_TIME .. " %-%-%> " .. _SRT_PATTERN_TIME

local __readSubtitleIdxOrEmptyLines = nil
local __readSubtitleTimeSpan        = nil
local __readSubtitleContent         = nil


local function __readLine(f)
    return f:read("*l")
end


__readSubtitleIdxOrEmptyLines = function(f, line, subIdx, d, pool, ctx)
    if not line
    then
        return #pool > 0
    end

    if line == _SRT_SEP_SUBTITLE
    then
        -- 继续读空行
        line = __readLine(f)
        return __readSubtitleIdxOrEmptyLines(f, line, subIdx, d, pool, ctx)
    else
        local nextIdx = line:match(_SRT_PATTERN_SUBTITLE_IDX)
        if not nextIdx
        then
            -- 没有起始的字幕编号
            return false
        else
            if subIdx + 1 ~= nextIdx
            then
                --TODO 字幕编号不连续，需要直接返回？
            end

            d = _base._Danmaku:new()
            line = __readLine(f)
            return __readSubtitleTimeSpan(f, line, nextIdx, d, pool, ctx)
        end
    end
end


__readSubtitleTimeSpan = function(f, line, subIdx, d, pool, ctx)
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
        d.startTime = startTime
        d.lifeTime = lifeTime

        return __readSubtitleContent(f, __readLine(f), subIdx, d, pool, ctx)
    end
end


__readSubtitleContent = function(f, line, subIdx, d, pool, ctx)
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
            text = text .. _base._NEWLINE_STR .. line
        end

        d.fontColor = ctx.defaultSRTFontColor
        d.fontSize = ctx.defaultSRTFontSize
        d.text = text
        table.insert(pool, d)

        line = hasMoreLine and __readLine(f) or nil
        return __readSubtitleIdxOrEmptyLines(f, line, subIdx, nil, pool, ctx)
    end
end


local function parseSRTFile(f, ctx)
    local line = __readLine(f)
    local startIdx = _SRT_SUBTITLE_IDX_START
    local pool = ctx.pool[asswriter.LAYER_SUBTITLE]
    local succeed = __readSubtitleIdxOrEmptyLines(f, line, startIdx, nil, pool, ctx)
    return succeed
end


return
{
    parseSRTFile    = parseSRTFile,
}