local utils = require('src/utils')      --= utils utils


local _CURL_ARG_SLIENT          = "--silent"
local _CURL_ARG_COMPRESSED      = "--compressed"
local _CURL_SEP_ARGS            = " "

local CURLNetworkConnection =
{
    _mCURLBin           = nil,
    _mCmdArgs           = nil,
    _mCallbackQueue     = nil,
    _mCallbackArgQueue  = nil,
    _mStdoutFileQueue   = nil,

    new = function(obj, curlBin)
        obj = utils.allocateInstance(obj)
        obj._mCURLBin = curlBin
        obj._mCmdArgs = {}
        obj._mCallbackQueue = {}
        obj._mCallbackArgQueue = {}
        obj._mStdoutFileQueue = {}
        return obj
    end,


    _doGetResponseFile = function(self, url, compressed)
        local cmdArgs = self._mCmdArgs
        table.insert(cmdArgs, utils.escapeBashString(self._mCURLBin))
        table.insert(cmdArgs, utils.escapeBashString(_CURL_ARG_SLIENT))
        if compressed
        then
            table.insert(cmdArgs, utils.escapeBashString(_CURL_ARG_COMPRESSED))
        end
        table.insert(cmdArgs, utils.escapeBashString(url))

        local f = io.popen(table.concat(cmdArgs, _CURL_SEP_ARGS))
        utils.clearTable(cmdArgs)
        return f
    end,


    doGET = function(self, url, compressed)
        local f = self:_doGetResponseFile(url, compressed)
        if f
        then
            local content = f:read("*a")
            f:close()
            return content
        else
            return nil
        end
    end,


    doQueuedGET = function(self, url, compressed, callback, arg)
        local f = self:_doGetResponseFile(url, compressed)
        table.insert(self._mStdoutFileQueue, f)
        table.insert(self._mCallbackQueue, callback)
        table.insert(self._mCallbackArgQueue, arg)
        return (f ~= nil)
    end,


    flush = function(self)
        local files = self._mStdoutFileQueue
        local callbacks = self._mCallbackQueue
        local callbackArgs = self._mCallbackArgQueue
        local callbackCount = #callbacks
        for i = 1, callbackCount
        do
            local f = files[i]
            local content = f and f:read("*a")
            local arg = callbackArgs[i]
            local callback = callbacks[i]

            if callback
            then
                callbacks[i](content, arg)
            end

            if f
            then
                f:close()
            end

            files[i] = nil
            callbacks[i] = nil
            callbackArgs[i] = nil
        end
    end,


    dispose = function(self)
        utils.clearTable(self)
    end,
}

utils.declareClass(CURLNetworkConnection)


return
{
    CURLNetworkConnection = CURLNetworkConnection,
}