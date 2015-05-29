local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local serialize     = require("src/base/serialize")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local application   = require("src/shell/application")


local _RAW_DATA_FILE_PREFIX         = "raw_"
local _RAW_DATA_FILE_FMT_SUFFIX     = "_%d.txt"

local _DEFAULT_START_TIME_OFFSET    = 0


local function __deleteDownloadedFiles(app, filePaths)
    local function __deleteFile(fullPath, _, __, app)
        app:deleteTree(fullPath)
    end
    utils.forEachArrayElement(filePaths, __deleteFile, app)
    utils.clearTable(filePaths)
end


local function __downloadDanmakuRawDataFiles(app, plugin, videoIDs, outFilePaths)
    if not classlite.isInstanceOf(app, application.MPVDanmakuLoaderApp)
        or types.isNilOrEmpty(videoIDs)
        or not types.isTable(outFilePaths)
    then
        return false
    end

    local function __writeRawData(content, rawDatas)
        table.insert(rawDatas, content)
    end

    -- 没有指定缓存的文件夹
    local baseDir = app:getDanmakuSourceRawDataDirPath()
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
    plugin:downloadDanmakuRawDatas(videoIDs, rawDatas)

    -- 有文件下不动的时候，数量就对不上
    if not hasCreatedDir or #rawDatas ~= #videoIDs
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
            utils.clearArray(rawDatas, i)
            __deleteDownloadedFiles(app, outFilePaths)
            return false
        end
        outFilePaths[i] = fullPath
    end
    return true
end



local __ArrayAndCursorMixin =
{
    _mArray     = classlite.declareConstantField(nil),
    _mCursor    = classlite.declareConstantField(nil),

    init = function(self, array)
        self._mArray = array
        self._mCursor = 1
    end,
}

classlite.declareClass(__ArrayAndCursorMixin)


