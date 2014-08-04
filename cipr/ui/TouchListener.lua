local cipr = require 'cipr'
local class = cipr.import('cipr.class')
local abs = math.abs

--[[
Manages duration::

    myDuration = duration()
    print(myDuration.start)
    print(myDuration())
    print(myDuration.last)

]]--
local duration = function(startTime)
    local startTime = startTime or system.getTimer()
    local getDuration = {
        start = startTime
    }
    getDuration.__call = function()
        getDuration.last = system.getTimer() - startTime
        return getDuration.last
    end

    return getDuration
end

--[[
Base class for Touch event
]]--
local Touch = class.class(... .. '.Touch')
function Touch:initialize(listener, target, event)
    self.listener = listener
    self.target = target
    self.xStart = event.xStart
    self.yStart = event.yStart
    self.xFirst = event.x
    self.yFirst = event.y
    self.xLast = event.x
    self.yLast = event.y
    self.xTargetOffset = event.xTargetOffset
    self.yTargetOffset = event.yTargetOffset
    self.xOffset = 0
    self.yOffset = 0
    self.duration = duration(event.time)
end

--[[
Called when a touch begins
]]--
function Touch:began(event)
end

--[[
Called when a touch moves
]]--
function Touch:moved(event)
end

--[[
Called when a touch ends
]]--
function Touch:ended(event)
end

--[[
Called when a touch has been cancelled
]]--
function Touch:cancelled(event)
end

--[[
Called when a touch has ended or been cancelled
]]--
function Touch:final(event)
end

--[[
Cancel a touch
]]--
function Touch:cancel(event)
    self.listener:cancel(self, event)
end

local Tap = class.class(... .. '.Tap', Touch)
function Tap:initialize(listener, target, event)
    Touch.initialize(self, listener, target, event)
    self.x = event.x
    self.y = event.y
end

--[[
Trag drag events
]]--
local Drag = class.class(... .. '.Drag', Touch)
Drag.X_AXIS = 'x'
Drag.Y_AXIS = 'y'

function Drag:initialize(listener, target, event, axis, direction)
    Touch.initialize(self, listener, target, event)
    -- Is drag happening on X_AXIS or Y_AXIS axis?
    self.axis = axis
    -- Should we only allow dragging along an axis?
    self.lockAxis = nil
    -- Ratio we move objects to touch movement
    self.ratio = 1
    self.direction = direction
end

--[[
Default drag handler, move object to position
]]--
function Drag:moved(event)
    local xRatio = self.ratio
    local yRatio = self.ratio

    if self.lockAxis then
        if self.axis == Drag.Y_AXIS then
            xRatio = 0
        else
            yRatio = 0
        end
    end

    local xDelta = ((event.x - self.xTargetOffset) - self.target.x) * xRatio
    local yDelta = ((event.y - self.yTargetOffset) - self.target.y) * yRatio

    self.target:translate(xDelta, yDelta)
end

--[[
Get distance a drag has moved
Returns {x distance, y distance}
]]--
function Drag:getDistance(event)
    return event.x - self.xStart, event.y - self.yStart
end

--[[
Handle Corona touch events and turn them into Touch objects

Drag
---
To listen to drag events, must implement `targetWasDragged(Drag)`
that returns a handler.

For default Drag behavior of moving target, target must implement
`translate(x, y)`.

Tap
---
To listen to tap events, must implement `targetWasTapped(Tap)`.
]]--
local TouchListener = class.class(...)

-- Number of pixels has to move to be considered a drag
TouchListener.dragThreshold = 10

function TouchListener:initialize(target, listener, toucher)
    self._target = target
    self._listener = listener or self._target
    self._toucher = toucher or self._target
    self._toucher:addEventListener('touch', self)
    self._moveHandler = nil
end

local function reset(self)
    if self.isFocus then
        display.getCurrentStage():setFocus(nil)
    end

    self._moveHandler = nil
    self._startEvent = nil
    self.isFocus = nil
end

function TouchListener:cancel(handler, event)
    if self._moveHandler then
        self._moveHandler:cancelled(event)
        self._moveHandler:final(event)
    end

    reset(self)
end

function TouchListener:touch(event)
    local phase = event.phase
    local result

    if phase == 'began' then
        if self._moveHandler then
            print('We have a handler that was never cancelled')
            self._moveHandler:cancelled({})
            self._moveHandler = nil
        end

        display.getCurrentStage():setFocus(self._toucher)

        self.isFocus = true

        self._startEvent = event
        self._startEvent.xTargetOffset = event.x - self._target.x
        self._startEvent.yTargetOffset = event.y - self._target.y

        result = true
    elseif self.isFocus then
        if phase == 'moved' then
            if self._moveHandler then
                -- self._moveHandler.direction = 1
                if self._moveHandler.axis == Drag.X_AXIS then
                    if event.x < self.xLast then
                        self._moveHandler.direction = -1
                    elseif event.x > self.xLast then
                        self._moveHandler.direction = 1
                    end
                elseif self._moveHandler.axis == Drag.Y_AXIS then
                    if event.y < self.yLast then
                        self._moveHandler.direction = -1
                    elseif event.y > self.yLast then
                        self._moveHandler.direction = 1
                    end
                end

                result = self._moveHandler:moved(event)
            else
                -- Detect handler
                if self._listener.targetWasDragged then
                    local xMovement = abs(event.xStart - event.x)
                    local yMovement = abs(event.yStart - event.y)

                    if xMovement > self.dragThreshold or yMovement > self.dragThreshold then
                        -- looks like a drag
                        local axis = xMovement > yMovement and Drag.X_AXIS or Drag.Y_AXIS
                        local direction = 1
                        if (axis == Drag.X_AXIS and event.x < event.xStart) or (axis == Drag.Y_AXIS and event.y < event.yStart) then
                            direction = -1
                        end

                        self._moveHandler = Drag:new(self, self._target, self._startEvent, axis, direction)
                        self._moveHandler = self._listener:targetWasDragged(self._moveHandler)
                        if self._moveHandler then
                            self._moveHandler:began(self._startEvent)
                            self._moveHandler:moved(event)
                        else
                            self:cancel()
                        end
                    end
                end
            end

        elseif phase == 'ended' or phase == 'cancelled' then
            local handler = self._moveHandler
            if not handler and handler ~= false then
                -- Never had a move handler, maybe this is a tap
                if self._listener.targetWasTapped then
                    handler = Tap:new(self, self._target, self._startEvent)
                    handler = self._listener:targetWasTapped(handler)
                    if handler then
                        handler:began(self._startEvent)
                    end
                end
            end

            if handler then
                if phase == 'ended' then
                    handler:ended(event)
                elseif phase == 'cancelled' then
                    handler:cancelled(event)
                end
            end

            reset(self)

            if handler then
                result = handler:final(event)
            end
        end
    end

    self.xLast = event.x
    self.yLast = event.y

    return result
end

return TouchListener