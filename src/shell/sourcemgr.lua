local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local pluginbase    = require("src/plugins/pluginbase")


local _RAW_DATA_FILE_PREFIX         = "raw_"
local _RAW_DATA_FILE_SUFFIX_FMT     = "_%d.txt"


local function __deleteDownloadedFiles(app, filePaths)
    local function __deleteFile(fullPath, _, __, app)
        app:deleteTree(fullPath)
    end
    utils.forEachArrayElement(filePaths, __deleteFile, app)
    utils.clearTable(filePaths)
end


local function __downloadDanmakuRawDataFiles(app, urls, outFilePaths)
    local function __writeRawData(content, rawDatas)
        table.insert(rawDatas, content)
    end

    -- 没有指定缓存的文件夹
    local baseDir = app:getConfiguration().danmakuSourceRawDataDirPath
    if not baseDir
    then
        return false
    end

    -- 创建文件夹失败
    local hasCreatedDir = app:isExistedDir(baseDir)
    hasCreatedDir = hasCreatedDir or app:createDir(baseDir)
    if not hasCreatedDir
    then
        return false
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

    -- 有文件下不动的时候，数量就对不上
    if not hasCreatedDir or #rawDatas ~= #urls
    then
        utils.clearTable(rawDatas)
        return false
    end

    for i, rawData in ipairs(rawDatas)
    do
        local suffix = string.format(_RAW_DATA_FILE_SUFFIX_FMT, i)
        local fullPath = app:getUniqueFilePath(baseDir, _RAW_DATA_FILE_PREFIX, suffix)
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
                table.insert(outArray, elem)
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



local IDanmakuSource =
{
    _mPlugin    = classlite.declareConstantField(nil),

    getPluginName = function(self)
        local plugin = self._mPlugin
        return plugin and plugin:getName()
    end,

    parse = constants.FUNC_EMPTY,
    getDate = constants.FUNC_EMPTY,
    getDescription = constants.FUNC_EMPTY,

    _init = constants.FUNC_EMPTY,
    _delete = constants.FUNC_EMPTY,
    _update = constants.FUNC_EMPTY,
    _serialize = constants.FUNC_EMPTY,
    _deserizlie = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSource)


local _LocalDanmakuSource =
{
    _mPlugin        = classlite.declareConstantField(nil),
    _mFilePath      = classlite.declareTableField(),

    _init = function(self, app, plugin, filePath)
        self._mPlugin = plugin
        self._mFilePath = filePath
        return self:__isValid(app)
    end,

    parse = function(self, app)
        if self:__isValid(app)
        then
            self._mPlugin:parse(app, self._mFilePath)
        end
    end,

    __isValid = function(self, app)
        return classlite.isInstanceOf(self._mPlugin, pluginbase.IDanmakuSourcePlugin)
               and app:isExistedFile(self._mFilePath)
    end,
}

classlite.declareClass(_LocalDanmakuSource, IDanmakuSource)


