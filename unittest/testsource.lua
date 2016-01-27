local lu            = require("unittest/luaunit")    --= luaunit lu
local mocks         = require("unittest/mocks")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local source        = require("src/shell/source")
local application   = require("src/shell/application")


local MockPlugin =
{
    _mName              = classlite.declareConstantField(nil),
    _mFileNamePattern   = classlite.declareConstantField(nil),
    _mParseFilePaths    = classlite.declareConstantField(nil),

    getName = function(self)
        local name = self._mName
        lu.assertTrue(types.isString(name))
        return name
    end,

    parse = function(self, app, filePath)
        utils.pushArrayElement(self._mParseFilePaths, filePath)
    end,

    isMatchedRawDataFile = function(self, app, filePath)
        local pattern = self._mFileNamePattern
        lu.assertTrue(types.isString)
        return app:isExistedFile(filePath) and filePath:match(pattern)
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


    testMatchedLocalSources = function(self)
        local function __writeFile(app, dir, fileName, content)
            local f = app:writeFile(unportable.joinPath(dir, fileName))
            utils.writeAndCloseFile(f, content or constants.STR_EMPTY)
        end

        local app = self._mApplication
        local factory = self._mDanmakuSourceFactory
        local dir = app:getLocalDanamakuSourceDirPath()


    end,
}



lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())