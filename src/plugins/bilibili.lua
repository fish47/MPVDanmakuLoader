local _intf     = require("src/plugins/_intf")
local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")
local danmaku   = require("src/core/danmaku")


local _BILI_PATTERN_DANMAKU_ID  = "_bili_%s_%s"
local _BILI_PATTERN_DANMAKU     = '<d%s+p="'
                                  .. "([%d%.]+),"       -- 起始时间
                                  .. "(%d+),"           -- 移动类型
                                  .. "(%d+),"           -- 字体大小
                                  .. "(%d+),"           -- 字体颜色
                                  .. "[^>]+,"
                                  .. "(%d+),"           -- ??
                                  .. "[^>]+,"
                                  .. "(%d+)"            -- ??
                                  .. '">([^<]+)</d>'

local _BILI_FMT_URL_DAMAKU      = "http://comment.bilibili.com/%s.xml"

local _BILI_FACTOR_TIME_STAMP   = 1000
local _BILI_FACTOR_FONT_SIZE    = 25

local _BILI_POS_MOVING_L2R      = 6
local _BILI_POS_MOVING_R2L      = 1
local _BILI_POS_STATIC_TOP      = 5
local _BILI_POS_STATIC_BOTTOM   = 4
local _BILI_POS_ADVANCED        = 7

-- 暂时不处理神弹幕
local _BILI_POS_TO_LAYER_MAP =
{
    [_BILI_POS_MOVING_L2R]      = danmaku.LAYER_MOVING_L2R,
    [_BILI_POS_MOVING_R2L]      = danmaku.LAYER_MOVING_R2L,
    [_BILI_POS_STATIC_TOP]      = danmaku.LAYER_STATIC_TOP,
    [_BILI_POS_STATIC_BOTTOM]   = danmaku.LAYER_STATIC_BOTTOM,
}

local BiliBiliDanmakuSourcePlugin =
{
    getName = function()
        return "bilibili"
    end,

    parse = function(self, app, file, timeOffset, sourceID)
        local rawData = utils.readAndCloseFile(file)
        if not rawData
        then
            return
        end

        local function __getLifeTime(cfg, pos)
            if pos == _BILI_POS_MOVING_L2R or pos == _BILI_POS_MOVING_R2L
            then
                return cfg.movingDanmakuLifeTime
            else
                return cfg.staticDanmakuLIfeTime
            end
        end

        local pools = app:getDanmakuPools()
        local cfg = app:getConfiguration()
        timeOffset = timeOffset or 0
        for start, typeStr, size, color, id1, id2, text in rawData:gmatch(_BILI_PATTERN_DANMAKU)
        do
            local biliPos = tonumber(typeStr) or _BILI_POS_MOVING_R2L
            local layer = _BILI_POS_TO_LAYER_MAP[biliPos]
            local pool = layer and pools:getDanmakuPoolByLayer(layer)
            if pool
            then
                local startTime = timeOffset + tonumber(start) * _BILI_FACTOR_TIME_STAMP
                local lifeTime = __getLifeTime(biliPos, cfg)
                local fontColor = utils.convertRGBHexToBGRString(tonumber(color))
                local fontFactor = math.floor(tonumber(size) / _BILI_FACTOR_FONT_SIZE)
                local fontSize = fontFactor * cfg.danmakuFontSize
                local danmakuID = string.format(_BILI_PATTERN_DANMAKU_ID, id1, id2)
                local text = utils.unescapeXMLString(text)
                pool:addDanmaku(startTime, lifeTime, fontColor, fontSize, sourceID, danmakuID, text)
            end
        end
    end,


    search = function(self, app, outVideoIDs, outSouceIDs)
        --TODO
        return true, 1, true
    end,

    getDanmakuURLs = function(self, videoIDs, outURLs)
        utils.clearTable(outURLs)
        for _, videoID in utils.iterateArray(videoIDs)
        do
            local url = string.format(_BILI_FMT_URL_DAMAKU, videoID)
            utils.pushArrayElement(outURLs, url)
        end
    end,

    getVideoPartDurations = function(self, videoIDs, outDurations)
        --TODO
    end,
}

classlite.declareClass(BiliBiliDanmakuSourcePlugin, _intf.IRemoteDanmakuSourcePlugin)


return
{
    BiliBiliDanmakuSourcePlugin     = BiliBiliDanmakuSourcePlugin,
}