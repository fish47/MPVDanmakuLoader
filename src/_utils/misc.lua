local _base = require("src/_utils/_base")
local utf8 = require("src/_utils/utf8")
local classlite = require("src/_utils/classlite")


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

local function quoteBashString(text)
    -- 这是从 pipes.py 抄过来的
    text = tostring(text)
    local replaced = text:gsub(_BASH_STRONG_QUOTE, _BASH_ESCAPED_STRONG_QUOTE)
    return _BASH_STRONG_QUOTE .. replaced .. _BASH_STRONG_QUOTE
end


local _CMD_BUILDER_SEP                  = " "
local _CMD_BUILDER_GUESS_RET_CODE       = _base.getLuaVersion() <= 5.1
local _CMD_BUILDER_RET_STR_SUCCEED      = "succeed"
local _CMD_BUILDER_RET_STR_FAILED       = "failed"
local _CMD_BUILDER_RET_CODE_SUCCEED     = 0
local _CMD_BUILDER_RET_CODE_FAILED      = math.huge
local _CMD_BUILDER_PATTERN_SUCCEED      = "(succeed\n)$"
local _CMD_BUILDER_PATTERN_FAILED       = "(failed\n)$"
local _CMD_BUILDER_REASON_EXIT          = "exit"
local _CMD_BUILDER_REASON_SINGAL        = "signal"


local __LastLineStrippedPopenFile =
{
    _mSucceed           = nil,      -- 外部命令是否执行成功
    _mReturnCode        = nil,      -- 执行成功后的返回值
    _mPopenFile         = nil,
    _mTmpFile           = nil,


    new = function(obj, f)
        obj = classlite.allocateInstance(obj)
        obj._mSucceed = false
        obj._mReturnCode = nil
        obj._mPopenFile = f
        obj._mTmpFile = nil
        return obj
    end,


    __doFirstRead = function(self)
        local output = self._mPopenFile:read("*a")
        if not output
        then
            return false
        end

        -- 最后一行显示命令是否执行成功，所以要提取出来
        local matched = false
        local retCode = nil

        if not matched
        then
            matched = string.match(output, _CMD_BUILDER_PATTERN_SUCCEED)
            retCode = matched and _CMD_BUILDER_RET_CODE_SUCCEED
        end

        if not matched
        then
            matched = string.match(output, _CMD_BUILDER_PATTERN_FAILED)
            retCode = matched and _CMD_BUILDER_RET_CODE_FAILED
        end

        local stripped = matched and output:sub(0, -(matched:len() + 1)) or output
        return true, retCode, output
    end,


    __ensureTmpFile = function(self)
        if self._mTmpFile
        then
            return self._mTmpFile
        end

        local succeed, retCode, content = self:__doFirstRead()
        self._mSucceed = succeed
        self._mReturnCode = retCode
        self._mTmpFile = io.tmpfile()
        if content
        then
            self._mTmpFile:setvbuf("full")
            self._mTmpFile:write(content)
        end
        return self._mTmpFile
    end,


    _readAndClose = function(self)
        local succeed, retCode, content = self:__doFirstRead()
        return content, succeed, retCode
    end,

    write = function(self, ...)
        return self._mPopenFile:write(...)
    end,

    flush = function(self)
        return self._mPopenFile:flush()
    end,

    setvbuf = function(self, mode, size)
        self._mPopenFile:setvbuf(mode, size)
    end,

    read = function(self, readFormat)
        return self:__ensureTmpFile():read(readFormat)
    end,

    lines = function(self, ...)
        return self:__ensureTmpFile():lines(...)
    end,

    seek = function(self, whence, offset)
        return self:__ensureTmpFile():seek(whence, offset)
    end,

    close = function(self)
        local succeed = self._mSucceed or false
        local reason = succeed
                       and _CMD_BUILDER_REASON_EXIT
                       or _CMD_BUILDER_REASON_SINGAL
        local returnCode = succeed
                           and _CMD_BUILDER_RET_CODE_SUCCEED
                           or _CMD_BUILDER_RET_CODE_FAILED

        _base.closeSafely(self._mTmpFile)
        _base.closeSafely(self._mPopenFile)
        _base.clearTable(self)
        return reason, returnCode
    end,
}

classlite.declareClass(__LastLineStrippedPopenFile)


local CommandlineBuilder    =
{
    _mArguments             = nil,
    _mArgumentSep           = nil,
    _mQuoteFunction         = nil,


    new = function(obj, quoteFunc, sep)
        obj = classlite.allocateInstance(obj)
        obj._mArguments = {}
        obj._mArgumentSep = sep or _CMD_BUILDER_SEP
        obj._mQuoteFunction = quoteFunc or quoteBashString
        return obj
    end,

    dispose = function(self)
        _base.clearTable(self._mArguments)
        _base.clearTable(self)
    end,

    startCommand = function(self, binPath)
        _base.clearTable(self._mArguments)
        self:addArgument(binPath)
        return self
    end,

    addArgument = function(self, arg)
        arg = tostring(arg)
        arg = self._mQuoteFunction(arg)
        table.insert(self._mArguments, arg)
        return self
    end,

    execute = function(self, mode)
        local args = self._mArguments
        if _CMD_BUILDER_GUESS_RET_CODE
        then
            -- 在标准输出的第一行输出命令是否执行成功
            table.insert(args, "&&")
            table.insert(args, "echo")
            table.insert(args, _CMD_BUILDER_RET_STR_SUCCEED)
            table.insert(args, "||")
            table.insert(args, "echo")
            table.insert(args, _CMD_BUILDER_RET_CODE_FAILED)
        end

        local cmdStr = table.concat(self._mArguments, self._mArgumentSep)
        local f = io.popen(cmdStr, mode or "r")

        if _CMD_BUILDER_GUESS_RET_CODE
        then
            f = __LastLineStrippedPopenFile:new(f)
        end

        return f
    end,

    executeAndWait = function(self)
        local f = self:execute()
        if _CMD_BUILDER_GUESS_RET_CODE
        then
            return f:_readAndClose()
        else
            return _base.readAndCloseFile(f)
        end
    end,
}


return
{
    CommandlineBuilder          = CommandlineBuilder,
    escapeASSString             = escapeASSString,
    unescapeXMLString           = unescapeXMLString,
    escapeURLString             = escapeURLString,
    quoteBashString             = quoteBashString,
    convertTimeToHMS            = convertTimeToHMS,
    convertHHMMSSToTime         = convertHHMMSSToTime,
    convertRGBHexToBGRString    = convertRGBHexToBGRString,
}