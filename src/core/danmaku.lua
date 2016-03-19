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
    _mDanmakuSourceIDs  = classlite.declareTableField(),    -- 弹幕源
    _mDanmakuIDs        = classlite.declareTableField(),    -- 在相同弹幕源前提下的唯一标识
    _mTexts             = classlite.declareTableField(),    -- 评论内容，以 utf8 编码
    _mAddDanmakuHook    = classlite.declareConstantField(nil),
    __mDanmakuIndexes   = classlite.declareTableField(),

    setAddDanmakuHook = function(self, func)
        self._mAddDanmakuHook = types.isFunction(func) and func
    end,

    getDanmakuCount = function(self)
        return #self.__mDanmakuIndexes
    end,


    getDanmakuByIndex = function(self, idx)
        idx = types.isNumber(idx) and self.__mDanmakuIndexes[idx]
        if idx
        then
            return self._mStartTimes[idx],
                self._mLifeTimes[idx],
                self._mFontColors[idx],
                self._mFontSizes[idx],
                self._mDanmakuSourceIDs[idx],
                self._mDanmakuIDs[idx],
                self._mTexts[idx]

        end
    end,


    sortAndTrim = function(self)
        local startTimes = self._mStartTimes
        local sources = self._mDanmakuSourceIDs
        local danmakuIDs = self._mDanmakuIDs
        local indexes = self.__mDanmakuIndexes
        utils.clearTable(indexes)
        utils.fillArrayWithAscNumbers(indexes, #sources)

        local function __cmp(idx1, idx2)
            local function __compareString(str1, str2)
                if str1 == str2
                then
                    return 0
                else
                    return str1 < str2 and -1 or 1
                end
            end

            local ret = 0
            ret = ret ~= 0 and ret or startTimes[idx1] - startTimes[idx2]
            ret = ret ~= 0 and ret or __compareString(sources[idx1], sources[idx2])
            ret = ret ~= 0 and ret or __compareString(danmakuIDs[idx1], danmakuIDs[idx2])
            return ret < 0
        end

        table.sort(indexes, __cmp)

        -- 去重
        local writeIdx = 1
        local prevSource = nil
        local prevDanmakuID = nil
        for i, idx in ipairs(indexes)
        do
            local curSource = sources[i]
            local curDanmakuID = danmakuIDs[i]
            if curSource ~= prevSource or curDanmakuID ~= prevDanmakuID
            then
                indexes[writeIdx] = idx
                writeIdx = writeIdx + 1
                prevSource = curSource
                prevDanmakuID = prevDanmakuID
            end
        end

        -- 如果有重复数组长度会比原来的短
        for i = writeIdx, #indexes
        do
            indexes[i] = nil
        end
    end,


    addDanmaku = function(self, ...)
        local function __checkArgs(checkFunc, ...)
            for i = 1, types.getVarArgCount(...)
            do
                local arg = select(i, ...)
                if not checkFunc(arg)
                then
                    return false
                end
            end
            return true
        end

        local function __unpackAll(...)
            return ...
        end

        local hook = self._mAddDanmakuHook or __unpackAll
        local sourceID, start, life, color, size, danmakuID, text = hook(...)
        if sourceID
            and danmakuID
            and types.isString(text)
            and __checkArgs(types.isNumber, start, life, color, size)
        then
            table.insert(self._mStartTimes, start)
            table.insert(self._mLifeTimes, life)
            table.insert(self._mFontColors, color)
            table.insert(self._mFontSizes, size)
            table.insert(self._mDanmakuSourceIDs, sourceID)
            table.insert(self._mDanmakuIDs, danmakuID)
            table.insert(self._mTexts, text)
            table.insert(self.__mDanmakuIndexes, #self.__mDanmakuIndexes + 1)
        end
    end,


    clear = function(self)
        utils.clearTable(self._mStartTimes)
        utils.clearTable(self._mLifeTimes)
        utils.clearTable(self._mFontColors)
        utils.clearTable(self._mFontSizes)
        utils.clearTable(self._mDanmakuSourceIDs)
        utils.clearTable(self._mDanmakuIDs)
        utils.clearTable(self._mTexts)
        utils.clearTable(self.__mDanmakuIndexes)
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

    iteratePools = function(self)
        return ipairs(self._mPools)
    end,

    getDanmakuPoolByLayer = function(self, layer)
        return layer and self._mPools[layer]
    end,

    writeDanmakus = function(self, app, f)
        local cfg = app:getConfiguration()
        local width = app:getVideoWidth()
        local height = app:getVideoHeight()
        return self._mWriter:writeDanmakus(self, cfg, width, height, f)
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
    LAYER_SKIPPED           = _ass.LAYER_SKIPPED,

    DanmakuPool             = DanmakuPool,
    DanmakuPools            = DanmakuPools,
}