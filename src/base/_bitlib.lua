local function __doCreateSoftImpl()
    -- 注意，这里的位操作函数不能处理 负数 / 大于 32bit 的数 / 小数

    local _META_VALUES_BIT_COUNT        = 1
    local _META_VALUES_STEP_MUL         = math.floor(2 ^ _META_VALUES_BIT_COUNT)
    local _META_CACHED_VALUES_AND       =
    {
        [0 * _META_VALUES_STEP_MUL + 0] = 0,    -- 0 and 0 = 0
        [0 * _META_VALUES_STEP_MUL + 1] = 0,    -- 0 and 1 = 0
        [1 * _META_VALUES_STEP_MUL + 0] = 0,    -- 1 and 1 = 0
        [1 * _META_VALUES_STEP_MUL + 1] = 1,    -- 1 and 1 = 1
    }

    local _META_CACHED_VALUES_OR        =
    {
        [0 * _META_VALUES_STEP_MUL + 0] = 0,    -- 0 or 0 = 0
        [0 * _META_VALUES_STEP_MUL + 1] = 1,    -- 0 or 1 = 1
        [1 * _META_VALUES_STEP_MUL + 0] = 1,    -- 0 or 1 = 1
        [1 * _META_VALUES_STEP_MUL + 1] = 1,    -- 0 or 1 = 1
    }

    local _META_CACHED_VALUES_XOR       =
    {
        [0 * _META_VALUES_STEP_MUL + 0] = 0,    -- 0 xor 0 = 0
        [0 * _META_VALUES_STEP_MUL + 1] = 1,    -- 0 xor 1 = 1
        [1 * _META_VALUES_STEP_MUL + 0] = 1,    -- 1 xor 0 = 1
        [1 * _META_VALUES_STEP_MUL + 1] = 0,    -- 1 xor 1 = 0
    }

    -- 虽然取反符是单操作符，但真值表的第二个操作数定义为掩码
    -- 例如缓存 5bit 必须做 7 轮运算，在最后一轮运算，必须防止填充多余的高位 1
    -- 对于其他操作数来说，总体有 0 op 0 = 0 ，所以保证输入数值合法，就不会出现多余的位结果
    local _META_CACHED_VALUES_NOT       =
    {
        [0 * _META_VALUES_STEP_MUL + 0] = 0,    -- ignored
        [0 * _META_VALUES_STEP_MUL + 1] = 1,    -- not 0 = 1
        [1 * _META_VALUES_STEP_MUL + 0] = 1,    -- not 1 = 0
        [1 * _META_VALUES_STEP_MUL + 1] = 0,    -- ignored
    }


    local function __doBitwiseOp(op1, op2, step, loopCount, values)
        local result = 0
        local shiftPow = 1
        for i = 0, loopCount - 1
        do
            -- 截取低 sqrt(step) 个 bit
            local atom1 = op1 % step
            local atom2 = op2 % step

            -- 溢出右移，去掉已处理的位
            op1 = math.floor(op1 / step)
            op2 = math.floor(op2 / step)

            -- 计算 atom1 op atom2 的值，结果为 sqrt(step) 个 bit
            local val = values[atom1 * step + atom2]

            -- 将结果偏移到对应位
            -- 以 4bit 位宽为例，第 i 轮计算结果是 [ 4 * (i + 1) : 4 * i ] 位
            val = val * shiftPow
            shiftPow = shiftPow * step

            result = result + val
        end

        return result
    end


    local _BITLIB_BIT_COUNT             = 32
    local _BITLIB_MASK                  = 0xffffffff
    local _BITLIB_MOD                   = _BITLIB_MASK + 1

    local _BITLIB_POW_LIST              = {}
    for i = 0, _BITLIB_BIT_COUNT
    do
        _BITLIB_POW_LIST[i] = math.floor(2 ^ i)
    end

    -- 缓存 4bit ~ 8bit 效果是很明显的，再向上就变慢了
    local _CACHED_VALUES_BIT_COUNT      = 7
    local _CACHED_VALUES_STEP_MUL       = math.floor(2 ^ _CACHED_VALUES_BIT_COUNT)
    local _CACHED_VALUES_MIN_OP         = 0
    local _CACHED_VALUES_MAX_OP         = math.floor(2 ^ _CACHED_VALUES_BIT_COUNT - 1)

    -- 例如缓存了 4bit x 4bit 的结果，所以将 32bit 分成 8 轮运算
    local _CACHED_VALUES_LOOP_COUNT     = math.ceil(_BITLIB_BIT_COUNT / _CACHED_VALUES_BIT_COUNT)


    -- 缓存的位运算结果
    local _CACHED_VALUES_AND    = {}
    local _CACHED_VALUES_OR     = {}
    local _CACHED_VALUES_XOR    = {}
    local _CACHED_VALUES_NOT    = {}

    for op1 = _CACHED_VALUES_MIN_OP, _CACHED_VALUES_MAX_OP
    do
        for op2 = _CACHED_VALUES_MIN_OP, _CACHED_VALUES_MAX_OP
        do
            local idx = op1 * _CACHED_VALUES_STEP_MUL + op2
            local loopCount = _CACHED_VALUES_BIT_COUNT / _META_VALUES_BIT_COUNT

            _CACHED_VALUES_AND[idx] = __doBitwiseOp(op1, op2,
                                                    _META_VALUES_STEP_MUL,
                                                    loopCount,
                                                    _META_CACHED_VALUES_AND)

            _CACHED_VALUES_OR[idx] = __doBitwiseOp(op1, op2,
                                                   _META_VALUES_STEP_MUL,
                                                   loopCount,
                                                   _META_CACHED_VALUES_OR)

            _CACHED_VALUES_XOR[idx] = __doBitwiseOp(op1, op2,
                                                    _META_VALUES_STEP_MUL,
                                                    loopCount,
                                                    _META_CACHED_VALUES_XOR)

            _CACHED_VALUES_NOT[idx] = __doBitwiseOp(op1, op2,
                                                    _META_VALUES_STEP_MUL,
                                                    loopCount,
                                                    _META_CACHED_VALUES_NOT)
        end
    end


    local band      = nil
    local bor       = nil
    local bxor      = nil
    local bnot      = nil
    local lshift    = nil
    local rshift    = nil
    local lrotate   = nil
    local rrotate   = nil

    band = function(op1, op2)
        return __doBitwiseOp(op1, op2,
                             _CACHED_VALUES_STEP_MUL,
                             _CACHED_VALUES_LOOP_COUNT,
                             _CACHED_VALUES_AND)
    end


    bor = function(op1, op2)
        return __doBitwiseOp(op1, op2,
                             _CACHED_VALUES_STEP_MUL,
                             _CACHED_VALUES_LOOP_COUNT,
                             _CACHED_VALUES_OR)
    end


    bxor = function(op1, op2)
        return __doBitwiseOp(op1, op2,
                             _CACHED_VALUES_STEP_MUL,
                             _CACHED_VALUES_LOOP_COUNT,
                             _CACHED_VALUES_XOR)
    end


    bnot = function(op1)
        local res = __doBitwiseOp(op1, _BITLIB_MASK,
                                  _CACHED_VALUES_STEP_MUL,
                                  _CACHED_VALUES_LOOP_COUNT,
                                  _CACHED_VALUES_NOT)

        return res
    end


    lshift = function(op1, op2)
        if op2 >= _BITLIB_BIT_COUNT
        then
            return 0
        elseif op2 < 0
        then
            return rshift(op1, -op2)
        else
            local result = op1 * _BITLIB_POW_LIST[op2]
            return result % _BITLIB_MOD
        end
    end


    rshift = function(op1, op2)
        if op2 >= _BITLIB_BIT_COUNT
        then
            return 0
        elseif op2 < 0
        then
            return lshift(op1, -op2)
        else
            local result = op1 / _BITLIB_POW_LIST[op2]
            return math.floor(result)
        end
    end


    local function __normalizeRotateCount(rotCount)
        -- 保证 rotCount 是正数
        local ret = rotCount % _BITLIB_BIT_COUNT
        ret = (ret < 0) and (ret + _BITLIB_BIT_COUNT) or (ret)
        return ret
    end


    lrotate = function(op1, rot)
        local rotCount = __normalizeRotateCount(rot)
        local shiftedPart = lshift(op1, rotCount)
        local rotatedPart = rshift(op1, _BITLIB_BIT_COUNT - rotCount)
        return shiftedPart + rotatedPart
    end


    rrotate = function(op1, rot)
        local rotCount = __normalizeRotateCount(rot)
        local shiftedPart = rshift(op1, rotCount)
        local rotatedPart = lshift(op1, _BITLIB_BIT_COUNT - rotCount)
        return shiftedPart + rotatedPart
    end


    return
    {
        band    = band,
        bor     = bor,
        bxor    = bxor,
        bnot    = bnot,
        lshift  = lshift,
        rshift  = rshift,
        lrotate = lrotate,
        rrotate = rrotate,
    }
end


local __gSoftImpl = nil

local function __getSoftImpl()
    __gSoftImpl = __gSoftImpl or __doCreateSoftImpl()
    return __gSoftImpl
end


local __gBitLibImpl = bit32 or __getSoftImpl()

return
{
    __getSoftImpl   = __getSoftImpl,

    band            = __gBitLibImpl.band,
    bor             = __gBitLibImpl.bor,
    bxor            = __gBitLibImpl.bxor,
    bnot            = __gBitLibImpl.bnot,
    lshift          = __gBitLibImpl.lshift,
    rshift          = __gBitLibImpl.rshift,
    lrotate         = __gBitLibImpl.lrotate,
    rrotate         = __gBitLibImpl.rrotate,
}