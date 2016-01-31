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
    _mPathPattern       = classlite.declareConstantField(nil),
    _mParsedFilePaths   = classlite.declareTableField(),

    new = function(self, name, pattern)
        lu.assertTrue(types.isString(name))
        self._mName = name
        self._mPathPattern = pattern
    end,

    getName = function(self)
        return self._mName
    end,

    getParsedFilePaths = function(self)
        return self._mParsedFilePaths
    end,

    parse = function(self, app, filePath)
        local paths = self._mParsedFilePaths
        lu.assertTrue(types.isTable(paths))
        utils.pushArrayElement(paths, filePath)
    end,

    isMatchedRawDataFile = function(self, app, fullPath)
        local pattern = self._mPathPattern
        lu.assertTrue(types.isString(fullPath))
        return types.isString(pattern) and fullPath:match(pattern)
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


    _writeEmptyFiles = function(self, dir, fileNames, outFullPaths)
        for _, fileName in ipairs(fileNames)
        do
            local fullPath = unportable.joinPath(dir, fileName)
            local file = self._mApplication:writeFile(fullPath)
            local ret = utils.writeAndCloseFile(file, constants.STR_EMPTY)
            lu.assertTrue(ret)
            utils.pushArrayElement(outFullPaths, fullPath)
        end
    end,


    testMatchLocalSource = function(self)

        local function __assertPluginMatchedFilePaths(app, factory, plugin, assertPaths)
            local localSources = {}
            local pluginParsedPaths = plugin:getParsedFilePaths()
            factory:listDanmakuSources(localSources)
            utils.clearTable(pluginParsedPaths)
            for _, source in ipairs(localSources)
            do
                source:parse(app)
            end

            local parsedPathsBak = utils.appendArrayElements({}, pluginParsedPaths)
            local assertPathsBak = utils.appendArrayElements({}, assertPaths)
            table.sort(parsedPathsBak)
            table.sort(assertPathsBak)
            lu.assertEquals(parsedPathsBak, assertPathsBak)
            utils.clearTable(localSources)
            utils.clearTable(parsedPathsBak)
            utils.clearTable(assertPathsBak)
        end

        local app = self._mApplication
        local factory = self._mDanmakuSourceFactory
        local dir = app:getLocalDanamakuSourceDirPath()

        local filePaths1 = {}
        local filePaths2 = {}
        self:_writeEmptyFiles(dir, { "1.p1", "2.p1", "3.p1" }, filePaths1)
        self:_writeEmptyFiles(dir, { "1.p2", "2.p2", "3.p2" }, filePaths2)

        local plugin1 = MockPlugin:new("1", ".*%.p1$")
        local plugin2 = MockPlugin:new("2", ".*%.p2$")
        app:addDanmakuSourcePlugin(plugin1)
        app:addDanmakuSourcePlugin(plugin2)
        __assertPluginMatchedFilePaths(app, factory, plugin1, filePaths1)
        __assertPluginMatchedFilePaths(app, factory, plugin2, filePaths2)

        -- 匹配插件有优先级
        local filePaths3 = {}
        self:_writeEmptyFiles(dir, { "1.p3", "2.p4", "3.p5" }, filePaths3)

        local plugin3 = MockPlugin:new("3", ".*%.p[0-9]$")
        app:addDanmakuSourcePlugin(plugin3)
        __assertPluginMatchedFilePaths(app, factory, plugin3, filePaths3)
    end,


    testAddSource = function(self)
    end,
}



lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())