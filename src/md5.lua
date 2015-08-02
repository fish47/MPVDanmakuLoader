local utils = require('src/utils')      --= utils utils

local __band        = nil
local __bor         = nil
local __bxor        = nil
local __bnot        = nil
local __lshift      = nil
local __rshift      = nil
local __lrotate     = nil

if bit32 and not _USE_SOFT_BITWISE_LIB
then
    __band = bit32.band
    __bor = bit32.bor
    __bxor = bit32.bxor
    __bnot = bit32.bnot
    __lshift = bit32.lshift
    __rshift = bit32.rshift
    __lrotate = bit32.lrotate
else
    -- 注意，这里的位操作函数不能处理 负数 / 大于 32bit 的数 / 小数

    local _META_VALUE_TABLE_BIT_COUNT       = 1
    local _META_VALUE_TABLE_BANDWIDTH_POW   = math.floor(2 ^ _META_VALUE_TABLE_BIT_COUNT)
    local _META_CACHED_VALUE_TABLE_AND =
    {
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 0,    -- 0 and 0 = 0
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 0,    -- 0 and 1 = 0
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 0,    -- 1 and 1 = 0
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 1,    -- 1 and 1 = 1
    }

    local _META_CACHED_VALUE_TABLE_OR  =
    {
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 0,    -- 0 or 0 = 0
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 1,    -- 0 or 1 = 1
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 1,    -- 0 or 1 = 1
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 1,    -- 0 or 1 = 1
    }

    local _META_CACHED_VALUE_TABLE_XOR =
    {
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 0,    -- 0 xor 0 = 0
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 1,    -- 0 xor 1 = 1
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 1,    -- 1 xor 0 = 1
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 0,    -- 1 xor 1 = 0
    }

    -- 虽然取反符是单操作符，但直值表的第二个操作数定义为掩码
    -- 例如缓存 5bit 必须做 7 轮运算，在最后一轮运算，必须防止填充多余的高位 1
    -- 对于其他操作数来说，总体有 0 op 0 = 0 ，所以保证输入数值合法，就不会出现多余的位结果
    local _META_CACHED_VALUE_TABLE_NOT =
    {
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 0,    -- ignored
        [0 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 1,    -- not 0 = 1
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 0]   = 1,    -- not 1 = 0
        [1 * _META_VALUE_TABLE_BANDWIDTH_POW + 1]   = 0,    -- ignored
    }


    local function __doBitwiseOp(op1, op2, bandWidthPow, loopCount, valueTbl)
        local result = 0
        local shiftPow = 1
        for i = 0, loopCount - 1
        do
            -- 截取低 sqrt(bandWidthPow) 个 bit
            local atom1 = op1 % bandWidthPow
            local atom2 = op2 % bandWidthPow

            -- 溢出右移，去掉已处理的位
            op1 = math.floor(op1 / bandWidthPow)
            op2 = math.floor(op2 / bandWidthPow)

            -- 计算 atom1 op atom2 的值，结果为 sqrt(bandWidthPow) 个 bit
            local val = valueTbl[atom1 * bandWidthPow + atom2]

            -- 将结果偏移到对应位，以 4bit 位宽为例，第 i 轮计算结果是 [ 4 * (i + 1) : 4 * i ] 位
            val = val * shiftPow
            shiftPow = shiftPow * bandWidthPow

            result = result + val
        end

        return result
    end


    local _BITWISE_LIB_BIT_COUNT                = 32
    local _BITWISE_LIB_MASK                     = 0xffffffff
    local _BITWISE_LIB_MOD                      = _BITWISE_LIB_MASK + 1

    local _BITWISE_LIB_POW_LIST                 = {}
    for i = 0, _BITWISE_LIB_BIT_COUNT
    do
        _BITWISE_LIB_POW_LIST[i] = math.floor(2 ^ i)
    end

    -- 缓存 4bit ~ 8bit 效果是很明显的，再向上就变慢了
    local _CACHED_VALUE_TABLE_BIT_COUNT         = 7
    local _CACHED_VALUE_TABLE_BANDWIDTH_POW     = math.floor(2 ^ _CACHED_VALUE_TABLE_BIT_COUNT)
    local _CACHED_VALUE_TABLE_MIN_OP            = 0
    local _CACHED_VALUE_TABLE_MAX_OP            = math.floor(2 ^ _CACHED_VALUE_TABLE_BIT_COUNT - 1)

    -- 例如缓存了 4bit x 4bit 的结果，所以将 32bit 分成 8 轮运算
    local _CACHED_VALUE_TABLE_LOOP_COUNT        = math.ceil(_BITWISE_LIB_BIT_COUNT / _CACHED_VALUE_TABLE_BIT_COUNT)


    -- 缓存的位运算结果
    local _CACHED_VALUE_TABLE_AND   = {}
    local _CACHED_VALUE_TABLE_OR    = {}
    local _CACHED_VALUE_TABLE_XOR   = {}
    local _CACHED_VALUE_TABLE_NOT   = {}

    for op1 = _CACHED_VALUE_TABLE_MIN_OP, _CACHED_VALUE_TABLE_MAX_OP
    do
        for op2 = _CACHED_VALUE_TABLE_MIN_OP, _CACHED_VALUE_TABLE_MAX_OP
        do
            local idx = op1 * _CACHED_VALUE_TABLE_BANDWIDTH_POW + op2
            local loopCount = _CACHED_VALUE_TABLE_BIT_COUNT / _META_VALUE_TABLE_BIT_COUNT

            _CACHED_VALUE_TABLE_AND[idx] = __doBitwiseOp(op1, op2,
                                                         _META_VALUE_TABLE_BANDWIDTH_POW,
                                                         loopCount,
                                                         _META_CACHED_VALUE_TABLE_AND)

            _CACHED_VALUE_TABLE_OR[idx] = __doBitwiseOp(op1, op2,
                                                        _META_VALUE_TABLE_BANDWIDTH_POW,
                                                        loopCount,
                                                        _META_CACHED_VALUE_TABLE_OR)

            _CACHED_VALUE_TABLE_XOR[idx] = __doBitwiseOp(op1, op2,
                                                         _META_VALUE_TABLE_BANDWIDTH_POW,
                                                         loopCount,
                                                         _META_CACHED_VALUE_TABLE_XOR)

            _CACHED_VALUE_TABLE_NOT[idx] = __doBitwiseOp(op1, op2,
                                                         _META_VALUE_TABLE_BANDWIDTH_POW,
                                                         loopCount,
                                                         _META_CACHED_VALUE_TABLE_NOT)
        end
    end

    __band = function(op1, op2)
        return __doBitwiseOp(op1, op2,
                             _CACHED_VALUE_TABLE_BANDWIDTH_POW,
                             _CACHED_VALUE_TABLE_LOOP_COUNT,
                             _CACHED_VALUE_TABLE_AND)
    end

    __bor = function(op1, op2)
        return __doBitwiseOp(op1, op2,
                             _CACHED_VALUE_TABLE_BANDWIDTH_POW,
                             _CACHED_VALUE_TABLE_LOOP_COUNT,
                             _CACHED_VALUE_TABLE_OR)
    end

    __bxor = function(op1, op2)
        return __doBitwiseOp(op1, op2,
                             _CACHED_VALUE_TABLE_BANDWIDTH_POW,
                             _CACHED_VALUE_TABLE_LOOP_COUNT,
                             _CACHED_VALUE_TABLE_XOR)
    end

    __bnot = function(op1)
        local res = __doBitwiseOp(op1, _BITWISE_LIB_MASK,
                                  _CACHED_VALUE_TABLE_BANDWIDTH_POW,
                                  _CACHED_VALUE_TABLE_LOOP_COUNT,
                                  _CACHED_VALUE_TABLE_NOT)

        return res
    end

    __lshift = function(op1, op2)
        if op2 >= _BITWISE_LIB_BIT_COUNT
        then
            return 0
        elseif op2 < 0
        then
            return __rshift(op1, -op2)
        else
            local result = op1 * _BITWISE_LIB_POW_LIST[op2]
            return result % _BITWISE_LIB_MOD
        end
    end

    __rshift = function(op1, op2)
        if op2 >= _BITWISE_LIB_BIT_COUNT
        then
            return 0
        elseif op2 < 0
        then
            return __lshift(op1, -op2)
        else
            local result = op1 / _BITWISE_LIB_POW_LIST[op2]
            return math.floor(result)
        end
    end

    __lrotate = function(op1, rotCount)
        -- 保证 rotCount 是正数
        rotCount = rotCount % _BITWISE_LIB_BIT_COUNT
        rotCount = (rotCount < 0) and (rotCount + _BITWISE_LIB_BIT_COUNT) or (rotCount)
        local shiftedPart = __lshift(op1, rotCount)
        local rotatedPart = __rshift(op1, _BITWISE_LIB_BIT_COUNT - rotCount)
        return shiftedPart + rotatedPart
    end
