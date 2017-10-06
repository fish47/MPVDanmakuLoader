local lu            = require("lib/luaunit")
local testutils     = require("common/testutils")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")


local MockNetworkConnection =
{
    __mExpectedFlags    = classlite.declareTableField(),
    __mExpectedURLs     = classlite.declareTableField(),
    __mRequestResults   = classlite.declareTableField(),
    __mRequestReturn    = classlite.declareConstantField(true),
}

function MockNetworkConnection:_requestURLs(urls, timeout, flags, outArray)
    local results = self.__mRequestResults
    local expectedURLs = self.__mExpectedURLs
    local expectedFlags = self.__mExpectedFlags
    if types.isNonEmptyArray(expectedFlags)
    then
        lu.assertEquals(expectedFlags, flags)
    end
    if types.isNonEmptyArray(expectedURLs)
    then
        lu.assertEquals(expectedURLs, urls)
    end
    utils.clearTable(outArray)
    utils.appendArrayElements(outArray, results)
    return self.__mRequestReturn
end

local function __packArgs(array, ...)
    utils.clearTable(array)
    utils.packArray(array, ...)
end

function MockNetworkConnection:setExpectedRequestFlags(...)
    __packArgs(self.__mExpectedFlags, ...)
end

function MockNetworkConnection:setExpectedURLs(...)
    __packArgs(self.__mExpectedURLs, ...)
end

function MockNetworkConnection:setRequestResults(ret, ...)
    self.__mRequestReturn = ret
    __packArgs(self.__mRequestResults, ...)
end

classlite.declareClass(MockNetworkConnection, unportable.NetworkConnection)


TestNetwork = {}

function TestNetwork:testIndividualFlags()
    local conn = MockNetworkConnection:new()
    conn:resetRequestFlags()
    local flag1 = conn:setAcceptXML(true)
    conn:receiveLater("1")

    conn:setAcceptXML(false)
    local flag2 = conn:setUncompress(true)
    conn:receiveLater("2")

    conn:resetRequestFlags()
    conn:setAcceptXML(true)
    local flag3 = conn:setUncompress(true)
    conn:receiveLater("3")

    conn:setExpectedRequestFlags(flag1, flag2, flag3)
    conn:setRequestResults(true, "r1", "r2", "r3")
    lu.assertEquals(flag3, bit32.bor(flag1, flag2))
    lu.assertTrue(conn:flushReceiveQueue())
end


function TestNetwork:testReceiveAndFlush()
    local function __addDeferredResult(result, arg)
        if arg
        then
            table.insert(arg, result)
        end
    end

    local deferredResults = {}
    local conn = MockNetworkConnection:new()
    conn:receiveLater("1", __addDeferredResult, deferredResults)
    conn:receiveLater("2")
    conn:receiveLater("3", __addDeferredResult, deferredResults)
    conn:receiveLater("4", __addDeferredResult, deferredResults)
    conn:setRequestResults(true, "r1", "r2", "r3", "r4")
    lu.assertTrue(conn:flushReceiveQueue())
    lu.assertEquals(deferredResults, { "r1", "r3", "r4" })

    utils.clearTable(deferredResults)
    conn:receiveLater("1", __addDeferredResult, deferredResults)
    conn:receiveLater("2", __addDeferredResult)
    conn:setRequestResults(true, "r3")
    conn:setExpectedURLs("3")
    lu.assertEquals(conn:receive("3"), "r3")
    conn:receiveLater("4")
    conn:receiveLater("5", __addDeferredResult, deferredResults)
    conn:setRequestResults(true, "r1", "r2", "r4", "r5")
    conn:setExpectedURLs("1", "2", "4", "5")
    lu.assertTrue(conn:flushReceiveQueue())
    lu.assertEquals(deferredResults, { "r1", "r5" })

    utils.clearTable(deferredResults)
    conn:receiveLater("1", __addDeferredResult, deferredResults)
    conn:setRequestResults(false)
    conn:setExpectedURLs("2")
    lu.assertIsNil(conn:receive("2"))
    conn:receiveLater("3", __addDeferredResult, deferredResults)
    conn:setRequestResults(false)
    conn:setExpectedURLs("1", "3")
    lu.assertFalse(conn:flushReceiveQueue())
    lu.assertEquals(deferredResults, {})
end

testutils.runTestCases()