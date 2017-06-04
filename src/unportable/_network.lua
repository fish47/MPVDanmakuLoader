local NetworkConnection =
{
    _mIsCompressed      = classlite.declareConstantField(false),
    _mHeaders           = classlite.declareTableField(),
    _mCallbacks         = classlite.declareTableField(),
    _mCallbackArgs      = classlite.declareTableField(),
    _mConnections       = classlite.declareTableField(),
    _mTimeoutSeconds    = classlite.declareConstantField(nil),

    _createConnection = constants.FUNC_EMPTY,
    _readConnection = constants.FUNC_EMPTY,



    setTimeout = function(self, timeout)
        local val = types.chooseValue(types.isPositiveNumber(timeout), timeout)
        self._mTimeoutSeconds = val
    end,

    receive = function(self, url)
        if types.isString(url)
        then
            local succeed, conn = self:_createConnection(url)
            local content = succeed and self:_readConnection(conn)
            return content
        end
    end,

    receiveLater = function(self, url, callback, arg)
        if types.isString(url) and types.isFunction(callback)
        then
            local succeed, conn = self:_createConnection(url)
            if succeed
            then
                -- 注意参数有可能为空
                local newCount = #self._mConnections + 1
                self._mConnections[newCount] = conn
                self._mCallbacks[newCount] = callback
                self._mCallbackArgs[newCount] = arg
                return true
            end
        end
    end,

    flushReceiveQueue = function(self, url)
        local conns = self._mConnections
        local callbacks = self._mCallbacks
        local callbackArgs = self._mCallbackArgs
        local callbackCount = #callbacks
        for i = 1, callbackCount
        do
            local content = self:_readConnection(conns[i])
            callbacks[i](content, callbackArgs[i])
            conns[i] = nil
            callbacks[i] = nil
            callbackArgs[i] = nil
        end
    end,

    clearHeaders = function(self)
        self._mIsCompressed = false
        utils.clearTable(self._mHeaders)
        return self
    end,

    setCompressed = function(self, val)
        self._mIsCompressed = types.toBoolean(val)
    end,

    addHeader = function(self, val)
        if types.isString(val)
        then
            table.insert(self._mHeaders, val)
        end
    end,
}

classlite.declareClass(_NetworkConnectionBase)