local min = math.min
local max = math.max
local floor = math.floor
local abs = math.abs
local cipr = require 'cipr'
local class = cipr.import 'cipr.class'
local TouchListener = cipr.import 'cipr.ui.TouchListener'

--[[
Horizontal spring board.

TODO Add option to make a vertical spring board.
TODO Hide offscreen items

Events
------

* `addSlide` - When a slide is added to the springboard.

    * name - Event name
    * target - New slide object
    * position - Position number of new slide

* `changeSlide` - When the current slide is changed    
]]--

local SpringBoard = class.class('cipr.ui.widgets.SpringBoard')

SpringBoard.ADD_SLIDE_EVENT = 'addSlide'
SpringBoard.CHANGE_SLIDE_EVENT = 'changeSlide'

--[[
The width and height determine the virtual size of each slide. Width and height 
can be smaller (or larger than) the screen. No scaling is done to fit objects 
within this size so objects may be much smaller or even larger than the box. Objects
are placed at the center of this box.

:param width: int - The maximum width of a single slide. 
:param height: int - The maximum height of a single slide. 
:param opts: table - Options


Options
-------
* margin: int (default: 0) - Space between slides
* slingThreshold: int (default: 1/5th of width) - The amount of pixels a slide must be dragged to be considered a sling
]]--
function SpringBoard:initialize(width, height, opts)
    local opts = opts or {}
    self.view = display.newGroup()
    self._pad = opts.margin or 0
    self._width = width
    self._height = height
    self._slides = {}
    self._slideNumIdx = {}
    self._currentTransition = nil
    self.slingThreshold = opts.slingThreshold or self._width / 5
    self._pane = display.newGroup()
    self._currentSlide = 1

    self.view:insert(self._pane)
    TouchListener(self._pane, self)
end

local function cancelTransition(self)
    if self._currentTransition then
        transition.cancel(self._currentTransition)
        self._currentTransition = nil
    end    
end    

local function clampSlideNum(self, num)
    return max(1, min(num, #self._slideNumIdx))
end
    
local function calcSlideNum(self, clamp)
    local xOffset = -(self._pane.x / (self._width + self._pad)) + 1
    local num = floor(xOffset + 0.5)   
    
    if clamp == false then 
        return num
    else
        return clampSlideNum(self, num)
    end
end

--[[
Add a display object to the springboard
]]--
function SpringBoard:add(name, slideObj)
    local slideNum = #self._slideNumIdx+1
    self._slides[name] = slideObj
    self._slideNumIdx[slideNum] = self._slides[name]
    self._pane:insert(slideObj)

    slideObj.y = 0
    slideObj.x = (slideNum - 1) * (self._width + self._pad)

    self.view:dispatchEvent(SpringBoard.ADD_SLIDE_EVENT, {
        name = SpringBoard.ADD_SLIDE_EVENT,
        target = slideObj,
        position = slideNum
    })
end

local function gotoSlide(self, target)
    local target = target
    local xTarget = -target.x
    local xDelta = xTarget - self._pane.x

    local transTime = 1000 * (abs(xDelta) / 600)
    
    cancelTransition(self)

    local onComplete = function()
        cancelTransition(self)
        self._currentSlide = calcSlideNum(self)

        -- TODO For some reason dispatching this event throws a runtime error
        -- self:dispatchEvent(SpringBoard.CHANGE_SLIDE_EVENT, {
        --     name = SpringBoard.CHANGE_SLIDE_EVENT,
        --     target = target,
        --     position = self._currentSlide
        -- })
    end

    self._currentTransition = transition.to(self._pane, { 
        x = xTarget,
        time = transTime,
        transition = easing.outQuad, 
        onComplete = onComplete 
    })    
end

--[[
Jump to slide by name
]]--
function SpringBoard:goto(name, method)
    cancelTransition(self)

    local target = self._slides[name]
    assert(target, 'Slide ' .. name .. ' not found')   
    
    gotoSlide(self, target)     
end

--[[
Jump to slide by position number
]]--
function SpringBoard:gotoNum(num, method)
    local num = clampSlideNum(self, num)
    local target = self._slideNumIdx[num]

    assert(target, 'Slide #' .. num .. ' not found')        

    gotoSlide(self, target)
end

--[[
Drag handler
]]--
function SpringBoard:drag(handler)

    handler.lockAxis = true
    handler.axis = 'x'

    local startSlide = self._currentSlide
    local currentSlide = startSlide
    local numSlides = #self._slideNumIdx
    local this = self

    local oldMovedHandler = handler.moved
    function handler:moved(event)
        cancelTransition(self)

        local xDistance, yDistance = self:getDistance(event)
        if currentSlide == 1 and xDistance > 0 then
            self.ratio = 0.3
        elseif currentSlide == numSlides and xDistance < 0 then
            self.ratio = 0.3
        else
            self.ratio = 1
        end

        oldMovedHandler(self, event)

        local slideNum = calcSlideNum(this, false)
        currentSlide = clampSlideNum(this, slideNum)
        if slideNum < 1 or slideNum > numSlides then
            self:cancel(event)            
        end
    end

    function handler:final(event)
        local xDistance, yDistance = self:getDistance(event)
        if currentSlide == startSlide then
            if xDistance < -this.slingThreshold then
                currentSlide = currentSlide + 1
            elseif xDistance > this.slingThreshold then
                currentSlide = currentSlide - 1
            end
        end
                
        this:gotoNum(currentSlide)
    end

    return handler
end

function SpringBoard:addEventListener(...)
    return self.view:addEventListener(...)
end

    
return SpringBoard