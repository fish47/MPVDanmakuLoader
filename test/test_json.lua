local lu = require('3rdparties/luaunit')    --= luaunit lu
local base = require('src/base')            --= base base
local json = require('src/json')            --= json json
local encoding = require('src/encoding')    --= encoding encoding


local function __doAssertParseValue(content, expected)
    local ret, val = json.parse(content)
    lu.assertTrue(ret)
    lu.assertEquals(val, expected)
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
        encoding.getUTF8Bytes(0x9ae3, buf, string.char)
        table.insert(buf, "fff")
        encoding.getUTF8Bytes(0x1343, buf, string.char)
        table.insert(buf, "aab")
        __doAssertParseValue([[ "asdf\u9ae3fff\u1343aab" ]], table.concat(buf))
    end,


    test_arrays = function()
        __doAssertParseValue([[ [ 1, 2, 3, [ 1, 2, 3 ], 4, 5 ] ]],
                             { 1, 2, 3, { 1, 2, 3 }, 4, 5 })
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())