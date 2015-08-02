local _base = require('src/_parse/_base')
local poscalc = require('src/poscalc')      --= poscalc poscalc
local asswriter = require('src/asswriter')  --= asswriter asswriter


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
            local w, h = _base._measureDanmakuText(d.text, fontSize)
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


return
{
    writeDanmakus   = writeDanmakus,
}