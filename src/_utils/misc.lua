local _base = require("src/_utils/_base")
local utf8 = require("src/_utils/utf8")


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
        local ret = ""
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


local _ASS_ESCAPABLE_CHARS_PATTERN  = "[\n\\{} ]"
local _ASS_ESCAPABLE_CHAR_MAP       =
{
    ["\n"]      = "\\N",
    ["\\"]      = "\\\\",
    ["{"]       = "\\{",
    ["}"]       = "\\}",
    [" "]       = "\\h",
}

local function escapeASSString(text, outList)
    local str = text:gsub(_ASS_ESCAPABLE_CHARS_PATTERN, _ASS_ESCAPABLE_CHAR_MAP)
    return str
end



local _URL_ESCAPED_CHAR_FORMAT      = "%%%02X"
local _URL_PATTERN_SPECIAL_CHARS    = "[^A-Za-z0-9%-_%.~]"

local function __replaceURLSpecialChars(text)
    return string.format(_URL_ESCAPED_CHAR_FORMAT, text:byte(1))
end

local function escapeURLString(text)
    return text:gsub(_URL_PATTERN_SPECIAL_CHARS, __replaceURLSpecialChars)
end


local _BASH_STRONG_QUOTE            = "\'"
local _BASH_ESCAPED_STRONG_QUOTE    = "'\"'\"'"

local function escapeBashString(text)
    -- 这是从 pipes.py 抄过来的
    local replaced = text:gsub(_BASH_STRONG_QUOTE, _BASH_ESCAPED_STRONG_QUOTE)
    return _BASH_STRONG_QUOTE .. replaced .. _BASH_STRONG_QUOTE
end


return
{
    escapeASSString             = escapeASSString,
    unescapeXMLString           = unescapeXMLString,
    escapeURLString             = escapeURLString,
    escapeBashString            = escapeBashString,
    convertTimeToHHMMSS         = convertTimeToHHMMSS,
    convertHHMMSSToTime         = convertHHMMSSToTime,
    convertRGBHexToBGRString    = convertRGBHexToBGRString,
}