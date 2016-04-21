local utf8              = require("src/base/utf8")
local types             = require("src/base/types")
local utils             = require("src/base/utils")
local constants         = require("src/base/constants")
local classlite         = require("src/base/classlite")
local _ass              = require("src/core/_ass")
local _coreconstants    = require("src/core/_coreconstants")
local _poscalc          = require("src/core/_poscalc")


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


local function __writeMovingL2RPos(cfg, b, screenW, screenH, w, y)
    b:addMove(0, y, screenW + w, y)
end

local function __writeMovingR2LPos(cfg, b, screenW, screenH, w, y)
    b:addMove(screenW, y, -w, y)
end

local function __writeStaticTopPos(cfg, b, screenW, screenH, w, y)
    b:addTopCenterAlign()
    b:addPos(screenW / 2, y)
end

local function __writeStaticBottomPos(cfg, b, screenW, screenH, w, y)
    local stageH = screenH - cfg.bottomReservedHeight
    y = stageH - y
    y = y - cfg.bottomReservedHeight
    b:addBottomCenterAlign()
    b:addPos(screenW / 2, y)
end

local function __writeBottomSubtitlePos(cfg, b, screenW, screenH, w, y)
    y = screenH - y
    b:addBottomCenterAlign()
    b:addPos(screenW / 2, y)
    b:addStyleUnchecked(cfg.subtitleASSStyleString)
end


local DanmakuWriter =
{
    __mDanmakuData      = classlite.declareTableField(),
    _mCalculators       = classlite.declareTableField(),
    _mWritePosFunctions = classlite.declareTableField(),
    _mDialogueBuilder   = classlite.declareClassField(_ass.DialogueBuilder),


    new = function(self)
        local calcs = self._mCalculators
        calcs[_coreconstants.LAYER_MOVING_L2R]      = _poscalc.MovingPosCalculator:new()
        calcs[_coreconstants.LAYER_MOVING_R2L]      = _poscalc.MovingPosCalculator:new()
        calcs[_coreconstants.LAYER_STATIC_TOP]      = _poscalc.StaticPosCalculator:new()
        calcs[_coreconstants.LAYER_STATIC_BOTTOM]   = _poscalc.StaticPosCalculator:new()
        calcs[_coreconstants.LAYER_SUBTITLE]        = _poscalc.StaticPosCalculator:new()

        local posFuncs = self._mWritePosFunctions
        posFuncs[_coreconstants.LAYER_MOVING_L2R]       = __writeMovingL2RPos
        posFuncs[_coreconstants.LAYER_MOVING_R2L]       = __writeMovingR2LPos
        posFuncs[_coreconstants.LAYER_STATIC_TOP]       = __writeStaticTopPos
        posFuncs[_coreconstants.LAYER_STATIC_BOTTOM]    = __writeStaticBottomPos
        posFuncs[_coreconstants.LAYER_SUBTITLE]         = __writeBottomSubtitlePos
    end,


    dispose = function(self)
        utils.forEachTableValue(self._mCalculators, utils.disposeSafely)
    end,


    writeDanmakus = function(self, pools, cfg, screenW, screenH, f)
        local hasDanmaku = false
        local calculators = self._mCalculators
        for layer, calc in pairs(calculators)
        do
            local pool = pools:getDanmakuPoolByLayer(layer)
            pool:freeze()
            hasDanmaku = hasDanmaku or pool:getDanmakuCount() ~= 0
        end

        if not hasDanmaku
        then
            return false
        end


        local stageW = screenW
        local stageH = math.max(screenH - cfg.bottomReservedHeight, 1)
        _ass.writeScriptInfo(f, screenW, screenH)
        _ass.writeStyle(f, cfg.danmakuFontName, cfg.danmakuFontSize)
        _ass.writeEvents(f)

        local builder = self._mDialogueBuilder
        builder:clear()
        builder:setDefaultFontColor(cfg.danmakuFontColor)
        builder:setDefaultFontSize(cfg.danmakuFontSize)

        local danmakuData = utils.clearTable(self.__mDanmakuData)
        local writePosFuncs = self._mWritePosFunctions
        for layer, calc in pairs(calculators)
        do
            local writePosFunc = writePosFuncs[layer]
            local pool = pools:getDanmakuPoolByLayer(layer)
            calc:init(screenW, screenH)

            for i = 1, pool:getDanmakuCount()
            do
                utils.clearTable(danmakuData)
                pool:getDanmakuByIndex(i, danmakuData)

                local text = danmakuData[_coreconstants.DANMAKU_IDX_TEXT]
                local startTime = danmakuData[_coreconstants.DANMAKU_IDX_START_TIME]
                local fontSize = danmakuData[_coreconstants.DANMAKU_IDX_FONT_SIZE]
                local fontColor = danmakuData[_coreconstants.DANMAKU_IDX_FONT_COLOR]
                local lifeTime = danmakuData[_coreconstants.DANMAKU_IDX_LIFE_TIME]
                local w, h = _measureDanmakuText(text, fontSize)
                local y = calc:calculate(w, h, startTime, lifeTime)

                builder:startDialogue(layer, startTime, startTime + lifeTime)
                builder:startStyle()
                builder:addFontColor(fontColor)
                builder:addFontSize(fontSize)
                writePosFunc(cfg, builder, screenW, screenH, w, y)
                builder:endStyle()
                builder:addText(text)
                builder:endDialogue()
                builder:flushContent(f)
            end
        end

        return true
    end,
}

classlite.declareClass(DanmakuWriter)


return
{
    DanmakuWriter   = DanmakuWriter,
}