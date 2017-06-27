local _cmd      = require("src/unportable/_cmd")
local utils     = require("src/base/utils")
local types     = require("src/base/types")
local classlite = require("src/base/classlite")


local NetworkConnection =
{
    _mRequestTimeout        = classlite.declareConstantField(nil),
    _mRequestURLs           = classlite.declareTableField(),
    _mRequestFlags          = classlite.declareTableField(),
    _mRequestCallbacks      = classlite.declareTableField(),
    _mRequestCallbackArgs   = classlite.declareTableField(),

    __mPyScriptCmdExecutor  = classlite.declareConstantField(nil),
    __mCurrentReqFlags      = classlite.declareConstantField(_cmd._REQ_URL_FLAG_NONE),
    __mTmpTable1            = classlite.declareTableField(),
    __mTmpTable2            = classlite.declareTableField(),
}

function NetworkConnection:setPyScriptCommandExecutor(executor)
    self.__mPyScriptCmdExecutor = executor
end

function NetworkConnection:__getConnectionCount()
    return #self._mRequestURLs
end

function NetworkConnection:_requestURLs(urls, timeout, flags, results)
    local executor = self.__mPyScriptCmdExecutor
    return exexecutor and executor:requestURLs(urls, timeout, flags, results) or false
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
        local urlArgs = utils.clearTable(self.__mTmpTable1)
        for i = startIdx, lastIdx
        do
            urlArgs[i - startIdx] = urls[i]
        end

        local flags = self._mRequestFlags
        local timeout = self._mRequestTimeout
        local results = utils.clearTable(self.__mTmpTable2)
        succeed = self:_requestURLs(urls, timeout, flags, results)

        local callbacks = self._mRequestCallbacks
        local callbackArgs = self._mRequestCallbackArgs
        for i = startIdx, lastIdx
        do
            local cb = callbacks[i]
            if succeed and types.isFunction(cb)
            then
                cb(result, results[i - startIdx])
            end

            -- 内部实现要保证请求以栈式增删，不然数组会有空洞
            urls[i] = nil
            callbacks[i] = nil
            callbackArgs[i] = nil
        end

        utils.clearTable(urlArgs)
        utils.clearTable(results)
    end
    return succeed
end

function NetworkConnection:resetRequestFlags()
    self.__mCurrentReqFlags = _cmd._REQ_URL_FLAG_NONE
end

function NetworkConnection:setTimeout(timeout)
    local val = types.chooseValue(types.isPositiveNumber(timeout), timeout)
    self._mRequestTimeout = val
end

function NetworkConnection:__setRequestFlag(flag, val)
    local flags = self.__mCurrentReqFlags
    if val
    then
        flags = bit32.band(flags, val)
    else
        if bit32.test(flags, flag)
        then
            flags = flags - flag
        end
    end
    self.__mCurrentReqFlags = flags
end

function NetworkConnection:setUncompress(val)
    self:__setRequestFlag(_cmd._REQ_URL_FLAG_UNCOMPRES, val)
end

function NetworkConnection:setAcceptXML(val)
    self:__setRequestFlag(_cmd._REQ_URL_FLAG_ACCEPT_XML, val)
end

function NetworkConnection:receive(url)
    local function __getResult(content, tbl)
        utils.clearTable(tbl)
        table.insert(tbl, content)
    end

    local result = nil
    if types.isString(url)
    then
        local idx = self:__getConnectionCount() + 1
        local resultTable = utils.clearTable(self.__mTmpTable1)
        local succeed = self:_createConnection(url, __getResult, resultTable)
        if succeed
        then
            self:__readConnections(idx, idx)
            result = resultTable[0]
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