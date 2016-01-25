local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local srt           = require("src/parse/srt")


local SOURCE_TYPE_SRT       = "srt"
local SOURCE_TYPE_BILI      = "bili"
local SOURCE_TYPE_ACFUN     = "acfun"
local SOURCE_TYPE_DDP       = "ddp"


local _SOURCE_DATE_SRT          = 0
local _SOURCE_FMT_DATETIME      = "%y%m%d_%H%M%S"
local _SOURCE_FMT_FILE_NAME     = "%s_%d.txt"
local _SOURCE_PATTERN_SRT_FILE  = ".*[sS][rR][tT]$"


local function __deleteDownloadedFiles(app, filePaths)
    local function __deleteFile(fullPath, _, __, app)
        app:deleteTree(fullPath)
    end
    utils.forEachArrayElement(filePaths, __deleteFile, app)
    utils.clearTable(filePaths)
end


local function __downloadDanmakuRawDataFiles(app, datetime, urls, outFilePaths)
    local function __writeRawData(content, rawDatas)
        utils.pushArrayElement(rawDatas, content)
    end

    -- 先用此数组来暂存下载内容，下载完写文件后再转为路径
    local rawDatas = utils.clearTable(outFilePaths)
    local conn = app:getNetworkConnection()
    conn:resetParams()
    for _, url in ipairs(urls)
    do
        conn:receiveLater(url, __writeRawData, rawDatas)
    end
    conn:flushReceiveQueue()

    local baseDir = app:getDanmakuSourceRawDataDirPath()
    local hasCreatedDir = app:isExistedDir(baseDir)
    hasCreatedDir = not hasCreatedDir and app:createDir(baseDir)

    -- 有文件下不动的时候，数量就对不上
    if not hasCreatedDir or #rawDatas ~= #urls
    then
        utils.clearTable(rawDatas)
        return false
    end

    local prefix = os.date(_SOURCE_FMT_DATETIME, datetime)
    for i, rawData in ipairs(rawDatas)
    do
        local fileName = string.format(_SOURCE_FMT_FILE_NAME, prefix, i)
        local fullPath = unportable.joinPath(baseDir, fileName)
        local f = app:writeFile(fullPath)
        if not utils.writeAndCloseFile(f, rawData)
        then
            utils.clearArray(rawDatas, i + 1)
            __deleteDownloadedFiles(app, outFilePaths)
            return false
        end
        outFilePaths[i] = fullPath
    end
    return true
end



local __TupleAndCursorMixin =
{
    _mTuple     = classlite.declareConstantField(nil),
    _mCursor    = classlite.declareConstantField(nil),

    _init = function(self, tuple)
        self._mTuple = tuple
        self._mCursor = 1
    end,
}

classlite.declareClass(__TupleAndCursorMixin)


local _Deserializer =
{
    readElement = function(self)
        local ret = self._mTuple[self._mCursor]
        self._mCursor = self._mCursor + 1
        return ret
    end,

    readArray = function(self, outArray)
        local count = self:readElement()
        if types.isNumber(count) and count > 0
        then
            utils.clearTable(outArray)
            for i = 1, count
            do
                local elem = self:readElement()
                utils.pushArrayElement(outArray, elem)
            end
            return true
        end
    end,
}

classlite.declareClass(_Deserializer, __TupleAndCursorMixin)


local _Serializer =
{
    writeElement = function(self, elem)
        self._mTuple[self._mCursor] = elem
        self._mCursor = self._mCursor + 1
    end,

    writeArray = function(self, array)
        local count = #array
        self:writeElement(count)
        for i = 1, count
        do
            self:writeElement(array[i])
        end
    end,
}

classlite.declareClass(_Serializer, __TupleAndCursorMixin)



