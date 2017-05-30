local types     = require("src/base/types")
local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")


local _IMPL_FUNC_CALLBACK_FUNCTION_NAME = "_"
local _IMPL_FUNC_SCRIPT_CONTENT         = ""


local function _appendKeyValue(args, key, value)
    if types.isString(key) and types.isString(value)
    then
        table.insert(args, key)
        table.insert(args, value)
    end
end

local function _appendKeyArray(args, key, value)
    if types.isString(key) and types.isNonEmptyTable(value)
    then
        table.insert(args, key)
        utils.appendArrayElements(args, value)
    end
end

local function __projectStdoutData(retCode, out)
    return out
end

local function __projectReturnCode(retCode)
    return types.toBoolean(retCode)
end

local function __isNilOrPositiveInt(num)
    return num == nil or types.isPositiveNumber(num)
end


local ExternalCommandExecutor =
{
    _mLoadEnv       = classlite.declareTableField(),
    _mArguments     = classlite.declareTableField(),
    _mReturnValues  = classlite.declareTableField(),
    _mApplication   = classlite.declareConstantField(nil),

    setApplication = function(self, app)
        self._mApplication = app
    end,

    __prepareArguments = function(self)
        local args = utils.clearTable(self._mArguments)
        local app = self._mApplication
        local cfg = app and app:getConfiguration()
        local pythonPath = cfg and cfg.python2BinPath
        if pythonPath
        then
            table.insert(args, pythonPath)
            table.insert(args, "-c")
            table.insert(args, _IMPL_FUNC_SCRIPT_CONTENT)
            return args
        end
    end,

    __execute = function(self, checkArgsFunc, buildArgsFunc, returnFunc, ...)

    end,

    createDirs = function(self, path)
        local function _build(args, path)
            table.insert(args, "create_dirs")
            _appendKeyValue(args, "path", path)
        end
        return self:__execute(types.isNonEmptyString, _build, __projectReturnCode, path)
    end,

    deletePath = function(self, path)
        local function _build(args, path)
            table.insert(args, "delete_path")
            _appendKeyValue(args, "path", path)
        end
        return self:__execute(types.isNonEmptyString, _build, __projectReturnCode, path)
    end,

    redirectExternalCommand = function(self, content, cmdArgs)
        local function _check(content, cmdArgs)
            return types.isNonEmptyString(content) and types.isNonEmptyArray(cmdArgs)
        end
        local function _build(args, content, cmdArgs)
            table.insert(args, "redirect_external_command")
            _appendKeyValue(args, "content", content)
            _appendKeyArray(args, "cmd_args", cmdArgs)
        end
        local function _return(ret, out)
            return types.toBoolean(ret), out
        end
        return self:__execute(_check, _build, _return, content, cmdArgs)
    end,

    readUTF8File = function(self, path)
        local function _build(args, path)
            table.insert(args, "read_utf8_file")
            _appendKeyArray(args, "path", path)
        end
        return self:__execute(types.isNonEmptyString, _build, __projectStdoutData, path)
    end,

    calculateFileMD5 = function(self, path, byteCount)
        local function _check(path, byteCount)
            return types.isNonEmptyString(path) and __isNilOrPositiveInt(byteCount)
        end
        local function _build(args, path, byteCount)
            table.insert(args, "calculate_file_md5")
            _appendKeyValue(args, "path", path)
            _appendKeyValue(args, "byte_count", tostring(byteCount))
        end
        byteCount = types.toInt(byteCount)
        return self:__execute(_check, _build, __projectStdoutData, path, byteCount)
    end,

    requestURLs = function(self, urls, timeout, outArray)
        local function __isNotString(str)
            return not types.isString(str)
        end
        local function _check(urls, timeout, outArray)
            return types.isNonEmptyArray(urls)
                and not utils.linearSearchArrayIf(urls, __isNotString)
                and __isNilOrPositiveInt(timeout)
                and types.isTable(outArray)
        end
        local function _build(args, urls, timeout)
            table.insert(args, "request_urls")
            _appendKeyArray("urls", urls)
            _appendKeyValue("timeout", timeout)
        end
        local function _return(ret, out, urls)
            --TODO 怎样验证返回值比较好？
        end
        timeout = types.toInt(timeout)
        return self:__execute(_check, _build, _return, urls, timeout)
    end,
}