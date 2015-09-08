local utils = require("src/utils")          --= utils utils


local _ZENITY_OUTPUT_SEP            = "|"
local _ZENITY_PATTERN_SPLIT_INDEXES = "(%d+)"

local _ZENITY_UI_TYPE_LIST          = 0
local _ZENITY_UI_TYPE_ENTRY         = 1


local ZenityGUIBuilder =
{
    _mZentiyBinPath     = nil,
    _mCmdBuilder        = nil,

    _mUIType            = nil,
    _mWindowTitle       = nil,

    _mEntryTitle        = nil,
    _mEntryEntry        = nil,

    _mIsCheckList       = nil,
    _mIsHeaderVisible   = nil,
    _mListBoxTitle      = nil,
    _mListBoxHeaders    = nil,
    _mListBoxTuples     = nil,


    new = function(obj, zenityBin)
        obj = utils.allocateInstance(obj)
        obj._mZentiyBinPath = zenityBin
        obj._mCmdBuilder = utils.CommandlineBuilder:new()
        obj._mListBoxTuples = {}
        obj:reset()
        return obj
    end,

    dispose = function(self)
        utils.disposeSafely(self._mCmdBuilder)
        utils.clearTable(self._mListBoxTuples)
        utils.clearTable(self)
    end,

    reset = function(self)
        self._mUIType = nil
        self._mWindowTitle = nil

        self._mIsCheckList = false
        self._mIsHeaderVisible = true
        self._mListBoxHeaders = nil
        utils.clearTable(self._mListBoxTuples)
    end,

    setWindowTitle = function(self, title)
        self._mWindowTitle = title
    end,

    createEntry = function(self)
        self._mUIType = _ZENITY_UI_TYPE_ENTRY
    end,

    createListBox = function(self, isMulSel)
        self._mUIType = _ZENITY_UI_TYPE_LIST
        self._mIsCheckList = isMulSel
    end,

    setListBoxHeaderVisible = function(self, val)
        self._mIsHeaderVisible = val
    end,

    setListBoxHeaders = function(self, ...)
        self._mListBoxHeaders = { ... }
    end,

    setListBoxTitle = function(self, title)
        self._mListBoxTitle = title
    end,

    addListBoxTuple = function(self, ...)
        table.insert(self._mListBoxTuples, { ... })
    end,



    __doBuildZenityCommand = function(self)
        local cmdBuilder = self._mCmdBuilder
        cmdBuilder:startCommand(self._mZentiyBinPath)

        if self._mWindowTitle
        then
            cmdBuilder:addArgument("--title")
            cmdBuilder:addArgument(self._mWindowTitle)
        end

        if self._mUIType == _ZENITY_UI_TYPE_LIST
        then
            cmdBuilder:addArgument("--list")

            if self._mListBoxTitle
            then
                cmdBuilder:addArgument("--text")
                cmdBuilder:addArgument(self._mListBoxTitle)
            end

            if not self._mIsHeaderVisible
            then
                cmdBuilder:addArgument("--hide-header")
            end

            local isFirstColumnDummy = false
            if self._mIsCheckList
            then
                cmdBuilder:addArgument("--checklist")
                cmdBuilder:addArgument("--separator")
                cmdBuilder:addArgument(_ZENITY_OUTPUT_SEP)

                -- 第一列被用作 CheckList 了囧
                cmdBuilder:addArgument("--column")
                cmdBuilder:addArgument("")
            end

            -- 加一列作为返回值
            local hiddenIDColIdx = isFirstColumnDummy and 2 or 1
            cmdBuilder:addArgument("--column")
            cmdBuilder:addArgument("")
            cmdBuilder:addArgument("--print-column")
            cmdBuilder:addArgument(hiddenIDColIdx)
            cmdBuilder:addArgument("--hide-column")
            cmdBuilder:addArgument(hiddenIDColIdx)

            if self._mListBoxHeaders
            then
                for _, header in ipairs(self._mListBoxHeaders)
                do
                    cmdBuilder:addArgument("--column")
                    cmdBuilder:addArgument(header)
                end
            else
                -- 有可能不写表头名
                local columnCount = #self._mListBoxTuples[1]
                for i = 1, columnCount
                do
                    cmdBuilder:addArgument("--column")
                    cmdBuilder:addArgument("")
                end
            end

            for i, tuple in ipairs(self._mListBoxTuples)
            do
                -- 就是 CheckList 那一列囧
                if isFirstColumnDummy
                then
                    cmdBuilder:addArgument("")
                end

                -- 返回值
                cmdBuilder:addArgument(i)

                for _, e in ipairs(tuple)
                do
                    cmdBuilder:addArgument(e)
                end
            end
        elseif self._mUIType == _ZENITY_UI_TYPE_ENTRY
        then

        end

        return cmdBuilder
    end,


    show = function(self)
        local cmdBuilder = self:__doBuildZenityCommand()
        local output = cmdBuilder:executeAndWait()
        if self._mUIType == _ZENITY_UI_TYPE_LIST
        then
            local indexes = nil
            if output
            then
                for idx in output:gmatch(_ZENITY_PATTERN_SPLIT_INDEXES)
                do
                    indexes = indexes or {}
                    table.insert(indexes, tonumber(idx))
                end
            end
            return indexes
        end
    end,
}

utils.declareClass(ZenityGUIBuilder)


return
{
    ZenityGUIBuilder    = ZenityGUIBuilder,
}