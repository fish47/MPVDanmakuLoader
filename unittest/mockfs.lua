local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")


local _BridgedFile =
{
    _mFile      = classlite.declareConstantField(nil),

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
            return found and node or nil
        end
    end,
}

classlite.declareClass(_MockFileSystemTreeNode)


local MockFileSystem =
{
    _mFreeNodes     = classlite.declareTableField(),
    _mRootNode      = classlite.declareClassField(_MockFileSystemTreeNode, "/"),

    setup = function(self)
        local orgIsOpenedFileFunc = types.isOpenedFile
        types.isOpenedFile = function(f)
            f = classlite.isInstanceOf(f, _BridgedFile) and f:getFile() or f
            return orgIsOpenedFileFunc(f)
        end

        local orgIsClosedFileFunc = types.isClosedFile
        types.isClosedFile = function(f)
            f = classlite.isInstanceOf(f, _BridgedFile) and f:getFile() or f
            return orgIsClosedFileFunc(f)
        end
    end,

    dispose = function(self)
        self:_doDeleteTreeNode(self._mRootNode)
        for _, node in ipairs(self._mFreeNodes)
        do
            node:dispose()
        end
    end,

    __doIteratePathElements = function(self, fullPath, findNodeFunc)
        local node = nil
        local parent = node
        local found = nil
        for i, path in unportable.iteratePathElements(fullPath)
        do
            -- 不管是否能尽早得出结果，尽可能走完迭代可减少 table 生成
            if found == nil or found
            then
                parent, node = findNodeFunc(i, path, parent, node)
                found = types.toBoolean(node)
            end
        end

        if found
        then
            return parent, node
        end
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
        return ret and ret or _MockFileSystemTreeNode:new()
    end,

    doesFileExist = function(self, fullPath)
        local _, node = self:_seekToNode(fullPath)
        return node and node:isFile()
    end,

    writeFile = function(self, fullPath)
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

            local f = _BridgedFile:new(io.tmpfile())
            local orgCloseFunc = f.close
            f.close = function(self)
                self:seek(constants.SEEK_MODE_BEGIN)
                fileNode.content = self:read(constants.READ_MODE_ALL)
                orgCloseFunc(self)
            end

            return f
        end
    end,

    readFile = function(self, fullPath)
        local _, fileNode = self:_seekToNode(fullPath)
        if fileNode and fileNode:isFile()
        then
            local f = _BridgedFile:new(io.tmpfile())
            f:write(fileNode.content)
            f:seek(constants.SEEK_MODE_BEGIN)
            return f
        end
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
        local children = node.children
        for i, child in ipairs(children)
        do
            children[i] = nil
            self:_doDeleteTreeNode(child)
        end
        node.name = nil
        node.content = nil
        table.insert(self._mFreeNodes, node)
    end,

    deleteTree = function(self, fullPath)
        local dirNode, node = self:_seekToNode(fullPath)
        if dirNode and node
        then
            utils.removeArrayElement(dirNode.children, node)
            self:_doDeleteTreeNode(node)
            return true
        end
        return false
    end,
}

classlite.declareClass(MockFileSystem)


return
{
    MockFileSystem      = MockFileSystem,
}