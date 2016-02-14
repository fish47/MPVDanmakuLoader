local lu        = require("test/luaunit")
local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local serialize = require("src/base/serialize")


TestSerialize =
{
    setUp = function(self)
        self._mTmpFilePaths = {}
    end,

    tearDown = function(self)
        for _, filepath in ipairs(self._mTmpFilePaths)
        do
            os.remove(filepath)
        end
        self._mTmpFilePaths = nil
    end,

    __getTempPath = function(self)
        local ret = os.tmpname()
        table.insert(self._mTmpFilePaths, ret)
        return ret
    end,

    __serializeTuplesToStream = function(self, data, file)
        for _, element in ipairs(data)
        do
            serialize.serializeTuple(file, utils.unpackArray(element))
        end
    end,

    __deserializeTuples = function(self, file)
        local results = nil
        local function __onReadTuple(...)
            results = results or {}
            table.insert(results, {...})
        end

        file:seek(constants.SEEK_MODE_BEGIN, 0)
        local serializedString = utils.readAndCloseFile(file)
        serialize.deserializeTupleFromString(serializedString, __onReadTuple)
        return results
    end,


    testSerialize = function(self)
        local origin = { { 1, 'A', "b" }, { "C", 1, false, nil, 0 }, { false }, {} }
        local tmpFile = io.tmpfile()
        self:__serializeTuplesToStream(origin, tmpFile)

        local results = self:__deserializeTuples(tmpFile)
        lu.assertEquals(origin, results)
    end,


    testInject = function()
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

        lu.assertTrue(types.isEmptyTable(outsideTable))
        lu.assertEquals(#referred, 2)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())