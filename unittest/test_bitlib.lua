local bitlib = require("src/_utils/_bitlib")
local lu = require("3rdparties/luaunit")    --= luaunit lu


TestSoftBitwiseOp =
{
    test_all = function()
        for i = 1, 100000
        do
            local op1 = math.random(0, 2 ^ 32 - 1)
            local op2 = math.random(0, 2 ^ 32 - 1)
            local shift = math.random(-64, 64)

            lu.assertEquals(bitlib.band(op1, op2), bit32.band(op1, op2))
            lu.assertEquals(bitlib.bor(op1, op2), bit32.bor(op1, op2))
            lu.assertEquals(bitlib.bxor(op1, op2), bit32.bxor(op1, op2))
            lu.assertEquals(bitlib.bnot(op1), bit32.bnot(op1))
            lu.assertEquals(bitlib.lshift(op1, shift), bit32.lshift(op1, shift))
            lu.assertEquals(bitlib.rshift(op1, shift), bit32.rshift(op1, shift))
            lu.assertEquals(bitlib.lrotate(op1, shift), bit32.lrotate(op1, shift))
            lu.assertEquals(bitlib.rrotate(op1, shift), bit32.rrotate(op1, shift))
        end

        lu.assertEquals(bitlib.band(0xffffffff, 0x12345678), 0x12345678)
        lu.assertEquals(bitlib.band(0xff0f0ff0, 0x12345678), 0x12040670)
        lu.assertEquals(bitlib.bor(0xff00ff00, 0x00ff00ff), 0xffffffff)
        lu.assertEquals(bitlib.bor(0xff000000, 0x00ff00ff), 0xffff00ff)
        lu.assertEquals(bitlib.bnot(0xffffffff), 0x00000000)
        lu.assertEquals(bitlib.bnot(0x00000000), 0xffffffff)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())