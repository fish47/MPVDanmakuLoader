local constants     = require("src/base/constants")
local utils         = require("src/base/utils")
local danmaku       = require("src/core/danmaku")
local danmakupool   = require("src/core/danmakupool")
local srt           = require("src/plugins/srt")
local acfun         = require("src/plugins/acfun")
local bilibili      = require("src/plugins/bilibili")
local dandanplay    = require("src/plugins/dandanplay")
local lu            = require("test/luaunit")
local mocks         = require("test/mocks")


local function __createSetUpMethod(pluginClz)
    local ret = function(self)
        local app = mocks.MockApplication:new()
        app:updateConfiguration()
        self._mApplication = app
        self._mConfiguration = app:getConfiguration()
        self._mDanmakuData = danmaku.DanmakuData:new()

        if pluginClz
        then
            local plugin = pluginClz:new()
            app:_addDanmakuSourcePlugin(plugin)
            self._mPlugin = plugin
        end
    end
    return ret
end


local function _tearDown(self)
    utils.disposeSafely(self._mApplication)
    utils.disposeSafely(self._mConfiguration)
    utils.disposeSafely(self._mPlugin)
    utils.disposeSafely(self._mDanmakuData)
    self._mApplication = nil
    self._mConfiguration = nil
    self._mPlugin = nil
    self._mDanmakuData = nil
end


local function _parseData(self, text)
    local app = self._mApplication
    local pools = app:getDanmakuPools()
    local sourceID = pools:allocateDanmakuSourceID()
    self._mPlugin:parseData(text, sourceID, 0)
    for _, pool in pools:iteratePools()
    do
        pool:freeze()
    end
end




TestParse =
{
    setUp = __createSetUpMethod(),
    tearDown = _tearDown,

    _parseSRT = function(self, content)
        local f = io.tmpfile()
        f:write(content)
        f:flush()
        f:seek(constants.SEEK_MODE_BEGIN, 0)

        local app = self._mApplication
        local pools = app:getDanmakuPools()
        local pool = pools:getDanmakuPoolByLayer(danmakupool.LAYER_SUBTITLE)
        pool:clear()

        local danmakuData = self._mDanmakuData
        local sourceID = pools:allocateDanmakuSourceID()
        local ret = srt._parseSRTFile(app:getConfiguration(), pool, f, sourceID, 0, danmakuData)
        pool:freeze()
        f:close()
        return ret, pool
    end,


    -- 随手截一段来测
    testParseSimple1 = function(self)
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

    end,


    -- 直到出现空行前，都算是字幕内容
    testParseSimple2 = function(self)

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
    end,


    -- 简单测一下不对的格式吧
    testMalformed = function(self)
        local ret, pool = self:_parseSRT([[
1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已


一个少女的纪录
]])
        lu.assertFalse(ret)
        lu.assertEquals(pool:getDanmakuCount(), 1)
    end,


    testBlankFile = function(self)
        local ret = self:_parseSRT([[



]])
        lu.assertFalse(ret)
    end,


    testTrailingBlankLines = function(self)
        local ret, pool = self:_parseSRT([[


1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已


]])
        lu.assertTrue(ret)
        lu.assertEquals(pool:getDanmakuCount(), 1)
    end,
}



TestParseBiliBili =
{
    setUp = __createSetUpMethod(bilibili.BiliBiliDanmakuSourcePlugin),
    tearDown = _tearDown,

    testParse = function(self)
        _parseData(self, [[
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
    end,
}


TestParseAcfun =
{
    setUp = __createSetUpMethod(acfun.AcfunDanmakuSourcePlugin),
    tearDown = _tearDown,

    testParse = function(self)
        _parseData(self, [[
{"c":"27.881,13369344,1,25,16dk1911614176,1397402398,139740239819","m":"金坷垃必须火金坷垃必须火金坷垃必须火金坷垃必须火金坷垃必须火金坷垃必须火"},
{"c":"57.977,16777215,1,25,2dbk3702005386,1397403508,139740350820","m":"比原版好听"},
{"c":"115.979,16777215,1,25,2dbk3702005386,1397403566,139740356621","m":"求番号、。。。。。。"},
{"c":"224.378,16777215,1,25,2dbk3702005386,1397403675,139740367522","m":"原版叫幸运恋爱奇曲。。。"}
]])

        local danmakuData = self._mDanmakuData
        local pool = self._mApplication:getDanmakuPools():getDanmakuPoolByLayer(danmakupool.LAYER_MOVING_R2L)
        pool:getDanmakuByIndex(2, danmakuData)
        lu.assertEquals(pool:getDanmakuCount(), 4)
        lu.assertEquals(danmakuData.danmakuText, "比原版好听")
        lu.assertEquals(danmakuData.startTime, 57977)
        lu.assertEquals(danmakuData.danmakuID, 1397403508)
    end,
}


TestParseDanDanPlay =
{
    setUp = __createSetUpMethod(dandanplay.DanDanPlayDanmakuSourcePlugin),
    tearDown = _tearDown,

    testParse = function(self)
        _parseData(self, [[
<Comment Time="191.38" Mode="1" Color="16777215" Timestamp="1415593473" Pool="0" UId="-1" CId="1415593473">死枪果然基佬</Comment>
<Comment Time="450.07" Mode="1" Color="16777215" Timestamp="1414926576" Pool="0" UId="-1" CId="1414926576">字幕组你又调皮了</Comment>
<Comment Time="949.49" Mode="1" Color="16707842" Timestamp="1415960581" Pool="0" UId="-1" CId="1415960581">yooooooooooo</Comment>
<Comment Time="1389.98" Mode="1" Color="16777215" Timestamp="1414916794" Pool="0" UId="-1" CId="1414916794">马云姨妈：怪我咯？</Comment>
]])

        local danmakuData = self._mDanmakuData
        local pool = self._mApplication:getDanmakuPools():getDanmakuPoolByLayer(danmakupool.LAYER_MOVING_R2L)
        pool:getDanmakuByIndex(3, danmakuData)
        lu.assertEquals(pool:getDanmakuCount(), 4)
        lu.assertEquals(danmakuData.danmakuText, "yooooooooooo")
        lu.assertEquals(danmakuData.startTime, 949490)
        lu.assertEquals(danmakuData.fontColor, 16707842)
        lu.assertEquals(danmakuData.danmakuID, 1415960581)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())