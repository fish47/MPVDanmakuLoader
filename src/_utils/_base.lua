
local function isTable(o)
    return type(o) == "table"
end


local function isEmptyTable(o)
    return isTable(o) and next(o) == nil
end


local function isString(o)
    return type(o) == "string"
end


local function isNumber(o)
    return type(o) == "number"
end

local function isConstant(o)
    local typeString = type(o)
    return typeString == "number"
           or typeString == "boolean"
           or typeString == "nil"
end


local function clearTable(t)
    if isTable(t)
    then
        while true
        do
            local k = next(t)
            if not k
            then
                break
            end

            t[k] = nil
        end
    end

    return t
end


local function updateTable(destTbl, srcTbl)
    for k, v in pairs(srcTbl)
    do
        destTbl[k] = v
    end
end


local function appendArray(destArray, srcArray)
    for _, v in ipairs(srcArray)
    do
        table.insert(destArray, v)
    end
end


local _PATTERN_PRIVATE_MEMBER   = "^_"

local function exportModules(...)
    local destTbl = {}
    local moduleTables = {...}
    for _, moduleTbl in ipairs(moduleTables)
    do
        for k, v in pairs(moduleTbl)
        do
            if not k:match(_PATTERN_PRIVATE_MEMBER)
            then
                destTbl[k] = v
            end
        end
    end
    return destTbl
end


local function binarySearchArray(list, cond, val)
    local low = 1
    local high = #list
    while low <= high
    do
        local mid = math.floor((low + high) / 2)
        local midVal = list[mid]
        local cmpRet = cond(list[mid], val)

        if cmpRet == 0
        then
            return true, mid, midVal
        elseif cmpRet > 0
        then
            high = mid - 1
        else
            low = mid + 1
        end
    end

    -- 找不到返回的是插入位置
    return false, low, nil
end


local function __doIteratePairsArray(array, idx)
    if idx + 1 > #array
    then
        return nil
    end

    return idx + 2, array[idx], array[idx + 1]
end


local function iteratePairsArray(array, startIdx)
    return __doIteratePairsArray, array, startIdx or 1
end


local function disposeSafely(obj)
    if obj
    then
        obj:dispose()
    end
end

local function closeSafely(obj)
    if obj
    then
        obj:close()
    end
end


local function readAndCloseFile(f)
    if f
    then
        local readRet = f:read("*a")
        local succeed, state, retCode = f:close()
        succeed = (state == "exit")
        retCode = succeed and retCode or nil
        return readRet, succeed, retCode
    end
    return nil
end


local _LUA_VERSION  = tonumber(string.match(_VERSION, "(%d+%.%d)") or 5)

local function getLuaVersion()
    return _LUA_VERSION
end


return
{
    isTable             = isTable,
    isEmptyTable        = isEmptyTable,
    isString            = isString,
    isNumber            = isNumber,
    isConstant          = isConstant,
    unpackArray         = unpack or table.unpack,
    appendArray         = appendArray,
    clearTable          = clearTable,
    updateTable         = updateTable,
    exportModules       = exportModules,
    iteratePairsArray   = iteratePairsArray,
    binarySearchArray   = binarySearchArray,
    disposeSafely       = disposeSafely,
    closeSafely         = closeSafely,
    readAndCloseFile    = readAndCloseFile,
    getLuaVersion       = getLuaVersion,
}