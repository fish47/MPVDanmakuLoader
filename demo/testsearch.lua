local unportable    = require("src/base/unportable")
local utils         = require("src/base/utils")


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
        print(string.format("%2d %s [%s] %d",
                            result.partIndex or -1,
                            result.title,
                            result.partName,
                            result.duration))
    end
end


--local conn = unportable.CURLNetworkConnection:new()
--testSearch(conn, "rising hope")
----testGetVideoInfo(conn, "1212481")
----testGetVideoInfo(conn, "41589")
--conn:dispose()



local _DDP_PATTERN_VIDEO_TITLE      = '<Anime Title="(.-)"'
local _DDP_PATTERN_EPISODE_TITLE    = '<Episode Id="(%d+)" Title="(.-)"'





local function __parseSearchResults(data, indexes1, indexes2, ids, videoTitles, episodeTitles)
    local function __captureIndexesAndStrings(data, pattern, indexes, table1, table2)
        -- 收集匹配的字符串
        for str1, str2 in data:gmatch(pattern)
        do
            utils.pushArrayElement(table1, str1)
            utils.pushArrayElement(table2, str2)
        end

        -- 收集匹配的字符串索引
        local findStartIndex = 1
        while true
        do
            local startIdx, endIdx = data:find(pattern, findStartIndex, false)
            if not startIdx
            then
                break
            end

            table.insert(indexes, startIdx)
            findStartIndex = endIdx + 1
        end
    end

    -- 剧集标题
    __captureIndexesAndStrings(data, _DDP_PATTERN_VIDEO_TITLE, indexes1, videoTitles)
    utils.forEachArrayElement(videoTitles, utils.unescapeXMLString)

    -- 分集标题
    __captureIndexesAndStrings(data, _DDP_PATTERN_EPISODE_TITLE, indexes2, ids, episodeTitles)
    utils.forEachArrayElement(episodeTitles, utils.unescapeXMLString)


    --TODO 首级
    local titleIdx = 1
    local resultTitles = {}
    for i, episodeTitle in ipairs(episodeTitles)
    do
    end
end




local data = io.open("/tmp/SAO.txt"):read("*a")
__parseSearchResults(data, {}, {}, {}, {}, {})