local base = require('src/base')            --= base base
local poscalc = require('src/poscalc')      --= poscalc poscalc


local Danmaku =
{
    text = nil,         -- 评论内容，以 utf8 编码，并处理 ASS 转义
    start = 0,          -- 弹幕起始时间，单位 ms
    width = 0,          -- 宽度，单位 pixel
    height = 0,         -- 高度，单位 pixel
    fontSize = 0,       -- 字体大小，单位 pt
    fontColor = 0,      -- 字体颜色，格式 RRGGBB
    transform = nil,    -- 定位信息

    new = function(obj)
        obj = base.allocateInstance(Danmaku, obj)
        return obj
    end,
}

base.declareClass(Danmaku)





local _PATTERN_BILI_POS     = "(.+),(.+),(.+),(.+),.+,.+,.+,.+"
local _PATTERN_BILI_DANMAKU = "<d%s+p=\"" .. _PATTERN_BILI_POS .. "\">(.+)</d>"

local _POS_BILI_LEFT_TO_RIGHT = 1
local _POS_BILI_RIGHT_TO_LEFT = 6
local _POS_BLIL_STATIC_TOP    = 5
local _POS_BILI_STATIC_BOTTOM = 4
local _POS_BILI_ADVANCED      = 7


--@tparam string rawDatat
--@tparam file f
function readBiliBiliDanmaku(rawData, f)
    local normalPosDanmakus =
    {
        _POS_BILI_LEFT_TO_RIGHT = {},
        _POS_BILI_RIGHT_TO_LEFT = {},
        _POS_BLIL_STATIC_TOP    = {},
        _POS_BILI_STATIC_BOTTOM = {},
    }

    local normalPosCalculcators =
    {
        --TODO
        _POS_BILI_LEFT_TO_RIGHT = poscalc.L2RPosCalculator.new(),
        _POS_BILI_RIGHT_TO_LEFT = poscalc.R2LPosCalculaotr.new(),
        _POS_BLIL_STATIC_TOP    = poscalc.T2BPosCalculator.new(),
        _POS_BILI_STATIC_BOTTOM = poscalc.B2TPosCalcluator.new(),
    }

    local advancedDanmaku = Danmaku.new()
    local defaultTextStyle = nil

    for start, typ, size, color, text in rawData:gmatch(_PATTERN_BILI_DANMAKU)
    do
        local posType = tonumber(typ) or _POS_BILI_LEFT_TO_RIGHT
        local danmakuList = normalPosDanmakus[posType]
        if danmakuList
        then
            local d = Danmaku.new()
            d.text = text
            table.insert(danmakuList, d)
        else
            --TODO 神弹幕
        end
    end

    rawData = nil
    collectgarbage()

    -- 按起始时间排序(升序)
    for _, danmakuList in pairs(normalPosDanmakus)
    do
        table.sort(danmakuList, function(d1, d2)
            return d1.start < d2.start
        end)
    end

    for i, calc in ipairs(normalPosCalculcators)
    do
        --= poscalc._BasePosCalculator calc

        local danmakuList = normalPosDanmakus[i]
        for _, d in ipairs(danmakuList)
        do
            base.clearTable(d)
        end

        calc:dispose()
        base.clearTable(danmakuList)
    end

    base.clearTable(normalPosCalculcators)
    base.clearTable(normalPosDanmakus)
    collectgarbage()
end


local _M = {}

return _M