local utils = require('src/utils')  --= utils utils


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
    "Script Updated By",    "MpvDanmakuLoader",
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


local LAYER_MOVING_L2R      = 6
local LAYER_MOVING_R2L      = 5
local LAYER_STATIC_TOP      = 4
local LAYER_STATIC_BOTTOM   = 3
local LAYER_ADVANCED        = 2
local LAYER_SUBTITLE        = 1



local DialogueBuilder =
{
    _mContent = nil,

    new = function(obj)
        obj = utils.allocateInstance(obj)
        obj._mContent = {}
        return obj
    end,

    startDialogue = function(self, layer, startTime, endTime)
        local content = self._mContent

        table.insert(content, _ASS_EVENTS_KEYNAME_DIALOGUE)
        table.insert(content, _ASS_SEP_KEY_VALUE)

        table.insert(content, layer)
        table.insert(content, _ASS_SEP_FIELD)

        table.insert(content, utils.convertTimeToHHMMSS(startTime))
        table.insert(content, _ASS_SEP_FIELD)

        table.insert(content, utils.convertTimeToHHMMSS(endTime))
        table.insert(content, _ASS_SEP_FIELD)

        table.insert(content, _STYLE_NAME_MDL)
        table.insert(content, _ASS_SEP_FIELD)
    end,


    endDialogue = function(self)
        table.insert(self._mContent, _ASS_SEP_LINE)
    end,

    startStyle = function(self)
        table.insert(self._mContent, _ASS_STYLE_START)
    end,

    endStyle = function(self)
        table.insert(self._mContent, _ASS_STYLE_END)
    end,

    addText = function(self, text)
        table.insert(self._mContent, utils.escapeASSText(text))
    end,

    addMove = function(self, startX, startY, endX, endY)
        local str = string.format("\\move(%d, %d, %d, %d)",
                                  math.floor(startX), math.floor(startY),
                                  math.floor(endX), math.floor(endY))
        table.insert(self._mContent, str)
    end,

    addTopCenterAlign = function(self)
        table.insert(self._mContent, "\\an8")
    end,

    addBottomCenterAlign = function(self)
        table.insert(self._mContent, "\\an2")
    end,

    addPos = function(self, x, y)
        table.insert(self._mContent, string.format("\\pos(%d, %d)", math.floor(x), math.floor(y)))
    end,

    addFontColor = function(self, bgrHexStr)
        if bgrHexStr
        then
            table.insert(self._mContent, "\\c&H")
            table.insert(self._mContent, bgrHexStr)
            table.insert(self._mContent, "&")
        end
    end,

    addFontSize = function(self, fontSize)
        if fontSize
        then
            table.insert(self._mContent, "\\fs")
            table.insert(self._mContent, tostring(fontSize))
        end
    end,

    flush = function(self, f)
        local content = self._mContent
        local contentLen = #content
        for i = 1, contentLen
        do
            f:write(content[i])
            content[i] = nil
        end
    end,
}

utils.declareClass(DialogueBuilder)


return
{
    LAYER_MOVING_L2R    = LAYER_MOVING_L2R,
    LAYER_MOVING_R2L    = LAYER_MOVING_R2L,
    LAYER_STATIC_TOP    = LAYER_STATIC_TOP,
    LAYER_STATIC_BOTTOM = LAYER_STATIC_BOTTOM,
    LAYER_ADVANCED      = LAYER_ADVANCED,
    LAYER_SUBTITLE      = LAYER_SUBTITLE,

    writeScriptInfo     = writeScriptInfo,
    writeStyle          = writeStyle,
    writeEvents         = writeEvents,

    DialogueBuilder     = DialogueBuilder,
}