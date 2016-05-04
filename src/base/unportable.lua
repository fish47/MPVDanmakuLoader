local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _SHELL_SYNTAX_PIPE_STDOUT_TO_INPUT        = "|"
local _SHELL_SYNTAX_ARGUMENT_SEP                = " "
local _SHELL_SYNTAX_STRONG_QUOTE                = "\'"
local _SHELL_SYNTAX_NO_STDERR                   = "2>/dev/null"
local _SHELL_SYNTAX_REDICT_STDIN                = "<"

local _SHELL_CONST_STRONG_QUOTE_ESCAPED         = "'\"'\"'"
local _SHELL_CONST_DOUBLE_DASH                  = "--"
local _SHELL_CONST_RETURN_CODE_SUCCEED          = 0

local _SHELL_PATTERN_STARTS_WITH_DASH           = "^%-"


local __gCommandArguments   = {}
local __gPathElements1      = {}
local __gPathElements2      = {}


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
    if optionName and val
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


local function __splitPathElements(fullPath, paths)
    utils.clearTable(paths)

    if not types.isString(fullPath)
    then
        return false
    end

    -- 将 / 作为单独的路径
    if fullPath:match(_PATH_PATTERN_STARTS_WITH_ROOT)
    then
        table.insert(paths, _PATH_ROOT_DIR)
    end

    for path in fullPath:gmatch(_PATH_PATTERN_ELEMENT)
    do
        if path == _PATH_PARENT_DIR
        then
            local pathCount = #paths
            local lastPathElement = paths[pathCount]
            if not lastPathElement or lastPathElement == _PATH_PARENT_DIR
            then
                table.insert(paths, _PATH_PARENT_DIR)
            elseif lastPathElement == _PATH_ROOT_DIR
            then
                -- 不允许用 .. 将 / 弹出栈，例如 "/../../a" 实际指的是 "/"
            else
                paths[pathCount] = nil
            end
        elseif path == _PATH_CURRENT_DIR
        then
            -- 指向当前文件夹
        else
            table.insert(paths, path)
        end
    end
    return true
end


local function __joinPathElements(paths)
    -- 路径退栈
    local writeIdx = 1
    for i, path in ipairs(paths)
    do
        local insertPath = nil
        if path == _PATH_CURRENT_DIR
        then
            -- ingore
        elseif path == _PATH_PARENT_DIR
        then
            if writeIdx == 1 or paths[writeIdx - 1] == _PATH_PARENT_DIR
            then
                insertPath = _PATH_PARENT_DIR
            else
                writeIdx = writeIdx - 1
            end
        else
            insertPath = path
        end

        if insertPath
        then
            paths[writeIdx] = insertPath
            writeIdx = writeIdx + 1
        end
    end
    utils.clearArray(paths, writeIdx)

    local ret = nil
    if paths[1] == _PATH_ROOT_DIR
    then
        local trailing = table.concat(paths, _PATH_SEPERATOR, 2)
        ret = _PATH_ROOT_DIR .. trailing
    else
        ret = table.concat(paths, _PATH_SEPERATOR)
    end
    utils.clearTable(paths)
    return ret
end



local PathElementIterator =
{
    _mTablePool     = classlite.declareTableField(),
    _mIterateFunc   = classlite.declareConstantField(),

    new = function(self)
        self._mIterateFunc = function(paths, idx)
            idx = idx + 1
            if idx > #paths
            then
                -- 如果是中途 break 出来，就让虚拟机回收吧
                self:_recycleTable(paths)
                return nil
            else
                return idx, paths[idx]
            end
        end
    end,

    _obtainTable = function(self)
        return utils.popArrayElement(self._mTablePool) or {}
    end,

    _recycleTable = function(self, tbl)
        local pool = self._mTablePool
        if types.isTable(pool)
        then
            utils.clearTable(tbl)
            table.insert(pool, tbl)
        end
    end,

    iterate = function(self, fullPath)
        local paths = self:_obtainTable()
        if __splitPathElements(fullPath, paths)
        then
            return self._mIterateFunc, paths, 0
        else
            self:_recycleTable(paths)
            return constants.FUNC_EMPTY
        end
    end,
}

classlite.declareClass(PathElementIterator)


local function normalizePath(fullPath)
    local paths = utils.clearTable(__gPathElements1)
    local succeed = __splitPathElements(fullPath, paths)
    local ret = succeed and __joinPathElements(paths)
    utils.clearTable(paths)
    return ret
end


local function joinPath(dirName, pathName)
    local ret = nil
    if types.isString(dirName) and types.isString(pathName)
    then
        local paths = utils.clearTable(__gPathElements1)
        local fullPath = dirName .. _PATH_SEPERATOR .. pathName
        if __splitPathElements(fullPath, paths)
        then
            ret = __joinPathElements(paths)
        end
        utils.clearTable(paths)
    end

    return ret
end


