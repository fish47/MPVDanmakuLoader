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
}

function MockPlugin:new(name, pattern)
    lu.assertTrue(types.isString(name))
    self._mName = name
    self._mPathPattern = pattern
end

function MockPlugin:getName()
    return self._mName
end

function MockPlugin:downloadDanmakuRawDatas(ids, outDatas)
    utils.appendArrayElements(outDatas, ids)
end

function MockPlugin:isMatchedRawDataFile(fullPath)
    local pattern = self._mPathPattern
    lu.assertTrue(types.isString(fullPath))
    return types.isString(pattern) and fullPath:match(pattern)
end

classlite.declareClass(MockPlugin, pluginbase.IDanmakuSourcePlugin)


TestDanmakuSourceManager =
{
    _mApplication           = nil,
    _mDanmakuSourceManager  = nil,
    _mRandomSourceIDCount   = nil,
    _mRandomFilePathCount   = nil,
}

function TestDanmakuSourceManager:setUp()
    self._mApplication = mocks.MockApplication:new()
    self._mApplication:updateConfiguration()
    self._mDanmakuSourceManager = mocks.MockDanmakuSourceManager:new()
    self._mDanmakuSourceManager:setApplication(self._mApplication)
    self._mRandomSourceIDCount = 0
    self._mRandomFilePathCount = 0
end

function TestDanmakuSourceManager:tearDown()
    self._mApplication:dispose()
    self._mDanmakuSourceManager:dispose()
end

function TestDanmakuSourceManager:_createRandomFiles(count, outPaths)
    local app = self._mApplication
    local dir = "/test/random_files"
    app:createDir(dir)
    for i = 1, count
    do
        local idx = self._mRandomFilePathCount
        local fullPath = unportable.joinPath(dir, string.format("file_%d", idx))
        self._mRandomFilePathCount = idx + 1

        local f = app:writeFile(fullPath)
        f:write("")
        app:closeFile(f)
        table.insert(outPaths, fullPath)
    end
end

function TestDanmakuSourceManager:_getRandomVideoID()
    local id = self._mRandomSourceIDCount
    self._mRandomSourceIDCount = id + 1
    return string.format("VideoID_%d", id)
end

function TestDanmakuSourceManager:_getRandomDanmakuSourceParams(ids, offsets, count)
    ids = utils.clearTable(ids) or {}
    offsets = utils.clearTable(offsets) or {}
    count = count or math.random(10)
    for i = 1, count
    do
        table.insert(ids, self:_getRandomVideoID())
        table.insert(offsets, math.random(1000))
    end
    return ids, offsets
end


