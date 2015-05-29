local lu        = require("test/luaunit")
local types     = require("src/base/types")
local utils     = require("src/base/utils")
local _poscalc  = require("src/core/_poscalc")

TestMovingArea =
{
    __doInitDanmakuArea = function(self, a, start, speed, width)
        a.start = start
        a.speed = speed
        a.width = width
    end,


    testDuration = function(self)
        local function __doAssertDuration(a1, a2, screenWidth, duration)
            local ret = a1:getCollidingDuration(a2, screenWidth)
            lu.assertEquals(ret, a2:getCollidingDuration(a1, screenWidth))
            lu.assertEquals(ret, duration)
        end

        local a1 = _poscalc.__DanmakuArea:new()
        local a2 = _poscalc.__DanmakuArea:new()

        -- 不相交而且追不上
        self:__doInitDanmakuArea(a1, 0, 10, 100)
        self:__doInitDanmakuArea(a2, 100, 5, 100)
        __doAssertDuration(a1, a2, 100000000, 0)

        -- 接近右边界，但因为速度相同，所以也追不上
        self:__doInitDanmakuArea(a1, 0, 10, 100)
        self:__doInitDanmakuArea(a2, 10.0001, 10, 100)
        __doAssertDuration(a1, a2, 100000000, 0)

        -- 后来刚出现，前者刚消失
        self:__doInitDanmakuArea(a1, 0, 10, 100)
        self:__doInitDanmakuArea(a2, 20, 20, 100)
        __doAssertDuration(a1, a2, 100, 0)

        -- 如果一开始就相交，存活时间影响碰撞时间
        self:__doInitDanmakuArea(a1, 0, 10, 100)
        self:__doInitDanmakuArea(a2, 9, 10, 100)
        __doAssertDuration(a1, a2, 100, 11)

        -- 速度为极值，暂认为完全不相交
        self:__doInitDanmakuArea(a1, 0, 10, 100)
        self:__doInitDanmakuArea(a2, 0, math.huge, 100)
        __doAssertDuration(a1, a2, 100, 0)

        -- 出现较早且速度较快，而且部分相交
        self:__doInitDanmakuArea(a1, 0, 10, 100)
        self:__doInitDanmakuArea(a2, 1, 5, 20)
        __doAssertDuration(a1, a2, 10000, 18)

        -- 出现较早且速度较快，而且与后来者不相交，也就不碰撞了
        self:__doInitDanmakuArea(a1, 0, 10, 10)
        self:__doInitDanmakuArea(a2, 1, 5, 20)
        __doAssertDuration(a1, a2, 1000, 0)


        -- a2 需要用 10 单位时间才追上 a1 ，接触后在 20 单位时间后才分离
        self:__doInitDanmakuArea(a1, 0, 10, 100)
        self:__doInitDanmakuArea(a2, 20, 20, 100)
        for i = 0, 10
        do
            local screenWidth = 200 + i * 10
            __doAssertDuration(a1, a2, screenWidth, i)
        end

        -- 在这个区间 a2 反而会先消失，注意消失后不算碰撞
        for i = 10, 20
        do
            local screenWidth = 300 + i * 10
            __doAssertDuration(a1, a2, screenWidth, 10 + i / 2)
        end

        __doAssertDuration(a1, a2, 10000, 20)
    end,
}


TestIntersectedHeight =
{
    testMain = function()
        local function __doAssert(top1, bottom1, top2, bottom2, heights)
            local h1, h2, h3 = _poscalc.__getIntersectedHeight(top1, bottom1, top2, bottom2)
            lu.assertEquals(h1, heights[1])
            lu.assertEquals(h2, heights[2])
            lu.assertEquals(h3, heights[3])
        end

        __doAssert(0, 10, -10, -5, {5, 0, 0})
        __doAssert(0, 10, -10, 20, {10, 10, 10})
        __doAssert(0, 10, -10, 5, {10, 5, 0})
        __doAssert(0, 10, 12, 14, {0, 0, 2})
        __doAssert(0, 10, 5, 14, {0, 5, 4})
        __doAssert(0, 10, 0, 10, {0, 10, 0})
        __doAssert(0, 10, 5, 6, {0, 1, 0})
        __doAssert(0, 10, 5, 12, {0, 5, 2})
        __doAssert(0, 10, 15, 16, {0, 0, 1})
    end,
}


