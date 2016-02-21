local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local logic         = require("src/shell/logic")
local mocks         = require("test/mocks")


local _LOG_TAG_WIDTH    = 14

local _TAG_PLUGIN       = "plugin"
local _TAG_NETWORK      = "network"
local _TAG_APPLICATION  = "application"
local _TAG_FILESYSTEM   = "filesystem"


local function __printLog(tag, fmt, ...)
    if not tag
    then
        print(string.format(fmt, ...))
    else
        local tagWidth = #tag
        local beforeSpaceCount = math.floor((_LOG_TAG_WIDTH - tagWidth) / 2)
        local afterSpaceCount = math.max(_LOG_TAG_WIDTH - tagWidth - beforeSpaceCount, 0)
        print(string.format("[%s%s%s]  " .. fmt,
                            string.rep(constants.STR_SPACE, beforeSpaceCount),
                            tag,
                            string.rep(constants.STR_SPACE, afterSpaceCount),
                            ...))
    end
end


local function __patchFunction(orgFunc, patchFunc)
    local ret = function(...)
        utils.invokeSafelly(patchFunc, ...)
        return utils.invokeSafelly(orgFunc, ...)
    end
    return ret
end


local function __createFile(app, fullPath, content)
    local dir = unportable.splitPath(fullPath)
    app:createDir(dir)

    local file = app:writeFile(fullPath)
    file:write(content or constants.STR_EMPTY)
    app:closeFile(file)
end


local MockPluginBase =
{
    _mName      = classlite.declareConstantField(nil),

    new = function(self, name)
        self._mName = name
    end,

    getName = function(self)
        return self._mName
    end,

    parseFile = function(self, app, filePath)
        __printLog(_TAG_PLUGIN, "%s -> %s", self:getName(), filePath)
    end,

    parseData = function(self, rawData)
        __printLog(_TAG_PLUGIN, "%s => %s", self:getName(), rawData)
    end
}

classlite.declareClass(MockPluginBase, pluginbase.IDanmakuSourcePlugin)


