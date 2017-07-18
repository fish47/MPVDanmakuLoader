local lu            = require("lib/luaunit")
local testutils     = require("common/testutils")
local danmakupool   = require("src/core/danmakupool")
local bilibili      = require("src/plugins/bilibili")


TestParseBiliBili =
{
    setUp       = testutils.createSetUpPluginMethod(bilibili.BiliBiliDanmakuSourcePlugin),
    tearDown    = testutils.tearDownPlugin,
}


function TestParseBiliBili:testParse()
    testutils.parseDanmakuData(self, [[
<d p="46.465000152588,5,25,15772458,1443071599,0,3f6f67dc,1228539049">一天不听全身难受</d>
<d p="98.81600189209,5,25,43981,1442841820,0,b866acaf,1224694747">不好听，一天也就听679次</d>


<d p="6.4949998855591,1,25,16777062,1443231265,0,c0eb9e07,1231674903">姐拿着小米4i看着这段。。。。</d>
<d p="22.941999435425,1,25,16777215,1443228647,0,e59f5789,1231616667">up有毒，各种自动循环</d>
<d p="23.441999435425,1,25,16777215,1443229745,0,62b26620,1231639931">我擦自动循环？</d>
<d p="36.86600112915,1,25,16777215,1443229882,0,62b26620,1231642831">擦我说怎么听那么久</d>
]])
    local danmakuData = self._mDanmakuData
    local pools = self._mApplication:getDanmakuPools()
    local pool1 = pools:getDanmakuPoolByLayer(danmakupool.LAYER_MOVING_R2L)
    lu.assertEquals(pool1:getDanmakuCount(), 4)

    pool1:getDanmakuByIndex(1, danmakuData)
    lu.assertEquals(danmakuData.danmakuText, "姐拿着小米4i看着这段。。。。")
    lu.assertEquals(danmakuData.startTime, 6494.9998855591)

    pool1:getDanmakuByIndex(4, danmakuData)
    lu.assertEquals(danmakuData.danmakuText, "擦我说怎么听那么久")
    lu.assertEquals(danmakuData.fontColor, 16777215)
    lu.assertEquals(danmakuData.danmakuID, 1231642831)

    local pool2 = pools:getDanmakuPoolByLayer(danmakupool.LAYER_STATIC_TOP)
    pool2:getDanmakuByIndex(1, danmakuData)
    lu.assertEquals(pool2:getDanmakuCount(), 2)
    lu.assertEquals(danmakuData.fontColor, 15772458)
end


testutils.runTestCases()