end



local _BYTE_BIT_COUNT   = 8
local _BYTE_MOD         = math.floor(2 ^ _BYTE_BIT_COUNT)

local _HEX_BIT_COUNT    = 4
local _HEX_MOD          = math.floor(2 ^ _HEX_BIT_COUNT)

local _INT32_BIT_COUNT  = 32
local _INT32_MOD        = math.floor(2 ^ _INT32_BIT_COUNT)

local _INT32_HEX_COUNT  = math.floor(_INT32_BIT_COUNT / _HEX_BIT_COUNT)
local _INT32_BYTE_COUNT = math.floor(_INT32_BIT_COUNT / _BYTE_BIT_COUNT)

local _MD5_CHUNK_PADDING_BYTE_WITH_MSB  = string.char(128)
local _MD5_CHUNK_PADDING_ZERO           = string.char(0)

local MD5_CHUNK_BYTE_COUNT                     = 64
local _MD5_CHUNK_PADDING_RESERVED_BYTE_COUNT    = 8


local _MD5_HASH_INIT_A  = 0x67452301
local _MD5_HASH_INIT_B  = 0xefcdab89
local _MD5_HASH_INIT_C  = 0x98badcfe
local _MD5_HASH_INIT_D  = 0x10325476


local function __convertByteToLowerHex(num)
    return string.format("%02x", num)
