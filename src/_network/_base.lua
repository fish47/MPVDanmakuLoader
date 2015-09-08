local utils = require("src/utils")      --= utils utils


local _CURL_ARG_SLIENT                  = "--silent"
local _CURL_ARG_COMPRESSED              = "--compressed"
local _CURL_ARG_MAX_TIME                = "--max-time"
local _CURL_ARG_ADD_HEADER              = "-H"
local _CURL_SEP_ARGS                    = " "
local _CURL_DEFAULT_TIMEOUT_SECONDS     = 3

local CURLNetworkConnection =
{
    _mCURLBinPath           = nil,
    _mCmdBuilder        = nil,
    _mTimeOutSeconds    = nil,
    _mIsCompressed      = nil,
    _mHeaders           = nil,
    _mCallbacks         = nil,
    _mCallbackArgs      = nil,
    _mStdoutFiles       = nil,


    new = function(obj, curlBin, timeOutSec)
        obj = utils.allocateInstance(obj)
        obj._mCURLBinPath = curlBin
        obj._mCmdBuilder = utils.CommandlineBuilder:new()
        obj._mTimeOutSeconds = timeOutSec or _CURL_DEFAULT_TIMEOUT_SECONDS
        obj._mHeaders = {}
        obj._mCallbacks = {}
        obj._mCallbackArgs = {}
        obj._mStdoutFiles = {}
        obj:resetParams()
        return obj
    end,

    resetParams = function(self)
        self._mIsCompressed = false
        utils.clearTable(self._mHeaders)
    end,

    setCompressed = function(self, val)
        self._mIsCompressed = val
    end,

    addHeader = function(self, val)
        table.insert(self._mHeaders, val)
    end,


    __doBuildCURLCommand = function(self, url)
        local cmdBuilder = self._mCmdBuilder
        cmdBuilder:startCommand(self._mCURLBinPath)
        cmdBuilder:addArgument("--silent")
        cmdBuilder:addArgument("--max-time")
        cmdBuilder:addArgument(self._mTimeOutSeconds)

        if self._mIsCompressed
        then
            cmdBuilder:addArgument("--compressed")
        end

        for _, header in ipairs(self._mHeaders)
        do
            cmdBuilder:addArgument("-H")
            cmdBuilder:addArgument(header)
        end

        return cmdBuilder
    end,


    doGET = function(self, url)
        local cmdBuilder = self:__doBuildCURLCommand(url)
        return cmdBuilder:executeAndWait()
    end,


    doQueuedGET = function(self, url, callback, arg)
        local cmdBuilder = self:__doBuildCURLCommand(url)
        local f = cmdBuilder:execute()
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
            local content = utils.readAndCloseFile(f)
            local arg = callbackArgs[i]
            local callback = callbacks[i]

            if callback
            then
                callbacks[i](content, arg)
            end

            files[i] = nil
            callbacks[i] = nil
            callbackArgs[i] = nil
        end
    end,


    dispose = function(self)
        utils.disposeSafely(self._mCmdBuilder)
        utils.clearTable(self._mHeaders)
        utils.clearTable(self._mCallbacks)
        utils.clearTable(self._mCallbackArgs)
        utils.clearTable(self._mStdoutFiles)
        utils.clearTable(self)
    end,
}

utils.declareClass(CURLNetworkConnection)


return
{
    CURLNetworkConnection = CURLNetworkConnection,
}