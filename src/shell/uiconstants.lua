local UI_STRINGS_CN =
{
    app =
    {
        title = "MPVDanmakuLoader",
    },

    main =
    {
        title = "操作",

        options =
        {
            add_danmaku             = "添加弹幕源",
            update_danmaku          = "更新弹幕源",
            generate_ass_file       = "生成弹幕",
            delete_danmaku_cache    = "删除弹幕缓存",
            show_help               = "帮助",
        },
    },

    add_danmaku =
    {
        title = "添加弹幕"
    },

    search_result_bili =
    {
        title = "BiliBili 视频分集标题",
    },

    search_result_ddp =
    {
        title = "弹弹Play 搜索结果",
        columns = { "影片标题", "分集标题" },
    },

    help =
    {
        title = "帮助",
        content = "Hahahahaha",
    },
}


local UI_SIZES_ZENITY =
{
    main =
    {
        width   = 280,
        height  = 280,
    },

    search_result =
    {
        width   = 300,
        height  = 400,
    },

    help =
    {
        width   = 200,
        height  = 300,
    },
}


return
{
    UI_STRINGS_CN       = UI_STRINGS_CN,
    UI_SIZES_ZENITY     = UI_SIZES_ZENITY,
}