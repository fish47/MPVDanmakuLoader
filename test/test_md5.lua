_USE_SOFT_BITWISE_LIB = true
local md5 = require('src/md5')              --= md5 md5
local lu = require('3rdparties/luaunit')    --= luaunit lu


TestSoftBitwiseOp =
{
    test_all = function(self)
        for i = 1, 100000
        do
            local op1 = math.random(0, 2 ^ 32)
            local op2 = math.random(0, 2 ^ 32)
            local shift = math.random(0, 32)

            lu.assertEquals(md5.__band(op1, op2), bit32.band(op1, op2))
            lu.assertEquals(md5.__bor(op1, op2), bit32.bor(op1, op2))
            lu.assertEquals(md5.__bxor(op1, op2), bit32.bxor(op1, op2))
            lu.assertEquals(md5.__bnot(op1), bit32.bnot(op1))
            lu.assertEquals(md5.__lshift(op1, shift), bit32.lshift(op1, shift))
            lu.assertEquals(md5.__rshift(op1, shift), bit32.rshift(op1, shift))
--            lu.assertEquals(md5.__lrotate(op1, op2), bit32.lrotate(op1, op2))
        end
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())