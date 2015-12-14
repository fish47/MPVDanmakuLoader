local _bitlib   = require("src/base/_bitlib")


local _BYTE_BIT_COUNT   = 8
local _BYTE_MOD         = math.floor(2 ^ _BYTE_BIT_COUNT)

local _HEX_BIT_COUNT    = 4
local _HEX_MOD          = math.floor(2 ^ _HEX_BIT_COUNT)

local _INT32_BIT_COUNT  = 32
local _INT32_MASK       = math.floor(2 ^ 32 - 1)
local _INT32_MOD        = math.floor(2 ^ _INT32_BIT_COUNT)

local _INT32_HEX_COUNT  = math.floor(_INT32_BIT_COUNT / _HEX_BIT_COUNT)
local _INT32_BYTE_COUNT = math.floor(_INT32_BIT_COUNT / _BYTE_BIT_COUNT)

local _MD5_HASH_INIT_A  = 0x67452301
local _MD5_HASH_INIT_B  = 0xefcdab89
local _MD5_HASH_INIT_C  = 0x98badcfe
local _MD5_HASH_INIT_D  = 0x10325476

local STRING_EMPTY      = ""
local STRING_TABLE      = "table"

local _MD5_CHUNK_PADDING_BYTE_WITH_MSB          = string.char(128)
local _MD5_CHUNK_PADDING_ZERO                   = string.char(0)

local _MD5_CHUNK_BYTE_COUNT                     = 64
local _MD5_CHUNK_PADDING_RESERVED_BYTE_COUNT    = 8



local function __clearTable(tbl)
    if type(tbl) == STRING_TABLE
    then
        for k, _ in pairs(tbl)
        do
            tbl[k] = nil
        end
    end
    return tbl
end

local function __convertByteToLowerHex(num)
    return string.format("%02x", num)
end


local function __getChunkInt32At(chunk, leastByteIdx)
    -- 小端模式，高位高地址，低位低地址
    local ret = 0
    for i = _INT32_BYTE_COUNT, 1, -1
    do
        ret = ret * _BYTE_MOD
        ret = ret + chunk:byte(leastByteIdx + i)
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


local function __F(bitlibArg, x, y, z)
    local ret = bitlibArg.bxor(y, z)
    ret = bitlibArg.band(ret, x)
    ret = bitlibArg.bxor(ret, z)
    return ret
end

local function __G(bitlibArg, x, y, z)
    local ret = bitlibArg.bxor(x, y)
    ret = bitlibArg.band(ret, z)
    ret = bitlibArg.bxor(ret, y)
    return ret
end

local function __H(bitlibArg, x, y, z)
    local ret = bitlibArg.bxor(x, y)
    ret = bitlibArg.bxor(ret, z)
    return ret
end

local function __I(bitlibArg, x, y, z)
    local ret = bitlibArg.bnot(z)
    ret = bitlibArg.bor(ret, x)
    ret = bitlibArg.bxor(ret, y)
    return ret
end


local function __doTransform(bitlibArg, a, b, c, d, x, s, ac, f)
    local ret = f(bitlibArg, b, c, d)
    ret = bitlibArg.band(_INT32_MASK, a + ret)
    ret = bitlibArg.band(_INT32_MASK, ret + x)
    ret = bitlibArg.band(_INT32_MASK, ret + ac)
    ret = bitlibArg.lrotate(ret, s)
    ret = bitlibArg.band(_INT32_MASK, ret + b)
    return ret
end

local function __FF(bitlibArg, a, b, c, d, x, s, ac)
    return __doTransform(bitlibArg, a, b, c, d, x, s, ac, __F)
end

local function __GG(bitlibArg, a, b, c, d, x, s, ac)
    return __doTransform(bitlibArg, a, b, c, d, x, s, ac, __G)
end

local function __HH(bitlibArg, a, b, c, d, x, s, ac)
    return __doTransform(bitlibArg, a, b, c, d, x, s, ac, __H)
end

local function __II(bitlibArg, a, b, c, d, x, s, ac)
    return __doTransform(bitlibArg, a, b, c, d, x, s, ac, __I)
