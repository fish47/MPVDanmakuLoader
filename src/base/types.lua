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

local function isConstant(obj)
    local typeString = type(obj)
    return typeString == _LUA_TYPE_NUMBER
           or typeString == _LUA_TYPE_BOOLEAN
           or typeString == _LUA_TYPE_NIL
end

local function isFunction(obj)
    return type(obj) == _LUA_TYPE_FUNCTION
end

local function isTable(obj)
    return type(obj) == _LUA_TYPE_TABLE
end

local function isEmptyTable(o)
    return (isTable(o) and next(o) == nil)
end

local function isNilOrEmpty(o)
    return (o == nil or isEmptyTable(o) or o == constants.STR_EMPTY)
end

local function getVarArgCount(...)
    return select("#", ...)
end

local function isEmptyVarArgs(...)
    return (getVarArgCount(...) == 0)
end

local function isFile(obj)
    return isTable(obj)
           and isFunction(obj.close)
           and isFunction(obj.flush)
           and isFunction(obj.lines)
           and isFunction(obj.read)
           and isFunction(obj.seek)
           and isFunction(obj.setvbuf)
           and isFunction(obj.write)
end

local function toNumber(o)
    if not o
    then
        return 0
    elseif isNumber(o)
    then
        return o
    else
        return 1
    end
end


return
{
    isString            = isString,
    isNumber            = isNumber,
    isConstant          = isConstant,
    isFunction          = isFunction,
    isTable             = isTable,
    isNilOrEmpty        = isNilOrEmpty,
    isEmptyTable        = isEmptyTable,
    isEmptyVarArgs      = isEmptyVarArgs,
    isFile              = isFile,

    getVarArgCount      = getVarArgCount,

    toNumber            = toNumber,
}