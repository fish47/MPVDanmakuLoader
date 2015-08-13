local utils = require('src/utils')          --= utils utils
local asswriter = require('src/asswriter')  --= asswriter asswriter


local _Danmaku =
{
    text = nil,         -- 评论内容，以 utf8 编码
    startTime = nil,    -- 弹幕起始时间，单位 ms
    lifeTime = nil,     -- 弹幕存活时间，单位 ms
    fontSize = nil,     -- 字体大小，单位 pt
    fontColor = nil,    -- 字体颜色字符串，格式 BBGGRR
}

utils.declareClass(_Danmaku)


local DanmakuParseContext =
{
    pool = nil,
    screenWidth = nil,
    screenHeight = nil,
    bottomReserved = nil,

    defaultFontSize = nil,
    defaultFontName = nil,
    defaultFontColor = nil,

    defaultSRTFontSize = nil,
    defaultSRTFontName = nil,
    defaultSRTFontColor = nil,


    new = function(obj)
        obj = utils.allocateInstance(obj)
        obj.pool =
        {
            [asswriter.LAYER_MOVING_L2R]    = {},
            [asswriter.LAYER_MOVING_R2L]    = {},
            [asswriter.LAYER_STATIC_TOP]    = {},
            [asswriter.LAYER_STATIC_BOTTOM] = {},
            [asswriter.LAYER_ADVANCED]      = {},
            [asswriter.LAYER_SUBTITLE]      = {},
        }
        return obj
    end,


    dispose = function(self)
        if self.pool
        then
            for k in next(self.pool)
            do
                utils.clearTable(self.pool[k])
            end

            utils.clearTable(self.pool)
        end
    end,
}

utils.declareClass(DanmakuParseContext)



local _NEWLINE_STR          = "\n"
local _NEWLINE_CODEPOINT    = string.byte(_NEWLINE_STR)

local function _measureDanmakuText(text, fontSize)
    local lineCount = 1
    local lineCharCount = 0
    local maxLineCharCount = 0
    for _, codePoint in utils.iterateUTF8CodePoints(text)
    do
        if codePoint == _NEWLINE_CODEPOINT
        then
            lineCount = lineCount + 1
            maxLineCharCount = math.max(maxLineCharCount, lineCharCount)
            lineCharCount = 0
        end

        lineCharCount = lineCharCount + 1
    end

    -- 可能没有回车符
    maxLineCharCount = math.max(maxLineCharCount, lineCharCount)

    -- 字体高度系数一般是 1.0 左右
    -- 字体宽度系数一般是 1.0 ~ 0.6 左右
    -- 就以最坏的情况来算吧
    local width = maxLineCharCount * fontSize
    local height = lineCount * fontSize
    return width, height
end


return
{
    _NEWLINE_STR            = _NEWLINE_STR,
    _measureDanmakuText     = _measureDanmakuText,
    _Danmaku                = _Danmaku,
    DanmakuParseContext     = DanmakuParseContext,
}