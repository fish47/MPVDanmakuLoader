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


local MPVDanmakuLoaderShell =
{
    _mApplication               = classlite.declareConstantField(nil),
    _mDanmakuSourceManager      = classlite.declareClassField(sourcemgr.DanmakuSourceManager),

    _mUIStrings                 = classlite.declareConstantField(uiconstants.UI_STRINGS_CN),
    _mUISizes                   = classlite.declareConstantField(uiconstants.UI_SIZES_ZENITY),

    _mGUIBuilder                = classlite.declareClassField(unportable.ZenityGUIBuilder),
    __mTextInfoProperties       = classlite.declareClassField(unportable.TextInfoProperties),
    __mListBoxProperties        = classlite.declareClassField(unportable.ListBoxProperties),
    __mEntryProperties          = classlite.declareClassField(unportable.EntryProperties),
    __mFileSelectionProperties  = classlite.declareClassField(unportable.FileSelectionProperties),
    __mProgressBarProperties    = classlite.declareClassField(unportable.ProgressBarProperties),
    __mQuestionProperties       = classlite.declareClassField(unportable.QuestionProperties),

    _mDanmakuSources            = classlite.declareTableField(),

    __mSelectedIndexes          = classlite.declareTableField(),
    __mSelectedFilePaths        = classlite.declareTableField(),
    __mOptionStrings            = classlite.declareTableField(),

    __mVideoIDs                 = classlite.declareTableField(),
    __mStartTimeOffsets         = classlite.declareTableField(),
    __mDanmakuRawDatas          = classlite.declareTableField(),
    __mToBeUpdatedSources       = classlite.declareTableField(),
    __mPlugins                  = classlite.declareTableField(),

    __mSearchResult             = classlite.declareClassField(pluginbase.DanmakuSourceSearchResult),
}

function MPVDanmakuLoaderShell:dispose()
    utils.forEachArrayElement(self._mDanmakuSources, utils.disposeSafely)
end

function MPVDanmakuLoaderShell:setApplication(app)
    local sourceMgr = self._mDanmakuSourceManager
    self._mApplication = app
    app:getDanmakuPools():clear()
    sourceMgr:setApplication(app)
    sourceMgr:recycleDanmakuSources(self._mDanmakuSources)
end

function MPVDanmakuLoaderShell:__showSelectPlugins()
    local plugins = utils.clearTable(self.__mPlugins)
    local props = self.__mListBoxProperties
    props:reset()
    self:__initWindowProperties(props, self._mUISizes.select_plugin)
    props.listBoxTitle = self._mUIStrings.title_select_plugin
    props.listBoxColumnCount = 1
    props.isHeaderHidden = true
    for _, plugin in self._mApplication:iterateDanmakuSourcePlugins()
    do
        table.insert(plugins, plugin)
        table.insert(props.listBoxElements, plugin:getName())
    end

    local selectedIndexes = utils.clearTable(self.__mSelectedIndexes)
    if self._mGUIBuilder:showListBox(props, selectedIndexes)
    then
        return plugins[selectedIndexes[1]]
    end
end

function MPVDanmakuLoaderShell:_showSelectFiles(outPaths)
    local props = self.__mFileSelectionProperties
    props:reset()
    self:__initWindowProperties(props)
    props.isMultiSelectable = true
    return self._mGUIBuilder:showFileSelection(props, outPaths)
end

function MPVDanmakuLoaderShell:_showAddLocalDanmakuSource()
    local paths = utils.clearTable(self.__mSelectedFilePaths)
    local plugin = self:__showSelectPlugins()
    local hasSelectedFile = plugin and self:_showSelectFiles(paths)
    if hasSelectedFile
    then
        local sources = self._mDanmakuSources
        local sourceMgr = self._mDanmakuSourceManager
        for _, path in ipairs(paths)
        do
            sourceMgr:addLocalDanmakuSource(sources, plugin, path)
        end
    end

    return self:_showMain()
end


function MPVDanmakuLoaderShell:_showSearchDanmakuSource()
    local props = self.__mEntryProperties
    props:reset()
    self:__initWindowProperties(props)
    props.entryTitle = self._mUIStrings.title_search_danmaku_source

    local input = self._mGUIBuilder:showEntry(props)
    if types.isNilOrEmpty(input)
    then
        return self:_showMain()
    end

    local result = self.__mSearchResult
    for _, plugin in self._mApplication:iterateDanmakuSourcePlugins()
    do
        result:reset()
        if plugin:search(input, result)
        then
            return self:__showSelectNewDanmakuSource(plugin, result)
        end
    end

    -- 即使没有搜索结果也要弹一下
    result:reset()
    return self:__showSelectNewDanmakuSource(nil, result)
