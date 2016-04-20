local _ass              = require("src/core/_ass")
local _coreconstants    = require("src/core/_coreconstants")
local _writer           = require("src/core/_writer")
local types             = require("src/base/types")
local utils             = require("src/base/utils")
local constants         = require("src/base/constants")
local classlite         = require("src/base/classlite")


local DanmakuPool =
{
    _mDanmakuDataArrays     = classlite.declareTableField(),
    _mDanmakuIndexes        = classlite.declareTableField(),
    _mAddDanmakuHook        = classlite.declareConstantField(nil),


    new = function(self)
        local arrays = self._mDanmakuDataArrays
        for i = 1, _coreconstants.DANMAKU_IDX_MAX
        do
            arrays[i] = {}
        end
    end,

    dispose = function(self)
        self:clear()
    end,

    setAddDanmakuHook = function(self, hook)
        self._mAddDanmakuHook = types.isFunction(hook) and hook
    end,

    getDanmakuCount = function(self)
        return #self._mDanmakuIndexes
    end,

    getDanmakuByIndex = function(self, idx, outArray)
        idx = types.isNumber(idx) and self._mDanmakuIndexes[idx]
        if idx and types.isTable(outArray)
        then
            local arrays = self._mDanmakuDataArrays
            for i = 1, _coreconstants.DANMAKU_IDX_MAX
            do
                table.insert(outArray, arrays[i][idx])
            end
        end
    end,


    freeze = function(self)
        local arrays = self._mDanmakuDataArrays
        local startTimes = arrays[_coreconstants.DANMAKU_IDX_START_TIME]
        local sourceIDs = arrays[_coreconstants.DANMAKU_IDX_SOURCE_ID]
        local danmakuIDs = arrays[_coreconstants.DANMAKU_IDX_DANMAKU_ID]
        local indexes = self._mDanmakuIndexes
        utils.clearTable(indexes)
        utils.fillArrayWithAscNumbers(indexes, #sourceIDs)

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
            ret = ret ~= 0 and ret or __compareString(sourceIDs[idx1], sourceIDs[idx2])
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
            local curSource = sourceIDs[i]
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


    addDanmaku = function(self, danmakuData)
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


        local hook = self._mAddDanmakuHook
        if hook and not hook(danmakuData)
        then
            return
        end

        if danmakuData[_coreconstants.DANMAKU_IDX_SOURCE_ID]
            and danmakuData[_coreconstants.DANMAKU_IDX_DANMAKU_ID]
            and types.isString(danmakuData[_coreconstants.DANMAKU_IDX_TEXT])
            and __checkArgs(types.isNumber,
                            danmakuData[_coreconstants.DANMAKU_IDX_START_TIME],
                            danmakuData[_coreconstants.DANMAKU_IDX_LIFE_TIME],
                            danmakuData[_coreconstants.DANMAKU_IDX_FONT_COLOR],
                            danmakuData[_coreconstants.DANMAKU_IDX_FONT_SIZE])
        then
            local arrays = self._mDanmakuDataArrays
            for i = 1, _coreconstants.DANMAKU_IDX_MAX
            do
                table.insert(arrays[i], danmakuData[i])
            end

            local indexes = self._mDanmakuIndexes
            table.insert(indexes, #indexes + 1)
        end
    end,


    clear = function(self)
        utils.forEachTableValue(self._mDanmakuDataArrays, utils.clearTable)
        utils.clearTable(self._mDanmakuIndexes)
    end,
}

classlite.declareClass(DanmakuPool)


local DanmakuPools =
{
    _mPools     = classlite.declareTableField(),
    _mWriter    = classlite.declareClassField(_writer.DanmakuWriter),

    new = function(self)
        local pools = self._mPools
        pools[_coreconstants.LAYER_MOVING_L2R]      = DanmakuPool:new()
        pools[_coreconstants.LAYER_MOVING_R2L]      = DanmakuPool:new()
        pools[_coreconstants.LAYER_STATIC_TOP]      = DanmakuPool:new()
        pools[_coreconstants.LAYER_STATIC_BOTTOM]   = DanmakuPool:new()
        pools[_coreconstants.LAYER_ADVANCED]        = DanmakuPool:new()
        pools[_coreconstants.LAYER_SUBTITLE]        = DanmakuPool:new()
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


local __exports =
{
    DanmakuPool             = DanmakuPool,
    DanmakuPools            = DanmakuPools,
}

utils.mergeTable(__exports, _coreconstants)
return __exports
