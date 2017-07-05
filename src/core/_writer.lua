local _ass              = require("src/core/_ass")
local _poscalc          = require("src/core/_poscalc")
local _coreconstants    = require("src/core/_coreconstants")
local utf8              = require("src/base/utf8")
local types             = require("src/base/types")
local utils             = require("src/base/utils")
local constants         = require("src/base/constants")
local classlite         = require("src/base/classlite")
local danmaku           = require("src/core/danmaku")


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


local function _writeMovingL2RPos(cfg, b, screenW, screenH, w, y)
    b:addMove(0, y, screenW + w, y)
end

local function _writeMovingR2LPos(cfg, b, screenW, screenH, w, y)
    b:addMove(screenW, y, -w, y)
end

local function _writeStaticTopPos(cfg, b, screenW, screenH, w, y)
    b:addTopCenterAlign()
    b:addPos(screenW / 2, y)
end


local function __doWriteStaticBottomPos(cfg, b, screenW, screenH, w, y, reservedH)
    local stageH = screenH - reservedH
    y = stageH - y
    y = y - reservedH
    b:addPos(screenW / 2, y)
end

local function _writeStaticBottomPos(cfg, b, screenW, screenH, w, y)
    b:addBottomCenterAlign()
    __doWriteStaticBottomPos(cfg, b, screenW, screenH, w, y, cfg.danmakuReservedBottomHeight)
end

local function _writeBottomSubtitlePos(cfg, b, screenW, screenH, w, y)
    -- 字幕对齐方式由默认样式指定
    __doWriteStaticBottomPos(cfg, b, screenW, screenH, w, y, cfg.subtitleReservedBottomHeight)
end


local DanmakuWriter =
{
    __mDanmakuData      = classlite.declareClassField(danmaku.DanmakuData),
    _mCalculators       = classlite.declareTableField(),
    _mWritePosFunctions = classlite.declareTableField(),
    _mDialogueBuilder   = classlite.declareClassField(_ass.DialogueBuilder),
}

function DanmakuWriter:new()
    local calcs = self._mCalculators
    calcs[_coreconstants.LAYER_MOVING_L2R]      = _poscalc.MovingPosCalculator:new()
    calcs[_coreconstants.LAYER_MOVING_R2L]      = _poscalc.MovingPosCalculator:new()
    calcs[_coreconstants.LAYER_STATIC_TOP]      = _poscalc.StaticPosCalculator:new()
    calcs[_coreconstants.LAYER_STATIC_BOTTOM]   = _poscalc.StaticPosCalculator:new()
    calcs[_coreconstants.LAYER_SUBTITLE]        = _poscalc.StaticPosCalculator:new()

    local posFuncs = self._mWritePosFunctions
    posFuncs[_coreconstants.LAYER_MOVING_L2R]       = _writeMovingL2RPos
    posFuncs[_coreconstants.LAYER_MOVING_R2L]       = _writeMovingR2LPos
    posFuncs[_coreconstants.LAYER_STATIC_TOP]       = _writeStaticTopPos
    posFuncs[_coreconstants.LAYER_STATIC_BOTTOM]    = _writeStaticBottomPos
    posFuncs[_coreconstants.LAYER_SUBTITLE]         = _writeBottomSubtitlePos
end


function DanmakuWriter:dispose()
    utils.forEachTableValue(self._mCalculators, utils.disposeSafely)
end


function DanmakuWriter:writeDanmakusToFile(pools, cfg, screenW, screenH, f)
    local hasDanmaku = false
    local calculators = self._mCalculators
    for layer, calc in pairs(calculators)
    do
        local pool = pools:getDanmakuPoolByLayer(layer)
        pool:freeze()
        hasDanmaku = hasDanmaku or pool:getDanmakuCount() > 0
    end

    if not hasDanmaku
    then
        return false
    end

    _ass.writeScriptInfo(f, screenW, screenH)
    _ass.writeStyleHeader(f)
    _ass.writeDanmakuStyle(f, cfg.danmakuFontName, cfg.danmakuFontSize, cfg.danmakuFontColor)
    _ass.writeSubtitleStyle(f, cfg.subtitleFontName, cfg.subtitleFontSize, cfg.subtitleFontColor)
    _ass.writeEventsHeader(f)


    local danmakuData = self.__mDanmakuData
    local writePosFuncs = self._mWritePosFunctions
    local builder = self._mDialogueBuilder
    builder:clear()

    for layer, calc in pairs(calculators)
    do
        if layer == _coreconstants.LAYER_SUBTITLE
        then
            builder:initSubtitleStyle()
            calc:init(screenW, screenH - cfg.subtitleReservedBottomHeight)
        else
            builder:initDanmakuStyle()
            calc:init(screenW, screenH - cfg.danmakuReservedBottomHeight)
        end

        local writePosFunc = writePosFuncs[layer]
        local pool = pools:getDanmakuPoolByLayer(layer)
        for i = 1, pool:getDanmakuCount()
        do
            utils.clearTable(danmakuData)
            pool:getDanmakuByIndex(i, danmakuData)

            local startTime = danmakuData.startTime
            local lifeTime = danmakuData.lifeTime
            local fontSize = danmakuData.fontSize
            local danmakuText = danmakuData.danmakuText
            local w, h = _measureDanmakuText(danmakuText, fontSize)
            local y = calc:calculate(w, h, startTime, lifeTime)

            builder:startDialogue(layer, startTime, startTime + lifeTime)
            builder:startStyle()
            builder:addFontColor(danmakuData.fontColor)
            builder:addFontSize(fontSize)
            writePosFunc(cfg, builder, screenW, screenH, w, y)
            builder:endStyle()
            builder:addText(danmakuText)
            builder:endDialogue()
            builder:flushContent(f)
        end
    end

    return true
end

function DanmakuWriter:writeDanmakusToString(pools, cfg, screenW, screenH)
end

classlite.declareClass(DanmakuWriter)


return
{
    DanmakuWriter   = DanmakuWriter,
}
