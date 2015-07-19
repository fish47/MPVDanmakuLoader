local _M = {}

_M.__gClassMetaTables = {}


local function __createClassMetaTable(clzDefObj)
    local ret = _M.__gClassMetaTables[clzDefObj]
    ret = { __index = clzDefObj }
    _M.__gClassMetaTables[clzDefObj] = ret
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


function _M.declareClass(clzDefObj, baseClzDefObj)
    -- 有可能是继承
    if baseClzDefObj ~= nil
    then
        __addMissedEntries(clzDefObj, baseClzDefObj)

        -- 如果没有声明构造方法
        if clzDefObj.new == nil
        then
            clzDefObj.new = function(obj, ...)
                obj = _M.allocateInstance(obj)
                return baseClzDefObj.new(obj, ...)
            end
        end
    end

    __createClassMetaTable(clzDefObj)
    return clzDefObj
end


function _M.allocateInstance(objArg)
    local mt = _M.__gClassMetaTables[objArg]
    if mt ~= nil
    then
        -- 如果以 ClazDefObj:new() 的形式调用，第一个参数就是指向 Class 本身
        local ret = {}
        setmetatable(ret, mt)
        return ret
    else
        -- 也有可能是子类间接调用父类的构建方法，此时不应再创建实例
        return objArg
    end
end


function _M.findIf(iter, list, cond, val)
    if not list
    then
        return nil
    end

    for i, v in iter(list)
    do
        if cond(v, val)
        then
            return i, v
        end
    end
    return nil
end


function _M.binarySearchList(list, cond, val)
    local low = 1
    local high = #list
    while low <= high
    do
        local mid = math.floor((low + high) / 2)
        local midVal = list[mid]
        local cmpRet = cond(list[mid], val)

        if cmpRet == 0
        then
            return mid, midVal
        elseif cmpRet > 0
        then
            high = mid - 1
        else
            low = mid + 1
        end
    end

    -- 找不到返回的是插入位置
    return low, nil
end


local function __doIteratePairsArray(array, idx)
    if idx + 1 > #array
    then
        return nil
    end

    return idx + 2, array[idx], array[idx + 1]
end

function _M.iteratePairsArray(array, startIdx)
    return __doIteratePairsArray, array, startIdx or 1
end

local __unpackImpl = table.unpack or unpack

function _M.unpack(tbl)
    return __unpackImpl(tbl)
end

function _M.isTable(o)
    return type(o) == "table"
end

function _M.isEmptyTable(o)
    return _M.isTable(o) and next(o) == nil
end

function _M.isString(o)
    return type(o) == "string"
end

function _M.isNumber(o)
    return type(o) == "number"
end


function _M.clearTable(t)
    if _M.isTable(t)
    then
        for k, v in pairs(t)
        do
            t[k] = nil
        end
    end

    return t
end


return _M