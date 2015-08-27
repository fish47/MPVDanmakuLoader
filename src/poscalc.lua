local utils = require('src/utils')  --= utils utils


local __DanmakuArea =
{
    width   = 0,    -- 宽度
    height  = 0,    -- 高度
    start   = 0,    -- 刚好出现屏幕边缘的时刻
    speed   = 0,    -- 水平移动速度
    _next   = nil,  -- 链表指针


    new = function(obj, copyArea)
        obj = utils.allocateInstance(obj)
        obj.width = copyArea and copyArea.width or 0
        obj.height = copyArea and copyArea.height or 0
        obj.start = copyArea and copyArea.start or 0
        obj.speed = copyArea and copyArea.speed or 1
        obj._next = obj._next or nil
        return obj
    end,


    getCollidingDuration = function(a1, a2, screenWidth)
        if a1.speed == math.huge or a2.speed == math.huge
        then
            return 0
        end

        -- 保证最先出现的是 a1
        if a1.start > a2.start
        then
            local tmp = a1
            a1 = a2
            a2 = tmp
        end

        -- a2 要追上 a1 要走的相对距离
        local startTimeDelta = math.max(a2.start - a1.start, 0)
        local movedDistance1 = a1.speed * startTimeDelta
        local chasingDistance = math.max(movedDistance1 - a1.width, 0)

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
        if a2.speed <= a1.speed and chasingDistance > 0
        then
            return 0
        end


        -- 计算从 刚好接触 到 刚好分离 需要走的相对距离，注意判断 a2 最终是否会赶上 a1
        local disjointDistance = 0
        if a2.speed > a1.speed
        then
            disjointDistance = movedDistance1 < a1.width
                               and a1.width - movedDistance1 + a2.width
                               or a1.width + a2.width
        else
            disjointDistance = movedDistance1 < a1.width
                               and a1.width - movedDistance1
                               or 0
        end


        -- 计算 刚好追上 / 刚好相离 所花费的时间
        local speedDelta = math.abs(a2.speed - a1.speed)
        local chasedElapsed = math.max(chasingDistance / speedDelta, 0)
        local disjointElapsed = math.max(disjointDistance / speedDelta, 0)

        -- 如果某一方提前消失，从该时刻开始就不算碰撞
        local remainingTime = math.min(dieOutTime1, dieOutTime2)
        local remainingTimeAfterChased = math.max(remainingTime - chasedElapsed, 0)
        local collidingDuration = math.min(remainingTimeAfterChased, disjointElapsed)

        return collidingDuration
    end,
}

utils.declareClass(__DanmakuArea);


-- 把 node2 插在 node1 后面
local function __insertAfter(node1, node2)
    node2._next = node1._next
    node1._next = node2
end


local function __getIntersectedHeight(top1, bottom1, top2, bottom2)
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



