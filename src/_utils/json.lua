local _base = require("src/_utils/_base")
local utf8 = require("src/_utils/utf8")
local classlite = require("src/_utils/classlite")


local _TOKEN_LBRACE     = "{"
local _TOKEN_RBRACE     = "}"
local _TOKEN_LBRACKET   = "["
local _TOKEN_RBRACKET   = "]"
local _TOKEN_COLON      = ":"
local _TOKEN_COMMA      = ","
local _TOKEN_BACKSLASH  = "\\"
local _TOKEN_QUOTE      = "\""

local _TOKEN_ESCAPABLE_QUOTE                = "\""
local _TOKEN_ESCAPABLE_REVERSE_SOLIDUS      = "\\"
local _TOKEN_ESCAPABLE_SOLIDUS              = "/"
local _TOKEN_ESCAPABLE_FORMFEED             = "b"
local _TOKEN_ESCAPABLE_NEWLINE              = "n"
local _TOKEN_ESCAPABLE_CARRIAGE_RETURN      = "r"
local _TOKEN_ESCAPABLE_HORIZONTAL_TAB       = "t"
local _TOKEN_ESCAPABLE_UNICODE_PREFIX       = "u"

local _MAP_ESCAPABLE_ =
{
    [_TOKEN_ESCAPABLE_QUOTE]                = "\"",
    [_TOKEN_ESCAPABLE_REVERSE_SOLIDUS]      = "\\",
    [_TOKEN_ESCAPABLE_SOLIDUS]              = "/",
    [_TOKEN_ESCAPABLE_FORMFEED]             = "\f",
    [_TOKEN_ESCAPABLE_NEWLINE]              = "\n",
    [_TOKEN_ESCAPABLE_HORIZONTAL_TAB]       = "\t",
    [_TOKEN_ESCAPABLE_CARRIAGE_RETURN]      = "\r",
}


local _CONSTANT_TRUE    = "true"
local _CONSTANT_FALSE   = "false"
local _CONSTANT_NULL    = "null"

-- 在 table 里声明 key = nil 是没用的囧
local _MAP_CONSTANT =
{
    _CONSTANT_NULL,   nil,
    _CONSTANT_TRUE,   true,
    _CONSTANT_FALSE,  false,
}


local _WORD_TYPE_ARRAY_START        = 1
local _WORD_TYPE_ARRAY_END          = 2
local _WORD_TYPE_OBJECT_START       = 3
local _WORD_TYPE_OBJECT_END         = 4
local _WORD_TYPE_PAIR_SEP           = 5
local _WORD_TYPE_COLLECTION_SEP     = 6
local _WORD_TYPE_STRING             = 7
local _WORD_TYPE_CONSTANT           = 8
local _WORD_TYPE_NUMBER             = 9
local _WORD_TYPE_END_OF_CONTENT     = 10
local _WORD_TYPE_UNKNOWN            = 11

local _MAP_WORD_TYPE =
{
    [_TOKEN_LBRACKET]   = _WORD_TYPE_ARRAY_START,
    [_TOKEN_RBRACKET]   = _WORD_TYPE_ARRAY_END,
    [_TOKEN_LBRACE]     = _WORD_TYPE_OBJECT_START,
    [_TOKEN_RBRACE]     = _WORD_TYPE_OBJECT_END,
    [_TOKEN_COLON]      = _WORD_TYPE_PAIR_SEP,
    [_TOKEN_COMMA]      = _WORD_TYPE_COLLECTION_SEP,
    [_TOKEN_QUOTE]      = _WORD_TYPE_STRING,


    ["t"]               = _WORD_TYPE_CONSTANT,      -- true
    ["f"]               = _WORD_TYPE_CONSTANT,      -- false
    ["n"]               = _WORD_TYPE_CONSTANT,      -- null

    ["-"]               = _WORD_TYPE_NUMBER,
    ["0"]               = _WORD_TYPE_NUMBER,
    ["1"]               = _WORD_TYPE_NUMBER,
    ["2"]               = _WORD_TYPE_NUMBER,
    ["3"]               = _WORD_TYPE_NUMBER,
    ["4"]               = _WORD_TYPE_NUMBER,
    ["5"]               = _WORD_TYPE_NUMBER,
    ["6"]               = _WORD_TYPE_NUMBER,
    ["7"]               = _WORD_TYPE_NUMBER,
    ["8"]               = _WORD_TYPE_NUMBER,
    ["9"]               = _WORD_TYPE_NUMBER,
}


