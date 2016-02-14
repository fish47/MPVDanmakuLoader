local UI_STRINGS_CN =
{
    title_app                               = "MPVDanmakuLoader",
    title_main                              = "选择操作",
    title_help                              = "帮助",
    title_add_danmaku_source                = "添加弹幕源",  --TODO inputTextBox
    title_select_new_danmaku_source         = "选择添加弹幕源",
    title_delete_danmaku_source             = "选择删除弹幕源",
    title_update_danmaku_source             = "选择更新弹幕源",
    title_generate_ass_file                 = "选择生成 ASS 文件的弹幕源",

    column_sources_date                     = "添加日期",
    column_sources_plugin_name              = "插件名",
    column_sources_description              = "备注",

    option_main_add_danmaku_source          = "添加弹幕源",
    option_main_update_danmaku_source       = "更新弹幕源",
    option_main_generate_ass_file           = "生成 ASS 文件",
    option_main_delete_danmaku_source       = "删除弹幕源",
    option_main_show_help                   = "帮助",

    fmt_select_new_danmaku_source_header    = "标题%d",
}


local UI_SIZES_ZENITY =
{
    main                        = { 280, 280 },
    help                        = { 400, 300 },
    select_new_danmaku_source   = { 500, 600 },
    show_danmaku_sources        = { 500, 600 },
}


return
{
    UI_STRINGS_CN       = UI_STRINGS_CN,
    UI_SIZES_ZENITY     = UI_SIZES_ZENITY,
}