end


function MPVDanmakuLoaderShell:__showSelectNewDanmakuSource(plugin, result)
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
    local props = self.__mListBoxProperties
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
        return self:_showSearchDanmakuSource()
    end

    local videoIDs = utils.clearTable(self.__mVideoIDs)
    for _, idx in utils.iterateArray(selectedIndexes)
    do
        table.insert(videoIDs, result.videoIDs[idx])
    end

    local desc = table.concat(videoIDs, _SHELL_DESCRIPTION_VID_SEP)
    local offsets = utils.clearTable(self.__mStartTimeOffsets)
    __getDanmakuTimeOffsets(plugin, videoIDs, offsets)

    local sources = self._mDanmakuSources
    local sourceMgr = self._mDanmakuSourceManager
    local source = sourceMgr:addCachedDanmakuSource(sources, plugin, desc, videoIDs, offsets)

    return self:_showMain()
end


function MPVDanmakuLoaderShell:__doShowDanmakuSources(title, iterFunc,
                                                      selectedJumpFunc,
                                                      noselectedJumpFunc)
    local props = self.__mListBoxProperties
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
    local datetimeFormat = uiStrings.fmt_danmaku_source_datetime
    local unknownDatetimeString = uiStrings.datetime_unknown
    for _, source in utils.iterateArray(sources)
    do
        local date = source:getDate()
        local dateString = date and os.date(datetimeFormat, date) or unknownDatetimeString
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
end


function MPVDanmakuLoaderShell:__doCommitDanmakus(assFilePath)
    local sid = nil
    local app = self._mApplication
    local pools = app:getDanmakuPools()
    if assFilePath
    then
        app:deletePath(assFilePath)

        local file = app:writeFile(assFilePath, constants.FILE_MODE_WRITE_ERASE)
        local hasContent = pools:writeDanmakus(app, file)
        pools:clear()
        app:closeFile(file)
        if hasContent
        then
            sid = app:addSubtitleFile(assFilePath)
        end
    else
        local file = app:createTempFile()
        local hasContent = pools:writeDanmakus(app, file)
        pools:clear()
        file:seek(constants.SEEK_MODE_BEGIN)
        if hasContent
        then
            sid = app:addSubtitleData(file:read(constants.READ_MODE_ALL))
        end
        app:closeFile(file)
    end

    if not sid
    then
        return
    end

    local shouldReplace = false
    local mainSID = app:getMainSubtitleID()
    if not app:getConfiguration().promptOnReplaceMainSubtitle and mainSID
    then
        local uiStrings = self._mUIStrings
        local questionProps = self.__mQuestionProperties
        questionProps:reset()
        self:__initWindowProperties(questionProps)
        questionProps.questionText = uiStrings.select_subtitle_should_replace
        questionProps.labelTextOK = uiStrings.select_subtitle_ok
        questionProps.labelTextCancel = uiStrings.select_subtitle_cancel
        shouldReplace = self._mGUIBuilder:showQuestion(questionProps)
    end

    app:setMainSubtitleByID(sid)
    app:setSecondarySubtitleByID(shouldReplace and mainSID)
end

function MPVDanmakuLoaderShell:__commitDanmakus()
    local assFilePath = self._mApplication:getGeneratedASSFilePath()
    self:__doCommitDanmakus(assFilePath)
end

function MPVDanmakuLoaderShell:_showGenerateASSFile()
    local function __parseSource(self, sources, idx)
        sources[idx]:parse(self._mApplication)
    end

    self._mApplication:getDanmakuPools():clear()
    return self:__doShowDanmakuSources(self._mUIStrings.title_generate_ass_file,
                                        __parseSource,
                                        self.__commitDanmakus,
                                        self._showMain)
end


function MPVDanmakuLoaderShell:_showDeleteDanmakuSource()
    local function __deleteSource(self, sources, idx)
        if self._mDanmakuSourceManager:deleteDanmakuSourceByIndex(sources, idx)
        then
            table.remove(sources, idx)
        end
    end

    return self:__doShowDanmakuSources(self._mUIStrings.title_delete_danmaku_source,
                                        __deleteSource,
                                        self._showDeleteDanmakuSource,
                                        self._showMain)
end


