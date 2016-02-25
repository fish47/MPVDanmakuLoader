local utils         = require("src/base/utils")
local types         = require("src/base/types")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")


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


local _PatternBasedDanmakuSourcePlugin =
{
    _getGMatchPattern = constants.FUNC_EMPTY,
    _extractDanmaku = constants.FUNC_EMPTY,
    _getDanmakuRawDataDownloadURL = constants.FUNC_EMPTY,

    parseFile = function(self, app, filePath, ...)
        local file = app:readUTF8File(filePath)
        local rawData = utils.readAndCloseFile(file)
        return rawData and self:parseData(app, rawData, ...)
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
        local iterFunc = rawData:gmatch(pattern)
        timeOffset = timeOffset or 0

        local hasMore = true
        while hasMore
        do
            hasMore = __addDanmaku(pools, timeOffset, self:_extractDanmaku(iterFunc, cfg))
        end
    end,


    _prepareToDownloadDanmakuRawDatas = function(self, conn)
        conn:resetParams()
        conn:addHeader(_HEADER_USER_AGENT)
    end,


    downloadDanmakuRawDatas = function(self, videoIDs, outDatas)
        local function __addRawData(rawData, outDatas)
            utils.pushArrayElement(outDatas, rawData)
        end

        local conn = self._mApplication:getNetworkConnection()
        self:_prepareToDownloadDanmakuRawDatas(conn)
        for _, videoID in utils.iterateArray(videoIDs)
        do
            local url = self:_getDanmakuRawDataDownloadURL(videoID)
            conn:receiveLater(url, __addRawData, outDatas)
        end
        conn:flushReceiveQueue()
    end,
}

classlite.declareClass(_PatternBasedDanmakuSourcePlugin, IDanmakuSourcePlugin)


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
    _PatternBasedDanmakuSourcePlugin    = _PatternBasedDanmakuSourcePlugin,
    DanmakuSourceSearchResult           = DanmakuSourceSearchResult,
}