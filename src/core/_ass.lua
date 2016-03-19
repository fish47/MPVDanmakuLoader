local utils     = require("src/base/utils")
local types     = require("src/base/types")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local LAYER_MOVING_L2R      = 1
local LAYER_MOVING_R2L      = 2
local LAYER_STATIC_TOP      = 3
local LAYER_STATIC_BOTTOM   = 4
local LAYER_ADVANCED        = 5
local LAYER_SUBTITLE        = 6
local LAYER_SKIPPED         = 7


local _ASS_SEP_FIELD            = ", "
local _ASS_SEP_KEY_VALUE        = ": "
local _ASS_SEP_LINE             = "\n"
local _ASS_HEADER_NAME_START    = "["
local _ASS_HEADER_NAME_END      = "]"
local _ASS_STYLE_START          = "{"
local _ASS_STYLE_END            = "}"

local _STYLE_NAME_MDL           = "_mdl_style"


local _ASS_SCRIPT_INFO_HEADERNAME       = "Script Info"
local _ASS_SCRIPT_INFO_KEYNAME_WIDTH    = "PlayResX"
local _ASS_SCRIPT_INFO_KEYNAME_HEIGHT   = "PlayResY"
local _PAIRS_SCRIPT_INFO                =
{
    "Script Updated By",    "MPVDanmakuLoader",
    "ScriptType",           "v4.00+",
    "Collisions",           "Normal",
    "WrapStyle",            "2",
}

local function __writeHeader(f, name)
    f:write(_ASS_HEADER_NAME_START, name, _ASS_HEADER_NAME_END)
    f:write(_ASS_SEP_LINE)
end

local function __writeKeyValue(f, k, v)
    f:write(k, _ASS_SEP_KEY_VALUE, v, _ASS_SEP_LINE)
end

local function writeScriptInfo(f, width, height)
    __writeHeader(f, _ASS_SCRIPT_INFO_HEADERNAME)

    for _, k, v in utils.iteratePairsArray(_PAIRS_SCRIPT_INFO)
    do
        __writeKeyValue(f, k, v)
    end

    __writeKeyValue(f, _ASS_SCRIPT_INFO_KEYNAME_WIDTH, tostring(width))
    __writeKeyValue(f, _ASS_SCRIPT_INFO_KEYNAME_HEIGHT, tostring(height))

    f:write(_ASS_SEP_LINE)
end



local _ASS_STYLE_HEADERNAME                     = "V4+ Styles"
local _ASS_STYLE_KEYNAME_FORMAT                 = "Format"
local _ASS_STYLE_KEYNAME_STYLE                  = "Style"
local _ASS_STYLE_FIELDNAME_FORMAT_STYLE_NAME    = "Name"
local _ASS_STYLE_FIELDNAME_FORMAT_FONT_NAME     = "Fontname"
local _ASS_STYLE_FIELDNAME_FORMAT_FONT_SIZE     = "Fontsize"
local _PAIRS_BASE_STYLE                         =
{
    "PrimaryColour",        "&H33FFFFFF",
    "SecondaryColour",      "&H33FFFFFF",
    "OutlineColour",        "&H33000000",
    "BackColour",           "&H33000000",
    "Bold",                 "0",
    "Italic",               "0",
    "Underline",            "0",
    "StrikeOut",            "0",
    "ScaleX",               "100",
    "ScaleY",               "100",
    "Spacing",              "0.00",
    "Angle",                "0.00",
    "BorderStyle",          "1",
    "Outline",              "1",
    "Shadow",               "0",
    "Alignment",            "7",
    "MarginL",              "0",
    "MarginR",              "0",
    "MarginV",              "0",
    "Encoding",             "0",
}


local function __writeFields(f, array, startIdx, step)
    startIdx = startIdx or 1
    step = step or 1

    local isFirstElem = true
    for i = startIdx, #array, step
    do
        -- 最前最后都不加上分割符
        if isFirstElem
        then
            isFirstElem = false
        else
            f:write(_ASS_SEP_FIELD)
        end

        f:write(array[i])
    end
end


local function writeStyle(f, fontName, fontSize)
    __writeHeader(f, _ASS_STYLE_HEADERNAME)

    f:write(_ASS_STYLE_KEYNAME_FORMAT, _ASS_SEP_KEY_VALUE)
    f:write(_ASS_STYLE_FIELDNAME_FORMAT_STYLE_NAME, _ASS_SEP_FIELD)
    f:write(_ASS_STYLE_FIELDNAME_FORMAT_FONT_NAME, _ASS_SEP_FIELD)
    f:write(_ASS_STYLE_FIELDNAME_FORMAT_FONT_SIZE, _ASS_SEP_FIELD)
    __writeFields(f, _PAIRS_BASE_STYLE, 1, 2)
    f:write(_ASS_SEP_LINE)

    f:write(_ASS_STYLE_KEYNAME_STYLE, _ASS_SEP_KEY_VALUE)
    f:write(_STYLE_NAME_MDL, _ASS_SEP_FIELD)
    f:write(fontName, _ASS_SEP_FIELD)
    f:write(fontSize, _ASS_SEP_FIELD)
    __writeFields(f, _PAIRS_BASE_STYLE, 2, 2)
    f:write(_ASS_SEP_LINE)

    f:write(_ASS_SEP_LINE)
end



