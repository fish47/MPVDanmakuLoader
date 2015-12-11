local utils = require("src/utils")


local MPVDanmakuLoaderCfg   =
{
    bottomReservedHeight    = 0,                -- 弹幕底部预留空间
    danmakuFontSize         = 34,               -- 弹幕默认字体大小
    danmakuFontName         = "sans-serif",     -- 弹幕默认字体名
    danmakuFontColor        = 0x33FFFFFF,       -- 弹幕默认颜色 BBGGRR
    subtitleFontSize        = 34,               -- 字幕默认字体大小
    subtitleFontName        = "mono",           -- 字幕默认字体名
    subtitleFontColor       = 0xFFFFFFFF,       -- 字幕默认颜色 BBGGRR

    saveRawData             = true,             -- 是否弹幕原始数据，可在离线时使用
    overwriteASSFile        = true,             -- 是否覆盖当前目录同名的 ASS 文件，反之则弹保存框

    rawDataDir              = "",               -- 弹幕原始数据的保存目录
    rawDataInfoPath         = "/tmp/1",         -- 弹幕关联数据
    searchInfoPath          = "/tmp/123",       -- 搜索关键字历史
}

utils.declareClass(MPVDanmakuLoaderCfg)


return
{
    MPVDanmakuLoaderCfg     = MPVDanmakuLoaderCfg,
}