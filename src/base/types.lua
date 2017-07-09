local constants     = require("src/base/constants")


local _LUA_TYPE_FUNCTION    = "function"
local _LUA_TYPE_TABLE       = "table"
local _LUA_TYPE_STRING      = "string"
local _LUA_TYPE_NUMBER      = "number"
local _LUA_TYPE_BOOLEAN     = "boolean"
local _LUA_TYPE_NIL         = "nil"


local function chooseValue(val, trueVal, falseVal)
    -- 注意选择的值可能就是 nil ，不要用简写为 A and B or C 的形式
    if val
    then
        return trueVal
    else
        return falseVal
    end
end

local function toInt(obj)
    local val = tonumber(obj)
    return chooseValue(val, math.floor, constants.FUNC_EMPTY)(val)
end

local function toZeroOrOne(obj)
    return obj and 1 or 0
end

local function toBoolean(obj)
    return obj and true or false
end

local function toValueOrNil(val)
    return chooseValue(val, val)
end

local function isString(obj)
    return type(obj) == _LUA_TYPE_STRING
end

local function isNonEmptyString(obj)
    return isString(obj) and #obj > 0
end

local function isNumber(obj)
    return type(obj) == _LUA_TYPE_NUMBER
end

local function isPositiveNumber(obj)
    return isNumber(obj) and obj > 0
end

local function isNonNegativeNumber(obj)
    return isNumber(obj) and obj >= 0
end

local function isBoolean(obj)
    return type(obj) == _LUA_TYPE_BOOLEAN
end

local function isNil(obj)
    return type(obj) == _LUA_TYPE_NIL
end

local function isFunction(obj)
    return type(obj) == _LUA_TYPE_FUNCTION
end

local function isTable(obj)
    return type(obj) == _LUA_TYPE_TABLE
end


local _IO_TYPE_OPENED_FILE  = "file"
local _IO_TYPE_CLOSED_FILE  = "closed file"

local function __isStringFile(obj)
    return isTable(obj)
        and isFunction(obj.read)
        and isFunction(obj.write)
        and isFunction(obj.close)
end

local function __doCheckNativeFileType(obj, reqType)
    return toBoolean(obj) and io.type(obj) == reqType
end

local function isOpenedFile(obj)
    local reqType = _IO_TYPE_OPENED_FILE
    return __doCheckNativeFileType(obj, reqType)
        or __isStringFile(obj) and __doCheckNativeFileType(obj._mFile, reqType)
end

local function isClosedFile(obj)
    local function __isNilOrNativeFileTypeMatched(obj, reqType)
        return obj == nil or __doCheckNativeFileType(obj, reqType)
    end
    local reqType = _IO_TYPE_CLOSED_FILE
    return __doCheckNativeFileType(obj, reqType)
        or __isStringFile(obj) and __isNilOrNativeFileTypeMatched(obj._mFile, reqType)
end

local function isEmptyTable(obj)
    return (isTable(obj) and next(obj) == nil)
end

local function isNonEmptyTable(obj)
    return (isTable(obj) and next(obj) ~= nil)
end

local function isNonEmptyArray(obj)
    return (isTable(obj) and obj[1] ~= nil)
end

local function isNilOrEmptyString(obj)
    return (obj == nil or obj == constants.STR_EMPTY)
end

local function getVarArgCount(...)
    return select("#", ...)
end

local function isEmptyVarArgs(...)
    return (getVarArgCount(...) == 0)
end


return
{
    toInt                   = toInt,
    toZeroOrOne             = toZeroOrOne,
    toBoolean               = toBoolean,
    toValueOrNil            = toValueOrNil,
    chooseValue             = chooseValue,
    isString                = isString,
    isNonEmptyString        = isNonEmptyString,
    isNumber                = isNumber,
    isPositiveNumber        = isPositiveNumber,
    isNonNegativeNumber     = isNonNegativeNumber,
    isBoolean               = isBoolean,
    isNil                   = isNil,
    isFunction              = isFunction,
    isTable                 = isTable,
    isOpenedFile            = isOpenedFile,
    isClosedFile            = isClosedFile,
    isNilOrEmptyString      = isNilOrEmptyString,
    isEmptyTable            = isEmptyTable,
    isEmptySet              = isEmptyTable,
    isNonEmptyTable         = isNonEmptyTable,
    isNonEmptyArray         = isNonEmptyArray,
    isEmptyVarArgs          = isEmptyVarArgs,
    getVarArgCount          = getVarArgCount,
}