end


-- http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/libkern/crypto/md5.c
local function __doDigestChunk(bitlibArg, a, b, c, d, byteOffset, chunk)
    local bakA = a
    local bakB = b
    local bakC = c
    local bakD = d

    local x0  = __getChunkInt32At(chunk, byteOffset + 0)
    local x1  = __getChunkInt32At(chunk, byteOffset + 4)
    local x2  = __getChunkInt32At(chunk, byteOffset + 8)
    local x3  = __getChunkInt32At(chunk, byteOffset + 12)
    local x4  = __getChunkInt32At(chunk, byteOffset + 16)
    local x5  = __getChunkInt32At(chunk, byteOffset + 20)
    local x6  = __getChunkInt32At(chunk, byteOffset + 24)
    local x7  = __getChunkInt32At(chunk, byteOffset + 28)
    local x8  = __getChunkInt32At(chunk, byteOffset + 32)
    local x9  = __getChunkInt32At(chunk, byteOffset + 36)
    local x10 = __getChunkInt32At(chunk, byteOffset + 40)
    local x11 = __getChunkInt32At(chunk, byteOffset + 44)
    local x12 = __getChunkInt32At(chunk, byteOffset + 48)
    local x13 = __getChunkInt32At(chunk, byteOffset + 52)
    local x14 = __getChunkInt32At(chunk, byteOffset + 56)
    local x15 = __getChunkInt32At(chunk, byteOffset + 60)

    local S11 = 7
    local S12 = 12
    local S13 = 17
    local S14 = 22
    a = __FF(bitlibArg, a, b, c, d, x0,  S11, 0xd76aa478)
    d = __FF(bitlibArg, d, a, b, c, x1,  S12, 0xe8c7b756)
    c = __FF(bitlibArg, c, d, a, b, x2,  S13, 0x242070db)
    b = __FF(bitlibArg, b, c, d, a, x3,  S14, 0xc1bdceee)
    a = __FF(bitlibArg, a, b, c, d, x4,  S11, 0xf57c0faf)
    d = __FF(bitlibArg, d, a, b, c, x5,  S12, 0x4787c62a)
    c = __FF(bitlibArg, c, d, a, b, x6,  S13, 0xa8304613)
    b = __FF(bitlibArg, b, c, d, a, x7,  S14, 0xfd469501)
    a = __FF(bitlibArg, a, b, c, d, x8,  S11, 0x698098d8)
    d = __FF(bitlibArg, d, a, b, c, x9,  S12, 0x8b44f7af)
    c = __FF(bitlibArg, c, d, a, b, x10, S13, 0xffff5bb1)
    b = __FF(bitlibArg, b, c, d, a, x11, S14, 0x895cd7be)
    a = __FF(bitlibArg, a, b, c, d, x12, S11, 0x6b901122)
    d = __FF(bitlibArg, d, a, b, c, x13, S12, 0xfd987193)
    c = __FF(bitlibArg, c, d, a, b, x14, S13, 0xa679438e)
    b = __FF(bitlibArg, b, c, d, a, x15, S14, 0x49b40821)

    local S21 = 5
    local S22 = 9
    local S23 = 14
    local S24 = 20
    a = __GG(bitlibArg, a, b, c, d, x1,  S21, 0xf61e2562)
    d = __GG(bitlibArg, d, a, b, c, x6,  S22, 0xc040b340)
    c = __GG(bitlibArg, c, d, a, b, x11, S23, 0x265e5a51)
    b = __GG(bitlibArg, b, c, d, a, x0,  S24, 0xe9b6c7aa)
    a = __GG(bitlibArg, a, b, c, d, x5,  S21, 0xd62f105d)
    d = __GG(bitlibArg, d, a, b, c, x10, S22, 0x02441453)
    c = __GG(bitlibArg, c, d, a, b, x15, S23, 0xd8a1e681)
    b = __GG(bitlibArg, b, c, d, a, x4,  S24, 0xe7d3fbc8)
    a = __GG(bitlibArg, a, b, c, d, x9,  S21, 0x21e1cde6)
    d = __GG(bitlibArg, d, a, b, c, x14, S22, 0xc33707d6)
    c = __GG(bitlibArg, c, d, a, b, x3,  S23, 0xf4d50d87)
    b = __GG(bitlibArg, b, c, d, a, x8,  S24, 0x455a14ed)
    a = __GG(bitlibArg, a, b, c, d, x13, S21, 0xa9e3e905)
    d = __GG(bitlibArg, d, a, b, c, x2,  S22, 0xfcefa3f8)
    c = __GG(bitlibArg, c, d, a, b, x7,  S23, 0x676f02d9)
    b = __GG(bitlibArg, b, c, d, a, x12, S24, 0x8d2a4c8a)

    local S31 = 4
    local S32 = 11
    local S33 = 16
    local S34 = 23
    a = __HH(bitlibArg, a, b, c, d, x5,  S31, 0xfffa3942)
    d = __HH(bitlibArg, d, a, b, c, x8,  S32, 0x8771f681)
    c = __HH(bitlibArg, c, d, a, b, x11, S33, 0x6d9d6122)
    b = __HH(bitlibArg, b, c, d, a, x14, S34, 0xfde5380c)
    a = __HH(bitlibArg, a, b, c, d, x1,  S31, 0xa4beea44)
    d = __HH(bitlibArg, d, a, b, c, x4,  S32, 0x4bdecfa9)
    c = __HH(bitlibArg, c, d, a, b, x7,  S33, 0xf6bb4b60)
    b = __HH(bitlibArg, b, c, d, a, x10, S34, 0xbebfbc70)
    a = __HH(bitlibArg, a, b, c, d, x13, S31, 0x289b7ec6)
    d = __HH(bitlibArg, d, a, b, c, x0,  S32, 0xeaa127fa)
    c = __HH(bitlibArg, c, d, a, b, x3,  S33, 0xd4ef3085)
    b = __HH(bitlibArg, b, c, d, a, x6,  S34, 0x04881d05)
    a = __HH(bitlibArg, a, b, c, d, x9,  S31, 0xd9d4d039)
    d = __HH(bitlibArg, d, a, b, c, x12, S32, 0xe6db99e5)
    c = __HH(bitlibArg, c, d, a, b, x15, S33, 0x1fa27cf8)
    b = __HH(bitlibArg, b, c, d, a, x2,  S34, 0xc4ac5665)


    local S41 = 6
    local S42 = 10
    local S43 = 15
    local S44 = 21
    a = __II(bitlibArg, a, b, c, d, x0,  S41, 0xf4292244)
    d = __II(bitlibArg, d, a, b, c, x7,  S42, 0x432aff97)
    c = __II(bitlibArg, c, d, a, b, x14, S43, 0xab9423a7)
    b = __II(bitlibArg, b, c, d, a, x5,  S44, 0xfc93a039)
    a = __II(bitlibArg, a, b, c, d, x12, S41, 0x655b59c3)
    d = __II(bitlibArg, d, a, b, c, x3,  S42, 0x8f0ccc92)
    c = __II(bitlibArg, c, d, a, b, x10, S43, 0xffeff47d)
    b = __II(bitlibArg, b, c, d, a, x1,  S44, 0x85845dd1)
    a = __II(bitlibArg, a, b, c, d, x8,  S41, 0x6fa87e4f)
    d = __II(bitlibArg, d, a, b, c, x15, S42, 0xfe2ce6e0)
    c = __II(bitlibArg, c, d, a, b, x6,  S43, 0xa3014314)
    b = __II(bitlibArg, b, c, d, a, x13, S44, 0x4e0811a1)
    a = __II(bitlibArg, a, b, c, d, x4,  S41, 0xf7537e82)
    d = __II(bitlibArg, d, a, b, c, x11, S42, 0xbd3af235)
    c = __II(bitlibArg, c, d, a, b, x2,  S43, 0x2ad7d2bb)
    b = __II(bitlibArg, b, c, d, a, x9,  S44, 0xeb86d391)


    a = bitlibArg.band(_INT32_MASK, a + bakA)
    b = bitlibArg.band(_INT32_MASK, b + bakB)
    c = bitlibArg.band(_INT32_MASK, c + bakC)
    d = bitlibArg.band(_INT32_MASK, d + bakD)

    return a, b, c, d
