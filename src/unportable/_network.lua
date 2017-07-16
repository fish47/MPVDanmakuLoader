local _executor     = require("src/unportable/_executor")
local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")


local NetworkConnection =
{
    _mRequestTimeout        = classlite.declareConstantField(nil),
    _mRequestURLs           = classlite.declareTableField(),
    _mRequestFlags          = classlite.declareTableField(),
    _mRequestCallbacks      = classlite.declareTableField(),
    _mRequestCallbackArgs   = classlite.declareTableField(),

    __mPyScriptExecutor     = classlite.declareConstantField(nil),
    __mCurrentReqFlags      = classlite.declareConstantField(0),
    __mTmpTable1            = classlite.declareTableField(),
    __mTmpTable2            = classlite.declareTableField(),
    __mTmpTable3            = classlite.declareTableField(),
    __mTmpTable4            = classlite.declareTableField(),
}

function NetworkConnection:setPyScriptExecutor(executor)
    self.__mPyScriptExecutor = executor
end

function NetworkConnection:__getConnectionCount()
    return #self._mRequestURLs
end

function NetworkConnection:_requestURLs(urls, timeout, flags, results)
    local executor = self.__mPyScriptExecutor
    return executor and executor:requestURLs(urls, timeout, flags, results) or false
end

function NetworkConnection:_createConnection(url, callback, arg)
    if types.isString(url)
    then
        -- 注意回调和参数有可能为空
        local idx = self:__getConnectionCount() + 1
        self._mRequestURLs[idx] = url
        self._mRequestFlags[idx] = self.__mCurrentReqFlags
        self._mRequestCallbacks[idx] = callback
        self._mRequestCallbackArgs[idx] = arg
        return true
    end
    return false
end

function NetworkConnection:__readConnections(startIdx, lastIdx)
    local succeed = false
    if startIdx <= lastIdx
    then
        local urls = self._mRequestURLs
        local flags = self._mRequestFlags
        local urlArgs = utils.clearTable(self.__mTmpTable1)
        local flagArgs = utils.clearTable(self.__mTmpTable2)
        for i = startIdx, lastIdx
        do
            local idx = i - startIdx + 1
            urlArgs[idx] = urls[i]
            flagArgs[idx] = flags[i]
        end

        local timeout = self._mRequestTimeout
        local results = utils.clearTable(self.__mTmpTable3)
        succeed = self:_requestURLs(urlArgs, timeout, flagArgs, results)

        local callbacks = self._mRequestCallbacks
        local callbackArgs = self._mRequestCallbackArgs
        for i = startIdx, lastIdx
        do
            local cb = callbacks[i]
            if succeed and types.isFunction(cb)
            then
                local result = results[i - startIdx + 1]
                cb(result, callbackArgs[i])
            end

            -- 内部实现要保证请求以栈式增删，不然数组会有空洞
            urls[i] = nil
            callbacks[i] = nil
            callbackArgs[i] = nil
        end

        utils.clearTable(urlArgs)
        utils.clearTable(flagArgs)
        utils.clearTable(results)
    end
    return succeed
end

function NetworkConnection:resetRequestFlags()
    self.__mCurrentReqFlags = 0
end

function NetworkConnection:setTimeout(timeout)
    local val = types.chooseValue(types.isPositiveNumber(timeout), timeout)
    self._mRequestTimeout = val
end

function NetworkConnection:__setRequestFlag(flag, val)
    local flags = self.__mCurrentReqFlags
    if val
    then
        flags = bit32.bor(flags, flag)
    else
        if bit32.test(flags, flag)
        then
            flags = flags - flag
        end
    end
    self.__mCurrentReqFlags = flags
end

function NetworkConnection:setUncompress(val)
    self:__setRequestFlag(_executor._REQ_URL_FLAG_UNCOMPRESS, val)
end

function NetworkConnection:setAcceptXML(val)
    self:__setRequestFlag(_executor._REQ_URL_FLAG_ACCEPT_XML, val)
end

function NetworkConnection:receive(url)
    local function __getResult(content, tbl)
        utils.clearTable(tbl)
        tbl[1] = content
    end

    local result = nil
    if types.isString(url)
    then
        local idx = self:__getConnectionCount() + 1
        local resultTable = utils.clearTable(self.__mTmpTable4)
        local succeed = self:_createConnection(url, __getResult, resultTable)
        if succeed
        then
            self:__readConnections(idx, idx)
            result = resultTable[1]
        end
        utils.clearTable(resultTable)
    end
    return result
end

function NetworkConnection:receiveLater(url, callback, arg)
    return self:_createConnection(url, callback, arg)
end

function NetworkConnection:flushReceiveQueue()
    return self:__readConnections(1, self:__getConnectionCount())
end

classlite.declareClass(NetworkConnection)

return
{
    NetworkConnection   = NetworkConnection,
}