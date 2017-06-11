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
    _mDanmakuDataArrays         = classlite.declareTableField(),
    _mDanmakuIndexes            = classlite.declareTableField(),
    _mModifyDanmakuDataHook     = classlite.declareConstantField(nil),
    __mCompareFunc              = classlite.declareConstantField(nil),
}

function DanmakuPool:new()
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
        ret = ret ~= 0 and ret or sourceIDs[idx1]._value - sourceIDs[idx2]._value
        ret = ret ~= 0 and ret or __compareString(danmakuIDs[idx1], danmakuIDs[idx2])
        return ret < 0
    end
end

function DanmakuPool:dispose()
    self:clear()
end

function DanmakuPool:setModifyDanmakuDataHook(hook)
    self._mModifyDanmakuDataHook = types.isFunction(hook) and hook
end

function DanmakuPool:getDanmakuCount()
    return #self._mDanmakuIndexes
end

function DanmakuPool:getDanmakuByIndex(idx, outData)
    local sortedIdx = self._mDanmakuIndexes[idx]
    outData:_readFromDanmakuPool(self._mDanmakuDataArrays, sortedIdx)
end


function DanmakuPool:addDanmaku(danmakuData)
    -- 钩子函数返回 true 才认为是过滤，因为 pcall 返回 false 表示调用失败
    local hook = self._mModifyDanmakuDataHook
    if hook and pcall(hook, danmakuData)
    then
        return
    end

    if danmakuData:_isValid()
    then
        danmakuData:_appendToDanmakuPool(self._mDanmakuDataArrays)
        table.insert(self._mDanmakuIndexes, self:getDanmakuCount() + 1)
    end
end


function DanmakuPool:freeze()
    local arrays = self._mDanmakuDataArrays
    local sourceIDs = arrays[_coreconstants._DANMAKU_IDX_SOURCE_ID]
    local danmakuIDs = arrays[_coreconstants._DANMAKU_IDX_DANMAKU_ID]
    local indexes = self._mDanmakuIndexes
    table.sort(indexes, self.__mCompareFunc)

    -- 去重
    local writeIdx = 1
    local prevDanmakuID = nil
    local prevSourceIDValue = math.huge
    for _, idx in ipairs(indexes)
    do
        local curDanmakuID = danmakuIDs[idx]
        local curSourceIDValue = sourceIDs[idx]._value
        if curDanmakuID ~= prevDanmakuID or curSourceIDValue ~= prevSourceIDValue
        then
            indexes[writeIdx] = idx
            writeIdx = writeIdx + 1
            prevDanmakuID = curDanmakuID
            prevSourceIDValue = curSourceIDValue
        end
    end

    -- 如果有重复数组长度会比原来的短，不要删平行数组的数据，因为索引没整理过
    utils.clearArray(indexes, writeIdx)
end


function DanmakuPool:clear()
    utils.forEachTableValue(self._mDanmakuDataArrays, utils.clearTable)
    utils.clearTable(self._mDanmakuIndexes)
end

classlite.declareClass(DanmakuPool)


local DanmakuPools =
{
    _mPools                 = classlite.declareTableField(),
    _mWriter                = classlite.declareClassField(_writer.DanmakuWriter),
    _mSourceIDPool          = classlite.declareTableField(),
    _mSourceIDCount         = classlite.declareConstantField(0),
    _mCompareSourceIDHook   = classlite.declareConstantField(nil),
}

function DanmakuPools:new()
    local pools = self._mPools
    pools[_coreconstants.LAYER_MOVING_L2R]      = DanmakuPool:new()
    pools[_coreconstants.LAYER_MOVING_R2L]      = DanmakuPool:new()
    pools[_coreconstants.LAYER_STATIC_TOP]      = DanmakuPool:new()
    pools[_coreconstants.LAYER_STATIC_BOTTOM]   = DanmakuPool:new()
    pools[_coreconstants.LAYER_ADVANCED]        = DanmakuPool:new()
    pools[_coreconstants.LAYER_SUBTITLE]        = DanmakuPool:new()
end

function DanmakuPools:dispose()
    utils.forEachArrayElement(self._mSourceIDPool, utils.disposeSafely)
    self:clear()
end

function DanmakuPools:setCompareSourceIDHook(hook)
    self._mCompareSourceIDHook = types.isFunction(hook) and hook
end

function DanmakuPools:iteratePools()
    return ipairs(self._mPools)
end

function DanmakuPools:getDanmakuPoolByLayer(layer)
    return layer and self._mPools[layer]
end

function DanmakuPools:allocateDanmakuSourceID(pluginName, videoID, partIdx,
                                              offset, filePath)
    local function __iterateSourceIDs(pool, count, hook, arg, sourceID)
        for i = 1, count
        do
            local iterSourceID = pool[i]
            if hook(arg, sourceID, iterSourceID)
            then
                sourceID._value = iterSourceID._value
                return iterSourceID
            end
        end
    end

    local function __checkIsSame(_, sourceID, iterSourceID)
        return iterSourceID:_isSame(sourceID)
    end

    local function __checkIsSameByHook(hook, sourceID, iterSouceID)
        return pcall(hook, sourceID, iterSouceID)
    end


    local pool = self._mSourceIDPool
    local count = self._mSourceIDCount
    local sourceID = pool[count]
    if not sourceID
    then
        sourceID = danmaku.DanmakuSourceID:new()
        pool[count] = sourceID
    end

    sourceID.pluginName = pluginName
    sourceID.videoID = videoID
    sourceID.videoPartIndex = partIdx
    sourceID.startTimeOffset = offset
    sourceID.filePath = filePath

    -- 有可能之前就构造过一模一样的实例
    local ret1 = __iterateSourceIDs(pool, count, __checkIsSame, nil, sourceID)
    if ret1
    then
        return ret1
    end

    -- 例如同一个 cid 的不同历史版本，虽然文件路径不同，但也应被认为是同一个弹幕源
    local hook = self._mCompareSourceIDHook
    local ret2 = hook and __iterateSourceIDs(pool, count, __checkIsSameByHook, hook, sourceID)
    if ret2
    then
        return ret2
    end

    self._mSourceIDCount = count + 1
    return sourceID
end

function DanmakuPools:writeDanmakus(app, f)
    local cfg = app:getConfiguration()
    local width = cfg.danmakuResolutionX
    local height = cfg.danmakuResolutionY
    return self._mWriter:writeDanmakus(self, cfg, width, height, f)
end

function DanmakuPools:clear()
    self._mSourceIDCount = 0
    utils.forEachTableValue(self._mPools, DanmakuPool.clear)
end

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
