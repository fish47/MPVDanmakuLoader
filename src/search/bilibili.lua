local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")
local classlite = require("src/base/classlite")


local _BILI_FMT_URL_SEARCH              = "http://search.bilibili.com/all?keyword=%s"
local _BILI_FMT_URL_VIDEO               = "http://www.bilibili.com/video/av%s/"
local _BILI_FMT_URL_VIDEO_PART          = "http://www.bilibili.com/video/av%s"
local _BILI_FMT_URL_VIDEO_INFO          = "http://interface.bilibili.com/player?id=cid:%s&aid=%s"
local _BILI_FMT_URL_DAMAKU              = "http://comment.bilibili.com/%d.xml"

local _BILI_PATTERN_TITLE               = '<h1.-title=.->(.-)</h1>'
local _BILI_PATTERN_NEXT_PAGE_DIV       = '<div class="pagelistbox">(.-)</div>'
local _BILI_PATTERN_NEXT_PAGE_A         = '<a.-href="/search%?keyword=(.-)">(%d+)</a>'
local _BILI_PATTERN_RESULT_A            = '<a.-href="http://www%.bilibili%.com/video/av(%d+)/".-title="(.-)"'
local _BILI_PATTERN_RESULT_DIV          = '<div.-class="t">.*<span>(.*)</span>%s*(.-)%s*</div>'
local _BILI_PATTERN_REMOVE_EM           = '<.->'
local _BILI_PATTERN_PARTS_DIV           = "<select.-id='dedepagetitles'.->(.*)</select>"
local _BILI_PATTERN_PARTS_OPTION        = "<option.-value='/video/av(.-)'>(.-)</option>"
local _BILI_PATTERN_CID_1               = "EmbedPlayer%(.-cid=(%d+).-%)"
local _BILI_PATTERN_CID_2               = '<iframe.-src=".-cid=(%d+).-"'
local _BILI_PATTERN_SANITIZE            = '[\x00-\x08\x0b\x0c\x0e-\x1f]'
local _BILI_PATTERN_DURATION            = "<duration>(%d+):?(%d+)</duration>"

local _BILI_PART_INDEX_START_OFFSET     = 0
local _BILI_DEFAULT_SEARCH_PAGE_COUNT   = 3


local BiliBiliVideoInfo =
{
    title       = classlite.declareConstantField(nil),  -- 标题
    partIndex   = classlite.declareConstantField(nil),  -- 分P编号
    partName    = classlite.declareConstantField(nil),  -- 分P标题
    duration    = classlite.declareConstantField(nil),  -- 视频时间长度，单位 ms
    danmakuURL  = classlite.declareConstantField(nil),  -- 视频之间会不会共享弹幕池？
}

classlite.declareClass(BiliBiliVideoInfo)


local BiliBiliSearchResult =
{
    videoType   = classlite.declareConstantField(nil),
    videoTitle  = classlite.declareConstantField(nil),
    videoID     = classlite.declareConstantField(nil),
}

classlite.declareClass(BiliBiliSearchResult)



local function __filterBadChars(text)
    local res = text:gsub(_BILI_PATTERN_SANITIZE, constants.STR_EMPTY)
    return res or text
end


local function _doParseSearchPage(rawData,
                                  readSearchFunc,
                                  readSearchArg,
                                  readPageCountFunc,
                                  readPageCountArg)

end


local function __parseSearchPage(rawData, outList)
    if not rawData
    then
        return
    end

    for videoID, rawResult in rawData:gmatch(_BILI_PATTERN_RESULT_A)
    do
        local videoType, rawTitle = rawResult:match(_BILI_PATTERN_RESULT_DIV)
        if videoType and rawTitle
        then
            local title = __filterBadChars(rawTitle)
            local plainTitle = title:gsub(_BILI_PATTERN_REMOVE_EM, constants.STR_EMPTY)
            local result = BiliBiliSearchResult:new()
            result.videoID = __filterBadChars(videoID)
            result.videoType = __filterBadChars(videoType)
            result.videoTitle = __filterBadChars(plainTitle)
            table.insert(outList, result)
        end
    end
end


local function __parseNextPageURLs(rawData, curPageIdx, outList)
    local pageListContent = rawData and rawData:match(_BILI_PATTERN_NEXT_PAGE_DIV)
    if types.isNilOrEmpty(pageListContent)
    then
        return
    end

    for params, pageIdx in pageListContent:gmatch(_BILI_PATTERN_NEXT_PAGE_A)
    do
        pageIdx = __filterBadChars(pageIdx)
        if tonumber(pageIdx) > curPageIdx
        then
            local searchURL = string.format(_BILI_FMT_URL_SEARCH, params)
            table.insert(outList, searchURL)
        end
    end
end



