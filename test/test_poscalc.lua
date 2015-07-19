local lu = require('3rdparties/luaunit')    --= luaunit lu
local base = require('src/base')            --= base base
local poscalc = require('src/poscalc')      --= poscalc poscalc
local MovingArea = poscalc._MovingArea

TestMovingArea =
{
    __doInitMovingArea = function(self, a, start, speed, width)
        a.start = start
        a.speed = speed
        a.width = width
    end,


    test_duration = function(self)
        local function __doAssertDuration(a1, a2, screenWidth, duration)
            local ret = a1:getCollidingDuration(a2, screenWidth)
            lu.assertEquals(ret, a2:getCollidingDuration(a1, screenWidth))
            lu.assertEquals(ret, duration)
        end

        local a1 = MovingArea:new()
        local a2 = MovingArea:new()

        -- 不相交而且追不上
        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 100, 5, 100)
        __doAssertDuration(a1, a2, 100000000, 0)

        -- 接近右边界，但因为速度相同，所以也追不上
        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 10.0001, 10, 100)
        __doAssertDuration(a1, a2, 100000000, 0)

        -- 后来刚出现，前者刚消失
        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 20, 20, 100)
        __doAssertDuration(a1, a2, 100, 0)

        -- 如果一开始就相交，存活时间影响碰撞时间
        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 9, 10, 100)
        __doAssertDuration(a1, a2, 100, 11)

        -- 碰撞时间 = 相交 + 分离
        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 20, 20, 100)
        for i = 0, 10
        do
            local screenWidth = 100 + i * 10
            __doAssertDuration(a1, a2, screenWidth, i)
        end

        -- 速度为极值，暂认为完全不相交
        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 0, math.huge, 100)
        __doAssertDuration(a1, a2, 100, 0)

        -- 出现较早且速度较快，而且部分相交
        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 1, 5, 20)
        __doAssertDuration(a1, a2, 10000, 18)

        -- 出现较早且速度较快，而且与后来者不相交，也就不碰撞了
        self:__doInitMovingArea(a1, 0, 10, 10)
        self:__doInitMovingArea(a2, 1, 5, 20)
        __doAssertDuration(a1, a2, 1000, 0)
    end,


    test_update = function(self)
        local function __doAssertArea(a, areaArg, start, speed, width)
            a:update(areaArg)
            lu.assertEquals(start, a.start)
            lu.assertEquals(speed, a.speed)
            lu.assertEquals(width, a.width)
        end

        local a1 = MovingArea:new()
        local a2 = MovingArea:new()

        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 10, 10, 100)
        __doAssertArea(a1, a2, 0, 10, 200)

        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 30, 10, 100)
        __doAssertArea(a1, a2, 0, 10, 400)

        self:__doInitMovingArea(a1, 0, 20, 100)
        self:__doInitMovingArea(a2, 40, 10, 100)
        __doAssertArea(a1, a2, 0, 10, 900)

        self:__doInitMovingArea(a1, 0, math.huge, 100000)
        self:__doInitMovingArea(a2, 2, 10, 20)
        __doAssertArea(a1, a2, 2, 10, 20)

        self:__doInitMovingArea(a1, 0, 10, 100)
        self:__doInitMovingArea(a2, 1, 10, 1)
        __doAssertArea(a1, a2, 0, 10, 101)

        self:__doInitMovingArea(a1, 0, 10, 1)
        self:__doInitMovingArea(a2, 20, 10, 200)
        __doAssertArea(a1, a2, 0, 10, 400)
    end,
}


TestIntersectedHeight =
{
    test_main = function()
        local function __doAssert(top1, bottom1, top2, bottom2, heights)
            local h1, h2, h3 = poscalc._getIntersectedHeight(top1, bottom1, top2, bottom2)
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
        local area = calc._mMovingAreas
        local heightSum = 0
        for i, h in ipairs(heights)
        do
            local newArea = (i == 1) and area or MovingArea:new()
            newArea.height = h
            area._next = newArea
            newArea._next = nil

            area = newArea
            heightSum = heightSum + h
        end

        calc._mScreenHeight = heightSum
    end,


    test_add_area = function(self)
        local function __doAddArea(calc, top, bottom)
            -- 只为防止被相容才做些奇怪数据而已
            local newArea = MovingArea:new()
            newArea.speed = 1234
            newArea.width = 4321
            newArea.start = 5555
            newArea.height = bottom - top
            calc:__addMovingArea(calc._mMovingAreas, 0, newArea, top)
        end

        local function __doAssertAreaHeights(calc, heights)
            local area = calc._mMovingAreas
            local calcHeightList = {}
            while area ~= nil
            do
                table.insert(calcHeightList, area.height)
                area = area._next
            end
            lu.assertEquals(heights, calcHeightList)
            base.clearTable(calcHeightList)
        end

        local function __doTest(heights, areaBounds, assertHeights)
            local addTop, addBottom = table.unpack(areaBounds)
            local calc = poscalc.L2RPosCalculator:new()
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


    test_score_sum = function(self)
        local function __doTest(heights, areaBounds, assertAreaIndexes)
            local calc = poscalc.L2RPosCalculator:new()
            self:__doInitAreaHeights(calc, heights)

            -- 编号
            local idx = 1
            local areaIndexes = {}
            local iterArea = calc._mMovingAreas
            while iterArea ~= nil
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

            local newArea = MovingArea:new()
            local newAreaTop, newAreaBottom = table.unpack(areaBounds)
            newArea.height = newAreaBottom - newAreaTop
            calc:__getCollisionScoreSum(0, calc._mMovingAreas, newAreaTop, newArea)

            lu.assertEquals(sumedAreaIndexes, assertAreaIndexes)

            base.clearTable(sumedAreaIndexes)
            base.clearTable(assertAreaIndexes)
            base.clearTable(areaIndexes)
            calc:dispose()
        end

        __doTest({10, 5, 4, 5}, {5, 6}, {1})
        __doTest({10, 5, 4, 5}, {10, 16}, {2, 3})
        __doTest({10, 5, 4, 5}, {10, 15}, {2})
        __doTest({10, 5, 4, 5}, {10, 20}, {2, 3, 4})
        __doTest({10, 5, 4, 5}, {19, 20}, {4})
    end,



    test_t2b_pos = function()

        local function __doTest(calc, h, start, lifeTime, expectedYPos)
            local y = calc:calculate(10, h, start, lifeTime)
            lu.assertEquals(y, expectedYPos)
        end

        local calc = poscalc.T2BPosCalculator:new(100, 50)
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


    test_l2r_pos = function()

        local function __doTest(calc, w, h, start, lifeTime, expectedYPos)
            local y = calc:calculate(w, h, start, lifeTime)
            lu.assertEquals(y, expectedYPos)
        end

        local calc = poscalc.L2RPosCalculator:new(100, 50)
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