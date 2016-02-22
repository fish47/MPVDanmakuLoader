local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _SHELL_SYNTAX_PIPE_STDOUT_TO_INPUT        = "|"
local _SHELL_SYNTAX_REDIRECT_STRING_TO_INPUT    = "<<<"
local _SHELL_SYNTAX_ARGUMENT_SEP                = " "
local _SHELL_SYNTAX_STRONG_QUOTE                = "\'"
local _SHELL_SYNTAX_NO_STDERR                   = "2>/dev/null"

local _SHELL_CONST_STRONG_QUOTE_ESCAPED         = "'\"'\"'"
local _SHELL_CONST_DOUBLE_DASH                  = "--"
local _SHELL_CONST_RETURN_CODE_SUCCEED          = 0

local _SHELL_PATTERN_STARTS_WITH_DASH           = "^%-"


-- 从 pipes.py 抄过来的
local function __quoteShellString(text)
    text = tostring(text)
    local replaced = text:gsub(_SHELL_SYNTAX_STRONG_QUOTE,
                               _SHELL_CONST_STRONG_QUOTE_ESCAPED)
    return _SHELL_SYNTAX_STRONG_QUOTE
           .. replaced
           .. _SHELL_SYNTAX_STRONG_QUOTE
end


local function __addRawArgument(arguments, arg)
    -- 排除 boolean 是因为懒得写 "cond and true_val or nil"
    -- 而且类似 --arg true 参数也很少见
    if types.isString(arg) or types.isNumber(arg)
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

local function _addSyntax(arguments, syntax)
    __addRawArgument(arguments, syntax)
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
        table.insert(arguments, __quoteShellString(val))
    end
end

local function _addOptionAndValue(arguments, optionName, val)
    if optionName ~= nil and val ~= nil
    then
        _addOption(arguments, optionName)
        _addValue(arguments, val)
    end
end

local function _getCommandString(arguments)
    return table.concat(arguments, _SHELL_SYNTAX_ARGUMENT_SEP)
end

local function _getCommandResult(arguments, expectedRetCode)
    expectedRetCode = expectedRetCode or _SHELL_CONST_RETURN_CODE_SUCCEED
    local popenFile = io.popen(_getCommandString(arguments))
    local output, succeed, reason, retCode = utils.readAndCloseFile(popenFile)
    local ret = succeed
                and reason == constants.EXEC_RET_EXIT
                and retCode == expectedRetCode
    return ret, output
end


local _PATH_SEPERATOR                   = "/"
local _PATH_ROOT_DIR                    = "/"
local _PATH_CURRENT_DIR                 = "."
local _PATH_PARENT_DIR                  = ".."
local _PATH_PATTERN_ELEMENT             = "[^/]+"
local _PATH_PATTERN_STARTS_WITH_ROOT    = "^/"
local _PATH_PATTERN_ROOT                = "^/+$"

