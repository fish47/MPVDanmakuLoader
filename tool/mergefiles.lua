local _STR_DIST_FILE_NAME               = "mpvdanmakuloader.lua"
local _STR_READ_MODE_LINE_WITH_EOL      = "*L"
local _STR_MODULE_FUNC_NAME_PATTERN     = "/%."
local _STR_MODULE_FUNC_NAME_REPLACE     = "_"

local _STR_MERGE_FILES_START    = [[
local require = nil
require = function(path)

]]

local _STR_MODULE_CONTENT_START = [[
    if path == "%s"
    then
        local module = package.loaded[path]
        if not module
        then
            local function %s()

]]

local _STR_MODULE_CONTENT_END   = [[

            end
            module = %s()
        end
        return module
    end
]]

local _STR_MERGE_FILES_END      = [[

    return _G.require(path)
end

]]


local function __doWriteModule(outFile, path, isMainFile)
    local moduleFile = io.open(path)
    if not moduleFile
    then
        return
    end

    local funcName = nil
    if not isMainFile
    then
        funcName = path:gsub(_STR_MODULE_FUNC_NAME_PATTERN, _STR_MODULE_FUNC_NAME_REPLACE)
        outFile:write(string.format(_STR_MODULE_CONTENT_START, path, funcName))
    end

    while true
    do
        local line = moduleFile:read(_STR_READ_MODE_LINE_WITH_EOL)
        if not line
        then
            moduleFile:close()
            break
        end

        outFile:write(line)
    end

    if not isMainFile
    then
        outFile:write(string.format(_STR_MODULE_CONTENT_END, funcName))
    end
end


local function _writeModule(outFile, path)
    return __doWriteModule(outFile, path, false)
end

local function _writeMain(outFile, path)
    return __doWriteModule(outFile, path, false)
end

local function main()
--    local distFile = io.open(_STR_DIST_FILE_NAME)
    local distFile = io.stdout
    if not distFile
    then
        return
    end

    distFile:write(_STR_MERGE_FILES_START)
    _writeModule(distFile, "src/base/_algo.lua")
    _writeModule(distFile, "src/base/_conv.lua")
--    _writeModule(distFile, "src/base/classlite.lua")
--    _writeModule(distFile, "src/base/constants.lua")
--    _writeModule(distFile, "src/base/serialize.lua")
--    _writeModule(distFile, "src/base/types.lua")
--    _writeModule(distFile, "src/base/unportable.lua")
--    _writeModule(distFile, "src/base/utf8.lua")
--    _writeModule(distFile, "src/base/utils.lua")
    distFile:write(_STR_MERGE_FILES_END)
    distFile:close()
end

main()