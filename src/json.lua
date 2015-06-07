local base = require('src/base')            --= base base
local encoding = require('src/encoding')    --= encoding encoding

local _TOKEN_LBRACE     = "{"
local _TOKEN_RBRACE     = "}"
local _TOKEN_LBRACKET   = "["
local _TOKEN_RBRACKET   = "]"
local _TOKEN_COLON      = ":"
local _TOKEN_COMMA      = ","
local _TOKEN_BACKSLASH  = "\\"
local _TOKEN_QUOTE      = "\""

local _TOKEN_ESCAPABLE_QUOTE            = "\""
local _TOKEN_ESCAPABLE_REVERSE_SOLIDUS  = "\\"
local _TOKEN_ESCAPABLE_SOLIDUS          = "/"
local _TOKEN_ESCAPABLE_FORMFEED         = "b"
local _TOKEN_ESCAPABLE_NEWLINE          = "n"
local _TOKEN_ESCAPABLE_CARRIAGE_RETURN  = "r"
local _TOKEN_ESCAPABLE_HORIZONTAL_TAB   = "t"
local _TOKEN_ESCAPABLE_UNICODE_PREFIX   = "u"

local _MAP_ESCAPABLE_ =
{
    _TOKEN_ESCAPABLE_QUOTE              = "\"",
    _TOKEN_ESCAPABLE_REVERSE_SOLIDUS    = "\\",
    _TOKEN_ESCAPABLE_SOLIDUS            = "/",
    _TOKEN_ESCAPABLE_FORMFEED           = "\f",
    _TOKEN_ESCAPABLE_NEWLINE            = "\n",
    _TOKEN_ESCAPABLE_CARRIAGE_RETURN    = "\r",
    _TOKEN_ESCAPABLE_HORIZONTAL_TAB     = "\t",
}


local _CONSTANT_TRUE    = "true"
local _CONSTANT_FALSE   = "false"
local _CONSTANT_NULL    = "null"

local _MAP_CONSTANT =
{
    _CONSTANT_TRUE      = true,
    _CONSTANT_FALSE     = false,
    _CONSTANT_NULL      = nil,
}


local _WORD_TYPE_ARRAY_START        = 0
local _WORD_TYPE_ARRAY_END          = 1
local _WORD_TYPE_OBJECT_START       = 2
local _WORD_TYPE_OBJECT_END         = 3
local _WORD_TYPE_COLLECTION_SEP     = 4
local _WORD_TYPE_STRING             = 5
local _WORD_TYPE_CONSTANT           = 6
local _WORD_TYPE_NUMBER             = 7
local _WORD_TYPE_END_OF_CONTENT     = 8
local _WORD_TYPE_UNKNOWN            = 9

local _MAP_WORD_TYPE =
{
    _TOKEN_LBRACKET     = _WORD_TYPE_ARRAY_END,
    _TOKEN_RBRACKET     = _WORD_TYPE_ARRAY_END,
    _TOKEN_LBRACE       = _WORD_TYPE_OBJECT_START,
    _TOKEN_RBRACE       = _WORD_TYPE_OBJECT_END,
    _TOKEN_COMMA        = _WORD_TYPE_COLLECTION_SEP,
    _TOKEN_QUOTE        = _WORD_TYPE_STRING,

    "t"                 = _WORD_TYPE_CONSTANT,      -- true
    "f"                 = _WORD_TYPE_CONSTANT,      -- false
    "n"                 = _WORD_TYPE_CONSTANT,      -- null

    "-"                 = _WORD_TYPE_NUMBER,
    "0"                 = _WORD_TYPE_NUMBER,
    "1"                 = _WORD_TYPE_NUMBER,
    "2"                 = _WORD_TYPE_NUMBER,
    "3"                 = _WORD_TYPE_NUMBER,
    "4"                 = _WORD_TYPE_NUMBER,
    "5"                 = _WORD_TYPE_NUMBER,
    "6"                 = _WORD_TYPE_NUMBER,
    "7"                 = _WORD_TYPE_NUMBER,
    "8"                 = _WORD_TYPE_NUMBER,
    "9"                 = _WORD_TYPE_NUMBER,
}


