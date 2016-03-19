local mocks         = require("test/mocks")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local pluginbase    = require("src/plugins/pluginbase")
local bilibili      = require("src/plugins/bilibili")
local acfun         = require("src/plugins/acfun")
local application   = require("src/shell/application")

local cfg = mocks.MockConfiguration:new()
local app = application.MPVDanmakuLoaderApp:new()
local result = pluginbase.DanmakuSourceSearchResult:new()
local plugin = acfun.AcfunDanmakuSourcePlugin:new()
app:init(cfg, "/1.mp4")
plugin:setApplication(app)

local f = io.open("/tmp/1.txt")
local rawData = f:read("*a")
f:close()
plugin:parseData(rawData, "asdf", 0)


local pool = app:getDanmakuPools():getDanmakuPoolByLayer(1)
for i = 1, pool:getDanmakuCount()
do
    local _, _, _, _, _, _, text = pool:getDanmakuByIndex(i)
    print(text)
end