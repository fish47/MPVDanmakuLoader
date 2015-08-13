local utils = require('src/utils')      --= utils utils


local _CURL_ARG_SLIENT          = "--silent"
local _CURL_ARG_COMPRESSED      = "--compressed"
local _CURL_SEP_ARGS            = " "
local _CURL_PATTERN_SEP_CONTENT = "--_curl_--%s\n"

local CURLNetworkConnection =
{
    _mCURLBin       = nil,
    _mCmdArgs       = nil,
    _mBatchedURLs   = nil,

    new = function(obj, curlBin)
        obj = utils.allocateInstance(obj)
        obj._mCURLBin = curlBin
        obj._mCmdArgs = {}
        obj._mBatchedURLs = {}
        return obj
    end,


    __doPrepareCommandArgs = function(self)
        utils.clearTable(self._mCmdArgs)
        table.insert(self._mCmdArgs, self._mCURLBin)
        table.insert(self._mCmdArgs, _CURL_ARG_SLIENT)
    end,


    __doExecuteCommand = function(self)
        if mp
        then
            local ret = mp.utils.subprocess({ args = self._mCmdArgs })
            utils.clearTable(self._mCmdArgs)
            return (not ret.error), ret.stdout
        else
            -- 调用时保证不出现 bash 特殊字符，以空格分割，仅在调试时使用
            local f = io.popen(table.concat(self._mCmdArgs, _CURL_SEP_ARGS))
            local succeed = (f ~= nil)
            local output = f:read("*a")
            utils.clearTable(self._mCmdArgs)
            return succeed, output
        end
    end,


    __doIterateBatchedContent = function(self, combinedRawData)
        -- 很久之前 curl 就用 "--_curl_--URL_ARG" 作分割符了
        -- https://github.com/bagder/curl/blame/master/src/tool_operate.c#L92
    end,


    addBatchedURL = function(self, url)
        table.insert(self._mBatchedURLs, url)
    end,


    doGET = function(self, url)
        self:__doPrepareCommandArgs()
        table.insert(self._mCmdArgs, url)
        return self:__doExecuteCommand()
    end,


    doCompressedGET = function(self, url)
        self:__doPrepareCommandArgs()
        table.insert(self._mCmdArgs, _CURL_ARG_COMPRESSED)
        table.insert(self._mCmdArgs, url)
        return self:__doExecuteCommand()
    end,


    doIterateBatchedGET = function(self)
        --
        utils.clearTable(self._mBatchedURLs)
        return nil
    end,


    doIterateBatchedCompressedGET = function(self)
        --
        utils.clearTable(self._mBatchedURLs)
        return nil
    end,
}

utils.declareClass(CURLNetworkConnection)


local BiliBiliSearchResult =
{
    videoType   = nil,
    videoTitle  = nil,
    videoID     = nil,
}

utils.declareClass(BiliBiliSearchResult)


local BiliBiliVideoInfo =
{
    subtitle    = nil,      -- 分P视频标题，无分P时此字段为空
    danmakuURL  = nil,      -- 视频之间会不会共享弹幕池？
    duration    = nil,      -- 视频长宽，单位 ms
}

utils.declareClass(BiliBiliVideoInfo)


local _BILI_FMT_URL_SEARCH              = "http://www.bilibili.com/search?keyword=%s"
local _BILI_FMT_URL_VIDEO               = "http://www.bilibili.com/video/av%s/"
local _BILI_FMT_URL_VIDEO_PIECE         = "http://www.bilibili.com/video/av%s"
local _BILI_FMT_URL_VIDEO_INFO          = "http://interface.bilibili.com/player?id=cid:%s&aid=%s"
local _BILI_FMT_URL_DAMAKU              = "http://comment.bilibili.com/%d.xml"

local _BILI_PATTERN_NEXT_PAGE_DIV       = '<div class="pagelistbox">(.-)</div>'
local _BILI_PATTERN_NEXT_PAGE_A         = '<a href="/search%?keyword=(.-)">(%d+)</a>'
local _BILI_PATTERN_RESULT_A            = '<a href="http://www%.bilibili%.com/video/av(%d+)/?".->(.-)</a>'
local _BILI_PATTERN_RESULT_DIV          = '<div class="t">.*<span>(.*)</span>%s*(.-)%s*</div>'
local _BILI_PATTERN_REMOVE_EM           = '<.->'
local _BILI_PATTERN_REMOVE_EM_REPL      = ''
local _BILI_PATTERN_PIECES_DIV          = "<select id='dedepagetitles'.->(.*)</select>"
local _BILI_PATTERN_PIECES_OPTION       = "<option value='/video/av(.-)'>(.-)</option>"
local _BILI_PATTERN_CID                 = "<script type='text/javascript'>EmbedPlayer%(.*, \"cid=(%d+).*\"%);</script>"
local _BILI_PATTERN_SANITIZE            = '[\x00-\x08\x0b\x0c\x0e-\x1f]'
local _BILI_PATTERN_SANITIZE_REPL       = ''
local _BILI_PATTERN_DURATION            = "<duration>(%d+):?(%d+)</duration>"

