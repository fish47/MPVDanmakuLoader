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


local _JSON_TOKEN_QUOTE         = "\""
local _JSON_TOKEN_BACKSLASH     = "\\"

local function findNextJSONString(text, findStartIdx)
    local firstQuoteIdx = text:find(_JSON_TOKEN_QUOTE, findStartIdx, true)
    if firstQuoteIdx
    then
        local lastQuoteIdx = nil
        local quoteLen = #_JSON_TOKEN_QUOTE
        local backSlashLen = #_JSON_TOKEN_BACKSLASH
        local lastQuoteFindStartIdx = firstQuoteIdx + quoteLen
        while true
        do
            lastQuoteIdx = text:find(_JSON_TOKEN_QUOTE, lastQuoteFindStartIdx, true)
            if not lastQuoteIdx
            then
                return
            end

            -- 向前看是不是被转义字符
            if text:sub(lastQuoteIdx - backSlashLen, lastQuoteIdx - 1) ~= _JSON_TOKEN_BACKSLASH
            then
                break
            end

            lastQuoteFindStartIdx = lastQuoteIdx + quoteLen
        end

        if firstQuoteIdx and lastQuoteIdx
        then
            local substring = text:sub(firstQuoteIdx + quoteLen, lastQuoteIdx - quoteLen)
            return unescapeJSONString(substring), lastQuoteIdx + quoteLen
        end
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
    findNextJSONString          = findNextJSONString,
    convertTimeToHMS            = convertTimeToHMS,
    convertHHMMSSToTime         = convertHHMMSSToTime,
    convertRGBHexToBGRString    = convertRGBHexToBGRString,
}