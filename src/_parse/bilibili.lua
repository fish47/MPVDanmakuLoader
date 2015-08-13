local _base = require('src/_parse/_base')
local utils = require('src/utils')          --= utils utils
local asswriter = require('src/asswriter')  --= asswriter asswriter


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
            local d = _base._Danmaku:new()
            d.text = utils.unescapeXMLString(text)
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


return
{
    parseBiliBiliRawData    = parseBiliBiliRawData,
}