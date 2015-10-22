local _base = require("src/_utils/_base")


local __gClassMetaTables = {}

local function __createClassMetaTable(clzDefObj)
    local ret = __gClassMetaTables[clzDefObj]
    ret = { __index = clzDefObj }
    __gClassMetaTables[clzDefObj] = ret
    return ret
end


local function __addMissedEntries(destTable, newTable)
    if newTable == nil
    then
        return
    end

    for k, v in pairs(newTable)
    do
        if not destTable[k]
        then
            destTable[k] = v
        end
    end
end


local function allocateInstance(objArg)
    local mt = __gClassMetaTables[objArg]
    if mt ~= nil
    then
        -- 如果以 ClazDefObj:new() 的形式调用，第一个参数就是指向 Class 本身
        local ret = {}
        setmetatable(ret, mt)
        return ret
    else
        -- 也有可能是子类间接调用父类的构造方法，此时不应再创建实例
        return objArg
    end
end


local function declareClass(clzDefObj, baseClzDefObj)
    -- 有可能是继承
    if baseClzDefObj ~= nil
    then
        __addMissedEntries(clzDefObj, baseClzDefObj)
    end

    -- 生成默认构造方法，如果没有的话
    if not clzDefObj.new
    then
        clzDefObj.new = function(obj)
            -- 一般父类会有明确的构造方法
            return allocateInstance(obj)
        end
    end

    -- 默认析构方法
    if not clzDefObj.dispose
    then
        clzDefObj.dispose = function(obj)
            _base.clearTable(obj)
        end
    end

    __createClassMetaTable(clzDefObj)
    return clzDefObj
end


local function METHOD_NOT_IMPLEMENTED()
    assert(0)
end


return
{
    METHOD_NOT_IMPLEMENTED  = METHOD_NOT_IMPLEMENTED,
    allocateInstance        = allocateInstance,
    declareClass            = declareClass,
}