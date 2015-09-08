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
        },
    },

    search_ddp =
    {
        title   = "搜索结果(DanDanPlay)",

        columns =
        {
            dummy       = "",
            id          = "ID",
            title       = "标题",
            subtitle    = "子标题",
        },
    },

    search_bili =
    {
        prompt =
        {
            title   = "输入搜索关键词",
        },

        select_pieces =
        {},

        show_results =
        {
            title   = "搜索结果(BiliBili)",
            columns =
            {
                dummy       = "",
                id          = "ID",
                type        = "类型",
                title       = "标题",
            },
        },
    },
}


return
{
    UI_STRINGS_CN   = UI_STRINGS_CN,
}