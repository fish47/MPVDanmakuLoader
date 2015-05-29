local base = require('src/base')    --= base base

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


local _PATTERN_NONSPACE_CHAR        = "([^%s])"
local _PATTERN_QUOTE_OR_ESCAPE      = "([\"\\])"
local _PATTERN_FOUR_HEX             = "(%x%x%x%x)"
local _PATTERN_NUMBER               = "%s*(%-?%d+%.?%d*[eE]?[+-]?%d*)"

local _PREFIX_NUMBER_START          = "0123456789-"


local RET_SUCCEED                            = 0
local RET_ERR_STRING_DOES_NOT_TERMINATE      = -1
local RET_ERR_INVALID_ESCAPE_CHAR            = -2
local RET_ERR_INVALID_NUMBER_FORMAT          = -3
local RET_ERR_INVALID_CONSTANT               = -4
local RET_ERR_ARRAY_DOES_NOT_TERMINATE       = -5


local function __getCharAt(str, idx)
    return str:sub(idx, idx + 1)
end


--@tparam string str
local function __parseString(str, startIdx, buf)
    buf = base.clearTable(buf or {})

    local findStartIdx = startIdx
    local nextStartIdx = startIdx
    while true
    do
        local idx = str:find(_PATTERN_QUOTE_OR_ESCAPE, findStartIdx, false)
        if not idx
        then
            -- 读到结尾字符串还没结束
            return RET_ERR_STRING_DOES_NOT_TERMINATE
        elseif __getCharAt(str, idx) == _TOKEN_QUOTE
        then
            -- 字符串结束
            table.insert(str:sub(startIdx, idx))
            nextStartIdx = idx + 1,
            break
        else
            -- 也有可能最后一个字符就是反斜杠
            local nextChIdx = idx + 1
            if nextChIdx == #str
            then
                return RET_ERR_STRING_DOES_NOT_TERMINATE
            end

            local nextCh = __getCharAt(str, nextChIdx)
            if nextCh == _TOKEN_ESCAPABLE_UNICODE_PREFIX
            then
                -- \uXXXX
                local hexString = str:find(_PATTERN_FOUR_HEX, nextChIdx + 1, false)
                if not hexString
                then
                    return RET_ERR_STRING_DOES_NOT_TERMINATE
                end

                --TODO
                findStartIdx = nextChIdx + #hexString + 1
            else
                -- 转义字符
                local ch = _MAP_ESCAPABLE_[nextCh]
                if not ch
                then
                    return RET_ERR_INVALID_ESCAPE_CHAR
                end

                table.insert(buf, ch)
                findStartIdx = nextChIdx + 1
            end

        end
    end

    local ret = table.concat(buf)
    return RET_SUCCEED, nextStartIdx, ret
end


--@tparam string str
local function __parseNumber(str, startIdx)
    local numStr = str:find(startIdx, _PATTERN_NUMBER, false)
    local num = numStr and tonumber(numStr) or nil
    if num
    then
        return RET_SUCCEED, startIdx + #numStr, num
    else
        return RET_ERR_INVALID_NUMBER_FORMAT
    end
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

    return RET_ERR_INVALID_CONSTANT
end


--@tparam string str
local function parse(str)
    local buf = nil
    local keyStack = nil
    local collectionStack = nil
    local startIdx = 0
    while true
    do
        local idx = str:find(_PATTERN_NONSPACE_CHAR, startIdx, false)
        if not idx
        then
            break
        end


        startIdx = idx + 1

        local ch = __getCharAt(str, idx)
        local val = nil
        local ret = nil

        if _PREFIX_NUMBER_START:find(ch)
        then
            asdf
        elseif ch == _TOKEN_LBRACE
        then
            --
        elseif ch == _TOKEN_LBRACE
        then
            --
        elseif ch == _TOKEN_QUOTE
        then
            --
        else
            --
        end
    end

    buf = nil
    keyStack = nil
    collectionStack = nil

end


local _M = {}
return _M