local _PATTERN_NONSPACE_CHAR        = "([^%s])"
local _PATTERN_QUOTE_OR_ESCAPE      = "([\"\\])"
local _PATTERN_FOUR_HEX             = "(%x%x%x%x)"
local _PATTERN_NUMBER               = "%s*(%-?%d+%.?%d*[eE]?[+-]?%d*)"

local _UNICODE_NUMBER_BASE          = 16

local function __getCharAt(str, idx)
    return str and idx and str:sub(idx, idx + 1) or nil
end

local function __getStackTop(stack)
    return stack[#stack]
end

local function __convertByteToString(byteVal)
    return string.char(byteVal)
end



local function _onParseString(ctx)
    local buf = ctx.stringBuf
    local content = ctx.content

    local result = nil
    local findStartIdx = ctx.readIndex
    local nextStartIdx = ctx.readIndex
    while true
    do
        local idx = content:find(_PATTERN_QUOTE_OR_ESCAPE, findStartIdx, false)
        if not idx
        then
            -- 读到结尾字符串还没结束
            break
        elseif __getCharAt(content, idx) == _TOKEN_QUOTE
        then
            -- 字符串结束
            table.insert(buf, content:sub(content, idx))
            result = table.concat(buf)
            nextStartIdx = idx + 1,
            break
        else
            -- 注意有可能最后一个字符就是反斜杠
            local nextChIdx = idx + 1
            local nextCh = (nextChIdx == #content) and nil or __getCharAt(content, nextChIdx)
            if not nextCh
            then
                break;
            elseif nextCh == _TOKEN_ESCAPABLE_UNICODE_PREFIX
            then
                -- \uXXXX
                local hexStr = content:find(_PATTERN_FOUR_HEX, nextChIdx + 1, false)
                local codePoint = hexStr and tonumber(hexStr, _UNICODE_NUMBER_BASE) or nil
                if codePoint
                then
                    encoding.getUTF8Bytes(codePoint, buf, #buf + 1, __convertByteToString)
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
        ctx.readIndex = math.min(ctx.readIndex, nextStartIdx - 1)
        return true, result
    else
        return false
    end
end



local function _onParseNumber(ctx)
    local content = ctx.content
    local numStr = content:find(ctx.readIndex, _PATTERN_NUMBER, false)
    local num = numStr and tonumber(numStr) or nil
    if num
    then
        ctx.readIndex = ctx.readIndex + #numStr - 1
        return true, num
    else
        return false
    end
end



local function _onParseConstant(ctx)
    local content = ctx.content
    local startIdx = ctx.readIndex
    local strEndIdx = #content
    for constName, val in ipairs(_MAP_CONSTANT)
    do
        local subStrEndIdx = startIdx + #constName - 1
        if subStrEndIdx <= strEndIdx and :sub(startIdx, subStrEndIdx) == constName
        then
            ctx.readIndex = ctx.readIndex + #constName - 1
            return true, val
        end
    end

    return false
end



local JSONParseContext =
{
    content = nil,
    readIndex = nil,
    stringBuf = nil,
    keyStack = nil,
    collectionStack = nil,
    parseElemFuncStack = nil

    new = function(obj, content)
        obj = base.allocateInstance(obj)
        obj.content = content
        obj.readIndex = 0
        obj.stringBuf = obj.stringBuf or {}
        obj.keyStack = base.clearTable(obj.keyStack or {})
        obj.collectionStack = base.clearTable(obj.collectionStack or {})
        obj.parseElemFuncStack = base.clearTable(obj.parseElemFuncStack or {})
    end,
}

base.declareClass(JSONParseContext)


-- 尾调用基本需要提前声明，因为状态需要跳来跳去
local _onParseArrayStart            = nil
local _onParseArrayItems            = nil
local _onParseArrayEnd              = nil
local _onParseObjectStart           = nil
local _onParseObjectPairs           = nil
local _onParseObjectEnd             = nil
local _onParsePlainValue            = nil
local _onParseCollectionSep         = nil
local _onCheckParseSucceed          = nil


local _JUMP_TABLE_ARRAY_START       = nil
local _JUMP_TABLE_ARRAY_ITEMS       = nil
local _JUMP_TABLE_ARRAY_END         = nil
local _JUMP_TABLE_OBJECT_START      = nil
local _JUMP_TABLE_OBJECT_PAIRS      = nil
local _JUMP_TABLE_OBJECT_END        = nil
local _JUMP_TABLE_PLAIN_VALUE       = nil


local function __readNextNonspaceChar(ctx)
    local content = ctx.content
    local nextIdx = content:find(_PATTERN_NONSPACE_CHAR, ctx.readIndex + 1, false)
    if nextIdx
    then
        ctx.readIndex = nextIdx
        local ch = __getCharAt(content, nextIdx)
        local wordType = _MAP_WORD_TYPE[ch] or _WORD_TYPE_UNKNOWN
        return wordType, ch
    else
        return _WORD_TYPE_END_OF_CONTENT
    end
end


local function __doJumpState(jumpTbl, ctx, wordType)
    -- 有可能在此之前已经读了一次
    wordType = wordType or __readNextNonspaceChar(ctx)

    -- 跳不到合法状态
    local jumpFunc = jumpTbl[wordType]
    if not jumpFunc
    then
        return false
    end

    return jumpFunc(ctx, wordType)
end


_onParseArrayStart = function(ctx)
    table.insert(ctx.collectionStack, {})
    table.insert(ctx.parseElemFuncStack, _onParseArrayItems)

    if _JUMP_TABLE_ARRAY_START == nil
    then
        _JUMP_TABLE_ARRAY_START =
        {
            _WORD_TYPE_CONSTANT     =   _onParseArrayItems,
            _WORD_TYPE_NUMBER       =   _onParseArrayItems,
            _WORD_TYPE_STRING       =   _onParseArrayItems,
            _WORD_TYPE_ARRAY_START  =   _onParseArrayItems,
            _WORD_TYPE_OBJECT_START =   _onParseArrayItems,
            _WORD_TYPE_ARRAY_END    =   _onParseArrayEnd,
        }
    end

    return __doJumpState(_JUMP_TABLE_ARRAY_START, ctx)
end


_onParseObjectStart = function(ctx)
    table.insert(ctx.collectionStack, {})
    table.insert(ctx.parseElemFuncStack, _onParseObjectPairs)

    if _JUMP_TABLE_OBJECT_START == nil
    then
        _JUMP_TABLE_OBJECT_START =
        {
            _WORD_TYPE_STRING       =   _onParseObjectPairs,
            _WORD_TYPE_OBJECT_END   =   _onParseObjectEnd,
        }
    end

    return __doJumpState(_JUMP_TABLE_OBJECT_START, ctx)
end


local function __doParsePlainValue(ctx, wordType)
    if _JUMP_TABLE_PLAIN_VALUE == nil
    then
        _JUMP_TABLE_PLAIN_VALUE =
        {
            _WORD_TYPE_CONSTANT     = _onParseConstant,
            _WORD_TYPE_NUMBER       = _onParseNumber,
            _WORD_TYPE_STRING       = _onParseString,
        }
    end

    local parseFunc = _JUMP_TABLE_PLAIN_VALUE[wordType]
    local ret, val = parseFunc and parseFunc(ctx) or false
    return ret, val
end


local function __doOnParseCollectionSep(ctx)
end


local function __doOnParseCollectionItems(ctx, jumpTble)

end

_onParseArrayItems = function(ctx, wordType)
    local ret, val = __doParsePlainValue(ctx, wordType)
    if not ret
    then
        return false
    end

    table.insert(__getStackTop(ctx.collectionStack), val)

    if _JUMP_TABLE_ARRAY_ITEMS == nil
    then
        _JUMP_TABLE_ARRAY_ITEMS =
        {
            _WORD_TYPE_COLLECTION_SEP   =   __doOnParseCollectionSep,
            _WORD_TYPE_ARRAY_END        =   _onParseArrayEnd,
        }
    end

    return __doJumpState(_JUMP_TABLE_ARRAY_ITEMS, ctx)
end


_onParseObjectPairs = function(ctx, wordType)
    local ret, val = __doParsePlainValue(ctx, wordType)
    if not ret
    then
        return false
    end

end


local _M = {}
return _M