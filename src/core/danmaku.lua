local _ass      = require("src/core/_ass")
local _writer   = require("src/core/_writer")
local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local DanmakuPool =
{
    _mStartTimes        = classlite.declareTableField(),    -- 弹幕起始时间，单位 ms
    _mLifeTimes         = classlite.declareTableField(),    -- 弹幕存活时间，单位 ms
    _mFontColors        = classlite.declareTableField(),    -- 字体颜色字符串，格式 BBGGRR
    _mFontSizes         = classlite.declareTableField(),    -- 字体大小，单位 pt
    _mDanmakuSources    = classlite.declareTableField(),    -- 弹幕源
    _mDanmakuIDs        = classlite.declareTableField(),    -- 如果来自于相同弹幕源，以此去重
    _mTexts             = classlite.declareTableField(),    -- 评论内容，以 utf8 编码
    _mDanmakuCount      = classlite.declareConstantField(0),


    sortDanmakusByStartTime = function(self)
        utils.sortParallelArrays(self._mStartTimes,
                                 self._mLifeTimes,
                                 self._mFontColors,
                                 self._mFontSizes,
                                 self._mDanmakuSources,
                                 self._mDanmakuIDs,
                                 self._mTexts)
    end,


    getDanmakuAt = function(self, idx)
        if 1 <= idx and idx <= self._mDanmakuCount
        then
            return self._mStartTimes[idx],
                   self._mLifeTimes[idx],
                   self._mFontColors[idx],
                   self._mFontSizes[idx],
                   self._mDanmakuSources[idx],
                   self._mDanmakuIDs[idx],
                   self._mTexts[idx]

        end
    end,


    getDanmakuCount = function(self)
        return self._mDanmakuCount
    end,


    addDanmaku = function(self, startTime, lifeTime, color, size, source, id, text)
        -- 防止因为空值而数组对不齐
        local idx = self:getDanmakuCount() + 1
        self._mStartTimes[idx]      = startTime
        self._mLifeTimes[idx]       = lifeTime
        self._mFontColors[idx]      = color
        self._mFontSizes[idx]       = size
        self._mDanmakuSources[idx]  = source
        self._mDanmakuIDs[idx]      = id
        self._mTexts[idx]           = text
        self._mDanmakuCount = self._mDanmakuCount + 1
    end,


    clear = function(self)
        utils.clearTable(self._mStartTimes)
        utils.clearTable(self._mLifeTimes)
        utils.clearTable(self._mFontColors)
        utils.clearTable(self._mFontSizes)
        utils.clearTable(self._mDanmakuSources)
        utils.clearTable(self._mDanmakuIDs)
        utils.clearTable(self._mTexts)
    end,
}

classlite.declareClass(DanmakuPool)


local DanmakuPools =
{
    _mPools     = classlite.declareTableField(),
    _mWriter    = classlite.declareClassField(_writer.DanmakuWriter),

    new = function(self)
        local pools = self._mPools
        pools[_ass.LAYER_MOVING_L2R]    = DanmakuPool:new()
        pools[_ass.LAYER_MOVING_R2L]    = DanmakuPool:new()
        pools[_ass.LAYER_STATIC_TOP]    = DanmakuPool:new()
        pools[_ass.LAYER_STATIC_BOTTOM] = DanmakuPool:new()
        pools[_ass.LAYER_ADVANCED]      = DanmakuPool:new()
        pools[_ass.LAYER_SUBTITLE]      = DanmakuPool:new()
    end,

    dispose = function(self)
        self:clear()
    end,

    getDanmakuPoolByLayer = function(self, layer)
        return self._mPools[layer]
    end,

    writeDanmakus = function(self, app, f)
        local cfg = app:getConfiguration()
        self._mWriter:writeDanmakus(self, cfg, app:getVideoWidth(), app:getVideoHeight(), f)
    end,

    clear = function(self)
        utils.forEachTableValue(self._mPools, DanmakuPool.clear)
    end,
}

classlite.declareClass(DanmakuPools)


return
{
    LAYER_MOVING_L2R        = _ass.LAYER_MOVING_L2R,
    LAYER_MOVING_R2L        = _ass.LAYER_MOVING_R2L,
    LAYER_STATIC_TOP        = _ass.LAYER_STATIC_TOP,
    LAYER_STATIC_BOTTOM     = _ass.LAYER_STATIC_BOTTOM,
    LAYER_ADVANCED          = _ass.LAYER_ADVANCED,
    LAYER_SUBTITLE          = _ass.LAYER_SUBTITLE,

    DanmakuPool             = DanmakuPool,
    DanmakuPools            = DanmakuPools,
}