function TestDanmakuSourceManager:testAddAndRemoveCachedSource()
    local app = self._mApplication
    local manager = self._mDanmakuSourceManager
    local dir = app:getDanmakuSourceRawDataDirPath()

    local plugins = {}
    local pluginCount = math.random(50)
    for i = 1, pluginCount
    do
        local plugin = MockPlugin:new(string.format("Plugin_%d", i))
        table.insert(plugins, plugin)
        app:_addDanmakuSourcePlugin(plugin)
    end

    local srcIDs = {}
    local srcOffsets = {}
    local srcPlugins = {}
    local sources = {}
    local sourceCount = math.random(5)
    for i = 1, sourceCount
    do
        local ids, offsets = self:_getRandomDanmakuSourceParams()
        local plugin = plugins[math.random(pluginCount)]
        table.insert(srcPlugins, plugin)
        table.insert(srcIDs, ids)
        table.insert(srcOffsets, offsets)

        -- 每次添加都会写一次序列化文件
        -- 因为不保证反序列化后的顺序，所以这里用描述来指定原始数据的索引
        local source = manager:addCachedDanmakuSource(sources, plugin, tostring(i), ids, offsets)
        lu.assertNotNil(source)
    end

    local function __assertDanmakuSourcesValid(sources, plugins, ids, offsets)
        for _, source in ipairs(sources)
        do
            local idx = tonumber(source:getDescription())
            lu.assertNotNil(idx)
            lu.assertIs(source._mPlugin, plugins[idx])

            local ids1, ids2 = source._mVideoIDs, ids[idx]
            local offsets1, offsets2 = source._mStartTimeOffsets, offsets[idx]
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
    manager:recycleDanmakuSources(sources)
    manager:listDanmakuSources(sources)
    __assertDanmakuSourcesValid(sources, srcPlugins, srcIDs, srcOffsets)

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
        local removeIdx = math.random(count)
        local removeSource = sources[removeIdx]
        utils.clearTable(filePaths)
        utils.appendArrayElements(filePaths, removeSource._mFilePaths)
        manager:deleteDanmakuSourceByIndex(sources, removeIdx)
        for _, filePath in ipairs(filePaths)
        do
            lu.assertFalse(app:isExistedFile(filePath))
        end

        manager:recycleDanmakuSources(sources)
        manager:listDanmakuSources(sources)
        __assertDanmakuSourcesValid(sources, srcPlugins, srcIDs, srcOffsets)
        lu.assertEquals(#sources, count - 1)
    end
end


function TestDanmakuSourceManager:testUpdateSource()
    local app = self._mApplication
    local manager = self._mDanmakuSourceManager
    local plugin = MockPlugin:new("mock_plugin")
    app:_addDanmakuSourcePlugin(plugin)

    local ids = {}
    local offsets = {}
    local sources = {}
    local filePaths1 = {}
    local filePaths2 = {}
    for i = 1, 10
    do
        local urlCount = math.random(30)
        self:_getRandomDanmakuSourceParams(ids, offsets, urlCount)

        local source = manager:addCachedDanmakuSource(sources, plugin, nil, ids, offsets)
        lu.assertNotNil(source)

        -- 因为某些文件下载不来，应该是更新失败的
        local orgDownloadFunc = plugin.downloadDanmakuRawDatas
        plugin.downloadDanmakuRawDatas = constants.FUNC_EMPTY
        manager:updateDanmakuSources(sources, sources)
        lu.assertEquals(#sources, 1)

        -- 更改回来应该可以更新成功了
        plugin.downloadDanmakuRawDatas = orgDownloadFunc
        manager:updateDanmakuSources(sources, sources)
        lu.assertEquals(#sources, 2)

        -- 更新失败的临时文件应该被删除
        utils.clearTable(filePaths1)
        utils.clearTable(filePaths2)
        app:listFiles(app:getDanmakuSourceRawDataDirPath(), filePaths1)
        for i, source in utils.reverseIterateArray(sources)
        do
            utils.appendArrayElements(filePaths2, source._mFilePaths)
            manager:deleteDanmakuSourceByIndex(sources, i)
        end

        table.sort(filePaths1)
        table.sort(filePaths2)
        lu.assertEquals(filePaths1, filePaths2)
    end
end


function TestDanmakuSourceManager:testUpdateSameSource()
    local app = self._mApplication
    local manager = self._mDanmakuSourceManager
    local plugin = MockPlugin:new("mock_plugin")
    app:_addDanmakuSourcePlugin(plugin)

    local sources = {}
    local ids, offsets = self:_getRandomDanmakuSourceParams({}, {}, 5)
    local source1 = manager:addCachedDanmakuSource(sources, plugin, nil, ids, offsets)
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
    local source2 = manager:addCachedDanmakuSource(sources, plugin, "clone", ids, offsets)
    lu.assertNotNil(source2)
    lu.assertTrue(source1:_isDuplicated(source2))

    -- 既然有 2 个来源相同，那么只更新一次
    manager:updateDanmakuSources(sources, sources)
    lu.assertEquals(#sources, 3)
    lu.assertTrue(source1:_isDuplicated(sources[3]))

    manager:recycleDanmakuSources(sources)
end


function TestDanmakuSourceManager:testAddAndRemoveLocalSource()
    local function __assertLocalSourcesValid(sources, localFiles)
        lu.assertEquals(#sources, #localFiles)
        for i, source in ipairs(sources)
        do
            lu.assertEquals(source._mFilePath, localFiles[i])
        end
    end

    local app = self._mApplication
    local manager = self._mDanmakuSourceManager
    local plugin = MockPlugin:new("mock_plugin")
    app:_addDanmakuSourcePlugin(plugin)

    local sourceCount = math.random(10, 30)
    local localFiles = {}
    local sources = {}
    self:_createRandomFiles(sourceCount, localFiles)
    for i = 1, sourceCount
    do
        local newSource = manager:addLocalDanmakuSource(sources, plugin, localFiles[i])
        lu.assertNotNil(newSource)
    end

    -- 添加本地弹幕也有记录，反序列化时应该能找到回来
    manager:recycleDanmakuSources(sources)
    manager:listDanmakuSources(sources)
    __assertLocalSourcesValid(sources, localFiles)

    -- 删除也有记录
    for i, _ in utils.reverseIterateArray(sources)
    do
        manager:deleteDanmakuSourceByIndex(sources, i)
    end
    lu.assertTrue(types.isEmptyTable(sources))
    manager:listDanmakuSources(sources)
    lu.assertTrue(types.isEmptyTable(sources))
end


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())