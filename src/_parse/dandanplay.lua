local _base = require('src/_parse/_base')
local utils = require("src/utils")          --= utils utils
local asswriter = require('src/asswriter')  --= asswriter asswriter


local _DDP_KEY_COMMENT_COMMENTS     = "Comments"
local _DDP_KEY_COMMENT_ID           = "CId"
local _DDP_KEY_COMMENT_TIMESTAMP    = "Time"
local _DDP_KEY_COMMENT_MESSAGE      = "Message"
local _DDP_KEY_COMMENT_MODE         = "Mode"
local _DDP_KEY_COMMENT_COLOR        = "Color"

local _DDP_PATTERN_DANMAKU_ID       = "_ddp_%d"

local _DDP_FACTOR_TIME_STAMP        = 1000

local _DDP_POS_MOVING_L2R           = 6
local _DDP_POS_MOVING_R2L           = 1
local _DDP_POS_STATIC_TOP           = 5
local _DDP_POS_STATIC_BOTTOM        = 4

local _DDP_POS_TO_LAYER_MAP     =
{
    [_DDP_POS_MOVING_L2R]       = asswriter.LAYER_MOVING_L2R,
    [_DDP_POS_MOVING_R2L]       = asswriter.LAYER_MOVING_R2L,
    [_DDP_POS_STATIC_TOP]       = asswriter.LAYER_STATIC_TOP,
    [_DDP_POS_STATIC_BOTTOM]    = asswriter.LAYER_STATIC_BOTTOM,
}

local _DDP_LIFETIME_MAP         =
{
    [_DDP_POS_MOVING_L2R]       = _base._LIFETIME_MOVING,
    [_DDP_POS_MOVING_R2L]       = _base._LIFETIME_MOVING,
    [_DDP_POS_STATIC_TOP]       = _base._LIFETIME_STATIC,
    [_DDP_POS_STATIC_BOTTOM]    = _base._LIFETIME_STATIC,
}



local function parseDanDanPlayRawData(rawData, ctx)
    local succed, jsonObj = utils.parseJSON(rawData)
    local comments = succed and jsonObj[_DDP_KEY_COMMENT_COMMENTS]
    if not comments
    then
        return nil
    end

    for _, commentObj in ipairs(comments)
    do
        local commentID = commentObj[_DDP_KEY_COMMENT_ID]
        local startTime = commentObj[_DDP_KEY_COMMENT_TIMESTAMP]
        local message = commentObj[_DDP_KEY_COMMENT_MESSAGE]
        local color = commentObj[_DDP_KEY_COMMENT_COLOR]
        local mode = commentObj[_DDP_KEY_COMMENT_MODE]

        color = color and tonumber(color)
        mode = mode and tonumber(mode)
        startTime = startTime and startTime * _DDP_FACTOR_TIME_STAMP

        local layer = mode and _DDP_POS_TO_LAYER_MAP[mode]
        local lifeTime = mode and _DDP_LIFETIME_MAP[mode]

        if commentID and startTime and message and layer and lifeTime
        then
            -- 重用解释 JSON 时创建的 table ，反正后面也不会用到
            local d = commentObj
            utils.clearTable(d)
            _base._Danmaku.new(d)

            d.text = message
            d.startTime = startTime
            d.lifeTime = lifeTime
            d.fontSize = ctx.defaultFontSize
            d.fontColor = color or ctx.defaultFontColor
            d.danmakuID = string.format(_DDP_PATTERN_DANMAKU_ID, commentID)

            table.insert(ctx.pool[layer], d)
        end
    end

    utils.clearTable(jsonObj)
end


local ctx = _base.DanmakuParseContext:new()
ctx.screenWidth = 1280
ctx.screenHeight = 720
ctx.bottomReserved = 0
ctx.defaultFontName = "文泉驿微米黑"
ctx.defaultFontSize = 34
ctx.defaultFontColor = 0

local f = io.open("/home/fish47/Desktop/danmaku.txt")
local rawData = f:read("*a")
f:close()
parseDanDanPlayRawData(rawData, ctx)

f = io.open("/tmp/1.ass", "w+")
require("src/_parse/writer").writeDanmakus(f, ctx)


return
{
    parseDanDanPlayRawData  = parseDanDanPlayRawData,
}