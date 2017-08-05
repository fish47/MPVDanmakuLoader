local lu            = require("lib/luaunit")
local testutils     = require("common/testutils")
local danmakupool   = require("src/core/danmakupool")
local acfun         = require("src/plugins/acfun")


TestAcfun =
{
    setUp       = testutils.createSetUpPluginMethod(acfun.AcfunDanmakuSourcePlugin),
    tearDown    = testutils.tearDownPlugin,
}

function TestAcfun:testParse()
    testutils.parseDanmakuData(self, [[
{"c":"27.881,13369344,1,25,16dk1911614176,1397402398,139740239819","m":"金坷垃必须火金坷垃必须火金坷垃必须火金坷垃必须火金坷垃必须火金坷垃必须火"},
{"c":"57.977,16777215,1,25,2dbk3702005386,1397403508,139740350820","m":"比原版好听"},
{"c":"115.979,16777215,1,25,2dbk3702005386,1397403566,139740356621","m":"求番号、。。。。。。"},
{"c":"224.378,16777215,1,25,2dbk3702005386,1397403675,139740367522","m":"原版叫幸运恋爱奇曲。。。"}
]])

    local danmakuData = self._mDanmakuData
    local pools = self._mApplication:getDanmakuPools()
    local pool = pools:getDanmakuPoolByLayer(danmakupool.LAYER_MOVING_R2L)
    pool:getDanmakuByIndex(2, danmakuData)
    lu.assertEquals(pool:getDanmakuCount(), 4)
    lu.assertEquals(danmakuData.danmakuText, "比原版好听")
    lu.assertEquals(danmakuData.startTime, 57977)
    lu.assertEquals(danmakuData.danmakuID, 1397403508)
end


testutils.runTestCases()