function MPVDanmakuLoaderShell:_showUpdateDanmakuSource()
    local function __updateSource(self, sources, idx)
        table.insert(self.__mToBeUpdatedSources, sources[idx])
    end

    local function __updateAndShowDanmakuSources(self)
        local toBeUpdatedSources = self.__mToBeUpdatedSources
        local sourceMgr = self._mDanmakuSourceManager
        sourceMgr:updateDanmakuSources(toBeUpdatedSources, self._mDanmakuSources)
        utils.clearTable(toBeUpdatedSources)
        return self:_showUpdateDanmakuSource()
    end

    utils.clearTable(self.__mToBeUpdatedSources)
    return self:__doShowDanmakuSources(self._mUIStrings.title_update_danmaku_source,
                                        __updateSource,
                                        __updateAndShowDanmakuSources,
                                        self._showMain)
end


function MPVDanmakuLoaderShell:__initWindowProperties(props, sizeSpec)
    props.windowTitle = self._mUIStrings.title_app
    props.windowWidth = sizeSpec and sizeSpec[1]
    props.windowHeight = sizeSpec and sizeSpec[2]
end


function MPVDanmakuLoaderShell:_showMain()
    local uiStrings = self._mUIStrings
    local props = self.__mListBoxProperties
    props:reset()
    self:__initWindowProperties(props, self._mUISizes.main)
    props.listBoxTitle = uiStrings.title_main
    props.listBoxColumnCount = 1
    props.isHeaderHidden = true

    local options = utils.clearTable(self.__mOptionStrings)
    table.insert(options, uiStrings.option_main_add_local_danmaku_source)
    table.insert(options, uiStrings.option_main_search_danmaku_source)
    table.insert(options, uiStrings.option_main_update_danmaku_source)
    table.insert(options, uiStrings.option_main_delete_danmaku_source)
    table.insert(options, uiStrings.option_main_generate_ass_file)
    utils.appendArrayElements(props.listBoxElements, options)

    local selectedIndexes = self.__mSelectedIndexes
    self._mGUIBuilder:showListBox(props, selectedIndexes)

    local idx = selectedIndexes[1]
    local optionString = idx and options[idx]
    if optionString == uiStrings.option_main_add_local_danmaku_source
    then
        return self:_showAddLocalDanmakuSource()
    elseif optionString == uiStrings.option_main_search_danmaku_source
    then
        return self:_showSearchDanmakuSource()
    elseif optionString == uiStrings.option_main_update_danmaku_source
    then
        return self:_showUpdateDanmakuSource()
    elseif optionString == uiStrings.option_main_generate_ass_file
    then
        return self:_showGenerateASSFile()
    elseif optionString == uiStrings.option_main_delete_danmaku_source
    then
        return self:_showDeleteDanmakuSource()
    end
end


function MPVDanmakuLoaderShell:showMainWindow()
    self._mDanmakuSourceManager:listDanmakuSources(self._mDanmakuSources)
    return self:_showMain()
end


function MPVDanmakuLoaderShell:loadDanmakuFromURL(url)
    local uiStrings = self._mUIStrings
    local guiBuilder = self._mGUIBuilder
    local progressBarProps = self.__mProgressBarProperties
    progressBarProps:reset()
    self:__initWindowProperties(progressBarProps)

    local succeed = false
    local result = self.__mSearchResult
    local app = self._mApplication
    local handler = guiBuilder:showProgressBar(progressBarProps)
    guiBuilder:advanceProgressBar(handler, 10, uiStrings.load_progress_search)
    for _, plugin in app:iterateDanmakuSourcePlugins()
    do
        if plugin:search(url, result)
        then
            local ids = utils.clearTable(self.__mVideoIDs)
            local rawDatas = utils.clearTable(self.__mDanmakuRawDatas)
            local videoID = result.videoIDs[result.preferredIDIndex]
            table.insert(ids, videoID)

            guiBuilder:advanceProgressBar(handler, 60, uiStrings.load_progress_download)
            plugin:downloadDanmakuRawDatas(ids, rawDatas)

            local data = rawDatas[1]
            if types.isString(data)
            then
                local offset = _SHELL_TIMEOFFSET_START
                local pluginName = plugin:getName()
                local pools = app:getDanmakuPools()
                local sourceID = pools:allocateDanmakuSourceID(pluginName, videoID, nil, offset)
                guiBuilder:advanceProgressBar(handler, 90, uiStrings.load_progress_parse)
                plugin:parseData(data, sourceID, offset)
                self:__doCommitDanmakus()
                succeed = true
            end
        end
    end

    local lastMsg = succeed and uiStrings.load_progress_succeed or uiStrings.load_progress_failed
    guiBuilder:advanceProgressBar(handler, 100, lastMsg)
    guiBuilder:finishProgressBar(handler)
end

classlite.declareClass(MPVDanmakuLoaderShell)


return
{
    MPVDanmakuLoaderShell   = MPVDanmakuLoaderShell,
}
