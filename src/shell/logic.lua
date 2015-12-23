local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local application   = require("src/shell/application")
local uiconstants   = require("src/shell/uiconstants")


local MPVDanmakuLoaderShell =
{
    _mApplication           = classlite.declareConstantField(nil),
    _mConfiguration         = classlite.declareConstantField(nil),
    _mNetworkConnection     = classlite.declareClassField(unportable.CURLNetworkConnection),
    _mGUIBuilder            = classlite.declareClassField(unportable.ZenityGUIBuilder),
    _mUIStrings             = classlite.declareConstantField(uiconstants.UI_STRINGS_CN),
    _mUISizes               = classlite.declareConstantField(uiconstants.UI_SIZES_ZENITY),

    _mTextInfoProperties    = classlite.declareClassField(unportable.TextInfoProperties),
    _mListBoxProperties     = classlite.declareClassField(unportable.ListBoxProperties),
    _mEntryProperties       = classlite.declareClassField(unportable.EntryProperties),

    _mSelectedIndexes       = classlite.declareTableField(),


    new = function(self, cfg)
        self._mConfiguration = cfg
    end,

    dispose = function(self)
        utils.disposeSafely(self._mApplication)
    end,


    setup = function(self)
        --TODO
    end,


    -- 目前只在单元测试用到
    _createApplication = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return application.MPVDanmakuLoaderApp:new(cfg, conn)
    end,


    _onLoadFile = function(self)
        utils.disposeSafely(self._mApplication)
        self._mApplication = self:_createApplication()
    end,


    __showSelectBiliBiliParts = function(self, searchResults, indexes)
        if searchResults and indexes
        then
            --
        end

        return self:_showMain()
    end,


    __showBiliBiliSearchResults = function(self, results)
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        local props = self._mListBoxProperties
        props:reset()
        props.isMultiSelectable = true
        props.windowTitle = uiStrings.app.title
        props.listBoxTitle = uiStrings.search_bili.show_results.title
        table.insert(props.listboxHeaders, uiStrings.search_bili.show_results.columns.type)
        table.insert(props.listboxHeaders, uiStrings.search_bili.show_results.columns.title)
        if results
        then
            for _, info in ipairs(results)
            do
                table.insert(props.listBoxElements, info.videoType)
                table.insert(props.listBoxElements, info.videoTitle)
            end
        end

        local selectedIndexes = builder:showListBox(props)
        if not selectedIndexes
        then
            -- 关键词不对，所以想再搜过？
            return self:_showSearchBiliBili()
        else
            return self:__showSelectBiliBiliParts(results, selectedIndexes)
        end
    end,


    __getSuggestedSearchName = function(self)
        --TODO 保存上次搜索结果
        return "123"
    end,


    _showSearchBiliBili = function(self)
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        local props = self._mEntryProperties
        props:reset()
        props.windowTitle = uiStrings.app.title
        props.entryTitle = uiStrings.search_bili.prompt.title
        props.entryText = self:__getSuggestedSearchName()

        local keyword = builder:showEntry(props)
        if keyword
        then
            local app = self._mApplication
            local results = app:searchBiliBiliByKeyword(keyword)
            return self:__showBiliBiliSearchResults(results)
        end

        return self:_showMain()
    end,


    _showSearchDanDanPlay = function(self)
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        local props = self._mListBoxProperties
        props:reset()
        props.windowTitle = uiStrings.app.title
        props.listBoxTitle = uiStrings.search_ddp.title
        table.insert(props.listboxHeaders, uiStrings.search_ddp.columns.title)
        table.insert(props.listboxHeaders, uiStrings.search_ddp.columns.subtitle)

        local app = self._mApplication
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


    _showHelp = function(self)
        local uiSizes = self._mUISizes
        local uiStrings = self._mUIStrings
        local builder = self._mGUIBuilder
        local props = self._mTextInfoProperties
        props:reset()
        props.windowTitle = uiStrings.show_help.title
        props.windowWidth = uiSizes.show_help.width
        props.windowHeight = uiSizes.show_help.height
        props.textInfoContent = uiStrings.show_help.content
        self._mGUIBuilder:showTextInfo(props)
        return self:_showMain()
    end,


    _showMain = function(self)
        local uiSizes = self._mUISizes
        local uiStrings = self._mUIStrings
        local props = self._mListBoxProperties
        props:reset()
        props.windowTitle = uiStrings.app.title
        props.windowWidth = uiSizes.main.width
        props.windowHeight = uiSizes.main.height
        props.listBoxTitle = uiStrings.main.title
        props.listBoxColumnCount = 1
        props.isHeaderHidden = true
        table.insert(props.listBoxElements, uiStrings.main.options.search_danmaku)
        table.insert(props.listBoxElements, uiStrings.main.options.update_danmaku)
        table.insert(props.listBoxElements, uiStrings.main.options.generate_ass_file)
        table.insert(props.listBoxElements, uiStrings.main.options.delete_danmaku_cache)
        table.insert(props.listBoxElements, uiStrings.main.options.show_help)

        local selectedIndexes = self._mSelectedIndexes
        self._mGUIBuilder:showListBox(props, selectedIndexes)

        local optionIdx = selectedIndexes[1]
        if optionIdx == 1
        then
            --TODO
        elseif optionIdx == 2
        then
            --TODO
        elseif optionIdx == 3
        then
            return self:_showGenerateASSFile()
        elseif optionIdx == 4
        then
            --TODO
        elseif optionIdx == 5
        then
            return self:_showHelp()
        else
            -- 退出
            return
        end
    end,
}

classlite.declareClass(MPVDanmakuLoaderShell)


return
{
    MPVDanmakuLoaderShell   = MPVDanmakuLoaderShell,
}