local CachedRemoteDanmakuSource =
{
    _mPlugin        = classlite.declareConstantField(nil),
    _mDate          = classlite.declareConstantField(0),
    _mDescription   = classlite.declareConstantField(nil),
    _mSourceIDs     = classlite.declareTableField(),
    _mFilePaths     = classlite.declareTableField(),
    _mTimeOffsets   = classlite.declareTableField(),
    _mDownloadURLs  = classlite.declareTableField(),

    _init = function(self, app, plugin, date, desc, ids, paths, offsets, urls)
        self._mPlugin = plugin
        self._mDate = date
        self._mDescription = desc or constants.STR_EMPTY
        utils.appendArrayElements(utils.clearTable(self._mSourceIDs), ids)
        utils.appendArrayElements(utils.clearTable(self._mFilePaths), paths)
        utils.appendArrayElements(utils.clearTable(self._mTimeOffsets), offsets)
        utils.appendArrayElements(utils.clearTable(self._mDownloadURLs), urls)
        return self:__isValid(app)
    end,

    getDate = function(self)
        return self._mDate
    end,

    getDescription = function(self)
        return self._mDescription
    end,

    parse = function(self, app)
        if self:__isValid(app)
        then
            for i, filePath in ipairs(self._mFilePaths)
            do
                self._mPlugin:parseFile(app, filePath, self._mTimeOffset[i])
            end
        end
    end,


    __isValid = function(self, app)
        if not classlite.isInstanceOf(self._mPlugin, pluginbase.IDanmakuSourcePlugin)
            or not types.isNumber(self._mDate)
            or not types.isString(self._mDescription)
        then
            return false
        end

        local ids = self._mSourceIDs
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

        if utils.linearSearchArrayIf(ids, __checkIsNotString)
            or utils.linearSearchArrayIf(filePaths, __checkNonExistedFilePath, app)
            or utils.linearSearchArrayIf(timeOffsets, __checkIsNotNumber)
            or utils.linearSearchArrayIf(downloadURLs, __checkIsNotString)
        then
            return false
        end

        return true
    end,


    _serialize = function(self, app, serializer)
        if self:__isValid(app)
        then
            serializer:writeElement(app:getVideoMD5())
            serializer:writeElement(self:getPluginName())
            serializer:writeElement(self._mDate)
            serializer:writeElement(self._mDescription)
            serializer:writeArray(self._mSourceIDs)
            serializer:writeArray(self._mFilePaths)
            serializer:writeArray(self._mTimeOffsets)
            serializer:writeArray(self._mDownloadURLs)
            return true
        end
    end,


    _deserizlie = function(self, app, deserializer)
        local videoMD5 = deserializer:readElement()
        if videoMD5 ~= app:getVideoMD5()
        then
            return false
        end

        local function __findPluginByName(app, name)
            for _, plugin in app:iterateDanmakuSourcePlugin()
            do
                if plugin:getName() == name
                then
                    return plugin
                end
            end
        end

        local succeed = true
        self._mPlugin = __findPluginByName(app, deserializer:readElement())
        self._mDate = deserializer:readElement()
        self._mDescription = deserializer:readElement()
        succeed = succeed and deserializer:readArray(self._mSourceIDs)
        succeed = succeed and deserializer:readArray(self._mFilePaths)
        succeed = succeed and deserializer:readArray(self._mTimeOffsets)
        succeed = succeed and deserializer:readArray(self._mDownloadURLs)
        return types.toBoolean(succeed and self:__isValid(app))
    end,


    _delete = function(self, app)
        -- 只要删除原始文件，反序列化的时候就被认为是无效的弹幕源
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
            if source2:__isValid(app)
            then
                return true
            end

            __deleteDownloadedFiles(app, filePaths)
        end
    end,
}

classlite.declareClass(CachedRemoteDanmakuSource, IDanmakuSource)