local JSONParseContext =
{
    result = nil,
    content = nil,
    readIndex = nil,
    stringBuf = nil,
    keyStack = nil,
    collectionStack = nil,
    addItemFuncStack = nil,
    parseItemListFuncStack = nil,

    new = function(obj)
        obj = classlite.allocateInstance(obj)
        obj.content = nil
        obj.readIndex = 0
        obj.stringBuf = {}
        obj.keyStack = {}
        obj.collectionStack = {}
        obj.addItemFuncStack = {}
        obj.parseItemListFuncStack = {}
        return obj
    end,

    _reset = function(self, content)
        self.result = nil
        self.content = content
        self.readIndex = 0
        _base.clearTable(self.stringBuf)
        _base.clearTable(self.keyStack)
        _base.clearTable(self.collectionStack)
        _base.clearTable(self.addItemFuncStack)
        _base.clearTable(self.parseItemListFuncStack)
    end,

    dispose = function(self)
        _base.disposeSafely(self.stringBuf)
        _base.disposeSafely(self.keyStack)
        _base.disposeSafely(self.collectionStack)
        _base.disposeSafely(self.addItemFuncStack)
        _base.disposeSafely(self.parseItemListFuncStack)
        _base.clearTable(self)
    end,
}

classlite.declareClass(JSONParseContext)


local _onParseArrayStart            = nil
local _onParseArrayElementList      = nil
local _onParseArrayEnd              = nil

local _onParseObjectStart           = nil
local _onParseObjectPairList        = nil
local _onParseObjectPair            = nil
local _onParseObjectEnd             = nil

local _onParseCollectionItemSep     = nil

local _onAddArrayElement            = nil
local _onAddObjectKey               = nil
local _onAddObjectValue             = nil
local _onCheckHasRemainingContent   = nil

local _onParseNumber                = nil
local _onParseString                = nil
local _onParseConstant              = nil


local _JUMP_TABLE_PARSE_ARRAY_START             = nil
local _JUMP_TABLE_PARSE_ARRAY_ELEMENT_LIST      = nil
local _JUMP_TABLE_ADD_ARRAY_ELEMENT             = nil

local _JUMP_TABLE_PARSE_OBJECT_START            = nil
local _JUMP_TABLE_PARSE_OBJECT_PAIR_LIST        = nil
local _JUMP_TABLE_ADD_OBJECT_KEY                = nil
local _JUMP_TABLE_ADD_OBJECT_VALUE              = nil

local _JUMP_TABLE_INITIAL                        = nil



local _PATTERN_NONSPACE_CHAR            = "([^%s])"
local _PATTERN_QUOTE_OR_ESCAPE          = "([\"\\])"
local _PATTERN_UNICODE_HEX              = "^(%x%x%x%x)"
local _PATTERN_NUMBER_DECIMAL_PART      = "^(%-?%d+)"
local _PATTERN_NUMBER_FRACTIONAL_PART   = "^(%.%d+)"
local _PATTERN_NUMBER_EXPONENTIAL_PART  = "^([eE][+-]?%d+)"
local _PATTERN_NUMBER_LEADING_ZREOS     = "^00+"

local _UNICODE_NUMBER_BASE          = 16


local function __getCharAt(str, idx)
    return str and idx and str:sub(idx, idx) or nil
end

