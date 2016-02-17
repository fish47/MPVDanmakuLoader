local types     = require("src/base/types")
local constants = require("src/base/constants")

local function __equals(val1, val2)
    return val1 == val2
end


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


local __gFreeTables = {}

local function _obtainTable()
    local count = #__gFreeTables
    if count > 0
    then
        local ret = __gFreeTables[count]
        __gFreeTables[count] = nil
        return ret
    end
    return {}
end

local function _recycleTable(tbl)
    if types.isTable(tbl)
    then
        clearTable(tbl)
        table.insert(__gFreeTables, tbl)
    end
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


local function appendArrayElementsIf(destArray, srcArray, filterFunc, arg)
    if types.isTable(destArray) and types.isTable(srcArray)
    then
        for _, v in ipairs(srcArray)
        do
            if not filterFunc or filterFunc(v, arg)
            then
                table.insert(destArray, v)
            end
        end
    end
    return destArray
end


local function appendArrayElements(destArray, srcArray)
    return appendArrayElementsIf(destArray, srcArray)
end


local function packArray(array, ...)
    if types.isTable(array)
    then
        for i = 1, types.getVarArgCount(...)
        do
            local val = select(i, ...)
            table.insert(array, val)
        end
    end
    return array
end


local function linearSearchArrayIf(array, func, arg)
    if types.isTable(array)
    then
        for idx, v in ipairs(array)
        do
            if func(v, arg)
            then
                return true, idx, v
            end
        end
    end
    return false
end


local function linearSearchArray(array, val)
    return linearSearchArrayIf(array, __equals, val)
end


local function binarySearchArrayIf(list, func, arg)
    if not types.isTable(list) or not types.isFunction(func)
    then
        return false
    end

    local low = 1
    local high = #list
    while low <= high
    do
        local mid = math.floor((low + high) / 2)
        local midVal = list[mid]
        local cmpRet = func(list[mid], arg)

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
    local nextIdx = idx and idx + 2 or 1
    if nextIdx > #array
    then
        return nil
    end

    return nextIdx, array[nextIdx], array[nextIdx + 1]
end

local function iteratePairsArray(array, startIdx)
    if not types.isTable(array)
    then
        return constants.FUNC_EMPTY
    end

    return __doIteratePairsArray, array, startIdx
end


local function fillArrayWithAscNumbers(array, count)
    for i = 1, count
    do
        array[i] = i
    end
    clearArray(array, count + 1)
end


local function reverseArray(array, startIdx, lastIdx)
    if types.isTable(array)
    then
        startIdx = startIdx or 1
        lastIdx = lastIdx or #array
        while startIdx < lastIdx
        do
            local lowVal = array[startIdx]
            local highVal = array[lastIdx]
            array[startIdx] = lowVal
            array[lastIdx] = highVal
            startIdx = startIdx + 1
            lastIdx = lastIdx - 1
        end
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

    -- 以第一个数组内容作为排序关键词
    local firstArray = select(arrayStartIdx, ...)
    if not firstArray
    then
        return
    end

    local compareFuncArg = nil
    if hasCompareFunc
    then
        compareFuncArg = function(idx1, idx2)
            return compareFunc(firstArray[idx1], firstArray[idx2])
        end
    else
        compareFuncArg = function(idx1, idx2)
            return firstArray[idx1] < firstArray[idx2]
        end
    end

    -- 获取排序后的新位置
    local indexes = _obtainTable()
    fillArrayWithAscNumbers(indexes, #firstArray)
    table.sort(indexes, compareFuncArg)


    -- 调整位置
    local arrayBak = nil
    for i = arrayStartIdx, types.getVarArgCount(...)
    do
        arrayBak = arrayBak or _obtainTable()
        __reorderArray(indexes, select(i, ...), arrayBak)
    end

    _recycleTable(indexes)
    _recycleTable(arrayBak)

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

local function iterateTable(tbl)
    if not types.isTable(tbl)
    then
        return constants.FUNC_EMPTY
    end
    return pairs(tbl)
end

local function iterateArray(array)
    if not types.isTable(array)
    then
        return constants.FUNC_EMPTY
    end

    return ipairs(array)
end

local function popArrayElement(array)
    if types.isTable(array)
    then
        local count = #array
        local ret = array[count]
        array[count] = nil
        return ret
    end
end

local function pushArrayElement(array, elem)
    if types.isTable(array) and not types.isNil(elem)
    then
        table.insert(array, elem)
    end
end


local function removeArrayElementsIf(array, func, arg)
    if types.isTable(array)
    then
        local writeIdx = 1
        for i, element in ipairs(array)
        do
            if not func(element, arg)
            then
                array[writeIdx] = element
                writeIdx = writeIdx + 1
            end
        end
        clearArray(array, writeIdx)
    end
end

local function removeArrayElements(array, val)
    removeArrayElementsIf(array, __equals, val)
end

local function forEachArrayElement(array, func, arg)
    if types.isFunction(func)
    then
        for i, v in iterateArray(array)
        do
            func(v, i, array, arg)
        end
    end
end

local function forEachTableKey(tbl, func, arg)
    if types.isFunction(func)
    then
        for k, v in iterateTable(tbl)
        do
            func(k, v, tbl, arg)
        end
    end
end

local function forEachTableValue(tbl, func, arg)
    if types.isFunction(func)
    then
        for k, v in iterateTable(tbl)
        do
            func(v, k, tbl, arg)
        end
    end
end


return
{
    _obtainTable                = _obtainTable,
    _recycleTable               = _recycleTable,
    clearTable                  = clearTable,
    mergeTable                  = mergeTable,
    clearArray                  = clearArray,
    packArray                   = packArray,
    unpackArray                 = unpack or table.unpack,
    appendArrayElements         = appendArrayElements,
    appendArrayElementsIf       = appendArrayElementsIf,
    removeArrayElements         = removeArrayElements,
    removeArrayElementsIf       = removeArrayElementsIf,
    pushArrayElement            = pushArrayElement,
    popArrayElement             = popArrayElement,
    linearSearchArray           = linearSearchArray,
    linearSearchArrayIf         = linearSearchArrayIf,
    binarySearchArrayIf         = binarySearchArrayIf,
    iterateTable                = iterateTable,
    iterateArray                = iterateArray,
    reverseIterateArray         = reverseIterateArray,
    iteratePairsArray           = iteratePairsArray,
    forEachArrayElement         = forEachArrayElement,
    forEachTableKey             = forEachTableKey,
    forEachTableValue           = forEachTableValue,
    sortParallelArrays          = sortParallelArrays,
    fillArrayWithAscNumbers     = fillArrayWithAscNumbers,
}