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
    local function __appendResult(outList, ret)
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

    parseFile = function(self, app, filePath, ...)
        local file = app:readUTF8File(filePath)
        local rawData = utils.readAndCloseFile(file)
        return rawData and self:parseData(app, rawData, ...)
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
    _extractDanmaku = constants.FUNC_EMPTY,
    _startExtractDanmakus = constants.FUNC_EMPTY,

    _getLifeTimeByLayer = function(self, cfg, pos)
        if pos == danmaku.LAYER_MOVING_L2R or pos == danmaku.LAYER_MOVING_L2R
        then
            return cfg.movingDanmakuLifeTime
        elseif pos == danmaku.LAYER_STATIC_TOP or pos == danmaku.LAYER_STATIC_BOTTOM
        then
            return cfg.staticDanmakuLIfeTime
        else
            -- 依靠弹幕池的参数检查来过滤
        end
    end,


    parseData = function(self, app, rawData, timeOffset, sourceID)
        local function __addDanmaku(pools, offset, layer, start, ...)
            if not layer
            then
                return false
            end

            local pool = pools:getDanmakuPoolByLayer(layer)
            if pool
            then
                pool:addDanmaku(start + offset, ...)
            end
            return true
        end


        local pattern = self:_getGMatchPattern()
        if not types.isString(rawData) or not types.isString(pattern)
        then
            return
        end

        local pools = app:getDanmakuPools()
        local cfg = app:getConfiguration()
        local iterFunc = self:_startExtractDanmakus(rawData)
        timeOffset = timeOffset or 0
        while true
        do
            local hasMore = __addDanmaku(pools, timeOffset, self:_extractDanmaku(iterFunc, cfg))
            if not hasMore
            then
                break
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