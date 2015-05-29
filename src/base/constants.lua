return
{
    LUA_VERSION                 = tonumber(_VERSION:match("(%d+%.%d)") or 5),

    FILE_MODE_READ              = "r",
    FILE_MODE_WRITE_ERASE       = "w",
    FILE_MODE_WRITE_APPEND      = "a",
    FILE_MODE_UPDATE            = "r+",
    FILE_MODE_UPDATE_ERASE      = "w+",
    FILE_MODE_UPDATE_APPEND     = "a+",

    READ_MODE_NUMBER            = "*n",
    READ_MODE_ALL               = "*a",
    READ_MODE_LINE_NO_EOL       = "*l",
    READ_MODE_LINE_WITH_EOL     = "*L",

    SEEK_MODE_BEGIN             = "set",
    SEEK_MODE_CURRENT           = "cur",
    SEEK_MODE_END               = "end",

    VBUF_MODE_NO                = "no",
    VBUF_MODE_FULL              = "full",
    VBUF_MODE_LINE              = "line",

    LOAD_MODE_BINARY            = "b",
    LOAD_MODE_CHUNKS            = "t",
    LOAD_MODE_BINARY_CHUNKS     = "bt",

    EXEC_RET_EXIT               = "exit",
    EXEC_RET_SIGNAL             = "signal",

    STR_EMPTY                   = "",
    STR_SPACE                   = " ",
    STR_NEWLINE                 = "\n",
    STR_CARRIAGE_RETURN         = "\r",
    CODEPOINT_NEWLINE           = string.byte("\n"),

    FUNC_EMPTY                  = function() end,
}