local _IDanmakuSource =
{
    parse = constants.FUNC_EMPTY,
    getType = constants.FUNC_EMPTY,
    getDate = constants.FUNC_EMPTY,
    getDescription = constants.FUNC_EMPTY,

    _init = constants.FUNC_EMPTY,
    _delete = constants.FUNC_EMPTY,
    _update = constants.FUNC_EMPTY,
    _serialize = constants.FUNC_EMPTY,
    _deserizlie = constants.FUNC_EMPTY,
}

classlite.declareClass(_IDanmakuSource)


local _LocalDanmakuSource =
{
    _mPlugin            = classlite.declareConstantField(nil),
    _mLocalFilePaths    = classlite.declareTableField(),

    _init = function(self, app, plugin, filePath)
        if app:isExistedFile(filePath)
        then
            self._mLocalFilePaths = filePath
            return true
        end
    end,

    parse = function(self, app)
        local file = app:openUTF8File(self._mLocalFilePaths)
        if file
        then
            local cfg = app:getConfiguration()
            local pools = app:getDanmakuPools()
            local pool = pools:getDanmakuPoolByLayer(danmaku.LAYER_SUBTITLE)
            local _, fileName = unportable.splitPath(self._mLocalFilePaths)
            srt.parseSRTFile(cfg, pool, file, string.format(_SOURCE_FMT_SRT, fileName))
            file:close()
        end
    end,

    getType = function(self)
        return SOURCE_TYPE_SRT
    end,

    getDescription = function(self)
        return self._mLocalFilePaths
    end,
}

classlite.declareClass(_LocalDanmakuSource, _IDanmakuSource)


local _CachedDanmakuSource =
{
    _mType          = classlite.declareConstantField(nil),
    _mDate          = classlite.declareConstantField(0),
    _mDescription   = classlite.declareConstantField(nil),
    _mFilePaths     = classlite.declareTableField(),
    _mTimeOffsets   = classlite.declareTableField(),
    _mDownloadURLs  = classlite.declareTableField(),

    _init = function(self, app, srcType, date, desc, paths, offsets, urls)
        self._mType = srcType
        self._mDate = date
        self._mDescription = desc or constants.STR_EMPTY
        utils.appendArrayElements(utils.clearTable(self._mFilePaths), paths)
        utils.appendArrayElements(utils.clearTable(self._mTimeOffsets), offsets)
        utils.appendArrayElements(utils.clearTable(self._mDownloadURLs), urls)
        return self:__isValid(app)
    end,

    _getParseFunction = function(self)
        local srcType = self._mType
        return srcType and _PARSE_FUNC_MAP[srcType]
    end,

    getType = function(self)
        return self._mType
    end,

    getDate = function(self)
        return self._mDate
    end,

    getDescription = function(self)
        return self._mDescription
    end,

    parse = function(self, app)
        local parseFunc = self._getParseFunction(self._mType)
        if parseFunc
        then
            for i, filePath in ipairs(self._mFilePaths)
            do
                local timeOffset = self._mTimeOffsets[i]
                local danmakuFile = app:openUTF8File(filePath)
                if types.isNumber(timeOffset) and danmakuFile
                then
                    parseFunc(app, self, danmakuFile, timeOffset)
                end
                utils.closeSafely(danmakuFile)
            end
        end
    end,

    __isValid = function(self, app)
        if not self:_getParseFunction()
            or not types.isNumber(self._mDate)
            or not types.isString(self._mDescription)
        then
            return false
        end

        local filePaths = self._mFilePaths
        local timeOffsets = self._mTimeOffsets
        local downloadURLs = self._mDownloadURLs
        local count = #filePaths
        if count <= 0 or #timeOffsets ~= count or #downloadURLs ~= count
        then
            return false
        end

        local function __checkNonExistedFilePath(path, app)
            return not app:isExistedFile(path)
        end

        local function __checkIsNotNumber(num)
            return not types.isNumber(num)
        end

        local function __checkIsNotString(url)
            return not types.isString(url)
        end

        if utils.linearSearchArrayIf(filePaths, __checkNonExistedFilePath, app)
            or utils.linearSearchArrayIf(timeOffsets, __checkIsNotNumber, app)
            or utils.linearSearchArrayIf(downloadURLs, __checkIsNotString, app)
        then
            return false
        end

        return true
    end,


    _serialize = function(self, app, serializer)
        if self:__isValid(app)
        then
            serializer:writeElement(app:getVideoMD5())
            serializer:writeElement(self._mType)
            serializer:writeElement(self._mDate)
            serializer:writeElement(self._mDescription)
            serializer:writeArray(self._mFilePaths)
            serializer:writeArray(self._mTimeOffsets)
            serializer:writeArray(self._mDownloadURLs)
        end
    end,


    _deserizlie = function(self, app, deserializer)
        local videoMD5 = deserializer:readElement()
        if videoMD5 == app:getVideoMD5()
        then
            local succeed = true
            self._mType = deserializer:readElement()
            self._mDate = deserializer:readElement()
            self._mDescription = deserializer:readElement()
            succeed = succeed and deserializer:readArray(self._mFilePaths)
            succeed = succeed and deserializer:readArray(self._mTimeOffsets)
            succeed = succeed and deserializer:readArray(self._mDownloadURLs)
            return types.toBoolean(succeed and self:__isValid())
        end
    end,


    _delete = function(self, app)
        -- 只要删除原始文件，反序列化的时候就当为无效的弹幕源
        for _, path in ipairs(self._mFilePaths)
        do
            app:deleteTree(path)
        end
        return true
    end,


    _update = function(self, app, source2)
        local datetime = app:getCurrentDateTime()
        self:clone(source2)
        source2._mDate = datetime

        local filePaths = source2._mFilePaths
        if __downloadDanmakuRawDataFiles(app, source2._mDownloadURLs, filePaths)
        then
            if source2:__isValid()
            then
                return true
            end

            __deleteDownloadedFiles(app, filePaths)
        end
    end,
}

