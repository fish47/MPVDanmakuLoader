local _STR_READ_MODE_LINE_WITH_EOL      = "*L"
local _STR_MODULE_FUNC_NAME_PATTERN     = "[/%.]"
local _STR_MODULE_FUNC_NAME_REPLACE     = "_"
local _STR_PATTERN_STRIP_SUFFIX         = "(.*)%.[^%.]-"
local _STR_FMT_FILE_SEPARATOR_TAG_STRAT = " %s <START> "
local _STR_FMT_FILE_SEPARATOR_TAG_END   = " %s <END> "
local _STR_CONST_SEPARATOR              = "-"
local _STR_CONST_EOL                    = "\n"
local _NUM_SEPARATOR_WIDTH              = 80

local _STR_MERGE_FILES_START    = [[
local mp = {}
setmetatable(mp, {
    __index = function(tbl, name)
        local ret = _G["mp"][name] or rawget(tbl, name)
        if ret
        then
            return ret
        end

        if name == "msg"
        then
            ret = require("mp.msg")
        elseif name == "options"
        then
            ret = require("mp.options")
        elseif name == "utils"
        then
            ret = require("mp.utils")
        else
            return ret
        end

        tbl[name] = ret
        return ret
    end,
})


local require = nil
local __loadedModules = {}
require = function(path)

]]

local _STR_MODULE_CONTENT_START = [[
    if path == "%s"
    then
        local requestedModule = __loadedModules[path]
        if not requestedModule
        then
            local function %s()

]]

local _STR_MODULE_CONTENT_END   = [[

            end
            requestedModule = %s()
            __loadedModules[path] = requestedModule
        end
        return requestedModule
    end
]]

local _STR_MERGE_FILES_END      = [[

    return _G.require(path)
end

]]


local function _writeFileTag(outFile, tag)
    local headSepCount = math.floor((_NUM_SEPARATOR_WIDTH - #tag) / 2)
    local tailSepCount = math.max(_NUM_SEPARATOR_WIDTH - headSepCount - #tag, 0)
    outFile:write(_STR_CONST_EOL)
    outFile:write(string.rep(_STR_CONST_SEPARATOR, headSepCount))
    outFile:write(tag)
    outFile:write(string.rep(_STR_CONST_SEPARATOR, tailSepCount))
    outFile:write(_STR_CONST_EOL)
end


local function __doWriteModule(outFile, path, isMainFile)
    local moduleFile = io.open(path)
    if not moduleFile
    then
        return
    end

    local funcName = nil
    if not isMainFile
    then
        local requirePath = path:match(_STR_PATTERN_STRIP_SUFFIX)
        funcName = path:gsub(_STR_MODULE_FUNC_NAME_PATTERN, _STR_MODULE_FUNC_NAME_REPLACE)
        outFile:write(string.format(_STR_MODULE_CONTENT_START, requirePath, funcName))
    end

    local startTag = string.format(_STR_FMT_FILE_SEPARATOR_TAG_STRAT, path)
    _writeFileTag(outFile, startTag)

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

    local endTag = string.format(_STR_FMT_FILE_SEPARATOR_TAG_END, path)
    _writeFileTag(outFile, endTag)

    if not isMainFile
    then
        outFile:write(string.format(_STR_MODULE_CONTENT_END, funcName))
    end
end


local function _writeModule(outFile, path)
    return __doWriteModule(outFile, path, false)
end

local function _writeMain(outFile, path)
    return __doWriteModule(outFile, path, true)
end

local function main()
    local destFile = io.stdout
    local function _addModule(path)
        _writeModule(destFile, path)
    end

    local function _addMain(path)
        _writeMain(destFile, path)
    end

    destFile:write(_STR_MERGE_FILES_START)
    _addModule("src/base/_algo.lua")
    _addModule("src/base/_conv.lua")
    _addModule("src/base/classlite.lua")
    _addModule("src/base/constants.lua")
    _addModule("src/base/serialize.lua")
    _addModule("src/base/types.lua")
    _addModule("src/base/unportable.lua")
    _addModule("src/base/utf8.lua")
    _addModule("src/base/utils.lua")
    _addModule("src/core/_ass.lua")
    _addModule("src/core/_coreconstants.lua")
    _addModule("src/core/_layer.lua")
    _addModule("src/core/_poscalc.lua")
    _addModule("src/core/_writer.lua")
    _addModule("src/core/danmaku.lua")
    _addModule("src/core/danmakupool.lua")
    _addModule("src/plugins/acfun.lua")
    _addModule("src/plugins/bilibili.lua")
    _addModule("src/plugins/dandanplay.lua")
    _addModule("src/plugins/pluginbase.lua")
    _addModule("src/plugins/srt.lua")
    _addModule("src/shell/application.lua")
    _addModule("src/shell/logic.lua")
    _addModule("src/shell/sourcemgr.lua")
    _addModule("src/shell/uiconstants.lua")
    destFile:write(_STR_MERGE_FILES_END)

    _addMain("src/shell/main.lua")
    destFile:close()
end

main()