local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _BASH_STRONG_QUOTE            = "\'"
local _BASH_ESCAPED_STRONG_QUOTE    = "'\"'\"'"

-- 从 pipes.py 抄过来的
local function __quoteShellString(text)
    text = tostring(text)
    local replaced = text:gsub(_BASH_STRONG_QUOTE, _BASH_ESCAPED_STRONG_QUOTE)
    return _BASH_STRONG_QUOTE .. replaced .. _BASH_STRONG_QUOTE
end

local function __addArgument(arguments, arg)
    if arg
    then
        local quotedArg = __quoteShellString(tostring(arg))
        table.insert(arguments, arg)
    end
end

local function __addOptionAndValue(arguments, optionName, val)
    if val
    then
        __addArgument(arguments, optionName)
        __addArgument(arguments, val)
    end
end,




local _WidgetPropertiesBase =
{
    windowTitle     = classlite.declareConstantField(nil),
    windowWidth     = classlite.declareConstantField(nil),
    windowHeight    = classlite.declareConstantField(nil),
}

classlite.declareClass(_WidgetPropertiesBase)


local EntryProperties =
{
    entryTitle      = classlite.declareConstantField(nil),  -- 提示信息
    entryText       = classlite.declareConstantField(nil),  -- 输入框内容
}

classlite.declareClass(EntryProperties, _WidgetPropertiesBase)


local ListBoxProperties =
{
    isCheckList     = classlite.declareConstantField(false),
    isHeaderHidden  = classlite.declareConstantField(false),
    listBoxTitle    = classlite.declareConstantField(nil),
    listBoxHeaders  = classlite.declareTableField(),
    listBoxTuples   = classlite.declareTableField(),
}

classlite.declareClass(ListBoxProperties, _WidgetPropertiesBase)


local _ZENITY_BIN_PATH              = "zenity"
local _ZENITY_RETURN_CODE_SUCCEED   = 0
local _ZENITY_DEFAULT_OUTPUT        = constants.STR_EMPTY
local _ZENITY_OUTPUT_SEP            = "|"
local _ZENITY_PATTERN_SPLIT_INDEXES = "(%d+)"

local ZenityGUIBuilder =
{
    __mArguments    = classlite.declareTableField(),


    __prepareWindowArguments = function(self, arguments, props)
        utils.clearTable(arguments)
        __addOptionAndValue(arguments, "--title", props.windowTitle)
        __addOptionAndValue(arguments, "--width", props.windowWidth)
        __addOptionAndValue(arguments, "--height", props.windowHeight)
    end,


    showEntry = function(self, props)
        local arguments = self.__mArguments
        self:__prepareWindowArguments(arguments, props)
        __addArgument(arguments, "--entry")
        __addArgument(arguments, "--text", props.entryTitle)
        __addArgument(arguments, "--entry-text", props.entryText)
        return --TODO
    end,


    shoeListBox = function(self, props)
        local arguments = self.__mArguments
        self:__prepareWindowArguments(arguments, props)
        __addArgument(arguments, "--list")
        __addOptionAndValue(arguments, "--text", props.listBoxTitle)
        __addArgument(arguments, props.isHeaderHidden and "--hide-header")

        local isFirstColumnDummy = false
        if props.isCheckList
        then
            __addArgument(arguments, "--checklist")
            __addArgument(arguments, "--separator")
            __addArgument(arguments, _ZENITY_OUTPUT_SEP)

            -- 第一列被用作 CheckList 了囧
            __addOptionAndValue("--column", constants.STR_EMPTY)
            isFirstColumnDummy = true
        end

        -- 加一列作为返回值
        local hiddenIDColIdx = isFirstColumnDummy and 2 or 1
        __addOptionAndValue(arguments, "--column", constants.STR_EMPTY)
        __addOptionAndValue(arguments, "--print-column", hiddenIDColIdx)
        __addOptionAndValue(arguments, "--hide-column", hiddenIDColIdx)

        -- 表头
        if types.isNilOrEmpty(props.listBoxHeaders)
        then
            for i = 1, #props.listBoxTuples[1]
            do
                __addOptionAndValue(arguments, "--column", constants.STR_EMPTY)
            end
        else
            for _, header in ipairs(props.listBoxHeaders)
            do
                __addOptionAndValue(arguments, "--column", header)
            end
        end

        -- 表格内容
        for i, tuple in ipairs(self._mListBoxTuples)
        do
            -- CheckList 列
            if isFirstColumnDummy
            then
                __addArgument(arguments, constants.STR_EMPTY)
            end

            -- 返回值列
            __addArgument(arguments, i)

            for _, e in ipairs(tuple)
            do
                __addArgument(arguments, e)
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
}

utils.declareClass(ZenityGUIBuilder)


return
{
    EntryProperties     = EntryProperties,
    ListBoxProperties   = ListBoxProperties,
    ZenityGUIBuilder    = ZenityGUIBuilder,
}