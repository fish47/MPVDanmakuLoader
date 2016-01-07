local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local srt           = require("src/parse/srt")


local _SOURCE_TYPE_SRT      = "srt"
local _SOURCE_TYPE_BILI     = "bili"
local _SOURCE_TYPE_ACFUN    = "acfun"
local _SOURCE_TYPE_DDP      = "ddp"


local _SOURCE_FMT_SRT       = "srt: %s"

local _SOURCE_DATE_SRT      = 0

local _SOURCE_PATTER_SRT_FILE   = ".*[sS][rR][tT]$"


local __IDanmakuSource =
{
    parse = constants.FUNC_EMPTY,
    getType = constants.FUNC_EMPTY,
    getDate = constants.FUNC_EMPTY,
    getVideoMD5 = constants.FUNC_EMPTY,
    getDescription = constants.FUNC_EMPTY,
    serialize = constants.FUNC_EMPTY,
    deserizlie = constants.FUNC_EMPTY,
}

classlite.declareClass(__IDanmakuSource)


local _SRTDanmakuSource =
{
    _mSRTFilePath   = classlite.declareConstantField(nil),

    _init = function(self, filePath)
        self._mSRTFilePath = filePath
    end,

    parse = function(self, app)
        local file = app:openUTF8File(self._mSRTFilePath)
        if file
        then
            local cfg = app:getConfiguration()
            local pools = app:getDanmakuPools()
            local pool = pools:getDanmakuPoolByLayer(danmaku.LAYER_SUBTITLE)
            local _, fileName = app:splitPath(self._mSRTFilePath)
            srt.parseSRTFile(cfg, pool, file, string.format(_SOURCE_FMT_SRT, fileName))
            file:close()
        end
    end,

    getType = function(self)
        return _SOURCE_TYPE_SRT
    end,

    getDescription = function(self)
        return self._mSRTFilePath
    end,
}

classlite.declareClass(_SRTDanmakuSource, __IDanmakuSource)


local function __writeTupleElement(tuple, idx, element)
    tuple[idx] = element
    return idx + 1
end

local function __readTupleElement(tuple, idx)
    return idx + 1, tuple[idx]
end


