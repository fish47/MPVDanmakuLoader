local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local danmaku       = require("src/core/danmaku")
local pluginbase    = require("src/plugins/pluginbase")
local application   = require("src/shell/application")


local _RAW_DATA_FILE_PREFIX         = "raw_"
local _RAW_DATA_FILE_FMT_SUFFIX     = "_%d.txt"

local _FMT_SOURCEID                 = "%s:%s"


local function __deleteDownloadedFiles(app, filePaths)
    local function __deleteFile(fullPath, _, __, app)
        app:deleteTree(fullPath)
    end
    utils.forEachArrayElement(filePaths, __deleteFile, app)
    utils.clearTable(filePaths)
end


local function __downloadDanmakuRawDataFiles(app, plugin, ids, outFilePaths)
    if not classlite.isInstanceOf(app, application.MPVDanmakuLoaderApp)
        or types.isNilOrEmpty(ids)
        or not types.isTable(outFilePaths)
    then
        return false
    end

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
    plugin:downloadDanmakuRawDatas(ids, rawDatas)

    -- 有文件下不动的时候，数量就对不上
    if not hasCreatedDir or #rawDatas ~= #ids
    then
        utils.clearTable(rawDatas)
        return false
    end

    for i, rawData in utils.iterateArray(rawDatas)
    do
        local suffix = string.format(_RAW_DATA_FILE_FMT_SUFFIX, i)
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
    _isFromSameUpdateSource = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSource)


local _LocalDanmakuSource =
{
    _mPlugin        = classlite.declareConstantField(nil),
    _mFilePath      = classlite.declareConstantField(nil),

    _init = function(self, app, plugin, filePath)
        self._mPlugin = plugin
        self._mFilePath = filePath
        if self:__isValid(app)
        then
            return true
        else
            self:reset()
            return false
        end
    end,

    parse = function(self, app)
        if self:__isValid(app)
        then
            local plugin = self._mPlugin
            local filePath = self._mFilePath
            local sourceID = string.format(_FMT_SOURCEID, plugin:getName(), filePath)
            plugin:parseFile(app, filePath, sourceID)
        end
    end,

    __isValid = function(self, app)
        return classlite.isInstanceOf(self._mPlugin, pluginbase.IDanmakuSourcePlugin)
            and app:isExistedFile(self._mFilePath)
    end,

    getDescription = function(self)
        local filePath = self._mFilePath
        if types.isString(filePath)
        then
            local _, fileName = unportable.splitPath(filePath)
            return fileName
        end
    end
}

classlite.declareClass(_LocalDanmakuSource, IDanmakuSource)


local _CachedRemoteDanmakuSource =
{
    _mPlugin        = classlite.declareConstantField(nil),
    _mDate          = classlite.declareConstantField(0),
    _mDescription   = classlite.declareConstantField(nil),
    _mSourceIDs     = classlite.declareTableField(),
    _mFilePaths     = classlite.declareTableField(),
    _mTimeOffsets   = classlite.declareTableField(),

    _init = function(self, app, plugin, date, desc, ids, paths, offsets)
        self._mPlugin = plugin
        self._mDate = date
        self._mDescription = desc or constants.STR_EMPTY

        local srcIDs = utils.clearTable(self._mSourceIDs)
        local srcPaths = utils.clearTable(self._mFilePaths)
        local srcOffsets = utils.clearTable(self._mTimeOffsets)
        utils.appendArrayElements(srcIDs, ids)
        utils.appendArrayElements(srcPaths, paths)
        utils.appendArrayElements(srcOffsets, offsets)

        -- 对字段排序方便后来更新时比较
        if self:__isValid(app)
        then
            utils.sortParallelArrays(srcOffsets, srcIDs, srcPaths)
            return true
        else
            self:reset()
            return false
        end
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
            local pluginName = self:getPluginName()
            for i, filePath in utils.iterateArray(self._mFilePaths)
            do
                local sourceID = string.format(_FMT_SOURCEID, pluginName, filePath)
                self._mPlugin:parseFile(app, filePath, self._mTimeOffsets[i], sourceID)
            end
        end
    end,


    __isValid = function(self, app)
        local function __checkNonExistedFilePath(path, app)
            return not app:isExistedFile(path)
        end

        local function __checkIsNotNumber(num)
            return not types.isNumber(num)
        end

        local function __checkIsNotString(url)
            return not types.isString(url)
        end

        local ids = self._mSourceIDs
        local filePaths = self._mFilePaths
        local timeOffsets = self._mTimeOffsets
        return classlite.isInstanceOf(self._mPlugin, pluginbase.IDanmakuSourcePlugin)
            and types.isNumber(self._mDate)
            and types.isString(self._mDescription)
            and #ids > 0
            and #ids == #filePaths
            and #ids == #timeOffsets
            and not utils.linearSearchArrayIf(ids, __checkIsNotString)
            and not utils.linearSearchArrayIf(filePaths, __checkNonExistedFilePath, app)
            and not utils.linearSearchArrayIf(timeOffsets, __checkIsNotNumber)
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

        if succeed and self:__isValid(app)
        then
            return true
        else
            self:reset()
            return false
        end
    end,


    _delete = function(self, app)
        -- 只要删除原始文件，反序列化的时候就被认为是无效的弹幕源
        for _, path in utils.iterateArray(self._mFilePaths)
        do
            app:deleteTree(path)
        end
        return true
    end,


    _update = function(self, app, source2)
        if self:__isValid(app)
        then
            self:clone(source2)
            source2._mDate = app:getCurrentDateTime()

            local ids = self._mSourceIDs
            local plugin = self._mPlugin
            local filePaths = utils.clearTable(source2._mFilePaths)
            local succeed = __downloadDanmakuRawDataFiles(app, plugin, ids, filePaths)
            if succeed and source2:__isValid(app)
            then
                return true
            end

            __deleteDownloadedFiles(app, filePaths)
            source2:reset()
        end
    end,

    _isFromSameUpdateSource = function(self, app, source2)
        local function __hasSameArrayContent(array1, array2)
            if types.isTable(array1) and types.isTable(array2) and #array1 == #array2
            then
                for i = 1, #array1
                do
                    if array1[i] ~= array2[i]
                    then
                        return false
                    end
                end
                return true
            end
        end

        return classlite.isInstanceOf(source2, self:getClass())
            and self:__isValid(app)
            and source2:__isValid(app)
            and __hasSameArrayContent(self._mSourceIDs, source2._mSourceIDs)
            and __hasSameArrayContent(self._mTimeOffsets, source2._mTimeOffsets)
    end,
}

