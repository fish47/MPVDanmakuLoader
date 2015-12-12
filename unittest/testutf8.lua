local lu    = require("3rdparties/luaunit")    --= luaunit lu
local utf8  = require("src/base/utf8")
local utils = require("src/base/utils")

local __UTF8_TEST_CASES =
{
    0x0000000, { 0x00 },
    0x0000080, { 0xc2, 0x80 },
    0x0000800, { 0xe0, 0xa0, 0x80 },
    0x0010000, { 0xf0, 0x90, 0x80, 0x80 },
    0x0200000, { 0xf8, 0x88, 0x80, 0x80, 0x80 },
    0x4000000, { 0xfc, 0x84, 0x80, 0x80, 0x80, 0x80 },

    0x0000007f, { 0x7f },
    0x000007ff, { 0xdf, 0xbf },
    0x0000ffff, { 0xef, 0xbf, 0xbf },
    0x001fffff, { 0xf7, 0xbf, 0xbf, 0xbf },
    0x03ffffff, { 0xfb, 0xbf, 0xbf, 0xbf, 0xbf },
    0x7fffffff, { 0xfd, 0xbf, 0xbf, 0xbf, 0xbf, 0xbf },
}


TestIterateUTF8CodePoints =
{
    test_decode = function()
        for _, codePoint, stringBytes in utils.iteratePairsArray(__UTF8_TEST_CASES)
        do
            local iterCount = 0
            local str = string.char(utils.unpackArray(stringBytes))
            for _, iterCodePoint in utf8.iterateUTF8CodePoints(str)
            do
                iterCount = iterCount + 1
                lu.assertEquals(iterCodePoint, codePoint)
            end

            lu.assertEquals(iterCount, 1)
        end
    end,


    test_encode = function()
        local encodedBytes = {}
        for _, codePoint, stringBytes in utils.iteratePairsArray(__UTF8_TEST_CASES)
        do
            for _, utf8Byte in utf8.iterateUTF8EncodedBytes(codePoint)
            do
                table.insert(encodedBytes, utf8Byte)
            end

            lu.assertEquals(encodedBytes, stringBytes)
            utils.clearTable(encodedBytes)
        end
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())