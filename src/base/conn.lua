local cmd       = require("src/base/cmd")
local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")


local _CURL_ARG_SLIENT                  = "--silent"
local _CURL_ARG_COMPRESSED              = "--compressed"
local _CURL_ARG_MAX_TIME                = "--max-time"
local _CURL_ARG_ADD_HEADER              = "-H"
local _CURL_SEP_ARGS                    = " "
local _CURL_DEFAULT_TIMEOUT_SECONDS     = 3

local CURLNetworkConnection =
{
    _mCURLBinPath       = classlite.declareConstantField(nil),
    _mCmdBuilder        = classlite.declareClassField(cmd.CommandlineBuilder),
    _mTimeOutSeconds    = classlite.declareConstantField(_CURL_DEFAULT_TIMEOUT_SECONDS),
    _mIsCompressed      = classlite.declareConstantField(false),
    _mHeaders           = classlite.declareTableField(),
    _mCallbacks         = classlite.declareTableField(),
    _mCallbackArgs      = classlite.declareTableField(),
    _mStdoutFiles       = classlite.declareTableField(),

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
        cmdBuilder:addArgument(self._mIsCompressed and "--compressed")

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
}

classlite.declareClass(CURLNetworkConnection)


return
{
    CURLNetworkConnection = CURLNetworkConnection,
}