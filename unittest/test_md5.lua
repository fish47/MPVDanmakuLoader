local md5 = require("src/_utils/md5")
local bitlib = require("src/_utils/_bitlib")
local lu = require("3rdparties/luaunit")    --= luaunit lu


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
            local val = md5.calcMD5Hash(__readChunkFunc, content, bitlib)
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