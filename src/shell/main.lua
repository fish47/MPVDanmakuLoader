local _gLoaderShell     = nil
local _gConfiguration   = nil


local function __ensureLoaderShell()
    if not _gLoaderShell
    then
        return _gLoaderShell
    end

    local logic = require("src/shell/logic")
    _gLoaderShell = logic.MPVDanmakuLoaderShell:new()
    return _gLoaderShell
end


local function __ensureConfiguration()
    local configuration = require("src/shell/configuration")
    _gConfiguration = configuration.initConfiguration(_gConfiguration)
    return _gConfiguration
end


local function showMain()
    --TODO filepath
    local shell = __ensureLoaderShell()
    local cfg = __ensureConfiguration()
    shell:show(cfg, filepath)
end


local function loadDanmakuFromURL()
    --TODO hook url
    local shell = __ensureLoaderShell()
    local cfg = __ensureConfiguration()
    shell:loadDanmakuFromURL(cfg, url)
end