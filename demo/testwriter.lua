local _demoapp      = require("demo/_demoapp")
local utils         = require("src/base/utils")
local config        = require("src/shell/config")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local application   = require("src/shell/application")


local _TITLE_WINDOW     = "TestWriter"
local _TITLE_LISTBOX    = "选择插件"


local ApplicationImpl =
{
    readUTF8File    = application.MPVDanmakuLoaderApp.readUTF8File,
}

function ApplicationImpl:_updateConfiguration(cfg)
    _demoapp.DemoApplication._updateConfiguration(self, cfg)
    cfg.compareSourceIDHook = function()
        return true
    end
end

classlite.declareClass(ApplicationImpl, _demoapp.DemoApplication)


local function __initPluginListBoxProps(listboxProps, app)
    for _, plugin in app:iterateDanmakuSourcePlugins()
    do
        table.insert(listboxProps.listBoxElements, plugin:getName())
    end
    listboxProps.isHeaderHidden = true
    listboxProps.listBoxColumnCount = 1
    listboxProps.windowTitle = _TITLE_WINDOW
    listboxProps.listBoxTitle = _TITLE_LISTBOX
    listboxProps.windowWidth = 100
    listboxProps.windowHeight = 250
end

local function __initFileSelectionProps(fileSelectionProps)
    fileSelectionProps.isMultiSelectable = true
    fileSelectionProps.isDirectoryOnly = false
    fileSelectionProps.windowTitle = _TITLE_WINDOW
end

local function __initTextInfoProps(textInfoProps)
    textInfoProps.windowTitle = _TITLE_WINDOW
    textInfoProps.windowWidth = 1024
    textInfoProps.windowHeight = 800
end


local app = ApplicationImpl:new()
local listboxProps = unportable.ListBoxProperties:new()
local textInfoProps = unportable.TextInfoProperties:new()
local fileSelectionProps = unportable.FileSelectionProperties:new()
local guiBuilder = unportable.ZenityGUIBuilder:new()
local outSelectedIndexes = {}
local outSelectedFilePaths = {}

__initTextInfoProps(textInfoProps)
__initPluginListBoxProps(listboxProps, app)
__initFileSelectionProps(fileSelectionProps)
guiBuilder:setApplication(app)
app:updateConfiguration()

while true
do
    local hasSelectedPlugin = guiBuilder:showListBox(listboxProps, outSelectedIndexes)
    if not hasSelectedPlugin
    then
        break
    end

    app:init()
    app:updateConfiguration()

    local danmakuPools = app:getDanmakuPools()
    guiBuilder:showFileSelection(fileSelectionProps, outSelectedFilePaths)
    for _, filePath in ipairs(outSelectedFilePaths)
    do
        local selectedIdx = outSelectedIndexes[1]
        local plugin = app:getPluginByName(listboxProps.listBoxElements[selectedIdx])
        local sourceID = danmakuPools:allocateDanmakuSourceID()
        plugin:parseFile(filePath, sourceID, 0)
    end

    local tmpFile = app:createAnonymousTempFile()
    local hasContent = danmakuPools:writeDanmakus(app, tmpFile)
    if hasContent
    then
        tmpFile:seek(constants.SEEK_MODE_BEGIN)
        guiBuilder:showTextInfo(textInfoProps, tmpFile:read(constants.READ_MODE_ALL))
    end
    tmpFile:close()
end