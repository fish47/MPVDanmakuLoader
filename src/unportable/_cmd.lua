local types     = require("src/base/types")
local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")
local serialize = require("src/base/serialize")


local REQ_URL_FLAG_UNCOMPRESS       = 1
local REQ_URL_FLAG_ACCEPT_XML       = 2

local _IMPL_FUNC_SCRIPT_CONTENT     = [[ __SCRIPT_CONTENT__ ]]


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
        for _, v in ipairs(value)
        do
            table.insert(args, tostring(v))
        end
    end
end

local function __project2(retCode, out)
    return out
end

local function __project1(retCode)
    return types.isNumber(retCode) and retCode
end

local function __isNilOrPositiveInt(num)
    return num == nil or types.isPositiveNumber(num)
end


local PyScriptCommandExecutor =
{
    _mLoadEnv               = classlite.declareTableField(),
    _mArguments             = classlite.declareTableField(),
    _mReturnArguments       = classlite.declareTableField(),
    _mReturnValues          = classlite.declareTableField(),
    _mApplication           = classlite.declareConstantField(nil),
    _mScriptCallback        = classlite.declareConstantField(nil),
}

function PyScriptCommandExecutor:new()
    self._mScriptCallback = function(...)
        local rets = utils.clearTable(self._mReturnValues)
        utils.packArray(rets, ...)
    end
end

function PyScriptCommandExecutor:setApplication(app)
    self._mApplication = app
end

function PyScriptCommandExecutor:_invokeImplScript(cmdArgs)
    local app = self._mApplication
    if app
    then
        local retCode, stdout = app:executeExternalCommand(cmdArgs)
        if retCode
        then
            serialize.deserializeFromString(stdout)
            return retCode, self._mReturnValues
        end
    end
end

function PyScriptCommandExecutor:__prepareArguments()
    local args = utils.clearTable(self._mArguments)
    local rets = utils.clearTable(self._mReturnArguments)
    local app = self._mApplication
    local cfg = app and app:getConfiguration()
    local pythonPath = cfg and cfg.python2BinPath
    if pythonPath
    then
        table.insert(args, pythonPath)
        table.insert(args, "-c")
        table.insert(args, _IMPL_FUNC_SCRIPT_CONTENT)
        return args, rets
    end
end

function PyScriptCommandExecutor:__execute(checkArgsFunc,
                                           buildArgsFunc,
                                           returnFunc,
                                           ...)
    local args, rets = self:__prepareArguments()
    if not args or not checkArgsFunc(...)
    then
        return
    end

    buildArgsFunc(args, rets, ...)
    local retCode, outValues = self:_invokeImplScript(args)
    if not retCode
    then
        return
    end

    utils.appendArrayElements(rets, outValues)
    return returnFunc(ret, utils.unpackArray(rets))
end

function PyScriptCommandExecutor:createDirs(path)
    local function _build(args, rets, path)
        table.insert(args, "create_dirs")
        _appendKeyValue(args, "path", path)
    end
    return self:__execute(types.isNonEmptyString, _build, __project1, path)
end

function PyScriptCommandExecutor:deletePath(path)
    local function _build(args, rets, path)
        table.insert(args, "delete_path")
        _appendKeyValue(args, "path", path)
    end
    return self:__execute(types.isNonEmptyString, _build, __project1, path)
end

function PyScriptCommandExecutor:redirectExternalCommand(content, cmdArgs)
    local function _check(content, cmdArgs)
        return types.isNonEmptyString(content) and types.isNonEmptyArray(cmdArgs)
    end
    local function _build(args, rets, content, cmdArgs)
        table.insert(args, "redirect_external_command")
        _appendKeyValue(args, "content", content)
        _appendKeyArray(args, "cmd_args", cmdArgs)
    end
    local function _return(ret, out)
        return types.toBoolean(ret), out
    end
    return self:__execute(_check, _build, _return, content, cmdArgs)
end

function PyScriptCommandExecutor:readUTF8File(path)
    local function _build(args, rets, path)
        table.insert(args, "read_utf8_file")
        _appendKeyArray(args, "path", path)
    end
    return self:__execute(types.isNonEmptyString, _build, __project2, path)
end

function PyScriptCommandExecutor:calculateFileMD5(path, byteCount)
    local function _check(path, byteCount)
        return types.isNonEmptyString(path) and __isNilOrPositiveInt(byteCount)
    end
    local function _build(args, rets, path, byteCount)
        table.insert(args, "calculate_file_md5")
        _appendKeyValue(args, "path", path)
        _appendKeyValue(args, "byte_count", tostring(byteCount))
    end
    byteCount = types.toInt(byteCount)
    return self:__execute(_check, _build, __project2, path, byteCount)
end

function PyScriptCommandExecutor:requestURLs(urls, timeout, flags, outArray)
    local function __isNotString(str)
        return not types.isString(str)
    end
    local function _check(urls, timeout, flags, outArray)
        return types.isNonEmptyArray(urls)
            and types.isNonEmptyArray(flags)
            and #urls == #flags
            and not utils.linearSearchArrayIf(urls, __isNotString)
            and __isNilOrPositiveInt(timeout)
            and types.isTable(outArray)
    end
    local function _build(args, rets, urls, timeout, flags, outArray)
        table.insert(args, "request_urls")
        _appendKeyArray("urls", urls)
        _appendKeyValue("timeout", timeout)
        _appendKeyArray("flags", flags)
        table.insert(rets, urls)
        table.insert(rets, outArray)
    end
    local function _return(ret, out, urls, outArray, ...)
        utils.clearTable(outArray)
        utils.utils.packArray(outArray)
        return types.chooseValue(#urls == #outArray, outArray)
    end
    timeout = types.toInt(timeout)
    return self:__execute(_check, _build, _return, urls, timeout, outArray)
end

classlite.declareClass(PyScriptCommandExecutor)


return
{
    REQ_URL_FLAG_UNCOMPRESS     = REQ_URL_FLAG_UNCOMPRESS,
    REQ_URL_FLAG_ACCEPT_XML     = REQ_URL_FLAG_ACCEPT_XML,

    PyScriptCommandExecutor     = PyScriptCommandExecutor,
}