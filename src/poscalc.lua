local base = require('src/base')    --= base base


local _MovingArea = {}
base.declareClass(_MovingArea, nil,
{
    width = 0,      -- 宽度
    height = 0,     -- 高度
    start = 0,      -- 刚好出现屏幕边缘的时刻
    speed = 0,      -- 水平移动速度
    _next = nil,    -- 链表指针


    new = function(obj, copyArea)
        obj = base.allocateInstance(_MovingArea, obj)
        obj.width = copyArea and copyArea.width or 0
        obj.height = copyArea and copyArea.height or 0
        obj.start = copyArea and copyArea.start or 0
        obj.speed = copyArea and copyArea.speed or 1
        obj._next = obj._next or nil
        return obj
    end,


    getCollidingDuration = function(a1, a2, screenWidth)
        -- 保证最先出现的是 a1
        if a1.start > a2.start
        then
            local tmp = a1
            a1 = a2
            a2 = tmp
        end

        -- a2 开始出现在屏幕右边缘，此时 a1 右侧距屏幕右边缘的距离
        -- 如果 a2 要追上 a1 必须要走完的长度
        local startTimeDelta = math.max(a2.start - a1.start, 0)
        local chasingDistance = math.max(a1.speed * startTimeDelta - a1.width, 0)

        -- 计算 a1 / a2 存活时间
        local lifeTime1 = (a1.width + screenWidth) / a1.speed
        local lifeTime2 = (a2.width + screenWidth) / a2.speed

        -- 以 a2 刚好出现作为基准点，记录几个关键时刻
        local dieOutTime1 = math.max(lifeTime1 - startTimeDelta, 0)
        local dieOutTime2 = lifeTime2

        -- 避免除零错误，提前判这种情况
        -- 根据初始状态是否相交，就可以知道碰撞时间了
        if a1.speed == a2.speed
        then
            if chasingDistance == 0
            then
                return math.min(dieOutTime1, dieOutTime2)
            else
                return 0
            end
        end

        -- 明显追不上
        if a2.speed <= a1.speed and chasingDistance >= 0
        then
            return 0
        end

        -- 计算 刚好接触 / 刚好相离 所花费的时间，注意区分是 a2 超越还是 a2 追不上
        local speedDelta = math.abs(a2.speed - a1.speed)
        local chasedElapsed = math.max(chasingDistance / speedDelta, 0)
        local disjointDistance = a2.speed > a1.speed
                                 and (a1.width + a2.width)
                                 or (chasingDistance)
        local disjointElapsed = math.max(disjointDistance / speedDelta, 0)

        -- 以 a2 刚好出现作为基准点，刚好追上和分离的时间
        local chasedTime = chasedElapsed
        local disjointTime = chasedTime + disjointElapsed

        return math.min(disjointTime - chasedTime, dieOutTime1, dieOutTime2)
    end,


    update = function(self, a2)
        -- 以最先出现的区域起始时间，作为基准点
        local a1 = self
        local newStartTime = math.min(a1.start, a2.start)

        -- 优先取最慢的速度
        local newSpeed = math.min(a1.speed, a2.speed)

        -- 将两个区域拼起来
        local movedWidth = a1.speed * math.abs(a1.start - a2.start)
        local newWidth = movedWidth + a2.width

        self.start = newStartTime
        self.speed = newSpeed
        self.width = newWidth
    end,
});


local function _getIntersectedHeight(top1, bottom1, top2, bottom2)
    local h1 = 0
    local h2 = 0
    local h3 = 0

    if top1 >= bottom2
    then
        -- 完全在上方
        h1 = bottom2 - top2
    elseif top2 >= bottom1
    then
        -- 完全在下方
        h3 = bottom2 - top2
    else
        h1 = math.max(math.min(top1, bottom2) - top2, 0)
        h2 = math.min(bottom1, bottom2) - math.max(top1, top2)
        h3 = math.max(bottom2 - math.max(bottom1, top2), 0)
    end

    -- 结果只针对第二个区域而言
    -- 上溢出高度, 相交高度, 下溢出高度
    return h1, h2, h3
end


