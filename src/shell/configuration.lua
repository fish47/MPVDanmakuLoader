local types     = require("src/base/types")
local utils     = require("src/base/utils")


local function initConfiguration(cfg)
    cfg = utils.clearTable(types.isTable(cfg) and cfg or {})

    -- 弹幕属性
    cfg.bottomReservedHeight    = 0                 -- 弹幕底部预留空间
    cfg.danmakuFontSize         = 34                -- 弹幕默认字体大小
    cfg.danmakuFontName         = "sans-serif"      -- 弹幕默认字体名
    cfg.danmakuFontColor        = 0x33FFFFFF        -- 弹幕默认颜色 BBGGRR
    cfg.subtitleFontSize        = 34                -- 字幕默认字体大小
    cfg.subtitleFontName        = "mono"            -- 字幕默认字体名
    cfg.subtitleFontColor       = 0xFFFFFFFF        -- 字幕默认颜色 BBGGRR
    cfg.movingDanmakuLifeTime   = 8000              -- 滚动弹幕存活时间
    cfg.staticDanmakuLIfeTime   = 5000              -- 固定位置弹幕存活时间

    -- 路径相关
    cfg.trashDirPath            = nil               -- 如果不为空，所有删除都替换成移动，前提是目录存在
    cfg.rawDataRelDirPath       = "rawdata"         -- 下载到本地的弹幕源原始数据目录
    cfg.metaDataRelFilePath     = "sourcemeta.lua"  -- 记录弹幕源的原始信息

    -- 钩子函数
    cfg.addDanmakuHook          = nil               -- 修改或过滤弹幕
    cfg.writeSubtitleHook       = nil               -- 为字幕添加样式

    -- 设置
    cfg.showDebugLog            = true              -- 是否输出调试信息
    cfg.pauseWhileShowing       = true              -- 弹窗后是否暂停播放

    return cfg
end


return
{
    initConfiguration       = initConfiguration,
}