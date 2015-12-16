local constants     = require("src/base/constants")


local _LUA_TYPE_FUNCTION    = "function"
local _LUA_TYPE_TABLE       = "table"
local _LUA_TYPE_STRING      = "string"
local _LUA_TYPE_NUMBER      = "number"
local _LUA_TYPE_BOOLEAN     = "boolean"
local _LUA_TYPE_NIL         = "nil"

local function isString(obj)
    return type(obj) == _LUA_TYPE_STRING
end

local function isNumber(obj)
    return type(obj) == _LUA_TYPE_NUMBER
end

local function isFunction(obj)
    return type(obj) == _LUA_TYPE_FUNCTION
end

local function isTable(obj)
    return type(obj) == _LUA_TYPE_TABLE
end


local _IO_TYPE_OPENED_FILE  = "file"
local _IO_TYPE_CLOSED_FILE  = "closed file"

local function isOpenedFile(obj)
    return io.type(obj) == _IO_TYPE_OPENED_FILE
end

local function isClosedFile(obj)
    return io.type(obj) == _IO_TYPE_CLOSED_FILE
end


local function isEmptyTable(obj)
    return (isTable(obj) and next(obj) == nil)
end

local function isNilOrEmpty(obj)
    return (obj == nil or obj == constants.STR_EMPTY or isEmptyTable(obj))
end

local function getVarArgCount(...)
    return select("#", ...)
end

local function isEmptyVarArgs(...)
    return (getVarArgCount(...) == 0)
end

local function toNumber(obj)
    if not obj
    then
        return 0
    elseif isNumber(obj)
    then
        return obj
    else
        return 1
    end
end

local function toBoolean(obj)
    return obj and true or false
end


return
{
    isString            = isString,
    isNumber            = isNumber,
    isFunction          = isFunction,
    isTable             = isTable,
    isOpenedFile        = isOpenedFile,
    isClosedFile        = isClosedFile,
    isNilOrEmpty        = isNilOrEmpty,
    isEmptyTable        = isEmptyTable,
    isEmptyVarArgs      = isEmptyVarArgs,
    getVarArgCount      = getVarArgCount,
    toNumber            = toNumber,
    toBoolean           = toBoolean,
}