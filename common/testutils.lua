local lu            = require("lib/luaunit")
local mock          = require("common/mock")
local utils         = require("src/base/utils")
local danmaku       = require("src/core/danmaku")
local danmakupool   = require("src/core/danmakupool")
local pluginbase    = require("src/plugins/pluginbase")


local function createSetUpPluginMethod(pluginClz)
    local ret = function(self)
        local app = mock.MockApplication:new()
        app:updateConfiguration()
        self._mApplication = app
        self._mConfiguration = app:getConfiguration()
        self._mDanmakuData = danmaku.DanmakuData:new()
        self._mSearchResult = pluginbase.DanmakuSourceSearchResult:new()

        lu.assertNotNil(pluginClz)
        local plugin = pluginClz:new()
        app:_addDanmakuSourcePlugin(plugin)
        self._mPlugin = plugin
    end
    return ret
end


local function tearDownPlugin(self)
    utils.disposeSafely(self._mApplication)
    utils.disposeSafely(self._mConfiguration)
    utils.disposeSafely(self._mPlugin)
    utils.disposeSafely(self._mDanmakuData)
    self._mApplication = nil
    self._mConfiguration = nil
    self._mPlugin = nil
    self._mDanmakuData = nil
end


local function parseDanmakuData(self, text)
    local app = self._mApplication
    local pools = app:getDanmakuPools()
    local sourceID = pools:allocateDanmakuSourceID()
    self._mPlugin:parseData(text, sourceID, 0)
    for _, pool in pools:iteratePools()
    do
        pool:freeze()
    end
end


local function runTestCases()
    lu.LuaUnit.verbosity = 2
    os.exit(lu.LuaUnit.run())
end


return
{
    createSetUpPluginMethod     = createSetUpPluginMethod,
    tearDownPlugin              = tearDownPlugin,
    parseDanmakuData            = parseDanmakuData,
    runTestCases                = runTestCases,
}