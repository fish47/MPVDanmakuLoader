local types     = require("src/base/types")
local utils     = require("src/base/utils")


local function initConfiguration(cfg)
    cfg = utils.clearTable(types.isTable(cfg) and cfg or {})

    -- 弹幕属性
    cfg.bottomReservedHeight    = 30                -- 弹幕底部预留空间
    cfg.danmakuFontSize         = 34                -- 弹幕默认字体大小
    cfg.danmakuFontName         = "sans-serif"      -- 弹幕默认字体名
    cfg.danmakuFontColor        = 0xFFFFFF          -- 弹幕默认颜色 RRGGBB
    cfg.subtitleFontSize        = 34                -- 字幕默认字体大小
    cfg.subtitleFontName        = "mono"            -- 字幕默认字体名
    cfg.subtitleFontColor       = 0xFFFFFF          -- 字幕默认颜色 RRGGBB
    cfg.subtitleASSStyleString  = nil               -- 字幕 ASS 特效
    cfg.movingDanmakuLifeTime   = 8000              -- 滚动弹幕存活时间
    cfg.staticDanmakuLIfeTime   = 5000              -- 固定位置弹幕存活时间

    -- 路径相关
    cfg.trashDirPath            = nil               -- 如果不为空，所有删除都替换成移动，前提是目录存在
    cfg.rawDataRelDirPath       = "rawdata"         -- 下载到本地的弹幕源原始数据目录
    cfg.metaDataRelFilePath     = "sourcemeta.lua"  -- 记录弹幕源的原始信息

    -- 钩子函数
    cfg.addDanmakuHook          = nil               -- 修改或过滤弹幕

    -- 设置
    cfg.showDebugLog            = true              -- 是否输出调试信息
    cfg.pauseWhileShowing       = true              -- 弹窗后是否暂停播放
    cfg.saveGeneratedASS        = false             -- 是否保存每次生成的弹幕文件
    cfg.networkTimeout          = nil               -- 网络请求超时秒数

    return cfg
end


return
{
    initConfiguration       = initConfiguration,
}