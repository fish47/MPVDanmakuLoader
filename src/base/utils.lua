local _algo     = require("src/base/_algo")
local _conv     = require("src/base/_conv")
local _validate = require("src/base/_validate")
local types     = require("src/base/types")
local constants = require("src/base/constants")


local function invokeSafely(func, ...)
    if types.isFunction(func)
    then
        -- 即使可能是最后一句，但明确 return 才是尾调用
        return func(...)
    end
end


local function __createSafeInvokeWrapper(funcName)
    local ret = function(obj)
        if types.isTable(obj)
        then
            invokeSafely(obj[funcName], obj)
        end
    end

    return ret
end


local function writeAndCloseFile(f, content)
    if types.isOpenedFile(f)
    then
        local succeed = f:write(content)
        f:close()
        return succeed
    end
end


local function readAndCloseFile(f)
    if types.isOpenedFile(f)
    then
        local readRet = f:read(constants.READ_MODE_ALL)
        return readRet, f:close()
    end
end


return _algo._mergeModuleTables(
    {
        invokeSafely        = invokeSafely,
        closeSafely         = __createSafeInvokeWrapper("close"),
        disposeSafely       = __createSafeInvokeWrapper("dispose"),

        writeAndCloseFile   = writeAndCloseFile,
        readAndCloseFile    = readAndCloseFile,
    }, _algo, _conv, _validate)