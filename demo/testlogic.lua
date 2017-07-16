local mock          = require("common/mock")
local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local logic         = require("src/shell/logic")


local MockRemoteDanmakuSourcePlugin =
{
    _mName                  = classlite.declareConstantField(nil),
    _mVideoIDsMap           = classlite.declareTableField(),
    _mIsSplitedFlags        = classlite.declareTableField(),
    _mVideoDurations        = classlite.declareTableField(),
    _mVideoTitles           = classlite.declareTableField(),
    _mVideoTitleColCounts   = classlite.declareTableField(),
    _mPreferredIDIndexes    = classlite.declareTableField(),
    __mVideoIDCount         = classlite.declareConstantField(0),
}

function MockRemoteDanmakuSourcePlugin:new(name)
    self._mName = name
end

function MockRemoteDanmakuSourcePlugin:getName()
    return self._mName
end

function MockRemoteDanmakuSourcePlugin:dispose()
    utils.forEachTableValue(self._mVideoIDsMap, utils.clearTable)
    utils.forEachTableValue(self._mVideoDurations, utils.clearTable)
    utils.forEachTableValue(self._mVideoTitles, utils.clearTable)
end

function MockRemoteDanmakuSourcePlugin:addSearchResult(keyword, titles, isSplited, colCount)
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
end

function MockRemoteDanmakuSourcePlugin:search(keyword, result)
    local videoIDs = self._mVideoIDsMap[keyword]
    if videoIDs
    then
        result.isSplited = self._mIsSplitedFlags[keyword]
        result.preferredIDIndex = self._mPreferredIDIndexes[keyword]
        result.videoTitleColumnCount = self._mVideoTitleColCounts[keyword]
        utils.appendArrayElements(result.videoIDs, videoIDs)
        utils.appendArrayElements(result.videoTitles, self._mVideoTitles[keyword])
        return true
    end
end

function MockRemoteDanmakuSourcePlugin:downloadDanmakuRawDataList(videoIDs, outList)
    utils.appendArrayElements(outList, videoIDs)
end

function MockRemoteDanmakuSourcePlugin:getVideoDurations(videoIDs, outDurations)
    for _, videoID in utils.iterateArray(videoIDs)
    do
        table.insert(outDurations, self._mVideoDurations[videoID])
    end
end

classlite.declareClass(MockRemoteDanmakuSourcePlugin, pluginbase.IDanmakuSourcePlugin)


local MockShell =
{
    _mApplication           = classlite.declareClassField(mock.DemoApplication),
    _mDanmakuSourceManager  = classlite.declareClassField(mock.MockDanmakuSourceManager),
}


function MockShell:new()
    logic.MPVDanmakuLoaderShell.new(self)

    local app = self._mApplication
    app:setLogFunction(print)
    self:setApplication(app)

    local plugin1 = MockRemoteDanmakuSourcePlugin:new("Plugin1")
    local plugin2 = MockRemoteDanmakuSourcePlugin:new("Plugin2")
    app:_addDanmakuSourcePlugin(plugin1)
    app:_addDanmakuSourcePlugin(plugin2)

    local orgInitFunc = app.init
    app.init = function(self, ...)
        orgInitFunc(self, ...)
        plugin1:addSearchResult("a", { "Title1", "Title2", "Title3", "Title4" }, true)
        plugin1:addSearchResult("b",
                                { "Title1", "Subtitle1", "Title2", "Subtitle2" },
                                false,
                                2)

        plugin2:addSearchResult("c", { "Title1", "Title2" })
    end
end


function MockShell:_showSelectFiles(outPaths)
    -- 控件选中的是实际文件系统的路径，在虚拟文件系统是不存在的，这里也顺道创建空文件
    local ret = logic.MPVDanmakuLoaderShell._showSelectFiles(self, outPaths)
    local app = self._mApplication
    for _, path in ipairs(outPaths)
    do
        if not app:isExistedFile(path)
        then
            app:createDir(unportable.splitPath(path))
            local f = app:writeFile(path)
            f:write(constants.STR_EMPTY)
            app:closeFile(f)
        end
    end
    return ret
end

classlite.declareClass(MockShell, logic.MPVDanmakuLoaderShell)


local shell = MockShell:new()
local app = shell._mApplication
app:setLogFunction(print)
app:init()
app:updateConfiguration()
shell:showMainWindow()
app:dispose()