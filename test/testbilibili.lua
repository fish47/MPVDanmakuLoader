local lu            = require("lib/luaunit")
local testutils     = require("common/testutils")
local danmakupool   = require("src/core/danmakupool")
local bilibili      = require("src/plugins/bilibili")


TestParseBiliBili =
{
    setUp       = testutils.createSetUpPluginMethod(bilibili.BiliBiliPlugin),
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

function TestParseBiliBili:testSearch1P()
end

function TestParseBiliBili:testSearchNP()
    local avID = "123"
    local result = self._mSearchResult
    local plugin = self._mPlugin
    local conn = self._mApplication:getNetworkConnection()
end

function TestParseBiliBili:testSearch()
    -- Bangumi
    local bangumiID = "123"
    local result = self._mSearchResult
    local plugin = self._mPlugin
    local conn = self._mApplication:getNetworkConnection()
    conn:setResponse(plugin:_getBangumiInfoURL(bangumiID), [[
{
    // http://bangumi.bilibili.com/web_api/episode/65171.json
    ...
    "danmaku" : "16635884",
    "longTitle" : "真天使小凌濑不可能降临于一个人住的我家",
    ...
}
    ]])
    local ret = plugin:_searchBangumi(result, bangumiID)
    lu.assertEquals(ret, 1)
    lu.assertEquals(result.videoIDs, { "16635884" })
    lu.assertEquals(result.videoTitles, { "真天使小凌濑不可能降临于一个人住的我家" })


    -- NP
    for i = 1, 5
    do
        local avID = "1234"
        conn:setResponse(plugin:_getVideoPageURL(avID, idx), [[
// http://www.bilibili.com/video/av3270297
...
<option value='/video/av3270297/index_1.html' cid='5162446'>1、P1</option>
<option value='/video/av3270297/index_2.html' cid='5162447'>2、P2</option>
<option value='/video/av3270297/index_3.html' cid='5162448'>3、P3</option>
<option value='/video/av3270297/index_4.html' cid='5162449'>4、P4</option>
<option value='/video/av3270297/index_5.html' cid='5162450'>5、P5</option>
...
        ]])
        result:reset()
        ret = plugin:_searchAV(result, avID, idx)
        lu.assertEquals(ret, idx)
        lu.assertEquals(result.videoTitles, { "P1", "P2", "P3", "P4", "P5" })
        lu.assertEquals(result.videoIDs, {
            "5162446",
            "5162447",
            "5162448",
            "5162449",
            "5162450",
        })
    end


    -- 1P
    local avID = "1234"
    conn:setResponse(plugin:_getVideoPageURL(avID, 1), [[
// https://www.bilibili.com/video/av2271112
...
<h1 title="【循环向】跟着雷总摇起来！Are you OK！">...</h1>
...
EmbedPlayer('player', "//static.hdslb.com/play.swf", "cid=3540266&aid=2271112&pre_ad=0")
...
    ]])
    result:reset()
    ret = plugin:_searchAV(result, avID, 1)
    lu.assertEquals(ret, 1)
    lu.assertEquals(result.videoIDs, { "3540266" })
    lu.assertEquals(result.videoTitles, { "【循环向】跟着雷总摇起来！Are you OK！" })
end

testutils.runTestCases()