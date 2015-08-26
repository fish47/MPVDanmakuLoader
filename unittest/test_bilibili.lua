local lu = require('3rdparties/luaunit')    --= luaunit lu
local utils = require('src/utils')          --= utils utils
local network = require('src/network')


local MockCURLNetworkConnection =
{
    _mResponseFileMap = nil,


    new = function(obj, fileMap)
        obj = network.CURLNetworkConnection.new(obj, "")
        obj = utils.allocateInstance(obj)
        obj._mResponseFileMap = fileMap
        return obj
    end,

    _doGetResponseFile = function(self, url)
        -- B站的网页都是压缩过的
        local filePath = self._mResponseFileMap[url]
        lu.assertTrue(self._mCompressed)
        lu.assertNotNil(filePath)
        return io.open(filePath)
    end,

    dispose = function(self)
        network.CURLNetworkConnection.dispose(self)
        self._mResponseFileMap = nil
    end,
}

utils.declareClass(MockCURLNetworkConnection, network.CURLNetworkConnection)



local __FILEMAP_SINGLE_P =
{
    ["http://www.bilibili.com/video/av1208727/"]                            = "unittest/_test_bilibili/single_p/av1208727/av1208727.html",
    ["http://interface.bilibili.com/player?id=cid:1805894&aid=1208727"]     = "unittest/_test_bilibili/single_p/av1208727/av1208727_intf.xml",
}


local __FILEMAP_MULTI_P =
{
    ["http://www.bilibili.com/video/av2184220/"]                            = "unittest/_test_bilibili/multi_p/av2184220/av2184220.html",
    ["http://www.bilibili.com/video/av2184220/index_1.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_1.html",
    ["http://www.bilibili.com/video/av2184220/index_2.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_2.html",
    ["http://www.bilibili.com/video/av2184220/index_3.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_3.html",
    ["http://www.bilibili.com/video/av2184220/index_4.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_4.html",
    ["http://www.bilibili.com/video/av2184220/index_5.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_5.html",
    ["http://www.bilibili.com/video/av2184220/index_6.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_6.html",
    ["http://www.bilibili.com/video/av2184220/index_7.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_7.html",
    ["http://www.bilibili.com/video/av2184220/index_8.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_8.html",
    ["http://www.bilibili.com/video/av2184220/index_9.html"]                = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_9.html",
    ["http://www.bilibili.com/video/av2184220/index_10.html"]               = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_10.html",
    ["http://www.bilibili.com/video/av2184220/index_11.html"]               = "unittest/_test_bilibili/multi_p/av2184220/av2184220_index_11.html",
    ["http://interface.bilibili.com/player?id=cid:3393018&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_1.xml",
    ["http://interface.bilibili.com/player?id=cid:3393019&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_2.xml",
    ["http://interface.bilibili.com/player?id=cid:3393020&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_3.xml",
    ["http://interface.bilibili.com/player?id=cid:3391808&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_4.xml",
    ["http://interface.bilibili.com/player?id=cid:3391809&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_5.xml",
    ["http://interface.bilibili.com/player?id=cid:3391810&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_6.xml",
    ["http://interface.bilibili.com/player?id=cid:3391811&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_7.xml",
    ["http://interface.bilibili.com/player?id=cid:3391812&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_8.xml",
    ["http://interface.bilibili.com/player?id=cid:3391813&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_9.xml",
    ["http://interface.bilibili.com/player?id=cid:3391814&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_10.xml",
    ["http://interface.bilibili.com/player?id=cid:3433820&aid=2184220"]     = "unittest/_test_bilibili/multi_p/av2184220/av2184220_intf_11.xml",
}


local __FILEMAP_SEARCH =
{
    ["http://www.bilibili.com/search?keyword=rising%20hope"]                                                                        = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=2"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=3"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=4"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=5"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=6"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=7"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=8"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
    ["http://www.bilibili.com/search?keyword=rising+hope&tids=&orderby=&type=video&arctype=all&seid=14215275947755465484&page=9"]   = "unittest/_test_bilibili/search/rising_hope/1.html",
}



TestGetVideoInfos =
{
    test_av1208727 = function()
        local conn = MockCURLNetworkConnection:new(__FILEMAP_SINGLE_P)
        local results = network.getBiliBiliVideoInfos(conn, "1208727")
        lu.assertEquals(#results, 1)
        lu.assertEquals(results[1].subtitle, nil)
        lu.assertEquals(results[1].duration, 256000)
    end,


    test_av2184220 = function()
        local conn = MockCURLNetworkConnection:new(__FILEMAP_MULTI_P)
        local results = network.getBiliBiliVideoInfos(conn, "2184220")
        conn:dispose()

        local function __assertEachFields(arr, assertArray, fieldName)
            local ret = {}
            for i, val in ipairs(arr)
            do
                lu.assertEquals(assertArray[i], val[fieldName])
            end
            return ret
        end


        local assertSubtitles =
        {
            "1、01 いじめられっこ転校生を人気者に",
            "2、02 （秘）キレイ大作戦",
            "3、03 恐怖の文化祭",
            "4、04 恋の告白作戦",
            "5、05 悪梦のデート",
            "6、06 亲と子の青春",
            "7、07 女を泣かす男",
            "8、08 いじめの正体",
            "9、09 别れても友达",
            "10、10 青春アミーゴ",
            "11、【1024X576】完整版01【解决字幕不对问题】",
        }
        __assertEachFields(results, assertSubtitles, "subtitle")


        local assertDurations =
        {
            25958000,
            25958000,
            25958000,
            25958000,
            25958000,
            25958000,
            25958000,
            25958000,
            25958000,
            25958000,
            25958000,
        }
        __assertEachFields(results, assertDurations, "duration")
    end,
}


TestSearch =
{
    test_search_rising_hope = function()
        local conn = MockCURLNetworkConnection:new(__FILEMAP_SEARCH)
        local results = network.searchBiliBiliByKeyword(conn, "rising hope", 9)
        lu.assertEquals(#results, 180)
        lu.assertEquals(results[12].videoID, "1208727")
        lu.assertEquals(results[12].videoType, "翻唱")
        lu.assertEquals(results[12].videoTitle, "【8人合唱】「Rising Hope」【魔法科高校的劣等生OP】")
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())