local lu        = require("3rdparties/luaunit")    --= luaunit lu
local _bitlib   = require("src/base/_bitlib")
local md5       = require("src/base/md5")


TestMD5 =
{
    testAll = function()
        local function __doTest(content, expected)
            local val = md5.calcMD5Hash(content)
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
        __doTest(string.rep("a", 65), "c743a45e0d2e6a95cb859adae0248435")
        __doTest(string.rep("a", 128), "e510683b3f5ffe4093d021808bc6ff70")
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())