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

    downloadRawDatas = function(self, ids, outDatas)
        utils.appendArrayElements(outDatas, ids)
    end,

    isMatchedRawDataFile = function(self, fullPath)
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
    _mRandomSourceIDCount   = nil,

    setUp = function(self)
        self._mApplication = mocks.MockApplication:new()
        self._mDanmakuSourceManager = mocks.MockDanmakuSourceManager:new()
        self._mDanmakuSourceManager:setApplication(self._mApplication)
        self._mRandomSourceIDCount = 0
    end,

    tearDown = function(self)
        self._mApplication:dispose()
        self._mDanmakuSourceManager:dispose()
    end,

    _getRandomSourceID = function(self)
        local id = self._mRandomSourceIDCount
        self._mRandomSourceIDCount = id + 1
        return string.format("SourceID_%d", id)
    end,

    _getRandomDanmakuSourceParams = function(self, ids, offsets, count)
        ids = utils.clearTable(ids) or {}
        offsets = utils.clearTable(offsets) or {}
        count = count or math.random(10)
        for i = 1, count
        do
            table.insert(ids, self:_getRandomSourceID())
            table.insert(offsets, math.random(1000))
        end
        return ids, offsets
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

        local srcIDs = {}
        local srcOffsets = {}
        local srcPlugins = {}
        local sourceCount = math.random(100)
        for i = 1, sourceCount
        do
            local ids, offsets = self:_getRandomDanmakuSourceParams()
            local plugin = plugins[math.random(pluginCount)]
            table.insert(srcPlugins, plugin)
            table.insert(srcIDs, ids)
            table.insert(srcOffsets, offsets)

            -- 每次添加都会写一次序列化文件
            local source = manager:addDanmakuSource(plugin, tostring(i), ids, offsets)
            lu.assertNotNil(source)
            manager:recycleDanmakuSource(source)
        end

        local function __assertDanmakuSources(sources, plugins, ids, offsets)
            for _, source in ipairs(sources)
            do
                local idx = tonumber(source:getDescription())
                lu.assertNotNil(idx)
                lu.assertIs(source._mPlugin, plugins[idx])

                local ids1, ids2 = source._mSourceIDs, ids[idx]
                local offsets1, offsets2 = source._mTimeOffsets, offsets[idx]
                lu.assertEquals(#ids1, #ids2)
                lu.assertEquals(#offsets1, #offsets2)
                lu.assertTrue(#ids1 == #offsets1)

                -- 顺序不一定相同，但保证是平行对应的
                for i = 1, #ids1
                do
                    local id1 = ids1[i]
                    local found, searchIdx = utils.linearSearchArray(ids2, id1)
                    lu.assertTrue(found)
                    lu.assertEquals(ids1[i], ids2[searchIdx])
                    lu.assertEquals(offsets1[i], offsets2[searchIdx])
                end
            end
        end

        -- 看一下反序列化正不正确
        local sources = {}
        manager:listDanmakuSources(sources)
        __assertDanmakuSources(sources, srcPlugins, srcIDs, srcOffsets)

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
            __assertDanmakuSources(sources, srcPlugins, srcIDs, srcOffsets)
            lu.assertEquals(#sources, count - 1)
        end
    end,


    testUpdateSource = function(self)
        local app = self._mApplication
        local manager = self._mDanmakuSourceManager
        local plugin = MockPlugin:new("mock_plugin")
        app:addDanmakuSourcePlugin(plugin)

        local ids = {}
        local offsets = {}
        local filePaths = {}
        local sources = {}
        for i = 1, 10
        do
            local urlCount = 5
            self:_getRandomDanmakuSourceParams(ids, offsets, urlCount)

            local source = manager:addDanmakuSource(plugin, nil, ids, offsets)
            lu.assertNotNil(source)

            -- 因为某些文件下载不来，应该是更新失败的
            local orgDownloadFunc = plugin.downloadRawDatas
            plugin.downloadRawDatas = constants.FUNC_EMPTY
            utils.clearTable(sources)
            table.insert(sources, source)
            manager:updateDanmakuSources(sources, sources)
            lu.assertEquals(#sources, 1)

            -- 更改回来应该可以更新成功了
            plugin.downloadRawDatas = orgDownloadFunc
            manager:updateDanmakuSources(sources, sources)
            lu.assertEquals(#sources, 2)

            local source2 = sources[2]
            for j, filePath in ipairs(source2._mFilePaths)
            do
                local content = utils.readAndCloseFile(app:readFile(filePath))
                lu.assertNotNil(content)
                lu.assertEquals(content, source2._mSourceIDs[j])
            end

            -- 更新失败的临时文件应该被删除
            manager:deleteDanmakuSource(source)
            manager:deleteDanmakuSource(source2)

            local cfg = app:getConfiguration()
            utils.clearTable(filePaths)
            app:listFiles(cfg.danmakuSourceRawDataDirPath, filePaths)
            lu.assertTrue(types.isEmptyTable(filePaths))
        end
    end,


    testUpdateSameSource = function(self)
        local app = self._mApplication
        local manager = self._mDanmakuSourceManager
        local plugin = MockPlugin:new("mock_plugin")
        app:addDanmakuSourcePlugin(plugin)

        local ids, offsets = self:_getRandomDanmakuSourceParams({}, {}, 5)
        local source1 = manager:addDanmakuSource(plugin, nil, ids, offsets)
        lu.assertNotNil(source1)

        local function __swapArraysElement(idx1, idx2, ...)
            for i = 1, types.getVarArgCount(...)
            do
                local array = select(i, ...)
                local a, b = array[idx1], array[idx2]
                array[idx1] = b
                array[idx2] = a
            end
        end

        __swapArraysElement(1, 5, ids, offsets)

        -- 不阻止重复添加，因为下载的内容可能有变化，但来源确定是相同的
        local source2 = manager:addDanmakuSource(plugin, "clone", ids, offsets)
        lu.assertNotNil(source2)
        lu.assertTrue(source1:_isFromSameUpdateSource(app, source2))

        -- 既然有 2 个来源相同，那么只更新一次
        local sources = { source1, source2 }
        manager:updateDanmakuSources(sources, sources)
        lu.assertEquals(#sources, 3)
        lu.assertTrue(source1:_isFromSameUpdateSource(app, sources[3]))

        manager:recycleDanmakuSources(sources)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())