end


local function __getChunkInt32At(chunk, int32Idx)
    -- 注意索引是 0-based
    local baseIdx = int32Idx * _INT32_BYTE_COUNT

    -- 小端模式，高位高地址，低位低地址
    local ret = 0
    for i = _INT32_BYTE_COUNT, 1, -1
    do
        ret = ret * _BYTE_MOD
        ret = ret + chunk:byte(baseIdx + i)
    end

    return ret
end


local function __getInt32Bytes(num, outBuf, hookFunc)
    for i = 1, _INT32_BYTE_COUNT
    do
        local val = num % _BYTE_MOD
        val = hookFunc and hookFunc(val)
        table.insert(outBuf, val)
        num = math.floor(num / _BYTE_MOD)
    end
end




local _BIT_MOD              = 2
local _INT31_MOD            = math.floor(2 ^ 31)
local _INT32_MSB_OFFSET     = 31

local function __sumInt32Safelly(a, b)
    a = a % _INT32_MOD
    b = b % _INT32_MOD

    -- 先将低 31bit 相加，结果肯定不会超出 32bit 的
    local lowerBits1 = a % _INT31_MOD
    local lowerBits2 = b % _INT31_MOD
    local sum1 = lowerBits1 + lowerBits2

    -- 注意第 32 位可能包含进位
    local msb1 = __rshift(a, _INT32_MSB_OFFSET)
    local msb2 = __rshift(b, _INT32_MSB_OFFSET)
    local msb3 = __rshift(sum1, _INT32_MSB_OFFSET)
    local msb = (msb1 + msb2 + msb3) % _BIT_MOD

    sum1 = sum1 % _INT31_MOD
    local ret = sum1 + __lshift(msb, _INT32_MSB_OFFSET)

    return ret
end


local function __F(x, y, z)
    local ret = __bxor(y, z)
    ret = __band(ret, x)
    ret = __bxor(ret, z)
    return ret
end

