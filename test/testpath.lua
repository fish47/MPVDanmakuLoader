local lu            = require("test/luaunit")
local unportable    = require("src/base/unportable")


TestPath =
{
    testNormalizePath = function()
        local function __doTest(arg, ret)
            lu.assertEquals(unportable.normalizePath(arg), ret)
        end

        __doTest("/1/2/3/../../..///2/3/////", "/2/3")
        __doTest("/1/./2/./3/./4/../../././", "/1/2")
        __doTest("/../a/b/c", "/a/b/c")
        __doTest("/../../../a/b/c", "/a/b/c")
        __doTest("1/2/3/../../../asdf", "asdf")
        __doTest("1/2/3/../../../../../asdf", "../../asdf")
    end,

    testJoinPath = function()
        local function __doTest(arg1, arg2, ret)
            lu.assertEquals(unportable.joinPath(arg1, arg2), ret)
        end

        __doTest("/1/2/3", "../../../4", "/4")
        __doTest("1/2/3/../../../", "../../../4", "../../../4")
    end,

    testRelativePath = function()
        local function __doTest(arg1, arg2, ret)
            lu.assertEquals(unportable.getRelativePath(arg1, arg2), ret)
        end

        __doTest("/1/2/3/4", "/1/2/3/4/5", "5")
        __doTest("/1/2/3/4", "/a", "../../../../a")
        __doTest("a/b/c/d", "c", "../../../../c")
    end,

    testSplitPath = function()
        local function __doTest(arg, ret1, ret2)
            local dir, path = unportable.splitPath(arg)
        end

        __doTest("/../../", "/")
        __doTest("/a/b", "/a", "b")
        __doTest("/a", "/", 'a')
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())