local base = require('src/base')            --= base base
local utf8 = require('src/utf8')            --= utf8 utf8
local utils = require('src/utils')          --= utils utils
local poscalc = require('src/poscalc')      --= poscalc poscalc
local asswriter = require('src/asswriter')  --= asswriter asswriter


local Danmaku =
{
    text = nil,         -- 评论内容，以 utf8 编码
    startTime = nil,    -- 弹幕起始时间，单位 ms
    lifeTime = nil,     -- 弹幕存活时间，单位 ms
    fontSize = nil,     -- 字体大小，单位 pt
    fontColor = nil,    -- 字体颜色字符串，格式 BBGGRR

    new = function(obj)
        obj = base.allocateInstance(obj)
        return obj
    end,
}

base.declareClass(Danmaku)


local DanmakuParseContext =
{
    pool = nil,
    screenWidth = nil,
    screenHeight = nil,
    bottomReserved = nil,

    defaultFontSize = nil,
    defaultFontName = nil,
    defaultFontColor = nil,

    defaultSRTFontSize = nil,
    defaultSRTFontName = nil,
    defaultSRTFontColor = nil,


    new = function(obj)
        obj = base.allocateInstance(obj)
        obj.pool =
        {
            [asswriter.LAYER_MOVING_L2R]    = {},
            [asswriter.LAYER_MOVING_R2L]    = {},
            [asswriter.LAYER_STATIC_TOP]    = {},
            [asswriter.LAYER_STATIC_BOTTOM] = {},
            [asswriter.LAYER_ADVANCED]      = {},
            [asswriter.LAYER_SUBTITLE]      = {},
        }
        return obj
    end,


    dispose = function(self)
        if self.pool
        then
            for k in next(self.pool)
            do
                base.clearTable(self.pool[k])
            end

            base.clearTable(self.pool)
        end
    end,
}

base.declareClass(DanmakuParseContext)



local _NEWLINE_STR          = "\n"
local _NEWLINE_CODEPOINT    = string.byte(_NEWLINE_STR)

local function __measureDanmakuText(text, fontSize)
    local lineCount = 1
    local lineCharCount = 0
    local maxLineCharCount = 0
    for _, codePoint in utf8.iterateUTF8CodePoints(text)
    do
        if codePoint == _NEWLINE_CODEPOINT
        then
            lineCount = lineCount + 1
            maxLineCharCount = math.max(maxLineCharCount, lineCharCount)
            lineCharCount = 0
        end

        lineCharCount = lineCharCount + 1
    end

    -- 可能没有回车符
    maxLineCharCount = math.max(maxLineCharCount, lineCharCount)

    -- 字体高度系数一般是 1.0 左右
    -- 字体宽度系数一般是 1.0 ~ 0.6 左右
    -- 就以最坏的情况来算吧
    local width = maxLineCharCount * fontSize
    local height = lineCount * fontSize
    return width, height
end




local _LIFETIME_STATIC          = 5000
local _LIFETIME_MOVING          = 8000

local _PATTERN_BILI_POS         = "([%d%.]+),(%d+),(%d+),(%d+),[^>]+,[^>]+,[^>]+,[^>]+"
local _PATTERN_BILI_DANMAKU     = "<d%s+p=\"" .. _PATTERN_BILI_POS .. "\">([^<]+)</d>"

local _BILI_FACTOR_TIME_STAMP   = 1000
local _BILI_FACTOR_FONT_SIZE    = 25

local _BILI_POS_MOVING_L2R      = 6
local _BILI_POS_MOVING_R2L      = 1
local _BILI_POS_STATIC_TOP      = 5
local _BILI_POS_STATIC_BOTTOM   = 4
local _BILI_POS_ADVANCED        = 7

local _BILI_POS_TO_LAYER_MAP    =
{
    [_BILI_POS_MOVING_L2R]      = asswriter.LAYER_MOVING_L2R,
    [_BILI_POS_MOVING_R2L]      = asswriter.LAYER_MOVING_R2L,
    [_BILI_POS_STATIC_TOP]      = asswriter.LAYER_STATIC_TOP,
    [_BILI_POS_STATIC_BOTTOM]   = asswriter.LAYER_STATIC_BOTTOM,
}

