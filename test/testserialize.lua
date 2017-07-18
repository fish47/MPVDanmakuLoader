local lu        = require("lib/luaunit")
local testutils = require("common/testutils")
local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local serialize = require("src/base/serialize")


TestSerialize = {}

function TestSerialize:setUp()
    self._mTmpFilePaths = {}
end

function TestSerialize:tearDown()
    for _, filepath in ipairs(self._mTmpFilePaths)
    do
        os.remove(filepath)
    end
    self._mTmpFilePaths = nil
end


function TestSerialize:testSerialize()
    local function __doTest(input)
        local results = {}
        local __callback = function(...)
            utils.clearTable(results)
            utils.packArray(results, ...)
        end

        local tmpFile = io.tmpfile()
        serialize.serializeArray(tmpFile, input)
        tmpFile:seek(constants.SEEK_MODE_BEGIN)

        local dataString = tmpFile:read(constants.READ_MODE_ALL)
        serialize.deserializeFromString(dataString, __callback)
        lu.assertEquals(results, input)

        tmpFile:close()
        utils.clearTable(results)
    end

    __doTest({ 1, "A", "b" })
    __doTest({ false })
    __doTest({})
end


function TestSerialize:testInject()
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
    serialize.deserializeFromString(rawData, __onReadTuple)

    lu.assertTrue(types.isEmptyTable(outsideTable))
    lu.assertEquals(#referred, 2)
end


testutils.runTestCases()