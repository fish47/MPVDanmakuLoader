local lu = require("3rdparties/luaunit")    --= luaunit lu
local utils = require("src/utils")
local serialize = require("src/_shell/serialize")


TestSerialize =
{
    test_serialize = function()
        local origin = { { 1, 'A', "b" }, { "C", 1, false, nil }, { false }, {} }
        local tmpFile = io.tmpfile()
        for _, element in ipairs(origin)
        do
            serialize.appendSerializedTupleToStream(tmpFile, element)
        end
        tmpFile:seek("set", 0)

        local results = {}
        local function __onReadTuple(...)
            table.insert(results, {...})
        end

        local serializedData = utils.readAndCloseFile(tmpFile)
        serialize.deserializeTupleFromString(serializedData, __onReadTuple)
        lu.assertEquals(origin, results)
    end,


    test_inject = function()
        local outsideTable = {}
        local referred = {}
        local function __onReadTuple(...)
            table.insert(referred, {...})
        end

        local rawData = [[
            _(1, 2, 3)
            _(4, 5, 6)
            table.insert(outsideTable, 1)
        ]]
        serialize.deserializeTupleFromString(rawData, __onReadTuple)

        lu.assertTrue(utils.isEmptyTable(outsideTable))
        lu.assertEquals(#referred, 2)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())