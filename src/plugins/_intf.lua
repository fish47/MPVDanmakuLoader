local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")


local SOURCE_TYPE_LOCAL     = 0
local SOURCE_TYPE_REMOTE    = 1

local IDanmakuSourcePlugin =
{
    getType = constants.FUNC_EMPTY,
    getName = constants.FUNC_EMPTY,
    search = constants.FUNC_EMPTY,
    parse = constants.FUNC_EMPTY,
    getDanmakuURLs = constants.FUNC_EMPTY,
    getVideoDurations = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSourcePlugin)


return
{
    SOURCE_TYPE_LOCAL       = SOURCE_TYPE_LOCAL,
    SOURCE_TYPE_REMOTE      = SOURCE_TYPE_REMOTE,
    IDanmakuSourcePlugin    = IDanmakuSourcePlugin,
}