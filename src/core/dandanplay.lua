local _ass  = require("src/core/_ass")
local utils = require("src/base/utils")


local _DDP_PATTERN_DANMAKU_ID       = "_ddp_%d_%d"
local _DDP_PATTERN_COMMENT          = "<Comment"
                                      .. '%s+Time="([%d.]+)"'
                                      .. '%s+Mode="(%d+)"'
                                      .. '%s+Color="(%d+)"'
                                      .. '%s+Timestamp="%d+"'
                                      .. '%s+Pool="(%d+)"'
                                      .. '%s+UId="%-?[%d]+"'
                                      .. '%s+CId="(%d+)"'
                                      .. "%s*>"
                                      .. "([^<]+)"
                                      .. "</Comment>"


local _DDP_FACTOR_TIME_STAMP        = 1000

local _DDP_POS_MOVING_L2R           = 6
local _DDP_POS_MOVING_R2L           = 1
local _DDP_POS_STATIC_TOP           = 5
local _DDP_POS_STATIC_BOTTOM        = 4

local _DDP_POS_TO_LAYER_MAP     =
{
    [_DDP_POS_MOVING_L2R]       = _ass.LAYER_MOVING_L2R,
    [_DDP_POS_MOVING_R2L]       = _ass.LAYER_MOVING_R2L,
    [_DDP_POS_STATIC_TOP]       = _ass.LAYER_STATIC_TOP,
    [_DDP_POS_STATIC_BOTTOM]    = _ass.LAYER_STATIC_BOTTOM,
}

local _DDP_LIFETIME_MAP         =
{
    [_DDP_POS_MOVING_L2R]       = _ass._LIFETIME_MOVING,
    [_DDP_POS_MOVING_R2L]       = _ass._LIFETIME_MOVING,
    [_DDP_POS_STATIC_TOP]       = _ass._LIFETIME_STATIC,
    [_DDP_POS_STATIC_BOTTOM]    = _ass._LIFETIME_STATIC,
}



local function parseDanDanPlayRawData(cfg, pools, rawData)
    if not rawData
    then
        return
    end

    for start, typeStr, color, id1, id2, text in rawData:gmatch(_DDP_PATTERN_COMMENT)
    do
        local pos = tonumber(typeStr) or _DDP_POS_MOVING_R2L
        local layer = _DDP_POS_TO_LAYER_MAP[pos]
        local pool = layer and pools:getDanmakuPoolByLayer(layer)
        if pool
        then
            local startTime = tonumber(start) * _DDP_FACTOR_TIME_STAMP
            local lifeTime = _DDP_LIFETIME_MAP[pos]
            local fontColor = utils.convertRGBHexToBGRString(tonumber(color))
            local fontSize = cfg.danmakuFontSize
            local danmakuID = string.format(_DDP_PATTERN_DANMAKU_ID, id1, id2)
            local text = utils.unescapeXMLString(text)
            pool:addDanmaku(startTime, lifeTime, fontColor, fontSize, danmakuID, text)
        end
    end
end


return
{
    parseDanDanPlayRawData  = parseDanDanPlayRawData,
}