local utils     = require("src/base/utils")
local types     = require("src/base/types")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _ASS_CONST_SEP_FIELD              = ", "
local _ASS_CONST_SEP_KEY_VALUE          = ": "
local _ASS_CONST_SEP_LINE               = "\n"
local _ASS_CONST_HEADER_NAME_START      = "["
local _ASS_CONST_HEADER_NAME_END        = "]"
local _ASS_CONST_STYLE_START            = "{"
local _ASS_CONST_STYLE_END              = "}"

local _ASS_CONST_BOOL_TRUE              = "-1"
local _ASS_CONST_BOOL_FALSE             = "0"

local _ASS_CONST_FMT_INT                = "%d"
local _ASS_CONST_FMT_COLOR_ABGR         = "&H%02X%02X%02X%02X"
local _ASS_CONST_FMT_DIALOGUE_TIME      = "%d:%02d:%05.02f"

local _ASS_CONST_STYLENAME_DANMAKU      = "_mdl_default"
local _ASS_CONST_STYLENAME_SUBTITLE     = "_mdl_subtitle"

local _ASS_CONST_MOD_COLOR_RGB          = 0xFFFFFF + 1

local _ASS_HEADERNAME_SCRIPT_INFO       = "Script Info"
local _ASS_HEADERNAME_STYLES            = "V4+ Styles"
local _ASS_HEADERNAME_EVENTS_           = "Events"

local _ASS_KEYNAME_SCRIPTINFO_WIDTH     = "PlayResX"
local _ASS_KEYNAME_SCRIPTINFO_HEIGHT    = "PlayResY"
local _ASS_KEYNAME_STYLE_FORMAT         = "Format"
local _ASS_KEYNAME_STYLE_STYLE          = "Style"
local _ASS_KEYNAME_EVENTS_FORMAT        = "Format"
local _ASS_KEYNAME_EVENTS_DIALOGUE      = "Dialogue"

local _ASS_VALNAME_STYLE_STYLENAME      = "Name"
local _ASS_VALNAME_STYLE_FONTNAME       = "Fontname"
local _ASS_VALNAME_STYLE_FONTSIZE       = "Fontsize"
local _ASS_VALNAME_STYLE_FONTCOLOR      = "PrimaryColour"

local _ASS_ARRAY_EVENTS_KEYNAMES        = { "Layer", "Start", "End", "Style", "Text" }

local __gStyleData      = {}
local __gWriteFields    = {}


local function _convertARGBHexToABGRColorString(num)
    local a, r, g, b = utils.splitARGBHex(num)
    return string.format(_ASS_CONST_FMT_COLOR_ABGR, a, b, g, r)
end

local function _convertNumberToIntString(num)
    return string.format(_ASS_CONST_FMT_INT, math.floor(num))
end

local function _convertBoolToASSBoolString(val)
    return types.chooseValue(val, _ASS_CONST_BOOL_TRUE, _ASS_CONST_BOOL_FALSE)
end

local function _convertNonEmptyString(val)
    return types.chooseValue(types.isNonEmptyString(val), val, nil)
end

local function _createIntValidator(minVal, maxVal)
    return utils.createIntValidator(nil, nil, minVal, maxVal)
end


local _VALIDATOR_POSITIVE_INT   = utils.createIntValidator(nil, nil, 0)
local _VALIDATOR_SCALE_PERCENT  = utils.createIntValidator(nil, nil, 0, 100)
local _VALIDATOR_ASS_BOOL       = utils.createSimpleValidator(types.toBoolean, _convertBoolToASSBoolString)
local _VALIDATOR_ASS_COLOR      = utils.createIntValidator(types.toInt, _convertNumberToIntString)
local _VALIDATOR_STRING         = utils.createSimpleValidator(_convertNonEmptyString)


local _ASS_CONST_STYLE_DEF_IDX_VALIDATOR    = 1
local _ASS_CONST_STYLE_DEF_IDX_DANMAKU      = 2
local _ASS_CONST_STYLE_DEF_IDX_SUBTITLE     = 3


