local mdlapp = require("src/app")
local mdlcfg = require("src/cfg")
local shell = require("src/shell")
local network = require("src/network")
local utils = require("src/utils")      --= utils utils


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
            network.DanDanPlayVideoInfo:new("a", "1", "aas"),
            network.DanDanPlayVideoInfo:new("b", "2", "aas"),
        }
    end,

    searchBiliBiliByKeyword = function()
        return
        {
            network.BiliBiliSearchResult:new("type1", "title1", "bid1"),
            network.BiliBiliSearchResult:new("type2", "title2", "bid2"),
            network.BiliBiliSearchResult:new("type3", "title3", "bid3"),
        }
    end,

    getBiliBiliVideoInfos = function(self, videoID)
        local results =
        {
            ["bid1"]    =
            {
                network.BiliBiliVideoInfo:new("subtitle1_1", 1000, "url1"),
            },

            ["bid2"]    =
            {
                network.BiliBiliVideoInfo:new("subtitle2_1", 100, "url2"),
                network.BiliBiliVideoInfo:new("subtitle2_2", 100, "url3"),
                network.BiliBiliVideoInfo:new("subtitle2_3", 100, "url4"),
            },

            ["bid3"]    =
            {
                network.BiliBiliVideoInfo:new("subtitle3_1", 1000, "url5"),
                network.BiliBiliVideoInfo:new("subtitle3_2", 1000, "url6"),
            },
        }
        return results[videoID]
    end,
}

utils.declareClass(MockApp, mdlapp.MPVDanmakuLoaderApp)


local MockShell =
{
    _createApplication = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return MockApp:new(cfg, conn)
    end,
}

utils.declareClass(MockShell, shell.MPVDanmakuLoaderShell)


local function test_main()
    local cfg = mdlcfg.MPVDanmakuLoaderCfg:new()
    local conn = network.CURLNetworkConnection:new("curl")
    local guiBuilder = shell.ZenityGUIBuilder:new("zenity")
    local gui = MockShell:new(cfg, conn, guiBuilder)
    gui:_onLoadFile()
    gui:_showMain()
end


test_main()