classlite.declareClass(_CachedRemoteDanmakuSource, IDanmakuSource)



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
            for i, danmakuSource in utils.iterateArray(pool)
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
        for i, source in utils.iterateArray(danmakuSources)
        do
            self:recycleDanmakuSource(source)
            danmakuSources[i] = nil
        end
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
            app:closeFile(file)
        end
    end,


    listDanmakuSources = function(self, outList)
        if not types.isTable(outList)
        then
            return
        end


        local app = self._mApplication
        local danmakuSources = utils.clearTable(self.__mDanmakuSources)

        -- 读取下载过的弹幕源
        local function __callback(md5, ...)
            -- 用 MD5 来区分不同视频文件的弹幕源，提前判可以过滤大部分记录
            if md5 == app:getVideoMD5()
            then
                local deserializer = self._mDeserializer
                local tuple = utils.clearTable(self.__mDeserializeTuple)
                local source = self:_obtainDanmakuSource(_CachedRemoteDanmakuSource)
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


    addCachedDanmakuSource = function(self, plugin, desc, ids, offsets)
        local app = self._mApplication
        local datetime = app:getCurrentDateTime()
        local filePaths = utils.clearTable(self.__mDownloadedFilePaths)
        if __downloadDanmakuRawDataFiles(app, plugin, ids, filePaths)
        then
            local source = self:_obtainDanmakuSource(_CachedRemoteDanmakuSource)
            if source and source:_init(app, plugin, datetime, desc, ids, filePaths, offsets)
            then
                self:_doAppendMetaFile(source)
                return source
            end

            self:recycleDanmakuSource(source)
        end
    end,

    addLocalDanmakuSource = function(self, plugin, filePath)
        local source = self._obtainDanmakuArea(_LocalDanmakuSource)
        if source._init(self._mApplication, plugin, filePath)
        then
            return source
        end

        self:recycleDanmakuSource(source)
    end,

    deleteDanmakuSource = function(self, source)
        local app = self._mApplication
        if classlite.isInstanceOf(source, IDanmakuSource) and source:_delete(app)
        then
            -- 外部不要再持有这个对象了
            self:recycleDanmakuSource(source)
            return true
        end
    end,

    updateDanmakuSources = function(self, inSources, outSources)
        local function __checkIsNotDanmakuSource(source)
            return not classlite.isInstanceOf(source, IDanmakuSource)
        end

        if types.isTable(inSources)
            and types.isTable(outSources)
            and not types.isNilOrEmpty(inSources)
            and not utils.linearSearchArrayIf(inSources, __checkIsNotDanmakuSource)
        then
            -- 注意输入和输出有可能是同一个 table
            local app = self._mApplication
            local tmpSource = self:_obtainDanmakuSource(_CachedRemoteDanmakuSource)
            for i = 1, #inSources
            do
                -- 排除掉一些来源重复的
                local source = inSources[i]
                local found = false
                for j = 1, i - 1
                do
                    if source:_isFromSameUpdateSource(app, inSources[j])
                    then
                        found = true
                        break
                    end
                end

                if not found and source:_update(app, tmpSource)
                then
                    self:_doAppendMetaFile(tmpSource)
                    table.insert(outSources, tmpSource)
                    tmpSource = self:_obtainDanmakuSource(_CachedRemoteDanmakuSource)
                end
            end
            self:recycleDanmakuSource(tmpSource)
        end
    end,
}

classlite.declareClass(DanmakuSourceManager)


return
{
    IDanmakuSource          = IDanmakuSource,
    DanmakuSourceManager    = DanmakuSourceManager,
}