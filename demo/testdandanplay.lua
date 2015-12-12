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
    local f = io.popen("ffmpeg -i " .. quotedPath .. " 2>&1")
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


local function testSearch(filepath)
--    local hash = md5.calcFileMD5Hash(filepath, dandanplay.DDP_MD5_HASH_BYTE_COUNT)
    local hash = "d41d8cd98f00b204e9800998ecf8427e"
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


--testSearch("/home/fish47/111/SAO/[ZERO动漫下载][SOSG&DMG][刀剑神域][19][1280x720][BIG5].mp4")

local byteCount = 16 * 1024 * 1024
local filepath = "/home/fish47/111/SAO/[ZERO动漫下载][SOSG&DMG][刀剑神域][19][1280x720][BIG5].mp4"
local start = os.clock()
md5.calcFileMD5Hash(filepath, byteCount)
print(os.clock() - start)


start = os.clock()
local data = io.open(filepath):read(byteCount)
require("3rdparties/md5").sum(data)
print(os.clock() - start)