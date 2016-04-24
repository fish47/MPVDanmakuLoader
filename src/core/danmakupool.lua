local _ass              = require("src/core/_ass")
local _writer           = require("src/core/_writer")
local _coreconstants    = require("src/core/_coreconstants")
local types             = require("src/base/types")
local utils             = require("src/base/utils")
local constants         = require("src/base/constants")
local classlite         = require("src/base/classlite")
local danmaku           = require("src/core/danmaku")


local DanmakuPool =
{
    _mDanmakuDataArrays     = classlite.declareTableField(),
    _mDanmakuIndexes        = classlite.declareTableField(),
    _mAddDanmakuHook        = classlite.declareConstantField(nil),
    __mCompareFunc          = classlite.declareConstantField(nil),

    new = function(self)
        local arrays = self._mDanmakuDataArrays
        for i = 1, _coreconstants._DANMAKU_IDX_MAX
        do
            arrays[i] = {}
        end

        self.__mCompareFunc = function(idx1, idx2)
            local function __compareString(str1, str2)
                if str1 == str2
                then
                    return 0
                else
                    return str1 < str2 and -1 or 1
                end
            end


            local ret = 0
            local arrays = self._mDanmakuDataArrays
            local startTimes = arrays[_coreconstants._DANMAKU_IDX_START_TIME]
            local sourceIDs = arrays[_coreconstants._DANMAKU_IDX_SOURCE_ID]
            local danmakuIDs = arrays[_coreconstants._DANMAKU_IDX_DANMAKU_ID]
            ret = ret ~= 0 and ret or startTimes[idx1] - startTimes[idx2]
            ret = ret ~= 0 and ret or sourceIDs[idx1]._index - sourceIDs[idx2]._index
            ret = ret ~= 0 and ret or __compareString(danmakuIDs[idx1], danmakuIDs[idx2])
            return ret < 0
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

    getDanmakuByIndex = function(self, idx, outData)
        local sortedIdx = self._mDanmakuIndexes[idx]
        outData:_readFromDanmakuPool(self._mDanmakuDataArrays, sortedIdx)
    end,


    addDanmaku = function(self, danmakuData)
        local hook = self._mAddDanmakuHook
        if hook and not hook(danmakuData)
        then
            return
        end

        if danmakuData:_isValid()
        then
            danmakuData:_appendToDanmakuPool(self._mDanmakuDataArrays)
            table.insert(self._mDanmakuIndexes, self:getDanmakuCount() + 1)
        end
    end,


    freeze = function(self)
        local arrays = self._mDanmakuDataArrays
        local sourceIDs = arrays[_coreconstants._DANMAKU_IDX_SOURCE_ID]
        local danmakuIDs = arrays[_coreconstants._DANMAKU_IDX_DANMAKU_ID]
        local indexes = self._mDanmakuIndexes
        table.sort(indexes, self.__mCompareFunc)

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
        utils.clearArray(indexes, writeIdx)
        for i = 1, _coreconstants._DANMAKU_IDX_MAX
        do
            utils.clearArray(arrays[i], writeIdx)
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
    _mPools         = classlite.declareTableField(),
    _mWriter        = classlite.declareClassField(_writer.DanmakuWriter),
    _mSourceIDPool  = classlite.declareTableField(),
    _mSourceIDCount = classlite.declareConstantField(0),

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
        utils.forEachArrayElement(self._mSourceIDPool, utils.disposeSafely)
        self:clear()
    end,

    iteratePools = function(self)
        return ipairs(self._mPools)
    end,

    getDanmakuPoolByLayer = function(self, layer)
        return layer and self._mPools[layer]
    end,

    allocateDanmakuSourceID = function(self, pluginName, videoID, partIdx, offset, filePath)
        local sourceIDPool = self._mSourceIDPool
        local sourceIDCount = self._mSourceIDCount
        local sourceID = sourceIDPool[sourceIDCount]
        if not sourceID
        then
            sourceID = danmaku.DanmakuSourceID:new()
            sourceIDPool[sourceIDCount] = sourceID
        end

        sourceID._index = sourceIDCount
        sourceID.pluginName = pluginName
        sourceID.videoID = videoID
        sourceID.videoPartIndex = partIdx
        sourceID.startTimeOffset = offset
        sourceID.filePath = filePath

        -- 有可能之前就生成过
        for i = 1, sourceIDCount
        do
            local iterSourceID = sourceIDPool[i]
            if iterSourceID:_isSame(sourceID)
            then
                return iterSourceID
            end
        end

        self._mSourceIDCount = sourceIDCount + 1
        return sourceID
    end,

    writeDanmakus = function(self, app, f)
        local cfg = app:getConfiguration()
        local width = app:getVideoWidth()
        local height = app:getVideoHeight()
        return self._mWriter:writeDanmakus(self, cfg, width, height, f)
    end,

    clear = function(self)
        self._mSourceIDCount = 0
        utils.forEachTableValue(self._mPools, DanmakuPool.clear)
    end,
}

classlite.declareClass(DanmakuPools)


return
{
    LAYER_MOVING_L2R        = _coreconstants.LAYER_MOVING_L2R,
    LAYER_MOVING_R2L        = _coreconstants.LAYER_MOVING_R2L,
    LAYER_STATIC_TOP        = _coreconstants.LAYER_STATIC_TOP,
    LAYER_STATIC_BOTTOM     = _coreconstants.LAYER_STATIC_BOTTOM,
    LAYER_ADVANCED          = _coreconstants.LAYER_ADVANCED,
    LAYER_SUBTITLE          = _coreconstants.LAYER_SUBTITLE,
    LAYER_SKIPPED           = _coreconstants.LAYER_SKIPPED,

    DanmakuPools            = DanmakuPools,
}
