local utils         = require("src/base/utils")
local types         = require("src/base/types")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local danmaku       = require("src/core/danmaku")


local _HEADER_USER_AGENT    = "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:44.0) Gecko/20100101 Firefox/44.0"
local _HEADER_ACCEPT_XML    = "Accept: application/xml"


local IDanmakuSourcePlugin =
{
    _mApplication   = classlite.declareConstantField(nil),

    setApplication = function(self, app)
        self._mApplication = app
    end,

    getName = constants.FUNC_EMPTY,
    parseFile = constants.FUNC_EMPTY,
    parseData = constants.FUNC_EMPTY,
    search = constants.FUNC_EMPTY,
    getVideoDurations = constants.FUNC_EMPTY,
    downloadDanmakuRawDatas = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSourcePlugin)


local function __doInvokeVideoIDsBasedMethod(self, videoIDs, outList, iterFunc)
    local function __appendResult(ret, outList)
        table.insert(outList, ret)
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
    _doDownloadDanmakuRawData = constants.FUNC_EMPTY,
    _doGetVideoDuration = constants.FUNC_EMPTY,

    parseFile = function(self, filePath, ...)
        local file = self._mApplication:readUTF8File(filePath)
        local rawData = utils.readAndCloseFile(file)
        return rawData and self:parseData(rawData, ...)
    end,

    downloadDanmakuRawDatas = function(self, videoIDs, outDatas)
        local iterFunc = self._doDownloadDanmakuRawData
        return __doInvokeVideoIDsBasedMethod(self, videoIDs, outDatas, iterFunc)
    end,

    getVideoDurations = function(self, videoIDs, outDurations)
        local iterFunc = self._doGetVideoDuration
        return __doInvokeVideoIDsBasedMethod(self, videoIDs, outDurations, iterFunc)
    end,
}

classlite.declareClass(_AbstractDanmakuSourcePlugin, IDanmakuSourcePlugin)


local _PatternBasedDanmakuSourcePlugin =
{
    __mTmpArray     = classlite.declareTableField(),

    _extractDanmaku = constants.FUNC_EMPTY,
    _startExtractDanmakus = constants.FUNC_EMPTY,

    _getLifeTimeByLayer = function(self, cfg, pos)
        if pos == danmaku.LAYER_MOVING_L2R or pos == danmaku.LAYER_MOVING_R2L
        then
            return cfg.movingDanmakuLifeTime
        elseif pos == danmaku.LAYER_STATIC_TOP or pos == danmaku.LAYER_STATIC_BOTTOM
        then
            return cfg.staticDanmakuLIfeTime
        else
            -- 依靠弹幕池的参数检查来过滤
        end
    end,


    parseData = function(self, rawData, sourceID, timeOffset)
        local app = self._mApplication
        local pools = app:getDanmakuPools()
        local cfg = app:getConfiguration()
        local iterFunc = self:_startExtractDanmakus(rawData)
        local danmakuData = self.__mTmpArray
        timeOffset = timeOffset or 0
        while true
        do
            local layer = self:_extractDanmaku(iterFunc, cfg, utils.clearTable(danmakuData))
            if not layer
            then
                break
            end

            local startTime = danmakuData[danmaku.DANMAKU_IDX_START_TIME]
            danmakuData[danmaku.DANMAKU_IDX_START_TIME] = startTime + timeOffset
            danmakuData[danmaku.DANMAKU_IDX_LIFE_TIME] = self:_getLifeTimeByLayer(cfg, layer)
            danmakuData[danmaku.DANMAKU_IDX_SOURCE_ID] = sourceID

            local pool = pools:getDanmakuPoolByLayer(layer)
            if pool
            then
                pool:addDanmaku(danmakuData)
            end
        end
    end,
}

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
    _HEADER_USER_AGENT                  = _HEADER_USER_AGENT,
    _HEADER_ACCEPT_XML                  = _HEADER_ACCEPT_XML,

    IDanmakuSourcePlugin                = IDanmakuSourcePlugin,
    _AbstractDanmakuSourcePlugin        = _AbstractDanmakuSourcePlugin,
    _PatternBasedDanmakuSourcePlugin    = _PatternBasedDanmakuSourcePlugin,
    DanmakuSourceSearchResult           = DanmakuSourceSearchResult,
}