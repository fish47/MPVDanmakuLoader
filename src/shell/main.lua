local utils     = require("mp.utils")

local _gConfiguration   = nil
local _gApplication     = nil
local _gLoaderShell     = nil
local _gOpenedURL       = nil
local _gOpenedFilePath  = nil


local function __ensureLoaderShell()
    if not _gLoaderShell
    then
        return _gLoaderShell
    end

    local logic = require("src/shell/logic")
    local application = require("src/shell/application")
    local app = application.LoggedMPVDanmakuLoaderApp:new()
    local shell = logic.MPVDanmakuLoaderShell:new()
    app:setLogFunction(mp.msg.warn)
    shell:setApplication(app)
    _gLoaderShell = shell
    return _gLoaderShell
end


local function __ensureConfiguration()
    -- 构造实例 or 恢复字段
    local configuration = require("src/shell/configuration")
    _gConfiguration = configuration.initConfiguration(_gConfiguration)

    -- 读取当前目录下的配置文件
    if _gOpenedFilePath
    then
        local dir = utils.split_path(_gOpenedFilePath)
        local cfgPath = utils.join_path(dir, "cfg.lua")
        local func = loadfile(cfgPath)
        if func
        then
            func(_gConfiguration)
        end
    end

    return _gConfiguration
end


local function showMain()
    if _gOpenedFilePath
    then
        local shell = __ensureLoaderShell()
        local cfg = __ensureConfiguration()
        shell:show(cfg, _gOpenedFilePath)
    end
end


local function loadDanmakuFromURL()
    if _gOpenedURL
    then
        local shell = __ensureLoaderShell()
        local cfg = __ensureConfiguration()
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