local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local application   = require("src/shell/application")
local configuration = require("src/shell/configuration")
local sourcemgr     = require("src/shell/sourcemgr")


local _BridgedFile =
{
    _mFile      = classlite.declareConstantField(nil),

    new = function(self, f)
        self._mFile = f
    end,

    getFile = function(self)
        return self._mFile
    end,
}

for _, name in ipairs({ "close",
                        "flush",
                        "lines",
                        "read",
                        "seek",
                        "setvbuf",
                        "write", })
do
    _BridgedFile[name] = function(self, ...)
        local luaFile = self:getFile()
        return luaFile[name](luaFile, ...)
    end
end

classlite.declareClass(_BridgedFile)


local _MockFileSystemTreeNode =
{
    name        = classlite.declareConstantField(nil),
    content     = classlite.declareConstantField(nil),
    children    = classlite.declareTableField(),

    new = function(self, name, content)
        self.name = name
        self.content = content
    end,

    isFile = function(self)
        return types.isString(self.content)
    end,

    isDir = function(self)
        return not self:isFile()
    end,

    findChildByName = function(self, name)
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
    end,
}

classlite.declareClass(_MockFileSystemTreeNode)


local __gIsOpenedFileFunc   = types.isOpenedFile
local __gIsClosedFileFunc   = types.isClosedFile

local function __isOpenedFilePatched(f)
    f = classlite.isInstanceOf(f, _BridgedFile) and f:getFile() or f
    return (f)
end

local function __isClosedFilePatched(f)
    f = classlite.isInstanceOf(f, _BridgedFile) and f:getFile() or f
    return __gIsClosedFileFunc(f)
end


local function setupMockFSEnvironment()
    types.isOpenedFile = __isOpenedFilePatched
    types.isClosedFile = __isClosedFilePatched
end


local function unsetupMockFSEnvironment()
    types.isOpenedFile = __gIsOpenedFileFunc
    types.isClosedFile = __gIsClosedFileFunc
end


local MockFileSystem =
{
    _mFreeNodes         = classlite.declareTableField(),
    _mRootNode          = classlite.declareClassField(_MockFileSystemTreeNode, "/"),
    _mPendingFileSet    = classlite.declareTableField(),

    new = function(self)
        setupMockFSEnvironment()
    end,

    dispose = function(self)
        utils.forEachTableKey(self._mPendingFileSet, utils.closeSafely)
        self:_doDeleteTreeNode(self._mRootNode)
        utils.forEachArrayElement(self._mFreeNodes, utils.disposeSafely)
    end,

    __doIteratePathElements = function(self, fullPath, findNodeFunc)
        local node = nil
        local parent = node
        local found = true
        for i, path in unportable.iteratePathElements(fullPath)
        do
            -- 尽可能走完迭代可减少 table 生成，虽然某些情况下很早就得出结果
            if found
            then
                parent, node = findNodeFunc(i, path, parent, node)
                found = types.toBoolean(node)
            end
        end

        return found and parent, node
    end,

    _seekToNode = function(self, fullPath)
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
    end,

    _obtainTreeNode = function(self)
        local ret = utils.popArrayElement(self._mFreeNodes)
        ret = ret or _MockFileSystemTreeNode:new()
        utils.clearTable(ret.children)
        return ret
    end,

    _doCreateBridgedFile = function(self, fullPath)
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
    end,

    isExistedFile = function(self, fullPath)
        local _, node = self:_seekToNode(fullPath)
        return node and node:isFile()
    end,

    isExistedDir = function(self, fullPath)
        local _, node = self:_seekToNode(fullPath)
        return node and node:isDir()
    end,

    writeFile = function(self, fullPath, mode)
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
    end,

    readFile = function(self, fullPath)
        local _, fileNode = self:_seekToNode(fullPath)
        if fileNode and fileNode:isFile()
        then
            local f = self:_doCreateBridgedFile(fullPath)
            f:write(fileNode.content)
            f:seek(constants.SEEK_MODE_BEGIN)
            return f
        end
    end,

    readUTF8File = function(self, fullPath)
        return self:readFile(fullPath)
    end,

    createDir = function(self, fullPath)
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
    end,

    _doDeleteTreeNode = function(self, node)
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
    end,

    deleteTree = function(self, fullPath)
        local dirNode, node = self:_seekToNode(fullPath)
        if dirNode and node
        then
            utils.removeArrayElements(dirNode.children, node)
            self:_doDeleteTreeNode(node)
            return true
        end
        return false
    end,

    listFiles = function(self, dir, outList)
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
    end,
}