end



local function __doDigestLastChunkAndPaddings(bitlibArg,
                                              a, b, c, d,
                                              lastChunk,
                                              readByteCount,
                                              buf)
    -- 先填充 0x80 ，注意有可能刚好令最后一个分块成为 512 bit
    if #lastChunk == _MD5_CHUNK_BYTE_COUNT - 1
    then
        local chunk = lastChunk .. _MD5_CHUNK_PADDING_BYTE_WITH_MSB
        a, b, c, d = __doDigestChunk(bitlibArg, a, b, c, d, 0, chunk)

        chunk = nil
        lastChunk = STRING_EMPTY
    else
        lastChunk = lastChunk .. _MD5_CHUNK_PADDING_BYTE_WITH_MSB
    end


    -- 剩余不足 64 bit 的，先补零字结束当前分块，再开一个分块
    local remainingByteCount = _MD5_CHUNK_BYTE_COUNT - #lastChunk
    if remainingByteCount < _MD5_CHUNK_PADDING_RESERVED_BYTE_COUNT
    then
        local trailing = string.rep(_MD5_CHUNK_PADDING_ZERO, remainingByteCount)
        local chunk = lastChunk .. trailing
        a, b, c, d = __doDigestChunk(bitlibArg, a, b, c, d, 0, chunk)

        chunk = nil
        lastChunk = STRING_EMPTY
        remainingByteCount = _MD5_CHUNK_BYTE_COUNT
    end


    -- 补充足够多的零字节，使得刚好剩下 64 bit
    local zeroByteCount = remainingByteCount - _MD5_CHUNK_PADDING_RESERVED_BYTE_COUNT
    if zeroByteCount > 0
    then
        lastChunk = lastChunk .. string.rep(_MD5_CHUNK_PADDING_ZERO, zeroByteCount)
    end

    -- 再填位长度余数
    buf = __clearTable(buf or {})
    table.insert(buf, lastChunk)

    local totalBitCount = readByteCount * _BYTE_BIT_COUNT
    __getInt32Bytes(totalBitCount % _INT32_MOD, buf, string.char)
    __getInt32Bytes(math.floor(totalBitCount / _INT32_MOD), buf, string.char)


    a, b, c, d = __doDigestChunk(bitlibArg, a, b, c, d, 0, table.concat(buf))
    buf = nil

    return a, b, c, d
