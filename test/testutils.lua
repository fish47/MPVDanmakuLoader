local lu    = require("test/luaunit")
local utils = require("src/base/utils")


TestEscape =
{
    __doTest = function(self, func, origin, expected)
        local ret = func(origin)
        lu.assertEquals(ret, expected)
    end,


    testEscapASSText = function(self)
        local func = utils.escapeASSString
        self:__doTest(func, "\n", "\\N")
        self:__doTest(func, "\\", "\\\\")
        self:__doTest(func, "{", "\\{")
        self:__doTest(func, "}", "\\}")
        self:__doTest(func, " ", "\\h")
    end,


    testUnescapeXMLString = function(self)
        local func = utils.unescapeXMLString
        self:__doTest(func, "&lt;", "<")
        self:__doTest(func, "&gt;", ">")
        self:__doTest(func, "&amp;", "&")
        self:__doTest(func, "&apos;", "\'")
        self:__doTest(func, "&quot;", "\"")
        self:__doTest(func, "&#x00020;", " ")
    end,


    testEscapeURLString = function(self)
        local func = utils.escapeURLString
        self:__doTest(func, "要要", "%E8%A6%81%E8%A6%81")
        self:__doTest(func, "%", "%25")
        self:__doTest(func,
                      "!#$&'()*+,/:;=?@[]",
                      "%21%23%24%26%27%28%29%2A%2B%2C%2F%3A%3B%3D%3F%40%5B%5D")
    end,

    testUnesapeJSONString = function(self)
        local func = utils.unescapeJSONString
        self:__doTest(func, [[\" \\ \/ \f \n \t \r]], "\" \\ / \f \n \t \r")
        self:__doTest(func, "\\u8981", "要")
    end,
}


TestFindJSONString =
{
    __doTest = function(self, text, findStart, captured, nextFindStart)
        local ret1, ret2 = utils.findJSONString(text, findStart)
        lu.assertEquals(ret1, captured)
        lu.assertEquals(ret2, nextFindStart)
    end,

    testFindEmptyString = function(self)
        self:__doTest([[""345]], nil, "", 3)
        self:__doTest([[12345""]], nil, "", 8)
        self:__doTest([[12345678]], nil, nil, nil)
    end,


    testFindString = function(self)
        local function __doTest(text, findStart, captured, nextFindStart)
            local ret1, ret2 = utils.findJSONString(text, findStart)
            lu.assertEquals(ret1, captured)
            lu.assertEquals(ret2, nextFindStart)
        end

        --         123456789
        __doTest([[123"AA"89]], 1, "AA", 8)
        __doTest([["AA"56789]], 1, "AA", 5)
        __doTest([["AA"56789]], 2, nil)
        __doTest([["AA"56789]], 5, nil)
        __doTest([[12345"AA"]], 1, "AA", 10)
        __doTest([[123"AA\""]], 1, "AA\"", 10)
        __doTest([[1"AA\"1"9]], 1, "AA\"1", 9)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())