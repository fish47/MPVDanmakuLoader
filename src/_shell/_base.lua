local utils = require("src/utils")          --= utils utils


local _UI_TYPE_LIST     = 0
local _UI_TYPE_ENTRY    = 1

local __GUIBuilderBase  =
{
    _mUIType            = nil,
    _mWindowTitle       = nil,
    _mWindowWidth       = nil,
    _mWindowHeight      = nil,

    _mEntryTitle        = nil,
    _mEntryText         = nil,

    _mIsCheckList       = nil,
    _mIsHeaderVisible   = nil,
    _mListBoxTitle      = nil,
    _mListBoxHeaders    = nil,
    _mListBoxTuples     = nil,

    new = function(obj)
        obj = utils.allocateInstance(obj)
        obj._mListBoxTuples = {}
        obj:reset()
        return obj
    end,

    dispose = function(self)
        utils.clearTable(self._mListBoxTuples)
        utils.clearTable(self)
    end,

    reset = function(self)
        self._mUIType = nil
        self._mWindowTitle = nil
        self._mWindowWidth = nil
        self._mWindowHeight = nil

        self._mEntryText = nil
        self._mEntryTitle = nil

        self._mIsCheckList = false
        self._mIsHeaderVisible = true
        self._mListBoxHeaders = nil
        utils.clearTable(self._mListBoxTuples)
    end,

    setWindowTitle = function(self, title)
        self._mWindowTitle = title
    end,

    setWindowWidth = function(self, width)
        self._mWindowWidth = width
    end,

    setWindowHeight = function(self, height)
        self._mWindowHeight = height
    end,

    createEntry = function(self)
        self._mUIType = _UI_TYPE_ENTRY
    end,

    setEntryTitle = function(self, title)
        self._mEntryTitle = title
    end,

    setEntryText = function(self, text)
        self._mEntryText = text
    end,

    createListBox = function(self, isMulSel)
        self._mUIType = _UI_TYPE_LIST
    end,

    setListBoxMultiSelectable = function(self, val)
        self._mIsCheckList = val
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

    show = utils.METHOD_NOT_IMPLEMENTED,
}

utils.declareClass(__GUIBuilderBase)



local _ZENITY_RETURN_CODE_SUCCEED   = 0
local _ZENITY_DEFAULT_OUTPUT        = ""
local _ZENITY_OUTPUT_SEP            = "|"
local _ZENITY_PATTERN_SPLIT_INDEXES = "(%d+)"

local ZenityGUIBuilder =
{
    _mZentiyBinPath     = nil,
    __mCmdBuilder       = nil,


    new = function(obj, zenityBin)
        obj = utils.allocateInstance(obj)
        __GUIBuilderBase.new(obj)
        obj._mZentiyBinPath = zenityBin
        obj.__mCmdBuilder = utils.CommandlineBuilder:new()
        return obj
    end,

    dispose = function(self)
        utils.disposeSafely(self.__mCmdBuilder)
        __GUIBuilderBase.dispose(self)
    end,


    _buildListBoxCommand = function(self, cmdBuilder)
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

            isFirstColumnDummy = true
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
            -- CheckList 列
            if isFirstColumnDummy
            then
                cmdBuilder:addArgument("")
            end

            -- 返回值列
            cmdBuilder:addArgument(i)

            for _, e in ipairs(tuple)
            do
                cmdBuilder:addArgument(e)
            end
        end
    end,


    _getListBoxResult = function(self, output, succeed, retCode)
        local indexes = nil
        if succeed and retCode == _ZENITY_RETURN_CODE_SUCCEED
            then
            for idx in output:gmatch(_ZENITY_PATTERN_SPLIT_INDEXES)
            do
                indexes = indexes or {}
                table.insert(indexes, tonumber(idx))
            end
        end
        return indexes
    end,


    _buildEntryCommand = function(self, cmdBuilder)
        cmdBuilder:addArgument("--entry")

        -- 提示
        local title = self._mEntryTitle
        if title
        then
            cmdBuilder:addArgument("--text")
            cmdBuilder:addArgument(title)
        end

        -- 输入框内容
        local entry = self._mEntryText
        if entry
        then
            cmdBuilder:addArgument("--entry-text")
            cmdBuilder:addArgument(self._mEntryText)
        end
    end,


    _getEntryResult = function(self, output, succeed, retCode)
        local ret = nil
        if succeed and retCode == _ZENITY_RETURN_CODE_SUCCEED
        then
            ret = output or _ZENITY_DEFAULT_OUTPUT
        end
        return ret
    end,


    _prepareWindowArguments = function(self, cmdBuilder)
        if self._mWindowTitle
        then
            cmdBuilder:addArgument("--title")
            cmdBuilder:addArgument(self._mWindowTitle)
        end

        if self._mWindowWidth
        then
            cmdBuilder:addArgument("--width")
            cmdBuilder:addArgument(self._mWindowWidth)
        end

        if self._mWindowHeight
        then
            cmdBuilder:addArgument("--height")
            cmdBuilder:addArgument(self._mWindowHeight)
        end
    end,


    show = function(self)
        local buildCmdFunc = nil
        local getResultFunc = nil
        local uiType = self._mUIType
        if uiType == _UI_TYPE_LIST
        then
            buildCmdFunc = self._buildListBoxCommand
            getResultFunc = self._getListBoxResult
        elseif uiType == _UI_TYPE_ENTRY
        then
            buildCmdFunc = self._buildEntryCommand
            getResultFunc = self._getEntryResult
        else
            return nil
        end

        -- 先处理一些类型无关的参数
        local cmdBuilder = self.__mCmdBuilder
        cmdBuilder:startCommand(self._mZentiyBinPath)
        self:_prepareWindowArguments(cmdBuilder)

        buildCmdFunc(self, cmdBuilder)
        local output, succeed, retCode = cmdBuilder:executeAndWait()
        return getResultFunc(self, output, succeed, retCode)
    end,
}

utils.declareClass(ZenityGUIBuilder, __GUIBuilderBase)


return
{
    ZenityGUIBuilder    = ZenityGUIBuilder,
}