local _BILI_LIFETIME_MAP        =
{
    [_BILI_POS_MOVING_L2R]      = _LIFETIME_MOVING,
    [_BILI_POS_MOVING_R2L]      = _LIFETIME_MOVING,
    [_BILI_POS_STATIC_TOP]      = _LIFETIME_STATIC,
    [_BILI_POS_STATIC_BOTTOM]   = _LIFETIME_STATIC,
}


local function parseBiliBiliRawData(rawData, ctx)
    local builder = nil

    for start, typeStr, size, color, text in rawData:gmatch(_PATTERN_BILI_DANMAKU)
    do
        local biliPos = tonumber(typeStr) or _BILI_POS_MOVING_L2R
        local layer = _BILI_POS_TO_LAYER_MAP[biliPos]

        if biliPos == _BILI_POS_ADVANCED
        then
            --TODO 神弹幕
        else
            local d = Danmaku:new()
            d.text = utils.unescapeXMLText(text)
            d.startTime = tonumber(start) * _BILI_FACTOR_TIME_STAMP
            d.lifeTime = _BILI_LIFETIME_MAP[biliPos]

            local fontSize = tonumber(size) * ctx.defaultFontSize / _BILI_FACTOR_FONT_SIZE
            local isNotSameAsDefault = (fontSize ~= ctx.defaultFontSize)
            d.fontSize = isNotSameAsDefault and fontSize or nil

            local fontColor = tonumber(color)
            isNotSameAsDefault = (fontColor ~= ctx.defaultFontColor)
            d.fontColor = isNotSameAsDefault
                          and utils.convertRGBHexToBGRString(fontColor)
                          or nil

            table.insert(ctx.pool[layer], d)
        end
    end
end



local _SRT_SUBTITLE_IDX_START   = 1
local _SRT_SEP_SUBTITLE         = ""
local _SRT_PATTERN_SUBTITLE_IDX = "^(%d+)$"
local _SRT_PATTERN_TIME         = "(%d+):(%d+):(%d+),(%d+)"
local _SRT_PATTERN_TIME_SPAN    = _SRT_PATTERN_TIME .. " %-%-%> " .. _SRT_PATTERN_TIME

local function __readLine(f)
    return f:read("*l")
end


local __readSubtitleIdxOrEmptyLines = nil
local __readSubtitleTimeSpan        = nil
local __readSubtitleContent         = nil


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

            d = Danmaku:new()
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

            -- 字幕一般是不分行的
            text = text .. _NEWLINE_STR .. line
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


local function parseDanDanPlayRawData(rawData, ctx)
end



local function __compareDanmakuByStartTime(d1, d2)
    return d1.startTime < d2.startTime
end

local function __sortDanmakuByStartTimeAsc(danmakuList)
    table.sort(danmakuList, __compareDanmakuByStartTime)
end


local function __writeMovingL2RPos(builder, d, w, y, ctx)
    builder:addMove(0, y, ctx.screenWidth + w, y)
end

local function __writeMovingR2LPos(builder, d, w, y, ctx)
    builder:addMove(ctx.screenWidth, y, -w, y)
end

local function __writeStaticTopPos(builder, d, w, y, ctx)
    builder:addTopCenterAlign()
    builder:addPos(ctx.screenWidth / 2, y)
end

local function __writeStaticBottomPos(builder, d, w, y, ctx)
    local stageH = ctx.screenHeight - ctx.bottomReserved
    y = stageH - y
    y = y - ctx.bottomReserved
    builder:addBottomCenterAlign()
    builder:addPos(ctx.screenWidth / 2, y)
end

local function __writeBottomSubtitlePos(builder, d, w, y, ctx)
    y = ctx.screenHeight - y
    builder:addBottomCenterAlign()
    builder:addPos(ctx.screenWidth / 2, y)
end