local __BasePosCalculator =
{
    _mScreenWidth       = nil,
    _mScreenHeight      = nil,
    _mDanmakuAreas      = nil,
    __mTmpDanmakuArea   = nil,


    new = function(obj, width, height)
        obj = utils.allocateInstance(obj)
        obj._mScreenWidth = math.floor(width)
        obj._mScreenHeight = math.floor(height)
        obj._mDanmakuAreas = obj:_doInitDanmakuArea(width, height, 0, 0)
        obj.__mTmpDanmakuArea = __DanmakuArea:new()
        return obj
    end,


    __getCollisionScoreSum = function(self, iterAreaTop, iterArea, newAreaTop, area2)
        local scoreSum = 0
        local iterAreaBottom = iterAreaTop + iterArea.height
        local newAreaBottom = math.min(newAreaTop + area2.height, self._mScreenHeight)
        while iterArea ~= nil
        do
            local h1, h2, h3 = __getIntersectedHeight(iterAreaTop, iterAreaBottom,
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

        return scoreSum
    end,


    __addDanmakuArea = function(self, iterArea, iterAreaTop, area2, newAreaTop)
        local iterAreaBottom = iterAreaTop
        local newAreaBottom = newAreaTop + area2.height
        while iterArea ~= nil
        do
            iterAreaTop = iterAreaBottom
            iterAreaBottom = iterAreaTop + iterArea.height

            local h1, h2, h3 = __getIntersectedHeight(iterAreaTop, iterAreaBottom,
                                                      newAreaTop, newAreaBottom)
            if h1 > 0 and h2 == 0
            then
                break
            end

            -- 很多时候只是部分相交，所以需要切割
            if h2 > 0
            then
                local splitH1, _, splitH3 = __getIntersectedHeight(newAreaTop,
                                                                   newAreaBottom,
                                                                   iterAreaTop,
                                                                   iterAreaBottom)

                -- 切割不相交的上半部分
                if splitH1 > 0
                then
                    local prevArea = iterArea
                    local newArea = __DanmakuArea:new(prevArea)
                    prevArea.height = splitH1
                    newArea.height = h2
                    __insertAfter(prevArea, newArea)

                    iterArea = newArea
                end

                -- 切割不相交的下半部分
                if splitH3 > 0
                then
                    local newArea = __DanmakuArea:new(iterArea)
                    newArea.height = splitH3
                    __insertAfter(iterArea, newArea)
                end

                -- 可能做了切割，必须更新高度信息，不然下一轮遍历会出错
                iterAreaTop = iterAreaTop + splitH1
                iterAreaBottom = iterAreaTop + h2

                -- 切割之后两者区域上下边界都相同
                iterArea.height = h2
                self:_doUpdateDanmakuArea(iterArea, area2)
            end

            iterArea = iterArea._next
        end
    end,


    _doGetCollisionScore = function(self, area1, area2)
    end,

    _doInitDanmakuArea = function(self, w, h, start, lifeTime, outArea)
    end,

    _doUpdateDanmakuArea = function(self, area1, area2)
    end,


    calculate = function(self, w, h, start, lifeTime)
        -- 区域位置全部用整数表示
        h = math.ceil(h)

        local screenTop = 0
        local screenBottom = self._mScreenHeight
        local danmakuTop = screenTop
        local danmakuBottom = danmakuTop + h

        local minScore = math.huge
        local retY = screenTop
        local insertArea = self._mDanmakuAreas
        local insertAreaTop = screenTop

        local iterArea = self._mDanmakuAreas
        local area2 = self:_doInitDanmakuArea(w, h, start, lifeTime,
                                             self.__mTmpDanmakuArea)

        local iterAreaBottom = 0
        while iterArea ~= nil
        do
            -- 移动区域不记录上下边界，因为总是紧接的
            local iterAreaTop = iterAreaBottom
            iterAreaBottom = iterAreaTop + iterArea.height

            if iterAreaBottom >= danmakuTop
            then
                local score = self:__getCollisionScoreSum(iterAreaTop,
                                                          iterArea,
                                                          danmakuTop,
                                                          area2)

                if score == 0
                then
                    -- 找到完全合适的位置
                    retY = danmakuTop
                    break
                else
                    if minScore > score
                    then
                        minScore = score
                        retY = danmakuTop
                        insertArea = iterArea
                        insertAreaTop = iterAreaTop
                    end

                    local downHeight = iterArea.height
                    danmakuTop = danmakuTop + downHeight
                    danmakuBottom = danmakuBottom + downHeight

                    -- 不允许超出屏幕底边界
                    if danmakuBottom > self._mScreenHeight
                    then
                        break
                    end
                end
            end

            iterArea = iterArea._next
        end

        self:__addDanmakuArea(insertArea, insertAreaTop, area2, retY)
        return retY
    end,


    dispose = function(self)
        local area = self._mDanmakuAreas
        while area ~= nil
        do
            local org = area
            area = area._next
            utils.clearTable(org)
        end
        utils.clearTable(self)
    end
}

utils.declareClass(__BasePosCalculator);



local MovingPosCalculator =
{
    _doGetCollisionScore = function(self, area1, area2)
        return area1:getCollidingDuration(area2, self._mScreenWidth)
    end,


    _doInitDanmakuArea = function(self, w, h, start, lifeTime, outArea)
        local speed = 0
        if lifeTime == 0
        then
            -- 防止出现除零错误
            w = 1
            speed = math.huge
        else
            speed = (w + self._mScreenWidth) / lifeTime
        end

        outArea = outArea or __DanmakuArea:new()
        outArea.width = w
        outArea.height = h
        outArea.start = start
        outArea.speed = speed
        return outArea
    end,


    _doUpdateDanmakuArea = function(self, area1, area2)
        area1.start = area2.start
        area1.speed = area2.speed
        area1.width = area2.width
    end,
}

utils.declareClass(MovingPosCalculator, __BasePosCalculator)



local StaticPosCalculator =
{
    _doInitDanmakuArea = function(self, w, h, start, lifeTime, outArea)
        -- 这里把 speed 这个字段 hack 成存活时间了
        outArea = outArea or __DanmakuArea:new()
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
        return math.max(area1.start + area1.speed - area2.start, 0)
    end,


    _doUpdateDanmakuArea = function(self, area1, area2)
        local endTime1 = area1.start + area1.speed
        local endTime2 = area2.start + area2.speed

        area1.start = math.max(area1.start, area2.start)
        area1.speed = math.max(endTime1, endTime2) - area1.start
        area1.width = area2.width
    end,
}

utils.declareClass(StaticPosCalculator, __BasePosCalculator)



return
{
    __DanmakuArea           = __DanmakuArea,
    __getIntersectedHeight  = __getIntersectedHeight,

    MovingPosCalculator     = MovingPosCalculator,
    StaticPosCalculator     = StaticPosCalculator,
}