local mdlapp = require("src/app")
local mdlcfg = require("src/cfg")
local shell = require("src/shell")
local network = require("src/network")
local utils = require("src/utils")      --= utils utils


local MockApp   =
{
}

utils.declareClass(MockApp, mdlapp.MPVDanmakuLoaderApp)


local MockShell =
{
    _createApp = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return MockApp:new(cfg, conn)
    end,
}

utils.declareClass(MockShell, shell.ZenityShell)



local function test_main()
    local cfg = mdlcfg.MPVDanmakuLoaderCfg:new()
    local conn = network.CURLNetworkConnection:new("curl")
    local gui = MockShell:new("zenity", cfg, conn)
    gui:__onFileLoad()

    gui._mMPVDanmakuLoaderApp.searchDanDanPlayByVideoInfos = function()
        return
        {
            network.DanDanPlayVideoInfo:new("a", "1", "aas"),
            network.DanDanPlayVideoInfo:new("b", "b", "aas"),
        }
    end

    gui:_showMain()
end


test_main()