classlite.declareClass(MockFileSystem)


local MockNetworkConnection =
{
    _mResponseMap    = classlite.declareTableField(),

    setResponse = function(self, url, content)
        if types.isString(url) and (types.isString(content) or content == nil)
        then
            self._mResponseMap[url] = content
        end
    end,

    clearAllResponses = function(self)
        utils.clearTable(self._mResponseMap)
    end,

    _createConnection = function(self, url)
        local content = types.isString(url) and self._mResponseMap[url]
        return types.toBoolean(content), content
    end,

    _readConnection = function(self, conn)
        return conn
    end,
}

classlite.declareClass(MockNetworkConnection, unportable._NetworkConnectionBase)


local MockConfiguration =
{
    new = function(self)
        configuration.initConfiguration(self)
        self.rawDataRelDirPath = "1/2/3/rawdata"
        self.metaDataRelFilePath = "4/5/6/meta.lua"
    end,
}

classlite.declareClass(MockConfiguration)


local MockApplication =
{
    _mConfiguration     = classlite.declareClassField(MockConfiguration),
    _mNetworkConnection = classlite.declareClassField(MockNetworkConnection),
    _mMockFileSystem    = classlite.declareClassField(MockFileSystem),

    getMockFileSystem = function(self)
        return self._mMockFileSystem
    end,

    _initDanmakuSourcePlugins = constants.FUNC_EMPTY,

    _getPrivateDirPath = function(self)
        return "/mpvdanmakuloader/private_dir/"
    end,

    getVideoFileMD5 = function(self)
        return string.rep("1", 32)
    end,

    getVideoWidth = function(self)
        return 800
    end,

    getVideoHeight = function(self)
        return 600
    end,

    setSubtitleFile = function(self, path)
        -- do nothing
    end,

    setSubtitleData = function(self, data)
        -- do nothing
    end,
}

-- 将文件相关操作转交给虚拟文件系统
for _, methodName in ipairs({ "isExistedDir",
                              "isExistedFile",
                              "readUTF8File",
                              "readFile",
                              "writeFile",
                              "createDir",
                              "deleteTree",
                              "listFiles" })
do
    MockApplication[methodName] = function(self, ...)
        local mockfs = self._mMockFileSystem
        return mockfs[methodName](mockfs, ...)
    end
end

classlite.declareClass(MockApplication, application.MPVDanmakuLoaderApp)


local MockDanmakuSourceManager =
{
    _doReadMetaFile = function(self, callback)
        local app = self._mApplication
        local path = app:getDanmakuSourceMetaDataFilePath()
        local content = utils.readAndCloseFile(app:readFile(path))
        serialize.deserializeFromString(content, callback)
    end,
}

classlite.declareClass(MockDanmakuSourceManager, sourcemgr.DanmakuSourceManager)


return
{
    MockFileSystem              = MockFileSystem,
    MockNetworkConnection       = MockNetworkConnection,
    MockConfiguration           = MockConfiguration,
    MockApplication             = MockApplication,
    MockDanmakuSourceManager    = MockDanmakuSourceManager,

    setupMockFSEnvironment      = setupMockFSEnvironment,
    unsetupMockFSEnvironment    = unsetupMockFSEnvironment,
}
