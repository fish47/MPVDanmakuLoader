local types     = require("src/base/types")
local constants = require("src/base/constants")


local function clearTable(tbl)
    if types.isTable(tbl)
    then
        for k, _ in pairs(tbl)
        do
            tbl[k] = nil
        end
    end
    return tbl
end


local function clearArray(array, startIdx, endIdx)
    if types.isTable(array)
    then
        startIdx = startIdx or 1
        endIdx = endIdx or #array
        for i = startIdx, endIdx
        do
            array[i] = nil
        end
    end
    return array
end


local function mergeTable(destTbl, srcTbl, isJustMergeMissed)
    if types.isTable(destTbl) and types.isTable(srcTbl)
    then
        for k, v in pairs(srcTbl)
        do
            destTbl[k] = isJustMergeMissed and destTbl[k] or v
        end
    end
    return destTbl
end


local function appendArray(destArray, srcArray)
    if types.isTable(destArray) and types.isTable(srcArray)
    then
        for _, v in ipairs(srcArray)
        do
            table.insert(destArray, v)
        end
    end
    return destArray
end


local function linearSearchArray(array, val)
    if types.isTable(array)
    then
        for idx, v in ipairs(array)
        do
            if val == v
            then
                return true, idx
            end
        end
    end
    return false
end


local function binarySearchArray(list, compareFunc, val)
    if not types.isTable(list) or not types.isFunction(compareFunc)
    then
        return false
    end

    local low = 1
    local high = #list
    while low <= high
    do
        local mid = math.floor((low + high) / 2)
        local midVal = list[mid]
        local cmpRet = compareFunc(list[mid], val)

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
    if not types.isTable(array)
    then
        return constants.FUNC_EMPTY
    end

    return __doIteratePairsArray, array, startIdx or 1
end


local function fillArrayWithAscNumbers(array, count)
    for i = 1, count
    do
        array[i] = i
    end

    for i = count + 1, #array
    do
        array[i] = nil
    end
end


local function __reorderArray(indexes, array, arrayBak)
    for i = 1, #indexes
    do
        arrayBak[i] = array[i]
    end

    for i = 1, #indexes
    do
        array[i] = arrayBak[indexes[i]]
    end
end


local function sortParallelArrays(...)
    if types.isEmptyVarArgs(...)
    then
        return
    end

    -- 允许第一个参数是比较函数
    local firstArg = select(1, ...)
    local hasCompareFunc = types.isFunction(firstArg)
    local compareFunc = hasCompareFunc and firstArg
    local arrayStartIdx = 1 + types.toNumber(hasCompareFunc)

    local firstArray = select(arrayStartIdx, ...)
    if not firstArray
    then
        return
    end


    local compareFuncArg = hasCompareFunc and function(idx1, idx2)
        return compareFunc(firstArray[idx1], firstArray[idx2])
    end

    -- 获取排序后的新位置
    local indexes = {}
    fillArrayWithAscNumbers(indexes, #firstArray)
    table.sort(indexes, compareFuncArg)


    -- 调整位置
    local arrayBak = nil
    for i = arrayStartIdx, types.getVarArgCount(...)
    do
        arrayBak = arrayBak or {}
        __reorderArray(indexes, select(i, ...), arrayBak)
    end

    clearTable(indexes)
    clearTable(arrayBak)

    indexes = nil
    arrayBak = nil
    compareFuncArg = nil
end


local function __doReverseIterateArrayImpl(array, idx)
    if idx < 1
    then
        return nil
    end

    return idx - 1, array[idx]
end

local function reverseIterateArray(array)
    if not types.isTable(array)
    then
        return constants.FUNC_EMPTY
    end

    return __doReverseIterateArrayImpl, array, #array
end


return
{
    clearTable                  = clearTable,
    mergeTable                  = mergeTable,
    clearArray                  = clearArray,
    unpackArray                 = unpack or table.unpack,
    appendArray                 = appendArray,
    linearSearchArray           = linearSearchArray,
    binarySearchArray           = binarySearchArray,
    reverseIterateArray         = reverseIterateArray,
    iteratePairsArray           = iteratePairsArray,
    sortParallelArrays          = sortParallelArrays,
    fillArrayWithAscNumbers     = fillArrayWithAscNumbers,
}