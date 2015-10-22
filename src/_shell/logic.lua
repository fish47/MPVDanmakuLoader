local _base = require("src/_shell/_base")
local uiconstants = require("src/_shell/uiconstants")
local utils = require("src/utils")          --= utils utils
local app = require("src/app")


local _PATTERN_SEARCH_NAME  = "(.*)%..-$"

local MPVDanmakuLoaderShell =
{
    _mConfiguration                 = nil,
    _mNetworkConnection             = nil,
    _mMPVDanmakuLoaderApp           = nil,
    _mGUIBuilder                    = nil,
    _mUIStrings                     = nil,


    new = function(obj, cfg, conn, builder, uiStrings, uiSizes)
        obj = utils.allocateInstance(obj)
        obj._mConfiguration = cfg
        obj._mNetworkConnection = conn
        obj._mGUIBuilder = builder
        obj._mUIStrings = uiStrings or uiconstants.UI_STRINGS_CN
        obj._mUISizes = uiSizes or uiconstants.UI_SIZES_ZENITY
        return obj
    end,


    dispose = function(self)
        utils.disposeSafely(self._mConfiguration)
        utils.disposeSafely(self._mNetworkConnection)
        utils.disposeSafely(self._mMPVDanmakuLoaderApp)
        utils.disposeSafely(self._mGUIBuilder)
        utils.clearTable(self)
    end,


    setup = function(self)
        --TODO
    end,


    -- 目前只在单元测试用到
    _createApplication = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return app.MPVDanmakuLoaderApp:new(cfg, conn)
    end,


    _onLoadFile = function(self)
        utils.disposeSafely(self._mMPVDanmakuLoaderApp)
        self._mMPVDanmakuLoaderApp = self:_createApplication()
    end,


    __showSelectBiliBiliPieces = function(self, searchResults, indexes)
        if searchResults and indexes
        then
            --
        end

        return self:_showMain()
    end,


    __showBiliBiliSearchResults = function(self, results)
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        builder:reset()
        builder:createListBox()
        builder:setListBoxMultiSelectable(true)
        builder:setWindowTitle(uiStrings.app.title)
        builder:setListBoxTitle(uiStrings.search_bili.show_results.title)
        builder:setListBoxHeaders(uiStrings.search_bili.show_results.columns.type,
                                  uiStrings.search_bili.show_results.columns.title)

        if results
        then
            for _, info in ipairs(results)
            do
                builder:addListBoxTuple(info.videoType, info.videoTitle)
            end
        end

        local selectedIndexes = builder:show()
        if not selectedIndexes
        then
            -- 关键词不对，所以想再搜过？
            return self:_showSearchBiliBili()
        else
            return self:__showSelectBiliBiliPieces(results, selectedIndexes)
        end
    end,


    __getSuggestedSearchName = function(self)
        local fileName = self._mMPVDanmakuLoaderApp:getVideoFileName()
        local searchName = fileName:match(_PATTERN_SEARCH_NAME)
        return searchName or fileName
    end,


    _showSearchBiliBili = function(self)
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        builder:reset()
        builder:createEntry()
        builder:setWindowTitle(uiStrings.app.title)
        builder:setEntryTitle(uiStrings.search_bili.prompt.title)
        builder:setEntryText(self:__getSuggestedSearchName())

        local keyword = builder:show()
        if keyword
        then
            local app = self._mMPVDanmakuLoaderApp
            local results = app:searchBiliBiliByKeyword(keyword)
            return self:__showBiliBiliSearchResults(results)
        end

        return self:_showMain()
    end,


    _showSearchDanDanPlay = function(self)
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        builder:reset()
        builder:createListBox()
        builder:setWindowTitle(uiStrings.app.title)
        builder:setListBoxTitle(uiStrings.search_ddp.title)
        builder:setListBoxHeaders(uiStrings.search_ddp.columns.title,
                                  uiStrings.search_ddp.columns.subtitle)

        local app = self._mMPVDanmakuLoaderApp
        local results = app:searchDanDanPlayByVideoInfos()
        if results
        then
            for _, info in ipairs(results)
            do
                builder:addListBoxTuple(info.videoTitle, info.videoSubtitle)
            end
        end


        local selctedIndexes = builder:show()
        if selctedIndexes
        then
            --TODO
        end

        return self:_showMain()
    end,


    _showGenerateASSFile = function(self)
        --TODO
    end,

    _showDeleteDanmakuCache = function(self)
        --TODO
    end,


    _showMain = function(self)
        local uiSizes = self._mUISizes
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        builder:reset()
        builder:createListBox()
        builder:setWindowTitle(uiStrings.app.title)
        builder:setWindowWidth(uiSizes.main.width)
        builder:setWindowHeight(uiSizes.main.height)
        builder:setListBoxTitle(uiStrings.main.title)
        builder:setListBoxHeaderVisible(false)
        builder:addListBoxTuple(uiStrings.main.options.search_bilibili)
        builder:addListBoxTuple(uiStrings.main.options.search_dandanplay)
        builder:addListBoxTuple(uiStrings.main.options.generate_ass_file)
        builder:addListBoxTuple(uiStrings.main.options.delete_danmaku_cache)

        local ret = builder:show()
        if not ret
        then
            -- 什么都没有选
            return
        end

        local selectedIdx = ret[1]
        if selectedIdx == 1
        then
            return self:_showSearchBiliBili()
        elseif selectedIdx == 2
        then
            return self:_showSearchDanDanPlay()
        elseif selectedIdx == 3
        then
            return self:_showGenerateASSFile()
        elseif selectedIdx == 4
        then
            return self:_showDeleteDanmakuCache()
        end
    end,
}

utils.declareClass(MPVDanmakuLoaderShell)


return
{
    MPVDanmakuLoaderShell   = MPVDanmakuLoaderShell,
}