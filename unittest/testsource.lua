local lu            = require("unittest/luaunit")    --= luaunit lu
local mockfs        = require("unittest/mockfs")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local source        = require("src/shell/source")
local application   = require("src/shell/application")


local MockNetworkConnection =
{
    _createConnection = function(self, url)
        if types.isString(url) and not url:find("fail", 1, true)
        then
            return true, "mock_content: " .. url
        end
    end,

    _readConnection = function(self, conn)
        return conn
    end,
}

classlite.declareClass(MockNetworkConnection, unportable._NetworkConnectionBase)


local MockApplication =
{
    _mNetworkConnection = classlite.declareClassField(MockNetworkConnection),
    _mMockFileSystem    = classlite.declareClassField(mockfs.MockFileSystem),

    new = function(self, ...)
        self:getParent().new(self, ...)
        self._mMockFileSystem:setup(self)
    end,

    dispose = function(self)
        self._mMockFileSystem:unsetup()
    end,
}

classlite.declareClass(MockApplication, application.MPVDanmakuLoaderApp)


TestDanmakuSourceFactory =
{
    _mApplication           = nil,
    _mDanmakuSourceFactory  = nil,

    setUp = function(self)
        self._mApplication = MockApplication:new()
        self._mDanmakuSourceFactory = source.DanmakuSourceFactory:new()
        self._mDanmakuSourceFactory:setApplication(self._mApplication)
    end,

    tearDown = function(self)
        self._mApplication:dispose()
        self._mDanmakuSourceFactory:dispose()
    end,


    testAddSource = function(self)
--        local timeOffsets = {  }
    end,
}



lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())