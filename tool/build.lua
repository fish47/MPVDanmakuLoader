local _filelist     = require("tool/_filelist")


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


local function __doAppendFile(outFile, path, content)
    _writeFileTag(outFile, _STR_FMT_FILE_SEPARATOR_TAG_STRAT:format(path))
    outFile:write(content)
    _writeFileTag(outFile, _STR_FMT_FILE_SEPARATOR_TAG_END:format(path))
end


local function __readFile(path)
    local f = io.open(path)
    if f
    then
        local content = f:read("*a")
        f:close()
        return content
    end
end

local function __writeModuleString(outFile, path, content)
    if path and content
    then
        local requirePath = path:match(_STR_PATTERN_STRIP_SUFFIX)
        funcName = path:gsub(_STR_MODULE_FUNC_NAME_PATTERN, _STR_MODULE_FUNC_NAME_REPLACE)
        local startTag = _STR_MODULE_CONTENT_START:format(requirePath, funcName)
        local endTag = _STR_MODULE_CONTENT_END:format(funcName)
        outFile:write(startTag)
        __doAppendFile(outFile, path, content)
        outFile:write(endTag)
    end
end

local function __writeModuleFile(outFile, path)
    __writeModuleString(outFile, path, __readFile(path))
end

local function _writeMain(outFile, path)
    local content = __readFile(path)
    if content
    then
        __doAppendFile(outFile, path, content)
    end
end

local function _writeTemplate(outFile, path, substitutions)
    local function __compareReplaceItem(item1, item2)
        local start1 = item1[3]
        local start2 = item2[3]
        local end1 = item1[4]
        local end2 = item2[4]
        return (start1 < start2 or end1 < end2)
    end

    local function __appendStringPiece(buf, piece, startIdx, endIdx)
        if not piece
        then
            return
        end

        if startIdx and endIdx
        then
            if startIdx >= endIdx
            then
                return
            else
                piece = piece:sub(startIdx, endIdx - 1)
            end
        end

        table.insert(buf, piece)
    end

    local replaceItems = {}
    local content = __readFile(path)
    if content
    then
        for k, v in pairs(substitutions)
        do
            local startIdx, lastIdx = content:find(k, 0, true)
            if startIdx
            then
                table.insert(replaceItems, { k, v, startIdx, lastIdx + 1 })
            end
        end

        local lastEndIdx = 0
        local buf = {}
        table.sort(replaceItems, __compareReplaceItem)
        for _, item in ipairs(replaceItems)
        do
            local _, path, itemStart, itemEnd = table.unpack(item)
            if itemStart >= lastEndIdx
            then
                __appendStringPiece(buf, content, lastEndIdx, itemStart)
                __appendStringPiece(buf, __readFile(path))
                lastEndIdx = itemEnd
            end
        end
        __appendStringPiece(buf, content, lastEndIdx, #content + 1)
        __writeModuleString(outFile, path, table.concat(buf))
    end
end

local function main()
    local function __writeFiles(f, func, paths)
        for _, v in ipairs(paths)
        do
            func(f, v)
        end
    end

    local function __writeTemplates(f, paths)
        for path, substitutions in pairs(paths)
        do
            _writeTemplate(f, path, substitutions)
        end
    end

    local destFile = io.stdout
    destFile:write(_STR_MERGE_FILES_START)
    __writeFiles(destFile, __writeModuleFile, _filelist.FILE_LIST_SRC_PRIVATE)
    __writeFiles(destFile, __writeModuleFile, _filelist.FILE_LIST_SRC_PUBLIC)
    __writeTemplates(destFile, _filelist.FILE_LIST_TEMPLATE)
    destFile:write(_STR_MERGE_FILES_END)
    __writeFiles(destFile, _writeMain, _filelist.FILE_LIST_SRC_MAIN)
    destFile:close()
end

main()