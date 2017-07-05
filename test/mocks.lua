local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local application   = require("src/shell/application")
local config        = require("src/shell/config")
local sourcemgr     = require("src/shell/sourcemgr")


local _MockFileSystemTreeNode =
{
    name        = classlite.declareConstantField(nil),
    content     = classlite.declareConstantField(nil),
    children    = classlite.declareTableField(),
}

function _MockFileSystemTreeNode:new(name, content)
    self.name = name
    self.content = content
end

function _MockFileSystemTreeNode:isFile()
    return types.isString(self.content)
end

function _MockFileSystemTreeNode:isDir()
    return not self:isFile()
end

function _MockFileSystemTreeNode:findChildByName(name)
    if self:isFile()
    then
        return nil
    else
        local function func(node, findName)
            return node.name == findName
        end
        local found, _, node = utils.linearSearchArrayIf(self.children, func, name)
        return found and node
    end
end

classlite.declareClass(_MockFileSystemTreeNode)


local MockFileSystem =
{
    _mFreeNodes             = classlite.declareTableField(),
    _mRootNode              = classlite.declareClassField(_MockFileSystemTreeNode, "/"),
    _mPendingFileSet        = classlite.declareTableField(),
    _mPathElementIterator   = classlite.declareClassField(unportable.PathElementIterator),
}

function MockFileSystem:dispose()
    utils.forEachTableKey(self._mPendingFileSet, utils.closeSafely)
    self:_doDeleteTreeNode(self._mRootNode)
    utils.forEachArrayElement(self._mFreeNodes, utils.disposeSafely)
end

function MockFileSystem:__doIteratePathElements(fullPath, findNodeFunc)
    local node = nil
    local parent = node
    local found = true
    for i, path in self._mPathElementIterator:iterate(fullPath)
    do
        -- 尽可能走完迭代可减少 table 生成，虽然某些情况下很早就得出结果
        if found
        then
            parent, node = findNodeFunc(i, path, parent, node)
            found = types.toBoolean(node)
        end
    end
    return found and parent, node
end

function MockFileSystem:_seekToNode(fullPath)
    local function __findNode(i, path, parent, node)
        if i == 1
        then
            -- 参数要求是绝对路径
            node = self._mRootNode
            parent = nil
        else
            parent = node
            node = parent:findChildByName(path)
        end

        -- 文件(夹)名对不上
        if node and node.name ~= path
        then
            parent = nil
            node = nil
        end

        return parent, node
    end

    return self:__doIteratePathElements(fullPath, __findNode)
end

function MockFileSystem:_obtainTreeNode()
    local ret = utils.popArrayElement(self._mFreeNodes)
    ret = ret or _MockFileSystemTreeNode:new()
    utils.clearTable(ret.children)
    return ret
end

function MockFileSystem:_doCreateBridgedFile(fullPath)
    local f = _BridgedFile:new(io.tmpfile())
    local orgCloseFunc = f.close
    local pendingFiles = self._mPendingFileSet
    pendingFiles[f] = true
    f.close = function(self, ...)
        if types.isOpenedFile(self:getFile())
        then
            orgCloseFunc(self, ...)
            pendingFiles[f] = nil
        end
    end
    return f
end

function MockFileSystem:isExistedFile(fullPath)
    local _, node = self:_seekToNode(fullPath)
    return node and node:isFile()
end

function MockFileSystem:isExistedDir(fullPath)
    local _, node = self:_seekToNode(fullPath)
    return node and node:isDir()
end

function MockFileSystem:writeFile(fullPath, mode)
    local dirName, fileName = unportable.splitPath(fullPath)
    local _, dirNode = self:_seekToNode(dirName)
    local fileNode = dirNode and dirNode:findChildByName(fileName)
    if not dirNode
    then
        -- 没有创建对应的文件夹
        return nil
    elseif fileNode and fileNode:isDir()
    then
        -- 不能写文件夹
        return nil
    else
        if not fileNode
        then
            fileNode = self:_obtainTreeNode()
            fileNode.name = fileName
            fileNode.content = constants.STR_EMPTY
            table.insert(dirNode.children, fileNode)
        end

        local fs = self
        local f = self:_doCreateBridgedFile(fullPath)
        local orgCloseFunc = f.close
        f.close = function(self)
            if types.isOpenedFile(self:getFile())
            then
                self:seek(constants.SEEK_MODE_BEGIN)
                local content = self:read(constants.READ_MODE_ALL)

                -- 一定要重新搜结点，在打开到关闭期间，可能文件结构已经改变了
                local _, fileNode = fs:_seekToNode(fullPath)
                if fileNode and fileNode:isFile()
                then
                    if mode == constants.FILE_MODE_WRITE_APPEND
                    then
                        content = fileNode.content .. content
                    end
                    fileNode.content = content
                end

                orgCloseFunc(self)
            end
        end

        return f
    end
