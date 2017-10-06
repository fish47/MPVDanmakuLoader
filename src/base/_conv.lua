local utf8      = require("src/base/utf8")
local types     = require("src/base/types")
local constants = require("src/base/constants")


local _XML_ESCAPE_STR_UNICODE_RADIX     = 16
local _XML_ESCAPE_STR_PATTERN           = "(&[lgaq#][^;]*;)"
local _XML_ESCAPE_STR_UNICODE_PATTERN   = "&#x(%x+);"
local _XML_ESCAPE_STR_MAP               =
{
    ["&lt;"]    = "<",
    ["&gt;"]    = ">",
    ["&amp;"]   = "&",
    ["&apos;"]  = "\'",
    ["&quot;"]  = "\"",
}

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
        local ret = constants.STR_EMPTY
        local codePoint = tonumber(matched, _XML_ESCAPE_STR_UNICODE_RADIX)
        for _, utf8Byte in utf8.iterateUTF8EncodedBytes(codePoint)
        do
            ret = ret .. string.char(utf8Byte)
        end
        return ret
    end

    -- 不可转义，保持原样
    return nil
end

local function unescapeXMLString(text)
    local str = text:gsub(_XML_ESCAPE_STR_PATTERN, __replaceEscapedXMLText)
    return str
end



local _COLOR_CONV_CHANNEL_MOD   = 256
local _COLOR_CONV_MIN_VALUE     = 0

local function splitARGBHex(num)
    local function __popColorChannel(num)
        local channel = math.floor(num % _COLOR_CONV_CHANNEL_MOD)
        local remaining = math.floor(num / _COLOR_CONV_CHANNEL_MOD)
        return remaining, channel
    end

    local a = _COLOR_CONV_MIN_VALUE
    local r = _COLOR_CONV_MIN_VALUE
    local g = _COLOR_CONV_MIN_VALUE
    local b = _COLOR_CONV_MIN_VALUE
    num = math.max(math.floor(num), _COLOR_CONV_MIN_VALUE)
    num, b = __popColorChannel(num)
    num, g = __popColorChannel(num)
    num, r = __popColorChannel(num)
    num, a = __popColorChannel(num)
    return a, r, g, b
end


local _TIME_CONV_MS_PER_SECOND  = 1000
local _TIME_CONV_MS_PER_MINUTE  = 60 * 1000
local _TIME_CONV_MS_PER_HOUR    = 60 * 60 * 1000

local function convertTimeToHMS(time)
    local hours = math.floor(time / _TIME_CONV_MS_PER_HOUR)

    time = time - hours * _TIME_CONV_MS_PER_HOUR
    local minutes = math.floor(time / _TIME_CONV_MS_PER_MINUTE)

    time = time - minutes * _TIME_CONV_MS_PER_MINUTE
    local seconds = time / _TIME_CONV_MS_PER_SECOND

    return hours, minutes, seconds
end


local function convertHHMMSSToTime(h, m, s, ms)
    local ret = 0
    ret = ret + h * _TIME_CONV_MS_PER_HOUR
    ret = ret + m * _TIME_CONV_MS_PER_MINUTE
    ret = ret + s * _TIME_CONV_MS_PER_SECOND
    ret = ret + (ms or 0)
    return ret
end


local _ASS_ESCAPABLE_CHARS_PATTERN  = "[\n\\{} ]"
local _ASS_ESCAPABLE_CHAR_MAP       =
{
    ["\n"]      = "\\N",
    ["\\"]      = "\\\\",
    ["{"]       = "\\{",
    ["}"]       = "\\}",
    [" "]       = "\\h",
}

local function escapeASSString(text)
    local str = text:gsub(_ASS_ESCAPABLE_CHARS_PATTERN, _ASS_ESCAPABLE_CHAR_MAP)
    return str
end




