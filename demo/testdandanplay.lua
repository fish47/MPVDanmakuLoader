local md5           = require("src/base/md5")
local cmd           = require("src/base/cmd")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local connection    = require("src/base/connection")
local dandanplay    = require("src/search/dandanplay")


local function _getFileName(filepath)
    local name = filepath:match(".-([^/\\]+)$")
    return name
end


local function _getVideoDurationSeconds(filepath)
    local quotedPath = cmd.quoteShellString(filepath)
    local f = io.popen(string.format("ffmpeg -i %s 2>&1", quotedPath))
    local output = utils.readAndCloseFile(f)
    local h, m, s = output:match("Duration: (%d+):(%d+):(%d+)")
    h = tonumber(h)
    m = tonumber(m)
    s = tonumber(s)
    return h * 60 * 60 + m * 60 + s
end


local function _getFileByteCount(filepath)
    local f = io.open(filepath)
    local ret = f:seek(constants.SEEK_MODE_END)
    f:close()
    return ret
end


local function _getFileMD5Hash(filepath, byteCount)
    local quotedPath = cmd.quoteShellString(filepath)
    local f = io.popen(string.format("cut -b %d %s | md5sum", byteCount, quotedPath))
    local output = utils.readAndCloseFile(f)
    local ret = output:match("([^%s]*)")
    return ret
end


local function testSearch(filepath)
    local hash = _getFileMD5Hash(filepath, dandanplay.DDP_MD5_HASH_BYTE_COUNT)
    local filename = _getFileName(filepath)
    local seconds = _getVideoDurationSeconds(filepath)
    local byteCount = _getFileByteCount(filepath)
    local conn = connection.CURLNetworkConnection:new("curl", 10)
    local results = dandanplay.searchDanDanPlayByVideoInfos(conn,
                                                            filename,
                                                            hash,
                                                            byteCount,
                                                            seconds)

    for _, result in ipairs(results)
    do
        print(result.videoTitle)
        print(result.videoSubtitle)
        print(result.danmakuURL)
    end

    conn:dispose()
end


testSearch("/home/fish47/111/Biligrab/_【合集】我的妹妹不可能那么可爱 第二季【Bilibili正版】/1 - 我的妹妹哪有可能再回来.mp4")