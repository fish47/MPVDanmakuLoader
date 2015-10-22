local UI_STRINGS_CN =
{
    app =
    {
        title   = "MPVDanmakuLoader",
    },

    main =
    {
        title   = "操作",

        options =
        {
            search_bilibili     = "搜索弹幕(BiliBili)",
            search_dandanplay   = "搜索弹幕(DanDanPlay)",
            generate_ass_file   = "生成弹幕文件",
            delete_danmaku_cache  = "删除本地弹幕缓存",
        },
    },

    search_ddp =
    {
        title   = "搜索结果(DanDanPlay)",

        columns =
        {
            title       = "标题",
            subtitle    = "子标题",
        },
    },

    search_bili =
    {
        prompt =
        {
            title   = "搜索(BiliBili)",
        },

        select_pieces =
        {},

        show_results =
        {
            title   = "搜索结果(BiliBili)",
            columns =
            {
                type        = "类型",
                title       = "标题",
            },
        },
    },


    delete_danmaku_cache =
    {
        title   = "删除本地弹幕缓存",
        columns =
        {
        },
    },
}


local UI_SIZES_ZENITY =
{
    main =
    {
        width   = 240,
        height  = 220,
    },
}


return
{
    UI_STRINGS_CN       = UI_STRINGS_CN,
    UI_SIZES_ZENITY     = UI_SIZES_ZENITY,
}