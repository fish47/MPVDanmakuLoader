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
            search_danmaku          = "搜索弹幕源",
            update_danmaku          = "更新弹幕源",
            generate_ass_file       = "生成弹幕",
            delete_danmaku_cache    = "删除弹幕缓存",
            show_help               = "帮助",
        },
    },

    show_help =
    {
        title = "帮助",
        content = "Hahahahaha",
    },

}


local UI_SIZES_ZENITY =
{
    main =
    {
        width   = 240,
        height  = 300,
    },

    show_help =
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