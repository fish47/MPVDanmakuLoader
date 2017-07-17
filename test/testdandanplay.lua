local lu                = require("lib/luaunit")
local testpluginbase    = require("common/testpluginbase")
local danmakupool       = require("src/core/danmakupool")
local dandanplay        = require("src/plugins/dandanplay")


TestParseDanDanPlay =
{
    setUp       = testpluginbase.createSetUp(dandanplay.DanDanPlayDanmakuSourcePlugin),
    tearDown    = testpluginbase.tearDown,
}

function TestParseDanDanPlay:testParse()
    testpluginbase.parseData(self, [[
<Comment Time="191.38" Mode="1" Color="16777215" Timestamp="1415593473" Pool="0" UId="-1" CId="1415593473">死枪果然基佬</Comment>
<Comment Time="450.07" Mode="1" Color="16777215" Timestamp="1414926576" Pool="0" UId="-1" CId="1414926576">字幕组你又调皮了</Comment>
<Comment Time="949.49" Mode="1" Color="16707842" Timestamp="1415960581" Pool="0" UId="-1" CId="1415960581">yooooooooooo</Comment>
<Comment Time="1389.98" Mode="1" Color="16777215" Timestamp="1414916794" Pool="0" UId="-1" CId="1414916794">马云姨妈：怪我咯？</Comment>
]])

    local danmakuData = self._mDanmakuData
    local pools = self._mApplication:getDanmakuPools()
    local pool = pools:getDanmakuPoolByLayer(danmakupool.LAYER_MOVING_R2L)
    pool:getDanmakuByIndex(3, danmakuData)
    lu.assertEquals(pool:getDanmakuCount(), 4)
    lu.assertEquals(danmakuData.danmakuText, "yooooooooooo")
    lu.assertEquals(danmakuData.startTime, 949490)
    lu.assertEquals(danmakuData.fontColor, 16707842)
    lu.assertEquals(danmakuData.danmakuID, 1415960581)
end

function TestParseDanDanPlay:testSearch()
    local result = self._mSearchResult()
end


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())