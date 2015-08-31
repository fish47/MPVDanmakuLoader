local utils = require("src/utils")          --= utils utils
local mdlapp = require("src/app")


local _APP_TITLE                            = "MPVDanmakuLoader"

local _MAIN_TEXT                            = "操作"
local _MAIN_OPTION_SEARCH_BILIBILI          = "搜索弹幕(BiliBili)"
local _MAIN_OPTION_SEARCH_DANDANPLAY        = "搜索弹幕(DanDanPlay)"
local _MAIN_OPTION_GENERATE_ASS_FILE        = "生成弹幕文件"

local _SEARCH_DDP_TEXT                      = "搜索结果"
local _SEARCH_DDP_COLUMN_INDEX              = "ID"
local _SEARCH_DDP_COLUMN_TITLE              = "标题"
local _SEARCH_DDP_COLUMN_SUBTITLE           = "子标题"


local _ZENITY_ARG_TYPE_LIST                 = "--list"
local _ZENITY_ARG_TYPE_ENTRY                = "--entry"
local _ZENITY_ARG_TYPE_PROGRESS             = "--progress"
local _ZENITY_ARG_TYPE_FILESEL              = "--file-selection"

local _ZENITY_ARG_OPT_GENERAL_TITLE         = "--title"
local _ZENITY_ARG_OPT_ENTRY_TEXT            = "--text"
local _ZENITY_ARG_OPT_ENTRY_ENTRY_TEXT      = "--entry-text"
local _ZENITY_ARG_OPT_FILESEL_SAVE          = "--save"
local _ZENITY_ARG_OPT_LIST_TEXT             = "--text"
local _ZENITY_ARG_OPT_LIST_COLUMN           = "--column"
local _ZENITY_ARG_OPT_LIST_CHECKLIST        = "--checklist"
local _ZENITY_ARG_OPT_LIST_SEPARATOR        = "--separator"
local _ZENITY_ARG_OPT_LIST_MULTIPLE         = "--multiple"
local _ZENITY_ARG_OPT_LIST_HIDE_HEADER      = "--hide-header"
local _ZENITY_ARG_OPT_LIST_PRINT_COLUMN_IDX = "--print-column"
local _ZENITY_ARG_OPT_PROGRESS_TEXT         = "--text"
local _ZENITY_ARG_OPT_PROGRESS_AUTO_CLOSE   = "--auto-close"

local _ZENITY_ARG_SEP                       = " "
local _ZENITY_ARG_OPT_LIST_COLUMN_EMPTY     = " "

local _DEFAULT_STATE_KEY                    = {}

local _EMPTY_STRING                         = ""


local ZenityShell                   =
{
    _mConfiguration                 = nil,
    _mNetworkConnection             = nil,
    _mMPVDanmakuLoaderApp           = nil,
    _mZentiyBinPath                 = nil,
    _mCommandBuf                    = nil,

    __mJumpTableMain                = nil,
    __mJumpTableSearchDanDanPlay    = nil,


    new = function(obj, zenityBin, cfg, conn)
        obj = utils.allocateInstance(obj)
        obj._mConfiguration = cfg
        obj._mNetworkConnection = conn
        obj._mZentiyBinPath = zenityBin
        obj._mCommandBuf = {}
        return obj
    end,


    setup = function(self)
        --
    end,


    _createApp = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return mdlapp.MPVDanmakuLoaderApp:new(cfg, conn)
    end,


    __onFileLoad = function(self)
        utils.disposeSafely(self._mMPVDanmakuLoaderApp)
        self._mMPVDanmakuLoaderApp = self:_createApp()
    end,


    __startZenityCommand = function(self)
        utils.clearTable(self._mCommandBuf)
        self:__addCommandlineOption(self._mZentiyBinPath)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_GENERAL_TITLE)
        self:__addCommandlineOption(_APP_TITLE)
    end,

    __addCommandlineOption = function(self, arg)
        arg = arg or _EMPTY_STRING
        table.insert(self._mCommandBuf, utils.escapeBashString(arg))
    end,

    __doExecuteCommand = function(self, writable)
        local opt = writable and "w" or "r"
        local cmdStr = table.concat(self._mCommandBuf, _ZENITY_ARG_SEP)
        return io.popen(cmdStr, opt)
    end,


    __waitForCommandFinished = function(self)
        local f = self:__doExecuteCommand(false)
        return f and f:read("*a"):sub(1, -2)
    end,


    __doJumpState = function(self, key, jumpTable)
        local func = jumpTable[key or _DEFAULT_STATE_KEY]
        if func
        then
            return func(self)
        end
    end,


    _showSearchBiliBili = function(self)
        --
    end,


    _showSearchDanDanPlay = function(self)
        --TODO 留一列给 checkbox ，注意默认 print 的是第二列(如果有 checkbox)
        self:__startZenityCommand()
        self:__addCommandlineOption(_ZENITY_ARG_TYPE_LIST)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_CHECKLIST)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_COLUMN)
        self:__addCommandlineOption(_SEARCH_DDP_COLUMN_INDEX)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_COLUMN)
        self:__addCommandlineOption(_SEARCH_DDP_COLUMN_TITLE)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_COLUMN)
        self:__addCommandlineOption(_SEARCH_DDP_COLUMN_TITLE)

        local app = self._mMPVDanmakuLoaderApp
        local results = app:searchDanDanPlayByVideoInfos()
        if results
        then
            for i, info in ipairs(results)
            do
                self:__addCommandlineOption(i)
                self:__addCommandlineOption(info.videoTitle)
                self:__addCommandlineOption(info.videoSubtitle)
            end

            local indexes = self:__waitForCommandFinished()
            print(indexes)
        end

        return self:_showMain()
    end,


    _showGenerateASSFile = function(self)
        --
    end,


    _showMain = function(self)
        self:__startZenityCommand()
        self:__addCommandlineOption(_ZENITY_ARG_TYPE_LIST)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_TEXT)
        self:__addCommandlineOption(_MAIN_TEXT)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_HIDE_HEADER)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_COLUMN)
        self:__addCommandlineOption(_ZENITY_ARG_OPT_LIST_COLUMN_EMPTY)
        self:__addCommandlineOption(_MAIN_OPTION_SEARCH_BILIBILI)
        self:__addCommandlineOption(_MAIN_OPTION_SEARCH_DANDANPLAY)
        self:__addCommandlineOption(_MAIN_OPTION_GENERATE_ASS_FILE)

        if not self.__mJumpTableMain
        then
            self.__mJumpTableMain =
            {
                [_MAIN_OPTION_SEARCH_BILIBILI]      = self._showSearchBiliBili,
                [_MAIN_OPTION_SEARCH_DANDANPLAY]    = self._showSearchDanDanPlay,
                [_MAIN_OPTION_GENERATE_ASS_FILE]    = self._showGenerateASSFile,
            }
        end

        local ret = self:__waitForCommandFinished()
        return self:__doJumpState(ret, self.__mJumpTableMain)
    end,


    dispose = function(self)
        utils.disposeSafely(self._mConfiguration)
        utils.disposeSafely(self._mNetworkConnection)
        utils.disposeSafely(self._mMPVDanmakuLoaderApp)
        utils.disposeSafely(self._mZentiyBinPath)
        utils.disposeSafely(self._mCommandBuf)
        utils.disposeSafely(self.__mJumpTableMain)
        utils.clearTable(self)
    end,
}


return
{
    ZenityShell     = ZenityShell,
}