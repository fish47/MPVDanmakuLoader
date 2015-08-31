local utils = require("src/utils")


local MPVDanmakuLoaderCfg   =
{
    bottomReservedHeight    = 0,                -- 弹幕底部预留空间
    defaultFontSize         = 34,               -- 弹幕默认字体大小
    defaultFontName         = "sans-serif",     -- 弹幕默认字体名
    defaultFontColor        = 0x33FFFFFF,       -- 弹幕默认颜色 BBGGRR
    defaultSRTFontSize      = 34,               -- 字幕默认字体大小
    defaultSRTFontName      = "mono",           -- 字幕默认字体名
    defaultSRTFontColor     = 0xFFFFFFFF,       -- 字幕默认颜色 BBGGRR
    saveDownloadedRawData   = true,             -- 是否弹幕原始数据，可在离线时使用
    overwriteASSFile        = true,             -- 是否覆盖当前目录同名的 ASS 文件，反之则弹保存框
}

utils.declareClass(MPVDanmakuLoaderCfg)


return
{
    MPVDanmakuLoaderCfg     = MPVDanmakuLoaderCfg,
}