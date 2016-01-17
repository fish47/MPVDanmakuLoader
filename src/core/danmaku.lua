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
    _mDanmakuIDs        = classlite.declareTableField(),    -- 如果来自于相同弹幕源，以此作为排重字段
    _mDanmakuSources    = classlite.declareTableField(),    -- 弹幕源
    _mTexts             = classlite.declareTableField(),    -- 评论内容，以 utf8 编码
    __mDanmakuIndexes   = classlite.declareTableField(),


    sortDanmakusByStartTime = function(self)
        -- 在时间相同的情况下，才比较 ID
        local startTimes = self._mStartTimes
        local danmakuIDs = self._mDanmakuIDs
        local function __compareDanmakuAsc(a, b)
            local startTime1 = startTimes[a]
            local startTime2 = startTimes[b]
            if startTime1 == startTime2
            then
                local danmakuID1 = danmakuIDs[a] or constants.STR_EMPTY
                local danmakuID2 = danmakuIDs[b] or constants.STR_EMPTY
                return danmakuID1 < danmakuID2
            else
                return startTime1 < startTime2
            end
        end

        -- 平行数组的元素位置不变，只对"指针数组"排序
        local danmakuCount = self:getDanmakuCount()
        utils.fillArrayWithAscNumbers(self.__mDanmakuIndexes, danmakuCount)
        table.sort(self.__mDanmakuIndexes, __compareDanmakuAsc)
    end,


    getSortedDanmakuAt = function(self, i)
        local rawIdx = self.__mDanmakuIndexes[i]
        if rawIdx
        then
            return self._mStartTimes[rawIdx],
                   self._mLifeTimes[rawIdx],
                   self._mFontColors[rawIdx],
                   self._mFontSizes[rawIdx],
                   self._mDanmakuIDs[rawIdx],
                   self._mTexts[rawIdx]
        else
            return nil
        end
    end,


    getDanmakuCount = function(self)
        return #self.__mDanmakuIndexes
    end,


    addDanmaku = function(self, startTime, lifeTime, color, size, danmakuID, text)
        -- 原则上添加完成后要排序，在此期间不要尝试用索引取弹幕
        local danmakuCount = self:getDanmakuCount()
        local nextDanmakuIdx = danmakuCount + 1
        self.__mDanmakuIndexes[nextDanmakuIdx] = nextDanmakuIdx

        -- 不要用 table.insert() ，不然有空值数组就不对齐了
        self._mStartTimes[nextDanmakuIdx] = startTime
        self._mLifeTimes[nextDanmakuIdx] = lifeTime
        self._mFontColors[nextDanmakuIdx] = color
        self._mDanmakuIDs[nextDanmakuIdx] = danmakuID
        self._mTexts[nextDanmakuIdx] = text
    end,


    clear = function(self)
        for _, name, decl in classlite.iterateClassFields(self:getClass())
        do
            if decl[1] == classlite.FIELD_DECL_TYPE_TABLE
            then
                utils.clearTable(self[name])
            end
        end
    end,
}

classlite.declareClass(DanmakuPool)



local DanmakuPools =
{
    _mPools     = classlite.declareTableField(),
    _mWriter    = classlite.declareClassField(_writer.DanmakuWriter),

    new = function(self)
        self._mPools[_ass.LAYER_MOVING_L2R]     = DanmakuPool:new()
        self._mPools[_ass.LAYER_MOVING_R2L]     = DanmakuPool:new()
        self._mPools[_ass.LAYER_STATIC_TOP]     = DanmakuPool:new()
        self._mPools[_ass.LAYER_STATIC_BOTTOM]  = DanmakuPool:new()
        self._mPools[_ass.LAYER_ADVANCED]       = DanmakuPool:new()
        self._mPools[_ass.LAYER_SUBTITLE]       = DanmakuPool:new()
    end,

    dispose = function(self)
        utils.forEachTableValue(self._mPools, utils.disposeSafely)
    end,

    getDanmakuPoolByLayer = function(self, layer)
        return self._mPools[layer]
    end,

    writeDanmakus = function(self, cfg, screenW, screenH, f)
        if types.isOpenedFile(f)
        then
            self._mWriter:writeDanmakus(self, cfg, screenW, screenH, f)
        end
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
    DanmakuPools            = DanmakuPool,
}