local __CachedDanmakuSource =
{
    _mDate          = classlite.declareConstantField(0),
    _mVideoMD5      = classlite.declareConstantField(""),
    _mFilePaths     = classlite.declareTableField(),
    _mTimeOffsets   = classlite.declareTableField(),

    _init = function(self, videoMD5, filePaths, timeOffsets)
        self._mDate = os.time()
        self._mVideoMD5 = videoMD5
        utils.clearTable(self._mFilePaths)
        utils.extendArray(self._mFilePaths, filePaths)
        utils.clearTable(self._mTimeOffsets)
        utils.extendArray(self._mTimeOffsets, timeOffsets)
    end,

    getDate = function(self)
        return self._mDate
    end,

    getVideoMD5 = function(self)
        return self._mVideoMD5
    end,

    _doParse = constants.FUNC_EMPTY,

    parse = function(self, app)
        for i, filePath in ipairs(self._mFilePaths)
        do
            local timeOffset = self._mTimeOffsets[i]
            local danmakuFile = app:openUTF8File(filePath)
            if types.isNumber(timeOffset) and danmakuFile
            then
                self:_doParse(app, danmakuFile, timeOffset)
            end

            if danmakuFile
            then
                danmakuFile:close()
            end
        end
    end,


    serialize = function(self, app, tuple)
        local idx = 1
        idx = __writeTupleElement(tuple, idx, self:getType())
        idx = __writeTupleElement(tuple, idx, self._mVideoMD5)
        idx = __writeTupleElement(tuple, idx, self._mDate)

        -- 弹幕文件路径
        idx = __writeTupleElement(tuple, idx, #self._mFilePaths)
        for _, filePath in ipairs(self._mFilePaths)
        do
            idx = __writeTupleElement(tuple, idx, filePath)
        end

        -- 弹幕时间偏移
        idx = __writeTupleElement(tuple, idx, #self._mTimeOffsets)
        for _, offset in ipairs(self._mTimeOffsets)
        do
            idx = __writeTupleElement(tuple, idx, offset)
        end

        return idx
    end,


    deserizlie = function(self, app, tuple)
        local idx = 1
        local srcType = nil
        local videoMD5 = nil
        local danmakuDate = nil
        idx, srcType = __readTupleElement(tuple, idx)
        idx, videoMD5 = __readTupleElement(tuple, idx)
        idx, danmakuDate = __readTupleElement(tuple, idx)
        if self:getType() ~= srcType
            or not unportable.isMD5String(videoMD5)
            or not types.isNumber(danmakuDate)
        then
            return
        end

        -- 弹幕文件路径
        local fileCount = nil
        idx, fileCount = __readTupleElement(tuple, idx)
        if not types.isNumber(fileCount) or fileCount < 1
        then
            return
        end

        local filePath = nil
        local filePaths = utils.clearTable(self._mFilePaths)
        for i = 1, fileCount
        do
            idx, filePath = __readTupleElement(tuple, idx)
            if not app:doesFileExist(filePath)
            then
                return
            end
            table.insert(filePaths, filePath)
        end

        -- 弹幕时间偏移
        local timeOffsetCount = nil
        idx, timeOffsetCount = __readTupleElement(tuple, idx)
        if not types.isNumber(timeOffsetCount) or timeOffsetCount ~= fileCount
        then
            return
        end

        local timeOffset = nil
        local timeOffsets = utils.clearTable(self._mTimeOffsets)
        for i = 1, timeOffsetCount
        do
            idx, timeOffset = __readTupleElement(tuple, idx)
            if not types.isNumber(timeOffset)
            then
                return
            end
            table.insert(timeOffsets, timeOffset)
        end

        return true
    end,
}

classlite.declareClass(__CachedDanmakuSource, __IDanmakuSource)


local _BiliBiliDanmakuSource =
{
    _doParse = function(self, app, danmakuFile, timeOffset)
        --TODO
    end,

    getType = function(self)
        return _SOURCE_TYPE_BILI
    end,
}

classlite.declareClass(_BiliBiliDanmakuSource, __CachedDanmakuSource)


local _DanDanPlayDanmakuSource =
{
    _doParse = function(self, app, danmakuFile, timeOffset)
        --TODO
    end,

    getType = function(self)
        return _SOURCE_TYPE_DDP
    end,
}

classlite.declareClass(_DanDanPlayDanmakuSource, __CachedDanmakuSource)


local _AcfunDanmakuSource =
{
    _doParse = function(self, app, danmakuFile, timeOffset)
        --TODO
    end,

    getType = function(self)
        return _SOURCE_TYPE_ACFUN
    end,
}

classlite.declareClass(_AcfunDanmakuSource, __CachedDanmakuSource)



local DanmakuSourceFactory =
{
    _mDanmakuSourceClasses  = classlite.declareTableField(),
    _mDanmakuSourcePools    = classlite.declareTableField(),
    __mDeserializeTuple     = classlite.declareTableField(),
    __mFilePaths            = classlite.declareTableField(),
    __mDanmakuSources       = classlite.declareTableField(),

    new = function(self)
        local classes = self._mDanmakuSourceClasses
        classes[_SOURCE_TYPE_SRT] = _SRTDanmakuSource
        classes[_SOURCE_TYPE_DDP] = _DanDanPlayDanmakuSource
        classes[_SOURCE_TYPE_BILI] = _BiliBiliDanmakuSource
        classes[_SOURCE_TYPE_ACFUN] = _AcfunDanmakuSource

        local pools = self._mDanmakuSourcePools
        for k, _ in pairs(classes)
        do
            pools[k] = {}
        end
    end,

    dispose = function(self)
        for _, pool in pairs(self._mDanmakuSourcePools)
        do
            for i, danmakuSource in ipairs(pool)
            do
                danmakuSource:dispose()
                pool[i] = nil
            end
        end
    end,


    _obtainDanmakuSource = function(self, sourceType)
        local pool = self._mDanmakuSourcePools[sourceType]
        if pool
        then
            local count = #pool
            if count > 0
            then
                local ret = pool[count]
                pool[count] = nil
                return ret
            else
                local clzType = self._mDanmakuSourceClasses[sourceType]
                return clzType:new()
            end
        end
    end,

    _recycleDanmakuSource = function(self, danmakuSource)
        local sourceType = danmakuSource and danmakuSource:getType()
        local pool = sourceType and self._mDanmakuSourcePools[sourceType]
        if pool
        then
            table.insert(pool, danmakuSource)
        end
    end,

    recycleDanmakuSources = function(self, danmakuSources)
        for i, source in ipairs(danmakuSources)
        do
            self:_recycleDanmakuSource(source)
            danmakuSources[i] = nil
        end
    end,

    _listSRTDanmakuSource = function(self, app, curDir, outList)
        local filePaths = utils.clearTable(self.__mFilePaths)
        app:listFiles(filePaths)

        local function __filter(filePath, pattern)
            return not filePath:match(pattern)
        end
        utils.removeArrayElementsIf(filePaths, _SOURCE_PATTER_SRT_FILE)
        table.sort(filePaths)

        for _, filePath in ipairs(filePaths)
        do
            local source = self:_obtainDanmakuSource(_SOURCE_TYPE_SRT)
            source:_init(filePath)
            utils.pushArrayElement(outList, source)
        end
    end,


    _doDeserializeMetaFile = function(self, metaFilePath, callback)
        serialize.deserializeTupleFromFilePath(metaFilePath, callback)
    end,


    listDanmakuSources = function(self, app, curDir, metaFilePath, outList)
        -- 读取下载过的弹幕源
        local danmakuSources = utils.clearTable(self.__mDanmakuSources)
        local function __callback(sourceType, ...)
            local source = self:_obtainDanmakuSource(sourceType)
            if source
            then
                local tuple = self.__mDeserializeTuple
                utils.packArray(tuple, sourceType, ...)
                if source:deserizlie(app, tuple)
                then
                    utils.pushArrayElement(danmakuSources, source)
                else
                    self:_recycleDanmakuSource(source)
                end
            end
        end
        self:_doDeserializeMetaFile(metaFilePath, __callback)

        -- 按日期降序排序
        local function __cmp(source1, source2)
            local date1 = source1:getDate()
            local date2 = source2:getDate()
            return date1 < date2
        end
        table.sort(danmakuSources, __cmp)

        -- 优先显示 SRT 字幕
        self:_listSRTDanmakuSource(app, app:getSRTFileSearchDirPath(), outList)
        utils.extendArray(outList, danmakuSources)
    end,

    _doAddCachedDanmakuSource = function(self, sourceType, videoMD5, filePaths, timeOffsets)
        --TODO
    end,

    addBiliBiliDanmakuSource = function(self, ...)
        return self:_doAddCachedDanmakuSource(_SOURCE_TYPE_BILI, ...)
    end,

    addDanDanPlayDamakuSource = function(self, ...)
        return self:_doAddCachedDanmakuSource(_SOURCE_TYPE_DDP, ...)
    end,

    addAcfunDanmakuSource = function(self, ...)
        return self:_doAddCachedDanmakuSource(_SOURCE_TYPE_ACFUN, ...)
    end,
}


return
{
    DanmakuSourceFactory    = DanmakuSourceFactory,
}