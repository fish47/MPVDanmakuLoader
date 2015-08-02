local utf8 = require('src/_utils/utf8')


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


local _ASS_ESCAPABLE_CHARS_PATTERN  = "[\n\\{} ]"
local _ASS_ESCAPABLE_CHAR_MAP       =
{
    ["\n"]      = "\\N",
    ["\\"]      = "\\\\",
    ["{"]       = "\\{",
    ["}"]       = "\\}",
    [" "]       = "\\h",
}

local function escapeASSText(text, outList)
    local str = text:gsub(_ASS_ESCAPABLE_CHARS_PATTERN, _ASS_ESCAPABLE_CHAR_MAP)
    return str
end


return
{
    escapeASSText               = escapeASSText,
    unescapeXMLText             = unescapeXMLText,
    convertTimeToHHMMSS         = convertTimeToHHMMSS,
    convertHHMMSSToTime         = convertHHMMSSToTime,
    convertRGBHexToBGRString    = convertRGBHexToBGRString,
}