local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")


local _SERIALIZE_FUNC_NAME                  = "_"
local _SERIALIZE_FUNC_START                 = "("
local _SERIALIZE_FUNC_END                   = ")"
local _SERIALIZE_TABLE_START                = "{"
local _SERIALiZE_TABLE_END                  = "}"
local _SERIALIZE_SEP_ARG                    = ","
local _SERIALIZE_SEP_LINE                   = "\n"
local _SERIALIZE_QUOTE_STRING_FORMAT        = "%q"


local function serializeTuple(file, ...)
    if not types.isOpenedFile(file) or types.getVarArgCount(...) == 0
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
        elseif types.isNumber(elem) or types.isBoolean(elem) or types.isNil(elem)
        then
            file:write(tostring(elem))
        else
            -- 暂时不支持复杂的数据类型
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
    local loadEnv = { [_SERIALIZE_FUNC_NAME] = callback }
    local compiledChunks = isFilePath
                           and loadfile(input, constants.LOAD_MODE_CHUNKS, loadEnv)
                           or load(input, nil, constants.LOAD_MODE_CHUNKS, loadEnv)

    if compiledChunks
    then
        pcall(compiledChunks)
    end

    loadEnv = nil
    compiledChunks = nil
end


local function deserializeTupleFromFilePath(filePath, callback)
    return types.isString(filePath) and __doDeserialize(filePath, true, callback)
end

local function deserializeTupleFromString(chunks, callback)
    return types.isString(chunks) and __doDeserialize(chunks, false, callback)
end


return
{
    serializeTuple                  = serializeTuple,
    deserializeTupleFromFilePath    = deserializeTupleFromFilePath,
    deserializeTupleFromString      = deserializeTupleFromString,
}