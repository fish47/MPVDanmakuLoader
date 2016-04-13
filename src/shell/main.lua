local _gConfiguration   = nil
local _gApplication     = nil
local _gLoaderShell     = nil
local _gOpenedURL       = nil
local _gOpenedFilePath  = nil


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


local function __ensureApplication()
    local app = _gApplication
    if not app
    then
        local application = require("src/shell/application")
        app = application.MPVDanmakuLoaderApp:new()
        _gApplication = app
    end
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


local function showMain()
    if _gOpenedFilePath
    then
        local cfg = __ensureConfiguration()
        local app = __ensureApplication()
        local shell = __ensureLoaderShell(app)
        local isPausedBefore = mp.get_property_native("pause")
        mp.set_property_native("pause", cfg.pauseVideoWhileShowing and true or isPausedBefore)
        app:setLogFunction(cfg.showDebugLog and print)
        shell:show(cfg, _gOpenedFilePath)
        mp.set_property_native("pause", isPausedBefore)
    end
end


local function loadDanmakuFromURL()
    if _gOpenedURL
    then
        local cfg = __ensureConfiguration()
        local app = __ensureApplication()
        local shell = __ensureLoaderShell(app)
        shell:loadDanmakuFromURL(cfg, _gOpenedURL)
    end
end


local function __markOpenedPath()
    local path = mp.get_property("stream-open-filename")
    local isURL = path:match(".*://.*")
    _gOpenedURL = isURL and path
    _gOpenedFilePath = not isURL and path
end


-- 如果传网址会经过 youtube-dl 分析并重定向，为了拿到最初的网址必须加回调
mp.add_hook("on_load", 5, __markOpenedPath)

mp.add_key_binding("1", "show", showMain)
mp.add_key_binding("2", "load", loadDanmakuFromURL)