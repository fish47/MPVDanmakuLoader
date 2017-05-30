local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _WidgetPropertiesBase =
{
    windowTitle     = classlite.declareConstantField(nil),
    windowWidth     = classlite.declareConstantField(nil),
    windowHeight    = classlite.declareConstantField(nil),
}

classlite.declareClass(_WidgetPropertiesBase)


local TextInfoProperties = {}
classlite.declareClass(TextInfoProperties, _WidgetPropertiesBase)


local EntryProperties =
{
    entryTitle      = classlite.declareConstantField(nil),  -- 提示信息
    entryText       = classlite.declareConstantField(nil),  -- 输入框内容
}

classlite.declareClass(EntryProperties, _WidgetPropertiesBase)


local ListBoxProperties =
{
    isMultiSelectable   = classlite.declareConstantField(false),
    isHeaderHidden      = classlite.declareConstantField(false),
    listBoxTitle        = classlite.declareConstantField(nil),
    listBoxColumnCount  = classlite.declareConstantField(0),
    listBoxHeaders      = classlite.declareTableField(),
    listBoxElements     = classlite.declareTableField(),
}

classlite.declareClass(ListBoxProperties, _WidgetPropertiesBase)


local FileSelectionProperties =
{
    isMultiSelectable   = classlite.declareConstantField(false),
    isDirectoryOnly     = classlite.declareConstantField(false),
}

classlite.declareClass(FileSelectionProperties, _WidgetPropertiesBase)


local ProgressBarProperties =
{
    isAutoClose     = classlite.declareConstantField(false),
}

classlite.declareClass(ProgressBarProperties, _WidgetPropertiesBase)


local QuestionProperties =
{
    questionText    = classlite.declareConstantField(nil),
    labelTextOK     = classlite.declareConstantField(nil),
    labelTextCancel = classlite.declareConstantField(nil),
}

classlite.declareClass(QuestionProperties, _WidgetPropertiesBase)


local _ZENITY_RESULT_RSTRIP_COUNT       = 2
local _ZENITY_DEFAULT_OUTPUT            = constants.STR_EMPTY
local _ZENITY_SEP_LISTBOX_INDEX         = "|"
local _ZENITY_SEP_FILE_SELECTION        = "//.//"
local _ZENITY_PATTERN_SPLIT_INDEXES     = "(%d+)"
local _ZENITY_PREFFIX_PROGRESS_MESSAGE  = "# "

