local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")


local _SERIALIZE_FUNC_NAME                  = "_"
local _SERIALIZE_FUNC_START                 = "("
local _SERIALIZE_FUNC_END                   = ")"
local _SERIALIZE_SEP_ARG                    = ","
local _SERIALIZE_SEP_LINE                   = "\n"
local _SERIALIZE_QUOTE_STRING_FORMAT        = "%q"

local _DESERIALIZE_USE_LAGACY_ENV_SETUP     = constants.LUA_VERSION <= 5.1


local function serializeTuple(file, ...)
    if not file
    then
        return
    end

    file:write(_SERIALIZE_FUNC_NAME)
    file:write(_SERIALIZE_FUNC_START)

    local elementCount = types.getVarArgCount(...)
    for i = 1, elementCount
    do
        local elem = select(i, ...)
        if types.isString(elem)
        then
            file:write(string.format(_SERIALIZE_QUOTE_STRING_FORMAT, elem))
        elseif types.isConstant(elem)
        then
            file:write(tostring(elem))
        else
            -- 暂时不支持复杂类型的序列化
        end

        if i ~= elementCount
        then
            file:write(_SERIALIZE_SEP_ARG)
        end
    end

    file:write(_SERIALIZE_FUNC_END)
    file:write(_SERIALIZE_SEP_LINE)
end


local function __doDeserialize(input, isFilePath, callback)
    local compiledChunks = nil
    local loadEnv = { [_SERIALIZE_FUNC_NAME] = callback }
    if _DESERIALIZE_USE_LAGACY_ENV_SETUP
    then
        compiledChunks = isFilePath and loadfile(input) or load(input)
        if compiledChunks
        then
            setfenv(compiledChunks, loadEnv)
        end
    else
        compiledChunks = isFilePath
                         and loadfile(input, constants.LOAD_MODE_CHUNKS, loadEnv)
                         or load(input, nil, constants.LOAD_MODE_CHUNKS, loadEnv)
    end

    if compiledChunks
    then
        pcall(compiledChunks)
    end

    loadEnv = nil
    compiledChunks = nil
end


local function deserializeTupleFromFilePath(file, callback)
    return __doDeserialize(file, true, callback)
end

local function deserializeTupleFromString(chunks, callback)
    return __doDeserialize(chunks, false, callback)
end



local function __advanceQueueIndex(queueIdx, queueLen)
    queueIdx = queueIdx + 1
    queueIdx = queueIdx > queueLen and 1 or queueIdx
    return queueIdx
end



local function trimSerializedFile(fullPath, reserveCount)
    local queueStartIdx = 1
    local queueLastIdx = 1
    local queue = {}

    local function __doReadTuple(...)
        if #queue < reserveCount
        then
            table.insert(queue, {...})
            queueLastIdx = #queue
        else
            queue[queueStartIdx] = {...}
            queueStartIdx = __advanceQueueIndex(queueStartIdx, reserveCount)
            queueLastIdx = __advanceQueueIndex(queueLastIdx, reserveCount)
        end
    end

    -- 读入环型缓冲区
    deserializeTupleFromFilePath(fullPath, __doReadTuple)

    -- 写出到文件
    local file = io.open(fullPath, constants.FILE_MODE_WRITE_ERASE)
    if file
    then
        local queueIdx = queueStartIdx
        local tuple = queue[queueIdx]
        while tuple
        do
            serializeTuple(file, utils.unpackArray(tuple))
            utils.clearTable(tuple)
            queue[queueIdx] = nil

            queueIdx = __advanceQueueIndex(queueIdx, reserveCount)
            tuple = queue[queueIdx]
        end

        file:close()
    end

    utils.clearTable(queue)
end


return
{
    serializeTuple                  = serializeTuple,
    deserializeTupleFromFilePath    = deserializeTupleFromFilePath,
    deserializeTupleFromString      = deserializeTupleFromString,
    trimSerializedFile              = trimSerializedFile,
}