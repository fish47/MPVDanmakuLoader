local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")
local pluginbase    = require("src/plugins/pluginbase")

-- http://www.acfun.tv/member/special/getSpecialContentPageBySpecial.aspx?specialId=1058
-- http://www.acfun.tv/video/getVideo.aspx?id=1280192

-- http://www.acfun.tv/v/ac2545690
-- http://danmu.aixifan.com/V2/3201855
-- http://www.acfun.tv/video/getVideo.aspx?id=3201855

local _ACFUN_PLUGIN_NAME                = "Acfun"

local _ACFUN_DEFAULT_DURATION           = 0

local _ACFUN_PATTERN_VID                = '<a%s*data-vid="([%d]+)"'
local _ACFUN_PATTERN_DURATION           = '"time"%s*:%s*([%d]+)%s*,'
local _ACFUN_PATTERN_DANMAKU_INFO_KEY   = '"c"%s*:%s*'
local _ACFUN_PATTERN_DANMAKU_TEXT_KEY   = '"m"%s*:%s*'
local _ACFUN_PATTERN_DANMAKU_INFO_VALUE = "([%d%.]+)-,"     -- 出现时间
                                          .. "(%d+)-,"      -- 颜色
                                          .. "(%d+)-,"      -- 弹幕类型
                                          .. "(%d+)-,"      -- 字体大小
                                          .. "[^,]-,"       -- 用户 ID ？
                                          .. "(%d+)-,"      -- 弹幕 ID ？

local _ACFUN_FMT_URL_DANMAKU            = "http://danmu.aixifan.com/V2/%s"
local _ACFUN_FMT_URL_VIDEO_INFO         = "http://www.acfun.tv/video/getVideo.aspx?id=%s"

local _ACFUN_POS_MOVING_L2R     = 6
local _ACFUN_POS_MOVING_R2L     = 1
local _ACFUN_POS_STATIC_TOP     = 4
local _ACFUN_POS_STATIC_BOTTOM  = 5



local AcfunDanmakuSourcePlugin =
{
    getName = function(self)
        return _ACFUN_PLUGIN_NAME
    end,

    _startExtractDanmakus = function(self, rawData)
        --TODO
    end,

    _extractDanmaku = function(self, pos, text, cfg)
        --TODO
    end,

    __initNetworkConnection = function(self, conn)
        conn:resetParams()
        conn:addHeader(pluginbase._HEADER_USER_AGENT)
        conn:setCompressed(true)
    end,


    _doDownloadDanmakuRawData = function(self, conn, videoID, outDatas)
        self:__initNetworkConnection(conn)
        return string.format(_ACFUN_FMT_URL_DANMAKU, videoID)
    end,


    _doGetVideoDuration = function(self, conn, videoID, outDurations)
        local function __parseDuration(data, outDurations)
            local duration = nil
            if types.isString(data)
            then
                local seconds = data:match(_ACFUN_PATTERN_DURATION)
                duration = seconds and utils.convertHHMMSSToTime(0, 0, tonumber(seconds), 0)
            end
            duration = duration or _ACFUN_DEFAULT_DURATION
            table.insert(outDurations, duration)
        end

        local url = string.format(_ACFUN_FMT_URL_VIDEO_INFO, videoID)
        self:__initNetworkConnection(conn)
        conn:receiveLater(url, __parseDuration, outDurations)
    end,
}

classlite.declareClass(AcfunDanmakuSourcePlugin, pluginbase._PatternBasedDanmakuSourcePlugin)