local _base = require("src/_shell/_base")
local uistrings = require("src/_shell/uistrings")
local utils = require("src/utils")          --= utils utils
local mdlapp = require("src/app")


local MPVDanmakuLoaderShell =
{
    _mConfiguration                 = nil,
    _mNetworkConnection             = nil,
    _mMPVDanmakuLoaderApp           = nil,
    _mGUIBuilder                    = nil,
    _mUIStrings                     = nil,

    new = function(obj, zenityBin, cfg, conn, guiBuilder, uiStrings)
        obj = utils.allocateInstance(obj)
        obj._mConfiguration = cfg
        obj._mNetworkConnection = conn
        obj._mGUIBuilder = guiBuilder
        obj._mUIStrings = uiStrings or uistrings.UI_STRINGS_CN
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


    -- 目录只在单元测试用到
    _createApp = function(self)
        local cfg = self._mConfiguration
        local conn = self._mNetworkConnection
        return mdlapp.MPVDanmakuLoaderApp:new(cfg, conn)
    end,


    __onFileLoad = function(self)
        utils.disposeSafely(self._mMPVDanmakuLoaderApp)
        self._mMPVDanmakuLoaderApp = self:_createApp()
    end,

    _showSearchBiliBili = function(self)
        --
    end,

    _showMain = function(self)
        local uiStrings = self._mUIStrings
        local guiBuilder = self._mGUIBuilder
        guiBuilder:reset()
        guiBuilder:setWindowTitle(uiStrings.app.title)
        guiBuilder:createListBox()
        guiBuilder:setListBoxTitle(uiStrings.main.title)
        guiBuilder:setListBoxHeaderVisible(false)
        guiBuilder:addListBoxTuple(uiStrings.main.options.search_bilibili)
        guiBuilder:addListBoxTuple(uiStrings.main.options.search_dandanplay)
        guiBuilder:addListBoxTuple(uiStrings.main.options.generate_ass_file)

        local ret = guiBuilder:show()
        if not ret
        then
            -- 什么都没有选？
        elseif ret == 1
        then
            return self:_showSearchBiliBili()
        elseif ret == 2
        then
            return self:_showSearchDanDanPlay()
        elseif ret == 3
        then
            return self:_showGenerateASSFile()
        end
    end,
}

utils.declareClass(MPVDanmakuLoaderShell)


return
{
    MPVDanmakuLoaderShell   = MPVDanmakuLoaderShell,
}