local _ASS_PAIRS_SCRIPT_INFO_CONTENT =
{
    "Script Updated By",    "MPVDanmakuLoader",
    "ScriptType",           "v4.00+",
    "Collisions",           "Normal",
    "WrapStyle",            "2",
}


-- 弹幕样式抄自 https://github.com/cnbeining/Biligrab/blob/master/danmaku2ass2.py
-- 字幕样式抄自 http://www.zimuku.net/detail/45087.html
local _ASS_PAIRS_STYLE_DEFINITIONS =
{
    _ASS_VALNAME_STYLE_STYLENAME,   { _VALIDATOR_STRING,                _ASS_CONST_STYLENAME_DANMAKU,   _ASS_CONST_STYLENAME_SUBTITLE, },
    _ASS_VALNAME_STYLE_FONTNAME,    { _VALIDATOR_STRING,                "sans-serif",                   "mono",                        },
    _ASS_VALNAME_STYLE_FONTSIZE,    { _createIntValidator(1),           34,                             34,                            },
    _ASS_VALNAME_STYLE_FONTCOLOR,   { _VALIDATOR_ASS_COLOR,             0x33FFFFFF,                     0x00FFFFFF,                    },
    "SecondaryColour",              { _VALIDATOR_ASS_COLOR,             0x33FFFFFF,                     0xFF000000,                    },
    "OutlineColour",                { _VALIDATOR_ASS_COLOR,             0x33000000,                     0x0000336C,                    },
    "BackColour",                   { _VALIDATOR_ASS_COLOR,             0x33000000,                     0x00000000,                    },
    "Bold",                         { _VALIDATOR_ASS_BOOL,              false,                          false,                         },
    "Italic",                       { _VALIDATOR_ASS_BOOL,              false,                          false,                         },
    "Underline",                    { _VALIDATOR_ASS_BOOL,              false,                          false,                         },
    "StrikeOut",                    { _VALIDATOR_ASS_BOOL,              false,                          false,                         },
    "ScaleX",                       { _VALIDATOR_SCALE_PERCENT,         100,                            100                            },
    "ScaleY",                       { _VALIDATOR_SCALE_PERCENT,         100,                            100                            },
    "Spacing",                      { _VALIDATOR_POSITIVE_INT,          0,                              0,                             },
    "Angle",                        { _createIntValidator(0, 360),      0,                              0,                             },
    "BorderStyle",                  { _createIntValidator(1, 3),        1,                              1,                             },
    "Outline",                      { _createIntValidator(0, 4),        1,                              2,                             },
    "Shadow",                       { _createIntValidator(0, 4),        0,                              1,                             },
    "Alignment",                    { _createIntValidator(1, 9),        7,                              2,                             },
    "MarginL",                      { _VALIDATOR_POSITIVE_INT,          0,                              5,                             },
    "MarginR",                      { _VALIDATOR_POSITIVE_INT,          0,                              5,                             },
    "MarginV",                      { _VALIDATOR_POSITIVE_INT,          0,                              8,                             },
    "Encoding",                     { _VALIDATOR_POSITIVE_INT,          0,                              0,                             },
}


local function _writeKeyValue(f, k, v)
    f:write(k, _ASS_CONST_SEP_KEY_VALUE, v, _ASS_CONST_SEP_LINE)
end


local function _writeHeader(f, name)
    f:write(_ASS_CONST_HEADER_NAME_START, name, _ASS_CONST_HEADER_NAME_END)
    f:write(_ASS_CONST_SEP_LINE)
end


local function writeScriptInfo(f, width, height)
    _writeHeader(f, _ASS_HEADERNAME_SCRIPT_INFO)

    for _, k, v in utils.iteratePairsArray(_ASS_PAIRS_SCRIPT_INFO_CONTENT)
    do
        _writeKeyValue(f, k, v)
    end

    _writeKeyValue(f, _ASS_KEYNAME_SCRIPTINFO_WIDTH, _convertNumberToIntString(width))
    _writeKeyValue(f, _ASS_KEYNAME_SCRIPTINFO_HEIGHT, _convertNumberToIntString(height))

    f:write(_ASS_CONST_SEP_LINE)