TestPosCalculator =
{
    __doInitAreaHeights = function(self, calc, heights)
        local area = calc._mDanmakuAreas
        local heightSum = 0
        for i, h in ipairs(heights)
        do
            local newArea = (i == 1) and area or _poscalc.__DanmakuArea:new()
            newArea.height = h
            area._next = newArea
            newArea._next = nil

            area = newArea
            heightSum = heightSum + h
        end

        calc._mScreenHeight = heightSum
    end,


    __sumHeights = function(self, heights)
        local sum = 0
        for i, height in ipairs(heights)
        do
            sum = sum + height
        end
        return sum
    end,


    testAddArea = function(self)
        local function __doAddArea(calc, top, bottom)
            -- 只为防止被相容才做些奇怪数据而已
            local newArea = _poscalc.__DanmakuArea:new()
            newArea.speed = 1234
            newArea.width = 4321
            newArea.start = 5555
            newArea.height = bottom - top
            calc:__addDanmakuArea(calc._mDanmakuAreas, 0, newArea, top)
        end

        local function __doAssertAreaHeights(calc, heights)
            local area = calc._mDanmakuAreas
            local calcHeightList = {}
            while area
            do
                table.insert(calcHeightList, area.height)
                area = area._next
            end
            lu.assertEquals(heights, calcHeightList)
            utils.clearTable(calcHeightList)
        end

        local function __doTest(heights, areaBounds, assertHeights)
            local addTop, addBottom = table.unpack(areaBounds)
            local calc = _poscalc.MovingPosCalculator:new()
            calc:init(1, self:__sumHeights(heights))
            self:__doInitAreaHeights(calc, heights)
            __doAddArea(calc, addTop, addBottom)
            __doAssertAreaHeights(calc, assertHeights)
            calc:dispose()
        end

        __doTest({1, 2, 3, 4}, {3, 10}, {1, 2, 3, 4})
        __doTest({5, 10, 3, 4}, {4, 16}, {4, 1, 10, 1, 2, 4})
        __doTest({10, 5, 5, 10}, {0, 4}, {4, 6, 5, 5, 10})
        __doTest({10, 100, 10}, {20, 30}, {10, 10, 10, 80, 10})
        __doTest({1, 1, 1, 1, 1, 1}, {0, 6}, {1, 1, 1, 1, 1, 1})
    end,


    testScoreSum = function(self)
        local function __doTest(heights, areaBounds, assertAreaIndexes)
            local calc = _poscalc.MovingPosCalculator:new()
            calc:init(1, self:__sumHeights(heights))
            self:__doInitAreaHeights(calc, heights)

            -- 编号
            local idx = 1
            local areaIndexes = {}
            local iterArea = calc._mDanmakuAreas
            while iterArea
            do
                areaIndexes[iterArea] = idx
                idx = idx + 1
                iterArea = iterArea._next
            end

            local sumedAreaIndexes = {}
            calc._doGetCollisionScore = function(self, a1, a2)
                table.insert(sumedAreaIndexes, areaIndexes[a1])
                return 0
            end

            local newArea = _poscalc.__DanmakuArea:new()
            local newAreaTop, newAreaBottom = table.unpack(areaBounds)
            newArea.height = newAreaBottom - newAreaTop
            calc:__getCollisionScoreSum(0, calc._mDanmakuAreas, newAreaTop, newArea)

            lu.assertEquals(sumedAreaIndexes, assertAreaIndexes)

            utils.clearTable(sumedAreaIndexes)
            utils.clearTable(assertAreaIndexes)
            utils.clearTable(areaIndexes)
            calc:dispose()
        end

        __doTest({10, 5, 4, 5}, {5, 6}, {1})
        __doTest({10, 5, 4, 5}, {10, 16}, {2, 3})
        __doTest({10, 5, 4, 5}, {10, 15}, {2})
        __doTest({10, 5, 4, 5}, {10, 20}, {2, 3, 4})
        __doTest({10, 5, 4, 5}, {19, 20}, {4})
    end,



    testTopToBottomPos = function()

        local function __doTest(calc, h, start, lifeTime, expectedYPos)
            local y = calc:calculate(10, h, start, lifeTime)
            lu.assertEquals(y, expectedYPos)
        end

        local calc = _poscalc.StaticPosCalculator:new()
        calc:init(100, 50)
        __doTest(calc, 10, 0, 5, 0)
        __doTest(calc, 10, 1, 5, 10)
        __doTest(calc, 10, 2, 5, 20)
        __doTest(calc, 10, 5, 5, 0)

        __doTest(calc, 10, 10, 5, 0)
        __doTest(calc, 10, 12, 5, 10)
        __doTest(calc, 20, 12, 5, 20)

        __doTest(calc, 10, 20, 5, 0)
        __doTest(calc, 50, 21, 5, 0)

        calc:dispose()
    end,


    testLeftToRightPos = function()

        local function __doTest(calc, w, h, start, lifeTime, expectedYPos)
            local y = calc:calculate(w, h, start, lifeTime)
            lu.assertEquals(y, expectedYPos)
        end

        local calc = _poscalc.MovingPosCalculator:new()
        calc:init(100, 50)
        __doTest(calc, 100, 10, 0, 5, 0)
        __doTest(calc, 100, 10, 3, 5, 0)
        __doTest(calc, 100, 10, 8, 5, 0)
        __doTest(calc, 100, 10, 9, 5, 10)

        __doTest(calc, 100, 10, 20, 5, 0)
        __doTest(calc, 100, 10, 21, 5, 10)
        __doTest(calc, 100, 20, 24, 5, 0)

        calc:dispose()
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())