local _BILI_DEFAULT_SEARCH_PAGE_COUNT   = 3


local function __filterBadChars(text)
    local res = text:gsub(_BILI_PATTERN_SANITIZE,
                          _BILI_PATTERN_SANITIZE_REPL)
    return res or text
end


local function __parseSearchPage(rawData, outList)
    for videoID, rawResult in rawData:gmatch(_BILI_PATTERN_RESULT_A)
    do
        local videoType, rawTitle = rawResult:match(_BILI_PATTERN_RESULT_DIV)
        if videoType and rawTitle
        then
            local filteredTitle = __filterBadChars(rawTitle)
            local plainTitle = filteredTitle:gsub(_BILI_PATTERN_REMOVE_EM,
                                                  _BILI_PATTERN_REMOVE_EM_REPL)

            local result = BiliBiliSearchResult:new()
            result.videoID = __filterBadChars(videoID)
            result.videoType = __filterBadChars(videoType)
            result.videoTitle = plainTitle

            table.insert(outList, result)
        end
    end
end


local function __parseNextPageURLs(rawData, curPageIdx, outList)
    local pageListContent = rawData:match(_BILI_PATTERN_NEXT_PAGE_DIV)
    if pageListContent
    then
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
end



local function searchBiliBili(conn, keyword, maxPageCount)
    local escapedKeyword = utils.escapeURLString(keyword)
    local results = {}
    local pageURLs = { string.format(_BILI_FMT_URL_SEARCH, escapedKeyword) }

    maxPageCount = maxPageCount or _BILI_DEFAULT_SEARCH_PAGE_COUNT
    for i = 1, maxPageCount
    do
        local succeed, rawData = conn:doCompressedGET(pageURLs[i])
        if succeed
        then
            __parseSearchPage(rawData, results)

            -- 调用一次获取后 n 页路径，不需要每次都做
            if i == #pageURLs
            then
                __parseNextPageURLs(rawData, i, pageURLs)
            end
        else
            break
        end
    end

    pageURLs = nil
    return results
end



local function __parseVideoDuration(conn, videoID, chatID)
    local videoInfoURL = string.format(_BILI_FMT_URL_VIDEO_INFO, chatID, videoID)
    local succeed, rawData = conn:doGET(videoInfoURL)
    if succeed
    then
        -- 时频长度一般以 "MM:SS" 表示
        -- 例如少于 1 分钟的视频，会不会用 "SS" 格式？
        local piece1, piece2 = rawData:match(_BILI_PATTERN_DURATION)
        if piece1 or piece2
        then
            local minutes = (piece1 and piece2) and piece1 or 0
            local seconds = piece2 or piece1
            return utils.convertHHMMSSToTime(0, tonumber(minutes), tonumber(seconds), 0)
        end
    end

    return nil
end



local function __doGetBiliBiliVideoInfo(conn, rawData, videoID, subtitle, outList)
    local chatID = rawData:match(_BILI_PATTERN_CID)
    local duration = chatID and __parseVideoDuration(conn, videoID, chatID) or nil
    if duration
    then
        local info = BiliBiliVideoInfo:new()
        info.subtitle = subtitle
        info.duration = duration
        info.danmakuURL = string.format(_BILI_FMT_URL_DAMAKU, chatID)
        table.insert(outList, info)
    end
end


local function getBiliBiliVideoInfos(conn, videoID)
    local cmdBuf = {}
    local results = {}
    local subtitles = {}
    local videoPieceURLs = { string.format(_BILI_FMT_URL_VIDEO, videoID) }

    local i = 1
    while i <= #videoPieceURLs
    do
        local succeed, rawData = conn:doCompressedGET(videoPieceURLs[i])
        if succeed
        then
            -- 检查一下是不是多P视频
            if i == 1
            then
                local videoListDiv = rawData:match(_BILI_PATTERN_PIECES_DIV)
                if videoListDiv
                then
                    utils.clearTable(videoPieceURLs)
                    for relativeURL, subtitle in rawData:gmatch(_BILI_PATTERN_PIECES_OPTION)
                    do
                        table.insert(videoPieceURLs, string.format(_BILI_FMT_URL_VIDEO_PIECE, relativeURL))
                        table.insert(subtitles, __filterBadChars(subtitle))
                    end
                end
            end

            __doGetBiliBiliVideoInfo(conn, rawData, videoID, subtitles[i], results)
        end

        i = i + 1
    end

    cmdBuf = nil
    subtitles = nil
    videoPieceURLs = nil

    return results
end


local function getBiliBiliDanmakuRawData(conn, danmakuURL)
    local cmdBuf = {}
    local succeed, rawData = conn:doCompressedGET(cmdBuf, danmakuURL)
    local filteredRawData = succeed and __filterBadChars(rawData) or rawData
    cmdBuf = nil
    rawData = nil
    return succeed, filteredRawData
end


local conn = CURLNetworkConnection:new("curl")
local results = getBiliBiliVideoInfos(conn, "2184220")
for _, info in ipairs(results)
do
    print("----")
    print(info.subtitle)
    print(info.danmakuURL)
    print(info.duration)
end