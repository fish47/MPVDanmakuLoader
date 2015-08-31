local utils = require("src/utils")          --= utils utils
local asswriter = require("src/asswriter")  --= asswriter asswriter


local DanmakuPool       =
{
    _mStartTimes        = nil,      -- 弹幕起始时间，单位 ms
    _mLifeTimes         = nil,      -- 弹幕存活时间，单位 ms
    _mFontColors        = nil,      -- 字体颜色字符串，格式 BBGGRR
    _mFontSizes         = nil,      -- 字体大小，单位 pt
    _mDanmakuIDs        = nil,      -- 弹幕标识字符串，用于排重，不可为空
    _mTexts             = nil,      -- 评论内容，以 utf8 编码
    __mSortedIndexes    = nil,


    new = function(obj)
        obj = utils.allocateInstance(obj)
        obj._mStartTimes = {}
        obj._mLifeTimes = {}
        obj._mFontColors = {}
        obj._mFontSizes = {}
        obj._mDanmakuIDs = {}
        obj._mTexts = {}
        obj.__mSortedIndexes = {}
        return obj
    end,


    __reserveSortedIndexes = function(self)
        local count = self:getDanmakuCount()
        local indexes = self.__mSortedIndexes
        for i = 1, count
        do
            indexes[i] = i
        end

        for i = count + 1, #indexes
        do
            indexes[i] = nil
        end

        return self.__mSortedIndexes
    end,


    sortDanmakusByStartTime = function(self)
        -- 时间相同的情况下，才比较弹幕 ID
        local startTimes = self._mStartTimes
        local danmakuIDs = self._mDanmakuIDs
        local function __sort(a, b)
            local startTime1 = startTimes[a]
            local startTime2 = startTimes[b]
            if startTime1 == startTime2
            then
                local danmakuID1 = danmakuIDs[a] or ""
                local danmakuID2 = danmakuIDs[b] or ""
                return danmakuID1 < danmakuID2
            else
                return startTime1 < startTime2
            end
        end

        -- 平行数组的元素位置不变，只对"指针数组"排序
        local pointers = self:__reserveSortedIndexes()
        table.sort(pointers, __sort)
    end,


    getDanmakuCount = function(self)
        return #self._mTexts
    end,


    getSortedDanmakuAt = function(self, i)
        local rawIdx = self.__mSortedIndexes[i]
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


    addDanmaku = function(self, startTime, lifeTime, color, size, danmakuID, text)
        table.insert(self._mStartTimes, startTime)
        table.insert(self._mLifeTimes, lifeTime)
        table.insert(self._mFontColors, color)
        table.insert(self._mFontSizes, size)
        table.insert(self._mDanmakuIDs, danmakuID)
        table.insert(self._mTexts, text)
    end,


    clear = function(self)
        utils.clearTable(self._mStartTimes)
        utils.clearTable(self._mLifeTimes)
        utils.clearTable(self._mFontColors)
        utils.clearTable(self._mFontSizes)
        utils.clearTable(self._mDanmakuIDs)
        utils.clearTable(self._mTexts)
        utils.clearTable(self.__mSortedIndexes)
    end,


    dispose = function(self)
        self:clear()
        utils.clearTable(self)
    end,
}

utils.declareClass(DanmakuPool)



local DanmakuPools  =
{
    _mPools         = nil,


    new = function(obj)
        obj = utils.allocateInstance(obj)
        obj._mPools =
        {
            [asswriter.LAYER_MOVING_L2R]    = DanmakuPool:new(),
            [asswriter.LAYER_MOVING_R2L]    = DanmakuPool:new(),
            [asswriter.LAYER_STATIC_TOP]    = DanmakuPool:new(),
            [asswriter.LAYER_STATIC_BOTTOM] = DanmakuPool:new(),
            [asswriter.LAYER_ADVANCED]      = DanmakuPool:new(),
            [asswriter.LAYER_SUBTITLE]      = DanmakuPool:new(),
        }
    end,


    __doIterateDanmakuPools = function(self, func)
        if self._mPools
        then
            for _, pool in pairs(self._mPools)
            do
                func(pool)
            end
        end
    end,


    getDanmakuPoolByLayer = function(self, layer)
        return self._mPools[layer]
    end,


    clear = function(self)
        self:__doIterateDanmakuPools(DanmakuPool.clear)
    end,


    dispose = function(self)
        self:__doIterateDanmakuPools(DanmakuPool.dispose)
        utils.clearTable(self)
    end,
}



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


local _LIFETIME_STATIC          = 5000
local _LIFETIME_MOVING          = 8000


return
{
    _NEWLINE_STR            = _NEWLINE_STR,
    _LIFETIME_STATIC        = _LIFETIME_STATIC,
    _LIFETIME_MOVING        = _LIFETIME_MOVING,
    _measureDanmakuText     = _measureDanmakuText,
    DanmakuPool             = DanmakuPool,
    DanmakuPools            = DanmakuPool,
}