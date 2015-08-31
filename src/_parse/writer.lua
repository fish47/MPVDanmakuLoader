local _base = require("src/_parse/_base")
local poscalc = require("src/poscalc")      --= poscalc poscalc
local asswriter = require("src/asswriter")  --= asswriter asswriter


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


local function writeDanmakus(cfg, pools, screenW, screenH, f)
    local stageW = screenW
    local stageH = math.max(screenH - cfg.bottomReserved, 1)

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


    asswriter.writeScriptInfo(f, screenW, screenH)
    asswriter.writeStyle(f, cfg.defaultFontName, cfg.defaultFontSize)
    asswriter.writeEvents(f)

    local builder = asswriter.DialogueBuilder:new()
    builder:setDefaultFontColor(cfg.defaultFontColor)
    builder:setDefaultFontSize(cfg.defaultFontSize)

    for layer, calc in pairs(calculators)
    do
        local writePosFunc = writePosFuncs[layer]
        local pool = cfg.pools[layer]
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

    calculators = nil
    writePosFuncs = nil
    builder = nil

    f:close()
end


return
{
    writeDanmakus   = writeDanmakus,
}