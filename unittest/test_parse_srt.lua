local lu        = require("3rdparties/luaunit")    --= luaunit lu
local _ass      = require("src/core/_ass")
local srt       = require("src/core/srt")
local danmaku   = require("src/core/danmaku")
local utils     = require("src/base/utils")
local app       = require("src/shell/app")


TestParseSRTFile =
{
    __mPools    = nil,
    __mCfg      = nil,

    setUp = function(self)
        self.__mCfg = app.MPVDanmakuLoaderCfg:new()
        self.__mPools = {}
    end,


    tearDown = function(self)
        for i, pools in ipairs(self.__mPools)
        do
            pools:dispose()
            self.__mPools[i] = nil
        end
        self.__mPools = nil

        self.__mCfg:dispose()
        self.__mCfg = nil
    end,


    __doParse = function(self, content)
        local f = io.tmpfile()
        f:write(content)
        f:flush()
        f:seek("set", 0)

        local pool = danmaku.DanmakuPool:new()
        local ret = srt.parseSRTFile(self.__mCfg, pool, f, "foo")

        f:close()
        pool:sortDanmakusByStartTime()
        table.insert(self.__mPools, pool)
        return ret, pool
    end,


    __doGetDanmakuText = function(self, pool, idx)
        local _, _, _, _, _, text = pool:getSortedDanmakuAt(idx)
        return text
    end,


    -- 随手截一段来测
    test_parse_simple1 = function(self)
        local ret, pool = self:__doParse([[


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

        local startTime4, lifeTime4 = pool:getSortedDanmakuAt(4)
        lu.assertEquals(startTime4, 28700)
        lu.assertEquals(lifeTime4, 4790)

        local text5 = self:__doGetDanmakuText(pool, 5)
        lu.assertEquals(text5, "其中中枢神经分为大脑 间脑 小脑 脑干和脊髓")

        local text1 = self:__doGetDanmakuText(pool, 1)
        lu.assertEquals(text1, "没有甚么特别的 只是被特别的病魔缠上而已\n一个少女的纪录")

    end,


    -- 直到出现空行前，都算是字幕内容
    test_parse_simple2 = function(self)

        local ret, pool = self:__doParse([[
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

        local text1 = self:__doGetDanmakuText(pool, 1)
        lu.assertEquals(text1,
[[00:00:00,100 --> 00:00:03,750
00:00:00,100 --> 00:00:03,750]])
    end,


    -- 简单测一下不对的格式吧
    test_malformed = function(self)
        local ret, pool = self:__doParse([[
1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已


一个少女的纪录
]])
        lu.assertFalse(ret)
        lu.assertEquals(pool:getDanmakuCount(), 1)
    end,


    test_blank_file = function(self)
        local ret = self:__doParse([[



]])
        lu.assertFalse(ret)
    end,


    test_trailing_blank_lines = function(self)
        local ret, pool = self:__doParse([[


1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已


]])
        lu.assertTrue(ret)
        lu.assertEquals(pool:getDanmakuCount(), 1)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())