local _base = require("src/_utils/_base")


local _UTF8_DECODE_BYTE_RANGE_START_LIST        = { 0x00, 0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
local _UTF8_DECODE_BYTE_RANG_END_LIST           = { 0x7f, 0xbf, 0xdf, 0xef, 0xf7, 0xfb, 0xfd }
local _UTF8_DECODE_BYTE_MASK_LIST               = { 0x00, 0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
local _UTF8_DECODE_TRAILING_BYTE_COUNT_LIST     = {  0,    nil,  1,    2,    3,    4,    5   }
local _UTF8_DECODE_SHIFT_POW_LIST               = {  1,    64,   32,   16,   8,    4,    2   }
local _UTF8_DECODE_TRAILING_BYTE_RANGE_INDEX    = 2
local _UTF8_DECODE_BYTE_RANGE_LIST_LEN          = #_UTF8_DECODE_BYTE_RANGE_START_LIST

local UTF8_INVALID_CODEPOINT                    = -1

local function __compareNumber(rangEnd, val)
    return rangEnd - val
end

local function __binarySearchNumList(list, val)
    return _base.binarySearchArray(list, __compareNumber, val)
end


local function __iterateUTF8CodePoints(byteString, byteStartIdx)
    local byteLen = byteString:len()
    if byteStartIdx > byteLen then
        return nil
    end

    local codePointByteCount = nil
    local codePoint = UTF8_INVALID_CODEPOINT
    local remainingByteCount = 0
    local nextStartByteIdx = byteLen
    for byteIdx = byteStartIdx, byteLen
    do
        nextStartByteIdx = byteIdx + 1

        -- 判断是 UTF8 字节类型
        -- 不是所有字节都是有效的 UTF8 字节，例如 0b11111111
        local b = byteString:byte(byteIdx)
        local found, rangeIdx = __binarySearchNumList(_UTF8_DECODE_BYTE_RANG_END_LIST, b)
        if not found and rangeIdx > _UTF8_DECODE_BYTE_RANGE_LIST_LEN
        then
            break
        end

        -- 出现连续的首字节，或首字节不合法
        local hasFirstByte = (codePoint ~= UTF8_INVALID_CODEPOINT)
        local isFirstByte = (rangeIdx ~= _UTF8_DECODE_TRAILING_BYTE_RANGE_INDEX)
        if hasFirstByte == isFirstByte
        then
            codePoint = UTF8_INVALID_CODEPOINT
            break
        end

        if not hasFirstByte
        then
            remainingByteCount = _UTF8_DECODE_TRAILING_BYTE_COUNT_LIST[rangeIdx] + 1
            codePointByteCount = remainingByteCount
        end

        codePoint = (isFirstByte and 0 or codePoint) * _UTF8_DECODE_SHIFT_POW_LIST[rangeIdx]
        codePoint = codePoint + (b - _UTF8_DECODE_BYTE_MASK_LIST[rangeIdx])
        remainingByteCount = remainingByteCount - 1

        if remainingByteCount <= 0
        then
            break
        end

    end

    -- 下次迭代的起始字节索引, Unicode 编码, 字符串字节长度
    return nextStartByteIdx, codePoint, codePointByteCount
end

local function iterateUTF8CodePoints(byteString)
    return __iterateUTF8CodePoints, byteString, 1
end



local _UTF8_CODEPOINT_MIN = 0
local _UTF8_CODEPOINT_MAX = 0x80000000

local _UTF8_ENCODE_TRAILING_BYTE_DIV_POW = 2^6

local _UTF8_ENCODE_CODEPOINT_RANGE_END_LIST =
{
    0x7f,
    0x7ff,
    0xffff,
    0x1fffff,
    0x3ffffff,
    0x7fffffff,
}

local _UTF8_ENCODE_BYTE_MASK_LIST =
{
    { 0 },
    { 0xc0, 0x80 },
    { 0xe0, 0x80, 0x80 },
    { 0xf0, 0x80, 0x80, 0x80 },
    { 0xf8, 0x80, 0x80, 0x80, 0x80 },
    { 0xfc, 0x80, 0x80, 0x80, 0x80, 0x80 },
}


local function getUTF8Bytes(codePoint, outList, convertFunc)
    if codePoint < _UTF8_CODEPOINT_MIN or codePoint >= _UTF8_CODEPOINT_MAX
    then
        return 0
    end

    local _, rangeIdx = __binarySearchNumList(_UTF8_ENCODE_CODEPOINT_RANGE_END_LIST, codePoint)
    local bitMasks = _UTF8_ENCODE_BYTE_MASK_LIST[rangeIdx]
    local writeByteCount = #bitMasks
    local remainingBits = codePoint
    local writeStartIdx = #outList

    for i = writeByteCount, 1, -1
    do
        -- 提取低有效位，并加上掩码
        local outBits = remainingBits
        local shifted = 0
        if i ~= 1
        then
            shifted = math.floor(remainingBits / _UTF8_ENCODE_TRAILING_BYTE_DIV_POW)
            outBits = math.floor(remainingBits - shifted * _UTF8_ENCODE_TRAILING_BYTE_DIV_POW)
        end

        local byteVal = bitMasks[i] + outBits
        local writeVal = convertFunc and convertFunc(byteVal) or byteVal
        outList[writeStartIdx + i] = writeVal
        remainingBits = shifted
    end

    return writeByteCount
end



return
{
    UTF8_INVALID_CODEPOINT  = UTF8_INVALID_CODEPOINT,
    iterateUTF8CodePoints   = iterateUTF8CodePoints,
    getUTF8Bytes            = getUTF8Bytes,
}