classlite.declareClass(_CachedDanmakuSource, _IDanmakuSource)



local DanmakuSourceFactory =
{
    _mApplication               = classlite.declareConstantField(nil),
    _mSerializer                = classlite.declareClassField(_Serializer),
    _mDeserializer              = classlite.declareClassField(_Deserializer),
    _mDanmakuSourcePools        = classlite.declareTableField(),

    __mSerializeTuple           = classlite.declareTableField(),
    __mDeserializeTuple         = classlite.declareTableField(),
    __mListFilePaths            = classlite.declareTableField(),
    __mDownloadedFilePaths      = classlite.declareTableField(),
    __mDanmakuSources           = classlite.declareTableField(),


    new = function(self)
        self._mDanmakuSourcePools[_LocalDanmakuSource] = {}
        self._mDanmakuSourcePools[_CachedDanmakuSource] = {}
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

    setApplication = function(self, app)
        self._mApplication = app
    end,

    _obtainDanmakuSource = function(self, srcClz)
        local pool = self._mDanmakuSourcePools[srcClz]
        return pool and utils.popArrayElement(pool) or srcClz:new()
    end,

    _recycleDanmakuSource = function(self, source)
        if classlite.isInstanceOf(source, _IDanmakuSource)
        then
            local pool = self._mDanmakuSourcePools[source:getClass()]
            utils.pushArrayElement(pool, source)
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
        local filePaths = utils.clearTable(self.__mListFilePaths)
        app:listFiles(filePaths)

        local function __filter(filePath, pattern)
            return not filePath:match(pattern)
        end
        utils.removeArrayElementsIf(filePaths, _SOURCE_PATTERN_SRT_FILE)
        table.sort(filePaths)

        for _, filePath in ipairs(filePaths)
        do
            local source = self:_obtainDanmakuSource(_LocalDanmakuSource)
            source:_init(app, filePath)
            utils.pushArrayElement(outList, source)
        end
    end,


    _doReadMetaFile = function(self, deserializeCallback)
        local metaFilePath = self._mApplication:getDanmakuSourceMetaFilePath()
        serialize.deserializeTupleFromFilePath(metaFilePath, deserializeCallback)
    end,

    _doAppendMetaFile = function(self, source)
        local app = self._mApplication
        local tuple = utils.clearTable(self.__mSerializeTuple)
        local serializer = self._mSerializer
        serializer:_init(tuple)
        if source:_serialize(app, serializer)
        then
            local metaFilePath = app:getDanmakuSourceMetaFilePath()
            local file = app:writeFile(metaFilePath, constants.FILE_MODE_WRITE_APPEND)
            serialize.serializeTuple(file, utils.unpackArray(tuple))
            utils.closeSafely(file)
        end
    end,


    listDanmakuSources = function(self, outList)
        -- 读取下载过的弹幕源
        local app = self._mApplication
        local danmakuSources = utils.clearTable(self.__mDanmakuSources)
        local function __callback(md5, ...)
            -- 用 MD5 来区分不同视频文件的弹幕源，提早判可以过滤大部分记录
            if md5 == app:getVideoMD5()
            then
                local deserializer = self._mDeserializer
                local tuple = utils.clearTable(self.__mDeserializeTuple)
                local source = self:_obtainDanmakuSource(_CachedDanmakuSource)
                utils.packArray(tuple, md5, ...)
                deserializer:_init(tuple)
                if source:_deserizlie(app, deserializer)
                then
                    utils.pushArrayElement(danmakuSources, source)
                else
                    self:_recycleDanmakuSource(source)
                end
            end
        end
        self:_doReadMetaFile(__callback)

        -- 按日期降序排序
        local function __cmp(source1, source2)
            local date1 = source1:getDate()
            local date2 = source2:getDate()
            return date1 < date2
        end
        table.sort(danmakuSources, __cmp)

        -- 优先显示 SRT 字幕
        self:_listSRTDanmakuSource(app, app:getSRTFileSearchDirPath(), outList)
        utils.appendArrayElements(outList, danmakuSources)
    end,


    _doAddCachedDanmakuSource = function(self, srcType, desc, offsets, urls)
        local app = self._mApplication
        local datetime = app:getCurrentDateTime()
        local filePaths = utils.clearTable(self.__mDownloadedFilePaths)
        if __downloadDanmakuRawDataFiles(app, datetime, urls, filePaths)
        then
            local source = self:_obtainDanmakuSource(_CachedDanmakuSource)
            if source and source:_init(app, srcType, datetime, desc, filePaths, offsets, urls)
            then
                self:_doAppendMetaFile(source)
                return source
            else
                self:_recycleDanmakuSource(source)
            end
        end
    end,

    addBiliBiliDanmakuSource = function(self, ...)
        return self:_doAddCachedDanmakuSource(SOURCE_TYPE_BILI, ...)
    end,

    addDanDanPlayDamakuSource = function(self, ...)
        return self:_doAddCachedDanmakuSource(SOURCE_TYPE_DDP, ...)
    end,

    addAcfunDanmakuSource = function(self, ...)
        return self:_doAddCachedDanmakuSource(SOURCE_TYPE_ACFUN, ...)
    end,

    deleteDanmakuSource = function(self, source)
        local app = self._mApplication
        if classlite.isInstanceOf(source, _IDanmakuSource) and source:_delete(app)
        then
            -- 调用者不要再持有这个对象
            self:_recycleDanmakuSource(source)
            return true
        end
    end,

    updateDanmakuSource = function(self, source)
        local app = self._mApplication
        if classlite.isInstanceOf(source, _IDanmakuSource)
        then
            local updatedSource = self:_obtainDanmakuSource(source:getClass())
            if source:_update(app, updatedSource)
            then
                self:_doAppendMetaFile(updatedSource)
                return updatedSource
            else
                self:_recycleDanmakuSource(updatedSource)
            end
        end
    end,
}

classlite.declareClass(DanmakuSourceFactory)


return
{
    DanmakuSourceFactory    = DanmakuSourceFactory,
}