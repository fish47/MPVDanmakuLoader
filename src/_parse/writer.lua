local _base = require('src/_parse/_base')
local poscalc = require('src/poscalc')      --= poscalc poscalc
local asswriter = require('src/asswriter')  --= asswriter asswriter


local function __writeMovingL2RPos(ctx, builder, w, y)
    builder:addMove(0, y, ctx.screenWidth + w, y)
end

local function __writeMovingR2LPos(ctx, builder, w, y)
    builder:addMove(ctx.screenWidth, y, -w, y)
end

local function __writeStaticTopPos(ctx, builder, w, y)
    builder:addTopCenterAlign()
    builder:addPos(ctx.screenWidth / 2, y)
end

local function __writeStaticBottomPos(ctx, builder, w, y)
    local stageH = ctx.screenHeight - ctx.bottomReserved
    y = stageH - y
    y = y - ctx.bottomReserved
    builder:addBottomCenterAlign()
    builder:addPos(ctx.screenWidth / 2, y)
end

local function __writeBottomSubtitlePos(ctx, builder, w, y)
    y = ctx.screenHeight - y
    builder:addBottomCenterAlign()
    builder:addPos(ctx.screenWidth / 2, y)
end


local function writeDanmakus(ctx, f)
    local stageW = ctx.screenWidth
    local screenH = math.max(ctx.screenHeight, 1)
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
    builder:setDefaultFontColor(ctx.defaultFontColor)
    builder:setDefaultFontSize(ctx.defaultFontSize)

    for layer, calc in pairs(calculators)
    do
        local writePosFunc = writePosFuncs[layer]
        local pool = ctx.pools[layer]
        pool:sortDanmakusByStartTime()

        local prevDanmakuID = nil
        local danmakuCount = pool:getDanmakuCount()
        for i = 1, danmakuCount
        do
            local start, life, color, size, danmakuID, text = pool:getSortedDanmakuAt(i)
            if not prevDanmakuID or prevDanmakuID ~= danmakuID
            then
                prevDanmakuID = danmakuID

                local w, h = _base._measureDanmakuText(text, size)
                local y = calc:calculate(w, h, start, life)

                builder:startDialogue(layer, start, start + life)
                builder:startStyle()
                builder:addFontColor(color)
                builder:addFontSize(size)
                writePosFunc(ctx, builder, w, y)
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

    calculators = nil
    writePosFuncs = nil
    builder = nil
    collectgarbage()

    f:close()
end


return
{
    writeDanmakus   = writeDanmakus,
}