end


local function _writeFields(f, fields)
    for i, field in ipairs(fields)
    do
        -- 仅在元素之前加分割符
        if i ~= 1
        then
            f:write(_ASS_CONST_SEP_FIELD)
        end

        f:write(field)
    end
    f:write(_ASS_CONST_SEP_LINE)
end


local function writeStyleHeader(f)
    local styleNames = utils.clearTable(__gWriteFields)
    for _, name in utils.iteratePairsArray(_ASS_PAIRS_STYLE_DEFINITIONS)
    do
        table.insert(styleNames, name)
    end
    _writeHeader(f, _ASS_HEADERNAME_STYLES)
    f:write(_ASS_KEYNAME_STYLE_FORMAT)
    f:write(_ASS_CONST_SEP_KEY_VALUE)
    _writeFields(f, styleNames)
    utils.clearTable(styleNames)
end


local function writeEventsHeader(f)
    f:write(_ASS_CONST_SEP_LINE)
    _writeHeader(f, _ASS_HEADERNAME_EVENTS_)
    f:write(_ASS_KEYNAME_EVENTS_FORMAT, _ASS_CONST_SEP_KEY_VALUE)
    _writeFields(f, _ASS_ARRAY_EVENTS_KEYNAMES)
end


local function __createWriteStyleFunction(styleIdx)
    local ret = function(f, fontName, fontSize, fontColor)
        local styleData = utils.clearTable(__gStyleData)
        styleData[_ASS_VALNAME_STYLE_FONTNAME] = fontName
        styleData[_ASS_VALNAME_STYLE_FONTCOLOR] = fontColor
        styleData[_ASS_VALNAME_STYLE_FONTSIZE] = fontSize

        local styleValues = utils.clearTable(__gWriteFields)
        for _, name, defData in utils.iteratePairsArray(_ASS_PAIRS_STYLE_DEFINITIONS)
        do
            local validator = defData[_ASS_CONST_STYLE_DEF_IDX_VALIDATOR]
            local defaultValue = defData[styleIdx]
            local value = validator(styleData[name], defaultValue)
            table.insert(styleValues, value)
        end

        f:write(_ASS_KEYNAME_STYLE_STYLE)
        f:write(_ASS_CONST_SEP_KEY_VALUE)
        _writeFields(f, styleValues)
        utils.clearTable(styleData)
        utils.clearTable(styleValues)
    end
    return ret
end


local function __convertTimeToTimeString(builder, time)
    if types.isNumber(time)
    then
        local h, m, s = utils.convertTimeToHMS(time)
        return string.format(_ASS_CONST_FMT_DIALOGUE_TIME, h, m, s)
    end
end

local function __toASSEscapedString(builder, val)
    return types.isString(val) and utils.escapeASSString(val)
end

local function __toIntNumberString(builder, val)
    return types.isNumber(val) and _convertNumberToIntString(val)
end

local function __toNonDefaultFontSize(builder, fontSize)
    return types.isNumber(fontSize)
        and fontSize ~= builder._mDefaultFontSize
        and _convertNumberToIntString(fontSize)
end