local _ASS_EVENTS_HEADER_NAME       = "Events"
local _ASS_EVENTS_KEYNAME_FORMAT    = "Format"
local _ASS_EVENTS_KEYNAME_DIALOGUE  = "Dialogue"
local _ARRAY_EVENTS_FORMAT          =
{
    "Layer", "Start", "End", "Style", "Text"
}

local function writeEvents(f)
    __writeHeader(f, _ASS_EVENTS_HEADER_NAME)

    f:write(_ASS_EVENTS_KEYNAME_FORMAT, _ASS_SEP_KEY_VALUE)
    __writeFields(f, _ARRAY_EVENTS_FORMAT)

    f:write(_ASS_SEP_LINE)
end


local _ASS_DIALOGUE_TIME_FORMAT     = "%d:%02d:%05.02f"

local function __convertTimeToTimeString(builder, time)
    if types.isNumber(time)
    then
        local h, m, s = utils.convertTimeToHMS(time)
        return string.format(_ASS_DIALOGUE_TIME_FORMAT, h, m, s)
    end
end

local function __toNumberString(builder, val)
    return types.isNumber(val) and tostring(math.floor(val))
end

local function __toNonDefaultFontSize(builder, fontSize)
    if types.isNumber(fontSize) and fontSize ~= builder._mDefaultFontSize
    then
        return tostring(fontSize)
    end
end

local function __toNonDefaultFontColor(builder, fontColor)
    if types.isString(fontColor) and fontColor ~= builder._mDefaultFontColor
    then
        return fontColor
    end
end


local function __createBuilderMethod(...)
    local params = { ... }
    local ret = function(self, ...)
        local argIdx = 1
        local contentLastIdxBak = #self._mContent
        for _, param in ipairs(params)
        do
            local val = nil
            if types.isString(param)
            then
                -- 字符常量
                val = param
            elseif types.isFunction(param)
            then
                -- 函数返回值是字符串
                local arg = select(argIdx, ...)
                val = arg and param(arg)
                argIdx = argIdx + 1
            end

            if types.isNil(val)
            then
                -- 只要有一次返回空值，就取消本次写操作
                utils.clearArray(self._mContent, contentLastIdxBak + 1)
                break
            else
                table.insert(self._mContent, val)
            end
        end

        return self
    end

    return ret
end


local DialogueBuilder =
{
    _mContent               = classlite.declareTableField(),
    _mDefaultFontColor      = classlite.declareConstantField(nil),
    _mDefaultFontSize       = classlite.declareConstantField(nil),

    setDefaultFontColor = function(self, fontColor)
        self._mDefaultFontColor = fontColor
    end,

    setDefaultFontSize = function(self, defaultFontSize)
        self._mDefaultFontSize = defaultFontSize
    end,

    clear = function(self)
        utils.clearTable(self._mContent)
    end,

    flushContent = function(self, f)
        local content = self._mContent
        local contentLen = #content
        for i = 1, contentLen
        do
            f:write(content[i])
            content[i] = nil
        end
    end,


    startDialogue           = __createBuilderMethod(_ASS_EVENTS_KEYNAME_DIALOGUE,
                                                    _ASS_SEP_KEY_VALUE,
                                                    __toNumberString,           -- layer
                                                    _ASS_SEP_FIELD,
                                                    __convertTimeToTimeString,  -- startTime
                                                    _ASS_SEP_FIELD,
                                                    __convertTimeToTimeString,  -- endTime
                                                    _ASS_SEP_FIELD,
                                                    _STYLE_NAME_MDL,
                                                    _ASS_SEP_FIELD),

    endDialogue             = __createBuilderMethod(_ASS_SEP_LINE),

    startStyle              = __createBuilderMethod(_ASS_STYLE_START),

    endStyle                = __createBuilderMethod(_ASS_STYLE_START),

    addText                 = __createBuilderMethod(utils.escapeASSString),

    addTopCenterAlign       = __createBuilderMethod("\\an8"),

    addBottomCenterAlign    = __createBuilderMethod("\\an2"),

    addMove                 = __createBuilderMethod("\\move(",
                                                    __toNumberString,   -- startX
                                                    _ASS_SEP_FIELD,
                                                    __toNumberString,   -- startY
                                                    _ASS_SEP_FIELD,
                                                    __toNumberString,   -- endX
                                                    _ASS_SEP_FIELD,
                                                    __toNumberString,
                                                    ")"),

    addPos                  = __createBuilderMethod("\\pos(",
                                                    __toNumberString,   -- x
                                                    _ASS_SEP_FIELD,
                                                    __toNumberString,   -- y
                                                    ")"),

    addFontColor            = __createBuilderMethod("\\c&H",
                                                    __toNonDefaultFontColor     -- bgrHexStr
                                                    "&"),

    addFontSize             = __createBuilderMethod("\\fs",
                                                    __toNonDefaultFontSize),    -- fontSize
}

classlite.declareClass(DialogueBuilder)


return
{
    LAYER_MOVING_L2R        = LAYER_MOVING_L2R,
    LAYER_MOVING_R2L        = LAYER_MOVING_R2L,
    LAYER_STATIC_TOP        = LAYER_STATIC_TOP,
    LAYER_STATIC_BOTTOM     = LAYER_STATIC_BOTTOM,
    LAYER_ADVANCED          = LAYER_ADVANCED,
    LAYER_SUBTITLE          = LAYER_SUBTITLE,
    LAYER_SKIPPED           = LAYER_SKIPPED,

    writeScriptInfo         = writeScriptInfo,
    writeStyle              = writeStyle,
    writeEvents             = writeEvents,

    DialogueBuilder         = DialogueBuilder,
}