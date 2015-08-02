_USE_SOFT_BITWISE_LIB = true
local md5 = require('src/_utils/md5')
local lu = require('3rdparties/luaunit')    --= luaunit lu


TestSoftBitwiseOp =
{
    test_all = function()
        for i = 1, 100000
        do
            local op1 = math.random(0, 2 ^ 32 - 1)
            local op2 = math.random(0, 2 ^ 32 - 1)
            local shift = math.random(-64, 64)

            lu.assertEquals(md5.__band(op1, op2), bit32.band(op1, op2))
            lu.assertEquals(md5.__bor(op1, op2), bit32.bor(op1, op2))
            lu.assertEquals(md5.__bxor(op1, op2), bit32.bxor(op1, op2))
            lu.assertEquals(md5.__bnot(op1), bit32.bnot(op1))
            lu.assertEquals(md5.__lshift(op1, shift), bit32.lshift(op1, shift))
            lu.assertEquals(md5.__rshift(op1, shift), bit32.rshift(op1, shift))
            lu.assertEquals(md5.__lrotate(op1, shift), bit32.lrotate(op1, shift))
        end

        lu.assertEquals(md5.__band(0xffffffff, 0x12345678), 0x12345678)
        lu.assertEquals(md5.__band(0xff0f0ff0, 0x12345678), 0x12040670)
        lu.assertEquals(md5.__bor(0xff00ff00, 0x00ff00ff), 0xffffffff)
        lu.assertEquals(md5.__bor(0xff000000, 0x00ff00ff), 0xffff00ff)
        lu.assertEquals(md5.__bnot(0xffffffff), 0x00000000)
        lu.assertEquals(md5.__bnot(0x00000000), 0xffffffff)
    end,
}


TestMD5 =
{
    test_hash = function()

        local function __readChunkFunc(content, chunkIdx)
            local byteStartIdx = (chunkIdx - 1) * md5.MD5_CHUNK_BYTE_COUNT + 1
            if byteStartIdx > #content
            then
                return nil
            end

            return content:sub(byteStartIdx, byteStartIdx + md5.MD5_CHUNK_BYTE_COUNT - 1)
        end


        local function __doTest(content, expected)
            local val = md5.calcMD5HashSum(__readChunkFunc, content)
            lu.assertEquals(val, expected)
        end

        __doTest("123", "202cb962ac59075b964b07152d234b70")
        __doTest("HelloWorld", "68e109f0f40ca72a15e05cc22786f8e6")
        __doTest("Danmaku", "d351d06a96e567e896bae4842cb4b998")
        __doTest("Lua", "0ae9478a1db9d1e2c48efa49eac1c7c6")
        __doTest("fish47", "2e0da0076a5f791c2677d9e5df163e5c")

        __doTest(string.rep("a", 60), "cc7ed669cf88f201c3297c6a91e1d18d")
        __doTest(string.rep("a", 61), "cced11f7bbbffea2f718903216643648")
        __doTest(string.rep("a", 62), "24612f0ce2c9d2cf2b022ef1e027a54f")
        __doTest(string.rep("a", 63), "b06521f39153d618550606be297466d5")
        __doTest(string.rep("a", 64), "014842d480b571495a4a0363793f7367")
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())