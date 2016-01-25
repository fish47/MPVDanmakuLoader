local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")


local IDanmakuSourcePlugin =
{
    getName = constants.FUNC_EMPTY,
    parse = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSourcePlugin)


local ILocalDanmakuSourcePlugin =
{
    filter = constants.FUNC_EMPTY,
}

classlite.declareClass(ILocalDanmakuSourcePlugin, IDanmakuSourcePlugin)


local IRemoteDanmakuSourcePlugin =
{
    search = constants.FUNC_EMPTY,
    getDanmakuURLs = constants.FUNC_EMPTY,
    getVideoDurations = constants.FUNC_EMPTY,
}

classlite.declareClass(IRemoteDanmakuSourcePlugin, IDanmakuSourcePlugin)


return
{
    IDanmakuSourcePlugin        = IDanmakuSourcePlugin,
    ILocalDanmakuSourcePlugin   = ILocalDanmakuSourcePlugin,
    IRemoteDanmakuSourcePlugin  = IRemoteDanmakuSourcePlugin,
}