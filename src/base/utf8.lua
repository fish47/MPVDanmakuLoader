local _algo = require("src/base/_algo")


local _DECODE_BYTE_RANGE_STARTS         = { 0x00, 0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
local _DECODE_BYTE_RANG_ENDS            = { 0x7f, 0xbf, 0xdf, 0xef, 0xf7, 0xfb, 0xfd }
local _DECODE_BYTE_MASKS                = { 0x00, 0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
local _DECODE_TRAILING_BYTE_COUNTS      = {  0,    nil,  1,    2,    3,    4,    5   }
local _DECODE_LSHIFT_MULS               = {  1,    64,   32,   16,   8,    4,    2   }
local _DECODE_TRAILING_BYTE_RANGE_INDEX = 2
local _DECODE_BYTE_RANGES_LEN           = #_DECODE_BYTE_RANGE_STARTS

local UTF8_INVALID_CODEPOINT            = -1

local function __compareNumber(rangEnd, val)
    return rangEnd - val
end

local function __binarySearchNums(list, val)
    return _algo.binarySearchArray(list, __compareNumber, val)
end


local function __doIterateUTF8CodePoints(byteString, byteStartIdx)
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
        local found, idx = __binarySearchNums(_DECODE_BYTE_RANG_ENDS, b)
        if not found and idx > _DECODE_BYTE_RANGES_LEN
        then
            break
        end

        -- 出现连续的首字节，或首字节不合法
        local hasFirstByte = (codePoint ~= UTF8_INVALID_CODEPOINT)
        local isFirstByte = (idx ~= _DECODE_TRAILING_BYTE_RANGE_INDEX)
        if hasFirstByte == isFirstByte
        then
            codePoint = UTF8_INVALID_CODEPOINT
            break
        end

        if not hasFirstByte
        then
            remainingByteCount = _DECODE_TRAILING_BYTE_COUNTS[idx] + 1
            codePointByteCount = remainingByteCount
        end

        codePoint = (isFirstByte and 0 or codePoint) * _DECODE_LSHIFT_MULS[idx]
        codePoint = codePoint + (b - _DECODE_BYTE_MASKS[idx])
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
    return __doIterateUTF8CodePoints, byteString, 1
end




local _ENCODE_CODEPOINT_RANGE_ENDS  =
{
    0x7f,
    0x7ff,
    0xffff,
    0x1fffff,
    0x3ffffff,
    0x7fffffff,
}

local _ENCODE_DIVS                  =
{
    2^0,  nil,
    2^6,  2^0,  nil,
    2^12, 2^6,  2^0,  nil,
    2^18, 2^12, 2^6,  2^0,  nil,
    2^24, 2^18, 2^12, 2^6,  2^0,  nil,
    2^30, 2^24, 2^18, 2^12, 2^6,  2^0,  nil,
    2^36, 2^30, 2^24, 2^18, 2^12, 2^6,  2^0,  nil,
}


local _ENCODE_MODS                  =
{
    2^7, nil,
    2^5, 2^6, nil,
    2^4, 2^6, 2^6, nil,
    2^3, 2^6, 2^6, 2^6, nil,
    2^2, 2^6, 2^6, 2^6, 2^6, nil,
    2^1, 2^6, 2^6, 2^6, 2^6, 2^6, nil,
    2^0, 2^6, 2^6, 2^6, 2^6, 2^6, 2^6, nil,
}

local _ENCODE_MASKS                 =
{
    0x00, nil,
    0xc0, 0x80, nil,
    0xe0, 0x80, 0x80, nil,
    0xf0, 0x80, 0x80, 0x80, nil,
    0xf8, 0x80, 0x80, 0x80, 0x80, nil,
    0xfc, 0x80, 0x80, 0x80, 0x80, 0x80, nil,
    0xfe, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, nil,
}

local _ENCODE_ITERATE_INDEXES       = { 1, 3, 6, 10, 15, 21, 28 }

local _CODEPOINT_MIN                = 0
local _CODEPOINT_MAX                = 0x7fffffff


local function __dummyIterateFunction()
    return nil
end

local function __doIterateUTF8EncodedBytes(codePoint, iterIdx)
    local div = _ENCODE_DIVS[iterIdx]
    local mask = _ENCODE_MASKS[iterIdx]
    local mod = _ENCODE_MODS[iterIdx]
    if div and mask and mod
    then
        local ret = math.floor(codePoint / div % mod) + mask
        return iterIdx + 1, ret
    else
        return nil
    end
end


local function iterateUTF8EncodedBytes(codePoint)
    if codePoint > _CODEPOINT_MAX or codePoint < _CODEPOINT_MIN
    then
        return __dummyIterateFunction
    end

    local _, idx = __binarySearchNums(_ENCODE_CODEPOINT_RANGE_ENDS, codePoint)
    local iterIdx = _ENCODE_ITERATE_INDEXES[idx]
    return __doIterateUTF8EncodedBytes, codePoint, iterIdx
end


return
{
    UTF8_INVALID_CODEPOINT  = UTF8_INVALID_CODEPOINT,

    iterateUTF8CodePoints   = iterateUTF8CodePoints,
    iterateUTF8EncodedBytes = iterateUTF8EncodedBytes,
}