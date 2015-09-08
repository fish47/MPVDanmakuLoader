local utils = require("src/utils")          --= utils utils


local _PATTERN_ID_DDP   = "ddp_%s"
local _PATTERN_ID_BILI  = "bili_%s"
local _PATTERN_ID_LOCAL = "local_%s"

local __IDanmakuSource =
{
    getID = nil,
    getType = nil,
    getTitle = nil,
    getRawData = nil,
}

utils.declareClass(__IDanmakuSource)


local __DanDanPlayDanmakuSource =
{
    _mVideoInfo     = nil,

    new = function(obj, info)
        obj = utils.allocateInstance(obj)
        obj._mVideoInfo = info
        return obj
    end,

    getID = function(self)
        return string.format(_PATTERN_ID_DDP, self._mVideoInfo.danmakuURL)
    end,

    getRawData = function(self)
        return network.getDanDanPlayDanmakuRawData(self._mVideoInfo.danmakuURL)
    end,

    buildItem = function(self, cmdBuilder)
        local info = self._mVideoInfo
        cmdBuilder:addArgument("")
        cmdBuilder:addArgument(info.videoTitle)
        cmdBuilder:addArgument(info.videoSubtitle)
    end,
}

utils.declareClass(__DanDanPlayDanmakuSource, __IDanmakuSource)


local __BiliBiliDanmakuSource =
{}

utils.declareClass(__BiliBiliDanmakuSource, __IDanmakuSource)


local __LocalDanmakuSource =
{
    _mFileName      = nil,
    _mFullPath      = nil,

    new = function(obj, fullPath, fileName)
        obj = utils.allocateInstance(obj)
        obj._mFileName = fileName
        obj._mFullPath = fullPath
        return obj
    end,

    getRawData = function(self)
        local f = io.open(self._mFullPath)
        return utils.readAndClose(f)
    end,
}

utils.declareClass(__LocalDanmakuSource, __IDanmakuSource)


return
{}