local function writeDanmakus(f, ctx)
    local stageW = ctx.screenWidth
    local screenH = math.max(ctx.screenWidth, 1)
    local stageH = math.max(screenH - ctx.bottomReserved, 1)

    local calculators =
    {
        [asswriter.LAYER_MOVING_L2R]    = poscalc.MovingPosCalculator:new(stageW, stageH),
        [asswriter.LAYER_MOVING_R2L]    = poscalc.MovingPosCalculator:new(stageW, stageH),
        [asswriter.LAYER_STATIC_TOP]    = poscalc.StaticPosCalculator:new(stageW, stageH),
        [asswriter.LAYER_STATIC_BOTTOM] = poscalc.StaticPosCalculator:new(stageW, stageH),
        [asswriter.LAYER_ADVANCED]      = nil,
        [asswriter.LAYER_SUBTITLE]      = poscalc.StaticPosCalculator:new(stageW, screenH),
    }

    local writePosFuncs =
    {
        [asswriter.LAYER_MOVING_L2R]    = __writeMovingL2RPos,
        [asswriter.LAYER_MOVING_R2L]    = __writeMovingR2LPos,
        [asswriter.LAYER_STATIC_TOP]    = __writeStaticTopPos,
        [asswriter.LAYER_STATIC_BOTTOM] = __writeStaticBottomPos,
        [asswriter.LAYER_ADVANCED]      = nil,
        [asswriter.LAYER_SUBTITLE]      = __writeBottomSubtitlePos,
    }


    asswriter.writeScriptInfo(f, ctx.screenWidth, ctx.screenHeight)
    asswriter.writeStyle(f, ctx.defaultFontName, ctx.defaultFontSize)
    asswriter.writeEvents(f)

    local builder = asswriter.DialogueBuilder:new()
    for layer, calc in pairs(calculators)
    do
        local writePosFunc = writePosFuncs[layer]
        local danmakuList = ctx.pool[layer]
        __sortDanmakuByStartTimeAsc(danmakuList, __compareDanmakuByStartTime)

        for _, d in ipairs(danmakuList)
        do
            local fontSize = d.fontSize or ctx.defaultFontSize
            local w, h = __measureDanmakuText(d.text, fontSize)
            local y = calc:calculate(w, h, d.startTime, d.lifeTime)

            builder:startDialogue(layer, d.startTime, d.startTime + d.lifeTime)
            builder:startStyle()
            builder:addFontColor(d.fontColor)
            builder:addFontSize(d.fontSize)

            writePosFunc(builder, d, w, y, ctx)

            builder:endStyle()
            builder:addText(d.text)
            builder:endDialogue()
            builder:flush(f)
        end

        calc:dispose()
        calculators[layer] = nil
        writePosFuncs[layer] = nil
    end

    calculators = nil
    writePosFuncs = nil
    builder = nil
    collectgarbage()

    f:close()
end


local MockFile =
{
    _mContent = nil,

    new = function(obj)
        obj = base.allocateInstance(obj)
        obj._mContent = {}
        return obj
    end,

    write = function(self, ...)
        io.stdout:write(...)
    end,

    close = function(self)
--        self._mContent = table.concat(self._mContent)
    end,

    getContent = function(self)
        return self._mContent
    end,
}

base.declareClass(MockFile)


--local f = io.open("/home/fish47/111/Biligrab/【MV】 LiSA「Rising Hope」完整版【720P】/1 - 【MV】 LiSA「Rising Hope」完整版【720P】.xml")
--local ctx = DanmakuParseContext:new()
--ctx.screenWidth = 1280
--ctx.screenHeight = 720
--ctx.bottomReserved = 20
--ctx.defaultLifeTime = 8000
--ctx.defaultFontSize = 34
--ctx.defaultFontName = "Monospaced"
--ctx.defaultFontColor = 0xffffff
--local mockFile = MockFile:new()
--parseBiliBiliRawData(f:read("*a"), ctx)
--writeDanmakus(mockFile, ctx)
--print(mockFile:getContent())


return
{
    DanmakuParseContext         = DanmakuParseContext,

    parseBiliBiliRawData        = parseBiliBiliRawData,
    parseDanDanPlayRawData      = parseDanDanPlayRawData,
    parseSRTFile                = parseSRTFile,
    writeDanmakus               = writeDanmakus,
}