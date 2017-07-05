local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local application   = require("src/shell/application")
local mocks         = require("test/mocks")


local _TITLE_WINDOW     = "TestPlugin"
local _TITLE_ENTRY      = "输入搜索命令"

local MockApplicationWithBuiltinPlugins =
{
    _mNetworkConnection     = classlite.declareClassField(unportable.CURLNetworkConnection),

    _initDanmakuSourcePlugins = application.MPVDanmakuLoaderApp._initDanmakuSourcePlugins,
}

classlite.declareClass(MockApplicationWithBuiltinPlugins, mocks.MockApplication)


local app = MockApplicationWithBuiltinPlugins:new()
local result = pluginbase.DanmakuSourceSearchResult:new()
local guiBuilder = unportable.ZenityGUIBuilder:new()
local entryProps = unportable.EntryProperties:new()
local listboxProps = unportable.ListBoxProperties:new()

while true
do
    entryProps:reset()
    entryProps.windowTitle = _TITLE_WINDOW
    entryProps.entryTitle = _TITLE_ENTRY
    local keyword = guiBuilder:showEntry(entryProps)
    if types.isNilOrEmptyString(keyword)
    then
        break
    end

    local plugin = nil
    for _, p in app:iterateDanmakuSourcePlugins()
    do
        result:reset()
        if p:search(keyword, result)
        then
            plugin = p
            break
        end
    end

    if plugin
    then
        listboxProps:reset()
        listboxProps.windowTitle = _TITLE_WINDOW
        listboxProps.windowWidth = 600
        listboxProps.windowHeight = 400
        listboxProps.listBoxTitle = plugin:getName()
        listboxProps.isMultiSelectable = result.isSplited
        listboxProps.listBoxColumnCount = result.videoTitleColumnCount + 1

        -- 加一列 VideoID
        local titleIdx = 1
        local rowCount = #result.videoTitles / result.videoTitleColumnCount
        for i = 1, rowCount
        do
            table.insert(listboxProps.listBoxElements, result.videoIDs[i])
            for j = 1, result.videoTitleColumnCount
            do
                table.insert(listboxProps.listBoxElements, result.videoTitles[titleIdx])
                titleIdx = titleIdx + 1
            end
        end

        guiBuilder:showListBox(listboxProps)
    end
end