local _BasePosCalculator = {}
base.declareClass(_BasePosCalculator, nil,
{
    _mScreenWidth = nil,
    _mScreenHeight = nil,
    _mMovingAreas = nil,
    __mDanmakuMovingArea = nil,


    new = function(obj, width, height)
        obj = base.allocateInstance(_BasePosCalculator, obj)
        obj._mScreenWidth = width
        obj._mScreenHeight = height
        obj._mMovingAreas = obj:_doInitMovingArea(width, height, 0, 0)
        obj.__mDanmakuMovingArea = _MovingArea:new()
        return obj
    end,


    __getCollisionScoreSum = function(self, iterAreaTop, iterArea, newAreaTop, area2)
        local scoreSum = 0
        local iterAreaBottom = iterAreaTop + iterArea.height
        local newAreaBottom = newAreaTop + area2.height
        while iterArea ~= nil
        do
            local h1, h2, h3 = _getIntersectedHeight(iterAreaTop, iterAreaBottom,
                                                     newAreaTop, newAreaBottom)
            local score = h2 > 0 and self:_doGetCollisionScore(iterArea, area2) * h2 or 0
            scoreSum = scoreSum + score

            -- 继续向下遍历也不会相交
            if h1 > 0 and h2 == 0
            then
                break
            end

            iterArea = iterArea._next
            iterAreaTop = iterAreaBottom
            iterAreaBottom = iterAreaTop + (iterArea and iterArea.height or 0)
        end
    end,


    __addMovingArea = function(self, iterArea, iterAreaTop, area2, newAreaTop)
        local iterAreaBottom = iterAreaTop
        local newAreaBottom = newAreaTop + area2.height
        while iterArea ~= nil
        do
            iterAreaTop = iterAreaBottom
            iterAreaBottom = iterAreaTop + iterArea.height

            local h1, h2, h3 = _getIntersectedHeight(iterAreaTop, iterAreaBottom,
                                                     newAreaTop, newAreaBottom)
            if h1 > 0 and h2 == 0
            then
                break
            end

            -- 很多时候只是部分相交，所以需要切割
            if h2 > 0
            then
                local splitH1, _, splitH3 = _getIntersectedHeight(newAreaTop, newAreaBottom,
                                                                  iterAreaTop, iterAreaBottom)

                -- 把 node2 插在 node1 后面
                local function __insertAfter(node1, node2)
                    node2._next = node1._next
                    node1._next = node2
                end

                -- 切割不相交的上半部分
                if splitH1 > 0
                then
                    local prevArea = iterArea
                    local newArea = _MovingArea:new(prevArea)
                    prevArea.height = splitH1
                    newArea.height = h2
                    __insertAfter(prevArea, newArea)

                    iterArea = newArea
                end

                -- 切割不相交的下半部分
                if splitH3 > 0
                then
                    local newArea = _MovingArea:new(iterArea)
                    newArea.height = splitH3
                    __insertAfter(iterArea, newArea)
                end

                -- 可能做了切割，必须更新高度信息，不然下一轮遍历会出错
                iterAreaTop = iterAreaTop + splitH1
                iterAreaBottom = iterAreaTop + h2

                -- 切割之后两者区域上下边界都相同
                iterArea.height = h2
                self:_doUpdateMovingArea(iterArea, area2)
            end

            iterArea = iterArea._next
        end
    end,


    _doGetCollisionScore = function(self, area1, area2)
        return area1:getCollidingDuration(area2, self._mScreenWidth)
    end,


    _doInitMovingArea = function(self, w, h, start, lifeTime, outArea)
        local speed = 0
        if lifeTime == 0
        then
            -- 防止出现除零错误
            w = 0
            speed = math.huge
        else
            speed = (w + self._mScreenWidth) / lifeTime
        end

        outArea = outArea or _MovingArea:new()
        outArea.width = w
        outArea.height = h
        outArea.start = start
        outArea.speed = speed
        return outArea
    end,


    _doUpdateMovingArea = function(self, area1, area2)
        area1:update(area2)
    end,


    calculate = function(self, w, h, start, lifeTime, enumStep)
        local screenTop = 0
        local screenBottom = self._mScreenHeight
        local danmakuTop = screenTop
        local danmakuBottom = danmakuTop + h

        local minScore = math.huge
        local retY = screenTop
        local insertArea = self.__mMovingAreas
        local insertAreaTop = screenTop

        local iterArea = self.__mMovingAreas
        local prevArea = iterArea
        local area2 = self:_doInitMovingArea(w, h, start, lifeTime,
                                             self.__mDanmakuMovingArea)

        local iterAreaBottom = 0
        while iterArea ~= nil
        do
            -- 移动区域不记录上下边界，因为总是紧接的
            local iterAreaTop = iterAreaBottom
            iterAreaBottom = iterAreaTop + iterArea.height

            if iterAreaBottom <= danmakuTop
            then
                local score = self:__getCollisionScoreSum(iterAreaTop, iterArea,
                                                          danmakuTop, area2)
                if score == 0 or danmakuTop + enumStep >= screenBottom
                then
                    -- 找到完全合适的位置，或者再向下枚举就会出界
                    break
                else
                    if minScore > score
                    then
                        minScore = score
                        retY = danmakuTop
                        insertArea = iterArea
                        insertAreaTop = iterAreaTop
                    end

                    -- 弹幕的 y 坐标只会是 0, enumStep, enumStep*2, enumStep*3, ...
                    -- 应该不是最优算法，只是比较好写而已
                    danmakuTop = danmakuTop + enumStep
                    danmakuBottom = danmakuBottom + enumStep

                    -- 向下移也不一定能超出这个区域的
                    if danmakuTop <= iterAreaBottom
                    then
                        iterArea = prevArea
                        iterAreaBottom = iterAreaBottom - iterArea.height
                    end
                end
            end

            iterArea = iterArea._next
        end

        self:__addMovingArea(insertArea, insertAreaTop, area2, retY)
        return 0, retY
    end,


    dispose = function(self)
        local area = self.__mMovingAreas
        while area ~= nil
        do
            local org = area
            area = area._next
            base.clearTable(org)
        end
        base.clearTable(self)
    end
});