local function __G(x, y, z)
    local ret = __bxor(x, y)
    ret = __band(ret, z)
    ret = __bxor(ret, y)
    return ret
end

local function __H(x, y, z)
    local ret = __bxor(x, y)
    ret = __bxor(ret, z)
    return ret
end

local function __I(x, y, z)
    local ret = __bnot(z)
    ret = __bor(ret, x)
    ret = __bxor(ret, y)
    return ret
end


local function __doTransform(a, b, c, d, x, s, ac, f)
    local ret = __sumInt32Safelly(a, f(b, c, d))
    ret = __sumInt32Safelly(ret, x)
    ret = __sumInt32Safelly(ret, ac)
    ret = __lrotate(ret, s)
    ret = __sumInt32Safelly(ret, b)

    return ret
end

local function __FF(a, b, c, d, x, s, ac)
    return __doTransform(a, b, c, d, x, s, ac, __F)
end

local function __GG(a, b, c, d, x, s, ac)
    return __doTransform(a, b, c, d, x, s, ac, __G)
end

local function __HH(a, b, c, d, x, s, ac)
    return __doTransform(a, b, c, d, x, s, ac, __H)
end

local function __II(a, b, c, d, x, s, ac)
    return __doTransform(a, b, c, d, x, s, ac, __I)
end


