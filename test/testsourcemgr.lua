local lu            = require("test/luaunit")
local mocks         = require("test/mocks")
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


TestDanmakuSourceManager =
{
    _mApplication           = nil,
    _mDanmakuSourceManager  = nil,
    _mRandomURLCount        = nil,

    setUp = function(self)
        self._mApplication = mocks.MockApplication:new()
        self._mDanmakuSourceManager = mocks.MockDanmakuSourceManager:new()
        self._mDanmakuSourceManager:setApplication(self._mApplication)
        self._mRandomURLCount = 0
    end,

    tearDown = function(self)
        self._mApplication:dispose()
        self._mDanmakuSourceManager:dispose()
    end,

    _getRandomURL = function(self, content)
        local conn = self._mApplication:getNetworkConnection()
        local url = string.format("http://www.xxx.com/%d", self._mRandomURLCount)
        conn:setResponse(url, types.isString(content) or constants.STR_EMPTY)
        self._mRandomURLCount = self._mRandomURLCount + 1
        return url
    end,


    _writeEmptyFiles = function(self, dir, fileNames, outFullPaths)
        local app = self._mApplication
        app:createDir(dir)
        for _, fileName in ipairs(fileNames)
        do
            local fullPath = unportable.joinPath(dir, fileName)
            local file = app:writeFile(fullPath)
            local ret = utils.writeAndCloseFile(file, constants.STR_EMPTY)
            lu.assertTrue(ret)
            table.insert(outFullPaths, fullPath)
        end
    end,


    testMatchLocalSource = function(self)

        local function __assertPluginMatchedFilePaths(app, manager, plugin, assertPaths)
            local localSources = {}
            local sourcePaths = {}
            manager:listDanmakuSources(localSources)
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
        local manager = self._mDanmakuSourceManager
        local dir = app:getConfiguration().localDanmakuSourceDirPath
        lu.assertNotNil(dir)

        local filePaths1 = {}
        local filePaths2 = {}
        self:_writeEmptyFiles(dir, { "1.p1", "2.p1", "3.p1" }, filePaths1)
        self:_writeEmptyFiles(dir, { "1.p2", "2.p2", "3.p2" }, filePaths2)

        local plugin1 = MockPlugin:new("1", ".*%.p1$")
        local plugin2 = MockPlugin:new("2", ".*%.p2$")
        app:addDanmakuSourcePlugin(plugin1)
        app:addDanmakuSourcePlugin(plugin2)
        __assertPluginMatchedFilePaths(app, manager, plugin1, filePaths1)
        __assertPluginMatchedFilePaths(app, manager, plugin2, filePaths2)

        -- 匹配插件有优先级
        local filePaths3 = {}
        self:_writeEmptyFiles(dir, { "1.p3", "2.p4", "3.p5" }, filePaths3)

        local plugin3 = MockPlugin:new("3", ".*%.p[0-9]$")
        app:addDanmakuSourcePlugin(plugin3)
        __assertPluginMatchedFilePaths(app, manager, plugin3, filePaths3)
    end,


    testAddAndRemoveSource = function(self)
        local function __createRandomOffsetsAndURLs(self, conn)
            local count = math.random(10)
            local urls = {}
            local offsets = {}
            for i = 1, count
            do
                table.insert(offsets, math.random(100))
                table.insert(urls, self:_getRandomURL())
            end
            return offsets, urls
        end

        local app = self._mApplication
        local manager = self._mDanmakuSourceManager
        local dir = app:getConfiguration().danmakuSourceRawDataDirPath

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
                table.insert(urls, self:_getRandomURL())
                table.insert(offsets, math.random(100))
            end

            local plugin = plugins[math.random(pluginCount)]
            table.insert(srcPlugins, plugin)
            table.insert(srcOffsets, offsets)
            table.insert(srcURLs, urls)

            -- 每次添加都会写一次序列化文件
            local source = manager:addDanmakuSource(plugin, tostring(i), offsets, urls)
            lu.assertNotNil(source)
            manager:recycleDanmakuSource(source)
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
        manager:listDanmakuSources(sources)
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
            manager:deleteDanmakuSource(removeSource)
            for _, filePath in ipairs(filePaths)
            do
                lu.assertFalse(app:isExistedFile(filePath))
            end

            manager:listDanmakuSources(utils.clearTable(sources))
            __assertDanmakuSources(sources, srcPlugins, srcOffsets, srcURLs)
            lu.assertEquals(#sources, count - 1)
        end
    end,


    testUpdateSource = function(self)
        local app = self._mApplication
        local conn = app:getNetworkConnection()
        local manager = self._mDanmakuSourceManager
        local plugin = MockPlugin:new("mock_plugin")
        app:addDanmakuSourcePlugin(plugin)

        local urls = {}
        local offsets = {}
        local filePaths = {}
        for i = 1, 10
        do
            local urlCount = math.random(5)
            for j = 1, urlCount
            do
                table.insert(urls, self:_getRandomURL())
                table.insert(offsets, math.random(1000))
            end

            local source = manager:addDanmakuSource(plugin, nil, offsets, urls)
            lu.assertNotNil(source)

            -- 因为某些文件下载不来，应该是更新失败的
            for j = 1, math.random(urlCount)
            do
                conn:setResponse(urls[math.random(urlCount)], nil)
            end
            local source2 = manager:updateDanmakuSource(source)
            lu.assertNil(source2)

            -- 更改下载的内容
            for j = 1, urlCount
            do
                conn:setResponse(urls[j], tostring(j))
            end
            source2 = manager:updateDanmakuSource(source)
            lu.assertNotNil(source2)
            for j, filePath in ipairs(source2._mFilePaths)
            do
                local content = utils.readAndCloseFile(app:readFile(filePath))
                lu.assertNotNil(content)
                lu.assertEquals(tonumber(content), j)
            end

            manager:deleteDanmakuSource(source)
            manager:deleteDanmakuSource(source2)

            -- 更新失败后的临时文件应该被删除
            local cfg = app:getConfiguration()
            app:listFiles(cfg.danmakuSourceRawDataDirPath, filePaths)
            lu.assertTrue(types.isEmptyTable(filePaths))

            utils.clearTable(filePaths)
            utils.clearTable(urls)
            utils.clearTable(offsets)
            conn:clearAllResponses()
            manager:recycleDanmakuSource(source)
            manager:recycleDanmakuSource(source2)
        end
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())