local L2RPosCalculator = {}
base.declareClass(L2RPosCalculator, _BasePosCalculator)


local R2LPosCalculaotr = {}
base.declareClass(R2LPosCalculaotr, _BasePosCalculator,
{
    calculate = function(...)
        local x, y = _BasePosCalculator.calculate(self, ...)
        return self._mScreenWidth, y
    end,
})


local T2BPosCalculator = {}
base.declareClass(T2BPosCalculator, _BasePosCalculator,
{
    _doInitMovingArea = function(self, w, h, start, lifeTime, outArea)
        -- 这里把 speed 这个字段 hack 成存活时间了
        outArea.start = start
        outArea.width = 1
        outArea.height = h
        outArea.speed = lifeTime
        return outArea
    end,


    _doGetCollisionScore = function(self, area1, area2)
        -- 保证 area1 比 area2 先出现
        if area1.start > area2.start
        then
            local tmp = area1
            area1 = area2
            area2 = tmp
        end

        -- 计算同时出现的时间
        return math.max(area1.start + area1.speed, area2.start, 0)
    end,


    _doUpdateMovingArea = function(self, area1, area2)
        if area1.start + area1.speed < area2.start + area2.speed
        then
            area1:new(area2)
        end
    end,


    calculate = function(self, w, h, start, lifeTime, enumStep)
        -- 返回结果需要居中
        local _, y = _BasePosCalculator.calculate(self, w, h, start, lifeTime, enumStep)
        local x = math.min((self._mScreenWidth - w) / 2, 0)
        return x, y
    end
})


local B2TPosCalcluator = {}
base.declareClass(B2TPosCalcluator, T2BPosCalculator,
{
    calculate = function(w, h, start, lifeTime, enumStep)
        -- 竖直镜面反转
        local x, offset = T2BPosCalculator:calculate(w, h, start, lifeTime, enumStep)
        local y = self._mScreenHeight - (offset + h)
        return x, y
    end,
})


local _M = {}
_M._MovingArea = _MovingArea
_M._getIntersectedHeight = _getIntersectedHeight
_M.L2RPosCalculator = L2RPosCalculator
_M.R2LPosCalculaotr = R2LPosCalculaotr
_M.T2BPosCalculator = T2BPosCalculator
_M.B2TPosCalcluator = B2TPosCalcluator
return _M