local function __toNonDefaultFontColor(builder, fontColor)
    local function __getRGBHex(num)
        return types.isNumber(num) and math.floor(num % _ASS_CONST_MOD_COLOR_RGB)
    end

    return types.isNumber(fontColor)
        and __getRGBHex(fontColor) ~= __getRGBHex(builder._mDefaultFontColor)
        and _convertARGBHexToABGRColorString(fontColor)
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
                val = arg and param(self, arg)
                argIdx = argIdx + 1
            end

            if not val
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
    _mStyleName             = classlite.declareConstantField(nil),
    _mDefaultFontColor      = classlite.declareConstantField(nil),
    _mDefaultFontSize       = classlite.declareConstantField(nil),

    __doInitStyle = function(self, idx)
        local function __getStyleDefinitionValue(name, styleIdx)
            local found, idx = utils.linearSearchArray(_ASS_PAIRS_STYLE_DEFINITIONS, name)
            return found and _ASS_PAIRS_STYLE_DEFINITIONS[idx + 1][styleIdx]
        end

        self._mStyleName        = __getStyleDefinitionValue(_ASS_VALNAME_STYLE_STYLENAME, idx)
        self._mDefaultFontColor = __getStyleDefinitionValue(_ASS_VALNAME_STYLE_FONTCOLOR, idx)
        self._mDefaultFontSize  = __getStyleDefinitionValue(_ASS_VALNAME_STYLE_FONTSIZE, idx)
    end,

    initDanmakuStyle = function(self)
        self:__doInitStyle(_ASS_CONST_STYLE_DEF_IDX_DANMAKU)
    end,

    initSubtitleStyle = function(self)
        self:__doInitStyle(_ASS_CONST_STYLE_DEF_IDX_SUBTITLE)
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

    startDialogue = function(self, layer, startTime, endTime)
        return self:__doStartDialogue(layer, startTime, endTime, self._mStyleName)
    end,


    __doStartDialogue       = __createBuilderMethod(_ASS_KEYNAME_EVENTS_DIALOGUE,
                                                    _ASS_CONST_SEP_KEY_VALUE,
                                                    __toIntNumberString,        -- layer
                                                    _ASS_CONST_SEP_FIELD,
                                                    __convertTimeToTimeString,  -- startTime
                                                    _ASS_CONST_SEP_FIELD,
                                                    __convertTimeToTimeString,  -- endTime
                                                    _ASS_CONST_SEP_FIELD,
                                                    __toASSEscapedString,       -- styleName
                                                    _ASS_CONST_SEP_FIELD),

    endDialogue             = __createBuilderMethod(_ASS_CONST_SEP_LINE),

    startStyle              = __createBuilderMethod(_ASS_CONST_STYLE_START),

    endStyle                = __createBuilderMethod(_ASS_CONST_STYLE_END),

    addText                 = __createBuilderMethod(__toASSEscapedString),

    addTopCenterAlign       = __createBuilderMethod("\\an8"),

    addBottomCenterAlign    = __createBuilderMethod("\\an2"),

    addMove                 = __createBuilderMethod("\\move(",
                                                    __toIntNumberString,        -- startX
                                                    _ASS_CONST_SEP_FIELD,
                                                    __toIntNumberString,        -- startY
                                                    _ASS_CONST_SEP_FIELD,
                                                    __toIntNumberString,        -- endX
                                                    _ASS_CONST_SEP_FIELD,
                                                    __toIntNumberString,
                                                    ")"),

    addPos                  = __createBuilderMethod("\\pos(",
                                                    __toIntNumberString,        -- x
                                                    _ASS_CONST_SEP_FIELD,
                                                    __toIntNumberString,        -- y
                                                    ")"),

    addFontColor            = __createBuilderMethod("\\c",
                                                    __toNonDefaultFontColor,    -- rgb
                                                    "&"),

    addFontSize             = __createBuilderMethod("\\fs",
                                                    __toNonDefaultFontSize),    -- fontSize
}

classlite.declareClass(DialogueBuilder)


return
{
    writeScriptInfo         = writeScriptInfo,
    writeStyleHeader        = writeStyleHeader,
    writeDanmakuStyle       = __createWriteStyleFunction(_ASS_CONST_STYLE_DEF_IDX_DANMAKU),
    writeSubtitleStyle      = __createWriteStyleFunction(_ASS_CONST_STYLE_DEF_IDX_SUBTITLE),
    writeEventsHeader       = writeEventsHeader,
    DialogueBuilder         = DialogueBuilder,
}
