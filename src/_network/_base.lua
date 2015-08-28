local utils = require("src/utils")      --= utils utils


local _CURL_ARG_SLIENT                  = "--silent"
local _CURL_ARG_COMPRESSED              = "--compressed"
local _CURL_ARG_MAX_TIME                = "--max-time"
local _CURL_ARG_ADD_HEADER              = "-H"
local _CURL_SEP_ARGS                    = " "
local _CURL_DEFAULT_TIMEOUT_SECONDS     = 3

local CURLNetworkConnection =
{
    _mCURLBin           = nil,
    _mCmdArgs           = nil,
    _mCallbacks         = nil,
    _mCallbackArgs      = nil,
    _mStdoutFiles       = nil,

    _mCompressed        = nil,
    _mTimeOutSeconds    = nil,
    _mHeaders           = nil,


    new = function(obj, curlBin, timeOutSec)
        obj = utils.allocateInstance(obj)
        obj._mCURLBin = curlBin
        obj._mCmdArgs = {}
        obj._mCallbacks = {}
        obj._mCallbackArgs = {}
        obj._mStdoutFiles = {}
        obj._mTimeOutSeconds = tostring(timeOutSec or _CURL_DEFAULT_TIMEOUT_SECONDS)
        obj._mHeaders = {}
        obj:resetParams()
        return obj
    end,


    resetParams = function(self)
        self._mCompressed = false
        utils.clearTable(self._mHeaders)
    end,


    setCompressed = function(self, val)
        self._mCompressed = val
    end,

    addHeader = function(self, val)
        table.insert(self._mHeaders, val)
    end,

    __doAddCmdArg = function(self, arg)
        local escaped = utils.escapeBashString(arg)
        table.insert(self._mCmdArgs, escaped)
    end,


    _doGetResponseFile = function(self, url)
        self:__doAddCmdArg(self._mCURLBin)
        self:__doAddCmdArg(_CURL_ARG_SLIENT)
        self:__doAddCmdArg(_CURL_ARG_MAX_TIME)
        self:__doAddCmdArg(self._mTimeOutSeconds)
        if self._mCompressed
        then
            self:__doAddCmdArg(_CURL_ARG_COMPRESSED)
        end

        for _, header in ipairs(self._mHeaders)
        do
            self:__doAddCmdArg(_CURL_ARG_ADD_HEADER)
            self:__doAddCmdArg(header)
        end

        self:__doAddCmdArg(url)

        local cmdArgs = self._mCmdArgs
        local f = io.popen(table.concat(cmdArgs, _CURL_SEP_ARGS))
        utils.clearTable(cmdArgs)
        return f
    end,


    doGET = function(self, url)
        local f = self:_doGetResponseFile(url)
        if f
        then
            local content = f:read("*a")
            f:close()
            return content
        else
            return nil
        end
    end,


    doQueuedGET = function(self, url, callback, arg)
        local f = self:_doGetResponseFile(url)
        table.insert(self._mStdoutFiles, f)
        table.insert(self._mCallbacks, callback)
        table.insert(self._mCallbackArgs, arg)
        return (f ~= nil)
    end,


    flush = function(self)
        local files = self._mStdoutFiles
        local callbacks = self._mCallbacks
        local callbackArgs = self._mCallbackArgs
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
        utils.clearTable(self._mCmdArgs)
        utils.clearTable(self._mCallbacks)
        utils.clearTable(self._mCallbackArgs)
        utils.clearTable(self._mStdoutFiles)
        utils.clearTable(self._mHeaders)
        utils.clearTable(self)
    end,
}

utils.declareClass(CURLNetworkConnection)


return
{
    CURLNetworkConnection = CURLNetworkConnection,
}