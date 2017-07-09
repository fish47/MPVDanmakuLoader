local types     = require("src/base/types")
local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")
local constants = require("src/base/constants")
local serialize = require("src/base/serialize")


local _REQ_URL_FLAG_NONE            = 0
local _REQ_URL_FLAG_UNCOMPRESS      = bit32.lshift(1, 0)
local _REQ_URL_FLAG_ACCEPT_XML      = bit32.lshift(1, 1)

-- 不能向命令行参数传大量字符串，如有必要只能用文件转存
local _MAX_TRANSFER_BYTE_COUNT      = 1024

local _MARK_TEMP_FILE_OUTPUT        = "TEMP_FILE_OUTPUT"


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
        table.insert(args, #value)
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
    _mApplication           = classlite.declareConstantField(nil),
    _mArguments             = classlite.declareTableField(),
    _mReturnArguments       = classlite.declareTableField(),
    _mReturnValues          = classlite.declareTableField(),
    _mScriptCallback        = classlite.declareConstantField(nil),
    _mScriptPath            = classlite.declareConstantField(nil),
    _mTempFilePath          = classlite.declareConstantField(nil),
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

function PyScriptCommandExecutor:setTempFilePath(path)
    self._mTempFilePath = path
end


function PyScriptCommandExecutor:__writeTempFileIfExceed(content)
    local app = self._mApplication
    local tmpPath = self._mTempFilePath
    if #content > _MAX_TRANSFER_BYTE_COUNT and app and tmpPath
    then
        utils.writeAndCloseFile(app, tmpPath, content)
        return constants.STR_EMPTY, tmpPath
    else
        return content
    end
end

function PyScriptCommandExecutor:extractScript(path)
    local app = self._mApplication
    if utils.writeAndCloseFile(app, path, self:_getScriptContent())
    then
        self._mScriptPath = path
    end
end

function PyScriptCommandExecutor:__invokeImplScript(cmdArgs)
    local app = self._mApplication
    if app
    then
        local retCode, stdout = app:executeExternalCommand(cmdArgs)
        if retCode
        then
            local callback = self._mScriptCallback
            local outValues = utils.clearTable(self._mReturnValues)
            if stdout == _MARK_TEMP_FILE_OUTPUT
            then
                serialize.deserializeFromFilePath(self._mTempFilePath, callback)
            else
                serialize.deserializeFromString(stdout, callback)
            end
            return retCode, outValues
        end
    end
end

function PyScriptCommandExecutor:_getScriptContent()
    -- 下面内容会被构建脚本修改
    return __SCRIPT_CONTENT__
end

function PyScriptCommandExecutor:__prepareArguments()
    local args = utils.clearTable(self._mArguments)
    local rets = utils.clearTable(self._mReturnArguments)
    local app = self._mApplication
    local cfg = app and app:getConfiguration()
    local pythonPath = cfg and cfg.pythonPath
    local scriptPath = self._mScriptPath
    if pythonPath and scriptPath
    then
        table.insert(args, pythonPath)
        table.insert(args, scriptPath)
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
    local retCode, outValues = self:__invokeImplScript(args)
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

function PyScriptCommandExecutor:redirectExternalCommand(cmdArgs, content)
    local function _check(content, cmdArgs)
        return types.isNonEmptyString(content) and types.isNonEmptyArray(cmdArgs)
    end
    local function _build(args, rets, content, cmdArgs, executor)
        local contentArg, tmpPath = executor:__writeTempFileIfExceed(content)
        table.insert(args, "redirect_external_command")
        _appendKeyValue(args, "content", contentArg)
        _appendKeyArray(args, "cmd_args", cmdArgs)
        _appendKeyValue(args, "tmp_path", tmpPath)
    end
    local function _return(ret, out)
        return types.toBoolean(ret), out
    end
    return self:__execute(_check, _build, _return, content, cmdArgs, self)
end

function PyScriptCommandExecutor:readUTF8File(path)
    local function _build(args, rets, path, tempPath)
        table.insert(args, "read_utf8_file")
        _appendKeyValue(args, "path", path)
        _appendKeyValue(args, "tmp_path", tempPath)
    end
    local tempPath = self._mTempFilePath
    return self:__execute(types.isNonEmptyString, _build, __project2, path, tempPath)
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
    local function _build(args, rets, urls, timeout, flags, tmpPath, outArray)
        table.insert(args, "request_urls")
        _appendKeyArray("urls", urls)
        _appendKeyValue("timeout", timeout)
        _appendKeyArray("flags", flags)
        _appendKeyValue("tmp_path", tmpPath)
        table.insert(rets, urls)
        table.insert(rets, outArray)
    end
    local function _return(ret, out, urls, outArray, ...)
        utils.clearTable(outArray)
        utils.utils.packArray(outArray)
        return types.chooseValue(#urls == #outArray, outArray)
    end

    local tmpPath = self._mTempFilePath
    timeout = types.toInt(timeout)
    return self:__execute(_check, _build, _return, urls, timeout, tmpPath, outArray)
end

classlite.declareClass(PyScriptCommandExecutor)


return
{
    _REQ_URL_FLAG_NONE          = _REQ_URL_FLAG_NONE,
    _REQ_URL_FLAG_UNCOMPRESS    = _REQ_URL_FLAG_UNCOMPRESS,
    _REQ_URL_FLAG_ACCEPT_XML    = _REQ_URL_FLAG_ACCEPT_XML,

    PyScriptCommandExecutor     = PyScriptCommandExecutor,
}