local ZenityGUIBuilder =
{
    __mArguments    = classlite.declareTableField(),

    __prepareZenityCommand = function(self, arguments, props)
        utils.clearTable(arguments)
        _addCommand(arguments, "zenity")
        _addOptionAndValue(arguments, "--title", props.windowTitle)
        _addOptionAndValue(arguments, "--width", props.windowWidth)
        _addOptionAndValue(arguments, "--height", props.windowHeight)
    end,

    _getZenityCommandResult = function(self, arguments)
        _addSyntax(arguments, _SHELL_SYNTAX_NO_STDERR)
        local succeed, output = _getCommandResult(arguments)
        return succeed and output:sub(1, -_ZENITY_RESULT_RSTRIP_COUNT)
    end,


    showTextInfo = function(self, props, content)
        local arguments = self.__mArguments
        self:__prepareZenityCommand(arguments, props)
        _addOption(arguments, "--text-info")
        _addOption(arguments, _SHELL_SYNTAX_NO_STDERR)

        local cmdStr = _getCommandString(arguments)
        local f = io.popen(cmdStr, constants.FILE_MODE_WRITE_ERASE)
        utils.clearTable(arguments)
        f:write(content)
        utils.readAndCloseFile(f)
    end,


    showEntry = function(self, props)
        local arguments = self.__mArguments
        self:__prepareZenityCommand(arguments, props)
        _addOption(arguments, "--entry")
        _addOptionAndValue(arguments, "--text", props.entryTitle)
        _addOptionAndValue(arguments, "--entry-text", props.entryText)
        return self:_getZenityCommandResult(arguments)
    end,


    showListBox = function(self, props, outIndexes)
        local arguments = self.__mArguments
        self:__prepareZenityCommand(arguments, props)
        _addOption(arguments, "--list")
        _addOptionAndValue(arguments, "--text", props.listBoxTitle)
        _addOption(arguments, props.isHeaderHidden and "--hide-header")

        local isFirstColumnDummy = false
        if props.isMultiSelectable
        then
            _addOption(arguments, "--checklist")
            _addOptionAndValue(arguments, "--separator", _ZENITY_SEP_LISTBOX_INDEX)

            -- 第一列被用作 CheckList 了囧
            _addOptionAndValue(arguments, "--column", constants.STR_EMPTY)
            isFirstColumnDummy = true
        end

        -- 加一列作为返回值
        local hiddenIDColIdx = 1 + types.toZeroOrOne(isFirstColumnDummy)
        _addOptionAndValue(arguments, "--column", constants.STR_EMPTY)
        _addOptionAndValue(arguments, "--print-column", hiddenIDColIdx)
        _addOptionAndValue(arguments, "--hide-column", hiddenIDColIdx)

        -- 表头
        local columnCount = props.listBoxColumnCount
        local hasHeader = (not types.isEmptyTable(props.listBoxHeaders))
        for i = 1, columnCount
        do
            local header = hasHeader and props.listBoxHeaders[i] or constants.STR_EMPTY
            _addOptionAndValue(arguments, "--column", header)
        end

        -- 表格内容
        local tableCellCount = #props.listBoxElements
        local rowCount = (columnCount > 0) and math.ceil(tableCellCount / columnCount) or 0
        for i = 1, rowCount
        do
            -- CheckList 列
            if isFirstColumnDummy
            then
                _addValue(arguments, constants.STR_EMPTY)
            end

            -- 返回值列
            _addValue(arguments, i)

            for j = 1, columnCount
            do
                local idx = (i - 1) * columnCount + j
                local element = props.listBoxElements[idx]
                element = element and element or constants.STR_EMPTY
                _addValue(arguments, element)
            end
        end

        -- 返回点击的行索引
        utils.clearTable(outIndexes)
        local resultStr = self:_getZenityCommandResult(arguments)
        if not types.isNilOrEmpty(resultStr) and types.isTable(outIndexes)
        then
            for idx in resultStr:gmatch(_ZENITY_PATTERN_SPLIT_INDEXES)
            do
                table.insert(outIndexes, tonumber(idx))
            end
        end

        return not types.isEmptyTable(outIndexes)
    end,


    showFileSelection = function(self, props, outPaths)
        local arguments = self.__mArguments
        self:__prepareZenityCommand(arguments, props)
        _addOption(arguments, "--file-selection")
        _addOptionAndValue(arguments, "--separator", _ZENITY_SEP_FILE_SELECTION)
        _addOption(arguments, props.isMultiSelectable and "--multiple")
        _addOption(arguments, props.isDirectoryOnly and "--directory")

        utils.clearTable(outPaths)
        local resultStr = self:_getZenityCommandResult(arguments)
        if types.isNilOrEmpty(resultStr)
        then
            return
        end

        local startIdx = 1
        local endIdx = resultStr:len()
        while startIdx <= endIdx
        do
            local sepIdx = resultStr:find(_ZENITY_SEP_FILE_SELECTION, startIdx, true)
            local pathEndIdx = sepIdx and sepIdx - 1 or endIdx
            if startIdx <= pathEndIdx
            then
                table.insert(outPaths, resultStr:sub(startIdx, pathEndIdx))
            end

            startIdx = pathEndIdx + #_ZENITY_SEP_FILE_SELECTION + 1
        end

        return not types.isEmptyTable(outPaths)
    end,


    showProgressBar = function(self, props)
        local arguments = self.__mArguments
        self:__prepareZenityCommand(arguments, props)
        _addOption(arguments, "--progress")
        _addOption(arguments, props.isAutoClose and "--auto-close")
        _addSyntax(arguments, _SHELL_SYNTAX_NO_STDERR)

        local cmdStr = _getCommandString(arguments)
        local handler = io.popen(cmdStr, constants.FILE_MODE_WRITE_ERASE)
        utils.clearTable(arguments)
        return handler
    end,


    advanceProgressBar = function(self, handler, percentage, message)
        if types.isOpenedFile(handler) and percentage > 0
        then
            -- 进度
            handler:write(tostring(math.floor(percentage)))
            handler:write(constants.STR_NEWLINE)

            -- 提示字符
            if types.isString(message)
            then
                handler:write(_ZENITY_PREFFIX_PROGRESS_MESSAGE)
                handler:write(message)
                handler:write(constants.STR_NEWLINE)
            end

            handler:flush()
        end
    end,

    finishProgressBar = function(self, handler)
        utils.readAndCloseFile(handler)
    end,

    showQuestion = function(self, props)
        local arguments = self.__mArguments
        self:__prepareZenityCommand(arguments, props)
        _addOption(arguments, "--question")
        _addOptionAndValue(arguments, "--text", props.questionText)
        _addOptionAndValue(arguments, "--ok-label", props.labelTextOK)
        _addOptionAndValue(arguments, "--cancel-label", props.labelTextCancel)
        return self:_getZenityCommandResult(arguments)
    end,
}

classlite.declareClass(ZenityGUIBuilder)


return
{
    TextInfoProperties          = TextInfoProperties,
    EntryProperties             = EntryProperties,
    ListBoxProperties           = ListBoxProperties,
    FileSelectionProperties     = FileSelectionProperties,
    ProgressBarProperties       = ProgressBarProperties,
    QuestionProperties          = QuestionProperties,

    ZenityGUIBuilder            = ZenityGUIBuilder,
}