local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _PATH_SEPERATOR                   = "/"
local _PATH_ROOT_DIR                    = "/"
local _PATH_CURRENT_DIR                 = "."
local _PATH_PARENT_DIR                  = ".."
local _PATH_PATTERN_ELEMENT             = "[^/]+"
local _PATH_PATTERN_STARTS_WITH_ROOT    = "^/"

local __gPathElements1      = {}
local __gPathElements2      = {}


local function __splitPathElements(fullPath, paths)
    utils.clearTable(paths)

    if not types.isString(fullPath)
    then
        return false
    end

    -- 将 / 作为单独的路径
    if fullPath:match(_PATH_PATTERN_STARTS_WITH_ROOT)
    then
        table.insert(paths, _PATH_ROOT_DIR)
    end

    for path in fullPath:gmatch(_PATH_PATTERN_ELEMENT)
    do
        if path == _PATH_PARENT_DIR
        then
            local pathCount = #paths
            local lastPathElement = paths[pathCount]
            if not lastPathElement or lastPathElement == _PATH_PARENT_DIR
            then
                table.insert(paths, _PATH_PARENT_DIR)
            elseif lastPathElement == _PATH_ROOT_DIR
            then
                -- 不允许用 .. 将 / 弹出栈，例如 "/../../a" 实际指的是 "/"
            else
                paths[pathCount] = nil
            end
        elseif path == _PATH_CURRENT_DIR
        then
            -- 指向当前文件夹
        else
            table.insert(paths, path)
        end
    end
    return true
end


local function __joinPathElements(paths)
    -- 路径退栈
    local writeIdx = 1
    for i, path in ipairs(paths)
    do
        local insertPath = nil
        if path == _PATH_CURRENT_DIR
        then
            -- ingore
        elseif path == _PATH_PARENT_DIR
        then
            if writeIdx == 1 or paths[writeIdx - 1] == _PATH_PARENT_DIR
            then
                insertPath = _PATH_PARENT_DIR
            else
                writeIdx = writeIdx - 1
            end
        else
            insertPath = path
        end

        if insertPath
        then
            paths[writeIdx] = insertPath
            writeIdx = writeIdx + 1
        end
    end
    utils.clearArray(paths, writeIdx)

    local ret = nil
    if paths[1] == _PATH_ROOT_DIR
    then
        local trailing = table.concat(paths, _PATH_SEPERATOR, 2)
        ret = _PATH_ROOT_DIR .. trailing
    else
        ret = table.concat(paths, _PATH_SEPERATOR)
    end
    utils.clearTable(paths)
    return ret
end



local PathElementIterator =
{
    _mTablePool     = classlite.declareTableField(),
    _mIterateFunc   = classlite.declareConstantField(),
}

function PathElementIterator:new()
    self._mIterateFunc = function(paths, idx)
        idx = idx + 1
        if idx > #paths
        then
            -- 如果是中途 break 出来，就让虚拟机回收吧
            self:_recycleTable(paths)
            return nil
        else
            return idx, paths[idx]
        end
    end
end

function PathElementIterator:_obtainTable()
    return utils.popArrayElement(self._mTablePool) or {}
end

function PathElementIterator:_recycleTable(tbl)
    local pool = self._mTablePool
    if types.isTable(pool)
    then
        utils.clearTable(tbl)
        table.insert(pool, tbl)
    end
end

function PathElementIterator:iterate(fullPath)
    local paths = self:_obtainTable()
    if __splitPathElements(fullPath, paths)
    then
        return self._mIterateFunc, paths, 0
    else
        self:_recycleTable(paths)
        return constants.FUNC_EMPTY
    end
end

classlite.declareClass(PathElementIterator)


local function normalizePath(fullPath)
    local paths = utils.clearTable(__gPathElements1)
    local succeed = __splitPathElements(fullPath, paths)
    local ret = succeed and __joinPathElements(paths)
    utils.clearTable(paths)
    return ret
end


local function joinPath(dirName, pathName)
    local ret = nil
    if types.isString(dirName) and types.isString(pathName)
    then
        local paths = utils.clearTable(__gPathElements1)
        local fullPath = dirName .. _PATH_SEPERATOR .. pathName
        if __splitPathElements(fullPath, paths)
        then
            ret = __joinPathElements(paths)
        end
        utils.clearTable(paths)
    end
    return ret
end


local function splitPath(fullPath)
    local baseName = nil
    local dirName = nil
    local paths = utils.clearTable(__gPathElements1)
    local succeed = __splitPathElements(fullPath, paths)
    if succeed
    then
        baseName = utils.popArrayElement(paths)
        dirName = __joinPathElements(paths)
    end
    utils.clearTable(paths)
    return dirName, baseName
end


local function getRelativePath(dir, fullPath)
    local ret = nil
    local paths1 = utils.clearTable(__gPathElements1)
    local paths2 = utils.clearTable(__gPathElements2)
    local succeed1 = __splitPathElements(dir, paths1)
    local succeed2 = __splitPathElements(fullPath, paths2)
    if succeed1 and succeed2 and #paths1 > 0 and #paths2 > 0
    then
        -- 找出第一个不同的路径元素
        local paths1Count = #paths1
        local relIdx = paths1Count + 1
        for i = 1, paths1Count
        do
            local comparePath = paths2[i]
            if comparePath and paths1[i] ~= comparePath
            then
                relIdx = i
                break
            end
        end

        -- 有可能两个路径是一样的，提前特判
        local paths2Count = #paths2
        if paths1Count == paths2Count and relIdx > paths1Count
        then
            return _PATH_CURRENT_DIR
        end

        -- 前缀不一定完全匹配的，例如 /1 相对于 /a/b/c/d 路径是 ../../../../1
        local outPaths = utils.clearTable(paths1)
        local parentDirCount = paths1Count - relIdx + 1
        for i = 1, parentDirCount
        do
            table.insert(outPaths, _PATH_PARENT_DIR)
        end

        for i = relIdx, #paths2
        do
            table.insert(outPaths, paths2[i])
        end
        ret = __joinPathElements(outPaths)
    end

    utils.clearTable(paths1)
    utils.clearTable(paths2)
    return ret
end


local _UNIQUE_PATH_FMT_FILE_NAME    = "%s%s%03d%s"
local _UNIQUE_PATH_FMT_TIME_PREFIX  = "%y%m%d%H%M"

local UniquePathGenerator =
{
    _mUniquePathID      = classlite.declareConstantField(1),
}

function UniquePathGenerator:getUniquePath(dir, prefix, suffix,
                                           isExistedFunc, funcArg)
    local timeStr = os.date(_UNIQUE_PATH_FMT_TIME_PREFIX)
    prefix = types.isString(prefix) and prefix or constants.STR_EMPTY
    suffix = types.isString(suffix) and suffix or constants.STR_EMPTY
    while true
    do
        local pathID = self._mUniquePathID
        self._mUniquePathID = pathID + 1

        local fileName = string.format(_UNIQUE_PATH_FMT_FILE_NAME, prefix, timeStr, pathID, suffix)
        local fullPath = joinPath(dir, fileName)
        if not isExistedFunc(funcArg, fullPath)
        then
            return fullPath
        end
    end
end

classlite.declareClass(UniquePathGenerator)


return
{
    normalizePath               = normalizePath,
    joinPath                    = joinPath,
    splitPath                   = splitPath,
    getRelativePath             = getRelativePath,

    PathElementIterator         = PathElementIterator,
    UniquePathGenerator         = UniquePathGenerator,
}