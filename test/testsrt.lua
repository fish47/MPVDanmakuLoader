local lu            = require("lib/luaunit")
local testutils     = require("common/testutils")
local danmakupool   = require("src/core/danmakupool")
local srt           = require("src/plugins/srt")


TestParseSRT =
{
    setUp       = testutils.createSetUpPluginMethod(srt.SRTPlugin),
    tearDown    = testutils.tearDownPlugin,
}

function TestParseSRT:_parseSRT(content)
    local app = self._mApplication
    local pools = app:getDanmakuPools()
    local pool = pools:getDanmakuPoolByLayer(danmakupool.LAYER_SUBTITLE)
    pool:clear()

    local f = app:createReadOnlyStringFile(content)
    local danmakuData = self._mDanmakuData
    local sourceID = pools:allocateDanmakuSourceID()
    local ret = srt._parseSRTFile(app:getConfiguration(), pool, f, sourceID, 0, danmakuData)
    pool:freeze()
    app:closeFile(f)
    return ret, pool
end


-- 随手截一段来测
function TestParseSRT:testParseSimple1()
    local ret, pool = self:_parseSRT([[


1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已
一个少女的纪录

2
00:00:19,060 --> 00:00:23,520
人类的大脑里大约有140亿个神经细胞


3
00:00:23,530 --> 00:00:28,690
而控制这些神经细胞的细胞数量则是其10倍


4
00:00:28,700 --> 00:00:33,490
这些细胞分为中枢神经和末稍神经


5
00:00:33,500 --> 00:00:43,220
其中中枢神经分为大脑 间脑 小脑 脑干和脊髓


]])

    lu.assertEquals(pool:getDanmakuCount(), 5)

    local danmakuData = self._mDanmakuData
    pool:getDanmakuByIndex(4, danmakuData)
    lu.assertEquals(danmakuData.startTime, 28700)
    lu.assertEquals(danmakuData.lifeTime, 4790)

    pool:getDanmakuByIndex(5, danmakuData)
    lu.assertEquals(danmakuData.danmakuText, "其中中枢神经分为大脑 间脑 小脑 脑干和脊髓")

    pool:getDanmakuByIndex(1, danmakuData)
    lu.assertEquals(danmakuData.danmakuText, "没有甚么特别的 只是被特别的病魔缠上而已\n一个少女的纪录")

end


-- 直到出现空行前，都算是字幕内容
function TestParseSRT:testParseSimple2()

    local ret, pool = self:_parseSRT([[
1
00:00:00,100 --> 00:00:03,750
00:00:00,100 --> 00:00:03,750
00:00:00,100 --> 00:00:03,750

2
00:00:33,500 --> 00:00:43,220
sdf
]])

    lu.assertTrue(ret)
    lu.assertEquals(pool:getDanmakuCount(), 2)

    local danmakuData = self._mDanmakuData
    pool:getDanmakuByIndex(1, danmakuData)
    lu.assertEquals(danmakuData.danmakuText,
[[00:00:00,100 --> 00:00:03,750
00:00:00,100 --> 00:00:03,750]])
end


-- 简单测一下不对的格式吧
function TestParseSRT:testMalformed()
    local ret, pool = self:_parseSRT([[
1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已


一个少女的纪录
]])
    lu.assertFalse(ret)
    lu.assertEquals(pool:getDanmakuCount(), 1)
end


function TestParseSRT:testBlankFile()
    local ret = self:_parseSRT([[



]])
    lu.assertFalse(ret)
end


function TestParseSRT:testTrailingBlankLines()
    local ret, pool = self:_parseSRT([[


1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已


]])
    lu.assertTrue(ret)
    lu.assertEquals(pool:getDanmakuCount(), 1)
end


testutils.runTestCases()