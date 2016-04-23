local _coreconstants    = require("src/core/_coreconstants")
local types             = require("src/base/types")
local classlite         = require("src/base/classlite")


local DanmakuSourceID =
{
    _index          = classlite.declareConstantField(0),
    pluginName      = classlite.declareConstantField(nil),
    videoID         = classlite.declareConstantField(nil),
    videoPartIndex  = classlite.declareConstantField(1),
    startTimeOffset = classlite.declareConstantField(0),
    filePath        = classlite.declareConstantField(nil),

    _isSame = function(self, sourceID)
        if self == sourceID
        then
            return true
        end

        return classlite.isInstanceOf(sourceID, self:getClass())
            and self.pluginName == sourceID.pluginName
            and self.videoID == sourceID.videoID
            and self.videoPartIndex == sourceID.videoPartIndex
            and self.startTimeOffset == sourceID.startTimeOffset
            and self.filePath == sourceID.filePath
    end,
}

classlite.declareClass(DanmakuSourceID)


local DanmakuData =
{
    starTime        = classlite.declareConstantField(0),
    lifeTime        = classlite.declareConstantField(0),
    fontColor       = classlite.declareConstantField(0),
    fontSize        = classlite.declareConstantField(0),
    sourceID        = classlite.declareConstantField(nil),
    danmakuID       = classlite.declareConstantField(nil),
    danmakuText     = classlite.declareConstantField(nil),


    _isValid = function(self)
        return types.isNonNegativeNumber(self.startTime)
            and types.isPositiveNumber(self.lifeTime)
            and types.isNonNegativeNumber(self.fontColor)
            and types.isPositiveNumber(self.fontSize)
            and classlite.isInstanceOf(self.sourceID, DanmakuSourceID)
            and self.danmakuID
            and types.isString(self.danmakuText)
    end,


    _appendToDanmakuPool = function(self, poolArrays)
        table.insert(poolArrays[_coreconstants._DANMAKU_IDX_START_TIME],    self.startTime)
        table.insert(poolArrays[_coreconstants._DANMAKU_IDX_LIFE_TIME],     self.lifeTime)
        table.insert(poolArrays[_coreconstants._DANMAKU_IDX_FONT_COLOR],    self.fontColor)
        table.insert(poolArrays[_coreconstants._DANMAKU_IDX_FONT_SIZE],     self.fontSize)
        table.insert(poolArrays[_coreconstants._DANMAKU_IDX_SOURCE_ID],     self.sourceID)
        table.insert(poolArrays[_coreconstants._DANMAKU_IDX_DANMAKU_ID],    self.danmakuID)
        table.insert(poolArrays[_coreconstants._DANMAKU_IDX_DANMAKU_TEXT],  self.danmakuText)
    end,


    _readFromDanmakuPool = function(self, poolArrays, idx)
        self.startTime      = poolArrays[_coreconstants._DANMAKU_IDX_START_TIME][idx]
        self.lifeTime       = poolArrays[_coreconstants._DANMAKU_IDX_LIFE_TIME][idx]
        self.fontColor      = poolArrays[_coreconstants._DANMAKU_IDX_FONT_COLOR][idx]
        self.fontSize       = poolArrays[_coreconstants._DANMAKU_IDX_FONT_SIZE][idx]
        self.sourceID       = poolArrays[_coreconstants._DANMAKU_IDX_SOURCE_ID][idx]
        self.danmakuID      = poolArrays[_coreconstants._DANMAKU_IDX_DANMAKU_ID][idx]
        self.danmakuText    = poolArrays[_coreconstants._DANMAKU_IDX_DANMAKU_TEXT][idx]
    end,
}

classlite.declareClass(DanmakuData)


return
{
    DanmakuSourceID = DanmakuSourceID,
    DanmakuData     = DanmakuData,
}