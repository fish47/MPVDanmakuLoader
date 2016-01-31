local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")
local unportable    = require("src/base/unportable")
local application   = require("src/shell/application")
local uiconstants   = require("src/shell/uiconstants")
local sourcefactory = require("src/shell/sourcefactory")


local _SEARCH_PATTERN_BILI_AV       = "%s*av(%d+)%s*"
local _SEARCH_PATTERN_BILI_URL      = ".*www%.bilbili%..*/av(%d+).*"
local _SEARCH_PATTERN_ACFUN_AC      = "%s*ac(%d+)%s*"
local _SEARCH_PATTERN_ACFUN_URL     = ".*www%.acfun%..*/v/ac(%d+).*"
local _SEARCH_PATTERN_DDP_KEYWORD   = "ddp:%s*(.+)%s*"


local MPVDanmakuLoaderShell =
{
    _mApplication               = classlite.declareConstantField(nil),
    _mConfiguration             = classlite.declareConstantField(nil),
    _mDanmakuSourceFactory      = classlite.declareConstantField(nil),
    _mNetworkConnection         = classlite.declareClassField(unportable.CURLNetworkConnection),

    _mUIStrings                 = classlite.declareConstantField(uiconstants.UI_STRINGS_CN),
    _mUISizes                   = classlite.declareConstantField(uiconstants.UI_SIZES_ZENITY),

    _mGUIBuilder                = classlite.declareClassField(unportable.ZenityGUIBuilder),
    _mTextInfoProperties        = classlite.declareClassField(unportable.TextInfoProperties),
    _mListBoxProperties         = classlite.declareClassField(unportable.ListBoxProperties),
    _mEntryProperties           = classlite.declareClassField(unportable.EntryProperties),


    __mSelectedIndexes          = classlite.declareTableField(),
    __mVideoPartNames           = classlite.declareTableField(),
    __mVideoPartIndexes         = classlite.declareTableField(),
    __mDanmakuTimeOffsets       = classlite.declareTableField(),
    __mDanmakuRawDataFilePaths  = classlite.declareTableField(),
    __mDanmakuSources           = classlite.declareTableField(),

    __mDDPVideoTitles           = classlite.declareTableField(),
    __mDDPVideoSubtitles        = classlite.declareTableField(),
    __mDDPDanmakuURLs           = classlite.declareTableField(),


    new = function(self, cfg)
        self._mConfiguration = cfg
        self._mApplication = self:_createApplication()
        self._mDanmakuSourceFactory = self:_createDanmakuSourceFactory()
    end,

    dispose = function(self)
        utils.disposeSafely(self._mApplication)
    end,


    setup = function(self)
        --TODO
    end,

    _onLoadFile = function(self)
        self._mApplication:_onLoadFile()
    end,

    _createApplication = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return application.MPVDanmakuLoaderApp:new(cfg, conn)
    end,

    _createDanmakuSourceFactory = function(self)
        return sourcefactory.DanmakuSourceFactory:new()
    end,


    __showDanDanPlaySource = function(self, keyword)
        local uiStrings = self._mUIStrings
        local props = self._mListBoxProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.search_result)
        props.listBoxTitle = uiStrings.add_danmaku_src_ddp.title
        props.listBoxColumnCount = 2
        props.isMultiSelectable = false
        utils.appendArrayElements(props.listBoxHeaders, uiStrings.add_danmaku_src_ddp.columns)

        local titles = utils.clearTable(self.__mDDPVideoTitles)
        local subtitles = utils.clearTable(self.__mDDPVideoSubtitles)
        local danmakuURLs = utils.clearTable(self.__mDDPDanmakuURLs)
        self._mApplication:searchDanDanPlayByKeyword(keyword, titles, subtitles, danmakuURLs)
        for i = 1, #titles
        do
            table.insert(props.listBoxElements, titles[i])
            table.insert(props.listBoxElements, subtitles[i])
        end

        local selectedIndexes = utils.clearTable(self.__mSelectedIndexes)
        self._mGUIBuilder:showListBox(props, selectedIndexes)
        if types.isNilOrEmpty(selectedIndexes)
        then
            return self:_showAddDanmakuSource()
        end

        --TODO
        return self:_showAddDanmakuSource()
    end,


    __doShowGenericDanmakuSource = function(self,
                                            title,
                                            getVideoPartNamesFunc,
                                            getVideoDurationsFunc,
                                            addDanmakuSourceFunc,
                                            downloadDanmakuRawDatasFunc,
                                            videoID)
        local uiStrings = self._mUIStrings
        local props = self._mListBoxProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.search_result)
        props.listBoxTitle = title
        props.listBoxColumnCount = 1
        props.isHeaderHidden = true
        props.isMultiSelectable = true

        -- 根据标题选择分集
        local videoNames = utils.clearTable(self.__mVideoPartNames)
        local selectedIndexes = utils.clearTable(self.__mSelectedIndexes)
        getVideoPartNamesFunc(self, videoID, videoNames)
        utils.appendArrayElements(props.listBoxElements, videoNames)
        self._mGUIBuilder:showListBox(props, selectedIndexes)
        if types.isNilOrEmpty(selectedIndexes)
        then
            return self:_showAddDanmakuSource()
        end

        -- 如果需要合并分集弹幕，需要获取时间偏移
        -- 分集视频应该都是顺序播放的吧？
        local timeOffsets = utils.clearTable(self.__mDanmakuTimeOffsets)
        local videoPartIndexes = utils.clearTable(self.__mVideoPartIndexes)
        utils.appendArrayElements(videoPartIndexes, selectedIndexes)
        if #selectedIndexes == 1
        then
            table.insert(timeOffsets, 0)
        else
            utils.popArrayElement(videoPartIndexes)
            getVideoDurationsFunc(self, videoID, videoPartIndexes, timeOffsets)
            table.insert(timeOffsets, 1, 0)
        end

        -- 下载并添加到弹幕源
        local videoMD5 = self._mApplication:getVideoMD5()
        local danmakuDir = self._mApplication:getDanmakuSourceRawDataDirPath()
        local filePaths = utils.clearTable(self.__mDanmakuRawDataFilePaths)
        downloadDanmakuRawDatasFunc(self, videoID, videoPartIndexes, danmakuDir, filePaths)
        addDanmakuSourceFunc(self, videoMD5, videoID, videoPartIndexes, filePaths, timeOffsets)
        return self:_showAddDanmakuSource()
    end,


    __showBiliBiliSource = function(self, videoID)
        local function __getVideoPartNames(self, ...)
            return self._mApplication:getBiliBiliVideoPartNames(...)
        end
        local function __getVideoDurations(self, ...)
            return self._mApplication:getBiliBiliVideoDurations(...)
        end
        local function __addDanmakuSource(self, ...)
            return self._mDanmakuSourceFactory:addBiliBiliDanmakuSource(...)
        end
        local function __downloadDanmakuRawDatas(self, ...)
            return self._mApplication:downloadBiliBiliDanmakuRawData(...)
        end
        return self:__doShowGenericDanmakuSource(self._mUIStrings.add_danmaku_src_bili.title,
                                                 __getVideoPartNames,
                                                 __getVideoDurations,
                                                 __addDanmakuSource,
                                                 __downloadDanmakuRawDatas,
                                                 videoID)
    end,


    __showAcfunSource = function(self, videoID)
        local function __getVideoPartNames(self, ...)
            return self._mApplication:getAcfunVideoPartNames(...)
        end
        local function __getVideoDurations(self, ...)
            return self._mApplication:getAcfunVideoDurations(...)
        end
        local function __addDanmakuSource(self, ...)
            return self._mDanmakuSourceFactory:addAcfunDanmakuSource(...)
        end
        local function __downloadDanmakuRawDatas(self, ...)
            return self._mApplication:downloadAcfunDanmakuRawDatas(...)
        end
        return self:__doShowGenericDanmakuSource(self._mUIStrings.add_danmaku_src_acfun.title,
                                                 __getVideoPartNames,
                                                 __getVideoDurations,
                                                 __addDanmakuSource,
                                                 __downloadDanmakuRawDatas,
                                                 videoID)
    end,


    _showAddDanmakuSource = function(self)
        local uiSizes = self._mUISizes
        local uiStrings = self._mUIStrings
        local props = self._mEntryProperties
        props:reset()
        self:__initWindowProperties(props)
        props.entryTitle = uiStrings.add_danmaku_src.title

        local input = self._mGUIBuilder:showEntry(props)
        if not input
        then
            return self:_showMain()
        end

        -- BiliBili
        local biliVideoID = input:match(_SEARCH_PATTERN_BILI_AV)
        biliVideoID = biliVideoID or input:match(_SEARCH_PATTERN_BILI_URL)
        if biliVideoID
        then
            return self:__showBiliBiliSource(biliVideoID)
        end

        -- Acfun
        local acfunVideoID = input:match(_SEARCH_PATTERN_ACFUN_AC)
        acfunVideoID = acfunVideoID or input:match(_SEARCH_PATTERN_ACFUN_URL)
        if acfunVideoID
        then
            --TODO
            -- http://www.acfun.tv/member/special/getSpecialContentPageBySpecial.aspx?specialId=1058
            -- http://www.acfun.tv/video/getVideo.aspx?id=1280192
            return self:__showAcfunSource(acfunVideoID)
        end

        -- 弹弹Play
        local dandanplayKeyword = input:match(_SEARCH_PATTERN_DDP_KEYWORD)
        if dandanplayKeyword
        then
            return self:__showDanDanPlaySource(dandanplayKeyword)
        end

        return self:_showAddDanmakuSource(true)
    end,

    _showGenerateASSFile = function(self)
        local app = self._mApplication
        local srtDirPath = self:getSRTFileDirPath()
        local danmakuSources = utils.clearTable(self.__mDanmakuSources)
        self._mDanmakuSourceFactory:listSRTDanmakuSources(app, srtDirPath, danmakuSources)

        --TODO
    end,

    _showDeleteDanmakuSources = function(self)
        --TODO
    end,

    _showUpdateDanmakuSources = function(self)
        --TODO
    end,

    __initWindowProperties = function(self, props, sizeSpec)
        props.windowTitle = self._mUIStrings.app.title
        props.windowWidth = sizeSpec and sizeSpec.width
        props.windowHeight = sizeSpec and sizeSpec.height
    end,


    _showHelp = function(self)
        local uiStrings = self._mUIStrings
        local props = self._mTextInfoProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.help)
        props.textInfoContent = uiStrings.help.content
        self._mGUIBuilder:showTextInfo(props)
        return self:_showMain()
    end,


    _showMain = function(self)
        local uiStrings = self._mUIStrings
        local props = self._mListBoxProperties
        props:reset()
        self:__initWindowProperties(props, self._mUISizes.main)
        props.listBoxTitle = uiStrings.main.title
        props.listBoxColumnCount = 1
        props.isHeaderHidden = true
        table.insert(props.listBoxElements, uiStrings.main.options.add_danmaku_src)
        table.insert(props.listBoxElements, uiStrings.main.options.update_danmaku)
        table.insert(props.listBoxElements, uiStrings.main.options.generate_ass_file)
        table.insert(props.listBoxElements, uiStrings.main.options.delete_danmaku_cache)
        table.insert(props.listBoxElements, uiStrings.main.options.show_help)

        local selectedIndexes = self.__mSelectedIndexes
        self._mGUIBuilder:showListBox(props, selectedIndexes)

        local optionIdx = selectedIndexes[1]
        if optionIdx == 1
        then
            return self:_showAddDanmakuSource()
        elseif optionIdx == 2
        then
            return self:_showUpdateDanmakuSources()
        elseif optionIdx == 3
        then
            return self:_showGenerateASSFile()
        elseif optionIdx == 4
        then
            return self:_showDeleteDanmakuSources()
        elseif optionIdx == 5
        then
            return self:_showHelp()
        end
    end,
}

classlite.declareClass(MPVDanmakuLoaderShell)


return
{
    MPVDanmakuLoaderShell   = MPVDanmakuLoaderShell,
}