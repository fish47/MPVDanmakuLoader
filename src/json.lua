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

-- 花括号和方括号的英文也太相近了，起个别名吧
local _TOKEN_ARRAY_START    = _TOKEN_LBRACKET
local _TOKEN_ARRAY_END      = _TOKEN_RBRACKET
local _TOKEN_OBJECT_START   = _TOKEN_LBRACE
local _TOKEN_OBJECT_END     = _TOKEN_RBRACE

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


local _PATTERN_NONSPACE_CHAR        = "([^%s])"
local _PATTERN_QUOTE_OR_ESCAPE      = "([\"\\])"
local _PATTERN_FOUR_HEX             = "(%x%x%x%x)"
local _PATTERN_NUMBER               = "%s*(%-?%d+%.?%d*[eE]?[+-]?%d*)"

local _NUMBER_START_CHARS           = "0123456789-"

local _UNICODE_NUMBER_BASE          = 16

local RET_SUCCEED   = 0
local RET_FAILED    = nil


local function __getCharAt(str, idx)
    return str and idx and str:sub(idx, idx + 1) or nil
end

local function __convertByteToString(byteVal)
    return string.char(byteVal)
end

local function __isCollectionStartToken(token)
    return token == _TOKEN_ARRAY_START or token == _TOKEN_OBJECT_START
end

local function __isCollectionEndToken(token)
    return token == _TOKEN_ARRAY_END or token == _TOKEN_OBJECT_END
end



