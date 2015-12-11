local utils = require("src/utils")


local _PATTERN_ID_DDP   = "ddp_%s"
local _PATTERN_ID_BILI  = "bili_%s"
local _PATTERN_ID_LOCAL = "local_%s"

local _SRC_TYPE_SRT     = "srt"
local _SRC_TYPE_BILI    = "bili"
local _SRC_TYPE_DDP     = "ddp"


local _IDanmakuSource =
{
    parse           = nil,
    serialize       = nil,
    buildListItem   = nil,
}

utils.declareClass(_IDanmakuSource)


local _SRTDanmakuSource =
{
    _mFilePath      = nil,

    new = function(obj, filePath)
        obj = utils.allocateInstance(obj)
        obj._mFilePath = filePath
        return obj
    end,

    serialize = function(self, outArray)
        table.insert(outArray, _SRC_TYPE_SRT)
        table.insert(outArray, self._mFilePath)
    end,

}

utils.declareClass(_SRTDanmakuSource, _IDanmakuSource)


local _BiliBiliDanmakuSource =
{
    _mFetchDate     = nil,
    _mAVCode        = nil,
}

utils.declareClass(_BiliBiliDanmakuSource, _IDanmakuSource)


local _DanDanPlayDanmkauSource =
{}

utils.declareClass(_DanDanPlayDanmkauSource, _IDanmakuSource)


return
{}