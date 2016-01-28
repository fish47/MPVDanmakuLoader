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


    testMatchLocalSource = function(self)
        local function __createFile(app, dir, fileName, suffix)
            local fullPath = unportable.joinPath(dir, fileName)
            local f = app:writeFile(fullPath)
            local ret = utils.writeAndCloseFile(f, constants.STR_EMPTY)
            return ret and fullPath
        end

        local function __assertLocalRawDataFiles(app, plugin, factory, assertPaths)
            local parsedFilePaths = {}
            local orgParseFunc = plugin.parse
            plugin.parse = function(self, app, filePath)
                table.insert(parsedFilePaths, filePath)
            end

            local listedSources = {}
            factory:listDanmakuSources(listedSources)
            for _, source in ipairs(listedSources)
            do
                source:parse(app)
            end

            local pathsBak = {}
            utils.appendArrayElements(assertPaths)
            table.sort(pathsBak)
            table.sort(parsedFilePaths)
            lu.assertEquals(pathsBak, parsedFilePaths)
        end

        local app = self._mApplication
        local factory = self._mDanmakuSourceFactory
        local dir = app:getLocalDanamakuSourceDirPath()

        local suffix1 = ".p1"
        local filePaths1 = {}
        for _, fileName in ipairs({ "a", "b", "c" })
        do
            local fullPath = unportable.joinPath(dir, fileName .. suffix1)
            local f = app:writeFile(fullPath)
            if utils.writeAndCloseFile(f, constants.STR_EMPTY)
            then
                table.insert(filePaths1, fullPath)
            end
        end

        local plugin1 = pluginbase.IDanmakuSourcePlugin:new()
        plugin1.isMatchedRawDataFile = function(self, app, filePath)
            return utils.linearSearchArray(filePaths1, filePath)
        end

        app:addDanmakuSourcePlugin(plugin1)
        __assertLocalRawDataFiles(app, plugin1, factory, dir, filePaths1)


    end,
}



lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())