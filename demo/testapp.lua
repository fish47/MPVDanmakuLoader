local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local dandanplay    = require("src/search/dandanplay")
local bilibili      = require("src/search/bilibili")
local _source       = require("src/shell/_source")
local logic         = require("src/shell/logic")
local application   = require("src/shell/application")
local mockfs        = require("unittest/mockfs")


local MockApp =
{
    _mMockFileSystem    = classlite.declareClassField(mockfs.MockFileSystem),

    doesFileExist = function(self, fullPath)
        return self._mMockFileSystem.doesFileExist(fullPath)
    end,

    writeFile = function(self, fullPath)
        return self._mMockFileSystem:writeFile(fullPath)
    end,

    readUTF8File = function(self, fullPath)
        return self._mMockFileSystem:readFile(fullPath)
    end,

    createDir = function(self, dirName)
        return self._mMockFileSystem:createDir(dirName)
    end,

    deleteTree = function(self, fullPath)
        return self._mMockFileSystem:deleteTree(fullPath)
    end,

    listFiles = function(self, dir, outList)
        self._mMockFileSystem:listFiles(dir, outList)
    end,


    getBiliBiliVideoPartNames = function(self, videoID, outNames)
        utils.clearTable(outNames)
        if videoID == "001"
        then
            utils.appendArrayElements(outNames,
            {
                "1、分集1",
                "2、分集2",
            })
        elseif videoID == "002"
        then
            utils.appendArrayElements(outNames,
            {
                "1、没有分集"
            })
        end
    end,

    getAcfunVideoPartNames = function(self, videoID, outNames)
        return self:getBiliBiliVideoPartNames(videoID, outNames)
    end,

    getBiliBiliVideoDurations = function(self, videoID, partIndexes, outDurations)
        local partCount = types.isTable(partIndexes) and #partIndexes or 0
        for i = 1, partCount
        do
            utils.pushArrayElement(outDurations, math.random(10, 100))
        end
    end,

    getAcfunVideoDurations = function(self, videoID, partIndexes, outDurations)
        return self:getBiliBiliVideoDurations(videoID, partIndexes, outDurations)
    end,

    downloadBiliBiliDanmakuRawDatas = function(self, videoID, partIndexes, danmakuDir, outFilePaths)
        --TODO
    end,

    downloadAcfunDanmakuRawDatas = function(self, videoID, partIndexes, danmakuDir, outFilePaths)
        --TODO
    end,

    getVideoMD5 = function(self)
        return string.rep("1", 32)
    end,

    searchDanDanPlayByKeyword = function(self, keyword, outNames, outSubtitles, outURLs)
        if keyword == "key1"
        then
            utils.appendArrayElements(outNames, { "野猪大改造", "野猪大改造", "野猪大改造" })
            utils.appendArrayElements(outSubtitles, { "第一集", "第二集", "第三集" })
            utils.appendArrayElements(outURLs, { "u1", "u2", "u3" })
        elseif keyword == "key2"
        then
            utils.appendArrayElements(outNames, { "龙樱", "一公升的眼泪", "一公升的眼泪" })
            utils.appendArrayElements(outSubtitles, { "第一集", "第一集", "第二集" })
            utils.appendArrayElements(outURLs, { "u4", "u5", "u6" })
        end
    end,
}

classlite.declareClass(MockApp, application.MPVDanmakuLoaderApp)


local MockDanmakuSourceFactory =
{
    _obtainDanmakuSource = function(self, sourceType)
        local ret = self:getParent():_obtainDanmakuSource(sourceType)
        ret.parse = function(self)
            print(string.format("parse: %s", self:getType()))
        end
        return ret
    end,
}

classlite.declareClass(MockDanmakuSourceFactory, _source.DanmakuSourceFactory)


local MockShell =
{
    _createApplication = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return MockApp:new(cfg, conn)
    end,

    _createDanmakuSourceFactory = function(self)
        return MockDanmakuSourceFactory:new()
    end,
}

classlite.declareClass(MockShell, logic.MPVDanmakuLoaderShell)


local cfg = application.MPVDanmakuLoaderCfg:new()
local gui = MockShell:new(cfg)
gui:_showMain()