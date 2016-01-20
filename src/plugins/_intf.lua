local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")


local SOURCE_TYPE_LOCAL     = 0
local SOURCE_TYPE_REMOTE    = 1

local IDanmakuSourcePlugin =
{
    -- 弹幕源类型
    getType = constants.FUNC_EMPTY,

    -- 返回字符串，保证插件之间不重名
    getName = constants.FUNC_EMPTY,

    -- 解释弹幕数据
    parse = constants.FUNC_EMPTY,

    -- 根据当前播放的网络视频，直接返回弹幕源网址
    getFuzzyMatchedDanmakuURL = constants.FUNC_EMPTY,

    -- 根据 ID 获取弹幕原始数据的下载路径
    getDanmakuURLs = constants.FUNC_EMPTY,

    -- 根据 ID 获取分集视频长度，合并分集视频弹幕时会用到
    getVideoPartDurations = constants.FUNC_EMPTY,

    -- 根据搜索内容显示弹幕源，当插件能处理搜索请求时才返回 true
    buildDanmakuSourceListBox = constants.FUNC_EMPTY,
}

classlite.declareClass(IDanmakuSourcePlugin)


return
{
    SOURCE_TYPE_LOCAL       = SOURCE_TYPE_LOCAL,
    SOURCE_TYPE_REMOTE      = SOURCE_TYPE_REMOTE,
    IDanmakuSourcePlugin    = IDanmakuSourcePlugin,
}