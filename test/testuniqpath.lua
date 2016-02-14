local lu    = require("test/luaunit")
local utils = require("src/base/utils")


TestUniqueFilePath =
{
    __doTest = function(self, input, existed, expected)
        local function __isFileExisted(path)
            return utils.linearSearchArray(existed, path)
        end

        local ret = utils.getUniqueFilePath(input, __isFileExisted)
        lu.assertEquals(ret, expected)
    end,

    __doTestNewName = function(self, input, expected)
        self:__doTest(input, { input }, expected)
    end,

    testAll = function(self)
        self:__doTest("foo.txt", { "f1.txt", "f2.txt", "f3.txt" }, "foo.txt")
        self:__doTest("foo", { "foo", "foo_1", "f3" }, "foo_2")
        self:__doTestNewName("foo.txt", "foo_1.txt")
        self:__doTestNewName("foo_1.txt", "foo_2.txt")
        self:__doTestNewName(".txt", "_1.txt")
        self:__doTestNewName("_.txt", "__1.txt")
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())