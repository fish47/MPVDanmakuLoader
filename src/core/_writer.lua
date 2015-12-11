local _ass      = require("src/core/_ass")
local _poscalc  = require("src/core/_poscalc")
local utf8      = require("src/base/utf8")
local constants = require("src/base/constants")


local function _measureDanmakuText(text, fontSize)
    local lineCount = 1
    local lineCharCount = 0
    local maxLineCharCount = 0
    for _, codePoint in utf8.iterateUTF8CodePoints(text)
    do
        if codePoint == constants.CODEPOINT_NEWLINE
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


local function __writeMovingL2RPos(cfg, screenW, screenH, b, w, y)
    b:addMove(0, y, screenW + w, y)
end

local function __writeMovingR2LPos(cfg, screenW, screenH, b, w, y)
    b:addMove(screenW, y, -w, y)
end

local function __writeStaticTopPos(cfg, screenW, screenH, b, w, y)
    b:addTopCenterAlign()
    b:addPos(screenW / 2, y)
end

local function __writeStaticBottomPos(cfg, screenW, screenH, b, w, y)
    local stageH = screenH - cfg.bottomReserved
    y = stageH - y
    y = y - cfg.bottomReserved
    b:addBottomCenterAlign()
    b:addPos(screenW / 2, y)
end

local function __writeBottomSubtitlePos(cfg, screenW, screenH, b, w, y)
    y = screenH - y
    b:addBottomCenterAlign()
    b:addPos(screenW / 2, y)
end


local function writeDanmakus(pools, cfg, screenW, screenH, f)
    local stageW = screenW
    local stageH = math.max(screenH - cfg.bottomReserved, 1)

    local calculators =
    {
        [_ass.LAYER_MOVING_L2R]     = _poscalc.Moving_poscalculator:new(stageW, stageH),
        [_ass.LAYER_MOVING_R2L]     = _poscalc.Moving_poscalculator:new(stageW, stageH),
        [_ass.LAYER_STATIC_TOP]     = _poscalc.Static_poscalculator:new(stageW, stageH),
        [_ass.LAYER_STATIC_BOTTOM]  = _poscalc.Static_poscalculator:new(stageW, stageH),
        [_ass.LAYER_ADVANCED]       = nil,
        [_ass.LAYER_SUBTITLE]       = _poscalc.Static_poscalculator:new(stageW, screenH),
    }

    local writePosFuncs =
    {
        [_ass.LAYER_MOVING_L2R]     = __writeMovingL2RPos,
        [_ass.LAYER_MOVING_R2L]     = __writeMovingR2LPos,
        [_ass.LAYER_STATIC_TOP]     = __writeStaticTopPos,
        [_ass.LAYER_STATIC_BOTTOM]  = __writeStaticBottomPos,
        [_ass.LAYER_ADVANCED]       = nil,
        [_ass.LAYER_SUBTITLE]       = __writeBottomSubtitlePos,
    }


    _ass.writeScriptInfo(f, screenW, screenH)
    _ass.writeStyle(f, cfg.danmakuFontName, cfg.danmakuFontSize)
    _ass.writeEvents(f)

    local builder = _ass.DialogueBuilder:new()
    builder:setDefaultFontColor(cfg.danmakuFontColor)
    builder:setDefaultFontSize(cfg.danmakuFontSize)

    for layer, calc in pairs(calculators)
    do
        local writePosFunc = writePosFuncs[layer]
        local pool = cfg.pools:getDanmakuPoolByLayer(layer)
        pool:sortDanmakusByStartTime()

        local prevDanmakuID = nil
        local danmakuCount = pool:getDanmakuCount()
        for i = 1, danmakuCount
        do
            local start, life, color, size, danmakuID, text = pool:getSortedDanmakuAt(i)
            if not prevDanmakuID or prevDanmakuID ~= danmakuID
            then
                prevDanmakuID = danmakuID

                local w, h = _measureDanmakuText(text, size)
                local y = calc:calculate(w, h, start, life)

                builder:startDialogue(layer, start, start + life)
                builder:startStyle()
                builder:addFontColor(color)
                builder:addFontSize(size)
                writePosFunc(cfg, builder, screenW, screenH, w, y)
                builder:endStyle()
                builder:addText(text)
                builder:endDialogue()
                builder:flush(f)
            end
        end

        calc:dispose()
        calculators[layer] = nil
        writePosFuncs[layer] = nil
    end

    builder:dispose()
end


return
{
    writeDanmakus   = writeDanmakus,
}