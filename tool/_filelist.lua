local function __appendArray(dst, ...)
    local src = ...
    if dst and src
    then
        for _, v in ipairs(src)
        do
            table.insert(dst, v)
        end
    end
end


local FILE_LIST_SRC_PUBLIC =
{
    "src/base/classlite.lua",
    "src/base/constants.lua",
    "src/base/serialize.lua",
    "src/base/types.lua",
    "src/base/unportable.lua",
    "src/base/utf8.lua",
    "src/base/utils.lua",
    "src/core/danmaku.lua",
    "src/core/danmakupool.lua",
    "src/plugins/acfun.lua",
    "src/plugins/bilibili.lua",
    "src/plugins/dandanplay.lua",
    "src/plugins/pluginbase.lua",
    "src/plugins/srt.lua",
    "src/shell/application.lua",
    "src/shell/config.lua",
    "src/shell/logic.lua",
    "src/shell/sourcemgr.lua",
    "src/shell/uiconstants.lua",
}

local FILE_LIST_SRC_PRIVATE =
{
    "src/base/_algo.lua",
    "src/base/_conv.lua",
    "src/core/_ass.lua",
    "src/core/_coreconstants.lua",
    "src/core/_layer.lua",
    "src/core/_poscalc.lua",
    "src/core/_writer.lua",
    "src/unportable/_gui.lua",
    "src/unportable/_path.lua",
}

local FILE_LIST_TEMPLATE =
{
    ["src/unportable/_executor.lua"] =
    {
        ["__SCRIPT_CONTENT__"] = "src/unportable/_impl.py",
    },
}

local FILE_LIST_SRC_MAIN =
{
    "src/shell/main.lua"
}

local FILE_LIST_SRC_ALL = __appendArray({}, FILE_LIST_SRC_PUBLIC,
                                            FILE_LIST_SRC_PRIVATE,
                                            FILE_LIST_SRC_MAIN)


return
{
    FILE_LIST_SRC_PUBLIC    = FILE_LIST_SRC_PUBLIC,
    FILE_LIST_SRC_PRIVATE   = FILE_LIST_SRC_PRIVATE,
    FILE_LIST_TEMPLATE      = FILE_LIST_TEMPLATE,
    FILE_LIST_SRC_MAIN      = FILE_LIST_SRC_MAIN,
    FILE_LIST_SRC_ALL       = FILE_LIST_SRC_ALL,
}