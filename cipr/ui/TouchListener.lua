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

local TouchHandler = class.class('cipr.ui.TouchHandler')

function TouchHandler:initialize(listener, target, event)
    self.listener = listener
    self.target = target
    self.xStart = event.xStart
    self.yStart = event.yStart  
    self.xTargetOffset = event.xTargetOffset 
    self.yTargetOffset = event.yTargetOffset 
    self.duration = duration(event.time)    
end

function TouchHandler:began(event)
end

function TouchHandler:moved(event)
    
end

function TouchHandler:ended(event)
    
end

function TouchHandler:cancelled(event)
    
end

function TouchHandler:final(event)
    
end

function TouchHandler:cancel(event)
    self.listener:cancel(self, event)
end

local TapHandler = class.class('cipr.ui.DragHandler', TapHandler)

local DragHandler = class.class('cipr.ui.DragHandler', TouchHandler)

function DragHandler:initialize(listener, target, event, axis)
    TouchHandler.initialize(self, listener, target, event)
    self.axis = axis
    self.lockAxis = nil
    self.ratio = 1
end

--[[
Default drag handler, move object to position
]]--
function DragHandler:moved(event)
    local moveX = true
    local moveY = true

    if self.lockAxis then
        if self.axis == 'y' then
            moveX = false
        else
            moveY = false
        end
    end
    
    if moveX then
        local xDelta = (event.x - self.xTargetOffset) - self.target.x
        self.target.x = self.target.x + (xDelta * self.ratio)
    end

    if moveY then
        local yDelta = (event.y - self.yTargetOffset) - self.target.y
        self.target.y = self.target.y + (yDelta * self.ratio)
    end
end

function DragHandler:getDistance(event)
    return event.x - self.xStart, event.y - self.yStart
end

local TouchListener = class.class('cipr.ui.TouchListener')

-- Number of pixels has to move to be considered a drag
TouchListener.dragThreshold = 10

function TouchListener:initialize(target, listener)
    self._target = target
    self._listener = listener or self._target
    self._target:addEventListener('touch', self)
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

    if phase == 'began' then
        if self._moveHandler then
            print('We have a handler that was never cancelled')
            self._moveHandler:cancelled({})
            self._moveHandler = nil
        end

        display.getCurrentStage():setFocus(self._target)
        
        self.isFocus = true

        self._startEvent = event
        self._startEvent.xTargetOffset = event.x - self._target.x
        self._startEvent.yTargetOffset = event.y - self._target.y
                                    
        return true
    elseif self.isFocus then
        if phase == 'moved' then
            if self._moveHandler then
                return self._moveHandler:moved(event)
            else
                -- Detect handler
                local xMovement = abs(event.xStart - event.x)
                local yMovement = abs(event.yStart - event.y)

                if self._listener.drag then
                    if xMovement > self.dragThreshold or yMovement > self.dragThreshold then
                        -- looks like a drag
                        local axis = xMovement > yMovement and 'x' or 'y'    

                        self._moveHandler = DragHandler:new(self, self._target, self._startEvent, axis)
                        self._moveHandler = self._listener:drag(self._moveHandler)
                        self._moveHandler:began(self._startEvent)
                        self._moveHandler:moved(event)
                    end
                end
            end

        elseif phase == 'ended' or phase == 'cancelled' then
            local handler = self._moveHandler
            if not handler then
                -- Never had a move handler, maybe this is a tap
                if self._listener._tap then
                    handler = TapHandler:new(self, self._target, self._startEvent)
                    handler = self._listener:tap(handler)
                    handler:began(self._startEvent)                  
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

            local ret
            if handler then
                ret = handler:final(event)
            end
            return ret
        end
    end    
end

return TouchListener