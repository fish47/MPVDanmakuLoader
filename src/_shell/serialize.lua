local utils = require("src/utils")


local _SERIALIZE_FUNC_NAME                  = "_"
local _SERIALIZE_FUNC_START                 = "("
local _SERIALIZE_FUNC_END                   = ")"
local _SERIALIZE_SEP_ARG                    = ","
local _SERIALIZE_SEP_LINE                   = "\n"
local _SERIALIZE_QUOTE_STRING_FORMAT        = "%q"
local _SERIALIZE_TRIM_FILE_WRITE_MODE       = "w+"

local _DESERIALIZE_USE_LAGACY_SET_ENV_WAY   = utils.getLuaVersion() <= 5.1
local _DESERIALIZE_LOAD_READ_MODE           = "t"


local function __doGetSerializedTupleElement(element)
    local writeElement = nil
    if utils.isConstant(element)
    then
        writeElement = tostring(element)
    elseif utils.isString(element)
    then
        writeElement = string.format(_SERIALIZE_QUOTE_STRING_FORMAT, element)
    else
        -- 暂时不支持复杂类型的序列化
    end

    return writeElement
end


local function appendSerializedTupleToStream(file, tuple)
    file:write(_SERIALIZE_FUNC_NAME)
    file:write(_SERIALIZE_FUNC_START)

    local tupleLen = #tuple
    for i = 1, tupleLen
    do
        file:write(__doGetSerializedTupleElement(tuple[i]))

        if i ~= tupleLen
        then
            file:write(_SERIALIZE_SEP_ARG)
        end
    end

    file:write(_SERIALIZE_FUNC_END)
    file:write(_SERIALIZE_SEP_LINE)
end


local function doDeserializeTuple(input, isFilePath, callback)
    local compiledChunks = nil
    local loadEnv = { [_SERIALIZE_FUNC_NAME] = callback }
    if _DESERIALIZE_USE_LAGACY_SET_ENV_WAY
    then
        compiledChunks = isFilePath and loadfile(input) or load(input)
        if compiledChunks
        then
            setfenv(compiledChunks, loadEnv)
        end
    else
        compiledChunks = isFilePath
                         and loadfile(input, _DESERIALIZE_LOAD_READ_MODE, loadEnv)
                         or load(input, nil, _DESERIALIZE_LOAD_READ_MODE, loadEnv)
    end

    if compiledChunks
    then
        pcall(compiledChunks)
    end

    loadEnv = nil
    compiledChunks = nil
end


local function deserializeTupleFromFile(fullPath, callback)
    doDeserializeTuple(fullPath, true, callback)
end


local function deserializeTupleFromString(tupleString, callback)
    doDeserializeTuple(tupleString, false, callback)
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
            queueLastIdx = #queue - 1
        else
            queue[queueStartIdx] = {...}
            queueStartIdx = __advanceQueueIndex(queueStartIdx, reserveCount)
            queueLastIdx = __advanceQueueIndex(queueLastIdx, reserveCount)
        end
    end

    -- 读入环型缓冲区
    deserializeTupleFromFile(fullPath, __doReadTuple)

    -- 写出到文件
    local file = io.read(fullPath, _SERIALIZE_TRIM_FILE_WRITE_MODE)
    if file
    then
        while true
        do
            appendSerializedTupleToStream(queue[queueStartIdx], file)
            queueStartIdx = __advanceQueueIndex(queueStartIdx, reserveCount)

            if queueStartIdx == queueLastIdx
            then
                break
            end
        end

        file:close()
    end

    utils.clearTable(queue)
end




return
{
    appendSerializedTupleToStream   = appendSerializedTupleToStream,
    deserializeTupleFromString      = deserializeTupleFromString,
    deserializeTupleFromFile        = deserializeTupleFromFile,
    trimSerializedFile              = trimSerializedFile,
}