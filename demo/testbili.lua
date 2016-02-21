local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local pluginbase    = require("src/plugins/pluginbase")
local bilibili      = require("src/plugins/bilibili")
local application   = require("src/shell/application")

local app = application.MPVDanmakuLoaderApp:new()
local result = pluginbase.DanmakuSourceSearchResult:new()
local plugin = bilibili.BiliBiliDanmakuSourcePlugin:new()
plugin:setApplication(app)

--local succeed = plugin:search("http://www.bilibili.com/video/av2184220/index_2.html", result)
--print(succeed)
--for i, vid in ipairs(result.videoIDs)
--do
--    print(string.format("%-10s --> %s", vid, result.videoTitles[i]))
--end
--print(result.preferredIDIndex)

local out = {}
plugin:downloadRawDatas({3433820}, out)
local f = io.open("/tmp/1.txt", "w")
f:write(out[1])
f:close()