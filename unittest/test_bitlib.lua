local lu = require("3rdparties/luaunit")    --= luaunit lu
local bitlib = require("src/_utils/bitlib")


TestSoftBitwiseOp =
{
    test_all = function()
        local bitlibArg = bitlib._getSoftImpl()
        for i = 1, 100000
        do
            local op1 = math.random(0, 2 ^ 32 - 1)
            local op2 = math.random(0, 2 ^ 32 - 1)
            local shift = math.random(-64, 64)

            lu.assertEquals(bitlibArg.band(op1, op2), bit32.band(op1, op2))
            lu.assertEquals(bitlibArg.bor(op1, op2), bit32.bor(op1, op2))
            lu.assertEquals(bitlibArg.bxor(op1, op2), bit32.bxor(op1, op2))
            lu.assertEquals(bitlibArg.bnot(op1), bit32.bnot(op1))
            lu.assertEquals(bitlibArg.lshift(op1, shift), bit32.lshift(op1, shift))
            lu.assertEquals(bitlibArg.rshift(op1, shift), bit32.rshift(op1, shift))
            lu.assertEquals(bitlibArg.lrotate(op1, shift), bit32.lrotate(op1, shift))
            lu.assertEquals(bitlibArg.rrotate(op1, shift), bit32.rrotate(op1, shift))
        end

        lu.assertEquals(bitlibArg.band(0xffffffff, 0x12345678), 0x12345678)
        lu.assertEquals(bitlibArg.band(0xff0f0ff0, 0x12345678), 0x12040670)
        lu.assertEquals(bitlibArg.bor(0xff00ff00, 0x00ff00ff), 0xffffffff)
        lu.assertEquals(bitlibArg.bor(0xff000000, 0x00ff00ff), 0xffff00ff)
        lu.assertEquals(bitlibArg.bnot(0xffffffff), 0x00000000)
        lu.assertEquals(bitlibArg.bnot(0x00000000), 0xffffffff)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())