local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")
local constants = require("src/base/constants")


local _BASH_STRONG_QUOTE            = "\'"
local _BASH_ESCAPED_STRONG_QUOTE    = "'\"'\"'"

-- 从 pipes.py 抄过来的
local function quoteShellString(text)
    text = tostring(text)
    local replaced = text:gsub(_BASH_STRONG_QUOTE, _BASH_ESCAPED_STRONG_QUOTE)
    return _BASH_STRONG_QUOTE .. replaced .. _BASH_STRONG_QUOTE
end


local _CMD_BUILDER_SEP                  = " "
local _CMD_BUILDER_GUESS_RET_CODE       = constants.LUA_VERSION <= 5.1
local _CMD_BUILDER_RET_STR_SUCCEED      = "succeed"
local _CMD_BUILDER_RET_STR_FAILED       = "failed"
local _CMD_BUILDER_RET_CODE_SUCCEED     = 0
local _CMD_BUILDER_RET_CODE_FAILED      = math.huge
local _CMD_BUILDER_PATTERN_SUCCEED      = "(succeed\n)$"
local _CMD_BUILDER_PATTERN_FAILED       = "(failed\n)$"
local _CMD_BUILDER_REASON_EXIT          = "exit"
local _CMD_BUILDER_REASON_SINGAL        = "signal"


local _LastLineStrippedPopenFile =
{
    _mSucceed           = false,    -- 外部命令是否执行成功
    _mReturnCode        = nil,      -- 执行成功后的返回值
    _mPopenFile         = nil,
    _mTmpFile           = nil,


    new = function(obj, f)
        obj = classlite.allocateInstance(obj)
        obj._mPopenFile = f
        return obj
    end,


    __doFirstRead = function(self)
        local output = self._mPopenFile:read(constants.READ_MODE_ALL)
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

        utils.closeSafely(self._mTmpFile)
        utils.closeSafely(self._mPopenFile)
        utils.clearTable(self)
        return reason, returnCode
    end,
}

classlite.declareClass(_LastLineStrippedPopenFile)


local CommandlineBuilder =
{
    _mArguments             = classlite.declareTableField(),
    _mArgumentSep           = classlite.declareConstantField(_CMD_BUILDER_SEP),
    _mQuoteFunction         = classlite.declareConstantField(quoteShellString),

    startCommand = function(self, binPath)
        utils.clearTable(self._mArguments)
        self:addArgument(binPath)
        return self
    end,

    addArgument = function(self, arg)
        if arg
        then
            arg = tostring(arg)
            arg = self._mQuoteFunction(arg)
            table.insert(self._mArguments, arg)
        end
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
        local f = io.popen(cmdStr, mode or constants.FILE_MODE_READ)

        if _CMD_BUILDER_GUESS_RET_CODE
        then
            f = _LastLineStrippedPopenFile:new(f)
        end

        return f
    end,

    executeAndWait = function(self)
        local f = self:execute()
        if _CMD_BUILDER_GUESS_RET_CODE
        then
            return f:_readAndClose()
        else
            return utils.readAndCloseFile(f)
        end
    end,
}


return
{
    CommandlineBuilder      = CommandlineBuilder,
    quoteShellString        = quoteShellString,
}