local utils         = require("src/base/utils")
local types         = require("src/base/types")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")
local danmakupool   = require("src/core/danmakupool")


local IDanmakuSourcePlugin =
{
    _mApplication   = classlite.declareConstantField(nil),

    getName                 = constants.FUNC_EMPTY,
    parseFile               = constants.FUNC_EMPTY,
    parseData               = constants.FUNC_EMPTY,
    search                  = constants.FUNC_EMPTY,
    getVideoDurations       = constants.FUNC_EMPTY,
    downloadDanmakuRawDatas = constants.FUNC_EMPTY,
}

local function __initConnectionRequestFlags(conn, acceptXML, uncompress)
    conn:resetRequestFlags()
    conn:setAcceptXML(acceptXML)
    conn:setUncompress(uncompress)
    return conn
end

function IDanmakuSourcePlugin:_initRequestFlagsForCompressedXML(conn)
    return __initConnectionRequestFlags(conn, true, true)
end

function IDanmakuSourcePlugin:_initRequestFlagsForXML(conn)
    return __initConnectionRequestFlags(conn, true, false)
end


function IDanmakuSourcePlugin:setApplication(app)
    self._mApplication = app
end

classlite.declareClass(IDanmakuSourcePlugin)


local function __doInvokeVideoIDsBasedMethod(self, videoIDs, outList, iterFunc)
    local function __appendResult(ret, outList)
        utils.pushArrayElement(outList, ret)
    end

    if types.isTable(videoIDs) and types.isTable(outList)
    then
        local conn = self._mApplication:getNetworkConnection()
        for _, videoID in ipairs(videoIDs)
        do
            local ret = iterFunc(self, conn, videoID, outList)
            if types.isString(ret)
            then
                conn:receiveLater(ret, __appendResult, outList)
            end
        end
        conn:flushReceiveQueue()
    end
end


local _AbstractDanmakuSourcePlugin =
{
    _doDownloadDanmakuRawData   = constants.FUNC_EMPTY,
    _doGetVideoDuration         = constants.FUNC_EMPTY,
}

function _AbstractDanmakuSourcePlugin:parseFile(filePath, ...)
    local rawData = utils.readAndCloseFile(self._mApplication, filePath, true)
    if rawData
    then
        self:parseData(rawData, ...)
    end
end

function _AbstractDanmakuSourcePlugin:downloadDanmakuRawDatas(videoIDs, outDatas)
    local iterFunc = self._doDownloadDanmakuRawData
    return __doInvokeVideoIDsBasedMethod(self, videoIDs, outDatas, iterFunc)
end

function _AbstractDanmakuSourcePlugin:getVideoDurations(videoIDs, outDurations)
    local iterFunc = self._doGetVideoDuration
    return __doInvokeVideoIDsBasedMethod(self, videoIDs, outDurations, iterFunc)
end

classlite.declareClass(_AbstractDanmakuSourcePlugin, IDanmakuSourcePlugin)


local _PatternBasedDanmakuSourcePlugin =
{
    __mDanmakuData     = classlite.declareClassField(danmaku.DanmakuData),

    _extractDanmaku         = constants.FUNC_EMPTY,
    _startExtractDanmakus   = constants.FUNC_EMPTY,
}

function _PatternBasedDanmakuSourcePlugin:_getLifeTimeByLayer(cfg, pos)
    if pos == danmakupool.LAYER_MOVING_L2R or pos == danmakupool.LAYER_MOVING_R2L
    then
        return cfg.movingDanmakuLifeTime
    elseif pos == danmakupool.LAYER_STATIC_TOP or pos == danmakupool.LAYER_STATIC_BOTTOM
    then
        return cfg.staticDanmakuLIfeTime
    else
        -- 依靠弹幕池的参数检查来过滤
    end
end


function _PatternBasedDanmakuSourcePlugin:parseData(rawData, sourceID, timeOffset)
    if types.isNilOrEmptyString(rawData)
        or not classlite.isInstanceOf(sourceID, danmaku.DanmakuSourceID)
    then
        return
    end

    local app = self._mApplication
    local pools = app:getDanmakuPools()
    local cfg = app:getConfiguration()
    local iterFunc = self:_startExtractDanmakus(rawData)
    local danmakuData = self.__mDanmakuData
    timeOffset = timeOffset or 0
    while true
    do
        local layer = self:_extractDanmaku(iterFunc, cfg, danmakuData)
        if not layer
        then
            break
        end

        danmakuData.startTime = danmakuData.startTime + timeOffset
        danmakuData.lifeTime = self:_getLifeTimeByLayer(cfg, layer)
        danmakuData.sourceID = sourceID

        local pool = pools:getDanmakuPoolByLayer(layer)
        if pool
        then
            pool:addDanmaku(danmakuData)
        end
    end
end

classlite.declareClass(_PatternBasedDanmakuSourcePlugin, _AbstractDanmakuSourcePlugin)


local DanmakuSourceSearchResult =
{
    isSplited               = classlite.declareConstantField(false),
    videoIDs                = classlite.declareTableField(),
    videoTitles             = classlite.declareTableField(),
    videoTitleColumnCount   = classlite.declareConstantField(1),
    preferredIDIndex        = classlite.declareConstantField(1),
}

classlite.declareClass(DanmakuSourceSearchResult)


return
{
    IDanmakuSourcePlugin                = IDanmakuSourcePlugin,
    _AbstractDanmakuSourcePlugin        = _AbstractDanmakuSourcePlugin,
    _PatternBasedDanmakuSourcePlugin    = _PatternBasedDanmakuSourcePlugin,
    DanmakuSourceSearchResult           = DanmakuSourceSearchResult,
}
