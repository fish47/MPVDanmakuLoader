return
{
    LAYER_MOVING_L2R            = 1,
    LAYER_MOVING_R2L            = 2,
    LAYER_STATIC_TOP            = 3,
    LAYER_STATIC_BOTTOM         = 4,
    LAYER_ADVANCED              = 5,
    LAYER_SUBTITLE              = 6,
    LAYER_SKIPPED               = 7,

    _DANMAKU_IDX_START_TIME     = 1,    -- 弹幕起始时间，单位 ms
    _DANMAKU_IDX_LIFE_TIME      = 2,    -- 弹幕存活时间，单位 ms
    _DANMAKU_IDX_FONT_COLOR     = 3,    -- 字体颜色值，格式 RRGGBB
    _DANMAKU_IDX_FONT_SIZE      = 4,    -- 字体大小，单位 pt
    _DANMAKU_IDX_SOURCE_ID      = 5,    -- 弹幕源
    _DANMAKU_IDX_DANMAKU_ID     = 6,    -- 在相同弹幕源前提下的唯一标识
    _DANMAKU_IDX_DANMAKU_TEXT   = 7,    -- 弹幕内容，以 utf8 编码
    _DANMAKU_IDX_MAX            = 7,
}