end


local function calcMD5Hash(chunks, bitlibArg)
    local a = _MD5_HASH_INIT_A
    local b = _MD5_HASH_INIT_B
    local c = _MD5_HASH_INIT_C
    local d = _MD5_HASH_INIT_D
    local readByteCount = 0
    local buf = {}
    local byteOffset = 0
    local byteCount = #chunks
    bitlibArg = bitlibArg or _bitlib

    while true
    do
        local remainingByteCount = byteCount - byteOffset
        local chunkSize = math.min(remainingByteCount, _MD5_CHUNK_BYTE_COUNT)
        readByteCount = readByteCount + chunkSize

        -- 最后一个分块少于 512 bit
        if chunkSize < _MD5_CHUNK_BYTE_COUNT
        then
            -- 有可能数据长度总和刚好是 512 bit 的整数倍
            local lastChunk = nil
            if remainingByteCount == 0
            then
                lastChunk = STRING_EMPTY
            else
                lastChunk = chunks:sub(byteOffset + 1)
            end

            a, b, c, d= __doDigestLastChunkAndPaddings(bitlibArg,
                                                       a, b, c, d,
                                                       lastChunk,
                                                       readByteCount,
                                                       buf)
            break
        end

        -- 不是最后的数据块
        a, b, c, d = __doDigestChunk(bitlibArg, a, b, c, d, byteOffset, chunks)
        byteOffset = byteOffset + _MD5_CHUNK_BYTE_COUNT
    end


    __clearTable(buf)
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
    calcMD5Hash             = calcMD5Hash,
}