local connection    = require("src/base/connection")
local bilibili      = require("src/search/bilibili")


local function testSearch(conn, keyword, pageCount)
    local results = bilibili.searchBiliBiliByKeyword(conn, keyword, pageCount)
    for _, result in ipairs(results)
    do
        print(string.format("[%s][%s]%s",
                            result.videoID,
                            result.videoType,
                            result.videoTitle))
    end
end


local function testGetVideoInfo(conn, videoID)
    local results = bilibili.getBiliBiliVideoInfos(conn, videoID)
    for _, result in ipairs(results)
    do
        print(string.format("%2d %s [%s]",
                            result.partIndex or -1,
                            result.title,
                            result.partName))
    end
end


local conn = connection.CURLNetworkConnection:new("curl")
testSearch(conn, "rising hope")
testGetVideoInfo(conn, "1212481")
testGetVideoInfo(conn, "41589")
conn:dispose()