-- http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/libkern/crypto/md5.c
local function __doDigestChunk(a, b, c, d, chunk)
    local bakA = a
    local bakB = b
    local bakC = c
    local bakD = d

    local x0  = __getChunkInt32At(chunk, 0)
    local x1  = __getChunkInt32At(chunk, 1)
    local x2  = __getChunkInt32At(chunk, 2)
    local x3  = __getChunkInt32At(chunk, 3)
    local x4  = __getChunkInt32At(chunk, 4)
    local x5  = __getChunkInt32At(chunk, 5)
    local x6  = __getChunkInt32At(chunk, 6)
    local x7  = __getChunkInt32At(chunk, 7)
    local x8  = __getChunkInt32At(chunk, 8)
    local x9  = __getChunkInt32At(chunk, 9)
    local x10 = __getChunkInt32At(chunk, 10)
    local x11 = __getChunkInt32At(chunk, 11)
    local x12 = __getChunkInt32At(chunk, 12)
    local x13 = __getChunkInt32At(chunk, 13)
    local x14 = __getChunkInt32At(chunk, 14)
    local x15 = __getChunkInt32At(chunk, 15)

    local S11 = 7
    local S12 = 12
    local S13 = 17
    local S14 = 22
    a = __FF(a, b, c, d, x0,  S11, 0xd76aa478)
    d = __FF(d, a, b, c, x1,  S12, 0xe8c7b756)
    c = __FF(c, d, a, b, x2,  S13, 0x242070db)
    b = __FF(b, c, d, a, x3,  S14, 0xc1bdceee)
    a = __FF(a, b, c, d, x4,  S11, 0xf57c0faf)
    d = __FF(d, a, b, c, x5,  S12, 0x4787c62a)
    c = __FF(c, d, a, b, x6,  S13, 0xa8304613)
    b = __FF(b, c, d, a, x7,  S14, 0xfd469501)
    a = __FF(a, b, c, d, x8,  S11, 0x698098d8)
    d = __FF(d, a, b, c, x9,  S12, 0x8b44f7af)
    c = __FF(c, d, a, b, x10, S13, 0xffff5bb1)
    b = __FF(b, c, d, a, x11, S14, 0x895cd7be)
    a = __FF(a, b, c, d, x12, S11, 0x6b901122)
    d = __FF(d, a, b, c, x13, S12, 0xfd987193)
    c = __FF(c, d, a, b, x14, S13, 0xa679438e)
    b = __FF(b, c, d, a, x15, S14, 0x49b40821)

    local S21 = 5
    local S22 = 9
    local S23 = 14
    local S24 = 20
    a = __GG(a, b, c, d, x1,  S21, 0xf61e2562)
    d = __GG(d, a, b, c, x6,  S22, 0xc040b340)
    c = __GG(c, d, a, b, x11, S23, 0x265e5a51)
    b = __GG(b, c, d, a, x0,  S24, 0xe9b6c7aa)
    a = __GG(a, b, c, d, x5,  S21, 0xd62f105d)
    d = __GG(d, a, b, c, x10, S22, 0x02441453)
    c = __GG(c, d, a, b, x15, S23, 0xd8a1e681)
    b = __GG(b, c, d, a, x4,  S24, 0xe7d3fbc8)
    a = __GG(a, b, c, d, x9,  S21, 0x21e1cde6)
    d = __GG(d, a, b, c, x14, S22, 0xc33707d6)
    c = __GG(c, d, a, b, x3,  S23, 0xf4d50d87)
    b = __GG(b, c, d, a, x8,  S24, 0x455a14ed)
    a = __GG(a, b, c, d, x13, S21, 0xa9e3e905)
    d = __GG(d, a, b, c, x2,  S22, 0xfcefa3f8)
    c = __GG(c, d, a, b, x7,  S23, 0x676f02d9)
    b = __GG(b, c, d, a, x12, S24, 0x8d2a4c8a)

    local S31 = 4
    local S32 = 11
    local S33 = 16
    local S34 = 23
    a = __HH(a, b, c, d, x5,  S31, 0xfffa3942)
    d = __HH(d, a, b, c, x8,  S32, 0x8771f681)
    c = __HH(c, d, a, b, x11, S33, 0x6d9d6122)
    b = __HH(b, c, d, a, x14, S34, 0xfde5380c)
    a = __HH(a, b, c, d, x1,  S31, 0xa4beea44)
    d = __HH(d, a, b, c, x4,  S32, 0x4bdecfa9)
    c = __HH(c, d, a, b, x7,  S33, 0xf6bb4b60)
    b = __HH(b, c, d, a, x10, S34, 0xbebfbc70)
    a = __HH(a, b, c, d, x13, S31, 0x289b7ec6)
    d = __HH(d, a, b, c, x0,  S32, 0xeaa127fa)
    c = __HH(c, d, a, b, x3,  S33, 0xd4ef3085)
    b = __HH(b, c, d, a, x6,  S34, 0x04881d05)
    a = __HH(a, b, c, d, x9,  S31, 0xd9d4d039)
    d = __HH(d, a, b, c, x12, S32, 0xe6db99e5)
    c = __HH(c, d, a, b, x15, S33, 0x1fa27cf8)
    b = __HH(b, c, d, a, x2,  S34, 0xc4ac5665)


    local S41 = 6
    local S42 = 10
    local S43 = 15
    local S44 = 21
    a = __II(a, b, c, d, x0,  S41, 0xf4292244)
    d = __II(d, a, b, c, x7,  S42, 0x432aff97)
    c = __II(c, d, a, b, x14, S43, 0xab9423a7)
    b = __II(b, c, d, a, x5,  S44, 0xfc93a039)
    a = __II(a, b, c, d, x12, S41, 0x655b59c3)
    d = __II(d, a, b, c, x3,  S42, 0x8f0ccc92)
    c = __II(c, d, a, b, x10, S43, 0xffeff47d)
    b = __II(b, c, d, a, x1,  S44, 0x85845dd1)
    a = __II(a, b, c, d, x8,  S41, 0x6fa87e4f)
    d = __II(d, a, b, c, x15, S42, 0xfe2ce6e0)
    c = __II(c, d, a, b, x6,  S43, 0xa3014314)
    b = __II(b, c, d, a, x13, S44, 0x4e0811a1)
    a = __II(a, b, c, d, x4,  S41, 0xf7537e82)
    d = __II(d, a, b, c, x11, S42, 0xbd3af235)
    c = __II(c, d, a, b, x2,  S43, 0x2ad7d2bb)
    b = __II(b, c, d, a, x9,  S44, 0xeb86d391)


    a = __sumInt32Safelly(a, bakA)
    b = __sumInt32Safelly(b, bakB)
    c = __sumInt32Safelly(c, bakC)
    d = __sumInt32Safelly(d, bakD)

    return a, b, c, d
end



