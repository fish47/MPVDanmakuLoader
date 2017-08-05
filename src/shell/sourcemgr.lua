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
        app:deletePath(fullPath)
    end
    utils.forEachArrayElement(filePaths, __deleteFile, app)
    utils.clearTable(filePaths)
end


local function __downloadDanmakuRawDataFiles(app, plugin, videoIDs, outFilePaths)
    if not classlite.isInstanceOf(app, application.MPVDanmakuLoaderApp)
        or not types.isNonEmptyArray(videoIDs)
        or not types.isTable(outFilePaths)
    then
        return false
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
    local rawDataList = utils.clearTable(outFilePaths)
    local downloaded = plugin:downloadDanmakuRawDataList(videoIDs, rawDataList)
    if not downloaded
    then
        utils.clearTable(rawDataList)
        return false
    end

    for i, rawData in utils.iterateArray(rawDataList)
    do
        local suffix = string.format(_RAW_DATA_FILE_FMT_SUFFIX, i)
        local fullPath = app:getUniqueFilePath(baseDir, _RAW_DATA_FILE_PREFIX, suffix)
        local succeed = utils.writeAndCloseFile(app, fullPath, rawData)
        if not succeed
        then
            utils.clearArray(rawDataList, i)
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
}

function __ArrayAndCursorMixin:init(array)
    self._mArray = array
    self._mCursor = 1
end

classlite.declareClass(__ArrayAndCursorMixin)


local _Deserializer = {}

function _Deserializer:readElement()
    local ret = self._mArray[self._mCursor]
    self._mCursor = self._mCursor + 1
    return ret
end

function _Deserializer:readArray(outArray)
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
end

classlite.declareClass(_Deserializer, __ArrayAndCursorMixin)


local _Serializer = {}

function _Serializer:writeElement(elem)
    self._mArray[self._mCursor] = elem
    self._mCursor = self._mCursor + 1
end

function _Serializer:writeArray(array, hook, arg)
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
end

classlite.declareClass(_Serializer, __ArrayAndCursorMixin)



local IDanmakuSource =
{
    _mApplication   = classlite.declareConstantField(nil),
    _mPlugin        = classlite.declareConstantField(nil),

    parse           = constants.FUNC_EMPTY,
    getDate         = constants.FUNC_EMPTY,
    getDescription  = constants.FUNC_EMPTY,

    _init           = constants.FUNC_EMPTY,
    _delete         = constants.FUNC_EMPTY,
    _update         = constants.FUNC_EMPTY,
    _isDuplicated   = constants.FUNC_EMPTY,
}

function IDanmakuSource:setApplication(app)
    self._mApplication = app
end

function IDanmakuSource:getPluginName()
    local plugin = self._mPlugin
    return plugin and plugin:getName()
end

function IDanmakuSource:_serialize(serializer)
    if serializer and self:_isValid()
    then
        serializer:writeElement(self:getPluginName())
        return true
    end
end

function IDanmakuSource:_deserialize(deserializer)
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
end

classlite.declareClass(IDanmakuSource)


local _LocalDanmakuSource =
{
    _mPlugin        = classlite.declareConstantField(nil),
    _mFilePath      = classlite.declareConstantField(nil),
}

function _LocalDanmakuSource:_init(plugin, filePath)
    self._mPlugin = plugin
    self._mFilePath = filePath
    return self:_isValid()
end

function _LocalDanmakuSource:parse()
    if not self:_isValid()
    then
        return
    end
    local plugin = self._mPlugin
    local path = self._mFilePath
    local offset = _DEFAULT_START_TIME_OFFSET
    local pools = self._mApplication:getDanmakuPools()
    local name = plugin:getName()
    local sourceID = pools:allocateDanmakuSourceID(name, nil, nil, offset, path)
    plugin:parseFile(path, sourceID, offset)
end

function _LocalDanmakuSource:_isValid()
    return classlite.isInstanceOf(self._mPlugin, pluginbase.IDanmakuSourcePlugin)
        and self._mApplication:isExistedFile(self._mFilePath)
end

function _LocalDanmakuSource:getDescription()
    local filePath = self._mFilePath
    if types.isString(filePath)
    then
        local _, fileName = unportable.splitPath(filePath)
        return fileName
    end
end

function _LocalDanmakuSource:_serialize(serializer)
    if IDanmakuSource._serialize(self, serializer)
    then
        local cacheDir = self._mApplication:getDanmakuSourceRawDataDirPath()
        serializer:writeElement(unportable.getRelativePath(cacheDir, self._mFilePath))
        return true
    end
end

function _LocalDanmakuSource:_deserialize(deserializer)
    if IDanmakuSource._deserialize(self, deserializer)
    then
        local relPath = deserializer:readElement()
        local cacheDir = self._mApplication:getDanmakuSourceRawDataDirPath()
        self._mFilePath = unportable.joinPath(cacheDir, relPath)
        return self:_isValid()
    end
end

