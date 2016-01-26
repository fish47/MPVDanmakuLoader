local UI_STRINGS_CN =
{
    title_app = "MPVDanmakuLoader",
    title_main = "选择操作",
    title_help = "帮助",
    title_add_src = "添加弹幕源",

    option_main_add_danmaku_source      = "添加弹幕源",
    option_main_update_danmaku_source   = "更新弹幕源",
    option_main_generate_ass_file       = "生成 ASS 文件",
    option_main_delete_danmaku_source   = "删除弹幕源",
    option_main_show_help               = "帮助",
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