local MockRemoteDanmakuSourcePlugin =
{
    _mVideoIDsMap           = classlite.declareTableField(),
    _mIsSplitedFlags        = classlite.declareTableField(),
    _mVideoDurations        = classlite.declareTableField(),
    _mVideoTitles           = classlite.declareTableField(),
    _mVideoTitleColCounts   = classlite.declareTableField(),
    _mPreferredIDIndexes    = classlite.declareTableField(),
    __mVideoIDCount         = classlite.declareConstantField(0),


    dispose = function(self)
        utils.forEachTableValue(self._mVideoIDsMap, utils.clearTable)
        utils.forEachTableValue(self._mVideoDurations, utils.clearTable)
        utils.forEachTableValue(self._mVideoTitles, utils.clearTable)
    end,

    addSearchResult = function(self, keyword, titles, isSplited, colCount)
        local app = self._mApplication
        local videoIDsMap = self._mVideoIDsMap
        colCount = colCount or 1
        if not videoIDsMap[keyword]
        then
            local pluginName = self:getName()
            local videoIDs = {}
            local videoIDStart = self.__mVideoIDCount
            local videoIDCount = math.floor(#titles / colCount)
            for i = 1, videoIDCount
            do
                local videoIDNum = i + videoIDStart
                local videoID = string.format("%s_%d", pluginName, videoIDNum)
                table.insert(videoIDs, videoID)
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

    search = function(self, keyword, result)
        local videoIDs = self._mVideoIDsMap[keyword]
        if videoIDs
        then
            __printLog(_TAG_PLUGIN, "search %s -> %s", keyword, self:getName())
            result.isSplited = self._mIsSplitedFlags[keyword]
            result.preferredIDIndex = self._mPreferredIDIndexes[keyword]
            result.videoTitleColumnCount = self._mVideoTitleColCounts[keyword]
            utils.appendArrayElements(result.videoIDs, videoIDs)
            utils.appendArrayElements(result.videoTitles, self._mVideoTitles[keyword])
            return true
        end
    end,

    downloadRawDatas = function(self, videoIDs, outDatas)
        utils.appendArrayElements(outDatas, videoIDs)
    end,

    getVideoDurations = function(self, videoIDs, outDurations)
        for _, videoID in utils.iterateArray(videoIDs)
        do
            table.insert(outDurations, self._mVideoDurations[videoID])
        end
    end
}

classlite.declareClass(MockRemoteDanmakuSourcePlugin, MockPluginBase)


local MockLocalDanmakuSourcePlugin =
{
    _mMatchedFilePahtSet    = classlite.declareTableField(),

    addMatchedRawDataFile = function(self, fullPath)
        local app = self._mApplication
        __createFile(app, fullPath)
        self._mMatchedFilePahtSet[fullPath] = true
    end,

    isMatchedRawDataFile = function(self, filePath)
        return self._mMatchedFilePahtSet[filePath]
    end,
}

classlite.declareClass(MockLocalDanmakuSourcePlugin, MockPluginBase)


local MockShell =
{
    _mApplication               = classlite.declareClassField(mocks.MockApplication),
    _mDanmakuSourceManager      = classlite.declareClassField(mocks.MockDanmakuSourceManager),

    new = function(self)
        self:getParent().new(self)

        local app = self._mApplication
        local conn = app:getNetworkConnection()
        local plugin1 = MockRemoteDanmakuSourcePlugin:new("Remote1")
        local plugin2 = MockRemoteDanmakuSourcePlugin:new("Remote2")
        local plugin3 = MockLocalDanmakuSourcePlugin:new("Local1")
        app:addDanmakuSourcePlugin(plugin1)
        app:addDanmakuSourcePlugin(plugin2)
        app:addDanmakuSourcePlugin(plugin3)

        local function __printNetworkLog(_, url)
            __printLog(_TAG_NETWORK, "GET %s", url)
        end
        conn._createConnection = __patchFunction(conn._createConnection, __printNetworkLog)

        local function __initPluginResults()
            plugin1:addSearchResult("a", { "Title1", "Title2", "Title3", "Title4" }, true)
            plugin1:addSearchResult("b",
                                    { "Title1", "Subtitle1", "Title2", "Subtitle2" },
                                    false,
                                    2)

            plugin2:addSearchResult("c", { "Title1", "Title2" })

            plugin3:addMatchedRawDataFile("/local_source/1")
            plugin3:addMatchedRawDataFile("/local_source/2")
            plugin3:addMatchedRawDataFile("/local_source/3")
        end
        app.init = __patchFunction(__initPluginResults, app.init)


        local function __createPatchedFSFunction(orgFunc, tag)
            local function logFunc(_, fullPath)
                __printLog(_TAG_FILESYSTEM, "%s: %s", tag, fullPath or constants.STR_EMPTY)
            end
            return __patchFunction(orgFunc, logFunc)
        end
        app.readFile = __createPatchedFSFunction(app.readFile, "read")
        app.readUTF8File = __createPatchedFSFunction(app.readUTF8File, "readUTF8")
        app.writeFile = __createPatchedFSFunction(app.writeFile, "writeFile")
        app.closeFile = __createPatchedFSFunction(app.closeFile, "closeFile")
        app.createDir = __createPatchedFSFunction(app.createDir, "createDir")
        app.deleteTree = __createPatchedFSFunction(app.deleteTree, "deleteTree")
        app.createTempFile = __createPatchedFSFunction(app.createTempFile, "createTempFile")
    end,

    _commitDanmakus = function(self, assFilePath)
        __printLog(_TAG_APPLICATION, "set subtitle")
    end,
}

classlite.declareClass(MockShell, logic.MPVDanmakuLoaderShell)


local shell = MockShell:new()
local app = shell._mApplication
local cfg = app:getConfiguration()
local videoFilePath = "/dir/videofile.mp4"
cfg.localDanmakuSourceDirPath = "/local_source/"
__createFile(app, videoFilePath)
shell:show(cfg, videoFilePath)