local function __doDigestLastChunkAndPaddings(a, b, c, d,
                                              lastChunk,
                                              readByteCount,
                                              buf)
    -- 先填充 0x80 ，注意有可能刚好令最后一个分块成为 512 bit
    if #lastChunk == MD5_CHUNK_BYTE_COUNT - 1
    then
        local chunk = lastChunk .. _MD5_CHUNK_PADDING_BYTE_WITH_MSB
        a, b, c, d = __doDigestChunk(a, b, c, d, chunk)

        chunk = nil
        lastChunk = ""
    else
        lastChunk = lastChunk .. _MD5_CHUNK_PADDING_BYTE_WITH_MSB
    end


    -- 剩余不足 64 bit 的，先补零字结束当前分块，再开一个分块
    local remainingByteCount = MD5_CHUNK_BYTE_COUNT - #lastChunk
    if remainingByteCount < _MD5_CHUNK_PADDING_RESERVED_BYTE_COUNT
    then
        local chunk = lastChunk .. string.rep(_MD5_CHUNK_PADDING_ZERO, remainingByteCount)
        a, b, c, d = __doDigestChunk(a, b, c, d, chunk)

        chunk = nil
        lastChunk = ""
        remainingByteCount = MD5_CHUNK_BYTE_COUNT
    end


    -- 补充足够多的零字节，使得刚好剩下 64 bit
    local zeroByteFillCount = remainingByteCount - _MD5_CHUNK_PADDING_RESERVED_BYTE_COUNT
    if zeroByteFillCount > 0
    then
        lastChunk = lastChunk .. string.rep(_MD5_CHUNK_PADDING_ZERO, zeroByteFillCount)
    end

    -- 再填位长度余数
    buf = utils.clearTable(buf or {})
    table.insert(buf, lastChunk)

    local totalBitCount = readByteCount * _BYTE_BIT_COUNT
    __getInt32Bytes(totalBitCount % _INT32_MOD, buf, string.char)
    __getInt32Bytes(math.floor(totalBitCount / _INT32_MOD), buf, string.char)


    a, b, c, d = __doDigestChunk(a, b, c, d, table.concat(buf))
    buf = nil

    return a, b, c, d
end


local function calcMD5HashSum(iterFunc, iterArg)
    local a = _MD5_HASH_INIT_A
    local b = _MD5_HASH_INIT_B
    local c = _MD5_HASH_INIT_C
    local d = _MD5_HASH_INIT_D
    local readByteCount = 0
    local buf = {}
    local chunkIdx = 1

    while true
    do
        local chunk = iterFunc(iterArg, chunkIdx)

        -- 所有数据长度总和刚好是 512 bit 的整数倍
        if not chunk
        then
            a, b, c, d = __doDigestLastChunkAndPaddings(a, b, c, d,
                                                        "", readByteCount, buf)
            break
        end


        local chunkSize = #chunk
        readByteCount = readByteCount + chunkSize
        chunkIdx = chunkIdx + 1

        -- 最后一个分块少于 512 bit
        if chunkSize < MD5_CHUNK_BYTE_COUNT
        then
            a, b, c, d= __doDigestLastChunkAndPaddings(a, b, c, d,
                                                       chunk, readByteCount, buf)
            break
        end

        -- 不是最后的数据块
        a, b, c, d = __doDigestChunk(a, b, c, d, chunk)
    end


    utils.clearTable(buf)
    __getInt32Bytes(a, buf, __convertByteToLowerHex)
    __getInt32Bytes(b, buf, __convertByteToLowerHex)
    __getInt32Bytes(c, buf, __convertByteToLowerHex)
    __getInt32Bytes(d, buf, __convertByteToLowerHex)

    local ret = table.concat(buf)
    buf = nil
    return ret
end



return
{
    -- 目前只用于单元测试
    __band      = __band,
    __bor       = __bor,
    __bxor      = __bxor,
    __bnot      = __bnot,
    __lshift    = __lshift,
    __rshift    = __rshift,
    __lrotate   = __lrotate,

    MD5_CHUNK_BYTE_COUNT    = MD5_CHUNK_BYTE_COUNT,

    calcMD5HashSum          = calcMD5HashSum,
}