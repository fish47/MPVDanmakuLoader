local types         = require("src/base/types")
local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local application   = require("src/shell/application")
local mock          = require("test/mock")


local _SCRIPT_FILE_PATH     = "src/unportable/_impl.py"

local _DEFAULT_RETURN_CODE  = 65535

local _SHELL_SYNTAX_ARGUMENT_SEP            = " "
local _SHELL_SYNTAX_STRONG_QUOTE            = "\'"
local _SHELL_CONST_STRONG_QUOTE_ESCAPED     = "'\"'\"'"

-- 从 pipes.py 抄过来的
local function __quoteShellString(text)
    text = tostring(text)
    local replaced = text:gsub(_SHELL_SYNTAX_STRONG_QUOTE,
                               _SHELL_CONST_STRONG_QUOTE_ESCAPED)
    return _SHELL_SYNTAX_STRONG_QUOTE
           .. replaced
           .. _SHELL_SYNTAX_STRONG_QUOTE
end


local DemoPyScriptCommandExecutor =
{
    __mScriptContent    = classlite.declareConstantField(nil),
}

function DemoPyScriptCommandExecutor:_getScriptContent()
    if not self.__mScriptContent
    then
        local f = io.open(_SCRIPT_FILE_PATH)
        self.__mScriptContent = f:read(constants.READ_MODE_ALL)
        f:close()
    end
    return self.__mScriptContent
end

classlite.declareClass(DemoPyScriptCommandExecutor, unportable.PyScriptCommandExecutor)


local DemoApplication =
{
    __mCommandBuf               = classlite.declareTableField(),
    __mTempFilePathSet          = classlite.declareTableField(),
    _mPyScriptCmdExecutor       = classlite.declareClassField(DemoPyScriptCommandExecutor),

    _initDanmakuSourcePlugins   = application.MPVDanmakuLoaderApp._initDanmakuSourcePlugins,
}

function DemoApplication:dispose()
    local function __delete(path)
        os.remove(path)
    end
    local pathSet = self.__mTempFilePathSet
    utils.forEachSetElement(pathSet, __delete)
    utils.clearTable(pathSet)
end

function DemoApplication:_getTempFilePath()
    local ret = application.MPVDanmakuLoaderApp._getTempFilePath(self)
    utils.pushSetElement(self.__mTempFilePathSet, ret)
    return ret
end

function DemoApplication:__isTempFilePath(path)
    return types.isString(path) and self.__mTempFilePathSet[path]
end

function DemoApplication:writeFile(path, ...)
    local func = types.chooseValue(self:__isTempFilePath(path),
                                   application.MPVDanmakuLoaderApp.writeFile,
                                   mock.MockApplication.writeFile)
    return func(self, path, ...)
end

function DemoApplication:readFile(path, ...)
    local func = types.chooseValue(self:__isTempFilePath(path),
                                   application.MPVDanmakuLoaderApp.readFile,
                                   mock.MockApplication.readFile)
    return func(self, path, ...)
end

function DemoApplication:_spawnSubprocess(cmdArgs)
    local buf = utils.clearTable(self.__mCommandBuf)
    table.insert(buf, cmdArgs[1])
    for i = 2, #cmdArgs
    do
        local arg = __quoteShellString(cmdArgs[i])
        table.insert(buf, arg)
    end

    local cmd = table.concat(buf, _SHELL_SYNTAX_ARGUMENT_SEP)
    local f = io.popen(cmd)
    if f
    then
        local stdout = f:read(constants.READ_MODE_ALL)
        local _, reason, retCode = f:close()
        if reason and retCode
        then
            return retCode, stdout
        end
    end
    utils.clearTable(cmd)
    return _DEFAULT_RETURN_CODE, nil
end

classlite.declareClass(DemoApplication, mock.MockApplication)


return
{
    DemoApplication     = DemoApplication,
}