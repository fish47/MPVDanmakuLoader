local lu = require('3rdparties/luaunit')    --= luaunit lu
local utils = require('src/utils')          --= utils utils


TestEscapeASSText =
{
}

TestEscape =
{
    __doTest = function(self, func, origin, expected)
        local ret = func(origin)
        lu.assertEquals(ret, expected)
    end,


    test_escape_ass_text = function(self)
        local func = utils.escapeASSString
        self:__doTest(func, "\n", "\\N")
        self:__doTest(func, "\\", "\\\\")
        self:__doTest(func, "{", "\\{")
        self:__doTest(func, "}", "\\}")
        self:__doTest(func, " ", "\\h")
    end,


    test_unescape_xml_text = function(self)
        local func = utils.unescapeXMLString
        self:__doTest(func, "&lt;", "<")
        self:__doTest(func, "&gt;", ">")
        self:__doTest(func, "&amp;", "&")
        self:__doTest(func, "&apos;", "\'")
        self:__doTest(func, "&quot;", "\"")
        self:__doTest(func, "&#x00020;", " ")
    end,


    test_escape_url_text = function(self)
        local func = utils.escapeURLString
        self:__doTest(func, "要要", "%E8%A6%81%E8%A6%81")
        self:__doTest(func, "%", "%25")
        self:__doTest(func,
                      "!#$&'()*+,/:;=?@[]",
                      "%21%23%24%26%27%28%29%2A%2B%2C%2F%3A%3B%3D%3F%40%5B%5D")
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())