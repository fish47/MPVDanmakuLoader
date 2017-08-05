local lu            = require("lib/luaunit")
local testutils     = require("common/testutils")
local classlite     = require("src/base/classlite")
local danmakupool   = require("src/core/danmakupool")
local dandanplay    = require("src/plugins/dandanplay")


local _PluginImpl = {}

function _PluginImpl:_captureSearchKeyword(input)
    return input
end

classlite.declareClass(_PluginImpl, dandanplay.DanDanPlayDanmakuSourcePlugin)


TestDanDanPlay =
{
    setUp       = testutils.createSetUpPluginMethod(_PluginImpl),
    tearDown    = testutils.tearDownPlugin,
}

function TestDanDanPlay:testParse()
    testutils.parseDanmakuData(self, [[
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


function TestDanDanPlay:testSearch()
    local result = self._mSearchResult
    local conn = self._mApplication:getNetworkConnection()
    local keyword = "刀剑神域"
    local plugin = self._mPlugin
    local searchURL = plugin:_getKeywordSearchURL(keyword)
    conn:setResponse(searchURL, [[
<SearchResult HasMore="false">
    <Anime Title="刀剑神域II" Type="1">
        <Episode Id="103760001" Title="第1话 銃の世界"/>
        <Episode Id="103760002" Title="第2话 氷の狙撃手"/>
        <Episode Id="103760003" Title="第3话 鮮血の記憶"/>
        ...
    </Anime>
    <Anime Title="刀剑神域 序列之争" Type="4">
        <Episode Id="116810001" Title="剧场版"/>
    </Anime>
    <Anime Title="刀剑神域" Type="1">
        <Episode Id="86920001" Title="第1话 剣の世界"/>
        <Episode Id="86920002" Title="第2话 ビーター"/>
        <Episode Id="86920003" Title="第3话 赤鼻のトナカイ"/>
        ...
    </Anime>
</SearchResult>
    ]])
    lu.assertTrue(plugin:search(keyword, result))
    lu.assertFalse(result.isSplited)
    lu.assertEquals(result.videoTitleColumnCount, 2)
    lu.assertEquals(result.videoIDs,
    {
        "103760001", "103760002", "103760003",
        "116810001",
        "86920001", "86920002", "86920003"
    })
    lu.assertEquals(result.videoTitles,
    {
        "刀剑神域II",          "第1话 銃の世界",
        "刀剑神域II",          "第2话 氷の狙撃手",
        "刀剑神域II",          "第3话 鮮血の記憶",
        "刀剑神域 序列之争",    "剧场版",
        "刀剑神域",            "第1话 剣の世界",
        "刀剑神域",            "第2话 ビーター",
        "刀剑神域",            "第3话 赤鼻のトナカイ",
    })
end


testutils.runTestCases()