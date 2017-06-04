local _filelist = require("tool/_filelist")


local _SNIPPET_CONST_NEWLINE    = "\n"
local _SNIPPET_CONST_ENTRY_SEP  = ","
local _SNIPPET_DOCUMENT_START   = "{"
local _SNIPPET_DOCUMENT_END     = "}"
local _SNIPPET_ENTRY_SEP        = ","
local _SNIPPET_ENTRY_FORMAT     = [[    "%s" :
    {
        "prefix" : "%s",
        "body" : [ "%s" ],
        "description" : "%s"
    }]]

local _SNIPPET_ENTRY_DEFINIATIONS =
{
    { "__mdl_file_path_%d",         "File Path (Project)" },
    { "__mdl_self_method_%d",       "Instance Method (Project)" },
    { "__mdl_export_symbols_%d",    "Module Symbols (Project)" },
}

local _SNIPPET_ENTRY_DEFINIATION_IDX_KEY_FMT        = 1
local _SNIPPET_ENTRY_DEFINIATION_IDX_DESCRIPTION    = 2

local _SNIPPET_REGEX_MODULE_NAME    = ".-/?([_a-zA-Z]+)%.lua"
local _SNIPPET_REGEX_REQUIRE_NAME   = "(.*)%.lua"

local _SNIPPET_ENTRY_EXPORT_MODULE_SYMBOL_FMT   = "%s.%s"
local _SNIPPET_ENTRY_EXPORT_SELF_METHOD_FMT     = "self:%s"
local _SNIPPET_ENTRY_EXPORT_FILE_PATH_FMT       = '"%s"'

local _JSON_STRING_ESCAPE_CHAR_MATCH_PATTERN        = "[\\\"]"
local _JSON_STRING_ESCAPE_CHAR_SUBSTITUTE_PATTERN   = "\\%1"

local _WRITE_CTX_FILE_PATH_POOL         = 1
local _WRITE_CTX_SELF_METHOD_POOL       = 2
local _WRITE_CTX_EXPORT_SYMBOL_POOL     = 3
local _WRITE_CTX_POOL_COUNT             = 3

local function __isTable(obj)
    return type(obj) == "table"
end

local function __isFunction(obj)
    return type(obj) == "function"
end

local function __isString(obj)
    return type(obj) == "string"
end

local function __isPublicSymbol(name)
    return __isString(name) and #name > 0 and name:sub(1, 1) ~= "_"
end

local function __escapeJSONString(str)
    return str:gsub(_JSON_STRING_ESCAPE_CHAR_MATCH_PATTERN,
                    _JSON_STRING_ESCAPE_CHAR_SUBSTITUTE_PATTERN)
end

local function __exportEntry(f, ctx, defIdx, val, idx, isFirst)
    local def = _SNIPPET_ENTRY_DEFINIATIONS[defIdx]
    local desc = def[_SNIPPET_ENTRY_DEFINIATION_IDX_DESCRIPTION]
    local key = def[_SNIPPET_ENTRY_DEFINIATION_IDX_KEY_FMT]:format(idx)
    if not isFirst
    then
        f:write(_SNIPPET_CONST_ENTRY_SEP)
    end
    f:write(_SNIPPET_CONST_NEWLINE)

    key = __escapeJSONString(key)
    val = __escapeJSONString(val)
    desc = __escapeJSONString(desc)
    f:write(_SNIPPET_ENTRY_FORMAT:format(key, val, val, desc))
end

local function _accumulateFilePath(ctx, path)
    local snippet = _SNIPPET_ENTRY_EXPORT_FILE_PATH_FMT:format(path)
    ctx[_WRITE_CTX_FILE_PATH_POOL][snippet] = true
end

local function _accumulateSelfMethods(ctx, clzName, clz)
    if not __isString(clzName)
        or not __isPublicSymbol(clzName)
        or not __isTable(clz)
    then
        return
    end

    local pool = ctx[_WRITE_CTX_SELF_METHOD_POOL]
    for k, v in pairs(clz)
    do
        if __isPublicSymbol(k) and __isFunction(v)
        then
            local method = _SNIPPET_ENTRY_EXPORT_SELF_METHOD_FMT:format(k)
            pool[method] = clzName
        end
    end
end

local function _accumulateModuleSymbol(ctx, moduleName, symbolName)
    if __isPublicSymbol(moduleName) and __isPublicSymbol(symbolName)
    then
        local snippet = _SNIPPET_ENTRY_EXPORT_MODULE_SYMBOL_FMT:format(moduleName, symbolName)
        ctx[_WRITE_CTX_EXPORT_SYMBOL_POOL][snippet] = moduleName
    end
end

local function _accumulateSnippets(ctx, path)
    local name = path:match(_SNIPPET_REGEX_MODULE_NAME)
    if not name
    then
        return
    end

    local requireName = path:match(_SNIPPET_REGEX_REQUIRE_NAME) or path
    local module = require(requireName)
    if not __isTable(module)
    then
        return
    end

    _accumulateFilePath(ctx, path)
    for k, v in pairs(module)
    do
        _accumulateModuleSymbol(ctx, name, k)
        _accumulateSelfMethods(ctx, k, v)
    end
end

local function main()
    local function __accumulteSnippetsForFilePaths(ctx, paths)
        for _, path in ipairs(paths)
        do
            _accumulateSnippets(ctx, path)
        end
    end

    local function __writeSnippetPool(f, ctx, idx, isFirst)
        local pool = ctx[idx]
        local snippetIdx = 0
        for k, _ in pairs(pool)
        do
            __exportEntry(f, ctx, idx, k, snippetIdx, isFirst)
            snippetIdx = snippetIdx + 1
            isFirst = false
        end
    end

    local function __writeSnippetDocument(f, ctx)
        local isFirst = true
        f:write(_SNIPPET_DOCUMENT_START)
        for idx = 1, _WRITE_CTX_POOL_COUNT
        do
            isFirst = __writeSnippetPool(f, ctx, idx, isFirst)
        end
        f:write(_SNIPPET_CONST_NEWLINE)
        f:write(_SNIPPET_DOCUMENT_END)
    end

    local ctx = {}
    ctx[_WRITE_CTX_FILE_PATH_POOL] = {}
    ctx[_WRITE_CTX_SELF_METHOD_POOL] = {}
    ctx[_WRITE_CTX_EXPORT_SYMBOL_POOL] = {}
    __accumulteSnippetsForFilePaths(ctx, _filelist.FILE_LIST_SRC_PUBLIC)

    local f = io.stdout
    __writeSnippetDocument(f, ctx)
    f:close()
end

main()