local function splitPath(fullPath)
    local baseName = nil
    local dirName = nil
    local paths = utils.clearTable(__gPathElements1)
    local succeed = __splitPathElements(fullPath, paths)
    if succeed
    then
        baseName = utils.popArrayElement(paths)
        dirName = __joinPathElements(paths)
    end

    utils.clearTable(paths)
    return dirName, baseName
end


local function getRelativePath(dir, fullPath)
    local ret = nil
    local paths1 = utils.clearTable(__gPathElements1)
    local paths2 = utils.clearTable(__gPathElements2)
    local succeed1 = __splitPathElements(dir, paths1)
    local succeed2 = __splitPathElements(fullPath, paths2)
    if succeed1 and succeed2 and #paths1 > 0 and #paths2 > 0
    then
        -- 找出第一个不同的路径元素
        local paths1Count = #paths1
        local relIdx = paths1Count + 1
        for i = 1, paths1Count
        do
            local comparePath = paths2[i]
            if comparePath and paths1[i] ~= comparePath
            then
                relIdx = i
                break
            end
        end

        -- 有可能两个路径是一样的，提前特判
        local paths2Count = #paths2
        if paths1Count == paths2Count and relIdx > paths1Count
        then
            return _PATH_CURRENT_DIR
        end

        -- 前缀不一定完全匹配的，例如 /1 相对于 /a/b/c/d 路径是 ../../../../1
        local outPaths = utils.clearTable(paths1)
        local parentDirCount = paths1Count - relIdx + 1
        for i = 1, parentDirCount
        do
            table.insert(outPaths, _PATH_PARENT_DIR)
        end

        for i = relIdx, #paths2
        do
            table.insert(outPaths, paths2[i])
        end
        ret = __joinPathElements(outPaths)
    end

    utils.clearTable(paths1)
    utils.clearTable(paths2)
    return ret
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
        self._mTimeoutSeconds = types.isNumber(timeout) and timeout > 0 and timeout
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

    clearHeaders = function(self)
        self._mIsCompressed = false
        utils.clearTable(self._mHeaders)
        return self
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

            local fileName = string.format(_UNIQUE_PATH_FMT_FILE_NAME, prefix, timeStr, pathID, suffix)
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
    local arguments = utils.clearTable(__gCommandArguments)
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
    utils.clearTable(arguments)

    if ret:match(_MD5_PATTERN_CHECK_STRING) and #ret == _MD5_RESULT_CHAR_COUNT
    then
        return ret
    end
end


local function __executeSimpleCommand(...)
    local arguments = utils.clearTable(__gCommandArguments)
    for i = 1, types.getVarArgCount(...)
    do
        local arg = select(i, ...)
        table.insert(arguments, __quoteShellString(arg))
    end
    table.insert(arguments, _SHELL_SYNTAX_NO_STDERR)

    local succeed = _getCommandResult(arguments)
    utils.clearTable(arguments)
    return succeed
end


local function createDir(fullPath)
    return types.isString(fullPath) and __executeSimpleCommand("mkdir", "-p", fullPath)
end


local function deleteTree(fullPath)
    return types.isString(fullPath) and __executeSimpleCommand("rm", "-rf", fullPath)
end


local function moveTree(fromPath, toPath, preserved)
    local arg = preserved and "--backup=numbered" or "-f"
    return types.isString(fromPath) and __executeSimpleCommand("mv", arg, fromPath, toPath)
end


local function readUTF8File(fullPath)
    if types.isString(fullPath)
    then
        local arguments = utils.clearTable(__gCommandArguments)
        _addCommand(arguments, "enca")
        _addOption(arguments, "-L")
        _addValue(arguments, "zh")
        _addOption(arguments, "-x")
        _addValue(arguments, "utf8")
        _addSyntax(arguments, _SHELL_SYNTAX_REDICT_STDIN)
        _addValue(arguments, fullPath)
        _addSyntax(arguments, _SHELL_SYNTAX_NO_STDERR)

        local commandString = _getCommandString(arguments)
        utils.clearTable(arguments)
        return io.popen(commandString)
    end
end


return
{
    _NetworkConnectionBase      = _NetworkConnectionBase,

    TextInfoProperties          = TextInfoProperties,
    EntryProperties             = EntryProperties,
    ListBoxProperties           = ListBoxProperties,
    FileSelectionProperties     = FileSelectionProperties,
    ProgressBarProperties       = ProgressBarProperties,
    QuestionProperties          = QuestionProperties,

    ZenityGUIBuilder            = ZenityGUIBuilder,
    CURLNetworkConnection       = CURLNetworkConnection,
    UniquePathGenerator         = UniquePathGenerator,
    PathElementIterator         = PathElementIterator,

    calcFileMD5                 = calcFileMD5,
    createDir                   = createDir,
    deleteTree                  = deleteTree,
    moveTree                    = moveTree,
    readUTF8File                = readUTF8File,

    normalizePath               = normalizePath,
    joinPath                    = joinPath,
    splitPath                   = splitPath,
    getRelativePath             = getRelativePath,
}