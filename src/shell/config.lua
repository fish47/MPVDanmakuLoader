local utils         = require("src/base/utils")
local types         = require("src/base/types")
local unportable    = require("src/base/unportable")


local function _toNonEmptyString(val)
    return types.chooseValue(types.isNonEmptyString(val), val)
end

local _VALIDATOR_BOOL               = utils.createSimpleValidator(types.toBoolean)
local _VALIDATOR_STRING_NULLABLE    = utils.createSimpleValidator(types.tostring)
local _VALIDATOR_STRING_NON_EMPTY   = utils.createSimpleValidator(_toNonEmptyString)
local _VALIDATOR_INT_GE_ZERO        = utils.createIntValidator(types.toInt, nil, 0)
local _VALIDATOR_INT_GE_ONE         = utils.createIntValidator(types.toInt, nil, 1)

local _DEF_IDX_VALIDATOR        = 1
local _DEF_IDX_DEFAULT_VALUE    = 2

local _CONFIGURATION_DEFINATIONS =
{
    "danmakuFontSize",              { _VALIDATOR_INT_GE_ONE,        34 },
    "danmakuFontName",              { _VALIDATOR_STRING_NON_EMPTY,  "sans-serif" },
    "danmakuFontColor",             { _VALIDATOR_INT_GE_ZERO,       0x33FFFFFF },
    "subtitleFontSize",             { _VALIDATOR_INT_GE_ONE,        34 },
    "subtitleFontName",             { _VALIDATOR_STRING_NON_EMPTY,  "mono" },
    "subtitleFontColor",            { _VALIDATOR_INT_GE_ZERO,       0x00FFFFFF },
    "movingDanmakuLifeTime",        { _VALIDATOR_INT_GE_ONE,        8000 },
    "staticDanmakuLIfeTime",        { _VALIDATOR_INT_GE_ONE,        5000 },
    "danmakuResolutionX",           { _VALIDATOR_INT_GE_ONE,        1280 },
    "danmakuResolutionY",           { _VALIDATOR_INT_GE_ONE,        720 },
    "danmakuReservedBottomHeight",  { _VALIDATOR_INT_GE_ZERO,       30 },
    "subtitleReservedBottomHeight", { _VALIDATOR_INT_GE_ZERO,       10 },

    "zenityPath",                   { _VALIDATOR_STRING_NON_EMPTY,  "zenity" },
    "pythonPath",                   { _VALIDATOR_STRING_NON_EMPTY,  "python2" },

    "trashDirPath",                 { _VALIDATOR_STRING_NULLABLE,   nil },
    "privateDataDirName",           { _VALIDATOR_STRING_NULLABLE,   ".mpvdanmakuloader" },
    "hookScriptFileName",           { _VALIDATOR_STRING_NON_EMPTY,  "hook.lua" },
    "rawDataDirName",               { _VALIDATOR_STRING_NON_EMPTY,  "rawdata" },
    "metaDataFileName",             { _VALIDATOR_STRING_NON_EMPTY,  "sourcemeta.lua" },

    "enableDebugLog",               { _VALIDATOR_BOOL,              false },
    "pauseOnPopWindow",             { _VALIDATOR_BOOL,              false },
    "saveGeneratedASS",             { _VALIDATOR_BOOL,              false },
    "networkTimeout",               { _VALIDATOR_INT_GE_ONE,        5 },
    "promptOnReplaceMainSubtitle",  { _VALIDATOR_BOOL,              true }
}

local _CONFIGURATION_HOOK_FUNCTION_NAMES =
{
    "modifyDanmakuDataHook",        -- 修改或过滤此弹幕
    "compareSourceIDHook",          -- 判断弹幕来源是否相同
}


local function _updateConfigurationValues(tbl, options)
    if not types.isTable(table)
    then
        return
    end

    utils.clearTable(tbl)
    for _, key, def in utils.iteratePairsArray(_CONFIGURATION_DEFINATIONS)
    do
        local validator = def[_DEF_IDX_VALIDATOR]
        local defaultVal = def[_DEF_IDX_DEFAULT_VALUE]
        local optionVal = options and options[key] or nil
        local val = validator(optionVal, defaultVal)
        tbl[key] = val
    end
end

local function _updateConfigurationHooks(app, currentDir, tbl)
    local path = unportable.joinPath(currentDir, tbl.hookScriptFileName)
    if app:isExistedFile(path)
    then
        local tmp = {}
        local func = loadfile(path, constants.LOAD_MODE_CHUNKS, _ENV)
        pcall(func, tmp)

        for _, name in ipairs(_CONFIGURATION_HOOK_FUNCTION_NAMES)
        do
            local hook = tmp[name]
            tbl[name] = types.chooseValue(types.isFunction(hook), hook)
        end
    end
end

local function updateConfiguration(app, currentDir, tbl, options)
    _updateConfigurationValues(tbl, options)
    _updateConfigurationHooks(app, currentDir, tbl)
end

local function iterateConfigurationKeys()
    return utils.iteratePairsArray(_CONFIGURATION_DEFINATIONS)
end


return
{
    updateConfiguration         = updateConfiguration,
    iterateConfigurationKeys    = iterateConfigurationKeys,
}