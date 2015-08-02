local lu = require('3rdparties/luaunit')    --= luaunit lu
local json = require('src/json')            --= json json
local utf8 = require('src/utf8')            --= utf8 utf8


local function __doAssertParseValue(content, expected)
    local ret, val = json.parse(content)
    lu.assertTrue(ret)
    lu.assertEquals(val, expected)
end


local function __doAssertParseFailed(content)
    lu.assertFalse(json.parse(content))
end


TestJSON =
{
    test_plain_values = function()
        __doAssertParseValue("-1", -1)
        __doAssertParseValue("1", 1)
        __doAssertParseValue("123", 123)
        __doAssertParseValue("1.23", 1.23)
        __doAssertParseValue("-0.012", -0.012)
        __doAssertParseValue("121.1e+123", 121.1e+123)

        __doAssertParseValue("null", nil)
        __doAssertParseValue("true", true)
        __doAssertParseValue("false", false)

        __doAssertParseValue([[  "asdf"  ]], "asdf")
        __doAssertParseValue([[ "\n123" ]], "\n123")
        __doAssertParseValue([[ "123\\456\/789\b01\n23\r456\t7890" ]],
                             "123\\456/789\f01\n23\r456\t7890")

        local buf = { "asdf" }
        utf8.getUTF8Bytes(0x9ae3, buf, string.char)
        table.insert(buf, "fff")
        utf8.getUTF8Bytes(0x1343, buf, string.char)
        table.insert(buf, "aab")
        __doAssertParseValue([[ "asdf\u9ae3fff\u1343aab" ]], table.concat(buf))
    end,


    test_arrays = function()
        __doAssertParseValue("[]", {})
        __doAssertParseValue("[ [], [ 1 ] ]", { {}, { 1 } })
        __doAssertParseValue("[ [ [ ] ] ]", { { {} } })

        __doAssertParseValue("[ 1, 2, 3, [ 1, 2, 3 ], 4, 5 ]",
                             { 1, 2, 3, { 1, 2, 3 }, 4, 5 })

        __doAssertParseValue("[ 1, { \"abb\": [ 1, 2, 3 ] }, 3 ]",
                             { 1, { abb = { 1, 2, 3 } }, 3 })
    end,


    test_object = function()
        __doAssertParseValue([[ { "a":"123", "b":123  } ]], { a = "123", b = 123 })
        __doAssertParseValue([[ { "ab":"123", "bb":123  } ]], { ab = "123", bb = 123 })

        __doAssertParseValue([[ { "ab" : 1, "cd" : { "21" : { "sd" : [] } }, "null": true } ]],
                             { ab = 1, cd = { ["21"] = { sd = {} } }, ["null"] = true })

        __doAssertParseValue([[ { "a" : [ 1, "a", "bb", { "ab" : [ 3, 4, 5 ] }, "123" ] } ]],
                             { a = { 1, "a", "bb", { ab = { 3, 4, 5 } }, "123" } })
    end,


    test_illegal_constant = function()
        __doAssertParseFailed("007")
        __doAssertParseFailed("nil")
        __doAssertParseFailed("12,")
        __doAssertParseFailed([["asdfq\"]])
        __doAssertParseFailed([["asdfq\1"]])
        __doAssertParseFailed([["asdfq\u123"]])
    end,


    test_illegal_array = function()
        __doAssertParseFailed("[ 1, 2 }")
        __doAssertParseFailed("[ 1, [] }")
        __doAssertParseFailed("[ 1, 2,, ]")
        __doAssertParseFailed("[[[ 1, ")
        __doAssertParseFailed("[[[ 1 ]] ")
    end,


    test_illegal_object = function()
        __doAssertParseFailed([[ {  "as" :  } ]])
        __doAssertParseFailed([[ {  "as" ::  } ]])
        __doAssertParseFailed([[ {  "as" : 123,,  } ]])
        __doAssertParseFailed([[ {  "as" : 123, [] } ]])
        __doAssertParseFailed([[ {  "as" : 123,  123 } ]])
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())