local _JSON_PATTERN_ESCAPABLE_CHARS     = '\\([\\\"/bfnrt])'
local _JSON_PATTERN_ESCAPABLE_UNICODE   = '\\u(%x%x%x%x)'
local _JSON_PATTERN_KEY_VALUE_SEP       = '%s*:%s*'
local _JSON_PATTERN_QUOTE_OR_ESCAPE     = '[\\\"]'
local _JSON_CONST_STRING_QUOTE          = '\"'
local _JSON_CONST_STRING_ESCAPE         = "\\"
local _JSON_UNICODE_NUMBER_BASE         = 16
local _JSON_SPECIAL_CHAR_MAP            =
{
    ["\""]      = "\"",
    ["\\"]      = "\\",
    ["/"]       = "/",
    ["f"]       = "\f",
    ["b"]       = "",       -- 暂时忽略退格
    ["n"]       = "\n",
    ["t"]       = "\t",
    ["r"]       = "\r",
}

local function unescapeJSONString(text)
    -- 特殊字符转义
    local function __unescapeSpecialChars(captured)
        return _JSON_SPECIAL_CHAR_MAP[captured]
    end

    -- unicode 转义
    local function __unescapeJSONUnicode(captured)
        local hex = tonumber(captured, _JSON_UNICODE_NUMBER_BASE)
        local ret = constants.STR_EMPTY
        for _, utf8Byte in utf8.iterateUTF8EncodedBytes(hex)
        do
            ret = ret .. string.char(utf8Byte)
        end
        return ret
    end

    local ret = text:gsub(_JSON_PATTERN_ESCAPABLE_CHARS, __unescapeSpecialChars)
    ret = ret:gsub(_JSON_PATTERN_ESCAPABLE_UNICODE, __unescapeJSONUnicode)
    return ret
end


local function __clampFindIndex(idx)
    return types.chooseValue(types.isNumber(idx), idx, 1)
end

local function findJSONString(text, findStartIdx)
    findStartIdx = __clampFindIndex(findStartIdx)
    local pos = text:find(_JSON_CONST_STRING_QUOTE, findStartIdx, true)
    if not pos
    then
        return
    end

    local nextPos = pos
    while true
    do
        nextPos = text:find(_JSON_PATTERN_QUOTE_OR_ESCAPE, nextPos + 1)
        if not nextPos
        then
            return
        end

        local ch = text:sub(nextPos, nextPos)
        if ch == _JSON_CONST_STRING_ESCAPE
        then
            -- 跳过转义字符
            nextPos = nextPos + 1
        else
            local captured = text:sub(pos + 1, nextPos - 1)
            return unescapeJSONString(captured), nextPos + 1
        end
    end
end

local function findJSONKeyValue(text, key, findStartIdx)
    local findIdx = __clampFindIndex(findStartIdx)
    while true
    do
        local pos = text:find(key, findIdx, true)
        if not pos
        then
            return
        end

        local _, sepLastIdx = text:find(_JSON_PATTERN_KEY_VALUE_SEP, pos)
        if not sepLastIdx or sepLastIdx + 1 >= #text
        then
            return
        end

        local nextIdx = sepLastIdx + 1
        if text:sub(nextIdx, nextIdx) == _JSON_CONST_STRING_QUOTE
        then
            return findJSONString(text, nextIdx)
        end

        findIdx = nextIdx
    end
end


local _URL_ESCAPED_CHAR_FORMAT      = "%%%02X"
local _URL_PATTERN_SPECIAL_CHARS    = "[^A-Za-z0-9%-_%.~]"

local function escapeURLString(text)
    local function __replaceURLSpecialChars(text)
        return string.format(_URL_ESCAPED_CHAR_FORMAT, text:byte(1))
    end
    return text:gsub(_URL_PATTERN_SPECIAL_CHARS, __replaceURLSpecialChars)
end


return
{
    escapeASSString             = escapeASSString,
    unescapeXMLString           = unescapeXMLString,
    escapeURLString             = escapeURLString,
    unescapeJSONString          = unescapeJSONString,
    findJSONString              = findJSONString,
    findJSONKeyValue            = findJSONKeyValue,
    convertTimeToHMS            = convertTimeToHMS,
    convertHHMMSSToTime         = convertHHMMSSToTime,
    splitARGBHex                = splitARGBHex,
    getRGBHex                   = getRGBHex,
}
