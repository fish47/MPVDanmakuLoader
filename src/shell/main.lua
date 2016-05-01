local _gConfiguration       = nil
local _gApplication         = nil
local _gLoaderShell         = nil
local _gOpenedURL           = nil
local _gOpenedFilePath      = nil
local _gIsAppInitialized    = false


local function __ensureConfiguration()
    -- 构造实例 or 恢复字段
    local configuration = require("src/shell/configuration")
    local cfg = configuration.initConfiguration(_gConfiguration)

    -- 读取当前目录下的配置文件
    if _gOpenedFilePath
    then
        local dir = mp.utils.split_path(_gOpenedFilePath)
        local cfgPath = mp.utils.join_path(dir, "cfg.lua")
        local func = loadfile(cfgPath)
        if func
        then
            func(cfg)
        end
    end

    _gConfiguration = cfg
    return cfg
end


local function __ensureApplication(cfg)
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

    app:setConfiguration(cfg)
    app:setLogFunction(cfg.showDebugLog and print)
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
    local cfg = __ensureConfiguration()
    local app = __ensureApplication(cfg)
    local shell = __ensureLoaderShell(app)
    local isPausedBefore = mp.get_property_native("pause")
    mp.set_property_native("pause", cfg.pauseWhileShowing and true or isPausedBefore)
    func(cfg, app, shell)
    mp.set_property_native("pause", isPausedBefore)
end


local function showMainWindow()
    local function __func(cfg, app, shell)
        shell:showMainWindow()
    end

    if _gOpenedFilePath
    then
        __doRunKeyBindingCallback(__func)
    end
end


local function loadDanmakuFromURL()
    local function __func(cfg, app, shell)
        shell:loadDanmakuFromURL(_gOpenedURL)
    end

    if _gOpenedURL
    then
        __doRunKeyBindingCallback(__func)
    end
end


local function __markOpenedPath()
    _gOpenedURL = nil
    _gOpenedFilePath = nil
    _gIsAppInitialized = false

    local path = mp.get_property("stream-open-filename")
    local isURL = path:match(".*://.*")
    if isURL
    then
        _gOpenedURL = path
    else
        local isFullPath = path:match("^/.+$")
        local fullPath = isFullPath and path or mp.utils.join_path(mp.utils.getcwd(), path)
        _gOpenedFilePath = fullPath
    end
end


-- 如果传网址会经过 youtube-dl 分析并重定向，为了拿到最初的网址必须加回调
mp.add_hook("on_load", 5, __markOpenedPath)

mp.add_key_binding("1", "show", showMainWindow)
mp.add_key_binding("2", "load", loadDanmakuFromURL)