function _LocalDanmakuSource:_delete()
    return true
end

function _LocalDanmakuSource:_isDuplicated(source2)
    -- 一个文件不能对应多个弹幕源
    return classlite.isInstanceOf(source2, self:getClass())
        and self._mFilePath == source2._mFilePath
end

classlite.declareClass(_LocalDanmakuSource, IDanmakuSource)


local _CachedRemoteDanmakuSource =
{
    _mPlugin            = classlite.declareConstantField(nil),
    _mDate              = classlite.declareConstantField(0),
    _mDescription       = classlite.declareConstantField(nil),
    _mVideoIDs          = classlite.declareTableField(),
    _mFilePaths         = classlite.declareTableField(),
    _mStartTimeOffsets  = classlite.declareTableField(),
}

function _CachedRemoteDanmakuSource:_init(plugin, date, desc, videoIDs, paths, offsets)
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
end

function _CachedRemoteDanmakuSource:getDate()
    return self._mDate
end

function _CachedRemoteDanmakuSource:getDescription()
    return self._mDescription
end

function _CachedRemoteDanmakuSource:parse()
    if not self:_isValid()
    then
        return
    end
    local name = self._mPlugin:getName()
    local videoIDs = self._mVideoIDs
    local timeOffsets = self._mStartTimeOffsets
    local pools = self._mApplication:getDanmakuPools()
    for i, path in utils.iterateArray(self._mFilePaths)
    do
        local vid = videoIDs[i]
        local offset = timeOffsets[i]
        local sourceID = pools:allocateDanmakuSourceID(name, vid, i, offset, path)
        self._mPlugin:parseFile(path, sourceID, offset)
    end
end


function _CachedRemoteDanmakuSource:_isValid()
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
end

function _CachedRemoteDanmakuSource:_serialize(serializer)
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
end

function _CachedRemoteDanmakuSource:_deserialize(deserializer)
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
end


function _CachedRemoteDanmakuSource:_delete()
    -- 只要删除原始文件，反序列化的时候就被认为是无效的弹幕源
    local app = self._mApplication
    for _, path in utils.iterateArray(self._mFilePaths)
    do
        app:deletePath(path)
    end
    return true
end


function _CachedRemoteDanmakuSource:_update(source2)
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
        else
            __deleteDownloadedFiles(app, filePaths)
            return false
        end
    end
end


function _CachedRemoteDanmakuSource:_isDuplicated(source2)
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
end

classlite.declareClass(_CachedRemoteDanmakuSource, IDanmakuSource)


local _META_CMD_ADD     = 0
local _META_CMD_DELETE  = 1

local _META_SOURCE_TYPE_LOCAL   = 0
local _META_SOURCE_TYPE_CACHED  = 1

local _META_SOURCE_TYPE_ID_CLASS_MAP =
{
    _META_SOURCE_TYPE_LOCAL,    _LocalDanmakuSource,
    _META_SOURCE_TYPE_CACHED,   _CachedRemoteDanmakuSource,
}

local function __findSourceTypeEntry(startOffset, step, resultOffset, obj)
    if types.isNil(obj)
    then
        return obj
    end
    local map = _META_SOURCE_TYPE_ID_CLASS_MAP
    for i = startOffset, #map, step
    do
        if map[i] == obj
        then
            return map[i + resultOffset]
        end
    end
    return nil
end

local function _getSourceClassBySourceType(clz)
    return __findSourceTypeEntry(1, 2, 1, clz)
end

local function _getSourceTypeBySourceClass(sourceType)
    return __findSourceTypeEntry(2, 2, -1, sourceType)
end


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
}

function DanmakuSourceManager:new()
    self.__mReadMetaFileCallback = function(...)
        return self:__onReadMetaFileTuple(...)
    end
end


function DanmakuSourceManager:dispose()
    for _, pool in pairs(self._mDanmakuSourcePools)
    do
        utils.forEachArrayElement(pool, utils.disposeSafely)
        utils.clearTable(pool)
    end
end


function DanmakuSourceManager:setApplication(app)
    self._mApplication = app
end


function DanmakuSourceManager:__onReadMetaFileTuple(...)
    local deserializer = self._mDeserializer
    local outSources = self.__mDeserializedSources
    local array = utils.clearTable(self.__mDeserializeArray)
    utils.packArray(array, ...)
    deserializer:init(array)
    self:__deserializeDanmakuSourceCommand(deserializer, outSources)
end


function DanmakuSourceManager:__serializeDanmakuSourceCommand(serializer, cmdID, source)
    local sourceTypeID = _getSourceTypeBySourceClass(source:getClass())
    if sourceTypeID
    then
        serializer:writeElement(self._mApplication:getVideoFileMD5())
        serializer:writeElement(cmdID)
        serializer:writeElement(sourceTypeID)
        return source:_serialize(serializer)
    end
end


