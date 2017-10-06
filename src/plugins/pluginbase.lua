local utils         = require("src/base/utils")
local types         = require("src/base/types")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")
local danmakupool   = require("src/core/danmakupool")


local IDanmakuSourcePlugin =
{
    _mApplication       = classlite.declareConstantField(nil),

    getName             = constants.FUNC_EMPTY,
    parseFile           = constants.FUNC_EMPTY,
    parseData           = constants.FUNC_EMPTY,
    search              = constants.FUNC_EMPTY,
    downloadDanmakus    = constants.FUNC_EMPTY,
}

local function __initConnectionRequestFlags(app, arg, acceptXML, uncompress)
    local conn = arg or app:getNetworkConnection()
    conn:resetRequestFlags()
    conn:setAcceptXML(acceptXML)
    conn:setUncompress(uncompress)
    return conn
end

function IDanmakuSourcePlugin:_startRequestUncompressedData(conn)
    return __initConnectionRequestFlags(self._mApplication, conn, false, true)
end

function IDanmakuSourcePlugin:_startRequestUncompressedXML(conn)
    return __initConnectionRequestFlags(self._mApplication, conn, true, true)
end

function IDanmakuSourcePlugin:setApplication(app)
    self._mApplication = app
end

classlite.declareClass(IDanmakuSourcePlugin)


local _AbstractDanmakuSourcePlugin =
{

    __mDanmakuData              = classlite.declareClassField(danmaku.DanmakuData),

    _extractDanmaku             = constants.FUNC_EMPTY,
    _startExtractDanmakus       = constants.FUNC_EMPTY,
    _prepareToDownloadDanmaku   = constants.FUNC_EMPTY,
}

function _AbstractDanmakuSourcePlugin:_getNetworkConnection()
    return self._mApplication:getNetworkConnection()
end

function _AbstractDanmakuSourcePlugin:getVideoIDs(cache, indexes, outList)
    return cache:_getVideoIDs(self, indexes, outList)
end

function _AbstractDanmakuSourcePlugin:getVideoTitles(cache, indexes, outList)
    return cache:_getVideoTitles(self, indexes, outLists)
end

function _AbstractDanmakuSourcePlugin:parseFile(filePath, ...)
    local rawData = utils.readAndCloseFile(self._mApplication, filePath, true)
    if rawData
    then
        self:parseData(rawData, ...)
    end
end

function _AbstractDanmakuSourcePlugin:downloadDanmakus(videoIDs, outList)
    local function __appendResult(ret, outList)
        utils.pushArrayElement(outList, ret)
    end

    if types.isNonEmptyArray(videoIDs)
    then
        local conn = self:_getNetworkConnection()
        for _, videoID in ipairs(videoIDs)
        do
            local url = self:_prepareToDownloadDanmaku(conn, videoID)
            conn:receiveLater(url, __appendResult, outList)
        end
        return conn:flushReceiveQueue()
    else
        return false
    end
end


function _AbstractDanmakuSourcePlugin:_getLifeTimeByLayer(cfg, pos)
    if pos == danmakupool.LAYER_MOVING_L2R or pos == danmakupool.LAYER_MOVING_R2L
    then
        return cfg.movingDanmakuLifeTime
    elseif pos == danmakupool.LAYER_STATIC_TOP or pos == danmakupool.LAYER_STATIC_BOTTOM
    then
        return cfg.staticDanmakuLIfeTime
    else
        -- 依靠弹幕池的参数检查来过滤异常情况
    end
end


function _AbstractDanmakuSourcePlugin:parseData(rawData, sourceID, timeOffset)
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

classlite.declareClass(_AbstractDanmakuSourcePlugin, IDanmakuSourcePlugin)


local DanmakuSourceSearchResult =
{
    videoIDs                = classlite.declareTableField(),
    videoTitles             = classlite.declareTableField(),
    videoTitleColumnCount   = classlite.declareConstantField(1),
}

classlite.declareClass(DanmakuSourceSearchResult)


return
{
    IDanmakuSourcePlugin                = IDanmakuSourcePlugin,
    _AbstractDanmakuSourcePlugin        = _AbstractDanmakuSourcePlugin,
    DanmakuSourceSearchResult            = DanmakuSourceSearchResult,
}