local function searchBiliBiliByKeyword(conn, keyword, maxPageCount)
    local escapedKeyword = utils.escapeURLString(keyword)
    local results = nil
    local pageURLs = { string.format(_BILI_FMT_URL_SEARCH, escapedKeyword) }
    maxPageCount = math.max(maxPageCount or _BILI_DEFAULT_SEARCH_PAGE_COUNT, 1)

    conn:resetParams()
    conn:setCompressed(true)

    local i = 1
    repeat
        local rawData = conn:doGET(pageURLs[i])
        if types.isNilOrEmpty(rawData)
        then
            break
        end

        results = results or {}
        __parseSearchPage(rawData, results)
        __parseNextPageURLs(rawData, i, pageURLs)

        i = i + 1
        if i > maxPageCount
        then
            break
        end

        -- 用多进程读尽可能多的网页
        -- 如果还不知道最后一页网址，预留一页给下一轮循环
        -- 还有一种情况是，如果已知 n 页搜索结果地址，但实际上只要 m (m < n) 页，那么就全读完吧
        local lastReadPageIdx = math.min(#pageURLs - 1, maxPageCount)
        while i <= lastReadPageIdx
        do
            local succeed = conn:doQueuedGET(pageURLs[i], __parseSearchPage, results)

            -- 间接跳出最外层循环
            if not succeed
            then
                i = math.huge
                break
            end

            i = i + 1
        end

        conn:flush()

    until i > maxPageCount or i > #pageURLs

    utils.clearTable(pageURLs)
    return results
end



local function __doParseVideoDuration(rawData)
    if rawData
    then
        -- 时频长度一般以 "MM:SS" 表示
        -- 例如少于 1 分钟的视频，会不会用 "SS" 格式？
        local piece1, piece2 = rawData:match(_BILI_PATTERN_DURATION)
        if piece1 or piece2
        then
            local minutes = (piece1 and piece2) and piece1 or 0
            local seconds = piece2 or piece1
            minutes = tonumber(minutes)
            seconds = tonumber(seconds)
            return utils.convertHHMMSSToTime(0, minutes, seconds, 0)
        end
    end

    return nil
end


local function __parseVideoDuration(rawData, durations)
    table.insert(durations, __doParseVideoDuration(rawData))
end


local function __doParseVideoChatID(rawData)
    if types.isString(rawData)
    then
        local chatID = nil
        chatID = chatID or rawData:match(_BILI_PATTERN_CID_1)
        chatID = chatID or rawData:match(_BILI_PATTERN_CID_2)
        return chatID
    end
end


local function __parseVideoChatID(rawData, chatIDs)
    table.insert(chatIDs, __doParseVideoChatID(rawData))
end



local function getBiliBiliVideoInfos(conn, videoID)
    conn:resetParams()
    conn:setCompressed(true)

    local rawData = conn:doGET(string.format(_BILI_FMT_URL_VIDEO, videoID))
    if types.isNilOrEmpty(rawData)
    then
        return nil
    end

    local results = nil
    local title = rawData:match(_BILI_PATTERN_TITLE)
    local videoListDiv = rawData:match(_BILI_PATTERN_PARTS_DIV)
    if videoListDiv
    then
        -- 多P视频

        -- 获取每个分P视频页面的 子标题 和 chatID
        local chatIDs = {}
        local partNames = {}
        for relativeURL, partName in rawData:gmatch(_BILI_PATTERN_PARTS_OPTION)
        do
            local partURL = string.format(_BILI_FMT_URL_VIDEO_PART, relativeURL)
            conn:doQueuedGET(partURL, __parseVideoChatID, chatIDs)
            table.insert(partNames, __filterBadChars(partName))
        end

        conn:flush()


        -- 获取每个分P视频的时长
        local durations = {}
        for i, chatID in ipairs(chatIDs)
        do
            local valid = false
            if chatID
            then
                local videoInfoURL = string.format(_BILI_FMT_URL_VIDEO_INFO, chatID, videoID)
                conn:doQueuedGET(videoInfoURL, __parseVideoDuration, durations)
            else
                -- 保证平行数组长度一致
                table.insert(durations, nil)
            end
        end

        conn:flush()


        -- 生成视频信息
        local resultCount = #durations
        for i = 1, resultCount
        do
            local chatID = chatIDs[i]
            local duration = durations[i]
            if chatID and duration
            then
                local info = BiliBiliVideoInfo:new()
                info.title = title
                info.partIndex = _BILI_PART_INDEX_START_OFFSET + i
                info.partName = partNames[i]
                info.duration = duration
                info.danmakuURL = string.format(_BILI_FMT_URL_DAMAKU, chatID)
                results = results or {}
                table.insert(results, info)
            end

            partNames[i] = nil
            durations[i] = nil
            chatIDs[i] = nil
        end

        partNames = nil
        durations = nil
        chatIDs = nil

    else
        -- 单P视频

        local chatID = __doParseVideoChatID(rawData)
        if chatID
        then
            local videoInfoURL = string.format(_BILI_FMT_URL_VIDEO_INFO, chatID, videoID)
            local rawData2 = conn:doGET(videoInfoURL)
            local duration = rawData2 and __doParseVideoDuration(rawData2)
            if duration
            then
                local info = BiliBiliVideoInfo:new()
                info.title = title
                info.duration = duration
                info.danmakuURL = string.format(_BILI_FMT_URL_DAMAKU, chatID)
                results = results or {}
                table.insert(results, info)
            end
        end
    end

    return results
end


local function getBiliBiliDanmakuRawData(conn, danmakuURL)
    conn:resetParams()
    conn:setCompressed(true)
    local rawData = conn:doGET(danmakuURL)
    return rawData and __filterBadChars(rawData) or nil
end


return
{
    BiliBiliVideoInfo           = BiliBiliVideoInfo,
    BiliBiliSearchResult        = BiliBiliSearchResult,
    searchBiliBiliByKeyword     = searchBiliBiliByKeyword,
    getBiliBiliVideoInfos       = getBiliBiliVideoInfos,
    getBiliBiliDanmakuRawData   = getBiliBiliDanmakuRawData,
}