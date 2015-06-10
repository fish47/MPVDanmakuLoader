
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
    local _META_AND_VALUE_TABLE     = { [0] = {}, [1] = {} }
    _META_AND_VALUE_TABLE[0][0]     = 0
    _META_AND_VALUE_TABLE[0][1]     = 0
    _META_AND_VALUE_TABLE[1][0]     = 0
    _META_AND_VALUE_TABLE[1][1]     = 1

    local _META_OR_VALUE_TABLE      = { [0] = {}, [1] = {} }
    _META_OR_VALUE_TABLE[0][0]      = 0
    _META_OR_VALUE_TABLE[0][1]      = 1
    _META_OR_VALUE_TABLE[1][0]      = 1
    _META_OR_VALUE_TABLE[1][1]      = 1

    local _META_XOR_VALUE_TABLE     = { [0] = {}, [1] = {} }
    _META_XOR_VALUE_TABLE[0][0]     = 0
    _META_XOR_VALUE_TABLE[0][1]     = 1
    _META_XOR_VALUE_TABLE[1][0]     = 1
    _META_XOR_VALUE_TABLE[1][1]     = 0

    --
    local _META_NOT_VALUE_TABLE     = { [0] = {}, [1] = {} }
    _META_NOT_VALUE_TABLE[0][0]     = 1
    _META_NOT_VALUE_TABLE[0][1]     = 1
    _META_NOT_VALUE_TABLE[1][0]     = 0
    _META_NOT_VALUE_TABLE[1][1]     = 0


    local function __doBitwiseOp(op1, op2, bandWidthPow, loopCount, valueTbl)
        local result = 0
        for i = 0, loopCount - 1
        do
            -- 截取低 sqrt(bandWidthPow) 个 bit
            local atom1 = op1 % bandWidthPow
            local atom2 = op2 % bandWidthPow

            -- 溢出右移，去掉已处理的位
            op1 = math.floor(op1 / bandWidthPow)
            op2 = math.floor(op2 / bandWidthPow)

            local val = valueTbl[atom1][atom2] * (bandWidthPow ^ i)
            result = result + math.floor(val)
        end

        return result
    end



    -- 缓存 4bit x 4bit 的位运算结果
    local _AND_VALUE_TABLE      = {}
    local _OR_VALUE_TABLE       = {}
    local _XOR_VALUE_TABLE      = {}
    local _NOT_VALUE_TABLE      = {}

    local _BITWISE_LIB_BIT_COUNT        = 32
    local _BITWISE_LIB_MASK             = 0xffffffff

    local _META_VALUE_TABLE_BIT_COUNT   = 1
    local _CACHE_VALUE_TABLE_BIT_COUNT  = 4
    local _CACHE_VALUE_TABLE_MIN_INDEX  = 0
    local _CACHE_VALUE_TABLE_MAX_INDEX  = math.floor(2 ^ _CACHE_VALUE_TABLE_BIT_COUNT - 1)

    for op1 = _CACHE_VALUE_TABLE_MIN_INDEX, _CACHE_VALUE_TABLE_MAX_INDEX
    do
        _AND_VALUE_TABLE[op1] = {}
        _OR_VALUE_TABLE[op1] = {}
        _XOR_VALUE_TABLE[op1] = {}
        _NOT_VALUE_TABLE[op1] = {}

        -- 因为真值表只定义了 1bit x 1bit 的结果
        local bandWidthPow = 2 ^ _META_VALUE_TABLE_BIT_COUNT

        -- 因为期望的输出结果是 4bit
        local loop = _CACHE_VALUE_TABLE_BIT_COUNT / _META_VALUE_TABLE_BIT_COUNT

        for op2 = _CACHE_VALUE_TABLE_MIN_INDEX, _CACHE_VALUE_TABLE_MAX_INDEX
        do
            _AND_VALUE_TABLE[op1][op2] = __doBitwiseOp(op1, op2, bandWidthPow, loop, _META_AND_VALUE_TABLE)
            _OR_VALUE_TABLE[op1][op2] = __doBitwiseOp(op1, op2, bandWidthPow, loop, _META_OR_VALUE_TABLE)
            _XOR_VALUE_TABLE[op1][op2] = __doBitwiseOp(op1, op2, bandWidthPow, loop, _META_XOR_VALUE_TABLE)
            _NOT_VALUE_TABLE[op1][op2] = __doBitwiseOp(op1, op2, bandWidthPow, loop, _META_NOT_VALUE_TABLE)
        end
    end


    -- 因为缓存了 4bit x 4bit 的结果，所以将 32bit 分成 8 次运算
    local _CACHE_LOOP_COUNT = _BITWISE_LIB_BIT_COUNT / _CACHE_VALUE_TABLE_BIT_COUNT
    local _CACHE_BANDWIDTH_POW = math.floor(2 ^ _CACHE_VALUE_TABLE_BIT_COUNT)

    local function __doBitwiseOpWithCacheTable(op1, op2, valTbl)
        return __doBitwiseOp(op1, op2, _CACHE_BANDWIDTH_POW, _CACHE_LOOP_COUNT, valTbl)
    end

    __band = function(op1, op2)
        return __doBitwiseOpWithCacheTable(op1, op2, _AND_VALUE_TABLE)
    end

    __bor = function(op1, op2)
        return __doBitwiseOpWithCacheTable(op1, op2, _OR_VALUE_TABLE)
    end

    __bxor = function(op1, op2)
        return __doBitwiseOpWithCacheTable(op1, op2, _XOR_VALUE_TABLE)
    end

    __bnot = function(op1)
        return __doBitwiseOpWithCacheTable(op1, 0, _NOT_VALUE_TABLE)
    end

    __lshift = function(op1, op2)
        if op2 >= _BITWISE_LIB_BIT_COUNT
        then
            return 0
        elseif op2 < 0
        then
            return __rshift(op1, -op2)
        else
            local result = op1 * (2 ^ op2)
            return __band(result, _BITWISE_LIB_MASK)
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
            local result = op1 / (2 ^ op2)
            return math.floor(result)
        end
    end

    __lrotate = function(op1, rotCount)
        --TODO
    end
end



local _M = {}
_M.__band = __band
_M.__bor = __bor
_M.__bxor = __bxor
_M.__bnot = __bnot
_M.__lshift = __lshift
_M.__rshift = __rshift
_M.__lrotate = __lrotate
return _M