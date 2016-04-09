local function initConfiguration(cfg)
    cfg = cfg or {}

    -- 弹幕属性
    cfg.bottomReservedHeight                = 0                -- 弹幕底部预留空间
    cfg.danmakuFontSize                     = 34               -- 弹幕默认字体大小
    cfg.danmakuFontName                     = "sans-serif"     -- 弹幕默认字体名
    cfg.danmakuFontColor                    = 0x33FFFFFF       -- 弹幕默认颜色 BBGGRR
    cfg.subtitleFontSize                    = 34               -- 字幕默认字体大小
    cfg.subtitleFontName                    = "mono"           -- 字幕默认字体名
    cfg.subtitleFontColor                   = 0xFFFFFFFF       -- 字幕默认颜色 BBGGRR
    cfg.movingDanmakuLifeTime               = 8000             -- 滚动弹幕存活时间
    cfg.staticDanmakuLIfeTime               = 5000             -- 固定位置弹幕存活时间

    -- 路径相关
    cfg.danmakuSourceRawDataRelDirPath      = "rawdata"         -- 下载到本地的弹幕源原始数据目录
    cfg.danmakuSourceMetaDataRelFilePath    = "sourcemeta.lua"  -- 记录弹幕源的原始信息

    return cfg
end


return
{
    initConfiguration       = initConfiguration,
}