local DanmakuSourceManager =
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

    recycleDanmakuSource = function(self, source)
        if classlite.isInstanceOf(source, IDanmakuSource)
        then
            local clz = source:getClass()
            local pools = self._mDanmakuSourcePools
            local pool = pools[pools]
            if not pool
            then
                pool = {}
                pools[clz] = pool
            end
            table.insert(pool, source)
        end
    end,

    recycleDanmakuSources = function(self, danmakuSources)
        for i, source in ipairs(danmakuSources)
        do
            self:recycleDanmakuSource(source)
            danmakuSources[i] = nil
        end
    end,


    _listLocalDanmakuSources = function(self, localDir, outList)
        local app = self._mApplication
        local filePaths = utils.clearTable(self.__mListFilePaths)
        app:listFiles(localDir, filePaths)
        table.sort(filePaths)

        local src = nil
        for _, filePath in ipairs(filePaths)
        do
            src = src or self:_obtainDanmakuSource(_LocalDanmakuSource)
            for _, p in app:iterateDanmakuSourcePlugin()
            do
                if p:isMatchedRawDataFile(app, filePath) and src:_init(app, p, filePath)
                then
                    table.insert(outList, src)
                    src = nil
                    break
                end
            end
        end
        self:recycleDanmakuSource(src)
    end,


    _doReadMetaFile = function(self, deserializeCallback)
        local cfg = self._mApplication:getConfiguration()
        local metaFilePath = cfg.danmakuSourceMetaDataFilePath
        serialize.deserializeTupleFromFilePath(metaFilePath, deserializeCallback)
    end,

    _doAppendMetaFile = function(self, source)
        local app = self._mApplication
        local tuple = utils.clearTable(self.__mSerializeTuple)
        local serializer = self._mSerializer
        serializer:_init(tuple)
        if source:_serialize(app, serializer)
        then
            local metaFilePath = app:getConfiguration().danmakuSourceMetaDataFilePath
            if not app:isExistedFile(metaFilePath)
            then
                local dir = unportable.splitPath(metaFilePath)
                local hasCreated = app:isExistedDir(dir) or app:createDir(dir)
                if not hasCreated
                then
                    return
                end
            end

            local file = app:writeFile(metaFilePath, constants.FILE_MODE_WRITE_APPEND)
            serialize.serializeTuple(file, utils.unpackArray(tuple))
            utils.closeSafely(file)
        end
    end,


    _listCachedRemoteDanmakuSources = function(self, outList)
        -- 读取下载过的弹幕源
        local app = self._mApplication
        local danmakuSources = utils.clearTable(self.__mDanmakuSources)
        local function __callback(md5, ...)
            -- 用 MD5 来区分不同视频文件的弹幕源，提前判可以过滤大部分记录
            if md5 == app:getVideoMD5()
            then
                local deserializer = self._mDeserializer
                local tuple = utils.clearTable(self.__mDeserializeTuple)
                local source = self:_obtainDanmakuSource(CachedRemoteDanmakuSource)
                utils.packArray(tuple, md5, ...)
                deserializer:_init(tuple)
                if source:_deserizlie(app, deserializer)
                then
                    table.insert(danmakuSources, source)
                else
                    self:recycleDanmakuSource(source)
                end
            end
        end
        self:_doReadMetaFile(__callback)
        utils.appendArrayElements(outList, danmakuSources)
    end,


    listDanmakuSources = function(self, outList)
        local cfg = self._mApplication:getConfiguration()
        local dir = cfg.localDanmakuSourceDirPath
        if types.isString(dir) and types.isTable(outList)
        then
            self:_listLocalDanmakuSources(dir, outList)
            self:_listCachedRemoteDanmakuSources(outList)
        end
    end,


    addDanmakuSource = function(self, plugin, desc, offsets, urls)
        local app = self._mApplication
        local datetime = app:getCurrentDateTime()
        local filePaths = utils.clearTable(self.__mDownloadedFilePaths)
        if __downloadDanmakuRawDataFiles(app, urls, filePaths)
        then
            local source = self:_obtainDanmakuSource(CachedRemoteDanmakuSource)
            if source and source:_init(app, plugin, datetime, desc, filePaths, offsets, urls)
            then
                self:_doAppendMetaFile(source)
                return source
            else
                self:recycleDanmakuSource(source)
            end
        end
    end,

    deleteDanmakuSource = function(self, source)
        local app = self._mApplication
        if classlite.isInstanceOf(source, IDanmakuSource) and source:_delete(app)
        then
            -- 调用者不要再持有这个对象
            self:recycleDanmakuSource(source)
            return true
        end
    end,

    updateDanmakuSource = function(self, source)
        local app = self._mApplication
        if classlite.isInstanceOf(source, IDanmakuSource)
        then
            local updatedSource = self:_obtainDanmakuSource(source:getClass())
            if source:_update(app, updatedSource)
            then
                self:_doAppendMetaFile(updatedSource)
                return updatedSource
            else
                self:recycleDanmakuSource(updatedSource)
            end
        end
    end,
}

classlite.declareClass(DanmakuSourceManager)


return
{
    IDanmakuSource          = IDanmakuSource,
    DanmakuSourceManager    = DanmakuSourceManager,
}