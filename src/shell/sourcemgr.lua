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

    _init = function(self, array)
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

    writeArray = function(self, array)
        local count = #array
        self:writeElement(count)
        for i = 1, count
        do
            self:writeElement(array[i])
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

    parse = constants.FUNC_EMPTY,
    getDate = constants.FUNC_EMPTY,
    getDescription = constants.FUNC_EMPTY,

    _init = constants.FUNC_EMPTY,
    _delete = constants.FUNC_EMPTY,
    _update = constants.FUNC_EMPTY,
    _serialize = constants.FUNC_EMPTY,
    _deserizlie = constants.FUNC_EMPTY,
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

    _getTypeID = function(self)
        return _META_SOURCE_TYPE_LOCAL
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

    _delete = function(self)
        -- 因为不写入持久化数据，所以认为总是删除成功
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
        if IDanmakuSource._serialize(self, serializer)
        then
            serializer:writeElement(self._mDate)
            serializer:writeElement(self._mDescription)
            serializer:writeArray(self._mVideoIDs)
            serializer:writeArray(self._mFilePaths)
            serializer:writeArray(self._mStartTimeOffsets)
            return true
        end
    end,

    _deserizlie = function(self, deserializer)
        local app = self._mApplication
        if deserializer:readElement() ~= _META_CMD_ADD
            or deserializer:readElement() ~= _META_SOURCE_TYPE_CACHED
            or deserializer:readElement() ~= app:getVideoFileMD5()
        then
            return false
        end

        local succeed = true
        self._mDate = deserializer:readElement()
        self._mDescription = deserializer:readElement()
        succeed = succeed and deserializer:readArray(self._mVideoIDs)
        succeed = succeed and deserializer:readArray(self._mFilePaths)
        succeed = succeed and deserializer:readArray(self._mStartTimeOffsets)
        return succeed and self:_isValid()
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
    __mDanmakuSources           = classlite.declareTableField(),
    __mReadMetaFileCallback     = classlite.declareTableField(),


    new = function(self)
        self.__mReadMetaFileCallback = function(...)
            return self:__onReadMetaFile(...)
        end
    end,


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


    __onReadMetaFile = function(self, ...)
        local deserializer = self._mDeserializer
        local outSources = utils.clearTable(self.__mDanmakuSources)
        local array = utils.clearTable(self.__mDeserializeArray)
        utils.packArray(array, ...)

        local function __tryAddSource(self, deserializer, array, sourceClz, outSources)
            local source = self:_obtainDanmakuSource(sourceClz)
            deserializer:_init(array)
            if source:_deserizlie(deserializer)
            then
                table.insert(outSources, source)
                return true
            end
            self:recycleDanmakuSource(source)
        end

        local function __tryDeleteSource(self, deserializer, array, outSources)
            --TODO
        end

        return __tryAddSource(self, deserializer, array, _CachedRemoteDanmakuSource, outSources)
            or __tryAddSource(self, deserializer, array, _LocalDanmakuSource, outSources)
            or __tryDeleteSource(self, deserializer, array, outSources)
    end,


    _obtainDanmakuSource = function(self, srcClz)
        local pool = self._mDanmakuSourcePools[srcClz]
        local ret = pool and utils.popArrayElement(pool) or srcClz:new()
        ret:setApplication(self._mApplication)
        return ret
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
        local path = self._mApplication:getDanmakuSourceMetaDataFilePath()
        serialize.deserializeFromFilePath(path, deserializeCallback)
    end,


    _doAppendMetaFile = function(self, source)
        local app = self._mApplication
        local array = utils.clearTable(self.__mSerializeArray)
        local serializer = self._mSerializer
        serializer:_init(array)
        if source:_serialize(serializer)
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
        local app = self._mApplication
        local danmakuSources = utils.clearTable(self.__mDanmakuSources)
        self:_doReadMetaFile(self.__mReadMetaFileCallback)
        utils.appendArrayElements(outList, danmakuSources)
    end,


    addCachedDanmakuSource = function(self, plugin, desc, videoIDs, offsets)
        local app = self._mApplication
        local datetime = app:getCurrentDateTime()
        local filePaths = utils.clearTable(self.__mDownloadedFilePaths)
        if __downloadDanmakuRawDataFiles(app, plugin, videoIDs, filePaths)
        then
            local source = self:_obtainDanmakuSource(_CachedRemoteDanmakuSource)
            if source and source:_init(plugin, datetime, desc, videoIDs, filePaths, offsets)
            then
                self:_doAppendMetaFile(source)
                return source
            end

            self:recycleDanmakuSource(source)
        end
    end,


    addLocalDanmakuSource = function(self, sources, plugin, filePath)
        local isDuplicated = false
        local newSource = self:_obtainDanmakuSource(_LocalDanmakuSource)
        if newSource:_init(plugin, filePath)
        then
            for _, source in utils.iterateArray(sources)
            do
                if newSource:_isDuplicated(source)
                then
                    isDuplicated = true
                    break
                end
            end
        end

        if not isDuplicated
        then
            return newSource
        end

        self:recycleDanmakuSource(newSource)
    end,


    deleteDanmakuSource = function(self, source)
        local app = self._mApplication
        if classlite.isInstanceOf(source, IDanmakuSource) and source:_delete()
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
                    if source:_isDuplicated(inSources[j])
                    then
                        found = true
                        break
                    end
                end

                if not found and source:_update(tmpSource)
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