function DanmakuSourceManager:__deserializeDanmakuSourceCommand(deserializer, outSources)
    local function __deserializeDanmakuSource(self, deserializer)
        local clzID = deserializer:readElement()
        local sourceClz = _getSourceClassBySourceType(clzID)
        if sourceClz
        then
            local source = self:__obtainDanmakuSource(sourceClz)
            if source:_deserialize(deserializer)
            then
                return source
            end

            self:__recycleDanmakuSource(source)
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
                    self:__recycleDanmakuSource(iterSource)
                end
            end
            self:__recycleDanmakuSource(source)
            return true
        end
    end
end

function DanmakuSourceManager:_createDanmakuSource(srcClz)
    return srcClz:new()
end

function DanmakuSourceManager:__obtainDanmakuSource(srcClz)
    local pool = self._mDanmakuSourcePools[srcClz]
    local ret = utils.popArrayElement(pool) or self:_createDanmakuSource(srcClz)
    ret:reset()
    ret:setApplication(self._mApplication)
    return ret
end

function DanmakuSourceManager:__recycleDanmakuSource(source)
    if classlite.isInstanceOf(source, IDanmakuSource)
    then
        local clz = source:getClass()
        local pools = self._mDanmakuSourcePools
        local pool = pools[clz]
        if not pool
        then
            pool = {}
            pools[clz] = pool
        end
        table.insert(pool, source)
    end
end


function DanmakuSourceManager:recycleDanmakuSources(danmakuSources)
    for i, source in utils.iterateArray(danmakuSources)
    do
        self:__recycleDanmakuSource(source)
        danmakuSources[i] = nil
    end
end


function DanmakuSourceManager:_doReadMetaFile(deserializeCallback)
    local path = self._mApplication:getDanmakuSourceMetaDataFilePath()
    serialize.deserializeFromFilePath(path, deserializeCallback)
end


function DanmakuSourceManager:_doAppendMetaFile(cmdID, source)
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

        local file = app:writeFile(metaFilePath, true)
        serialize.serializeArray(file, array)
        app:closeFile(file)
    end
end


function DanmakuSourceManager:listDanmakuSources(outList)
    if not types.isTable(outList)
    then
        return
    end

    -- 读取下载过的弹幕源
    local outDanmakuSources = utils.clearTable(self.__mDeserializedSources)
    self:_doReadMetaFile(self.__mReadMetaFileCallback)
    utils.appendArrayElements(outList, outDanmakuSources)
    utils.clearTable(outDanmakuSources)
end


function DanmakuSourceManager:addCachedDanmakuSource(sources, plugin, desc,
                                                     videoIDs, offsets)
    local app = self._mApplication
    local datetime = app:getCurrentDateTime()
    local filePaths = utils.clearTable(self.__mDownloadedFilePaths)
    local downloaded = __downloadDanmakuRawDataFiles(app, plugin, videoIDs, filePaths)
    if downloaded
    then
        local source = self:__obtainDanmakuSource(_CachedRemoteDanmakuSource)
        if source and source:_init(plugin, datetime, desc, videoIDs, filePaths, offsets)
        then
            self:_doAppendMetaFile(_META_CMD_ADD, source)
            utils.pushArrayElement(sources, source)
            return source
        end

        self:__recycleDanmakuSource(source)
    end
    return nil
end


function DanmakuSourceManager:addLocalDanmakuSource(sources, plugin, filePath)
    local function __isDuplicated(iterSource, newSource)
        return iterSource:_isDuplicated(newSource)
    end

    local newSource = self:__obtainDanmakuSource(_LocalDanmakuSource)
    if newSource:_init(plugin, filePath)
        and not utils.linearSearchArrayIf(sources, __isDuplicated, newSource)
    then
        self:_doAppendMetaFile(_META_CMD_ADD, newSource)
        utils.pushArrayElement(sources, newSource)
        return newSource
    end

    self:__recycleDanmakuSource(newSource)
end


function DanmakuSourceManager:deleteDanmakuSourceByIndex(sources, idx)
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
        self:__recycleDanmakuSource(source)
        return true
    end
end


function DanmakuSourceManager:updateDanmakuSources(inSources, outSources)
    local function __checkIsNotDanmakuSource(source)
        return not classlite.isInstanceOf(source, IDanmakuSource)
    end

    if types.isNonEmptyArray(inSources)
        and types.isNonEmptyArray(outSources)
        and not utils.linearSearchArrayIf(inSources, __checkIsNotDanmakuSource)
    then
        -- 注意输入和输出有可能是同一个 table
        local app = self._mApplication
        local tmpSource = self:__obtainDanmakuSource(_CachedRemoteDanmakuSource)
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
                tmpSource = self:__obtainDanmakuSource(_CachedRemoteDanmakuSource)
            end
        end
        self:__recycleDanmakuSource(tmpSource)
    end
end

classlite.declareClass(DanmakuSourceManager)


return
{
    IDanmakuSource          = IDanmakuSource,
    DanmakuSourceManager    = DanmakuSourceManager,
}
