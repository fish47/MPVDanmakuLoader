local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local dandanplay    = require("src/search/dandanplay")
local bilibili      = require("src/search/bilibili")
local logic         = require("src/shell/logic")
local application   = require("src/shell/application")


local MockApp   =
{
    getVideoFileName = function()
        return "哦哈哈.avi.rmvb.wmv"
    end,

    getVideoDurationSeconds = function()
        return 1
    end,

    searchDanDanPlayByVideoInfos = function()
        return
        {
            dandanplay.DanDanPlayVideoInfo:new("a", "1", "aas"),
            dandanplay.DanDanPlayVideoInfo:new("b", "2", "aas"),
        }
    end,

    searchBiliBiliByKeyword = function()
        return
        {
            bilibili.BiliBiliSearchResult:new("type1", "title1", "bid1"),
            bilibili.BiliBiliSearchResult:new("type2", "title2", "bid2"),
            bilibili.BiliBiliSearchResult:new("type3", "title3", "bid3"),
        }
    end,

    getBiliBiliVideoInfos = function(self, videoID)
        local results =
        {
            ["bid1"]    =
            {
                bilibili.BiliBiliVideoInfo:new("subtitle1_1", 1000, "url1"),
            },

            ["bid2"]    =
            {
                bilibili.BiliBiliVideoInfo:new("subtitle2_1", 100, "url2"),
                bilibili.BiliBiliVideoInfo:new("subtitle2_2", 100, "url3"),
                bilibili.BiliBiliVideoInfo:new("subtitle2_3", 100, "url4"),
            },

            ["bid3"]    =
            {
                bilibili.BiliBiliVideoInfo:new("subtitle3_1", 1000, "url5"),
                bilibili.BiliBiliVideoInfo:new("subtitle3_2", 1000, "url6"),
            },
        }
        return results[videoID]
    end,
}

classlite.declareClass(MockApp, application.MPVDanmakuLoaderApp)


local MockShell =
{
    _createApplication = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return MockApp:new(cfg, conn)
    end,
}

classlite.declareClass(MockShell, logic.MPVDanmakuLoaderShell)



local cfg = application.MPVDanmakuLoaderCfg:new()
local gui = MockShell:new(cfg)
gui:_onLoadFile()
gui:_showMain()