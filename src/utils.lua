local utf8 = require('src/utf8')    --= utf8 utf8

local _XML_ESCAPE_STR_MAP =
{
    ["&lt;"]    = "<",
    ["&gt;"]    = ">",
    ["&amp;"]   = "&",
    ["&apos;"]  = "\'",
    ["&quot;"]  = "\"",
}

local _XML_ESCAPE_STR_UNICODE_RADIX = 16

local _XML_ESCAPE_STR_PATTERN = "(&[lgaq#][^;]*;)"
local _XML_ESCAPE_STR_UNICODE_PATTERN = "&#x(%x+);"

local function __replaceEscapedXMLText(text)
    -- 转义字符
    local unscaped = _XML_ESCAPE_STR_MAP[text]
    if unscaped
    then
        return unscaped
    end

    -- 也有可能是 unicode
    local matched = text:match(_XML_ESCAPE_STR_UNICODE_PATTERN)
    if matched
    then
        local codePoint = tonumber(matched, _XML_ESCAPE_STR_UNICODE_RADIX)
        local outList = {}
        utf8.getUTF8Bytes(codePoint, outList, string.char)

        local ret = table.concat(outList)
        outList = nil
        return ret
    end

    -- 不可转义，保持原样
    return nil
end

local function unescapeXMLText(text)
    local str = text:gsub(_XML_ESCAPE_STR_PATTERN, __replaceEscapedXMLText)
    return str
end


local _COLOR_CONV_FMT_STR       = "%02X%02X%02X"
local _COLOR_CONV_CHANNEL_MOD   = 256

local function convertRGBHexToBGRString(num)
    local b = math.floor(num % _COLOR_CONV_CHANNEL_MOD)

    num = math.floor(num / _COLOR_CONV_CHANNEL_MOD)
    local g = math.floor(num % _COLOR_CONV_CHANNEL_MOD)

    num = math.floor(num / _COLOR_CONV_CHANNEL_MOD)
    local r = math.floor(num % _COLOR_CONV_CHANNEL_MOD)


    return string.format(_COLOR_CONV_FMT_STR, b, g, r)
end



local _TIME_CONV_MS_PER_SECOND  = 1000
local _TIME_CONV_MS_PER_MINUTE  = 60 * 1000
local _TIME_CONV_MS_PER_HOUR    = 60 * 60 * 1000
local _TIME_CONV_FMT_STR        = "%d:%02d:%05.02f"

local function convertTimeToHHMMSS(time)
    local hours = math.floor(time / _TIME_CONV_MS_PER_HOUR)

    time = time - hours * _TIME_CONV_MS_PER_HOUR
    local minutes = math.floor(time / _TIME_CONV_MS_PER_MINUTE)

    time = time - minutes * _TIME_CONV_MS_PER_MINUTE
    local seconds = time / _TIME_CONV_MS_PER_SECOND

    return string.format(_TIME_CONV_FMT_STR, hours, minutes, seconds)
end


local function convertHHMMSSToTime(h, m, s, ms)
    local ret = 0
    ret = ret + h * _TIME_CONV_MS_PER_HOUR
    ret = ret + m * _TIME_CONV_MS_PER_MINUTE
    ret = ret + s * _TIME_CONV_MS_PER_SECOND
    ret = ret + (ms or 0)
    return ret
end


local _ASS_ESCAPABLE_CHAR_MAP =
{
    ["\n"]      = "\\N",
    ["\\"]      = "\\\\",
    ["{"]       = "\\{",
    ["}"]       = "\\}",
    [" "]       = "\\h",
}

local _ASS_ESCAPABLE_CHARS_PATTERN = "[\n\\{} ]"

local function escapeASSText(text, outList)
    local str = text:gsub(_ASS_ESCAPABLE_CHARS_PATTERN, _ASS_ESCAPABLE_CHAR_MAP)
    return str
end



local __gClassMetaTables = {}

local function __createClassMetaTable(clzDefObj)
    local ret = __gClassMetaTables[clzDefObj]
    ret = { __index = clzDefObj }
    __gClassMetaTables[clzDefObj] = ret
    return ret
end


local function __addMissedEntries(destTable, newTable)
    if newTable == nil
    then
        return
    end

    for k, v in pairs(newTable)
    do
        if not destTable[k]
        then
            destTable[k] = v
        end
    end
end


local function allocateInstance(objArg)
    local mt = __gClassMetaTables[objArg]
    if mt ~= nil
    then
        -- 如果以 ClazDefObj:new() 的形式调用，第一个参数就是指向 Class 本身
        local ret = {}
        setmetatable(ret, mt)
        return ret
    else
        -- 也有可能是子类间接调用父类的构建方法，此时不应再创建实例
        return objArg
    end
end


local function declareClass(clzDefObj, baseClzDefObj)
    -- 有可能是继承
    if baseClzDefObj ~= nil
    then
        __addMissedEntries(clzDefObj, baseClzDefObj)

        -- 如果没有声明构造方法，默认用父类的
        if clzDefObj.new == nil
        then
            clzDefObj.new = function(obj, ...)
                obj = allocateInstance(obj)
                return baseClzDefObj.new(obj, ...)
            end
        end
    end

    __createClassMetaTable(clzDefObj)
    return clzDefObj
end



local function binarySearchList(list, cond, val)
    local low = 1
    local high = #list
    while low <= high
    do
        local mid = math.floor((low + high) / 2)
        local midVal = list[mid]
        local cmpRet = cond(list[mid], val)

        if cmpRet == 0
        then
            return mid, midVal
        elseif cmpRet > 0
        then
            high = mid - 1
        else
            low = mid + 1
        end
    end

    -- 找不到返回的是插入位置
    return low, nil
end


local function __doIteratePairsArray(array, idx)
    if idx + 1 > #array
    then
        return nil
    end

    return idx + 2, array[idx], array[idx + 1]
end

local function iteratePairsArray(array, startIdx)
    return __doIteratePairsArray, array, startIdx or 1
end

local function isTable(o)
    return type(o) == "table"
end

local function isEmptyTable(o)
    return isTable(o) and next(o) == nil
end

local function isString(o)
    return type(o) == "string"
end

local function isNumber(o)
    return type(o) == "number"
end


local function clearTable(t)
    if not isTable(t)
    then
        while true
        do
            local k = next(t)
            if not k
            then
                break
            end

            t[k] = nil
        end
    end

    return t
end


return
{
    declareClass                = declareClass,
    allocateInstance            = allocateInstance,

    isNumber                    = isNumber,
    isString                    = isString,
    isTable                     = isTable,
    isEmptyTable                = isEmptyTable,
    clearTable                  = clearTable,
    unpack                      = unpack or table.unpack,
    iteratePairsArray           = iteratePairsArray,
    binarySearchList            = binarySearchList,

    escapeASSText               = escapeASSText,
    unescapeXMLText             = unescapeXMLText,
    convertTimeToHHMMSS         = convertTimeToHHMMSS,
    convertHHMMSSToTime         = convertHHMMSSToTime,
    convertRGBHexToBGRString    = convertRGBHexToBGRString,
}