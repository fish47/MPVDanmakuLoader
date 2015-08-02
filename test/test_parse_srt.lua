local lu = require('3rdparties/luaunit')    --= luaunit lu
local parse = require('src/parse')          --= parse parse
local asswriter = require('src/asswriter')  --= asswriter asswriter


TestParseSRTFile =
{
    __doParse = function(self, content)
        local f = io.tmpfile()
        f:write(content)
        f:flush()
        f:seek("set", 0)

        local ctx = parse.DanmakuParseContext:new()
        local ret = parse.parseSRTFile(f, ctx)
        local pool = ctx.pool[asswriter.LAYER_SUBTITLE]

        f:close()
        return ret, pool
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

        lu.assertEquals(#pool, 5)
        lu.assertEquals(pool[4].startTime, 28700)
        lu.assertEquals(pool[4].lifeTime, 4790)
        lu.assertEquals(pool[5].text, "其中中枢神经分为大脑 间脑 小脑 脑干和脊髓")
        lu.assertEquals(pool[1].text,
[[没有甚么特别的 只是被特别的病魔缠上而已
一个少女的纪录]])

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
        lu.assertEquals(#pool, 2)
        lu.assertEquals(pool[1].text,
[[00:00:00,100 --> 00:00:03,750
00:00:00,100 --> 00:00:03,750]])
    end,


    -- 简单测一下格式不对吧
    test_malformed = function(self)
        local ret, pool = self:__doParse([[
1
00:00:00,100 --> 00:00:03,750
没有甚么特别的 只是被特别的病魔缠上而已


一个少女的纪录
]])
        lu.assertFalse(ret)
        lu.assertEquals(#pool, 1)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())