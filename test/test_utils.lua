local lu = require('3rdparties/luaunit')    --= luaunit lu
local utils = require('src/utils')          --= utils utils


TestEscapeASSText =
{
    test1 = function()
        local function __doTest(orgin, expected)
            local escaped = utils.escapeASSText(orgin)
            lu.assertEquals(escaped, expected)
        end

        __doTest("\n", "\\N")
        __doTest("\\", "\\\\")
        __doTest("{", "\\{")
        __doTest("}", "\\}")
        __doTest(" ", "\\h")
    end,
}


TestUnescapeXMLText =
{
    test1 = function()
        local function __doTest(origin, expected)
            local unescaped = utils.unescapeXMLText(origin)
            lu.assertEquals(unescaped, expected)
        end

        __doTest("&lt;", "<")
        __doTest("&gt;", ">")
        __doTest("&amp;", "&")
        __doTest("&apos;", "\'")
        __doTest("&quot;", "\"")
        __doTest("&#x00020;", " ")
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())