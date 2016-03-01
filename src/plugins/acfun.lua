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

local AcfunDanmakuSourcePlugin =
{}

classlite.declareClass(AcfunDanmakuSourcePlugin, pluginbase._PatternBasedDanmakuSourcePlugin)