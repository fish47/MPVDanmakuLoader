local _algo     = require("src/base/_algo")
local _conv     = require("src/base/_conv")
local types     = require("src/base/types")
local constants = require("src/base/constants")


local _UNIQ_FN_DUP_INDEX_START              = 1
local _UNIQ_FN_SEP_DUP_INDEX                = "_"
local _UNIQ_FN_PATTERN_SPLIT_SUFFIX         = "(.*)(%.[^%.]+)"
local _UNIQ_FN_PATTERN_SPLIT_DUP_INDEX      = "(.*" .. _UNIQ_FN_SEP_DUP_INDEX .. ")(%d+)"

local function __isFileExisted(fullPath)
    local f = io.open(fullPath, constants.FILE_MODE_READ)
    if f
    then
        f:close()
        return true
    end

    return false
end

local function getUniqueFilePath(fullPath, checkFunc)
    checkFunc = checkFunc or __isFileExisted
    if not checkFunc(fullPath)
    then
        return fullPath
    end

    -- 分离出后缀名
    local basePath, suffix = fullPath:match(_UNIQ_FN_PATTERN_SPLIT_SUFFIX)
    basePath = basePath or fullPath
    suffix = suffix or constants.STR_EMPTY

    -- 分离出重复序号
    local basePath2, dupIdx = basePath:match(_UNIQ_FN_PATTERN_SPLIT_DUP_INDEX)
    basePath2 = basePath2 or basePath .. _UNIQ_FN_SEP_DUP_INDEX
    dupIdx = dupIdx and tonumber(dupIdx) or _UNIQ_FN_DUP_INDEX_START

    while true
    do
        local newFileName = basePath2 .. tostring(dupIdx) .. suffix
        if not checkFunc(newFileName)
        then
            return newFileName
        end

        -- 例如 a_1.txt 不成功，再枚举 a_2.txt 吧
        dupIdx = dupIdx + 1
    end

    -- 不应该出现
    return fullPath
end



local function invokeSafelly(func, ...)
    if types.isFunction(func)
    then
        -- 即使可能是最后一句，但明确 return 才是尾调用
        return func(...)
    end
end


local function __createSafeInvokeWrapper(funcName)
    local ret = function(obj)
        if types.isTable(obj)
        then
            invokeSafelly(obj[funcName], obj)
        end
    end

    return ret
end


local function writeAndCloseFile(f, content)
    if types.isOpenedFile(f)
    then
        local succeed = f:write(content)
        f:close()
        return succeed
    end
end


local function readAndCloseFile(f)
    if types.isOpenedFile(f)
    then
        local readRet = f:read(constants.READ_MODE_ALL)
        return readRet, f:close()
    end
end



local __exports =
{
    invokeSafelly       = invokeSafelly,
    closeSafely         = __createSafeInvokeWrapper("close"),
    disposeSafely       = __createSafeInvokeWrapper("dispose"),

    writeAndCloseFile   = writeAndCloseFile,
    readAndCloseFile    = readAndCloseFile,
    getUniqueFilePath   = getUniqueFilePath,
}

_algo.mergeTable(__exports, _algo)
_algo.mergeTable(__exports, _conv)
return __exports