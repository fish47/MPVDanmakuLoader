local types     = require("src/base/types")


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


return
{
    invokeSafely        = invokeSafely,
    disposeSafely       = disposeSafely,
}