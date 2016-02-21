local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")
local pluginbase    = require("src/plugins/pluginbase")


local _DDP_PLUGIN_NAME              = "DanDanPlay"

local _DDP_FMT_URL_DANMAKU          = "http://acplay.net/api/v1/comment/%s"
local _DDP_FMT_URL_SEARCH           = "http://acplay.net/api/v1/searchall/%s"


local _DDP_PATTERN_DANMAKU_ID       = "ddp_%d_%d"
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

local _DDP_POS_TO_LAYER_MAP =
{
    [_DDP_POS_MOVING_L2R]       = danmaku.LAYER_MOVING_L2R,
    [_DDP_POS_MOVING_R2L]       = danmaku.LAYER_MOVING_R2L,
    [_DDP_POS_STATIC_TOP]       = danmaku.LAYER_STATIC_TOP,
    [_DDP_POS_STATIC_BOTTOM]    = danmaku.LAYER_STATIC_BOTTOM,
}


local DanDanPlayDanmakuSourcePlugin =
{
    getName = function(self)
        return _DDP_PLUGIN_NAME
    end,

    _getGMatchPattern = function(self)
        return _DDP_PATTERN_COMMENT
    end,

    _iterateDanmakuParams = function(self, iterFunc, cfg)
        local function __getLifeTime(cfg, pos)
            if pos == _DDP_POS_MOVING_L2R or pos == _DDP_POS_MOVING_R2L
            then
                return cfg.movingDanmakuLifeTime
            else
                return cfg.staticDanmakuLIfeTime
            end
        end

        local start, typeStr, color, id1, id2, txt = iterFunc()
        if not start
        then
            return
        end

        local pos = tonumber(typeStr)
        local layer = _DDP_POS_TO_LAYER_MAP[pos] or danmaku.LAYER_MOVING_L2R
        local startTime = tonumber(start) * _DDP_FACTOR_TIME_STAMP
        local lifeTime = __getLifeTime(cfg, pos)
        local fontColor = utils.convertRGBHexToBGRString(tonumber(color))
        local fontSize = cfg.danmakuFontSize
        local danmakuID = string.format(_DDP_PATTERN_DANMAKU_ID, id1, id2)
        local text = utils.unescapeXMLString(txt)
        return layer, startTime, lifeTime, fontColor, fontSize, danmakuID, text
    end,


    search = function(self, keyword, result)
        --TODO

        result.isSplited = false
        result.videoTitleColumnCount = 2
        return true
    end,


    downloadRawDatas = function(self, videoIDs, outDatas)
        --TODO
    end,
}

classlite.declareClass(DanDanPlayDanmakuSourcePlugin, pluginbase.StringBasedDanmakuSourcePlugin)


return
{
    DanDanPlayDanmakuSourcePlugin   = DanDanPlayDanmakuSourcePlugin,
}