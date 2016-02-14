local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")


local IDanmakuSourcePlugin =
{
    getName = constants.FUNC_EMPTY,
    parseFile = constants.FUNC_EMPTY,
    parseData = constants.FUNC_EMPTY,
    search = constants.FUNC_EMPTY,
    getDanmakuURLs = constants.FUNC_EMPTY,
    getVideoDurations = constants.FUNC_EMPTY,
    isMatchedRawDataFile = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSourcePlugin)


local StringBasedDanmakuSourcePlugin =
{
    parseFile = function(self, app, filePath, ...)
        local file = app:readUTF8File(filePath)
        local rawData = utils.readAndCloseFile(file)
        return rawData and self:parseData(app, rawData, ...)
    end,
}

classlite.declareClass(StringBasedDanmakuSourcePlugin, IDanmakuSourcePlugin)


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
    StringBasedDanmakuSourcePlugin      = StringBasedDanmakuSourcePlugin,
    DanmakuSourceSearchResult           = DanmakuSourceSearchResult,
}