local function __splitPathElements(fullPath)
    if not types.isString(fullPath)
    then
        return nil
    end

    local paths = utils._obtainTable()
    if fullPath:match(_PATH_PATTERN_ROOT)
    then
        table.insert(paths, _PATH_ROOT_DIR)
        return paths
    end

    local hasRoot = fullPath:match(_PATH_PATTERN_STARTS_WITH_ROOT)
    for path in fullPath:gmatch(_PATH_PATTERN_ELEMENT)
    do
        if path == _PATH_PARENT_DIR
        then
            paths[math.max(#paths, 1)] = nil
        elseif path == _PATH_CURRENT_DIR
        then
            -- 指向当前文件夹
        else
            -- 将 / 作为单独的路径
            if hasRoot and types.isEmptyTable(paths)
            then
                table.insert(paths, _PATH_ROOT_DIR)
            end

            table.insert(paths, path)
        end
    end
    return paths
end


local function __joinPathElements(paths)
    local ret = nil
    if paths[1] == _PATH_ROOT_DIR
    then
        local trailing = table.concat(paths, _PATH_SEPERATOR, 2)
        ret = _PATH_ROOT_DIR .. trailing
    else
        ret = table.concat(paths, _PATH_SEPERATOR)
    end
    utils._recycleTable(paths)
    return ret
end


local function __doIteratePathElements(paths, idx)
    idx = idx + 1
    if idx > #paths
    then
        -- 如果是中途 break 出来，就让虚拟机回收吧
        utils._recycleTable(paths)
        return nil
    else
        return idx, paths[idx]
    end
end

local function iteratePathElements(fullPath)
    local paths = __splitPathElements(fullPath)
    return __doIteratePathElements, paths, 0
end


local function normalizePath(fullPath)
    local paths = __splitPathElements(fullPath)
    return paths and __joinPathElements(paths)
end

local function joinPath(dirName, pathName)
    local paths1 = __splitPathElements(dirName)
    local paths2 = __splitPathElements(pathName)
    if paths1 and paths2
    then
        utils.appendArrayElements(paths1, paths2)
        local ret = __joinPathElements(paths1)
        utils._recycleTable(paths2)
        return ret
    else
        utils._recycleTable(paths1)
        utils._recycleTable(paths2)
    end
end

local function splitPath(fullPath)
    local paths = __splitPathElements(fullPath)
    if paths
    then
        local baseName = utils.popArrayElement(paths)
        local dirName = __joinPathElements(paths)
        return dirName, baseName
    end
end


local _WidgetPropertiesBase =
{
    windowTitle     = classlite.declareConstantField(nil),
    windowWidth     = classlite.declareConstantField(nil),
    windowHeight    = classlite.declareConstantField(nil),
}

classlite.declareClass(_WidgetPropertiesBase)


local TextInfoProperties =
{
    textInfoContent = classlite.declareConstantField(nil),
}
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


local _ZENITY_RESULT_RSTRIP_COUNT   = 2
local _ZENITY_DEFAULT_OUTPUT        = constants.STR_EMPTY
local _ZENITY_SEP_LISTBOX_INDEX     = "|"
local _ZENITY_SEP_FILE_SELECTION    = "//.//"
local _ZENITY_PATTERN_SPLIT_INDEXES = "(%d+)"

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

    showTextInfo = function(self, props)
        local arguments = self.__mArguments
        self:__prepareZenityCommand(arguments, props)
        _addOption(arguments, "--text-info")
        _addSyntax(arguments, _SHELL_SYNTAX_REDIRECT_STRING_TO_INPUT)
        _addValue(arguments, props.textInfoContent)
        return self:_getZenityCommandResult(arguments)
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
        local hiddenIDColIdx = 1 + types.toNumber(isFirstColumnDummy)
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
                element = element ~= nil and element or constants.STR_EMPTY
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

        return types.isEmptyTable(outPaths)
    end,
}

classlite.declareClass(ZenityGUIBuilder)


local _NetworkConnectionBase =
{
    _mIsCompressed      = classlite.declareConstantField(false),
    _mHeaders           = classlite.declareTableField(),
    _mCallbacks         = classlite.declareTableField(),
    _mCallbackArgs      = classlite.declareTableField(),
    _mConnections       = classlite.declareTableField(),
    _mTimeoutSeconds    = classlite.declareConstantField(nil),

    _createConnection = constants.FUNC_EMPTY,
    _readConnection = constants.FUNC_EMPTY,

    setTimeout = function(self, timeout)
        self._mTimeoutSeconds = types.isNumber(timeout) and timeout
    end,

    receive = function(self, url)
        if types.isString(url)
        then
            local succeed, conn = self:_createConnection(url)
            local content = succeed and self:_readConnection(conn)
            return content
        end
    end,

    receiveLater = function(self, url, callback, arg)
        if types.isString(url) and types.isFunction(callback)
        then
            local succeed, conn = self:_createConnection(url)
            if succeed
            then
                -- 注意参数有可为空
                local newCount = #self._mConnections + 1
                self._mConnections[newCount] = conn
                self._mCallbacks[newCount] = callback
                self._mCallbackArgs[newCount] = arg
                return true
            end
        end
    end,

    flushReceiveQueue = function(self, url)
        local conns = self._mConnections
        local callbacks = self._mCallbacks
        local callbackArgs = self._mCallbackArgs
        local callbackCount = #callbacks
        for i = 1, callbackCount
        do
            local content = self:_readConnection(conns[i])
            callbacks[i](content, callbackArgs[i])
            conns[i] = nil
            callbacks[i] = nil
            callbackArgs[i] = nil
        end
    end,

    resetParams = function(self)
        self._mIsCompressed = false
        utils.clearTable(self._mHeaders)
    end,

    setCompressed = function(self, val)
        self._mIsCompressed = types.toBoolean(val)
    end,

    addHeader = function(self, val)
        if types.isString(val)
        then
            table.insert(self._mHeaders, val)
        end
    end,
}

classlite.declareClass(_NetworkConnectionBase)


local CURLNetworkConnection =
{
    __mArguments        = classlite.declareTableField(),

    __buildCommandString = function(self, url)
        local arguments = utils.clearTable(self.__mArguments)
        _addCommand(arguments, "curl")
        _addOption(arguments, "--silent")
        _addOption(arguments, self._mIsCompressed and "--compressed")
        _addOptionAndValue(arguments, "--max-time", self._mTimeoutSeconds)
        for _, header in ipairs(self._mHeaders)
        do
            _addOptionAndValue(arguments, "-H", header)
        end
        _addValue(arguments, url)
        return _getCommandString(arguments)
    end,

    _createConnection = function(self, url)
        local cmd = self:__buildCommandString(url)
        local f = io.popen(cmd)
        return types.isOpenedFile(f), f
    end,

    _readConnection = function(self, conn)
        return conn:read(constants.READ_MODE_ALL)
    end,
}

classlite.declareClass(CURLNetworkConnection, _NetworkConnectionBase)


local _UNIQUE_PATH_FMT_FILE_NAME    = "%s%s%03d%s"
local _UNIQUE_PATH_FMT_TIME_PREFIX  = "%y%m%d%H%M"

local UniquePathGenerator =
{
    _mUniquePathID      = classlite.declareConstantField(1),

    getUniquePath = function(self, dir, prefix, suffix, isExistedFunc, funcArg)
        local timeStr = os.date(_UNIQUE_PATH_FMT_TIME_PREFIX)
        prefix = types.isString(prefix) and prefix or constants.STR_EMPTY
        suffix = types.isString(suffix) and suffix or constants.STR_EMPTY
        while true
        do
            local pathID = self._mUniquePathID
            self._mUniquePathID = pathID + 1

            local fileName = string.format(_UNIQUE_PATH_FMT_FILE_NAME,
                                           prefix, timeStr, pathID, suffix)

            local fullPath = joinPath(dir, fileName)
            if not isExistedFunc(funcArg, fullPath)
            then
                return fullPath
            end
        end
    end,
}

classlite.declareClass(UniquePathGenerator)



local _MD5_RESULT_CHAR_COUNT    = 32
local _MD5_PATTERN_GRAB_OUTPUT  = "(%x+)"
local _MD5_PATTERN_CHECK_STRING = "^(%x+)$"


local function calcFileMD5(fullPath, byteCount)
    local arguments = utils._obtainTable()
    if types.isNumber(byteCount)
    then
        _addCommand(arguments, "head")
        _addOption(arguments, "-c")
        _addValue(arguments, byteCount)
        _addValue(arguments, fullPath)
        _addSyntax(arguments, _SHELL_SYNTAX_PIPE_STDOUT_TO_INPUT)
        _addCommand(arguments, "md5sum")
    else
        _addCommand(arguments, "md5sum")
        _addValue(arguments, fullPath)
    end

    local succeed, output = _getCommandResult(arguments)
    local ret = succeed and output:match(_MD5_PATTERN_GRAB_OUTPUT)
    utils._recycleTable(arguments)

    if ret:match(_MD5_PATTERN_CHECK_STRING) and #ret == _MD5_RESULT_CHAR_COUNT
    then
        return ret
    end
end


local function createDir(fullPath)
    if types.isString(fullPath)
    then
        local arguments = utils._obtainTable()
        _addCommand("mkdir")
        _addOption("-p")
        _addValue(fullPath)

        local succeed = _getCommandResult(arguments)
        utils._recycleTable(arguments)
        return succeed
    end
end


local function deleteTree(fullPath)
    if types.isString(fullPath)
    then
        local arguments
    end
end


return
{
    _NetworkConnectionBase      = _NetworkConnectionBase,

    TextInfoProperties          = TextInfoProperties,
    EntryProperties             = EntryProperties,
    ListBoxProperties           = ListBoxProperties,
    FileSelectionProperties     = FileSelectionProperties,
    ZenityGUIBuilder            = ZenityGUIBuilder,
    CURLNetworkConnection       = CURLNetworkConnection,
    UniquePathGenerator         = UniquePathGenerator,

    calcFileMD5                 = calcFileMD5,
    createDir                   = createDir,

    iteratePathElements         = iteratePathElements,
    normalizePath               = normalizePath,
    joinPath                    = joinPath,
    splitPath                   = splitPath,
}