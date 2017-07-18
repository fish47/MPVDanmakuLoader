local lu            = require("lib/luaunit")
local mock          = require("common/mock")
local utils         = require("src/base/utils")
local danmaku       = require("src/core/danmaku")
local danmakupool   = require("src/core/danmakupool")
local pluginbase    = require("src/plugins/pluginbase")


local function createSetUp(pluginClz)
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


local function tearDown(self)
    utils.disposeSafely(self._mApplication)
    utils.disposeSafely(self._mConfiguration)
    utils.disposeSafely(self._mPlugin)
    utils.disposeSafely(self._mDanmakuData)
    self._mApplication = nil
    self._mConfiguration = nil
    self._mPlugin = nil
    self._mDanmakuData = nil
end


local function parseData(self, text)
    local app = self._mApplication
    local pools = app:getDanmakuPools()
    local sourceID = pools:allocateDanmakuSourceID()
    self._mPlugin:parseData(text, sourceID, 0)
    for _, pool in pools:iteratePools()
    do
        pool:freeze()
    end
end


return
{
    createSetUp     = createSetUp,
    tearDown        = tearDownTestCase,
    parseData       = parseData,
}
