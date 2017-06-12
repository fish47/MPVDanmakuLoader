local lu    = require("test/luaunit")
local utils = require("src/base/utils")
local types = require("src/base/types")


TestEscape = {}

function TestEscape:__doTest(func, origin, expected)
    local ret = func(origin)
    lu.assertEquals(ret, expected)
end


function TestEscape:testEscapASSText()
    local func = utils.escapeASSString
    self:__doTest(func, "\n", "\\N")
    self:__doTest(func, "\\", "\\\\")
    self:__doTest(func, "{", "\\{")
    self:__doTest(func, "}", "\\}")
    self:__doTest(func, " ", "\\h")
end


function TestEscape:testUnescapeXMLString()
    local func = utils.unescapeXMLString
    self:__doTest(func, "&lt;", "<")
    self:__doTest(func, "&gt;", ">")
    self:__doTest(func, "&amp;", "&")
    self:__doTest(func, "&apos;", "\'")
    self:__doTest(func, "&quot;", "\"")
    self:__doTest(func, "&#x00020;", " ")
end


function TestEscape:testEscapeURLString()
    local func = utils.escapeURLString
    self:__doTest(func, "要要", "%E8%A6%81%E8%A6%81")
    self:__doTest(func, "%", "%25")
    self:__doTest(func,
                  "!#$&'()*+,/:;=?@[]",
                  "%21%23%24%26%27%28%29%2A%2B%2C%2F%3A%3B%3D%3F%40%5B%5D")
end

function TestEscape:testUnesapeJSONString()
    local func = utils.unescapeJSONString
    self:__doTest(func, [[\" \\ \/ \f \n \t \r]], "\" \\ / \f \n \t \r")
    self:__doTest(func, "\\u8981", "要")
end



TestValidators = {}

function TestValidators:testValidators()
    local boolOutputHook1 = function(val)
        return val and 1 or 2
    end

    local boolOutputHook2 = function(val)
        return val and "2" or "3"
    end

    local v1 = utils.createSimpleValidator(types.toBoolean, boolOutputHook1)
    lu.assertEquals(v1("true"), 1)
    lu.assertEquals(v1(false), 2)

    local v2 = utils.createSimpleValidator(nil, boolOutputHook2)
    lu.assertEquals(v2(nil, true), "2")
    lu.assertEquals(v2(nil, false), "3")

    local v3 = utils.createIntValidator(tonumber, nil, nil, 100)
    lu.assertEquals(v3("12"), 12)
    lu.assertEquals(v3("123"), 100)

    local v4 = utils.createIntValidator(tonumber, tostring, 0, nil)
    lu.assertEquals(v4("-1000"), "0")
    lu.assertEquals(v4(nil, 40), "40")

    local v5 = utils.createIntValidator(nil, nil, 10, 100)
    lu.assertEquals(v5(nil, 200), 100)
    lu.assertEquals(v5(5), 10)
end



TestFindJSONString = {}

function TestFindJSONString:__doTest(text, findStart, captured, nextFindStart)
    local ret1, ret2 = utils.findJSONString(text, findStart)
    lu.assertEquals(ret1, captured)
    lu.assertEquals(ret2, nextFindStart)
end


function TestFindJSONString:testFindEmptyString()
    --              12345678
    self:__doTest([[""345]], nil, "", 3)
    self:__doTest([[12345""]], nil, "", 8)
    self:__doTest([[12345678]], nil, nil, nil)
end


function TestFindJSONString:testFindString()
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
end


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())