local _Deserializer =
{
    readElement = function(self)
        local ret = self._mArray[self._mCursor]
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

classlite.declareClass(_Deserializer, __ArrayAndCursorMixin)


local _Serializer =
{
    writeElement = function(self, elem)
        self._mArray[self._mCursor] = elem
        self._mCursor = self._mCursor + 1
    end,

    writeArray = function(self, array, hook, arg)
        local count = #array
        self:writeElement(count)
        for i = 1, count
        do
            local val = array[i]
            if hook
            then
                val = hook(val, arg)
            end
            self:writeElement(val)
        end
    end,
}

classlite.declareClass(_Serializer, __ArrayAndCursorMixin)



local IDanmakuSource =
{
    _mApplication   = classlite.declareConstantField(nil),
    _mPlugin        = classlite.declareConstantField(nil),

    setApplication = function(self, app)
        self._mApplication = app
    end,

    getPluginName = function(self)
        local plugin = self._mPlugin
        return plugin and plugin:getName()
    end,

    _serialize = function(self, serializer)
        if serializer and self:_isValid()
        then
            serializer:writeElement(self:getPluginName())
            return true
        end
    end,

    _deserialize = function(self, deserializer)
        if deserializer
        then
            local pluginName = deserializer:readElement()
            local plugin = self._mApplication:getPluginByName(pluginName)
            if plugin
            then
                self._mPlugin = plugin
                return true
            end
        end
    end,

    parse = constants.FUNC_EMPTY,
    getDate = constants.FUNC_EMPTY,
    getDescription = constants.FUNC_EMPTY,

    _init = constants.FUNC_EMPTY,
    _delete = constants.FUNC_EMPTY,
    _update = constants.FUNC_EMPTY,
    _isDuplicated = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSource)


local _LocalDanmakuSource =
{
    _mPlugin        = classlite.declareConstantField(nil),
    _mFilePath      = classlite.declareConstantField(nil),

    _init = function(self, plugin, filePath)
        self._mPlugin = plugin
        self._mFilePath = filePath
        return self:_isValid()
    end,

    parse = function(self)
        if self:_isValid()
        then
            local plugin = self._mPlugin
            local filePath = self._mFilePath
            local timeOffset = _DEFAULT_START_TIME_OFFSET
            local pools = self._mApplication:getDanmakuPools()
            local sourceID = pools:allocateDanmakuSourceID(plugin:getName(), nil, nil,
                                                           timeOffset, filePath)

            plugin:parseFile(filePath, sourceID, timeOffset)
        end
    end,

    _isValid = function(self)
        return classlite.isInstanceOf(self._mPlugin, pluginbase.IDanmakuSourcePlugin)
            and self._mApplication:isExistedFile(self._mFilePath)
    end,

    getDescription = function(self)
        local filePath = self._mFilePath
        if types.isString(filePath)
        then
            local _, fileName = unportable.splitPath(filePath)
            return fileName
        end
    end,

    _serialize = function(self, serializer)
        if IDanmakuSource._serialize(self, serializer)
        then
            local cacheDir = self._mApplication:getDanmakuSourceRawDataDirPath()
            serializer:writeElement(unportable.getRelativePath(cacheDir, self._mFilePath))
            return true
        end
    end,

    _deserialize = function(self, deserializer)
        if IDanmakuSource._deserialize(self, deserializer)
        then
            local relPath = deserializer:readElement()
            local cacheDir = self._mApplication:getDanmakuSourceRawDataDirPath()
            self._mFilePath = unportable.joinPath(cacheDir, relPath)
            return self:_isValid()
        end
    end,

    _delete = function(self)
        return true
    end,

    _isDuplicated = function(self, source2)
        -- 一个文件不能对应多个弹幕源
        return classlite.isInstanceOf(source2, self:getClass())
            and self._mFilePath == source2._mFilePath
    end,
}

classlite.declareClass(_LocalDanmakuSource, IDanmakuSource)


local _CachedRemoteDanmakuSource =
{
    _mPlugin            = classlite.declareConstantField(nil),
    _mDate              = classlite.declareConstantField(0),
    _mDescription       = classlite.declareConstantField(nil),
    _mVideoIDs          = classlite.declareTableField(),
    _mFilePaths         = classlite.declareTableField(),
    _mStartTimeOffsets  = classlite.declareTableField(),

    _init = function(self, plugin, date, desc, videoIDs, paths, offsets)
        self._mPlugin = plugin
        self._mDate = date
        self._mDescription = desc or constants.STR_EMPTY

        local sourceVideoIDs = utils.clearTable(self._mVideoIDs)
        local sourcePaths = utils.clearTable(self._mFilePaths)
        local sourceOffsets = utils.clearTable(self._mStartTimeOffsets)
        utils.appendArrayElements(sourceVideoIDs, videoIDs)
        utils.appendArrayElements(sourcePaths, paths)
        utils.appendArrayElements(sourceOffsets, offsets)

        -- 对字段排序方便后来更新时比较
        if self:_isValid()
        then
            utils.sortParallelArrays(sourceOffsets, sourceVideoIDs, sourcePaths)
            return true
        end
    end,

    getDate = function(self)
        return self._mDate
    end,

    getDescription = function(self)
        return self._mDescription
    end,

    parse = function(self)
        if self:_isValid()
        then
            local pluginName = self._mPlugin:getName()
            local videoIDs = self._mVideoIDs
            local timeOffsets = self._mStartTimeOffsets
            local pools = self._mApplication:getDanmakuPools()
            for i, filePath in utils.iterateArray(self._mFilePaths)
            do
                local timeOffset = timeOffsets[i]
                local sourceID = pools:allocateDanmakuSourceID(pluginName, videoIDs[i], i, timeOffset)
                self._mPlugin:parseFile(filePath, sourceID, timeOffset)
            end
        end
    end,


    _isValid = function(self)
        local function __checkNonExistedFilePath(path, app)
            return not app:isExistedFile(path)
        end

        local function __checkIsNotNumber(num)
            return not types.isNumber(num)
        end

        local function __checkIsNotString(url)
            return not types.isString(url)
        end

        local app = self._mApplication
        local videoIDs = self._mVideoIDs
        local filePaths = self._mFilePaths
        local timeOffsets = self._mStartTimeOffsets
        return classlite.isInstanceOf(self._mPlugin, pluginbase.IDanmakuSourcePlugin)
            and types.isNumber(self._mDate)
            and types.isString(self._mDescription)
            and #videoIDs > 0
            and #videoIDs == #filePaths
            and #videoIDs == #timeOffsets
            and not utils.linearSearchArrayIf(videoIDs, __checkIsNotString)
            and not utils.linearSearchArrayIf(filePaths, __checkNonExistedFilePath, app)
            and not utils.linearSearchArrayIf(timeOffsets, __checkIsNotNumber)
    end,

    _serialize = function(self, serializer)
        local function __getRelativePath(fullPath, dir)
            return unportable.getRelativePath(dir, fullPath)
        end

        if IDanmakuSource._serialize(self, serializer)
        then
            local cacheDir = self._mApplication:getDanmakuSourceRawDataDirPath()
            serializer:writeElement(self._mDate)
            serializer:writeElement(self._mDescription)
            serializer:writeArray(self._mVideoIDs)
            serializer:writeArray(self._mFilePaths, __getRelativePath, cacheDir)
            serializer:writeArray(self._mStartTimeOffsets)
            return true
        end
    end,

    _deserialize = function(self, deserializer)
        local function __readFilePaths(deserializer, filePaths, dir)
            if deserializer:readArray(filePaths)
            then
                for i, relPath in ipairs(filePaths)
                do
                    filePaths[i] = unportable.joinPath(dir, relPath)
                end
                return true
            end
        end

        if IDanmakuSource._deserialize(self, deserializer)
        then
            local succeed = true
            local cacheDir = self._mApplication:getDanmakuSourceRawDataDirPath()
            self._mDate = deserializer:readElement()
            self._mDescription = deserializer:readElement()
            succeed = succeed and deserializer:readArray(self._mVideoIDs)
            succeed = succeed and __readFilePaths(deserializer, self._mFilePaths, cacheDir)
            succeed = succeed and deserializer:readArray(self._mStartTimeOffsets)
            return self:_isValid()
        end
    end,


    _delete = function(self)
        -- 只要删除原始文件，反序列化的时候就被认为是无效的弹幕源
        local app = self._mApplication
        for _, path in utils.iterateArray(self._mFilePaths)
        do
            app:deleteTree(path)
        end
        return true
    end,


    _update = function(self, source2)
        if self:_isValid()
        then
            local app = self._mApplication
            self:clone(source2)
            source2._mDate = app:getCurrentDateTime()

            local videoIDs = self._mVideoIDs
            local plugin = self._mPlugin
            local filePaths = utils.clearTable(source2._mFilePaths)
            local succeed = __downloadDanmakuRawDataFiles(app, plugin, videoIDs, filePaths)
            if succeed and source2:_isValid()
            then
                return true
            end

            __deleteDownloadedFiles(app, filePaths)
        end
    end,


    _isDuplicated = function(self, source2)
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
            and self:_isValid()
            and source2:_isValid()
            and __hasSameArrayContent(self._mVideoIDs, source2._mVideoIDs)
            and __hasSameArrayContent(self._mStartTimeOffsets, source2._mStartTimeOffsets)
    end,
}

classlite.declareClass(_CachedRemoteDanmakuSource, IDanmakuSource)


local _META_CMD_ADD     = 0
local _META_CMD_DELETE  = 1

local _META_SOURCE_TYPE_LOCAL   = 0
local _META_SOURCE_TYPE_CACHED  = 1

local _META_SOURCE_TYPE_CLASS_MAP =
{
    [_META_SOURCE_TYPE_LOCAL]       = _LocalDanmakuSource,
    [_META_SOURCE_TYPE_CACHED]      = _CachedRemoteDanmakuSource,
}

local _META_SOURCE_TYPE_ID_MAP =
{
    [_LocalDanmakuSource]           = _META_SOURCE_TYPE_LOCAL,
    [_CachedRemoteDanmakuSource]    = _META_SOURCE_TYPE_CACHED,
}


local DanmakuSourceManager =
{
    _mApplication               = classlite.declareConstantField(nil),
    _mSerializer                = classlite.declareClassField(_Serializer),
    _mDeserializer              = classlite.declareClassField(_Deserializer),
    _mDanmakuSourcePools        = classlite.declareTableField(),

    __mSerializeArray           = classlite.declareTableField(),
    __mDeserializeArray         = classlite.declareTableField(),
    __mListFilePaths            = classlite.declareTableField(),
    __mDownloadedFilePaths      = classlite.declareTableField(),
    __mDeserializedSources      = classlite.declareTableField(),
    __mReadMetaFileCallback     = classlite.declareTableField(),


    new = function(self)
        self.__mReadMetaFileCallback = function(...)
            return self:__onReadMetaFileTuple(...)
        end
    end,


    dispose = function(self)
        for _, pool in pairs(self._mDanmakuSourcePools)
        do
            utils.forEachArrayElement(pool, utils.disposeSafely)
            utils.clearTable(pool)
        end
    end,


    setApplication = function(self, app)
        self._mApplication = app
    end,


    __onReadMetaFileTuple = function(self, ...)
        local deserializer = self._mDeserializer
        local outSources = self.__mDeserializedSources
        local array = utils.clearTable(self.__mDeserializeArray)
        utils.packArray(array, ...)
        deserializer:init(array)
        self:__deserializeDanmakuSourceCommand(deserializer, outSources)
    end,


    __serializeDanmakuSourceCommand = function(self, serializer, cmdID, source)
        local sourceTypeID = _META_SOURCE_TYPE_ID_MAP[source:getClass()]
        if sourceTypeID
        then
            serializer:writeElement(self._mApplication:getVideoFileMD5())
            serializer:writeElement(cmdID)
            serializer:writeElement(sourceTypeID)
            return source:_serialize(serializer)
        end
    end,


    __deserializeDanmakuSourceCommand = function(self, deserializer, outSources)
        local function __deserializeDanmakuSource(self, deserializer)
            local clzID = deserializer:readElement()
            local sourceClz = clzID and _META_SOURCE_TYPE_CLASS_MAP[clzID]
            if sourceClz
            then
                local source = self:_obtainDanmakuSource(sourceClz)
                if source:_deserialize(deserializer)
                then
                    return source
                end

                self:_recycleDanmakuSource(source)
            end
        end

        if deserializer:readElement() ~= self._mApplication:getVideoFileMD5()
        then
            return
        end

        local cmdID = deserializer:readElement()
        if cmdID == _META_CMD_ADD
        then
            local source = __deserializeDanmakuSource(self, deserializer)
            if source
            then
                table.insert(outSources, source)
                return true
            end
        elseif cmdID == _META_CMD_DELETE
        then
            local source = __deserializeDanmakuSource(self, deserializer)
            if source
            then
                for i, iterSource in utils.reverseIterateArray(outSources)
                do
                    if iterSource:_isDuplicated(source)
                    then
                        table.remove(outSources, i)
                        self:_recycleDanmakuSource(iterSource)
                    end
                end
                self:_recycleDanmakuSource(source)
                return true
            end
        end
    end,


    _obtainDanmakuSource = function(self, srcClz)
        local pool = self._mDanmakuSourcePools[srcClz]
        local ret = pool and utils.popArrayElement(pool) or srcClz:new()
        ret:reset()
        ret:setApplication(self._mApplication)
        return ret
    end,


    _recycleDanmakuSource = function(self, source)
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
            self:_recycleDanmakuSource(source)
            danmakuSources[i] = nil
        end
    end,


    _doReadMetaFile = function(self, deserializeCallback)
        local path = self._mApplication:getDanmakuSourceMetaDataFilePath()
        serialize.deserializeFromFilePath(path, deserializeCallback)
    end,


    _doAppendMetaFile = function(self, cmdID, source)
        local app = self._mApplication
        local array = utils.clearTable(self.__mSerializeArray)
        local serializer = self._mSerializer
        serializer:init(array)
        if self:__serializeDanmakuSourceCommand(serializer, cmdID, source)
        then
            local metaFilePath = app:getDanmakuSourceMetaDataFilePath()
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
            serialize.serializeArray(file, array)
            app:closeFile(file)
        end
    end,


    listDanmakuSources = function(self, outList)
        if not types.isTable(outList)
        then
            return
        end

        -- 读取下载过的弹幕源
        local outDanmakuSources = utils.clearTable(self.__mDeserializedSources)
        self:_doReadMetaFile(self.__mReadMetaFileCallback)
        utils.appendArrayElements(outList, outDanmakuSources)
        utils.clearTable(outDanmakuSources)
    end,


    addCachedDanmakuSource = function(self, sources, plugin, desc, videoIDs, offsets)
        local app = self._mApplication
        local datetime = app:getCurrentDateTime()
        local filePaths = utils.clearTable(self.__mDownloadedFilePaths)
        if __downloadDanmakuRawDataFiles(app, plugin, videoIDs, filePaths)
        then
            local source = self:_obtainDanmakuSource(_CachedRemoteDanmakuSource)
            if source and source:_init(plugin, datetime, desc, videoIDs, filePaths, offsets)
            then
                self:_doAppendMetaFile(_META_CMD_ADD, source)
                utils.pushArrayElement(sources, source)
                return source
            end

            self:_recycleDanmakuSource(source)
        end
    end,


    addLocalDanmakuSource = function(self, sources, plugin, filePath)
        local function __isDuplicated(iterSource, newSource)
            return iterSource:_isDuplicated(newSource)
        end

        local newSource = self:_obtainDanmakuSource(_LocalDanmakuSource)
        if newSource:_init(plugin, filePath)
            and not utils.linearSearchArrayIf(sources, __isDuplicated, newSource)
        then
            self:_doAppendMetaFile(_META_CMD_ADD, newSource)
            utils.pushArrayElement(sources, newSource)
            return newSource
        end

        self:_recycleDanmakuSource(newSource)
    end,


    deleteDanmakuSourceByIndex = function(self, sources, idx)
        local source = types.isTable(sources) and types.isNumber(idx) and sources[idx]
        if classlite.isInstanceOf(source, IDanmakuSource) and sources[idx]:_delete()
        then
            -- 因为不能删外部文件来标记删除，所以在持久化文件里记个反操作
            if classlite.isInstanceOf(source, _LocalDanmakuSource)
            then
                self:_doAppendMetaFile(_META_CMD_DELETE, source)
            end

            -- 外部不要再持有这个对象了
            table.remove(sources, idx)
            self:_recycleDanmakuSource(source)
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
                    if source:_isDuplicated(inSources[j])
                    then
                        found = true
                        break
                    end
                end

                if not found and source:_update(tmpSource)
                then
                    self:_doAppendMetaFile(_META_CMD_ADD, tmpSource)
                    table.insert(outSources, tmpSource)
                    tmpSource = self:_obtainDanmakuSource(_CachedRemoteDanmakuSource)
                end
            end
            self:_recycleDanmakuSource(tmpSource)
        end
    end,
}

classlite.declareClass(DanmakuSourceManager)


return
{
    IDanmakuSource          = IDanmakuSource,
    DanmakuSourceManager    = DanmakuSourceManager,
}
