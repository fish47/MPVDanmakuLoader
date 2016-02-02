local lu            = require("unittest/luaunit")    --= luaunit lu
local mocks         = require("unittest/mocks")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local application   = require("src/shell/application")


local MockPlugin =
{
    _mName              = classlite.declareConstantField(nil),
    _mPathPattern       = classlite.declareConstantField(nil),

    new = function(self, name, pattern)
        lu.assertTrue(types.isString(name))
        self._mName = name
        self._mPathPattern = pattern
    end,

    getName = function(self)
        return self._mName
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
    _mRandomURLCount        = nil,

    setUp = function(self)
        self._mApplication = mocks.MockApplication:new()
        self._mDanmakuSourceFactory = mocks.MockDanmakuSourceFactory:new()
        self._mDanmakuSourceFactory:setApplication(self._mApplication)
        self._mRandomURLCount = 0
    end,

    tearDown = function(self)
        self._mApplication:dispose()
        self._mDanmakuSourceFactory:dispose()
    end,

    _createRandomURL = function(self, content)
        local conn = self._mApplication:getNetworkConnection()
        local url = string.format("http://www.xxx.com/%d", self._mRandomURLCount)
        conn:setResponse(url, types.isString(content) or constants.STR_EMPTY)
        self._mRandomURLCount = self._mRandomURLCount + 1
        return url
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
            local sourcePaths = {}
            factory:listDanmakuSources(localSources)
            lu.assertFalse(types.isEmptyTable(localSources))

            for _, source in ipairs(localSources)
            do
                if source._mPlugin == plugin
                then
                    table.insert(sourcePaths, source._mFilePath)
                end
            end

            local assertPathsBak = utils.appendArrayElements({}, assertPaths)
            table.sort(sourcePaths)
            table.sort(assertPathsBak)
            lu.assertEquals(sourcePaths, assertPathsBak)
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


    testAddAndRemoveSource = function(self)
        local function __createRandomOffsetsAndURLs(self, conn)
            local count = math.random(10)
            local urls = {}
            local offsets = {}
            for i = 1, count
            do
                table.insert(offsets, math.random(100))
                table.insert(urls, self:_createRandomURL())
            end
            return offsets, urls
        end

        local app = self._mApplication
        local factory = self._mDanmakuSourceFactory
        local dir = app:getDanmakuSourceRawDataDirPath()

        local plugins = {}
        local pluginCount = math.random(5)
        for i = 1, pluginCount
        do
            local plugin = MockPlugin:new(string.format("Plugin_%d", i))
            table.insert(plugins, plugin)
            app:addDanmakuSourcePlugin(plugin)
        end

        local srcURLs = {}
        local srcOffsets = {}
        local srcPlugins = {}
        local sourceCount = math.random(100)
        for i = 1, sourceCount
        do
            local count = math.random(10)
            local urls = {}
            local offsets = {}
            for i = 1, count
            do
                table.insert(urls, self:_createRandomURL())
                table.insert(offsets, math.random(100))
            end

            local plugin = plugins[math.random(pluginCount)]
            table.insert(srcPlugins, plugin)
            table.insert(srcOffsets, offsets)
            table.insert(srcURLs, urls)

            -- 每次添加都会写一次序列化文件
            local source = factory:addDanmakuSource(plugin, tostring(i), offsets, urls)
            factory:recycleDanmakuSource(source)
        end

        local function __assertDanmakuSources(sources, plugins, offsets, urls)
            for _, source in ipairs(sources)
            do
                local idx = tonumber(source:getDescription())
                lu.assertNotNil(idx)
                lu.assertEquals(source._mPlugin, plugins[idx])
                lu.assertEquals(source._mTimeOffsets, offsets[idx])
                lu.assertEquals(source._mDownloadURLs, urls[idx])
            end
        end

        -- 看一下反序列化正不正确
        local sources = {}
        factory:listDanmakuSources(sources)
        __assertDanmakuSources(sources, srcPlugins, srcOffsets, srcURLs)

        -- 测一下删除弹幕源
        local filePaths = {}
        while true
        do
            local count = #sources
            if count == 0
            then
                break
            end

            -- 删除对应文件
            local removeSource = table.remove(sources, math.random(count))
            utils.appendArrayElements(utils.clearTable(filePaths), removeSource._mFilePaths)
            factory:deleteDanmakuSource(removeSource)
            for _, filePath in ipairs(filePaths)
            do
                lu.assertFalse(app:isExistedFile(filePath))
            end

            factory:listDanmakuSources(utils.clearTable(sources))
            __assertDanmakuSources(sources, srcPlugins, srcOffsets, srcURLs)
            lu.assertEquals(#sources, count - 1)
        end
    end,


    testDeleteUnfinishedDownloadFiles = function(self)
        --TODO
    end,

    testUpdateSource = function(self)
        --TODO
    end,
}



lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())