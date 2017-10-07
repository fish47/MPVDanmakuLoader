local _gApplication         = nil
local _gLoaderShell         = nil
local _gOpenedURL           = nil
local _gOpenedFilePath      = nil
local _gIsAppInitialized    = false
local _gTempOptionTable     = nil


local function __ensureApplication()
    local app = _gApplication
    if not app
    then
        local application = require("src/shell/application")
        app = application.MPVDanmakuLoaderApp:new()
        _gApplication = app
    end

    if not _gIsAppInitialized
    then
        _gIsAppInitialized = true
        app:init(_gOpenedFilePath)
    end

    app:updateConfiguration()
    return app
end


local function __ensureLoaderShell(app)
    local shell = _gLoaderShell
    if not shell
    then
        local logic = require("src/shell/logic")
        shell = logic.MPVDanmakuLoaderShell:new()
        _gLoaderShell = shell
    end
    shell:setApplication(app)
    return shell
end


local function __doRunKeyBindingCallback(func)
    local app = __ensureApplication()
    local shell = __ensureLoaderShell(app)
    func(cfg, app, shell)
end

local function __loadDanmakuFromURL()
    local function __func(cfg, app, shell)
        shell:loadDanmakuFromURL(_gOpenedURL)
    end
    __doRunKeyBindingCallback(__func)
end

local function __showMainWindow()
    local function __func(cfg, app, shell)
        shell:showMainWindow()
    end
    __doRunKeyBindingCallback(__func)
end

local function __onRequestDanmaku()
    if _gOpenedFilePath
    then
        __showMainWindow()
    elseif _gOpenedURL
    then
        __loadDanmakuFromURL()
    end
end

local function _updateOptions()
    _gTempOptionTable = _gTempOptionTable or {}
    _gTempOptionTable.loadDanmakuOnURLPlayed = false
    mp.options.read_options(_gTempOptionTable)
end


local function __markOpenedPath()
    _gOpenedURL = nil
    _gOpenedFilePath = nil
    _gIsAppInitialized = false
    _updateOptions()

    local path = mp.get_property("stream-open-filename")
    local isURL = path:match(".*://.*")
    if isURL
    then
        _gOpenedURL = path
        if _gTempOptionTable.loadDanmakuOnURLPlayed
        then
            __loadDanmakuFromURL()
        end
    else
        local isFullPath = path:match("^/.+$")
        local fullPath = isFullPath and path or mp.utils.join_path(mp.utils.getcwd(), path)
        _gOpenedFilePath = fullPath
    end
end

local function __destroy()
    if _gApplication
    then
        _gApplication:dispose()
        _gApplication = nil
    end
    if _gLoaderShell
    then
        _gLoaderShell:dispose()
        _gLoaderShell = nil
    end
end


-- 如果传网址会经过 youtube-dl 分析并重定向，为了拿到最初的网址必须加回调
mp.add_hook("on_load", 5, __markOpenedPath)
mp.add_hook("shutdown", 50, __destroy)
mp.add_key_binding("Alt+D", "load", __onRequestDanmaku)
