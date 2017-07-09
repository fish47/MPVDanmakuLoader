local types         = require("src/base/types")
local constants     = require("src/base/constants")


local function invokeSafely(func, ...)
    if types.isFunction(func)
    then
        -- 即使可能是最后一句，但明确 return 才是尾调用
        return func(...)
    end
end

local function disposeSafely(obj)
    local func = types.isTable(obj) and obj.dispose or nil
    if func
    then
        func(obj)
    end
end

local function writeAndCloseFile(app, path, content, isAppend)
    if app and types.isString(path) and types.isString(content)
    then
        local f = app:writeFile(path, isAppend)
        if f
        then
            f:write(content)
            app:closeFile(f)
            return true
        end
    end
    return false
end

local function readAndCloseFile(app, path, asUTF8)
    if app and types.isString(path)
    then
        local f = nil
        if asUTF8
        then
            f = app:readUTF8File(path)
        else
            f = app:readFile(path)
        end
        if f
        then
            local ret = f:read(constants.READ_MODE_ALL)
            app:closeFile(f)
            return ret
        end
    end
    return nil
end


return
{
    invokeSafely        = invokeSafely,
    disposeSafely       = disposeSafely,
    writeAndCloseFile   = writeAndCloseFile,
    readAndCloseFile    = readAndCloseFile,
}