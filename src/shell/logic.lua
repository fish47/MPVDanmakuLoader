local utils         = require("src/base/utils")
local types         = require("src/base/types")
local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local application   = require("src/shell/application")
local uiconstants   = require("src/shell/uiconstants")
local sourcemgr     = require("src/shell/sourcemgr")


local _SHELL_TIMEOFFSET_START       = 0
local _SHELL_DESCRIPTION_VID_SEP    = ","
local _SHELL_DATE_FORMAT            = "%y/%m/%d %H:%M"


local MPVDanmakuLoaderShell =
{
    _mApplication           = classlite.declareClassField(application.MPVDanmakuLoaderApp),
    _mDanmakuSourceManager  = classlite.declareClassField(sourcemgr.DanmakuSourceManager),

    _mUIStrings             = classlite.declareConstantField(uiconstants.UI_STRINGS_CN),
    _mUISizes               = classlite.declareConstantField(uiconstants.UI_SIZES_ZENITY),

    _mGUIBuilder            = classlite.declareClassField(unportable.ZenityGUIBuilder),
    _mTextInfoProperties    = classlite.declareClassField(unportable.TextInfoProperties),
    _mListBoxProperties     = classlite.declareClassField(unportable.ListBoxProperties),
    _mEntryProperties       = classlite.declareClassField(unportable.EntryProperties),

    _mDanmakuSources        = classlite.declareTableField(),

    __mSelectedIndexes      = classlite.declareTableField(),
    __mOptionStrings        = classlite.declareTableField(),

    __mVideoIDs             = classlite.declareTableField(),
    __mTimeOffsets          = classlite.declareTableField(),
    __mDanmakuURLs          = classlite.declareTableField(),

    __mSearchResult         = classlite.declareClassField(pluginbase.DanmakuSourceSearchResult),


    new = function(self)
        self._mDanmakuSourceManager:setApplication(self._mApplication)
    end,

    dispose = function(self)
        utils.forEachArrayElement(self._mDanmakuSources, utils.disposeSafely)
    end,


    _showAddDanmakuSource = function(self)
        local props = self._mEntryProperties
        props:reset()
        self:__initWindowProperties(props)
        props.entryTitle = self._mUIStrings.title_add_danmaku_source

        local input = self._mGUIBuilder:showEntry(props)
        if types.isNilOrEmpty(input)
        then
            return self:_showMain()
        end

        local result = self.__mSearchResult
        for _, plugin in self._mApplication:iterateDanmakuSourcePlugin()
        do
            result:reset()
            if plugin:search(input, result)
            then
                return self:__showSelectNewDanmakuSource(plugin, result)
            end
        end

        return self:_showAddDanmakuSource()
    end,


    __showSelectNewDanmakuSource = function(self, plugin, result)
        local function __initListBoxHeaders(props, headerFormat, colCount)
            props.listBoxColumnCount = colCount
            for i = 1, colCount
            do
                local header = string.format(headerFormat, i)
                table.insert(props.listBoxHeaders, header)
            end
        end

        local function __getDanmakuTimeOffsets(plugin, videoIDs, timeOffsets)
            -- 最后一个分集视频的时长不需要知道
            local lastVID = utils.popArrayElement(videoIDs)
            if not types.isEmptyTable(videoIDs)
            then
                plugin:getVideoDurations(videoIDs, timeOffsets)
            end
            table.insert(timeOffsets, 1, _SHELL_TIMEOFFSET_START)
            table.insert(videoIDs, lastVID)
        end

        local uiStrings = self._mUIStrings
        local props = self._mListBoxProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.select_new_danmaku_source)
        props.listBoxTitle = uiStrings.title_select_new_danmaku_source
        props.isMultiSelectable = result.isSplited
        utils.appendArrayElements(props.listBoxElements, result.videoTitles)
        __initListBoxHeaders(props,
                             uiStrings.fmt_select_new_danmaku_source_header,
                             result.videoTitleColumnCount)

        local selectedIndexes = utils.clearTable(self.__mSelectedIndexes)
        if not self._mGUIBuilder:showListBox(props, selectedIndexes)
        then
            return self:_showAddDanmakuSource()
        end

        local videoIDs = utils.clearTable(self.__mVideoIDs)
        for _, idx in utils.iterateArray(selectedIndexes)
        do
            table.insert(videoIDs, result.videoIDs[idx])
        end

        local desc = table.concat(videoIDs, _SHELL_DESCRIPTION_VID_SEP)
        local urls = utils.clearTable(self.__mDanmakuURLs)
        local offsets = utils.clearTable(self.__mTimeOffsets)
        plugin:getDanmakuURLs(videoIDs, urls)
        __getDanmakuTimeOffsets(plugin, videoIDs, offsets)

        local sourceMgr = self._mDanmakuSourceManager
        local source = sourceMgr:addDanmakuSource(plugin, desc, offsets, urls)
        table.insert(self._mDanmakuSources, source)

        return self:_showMain()
    end,


    __doShowDanmakuSources = function(self, title, iterFunc, selectedJumpFunc, noselectedJumpFunc)
        local props = self._mListBoxProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.show_danmaku_sources)
        props.listBoxTitle = title
        props.isMultiSelectable = true

        local uiStrings = self._mUIStrings
        table.insert(props.listBoxHeaders, uiStrings.column_sources_date)
        table.insert(props.listBoxHeaders, uiStrings.column_sources_plugin_name)
        table.insert(props.listBoxHeaders, uiStrings.column_sources_description)
        props.listBoxColumnCount = #props.listBoxHeaders

        local sources = self._mDanmakuSources
        for _, source in utils.iterateArray(sources)
        do
            local date = source:getDate()
            local dateString = date and os.date(_SHELL_DATE_FORMAT, date) or constants.STR_EMPTY
            table.insert(props.listBoxElements, dateString)
            table.insert(props.listBoxElements, source:getPluginName())
            table.insert(props.listBoxElements, source:getDescription())
        end

        local selectedIndexes = utils.clearTable(self.__mSelectedIndexes)
        if self._mGUIBuilder:showListBox(props, selectedIndexes)
        then
            table.sort(selectedIndexes)
            for _, idx in utils.reverseIterateArray(selectedIndexes)
            do
                iterFunc(self, sources, idx)
            end
            return selectedJumpFunc(self)
        else
            return noselectedJumpFunc(self)
        end
    end,

    _commitDanmakus = function(self)
        local app = self._mApplication
        local pools = app:getDanmakuPools()
        local assFilePath = app:getConfiguration().generatedASSFilePath
        if assFilePath
        then
            local file = app:writeFile(assFilePath)
            pools:writeDanmakus(app, file)
            utils.closeSafely(file)
            app:setSubtitleByFilePath(assFilePath)
        else
            local file = io.tmpfile()
            pools:writeDanmakus(app, file)
            file:seek(constants.SEEK_MODE_BEGIN)
            app:setSubtitleByData(file:read(constants.READ_MODE_ALL))
            utils.closeSafely(file)
        end
    end,

    _showGenerateASSFile = function(self)
        local function __parseSource(self, sources, idx)
            sources[idx]:parse(self._mApplication)
        end

        self._mApplication:getDanmakuPools():clear()
        return self:__doShowDanmakuSources(self._mUIStrings.title_generate_ass_file,
                                           __parseSource,
                                           self._commitDanmakus,
                                           self._showMain)
    end,


    _showDeleteDanmakuSource = function(self)
        local function __deleteSource(self, sources, idx)
            if self._mDanmakuSourceManager:deleteDanmakuSource(sources[idx])
            then
                table.remove(sources, idx)
            end
        end

        return self:__doShowDanmakuSources(self._mUIStrings.title_delete_danmaku_source,
                                           __deleteSource,
                                           self._showDeleteDanmakuSource,
                                           self._showMain)
    end,


    _showUpdateDanmakuSource = function(self)
        local function __updateSource(self, sources, idx)
            local sourceMgr = self._mDanmakuSourceManager
            local newSource = sourceMgr:updateDanmakuSource(sources[idx])
            table.insert(sources, newSource)
        end

        return self:__doShowDanmakuSources(self._mUIStrings.title_update_danmaku_source,
                                           __updateSource,
                                           self._showUpdateDanmakuSource,
                                           self._showMain)
    end,


    __initWindowProperties = function(self, props, sizeSpec)
        props.windowTitle = self._mUIStrings.title_app
        props.windowWidth = sizeSpec and sizeSpec[1]
        props.windowHeight = sizeSpec and sizeSpec[2]
    end,


    _showHelp = function(self)
        local props = self._mTextInfoProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.help)
        props.textInfoContent = self._mUIStrings.option_main_show_help
        self._mGUIBuilder:showTextInfo(props)
        return self:_showMain()
    end,


    _showMain = function(self)
        local uiStrings = self._mUIStrings
        local props = self._mListBoxProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.main)
        props.listBoxTitle = uiStrings.title_main
        props.listBoxColumnCount = 1
        props.isHeaderHidden = true

        local options = utils.clearTable(self.__mOptionStrings)
        table.insert(options, uiStrings.option_main_add_danmaku_source)
        table.insert(options, uiStrings.option_main_update_danmaku_source)
        table.insert(options, uiStrings.option_main_delete_danmaku_source)
        table.insert(options, uiStrings.option_main_generate_ass_file)
        table.insert(options, uiStrings.option_main_show_help)
        utils.appendArrayElements(props.listBoxElements, options)

        local selectedIndexes = self.__mSelectedIndexes
        self._mGUIBuilder:showListBox(props, selectedIndexes)

        local idx = selectedIndexes[1]
        local optionString = idx and options[idx]
        if optionString == uiStrings.option_main_add_danmaku_source
        then
            return self:_showAddDanmakuSource()
        elseif optionString == uiStrings.option_main_update_danmaku_source
        then
            return self:_showUpdateDanmakuSource()
        elseif optionString == uiStrings.option_main_generate_ass_file
        then
            return self:_showGenerateASSFile()
        elseif optionString == uiStrings.option_main_delete_danmaku_source
        then
            return self:_showDeleteDanmakuSource()
        elseif optionString == uiStrings.option_main_show_help
        then
            return self:_showHelp()
        end
    end,


    show = function(self, cfg, videoFilePath)
        local sources = self._mDanmakuSources
        local sourceMgr = self._mDanmakuSourceManager
        self._mApplication:init(cfg, videoFilePath)
        sourceMgr:recycleDanmakuSources(sources)
        sourceMgr:listDanmakuSources(sources)
        return self:_showMain()
    end,


    loadDanmakuFromURL = function(self, cfg, url)
        local app = self._mApplication
        app:init(cfg, nil)

        local result = self.__mSearchResult
        for _, plugin in app:iterateDanmakuSourcePlugin()
        do
            if plugin:search(url, result)
            then
                --TODO
            end
        end
    end,
}

classlite.declareClass(MPVDanmakuLoaderShell)


return
{
    MPVDanmakuLoaderShell   = MPVDanmakuLoaderShell,
}