local function __getStackTop(stack)
    return stack[#stack]
end

local function __jumpAddItemStateSafelly(ctx, arg)
    local func = __getStackTop(ctx.addItemFuncStack)
    if func
    then
        return func(ctx, arg)
    else
        return false
    end
end


local function __readNextWord(ctx, nextCallFunc, arg)
    local content = ctx.content
    local nextIdx = content:find(_PATTERN_NONSPACE_CHAR, ctx.readIndex + 1, false)
    local wordType = _WORD_TYPE_END_OF_CONTENT
    if nextIdx
    then
        ctx.readIndex = nextIdx
        local ch = __getCharAt(content, nextIdx)
        wordType = _MAP_WORD_TYPE[ch] or _WORD_TYPE_UNKNOWN
    end

    -- 不要用 return CONDITION and CALL_F1() or CALL_F2() 的写法，
    -- 只要判断条件内的方法未执行完，都不会退栈，就样就不是尾调用了囧
    if nextCallFunc
    then
        return nextCallFunc(ctx, wordType, arg)
    else
        return wordType
    end
end


local function __jumpState(ctx, wordType, jumpTbl)
    -- 有可能跳不到合法状态
    local jumpFunc = jumpTbl[wordType]
    if jumpFunc
    then
        return jumpFunc(ctx, wordType)
    else
        return false
    end
end


local function __readNextAndJumpStateByTable(ctx, jumpTbl)
    return __readNextWord(ctx, __jumpState, jumpTbl)
end


local function __readNextAndJumpState(ctx, stateFunc)
    if stateFunc
    then
        return __readNextWord(ctx, stateFunc)
    else
        return false
    end
end


_onParseString = function(ctx)
    local buf = _base.clearTable(ctx.stringBuf)
    local content = ctx.content

    local result = nil
    local hasStartQuote = false
    local findStartIdx = ctx.readIndex
    local stringLastIdx = ctx.readIndex
    while true
    do
        local idx = content:find(_PATTERN_QUOTE_OR_ESCAPE, findStartIdx, false)
        if not idx
        then
            -- 读到结尾字符串还没结束
            break
        elseif not hasStartQuote
        then
            if idx == findStartIdx
            then
                findStartIdx = findStartIdx + 1
                hasStartQuote = true
            else
                return false
            end
        elseif __getCharAt(content, idx) == _TOKEN_QUOTE
        then
            -- 字符串结束
            table.insert(buf, content:sub(findStartIdx, idx - 1))
            result = table.concat(buf)
            stringLastIdx = idx
            break
        else
            -- 例如 "abc\n123" 遇到转义起始字符，先保存已解释的部分
            if findStartIdx < idx
            then
                table.insert(buf, content:sub(findStartIdx, idx - 1))
            end

            -- 注意有可能最后一个字符就是反斜杠
            local nextChIdx = idx + 1
            local nextCh = (nextChIdx == #content) and nil or __getCharAt(content, nextChIdx)
            if not nextCh
            then
                break;
            elseif nextCh == _TOKEN_ESCAPABLE_UNICODE_PREFIX
            then
                -- \uXXXX
                local hexStr = content:match(_PATTERN_UNICODE_HEX, nextChIdx + 1)
                local codePoint = hexStr and tonumber(hexStr, _UNICODE_NUMBER_BASE) or nil
                if codePoint
                then
                    for _, utf8Byte in utf8.iterateUTF8EncodedBytes(codePoint)
                    do
                        table.insert(buf, string.char(utf8Byte))
                    end
                    findStartIdx = nextChIdx + #hexStr + 1
                else
                    break
                end
            else
                -- 转义字符
                local ch = _MAP_ESCAPABLE_[nextCh]
                if ch
                then
                    table.insert(buf, ch)
                    findStartIdx = nextChIdx + 1
                else
                    break
                end
            end

        end
    end

    if result
    then
        ctx.readIndex = stringLastIdx
        return __jumpAddItemStateSafelly(ctx, result)
    else
        return false
    end
end


_onParseNumber = function(ctx)
    local content = ctx.content
    local startIdx = ctx.readIndex
    local matchedPart = content:match(_PATTERN_NUMBER_DECIMAL_PART, startIdx)

    -- 整数部分，不能有多余的前导 0
    if not matchedPart or matchedPart:find(_PATTERN_NUMBER_LEADING_ZREOS, 1, false)
    then
        return false
    end

    -- 小数部分
    local numStr = matchedPart
    startIdx = startIdx + #matchedPart
    matchedPart = content:match(_PATTERN_NUMBER_FRACTIONAL_PART, startIdx)
    if matchedPart
    then
        numStr = numStr .. matchedPart
        startIdx = startIdx + #matchedPart
    end

    -- 指数部分
    matchedPart = content:match(_PATTERN_NUMBER_EXPONENTIAL_PART, startIdx)
    if matchedPart
    then
        numStr = numStr .. matchedPart
        startIdx = startIdx + #matchedPart
    end

    local result = nil
    if numStr
    then
        ctx.readIndex = ctx.readIndex + #numStr - 1
        result = tonumber(numStr)
    end

    if result
    then
        return __jumpAddItemStateSafelly(ctx, result)
    else
        return false
    end
end



_onParseConstant = function(ctx)
    local content = ctx.content
    local startIdx = ctx.readIndex
    local strEndIdx = #content
    for _, constName, val in _base.iteratePairsArray(_MAP_CONSTANT)
    do
        local subStrEndIdx = startIdx + #constName - 1
        if subStrEndIdx <= strEndIdx and content:sub(startIdx, subStrEndIdx) == constName
        then
            ctx.readIndex = ctx.readIndex + #constName - 1
            return __jumpAddItemStateSafelly(ctx, val)
        end
    end

    return false
end


_onParseCollectionItemSep = function(ctx)
    local topParseListFunc = __getStackTop(ctx.parseItemListFuncStack)
    return __readNextAndJumpState(ctx, topParseListFunc)
end


local function __doOnParseCollectionStart(ctx, addItemFunc, parseItemListFunc)
    table.insert(ctx.collectionStack, {})
    table.insert(ctx.addItemFuncStack, addItemFunc)
    table.insert(ctx.parseItemListFuncStack, parseItemListFunc)
    return __readNextAndJumpState(ctx, parseItemListFunc)
end


_onParseArrayStart = function(ctx)
    return __doOnParseCollectionStart(ctx, _onAddArrayElement, _onParseArrayElementList)
end

_onParseObjectStart = function(ctx)
    -- JSON 规定对象的 key 只能是字符串
    return __doOnParseCollectionStart(ctx, _onAddObjectKey, _onParseObjectPairList)
end


local function __doOnParseCollectionEnd(ctx)
    table.remove(ctx.addItemFuncStack)
    table.remove(ctx.parseItemListFuncStack)
    local collection = table.remove(ctx.collectionStack)
    return __jumpAddItemStateSafelly(ctx, collection)
end

_onParseArrayEnd = __doOnParseCollectionEnd
_onParseObjectEnd = __doOnParseCollectionEnd



_onParseArrayElementList = function(ctx, wordType)
    -- 分派到对应的解释流程
    if not _JUMP_TABLE_PARSE_ARRAY_ELEMENT_LIST
    then
        _JUMP_TABLE_PARSE_ARRAY_ELEMENT_LIST =
        {
            [_WORD_TYPE_CONSTANT]       = _onParseConstant,
            [_WORD_TYPE_NUMBER]         = _onParseNumber,
            [_WORD_TYPE_STRING]         = _onParseString,
            [_WORD_TYPE_ARRAY_START]    = _onParseArrayStart,
            [_WORD_TYPE_OBJECT_START]   = _onParseObjectStart,
            [_WORD_TYPE_ARRAY_END]      = _onParseArrayEnd,
        }
    end

    return __jumpState(ctx, wordType, _JUMP_TABLE_PARSE_ARRAY_ELEMENT_LIST)
end


_onAddArrayElement = function(ctx, val)
    local curArray = __getStackTop(ctx.collectionStack)
    curArray[#curArray + 1] = val

    if not _JUMP_TABLE_ADD_ARRAY_ELEMENT
    then
        _JUMP_TABLE_ADD_ARRAY_ELEMENT =
        {
            [_WORD_TYPE_COLLECTION_SEP]   = _onParseCollectionItemSep,
            [_WORD_TYPE_ARRAY_END]        = _onParseArrayEnd,
        }
    end

    return __readNextAndJumpStateByTable(ctx, _JUMP_TABLE_ADD_ARRAY_ELEMENT)
end



_onParseObjectPairList = function(ctx, wordType)
    -- 接收到字符串作为 key
    local addItemFuncStack = ctx.addItemFuncStack
    addItemFuncStack[#addItemFuncStack] = _onAddObjectKey

    if not _JUMP_TABLE_PARSE_OBJECT_PAIR_LIST
    then
        _JUMP_TABLE_PARSE_OBJECT_PAIR_LIST =
        {
            [_WORD_TYPE_STRING]         = _onParseString,
            [_WORD_TYPE_OBJECT_END]     = _onParseObjectEnd,
        }
    end

    return __jumpState(ctx, wordType, _JUMP_TABLE_PARSE_OBJECT_PAIR_LIST)
end


_onAddObjectKey = function(ctx, val)
    table.insert(ctx.keyStack, val)

    -- 跳过 key-value 分割符
    if __readNextWord(ctx) ~= _WORD_TYPE_PAIR_SEP
    then
        return false
    end

    -- 下次接收的值就是 value 所以要把回调状态改一下
    local addItemFuncStack = ctx.addItemFuncStack
    addItemFuncStack[#addItemFuncStack] = _onAddObjectValue

    if not _JUMP_TABLE_ADD_OBJECT_KEY
    then
        _JUMP_TABLE_ADD_OBJECT_KEY =
        {
            [_WORD_TYPE_CONSTANT]       = _onParseConstant,
            [_WORD_TYPE_NUMBER]         = _onParseNumber,
            [_WORD_TYPE_STRING]         = _onParseString,
            [_WORD_TYPE_ARRAY_START]    = _onParseArrayStart,
            [_WORD_TYPE_OBJECT_START]   = _onParseObjectStart,
        }
    end

    return __readNextAndJumpStateByTable(ctx, _JUMP_TABLE_ADD_OBJECT_KEY)
end


_onAddObjectValue = function(ctx, val)
    local key = table.remove(ctx.keyStack)
    __getStackTop(ctx.collectionStack)[key] = val

    if not _JUMP_TABLE_ADD_OBJECT_VALUE
    then
        _JUMP_TABLE_ADD_OBJECT_VALUE =
        {
            [_WORD_TYPE_COLLECTION_SEP]     = _onParseCollectionItemSep,
            [_WORD_TYPE_OBJECT_END]         = _onParseObjectEnd
        }
    end

    return __readNextAndJumpStateByTable(ctx, _JUMP_TABLE_ADD_OBJECT_VALUE)
end


_onCheckHasRemainingContent = function(ctx, val)
    if __readNextWord(ctx) == _WORD_TYPE_END_OF_CONTENT
    then
        ctx.result = val
        return true
    else
        return false
    end
end



local function parseJSON(content, ctx)
    if not content
    then
        return false
    end

    ctx = ctx or JSONParseContext:new()
    ctx:_reset(content)

    -- 完成解释后，检测有没有多余的内容，例如 "[ 1 ] abc"
    table.insert(ctx.addItemFuncStack, _onCheckHasRemainingContent)

    if not _JUMP_TABLE_INITIAL
    then
        _JUMP_TABLE_INITIAL =
        {
            [_WORD_TYPE_CONSTANT]       = _onParseConstant,
            [_WORD_TYPE_NUMBER]         = _onParseNumber,
            [_WORD_TYPE_STRING]         = _onParseString,
            [_WORD_TYPE_ARRAY_START]    = _onParseArrayStart,
            [_WORD_TYPE_OBJECT_START]   = _onParseObjectStart,
        }
    end

    local succeed = __readNextAndJumpStateByTable(ctx, _JUMP_TABLE_INITIAL)
    return succeed, ctx.result
end



return
{
    JSONParseContext    = JSONParseContext,
    parseJSON           = parseJSON,
}