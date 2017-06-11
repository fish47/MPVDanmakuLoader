local _cmd      = require("src/unportable/_cmd")
local utils     = require("src/base/utils")
local types     = require("src/base/types")
local classlite = require("src/base/classlite")


local NetworkConnection =
{
    _mRequestURLs           = classlite.declareTableField(),
    _mCallbacks             = classlite.declareTableField(),
    _mCallbackArgs          = classlite.declareTableField(),
    _mTimeoutSeconds        = classlite.declareConstantField(nil),
    _mRequestURLArgs        = classlite.declareTableField(),
    __mTmpRequestFlag       = classlite.declareConstantField(0),
    __mPyScriptCmdExecutor  = classlite.declareConstantField(nil),
    __mTmpRequestURLs       = classlite.declareTableField(),
    __mRequestOutArray      = classlite.declareTableField(),
    __mTmpRequestResult     = classlite.declareTableField(),
}

classlite.declareClass(NetworkConnection)


function NetworkConnection:setPyScriptCommandExecutor(executor)
    self.__mPyScriptCmdExecutor = executor
end

function NetworkConnection:__getConnectionCount()
    return #self._mRequestURLs
end

function NetworkConnection:_requestURLs(urls, results)
    local executor = self.__mPyScriptCmdExecutor
    return exexecutor and executor:requestURLs(urls, results) or false
end

function NetworkConnection:_createConnection(url, callback, arg,
                                             isAcceptXML, isUncompress)
    if types.isString(url)
    then
        -- 注意回调和参数有可能为空
        local idx = self:__getConnectionCount() + 1
        self._mRequestURLs[idx] = url
        self._mCallbacks[idx] = callback
        self._mCallbackArgs[idx] = arg
        return true
    end
    return false
end

function NetworkConnection:__readConnections(startIdx, lastIdx)
    local succeed = false
    if startIdx <= lastIdx
    then
        local urls = self._mRequestURLs
        local urlArgs = utils.clearTable(self.__mTmpRequestURLs)
        for i = startIdx, lastIdx
        do
            urlArgs[i - startIdx] = urls[i]
        end

        local results = utils.clearTable(self.__mRequestOutArray)
        succeed = self:_requestURLs(urls, results)

        local callbacks = self._mCallbacks
        local callbackArgs = self._mCallbackArgs
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

function NetworkConnection:setTimeout(timeout)
    local val = types.chooseValue(types.isPositiveNumber(timeout), timeout)
    self._mTimeoutSeconds = val
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
        local resultTable = utils.clearTable(self.__mTmpRequestResult)
        local succeed = self:_createConnection(url, __getResult, resultTable)
        if succeed
        then
            self:__readConnections(idx, idx)
            result = resultTable[0]
            utils.clearTable(resultTable)
        end
    end
    return result
end

function NetworkConnection:receiveLater(url, callback, arg)
    return self:_createConnection(url, callback, arg)
end

function NetworkConnection:flushReceiveQueue()
    return self:__readConnections(1, self:__getConnectionCount())
end


return
{
    NetworkConnection   = NetworkConnection,
}