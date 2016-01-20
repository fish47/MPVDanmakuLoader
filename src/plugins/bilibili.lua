local _intf     = require("src/plugins/_intf")
local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")
local danmaku   = require("src/core/danmaku")


local _BILI_PATTERN_POS         = "([%d%.]+),(%d+),(%d+),(%d+),[^>]+,(%d+),[^>]+,(%d+)"
local _BILI_PATTERN_DANMAKU     = '<d%s+p="' .. _BILI_PATTERN_POS .. '">([^<]+)</d>'
local _BILI_PATTERN_DANMAKU_ID  = "_bili_%s_%s"

local _BILI_FACTOR_TIME_STAMP   = 1000
local _BILI_FACTOR_FONT_SIZE    = 25

local _BILI_POS_MOVING_L2R      = 6
local _BILI_POS_MOVING_R2L      = 1
local _BILI_POS_STATIC_TOP      = 5
local _BILI_POS_STATIC_BOTTOM   = 4
local _BILI_POS_ADVANCED        = 7

-- 暂时不处理神弹幕
local _BILI_POS_TO_LAYER_MAP    =
{
    [_BILI_POS_MOVING_L2R]      = danmaku.LAYER_MOVING_L2R,
    [_BILI_POS_MOVING_R2L]      = danmaku.LAYER_MOVING_R2L,
    [_BILI_POS_STATIC_TOP]      = danmaku.LAYER_STATIC_TOP,
    [_BILI_POS_STATIC_BOTTOM]   = danmaku.LAYER_STATIC_BOTTOM,
}

local _BILI_LIFETIME_MAP        =
{
    [_BILI_POS_MOVING_L2R]      = danmaku._LIFETIME_MOVING,
    [_BILI_POS_MOVING_R2L]      = danmaku._LIFETIME_MOVING,
    [_BILI_POS_STATIC_TOP]      = danmaku._LIFETIME_STATIC,
    [_BILI_POS_STATIC_BOTTOM]   = danmaku._LIFETIME_STATIC,
}

local BiliBiliDanmakuSourcePlugin =
{
    getName = function()
        return "BiliBili"
    end,

    getType = function()
        return _intf.SOURCE_TYPE_REMOTE
    end,

    parse = function(self, )
        --TODO
    end,

    getFuzzyMatchedDanmakuURL = function(self, app)
        --TODO
    end,

    getDanmakuURLs = function(self, videoIDs, outURLs)
        --TODO
    end,

    getVideoPartDurations = function(self, videoIDs, outDurations)
        --TODO
    end,
}

classlite.declareClass(BiliBiliDanmakuSourcePlugin, _intf.IDanmakuSourcePlugin)


local function parseBiliBiliRawData(cfg, pools, rawData, offset)
    if not rawData
    then
        return
    end

    -- 分P视频需要加时间偏移
    offset = offset or 0

    for start, typeStr, size, color, id1, id2, text in rawData:gmatch(_BILI_PATTERN_DANMAKU)
    do
        local biliPos = tonumber(typeStr) or _BILI_POS_MOVING_R2L
        local layer = _BILI_POS_TO_LAYER_MAP[biliPos]
        local pool = layer and pools:getDanmakuPoolByLayer(layer)
        if pool
        then
            local startTime = offset + tonumber(start) * _BILI_FACTOR_TIME_STAMP
            local lifeTime = _BILI_LIFETIME_MAP[biliPos]
            local fontColor = utils.convertRGBHexToBGRString(tonumber(color))
            local fontSize = tonumber(size) * cfg.danmakuFontSize / _BILI_FACTOR_FONT_SIZE
            local danmakuID = string.format(_BILI_PATTERN_DANMAKU_ID, id1, id2)
            local text = utils.unescapeXMLString(text)
            pool:addDanmaku(startTime, lifeTime, fontColor, fontSize, danmakuID, text)
        end
    end
end


return
{
    parseBiliBiliRawData    = parseBiliBiliRawData,
}