end

function MockFileSystem:readFile(fullPath)
    local _, fileNode = self:_seekToNode(fullPath)
    if fileNode and fileNode:isFile()
    then
        local f = self:_doCreateBridgedFile(fullPath)
        f:write(fileNode.content)
        f:seek(constants.SEEK_MODE_BEGIN)
        return f
    end
end

function MockFileSystem:readUTF8File(fullPath)
    return self:readFile(fullPath)
end

function MockFileSystem:createDir(fullPath)
    local function __ensureDir(i, path, parent, node)
        if i == 1
        then
            -- 注意有可能是绝对路径
            parent = nil
            node = self._mRootNode
            node = node.name == path and node or nil
        else
            parent = node
            node = parent:findChildByName(path)
            if not node
            then
                node = self:_obtainTreeNode()
                node.name = path
                table.insert(parent.children, node)
            end
        end
        return parent, node
    end

    local parent, node = self:__doIteratePathElements(fullPath, __ensureDir)
    return types.toBoolean(parent and node)
end

function MockFileSystem:_doDeleteTreeNode(node)
    if node
    then
        local children = node.children
        for i, child in utils.iterateArray(children)
        do
            children[i] = nil
            self:_doDeleteTreeNode(child)
        end
        node.name = nil
        node.content = nil
        table.insert(self._mFreeNodes, node)
    end
end

function MockFileSystem:deletePath(fullPath)
    local dirNode, node = self:_seekToNode(fullPath)
    if dirNode and node
    then
        utils.removeArrayElements(dirNode.children, node)
        self:_doDeleteTreeNode(node)
        return true
    end
    return false
end

function MockFileSystem:listFiles(dir, outList)
    utils.clearTable(outList)
    local _, node = self:_seekToNode(dir)
    if node and node:isDir()
    then
        for _, child in ipairs(node.children)
        do
            if child:isFile()
            then
                local fullPath = unportable.joinPath(dir, child.name)
                table.insert(outList, fullPath)
            end
        end
    end
    return false
end

classlite.declareClass(MockFileSystem)


local MockNetworkConnection =
{
    _mResponseMap    = classlite.declareTableField(),
}

function MockNetworkConnection:setResponse(url, content)
    if types.isString(url) and (types.isString(content) or content == nil)
    then
        self._mResponseMap[url] = content
    end
end

function MockNetworkConnection:clearAllResponses()
    utils.clearTable(self._mResponseMap)
end

function MockNetworkConnection:_requestURLs(urls, results)
    for idx, url in utils.iterateArray(urls)
    do
        local content = self._mResponseMap[url]
        table.insert(results, content)
    end
end

classlite.declareClass(MockNetworkConnection, unportable.NetworkConnection)


local MockApplication =
{
    _mNetworkConnection = classlite.declareClassField(MockNetworkConnection),
    _mMockFileSystem    = classlite.declareClassField(MockFileSystem),

    _initDanmakuSourcePlugins = constants.FUNC_EMPTY,
}

function MockApplication:_getCurrentDirPath()
    return "/mpvdanmakuloader/"
end

function MockApplication:getVideoFileMD5()
    return string.rep("1", 32)
end

function MockApplication:_updateConfiguration(cfg)
    config.updateConfiguration(self, nil, cfg, nil)
    cfg.rawDataDirName = "1/2/3/rawdata"
    cfg.metaDataFileName = "4/5/6/meta.lua"
end

-- 将文件相关操作转交给虚拟文件系统
for _, methodName in ipairs({ "isExistedDir",
                              "isExistedFile",
                              "readUTF8File",
                              "readFile",
                              "writeFile",
                              "createDir",
                              "deletePath",
                              "listFiles" })
do
    MockApplication[methodName] = function(self, ...)
        local mockfs = self._mMockFileSystem
        return mockfs[methodName](mockfs, ...)
    end
end

classlite.declareClass(MockApplication, application.MPVDanmakuLoaderApp)


local MockDanmakuSourceManager = {}

function MockDanmakuSourceManager:_doReadMetaFile(callback)
    local app = self._mApplication
    local path = app:getDanmakuSourceMetaDataFilePath()
    local content = utils.readAndCloseFile(app:readFile(path))
    serialize.deserializeFromString(content, callback)
end

classlite.declareClass(MockDanmakuSourceManager, sourcemgr.DanmakuSourceManager)


return
{
    MockFileSystem              = MockFileSystem,
    MockNetworkConnection       = MockNetworkConnection,
    MockApplication             = MockApplication,
    MockDanmakuSourceManager    = MockDanmakuSourceManager,
}