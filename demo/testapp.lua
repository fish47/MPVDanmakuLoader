local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local logic         = require("src/shell/logic")
local mocks         = require("test/mocks")


local _LOG_TAG_WIDTH    = 10

local _TAG_PLUGIN       = "plugin"
local _TAG_NETWORK      = "network"
local _TAG_APPLICATION  = "application"
local _TAG_SHELL        = "shell"


local function __printLog(tag, fmt, ...)
    local tagWidth = #tag
    local beforeSpaceCount = math.floor((_LOG_TAG_WIDTH - tagWidth) / 2)
    local afterSpaceCount = math.max(_LOG_TAG_WIDTH - tagWidth - beforeSpaceCount, 0)
    print(string.format("[%s%s%s]  " .. fmt,
                        string.rep(constants.STR_SPACE, beforeSpaceCount),
                        tag,
                        string.rep(constants.STR_SPACE, afterSpaceCount),
                        ...))
end


local MockRemoteDanmakuSourcePlugin =
{
    _mName                  = classlite.declareConstantField(nil),
    _mVideoIDsMap           = classlite.declareTableField(),
    _mIsSplitedFlags        = classlite.declareTableField(),
    _mDanmakuURLs           = classlite.declareTableField(),
    _mVideoDurations        = classlite.declareTableField(),
    _mVideoTitles           = classlite.declareTableField(),
    _mVideoTitleColCounts   = classlite.declareTableField(),
    _mPreferredIDIndexes    = classlite.declareTableField(),
    __mVideoIDCount         = classlite.declareConstantField(0),

    new = function(self, name)
        self._mName = name
    end,

    dispose = function(self)
        utils.forEachTableValue(self._mVideoIDsMap, utils.clearTable)
        utils.forEachTableValue(self._mVideoDurations, utils.clearTable)
        utils.forEachTableValue(self._mDanmakuURLs, utils.clearTable)
        utils.forEachTableValue(self._mVideoTitles, utils.clearTable)
    end,

    addSearchResult = function(self, app, keyword, titles, isSplited, colCount)
        local videoIDsMap = self._mVideoIDsMap
        colCount = colCount or 1
        if not videoIDsMap[keyword]
        then
            local conn = app:getNetworkConnection()
            local pluginName = self:getName()
            local videoIDs = {}
            local videoIDStart = self.__mVideoIDCount
            local videoIDCount = math.floor(#titles / colCount)
            for i = 1, videoIDCount
            do
                local videoIDNum = i + videoIDStart
                local videoID = string.format("%s_%d", pluginName, videoIDNum)
                table.insert(videoIDs, videoID)

                local url = string.format("http://www.fish47.com/%s/%d", pluginName, videoIDNum)
                conn:setResponse(url, pluginName)
                self._mDanmakuURLs[videoID] = url
                self._mVideoDurations[videoID] = math.random(1000)
            end

            videoIDsMap[keyword] = videoIDs
            self.__mVideoIDCount = videoIDStart + videoIDCount
            self._mVideoTitleColCounts[keyword] = colCount
            self._mIsSplitedFlags[keyword] = types.toBoolean(isSplited)
            self._mVideoTitles[keyword] = utils.appendArrayElements({}, titles)
            self._mPreferredIDIndexes[keyword] = math.random(videoIDCount)
        end
    end,

    getName = function(self)
        return self._mName
    end,

    parse = function(self, app, fullPath)
        __printLog(_TAG_PLUGIN, "parse %s: %s", self:getName(), fullPath)
    end,

    search = function(self, keyword, result)
        local videoIDs = self._mVideoIDsMap[keyword]
        if videoIDs
        then
            __printLog(_TAG_PLUGIN, "search %s => %s", keyword, self:getName())
            result.isSplited = self._mIsSplitedFlags[keyword]
            result.preferredIDIndex = self._mPreferredIDIndexes[keyword]
            result.videoTitleColumnCount = self._mVideoTitleColCounts[keyword]
            utils.appendArrayElements(result.videoIDs, videoIDs)
            utils.appendArrayElements(result.videoTitles, self._mVideoTitles[keyword])
            return true
        end
    end,

    getDanmakuURLs = function(self, videoIDs, outURLs)
        for _, videoID in utils.iterateArray(videoIDs)
        do
            table.insert(outURLs, self._mDanmakuURLs[videoID])
        end
    end,

    getVideoDurations = function(self, videoIDs, outDurations)
        for _, videoID in utils.iterateArray(videoIDs)
        do
            table.insert(outDurations, self._mVideoDurations[videoID])
        end
    end
}

classlite.declareClass(MockRemoteDanmakuSourcePlugin, pluginbase.IDanmakuSourcePlugin)


local MockLocalDanmakuSourcePlugin =
{
    _mName                  = classlite.declareConstantField(nil),
    _mMatchedFilePahtSet    = classlite.declareTableField(),

    new = function(self, name)
        self._mName = name
    end,

    addMatchedRawDataFile = function(self, app, fullPath)
        local dir = unportable.splitPath(fullPath)
        app:createDir(dir)

        local file = app:writeFile(fullPath)
        file:write(constants.STR_EMPTY)
        utils.closeSafely(file)
        self._mMatchedFilePahtSet[fullPath] = true
    end,

    isMatchedRawDataFile = function(self, app, filePath)
        return self._mMatchedFilePahtSet[filePath]
    end,
}

classlite.declareClass(MockLocalDanmakuSourcePlugin, pluginbase.IDanmakuSourcePlugin)


local MockShell =
{
    _mApplication               = classlite.declareClassField(mocks.MockApplication),
    _mDanmakuSourceManager      = classlite.declareClassField(mocks.MockDanmakuSourceManager),

    new = function(self)
        self:getParent().new(self)

        local app = self._mApplication
        local orgSetSubtitleFunc = app.setSubtitle
        app.setSubtitle = function(self, fullPath)
            __printLog(_TAG_APPLICATION, "set subtitle %s", fullPath)
            orgSetSubtitleFunc(self, fullPath)
        end

        app.addKeyBinding = function(self, key)
            __printLog(_TAG_APPLICATION, "bind: %s", key)
        end

        app._doAddEventCallback = function(self, eventName)
            __printLog(_TAG_APPLICATION, "register: %s", eventName)
        end

        local conn = app:getNetworkConnection()
        local orgCreateFunc = conn._createConnection
        conn._createConnection = function(self, url)
            __printLog(_TAG_NETWORK, "GET %s", url)
            return orgCreateFunc(self, url)
        end

        local plugin1 = MockRemoteDanmakuSourcePlugin:new("Remote1")
        plugin1:addSearchResult(app, "a", { "Title1", "Subtitle1", "Title2", "Subtitle2" }, false, 2)
        plugin1:addSearchResult(app, "b", { "Title1", "Title2", "Title3", "Title4" }, true)
        app:addDanmakuSourcePlugin(plugin1)

        local plugin2 = MockRemoteDanmakuSourcePlugin:new("Remote2")
        plugin2:addSearchResult(app, "c", { "Title1", "Title2" })
        app:addDanmakuSourcePlugin(plugin2)

        local plugin3 = MockLocalDanmakuSourcePlugin:new("Local1")
        plugin3:addMatchedRawDataFile(app, "/local_source/1")
        plugin3:addMatchedRawDataFile(app, "/local_source/2")
        plugin3:addMatchedRawDataFile(app, "/local_source/3")
        app:addDanmakuSourcePlugin(plugin3)
    end,

    _commitSubtitle = function(self, assFilePath)
        __printLog(_TAG_SHELL, "set subtitle: %s", tostring(assFilePath))
    end,
}

classlite.declareClass(MockShell, logic.MPVDanmakuLoaderShell)


MockShell:new():_showMain()