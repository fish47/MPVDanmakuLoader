local _CONST_STR_INDENT                 = "    "
local _CONST_STR_EMPTY                  = ""
local _CONST_READ_MODE_LINE_WITH_EOL    = "*L"

local _CONST_INDENT_MODULE_FILE_BLOCK   = 1
local _CONST_INDENT_MODULE_FILE_CONTENT = 4

local _CONST_STR_INNER_REQUIRE_PATTERN  = "/"
local _CONST_STR_INNER_REQUIRE_REPLACE  = "_"

local _PATTERN_LINE_WITH_EOL            = "(.-\r?\n)"


local _STR_REQUIRE_HACK_START   = [[
local require = nil
require = function(path)

]]

local _STR_REQUIRE_HACK_END     = [[

    return _G.require(path)
end
]]


local _STR_MODULE_FILE_START    = [[
if path == "%s"
then
    local module = package.loaded[path]
    if not module
    then
        local function %s()

]]

local _STR_MODULE_FILE_END      = [[

        end
        module = %s()
    end
    return module
end
]]


local function __getInnerRequireFunctionName(path)
    return path:gsub(_CONST_STR_INNER_REQUIRE_PATTERN, _CONST_STR_INNER_REQUIRE_REPLACE)
end


local function __getIndentString(level)
    local indent = _CONST_STR_EMPTY
    for i = 1, level
    do
        indent = indent .. _CONST_STR_INDENT
    end
    return indent
end


local function __writeStringWithIndent(outFile, str, indentLevel)
    local indent = __getIndentString(indentLevel)
    for line in str:gmatch(_PATTERN_LINE)
    do
        outFile:write(indent)
        outFile:write(line)
    end
end


local function _writeModuleFileContent(outFile, filePath, indentLevel)
    local indent = __getIndentString(indentLevel)
    local moduleFile = io.open(filePath)
    while true
    do
        local line = moduleFile:read(_CONST_READ_MODE_LINE_WITH_EOL)
        if not line
        then
            break
        end

        outFile:write(indent)
        outFile:write(line)
    end
    moduleFile:close()
end


local function _writeModule(outFile, filePath)
end