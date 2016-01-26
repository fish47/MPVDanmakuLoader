local lu            = require("unittest/luaunit")    --= luaunit lu
local mocks         = require("unittest/mocks")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local source        = require("src/shell/source")
local application   = require("src/shell/application")


local MockPlugin =
{
    getName = function(self)
        return "mock_plugin"
    end,
}
classlite.declareClass(MockPlugin, pluginbase.IDanmakuSourcePlugin)


TestDanmakuSourceFactory =
{
    _mApplication           = nil,
    _mDanmakuSourceFactory  = nil,

    setUp = function(self)
        self._mApplication = mocks.MockApplication:new()
        self._mDanmakuSourceFactory = mocks.MockDanmakuSourceFactory:new()
        self._mDanmakuSourceFactory:setApplication(self._mApplication)
    end,

    tearDown = function(self)
        self._mApplication:dispose()
        self._mDanmakuSourceFactory:dispose()
    end,


    testAddSource = function(self)
        local urls = { "1", "2", "3" }
        local offsets = { 0, 1, 2 }
        local desc = "123"
    end,
}



lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())