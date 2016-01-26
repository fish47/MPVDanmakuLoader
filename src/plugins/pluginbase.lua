local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")


local IDanmakuSourcePlugin =
{
    getName = constants.FUNC_EMPTY,
    parse = constants.FUNC_EMPTY,
    search = constants.FUNC_EMPTY,
    getDanmakuURLs = constants.FUNC_EMPTY,
    getVideoDurations = constants.FUNC_EMPTY,
    isMatchedRawDataFile = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSourcePlugin)

return
{
    IDanmakuSourcePlugin        = IDanmakuSourcePlugin,
}