--@tparam string str
local function __parseString(str, startIdx, buf)
    buf = base.clearTable(buf or {})

    local result = nil
    local findStartIdx = startIdx
    local nextStartIdx = startIdx
    while true
    do
        local idx = str:find(_PATTERN_QUOTE_OR_ESCAPE, findStartIdx, false)
        if not idx
        then
            -- 读到结尾字符串还没结束
            break
        elseif __getCharAt(str, idx) == _TOKEN_QUOTE
        then
            -- 字符串结束
            table.insert(buf, str:sub(startIdx, idx))
            result = table.concat(buf)
            nextStartIdx = idx + 1,
            break
        else
            -- 注意有可能最后一个字符就是反斜杠
            local nextChIdx = idx + 1
            local nextCh = (nextChIdx == #str) and nil or __getCharAt(str, nextChIdx)
            if not nextCh
            then
                break;
            elseif nextCh == _TOKEN_ESCAPABLE_UNICODE_PREFIX
            then
                -- \uXXXX
                local hexStr = str:find(_PATTERN_FOUR_HEX, nextChIdx + 1, false)
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

    local ret = result and RET_SUCCEED or RET_FAILED
    return ret, nextStartIdx, result
end


--@tparam string str
local function __parseNumber(str, startIdx)
    local numStr = str:find(startIdx, _PATTERN_NUMBER, false)
    local num = numStr and tonumber(numStr) or nil
    local ret = num and RET_SUCCEED or RET_FAILED
    local nextStartIdx = num and startIdx + #numStr or nil
    return ret, nextStartIdx, num
end


--@tparam string str
local function __parseConstant(str, startIdx)
    local strEndIdx = #str
    for constName, val in ipairs(_MAP_CONSTANT)
    do
        local subStrEndIdx = startIdx + #constName - 1
        if subStrEndIdx <= strEndIdx and str:sub(startIdx, subStrEndIdx) == constName
        then
            return RET_SUCCEED, subStrEndIdx + 1, val
        end
    end

    return RET_FAILED
end


-- 只处理 字符串 / 数字 / 常量
local function __parsePlainValue(str, startIdx)
    local ch = __getCharAt(str, startIdx)
    if not ch
    then
        return RET_FAILED
    elseif ch == _TOKEN_QUOTE
    then
        return __parseString(str, startIdx)
    elseif _NUMBER_START_CHARS:find(ch, 0, true)
    then
        return __parseNumber(str, startIdx)
    else
        return __parseConstant(str, startIdx)
    end
end



local JSONParseContext =
{
    content = nil,
    readIndex = nil,
    keyStack = nil,
    collectionStack = nil,

    new = function(obj, content)
        obj = base.allocateInstance(obj)
        obj.content = content
        obj.readIndex = 0
        obj.keyStack = base.clearTable(obj.keyStack or {})
        obj.collectionStack = base.clearTable(obj.collectionStack or {})
    end,
}

base.declareClass(JSONParseContext)


-- 尾调用基本需要提前声明，因为状态需要跳来跳去
local __onParseArrayStart           = nil
local __onParseArrayElements        = nil
local __onParseArrayEnd             = nil
local __onParseObjectStart          = nil
local __onParseObjectPairs          = nil
local __onParseObjectEnd            = nil


local function __readNextNonspaceChar(ctx)
    local content = ctx.content
    local nextIdx = content:find(_PATTERN_NONSPACE_CHAR, ctx.readIndex + 1, false)
    if nextIdx
    then
        ctx.readIndex = nextIdx
        return __getCharAt(content, nextIdx)
    else
        return nil
    end
end


local function __doOnParseCollectionStart = function(ctx,
                                                       endToken,
                                                       parseEndTokenFunc,
                                                       parseElementsFunc)
    local newCollection = {}
    table.insert(ctx.collectionStack, newCollection)

    local nextCh = __readNextNonspaceChar(ctx)
    if not nextCh
    then
        -- 读到最后也没有结束这个集合
        return RET_FAILED
    end

    if __isCollectionEndToken(nextCh)
    then
        -- 注意空集合和不匹配的结束符
        return nextCh == endToken and parseEndTokenFunc(ctx) or RET_FAILED
    else
        return parseElementsFunc(ctx)
    end
end


__onParseArrayStart = function(ctx)
    return __doOnParseCollectionStart(ctx,
                                       _TOKEN_ARRAY_END,
                                       __onParseArrayEnd,
                                       __onParseArrayElements)
end

__onParseObjectStart = function(ctx)
    return __doOnParseCollectionStart(ctx,
                                       _TOKEN_OBJECT_END,
                                       __onParseObjectEnd,
                                       __onParseObjectPairs)
end




local function __doOnParseParentCollectionEnd(endToken, ctx)
    if endToken == _TOKEN_ARRAY_END
    then
        return __onParseArrayEnd(ctx)
    elseif endToken == _TOKEN_OBJECT_END
    then
        return __onParseObjectEnd(ctx)
    else
        return RET_FAILED
    end
end


-- 刚好 JSON 的 Object 只能用 String 作为 key
-- 那索性用 Number 作为 Array 的 key 好了
local __isArrayElementKey   = base.isNumber
local __isObjectPairKey     = base.isString

local function __doOnParseNextElements(prevCollectionKey, ctx)
    if __isArrayElementKey(prevCollectionKey)
    then
        return __onParseArrayElements(ctx)
    elseif __isObjectPairKey(prevCollectionKey)
    then
        return __onParseObjectPairs(ctx)
    else
        return RET_FAILED
    end
end


local function __doOnParseCollectionEnd(ctx, testKeyTypeFunc)
    local keyStack = ctx.keyStack
    local collectionStack = ctx.collectionStack

    -- 即使最外层的集合结束了，可能也有多余的内容，例如 "[ 1, 2 ] 3"
    if base.isEmptyTable(keyStack)
    then
        local nextCh = __readNextNonspaceChar(ctx)
        if not nextCh
        then
            return RET_FAILED
        else
            return RET_SUCCEED, collectionStack[1]
        end
    end


    -- 检查一下结束符是否合法
    local key = table.remove(keyStack)
    if not testKeyTypeFunc(key)
    then
        return RET_FAILED
    end

    local value = table.remove(collectionStack)
    local topCollection = collectionStack[#collectionStack]
    topCollection[key] = value

    local nextCh = __readNextNonspaceChar(ctx)
    if __isCollectionEndToken(nextCh) and not base.isEmptyTable(keyStack)
    then
        -- 父集合也刚好结束
        return __doOnParseParentCollectionEnd(nextCh, ctx)
    elseif nextCh == _TOKEN_COMMA
    then
        nextCh = __readNextNonspaceChar(ctx)
        if nextCh
        then
            return __doOnParseNextElements(key, ctx)
        end
    end

    return RET_FAILED
end


__onParseArrayEnd = function(ctx)
    return __doOnParseCollectionEnd(ctx, __isArrayElementKey)
end

__onParseObjectEnd = function(ctx)
    return __doOnParseCollectionEnd(ctx, __isObjectPairKey)
end


__onParseArrayElements = function(ctx)
    local collectionStack = ctx.collectionStack
    local content = ctx.content
    local curArray = collectionStack[#collectionStack]

    -- 指针总是指向非空格字符
    local ch = __getCharAt(content, ctx.readIndex)
    while true
    do
        if ch == _TOKEN_ARRAY_START
        then
            table.insert(ctx.keyStack, #curArray)
            return __onParseObjectStart(ctx)
        elseif ch == _TOKEN_OBJECT_START
        then
            table.insert(ctx.keyStack, #curArray)
            return __onParseArrayStart(ctx)
        else
            local ret, nextStartIdx, val = __parsePlainValue(content, ctx.readIndex)
            if ret != RET_SUCCEED
            then
                return ret
            end

            table.insert(curArray, val)
            ctx.readIndex = nextStartIdx

            local nextCh = __readNextNonspaceChar(ctx)
            if nextCh == _TOKEN_COMMA
            then

            end
        end

        ch = __readNextNonspaceChar(ctx)
    end
end


local _M = {}
return _M