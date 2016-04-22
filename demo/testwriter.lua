local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local application   = require("src/shell/application")
local configuration = require("src/shell/configuration")


local _TITLE_WINDOW     = "TestWriter"
local _TITLE_LISTBOX    = "选择插件"


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
    fileSelectionProps.isMultiSelectable = false
    fileSelectionProps.isDirectoryOnly = false
    fileSelectionProps.windowTitle = _TITLE_WINDOW
end

local function __initTextInfoProps(textInfoProps)
    textInfoProps.windowTitle = _TITLE_WINDOW
    textInfoProps.windowWidth = 1024
    textInfoProps.windowHeight = 800
end

local function __patchApplication(app)
    local function __createFunction(returnVal)
        local ret = function()
            return returnVal
        end
        return ret
    end

    app.getVideoWidth = __createFunction(800)
    app.getVideoHeight = __createFunction(800)
end


local app = application.MPVDanmakuLoaderApp:new()
local cfg = configuration.initConfiguration()
local listboxProps = unportable.ListBoxProperties:new()
local textInfoProps = unportable.TextInfoProperties:new()
local fileSelectionProps = unportable.FileSelectionProperties:new()
local guiBuilder = unportable.ZenityGUIBuilder:new()
local outSelectedIndexes = {}
local outSelectedFilePaths = {}

__patchApplication(app)
__initTextInfoProps(textInfoProps)
__initPluginListBoxProps(listboxProps, app)
__initFileSelectionProps(fileSelectionProps)

while true
do
    local hasSelectedPlugin = guiBuilder:showListBox(listboxProps, outSelectedIndexes)
    if not hasSelectedPlugin
    then
        break
    end

    local hasSelectedFile = guiBuilder:showFileSelection(fileSelectionProps, outSelectedFilePaths)
    if hasSelectedFile
    then
        local filePath = outSelectedFilePaths[1]
        local selectedIdx = outSelectedIndexes[1]
        local plugin = app:getPluginByName(listboxProps.listBoxElements[selectedIdx])
        app:init(cfg, nil)
        plugin:parseFile(filePath, constants.STR_EMPTY, 0)

        local tmpFile = app:createTempFile()
        app:getDanmakuPools():writeDanmakus(app, tmpFile)
        tmpFile:seek(constants.SEEK_MODE_BEGIN)
        guiBuilder:showTextInfo(textInfoProps, tmpFile:read(constants.READ_MODE_ALL))
        tmpFile:close()
    end
end