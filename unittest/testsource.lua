local lu            = require("unittest/luaunit")    --= luaunit lu
local mockfs        = require("unittest/mockfs")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local source        = require("src/shell/source")
local application   = require("src/shell/application")


local MockNetworkConnection =
{
    _mBadURLs   = classlite.declareTableField(),

    addBadURL = function(self, url)
        if types.isString(url)
        then
            utils.pushArrayElement(self._mBadURLs, url)
        end
    end,

    _createConnection = function(self, url)
        if types.isString(url) and not utils.linearSearchArray(self._mBadURLs, url)
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

    _getPrivateDirPath = function(self)
        return "/"
    end,
}

classlite.declareClass(MockApplication, application.MPVDanmakuLoaderApp)


local MockDanmakuSourceFactory =
{
    _doReadMetaFile = function(self, callback)
        local app = self._mApplication
        local f = app:readFile(app:getDanmakuSourceMetaFilePath())
        local content = utils.readAndCloseFile(f)
        serialize.deserializeTupleFromString(content, callback)
    end,
}

classlite.declareClass(MockDanmakuSourceFactory, source.DanmakuSourceFactory)


TestDanmakuSourceFactory =
{
    _mApplication           = nil,
    _mDanmakuSourceFactory  = nil,

    setUp = function(self)
        self._mApplication = MockApplication:new()
        self._mDanmakuSourceFactory = MockDanmakuSourceFactory:new()
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
        local factory = self._mDanmakuSourceFactory
        local source1 = factory:addBiliBiliDanmakuSource(desc, offsets, urls)
        lu.assertNotNil(source1)
    end,
}



lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())