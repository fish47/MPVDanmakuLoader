local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _SHELL_PATTERN_STARTS_WITH_DASH   = "^%-.*"
local _SHELL_CONST_DOUBLE_DASH          = "--"
local _SHELL_RETURN_CODE_SUCCEED        = 0

local function __addRawArgument(arguments, arg)
    if not types.isNil(arg)
    then
        table.insert(arguments, tostring(arg))
    end
end

local function _addOption(arguments, arg)
    __addRawArgument(arguments, arg)
end

local function _addCommand(arguments, cmd)
    __addRawArgument(arguments, cmd)
end

local function _addValue(arguments, val)
    if types.isString(val) or types.isNumber(val)
    then
        -- 标准命令行中，为了避免值与选项混淆，如果带 - 号还要加一个 -- 来转义
        val = tostring(val)
        if val:match(_SHELL_PATTERN_STARTS_WITH_DASH)
        then
            table.insert(arguments, _SHELL_CONST_DOUBLE_DASH)
        end
        table.insert(arguments, val)
    end
end

local function _addOptionAndValue(arguments, optionName, val)
    if not types.isNil(optionName) and not types.isNil(val)
    then
        _addOption(arguments, optionName)
        _addValue(arguments, val)
    end
end


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


local ProgressBarProperties ={}
classlite.declareClass(ProgressBarProperties, _WidgetPropertiesBase)


local QuestionProperties =
{
    questionText    = classlite.declareConstantField(nil),
    labelTextOK     = classlite.declareConstantField(nil),
    labelTextCancel = classlite.declareConstantField(nil),
}

classlite.declareClass(QuestionProperties, _WidgetPropertiesBase)


local _GUIBuilderBase =
{
    _mApplication   = classlite.declareConstantField(nil),

    showTextInfo        = constants.FUNC_EMPTY,
    showEntry           = constants.FUNC_EMPTY,
    showListBox         = constants.FUNC_EMPTY,
    showFileSelection   = constants.FUNC_EMPTY,
    showQuestion        = constants.FUNC_EMPTY,
    showProgressBar     = constants.FUNC_EMPTY,
    advanceProgressBar  = constants.FUNC_EMPTY,
    finishProgressBar   = constants.FUNC_EMPTY,
}

function _GUIBuilderBase:setApplication(app)
    self._mApplication = app
end

classlite.declareClass(_GUIBuilderBase)


local OVERLAY_DURATION_MESSAGE  = 3
local OVERLAY_FMT_MESSAGE       = "[%0d%%] %s"

local OverlayGUIBuilder = {}

function OverlayGUIBuilder:__updateOSDMessage(text)
    self._mApplication:setOSDMessage(text, OVERLAY_MESSAGE_DURATION_SECONDS)
end

function OverlayGUIBuilder:showProgressBar(prop)
    -- ignored
end

function OverlayGUIBuilder:advanceProgressBar(handler, percentage, message)
    local text = string.format(OVERLAY_FMT_MESSAGE, percentage, message)
    self:__updateOSDMessage(text)
end

function OverlayGUIBuilder:finishProgressBar(handler)
    self:__updateOSDMessage(constants.STR_EMPTY)
end

classlite.declareClass(OverlayGUIBuilder, _GUIBuilderBase)


local _ZENITY_RESULT_RSTRIP_COUNT       = 2
local _ZENITY_DEFAULT_OUTPUT            = constants.STR_EMPTY
local _ZENITY_SEP_LISTBOX_INDEX         = "|"
local _ZENITY_SEP_FILE_SELECTION        = "//.//"
local _ZENITY_PATTERN_SPLIT_INDEXES     = "(%d+)"

local ZenityGUIBuilder =
{
    __mArguments    = classlite.declareTableField(),
}

function ZenityGUIBuilder:__prepareZenityCommand(props)
    local app = self._mApplication
    local cfg = app and app:getConfiguration()
    local path = cfg and cfg.zenityPath
    if path
    then
        local arguments = utils.clearTable(self.__mArguments)
        _addCommand(arguments, "zenity")
        _addOptionAndValue(arguments, "--title", props.windowTitle)
        _addOptionAndValue(arguments, "--width", props.windowWidth)
        _addOptionAndValue(arguments, "--height", props.windowHeight)
        return arguments
    end
end

function ZenityGUIBuilder:__getZenityCommandResult(arguments, stdin)
    local app = self._mApplication
    if app
    then
        local retCode, output = app:executeExternalCommand(arguments, stdin)
        if retCode == _SHELL_RETURN_CODE_SUCCEED and types.isString(output)
        then
            return output:sub(1, -_ZENITY_RESULT_RSTRIP_COUNT)
        end
    end
end


function ZenityGUIBuilder:showTextInfo(props, content)
    local arguments = self:__prepareZenityCommand(props)
    if arguments
    then
        _addOption(arguments, "--text-info")
        self:__getZenityCommandResult(arguments, content)
    end
end


function ZenityGUIBuilder:showEntry(props)
    local arguments = self:__prepareZenityCommand(props)
    if arguments
    then
        _addOption(arguments, "--entry")
        _addOptionAndValue(arguments, "--text", props.entryTitle)
        _addOptionAndValue(arguments, "--entry-text", props.entryText)
        return self:__getZenityCommandResult(arguments)
    end
end


function ZenityGUIBuilder:showListBox(props, outIndexes)
    local arguments = self:__prepareZenityCommand(props)
    if not arguments
    then
        return
    end

    _addOption(arguments, "--list")
    _addOptionAndValue(arguments, "--text", props.listBoxTitle)
    _addOption(arguments, types.chooseValue(props.isHeaderHidden, "--hide-header"))

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
    local hasColumn = (columnCount > 0)
    local rowCount = hasColumn and math.ceil(tableCellCount / columnCount) or 0
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
    local resultStr = self:__getZenityCommandResult(arguments)
    if types.isNonEmptyString(resultStr) and types.isTable(outIndexes)
    then
        for idx in resultStr:gmatch(_ZENITY_PATTERN_SPLIT_INDEXES)
        do
            table.insert(outIndexes, tonumber(idx))
        end
    end

    return types.isNonEmptyTable(outIndexes)
end


function ZenityGUIBuilder:showFileSelection(props, outPaths)
    local arguments = self:__prepareZenityCommand(props)
    if not arguments
    then
        return
    end

    _addOption(arguments, "--file-selection")
    _addOptionAndValue(arguments, "--separator", _ZENITY_SEP_FILE_SELECTION)
    _addOption(arguments, types.chooseValue(props.isMultiSelectable, "--multiple"))
    _addOption(arguments, types.chooseValue(props.isDirectoryOnly, "--directory"))

    utils.clearTable(outPaths)
    local resultStr = self:__getZenityCommandResult(arguments)
    if types.isNilOrEmptyString(resultStr)
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
    return types.isNonEmptyTable(outPaths)
end


function ZenityGUIBuilder:showQuestion(props)
    local arguments = self:__prepareZenityCommand(props)
    _addOption(arguments, "--question")
    _addOptionAndValue(arguments, "--text", props.questionText)
    _addOptionAndValue(arguments, "--ok-label", props.labelTextOK)
    _addOptionAndValue(arguments, "--cancel-label", props.labelTextCancel)
    return self:__getZenityCommandResult(arguments)
end

classlite.declareClass(ZenityGUIBuilder, _GUIBuilderBase)


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