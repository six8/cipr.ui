local stime = system.getTimer
local max = math.max
local cipr = require 'cipr'
local class = cipr.import 'cipr.class'
local log = cipr.import('cipr.logging').getLogger(...)

--[[
ParallaxLayer
-------------

A single layer within a ParallaxView
]]--
local ParallaxLayer = class.class('ParallaxLayer')

function ParallaxLayer:initialize(speed)
    self.view = display.newGroup()
    self.cols = {}
    self.numCols = 0
    self.totalWidth = 0
    self._halfTotalWidth = 0
    self.speed = speed    
end

--[[
Add a Corona Display Object to this layer
]]--
function ParallaxLayer:addCol(displayObj)
    self.view:insert(displayObj)
    
    displayObj:setReferencePoint(display.BottomLeftReferencePoint)
    displayObj.x = 0
    displayObj.y = 0 + (displayObj.offsetY or 0)    

    local offset = self.totalWidth
    
    self.totalWidth = self.totalWidth + displayObj.contentWidth
    self._halfTotalWidth = max(displayObj.contentWidth, self._halfTotalWidth)            

    local col = {
        obj = displayObj,
        offset = offset,
    }

    self.numCols = self.numCols + 1

    -- Set initial position
    self:_scrollCol(self.numCols, col, 0, 0, 0, 0)    

    -- Start invisible, we'll make it visible when needed
    col.obj.isVisible = false
    self.cols[self.numCols] = col
end

function ParallaxLayer:_scrollCol(i, col, x, y)
    local w = self.totalWidth
    x = (((x + col.offset) % w)  % w ) - self._halfTotalWidth
    
    col.obj:translate(x - col.obj.x, 0)
    
    local right = x + col.obj.contentWidth
    local left = x

    -- Hide objects that are offscreen for performance
    -- TODO Use the parallax view width to determine this
    col.obj.isVisible = right >= -self._halfTotalWidth and left <= (display.contentWidth / self.view.xScale)
end

function ParallaxLayer:scrollTo(x, y, scale)
    x = -x * self.speed / scale
    y = -y * self.speed / scale
    
    self.view.xScale = scale
    self.view.yScale = scale

    for i=1,self.numCols do
        local col = self.cols[i]
        self:_scrollCol(i, col, x, y)
    end
end

--[[
ParallaxView
------------

A ParallaxView has many layers that scroll at different rates.

Example::

    local view = ParallaxView(display.contentWidth, display.contentHeight)

    -- This layer moves at half the speed
    local layer1 = view:newLayer(0.5)

    -- A layer must have at least 2 columns. The width of all the cols combined must be
    -- at least the width of the view in order to loop properly
    layer1:addCol(bg1)
    layer1:addCol(bg2)
    layer1:addCol(bg3)

    -- This layer moves at 1/4 the speed
    local layer2 = view:newLayer(0.25)
    layer2:addCol(mySprite)

    layer2:addCol(bgA)
    layer2:addCol(bgB)    

    local function enterFrame()
        view:scrollTo(world.x, world.y, world.xScale)
    end
]]--
local ParallaxView = class.class('cipr.ui.widgets.ParallaxView')

function ParallaxView:initialize(width, height)
    self.view = display.newGroup()
    self.layers = {}
    self.numLayers = 0
    self.viewWidth = width
    self.viewHeight = height
    self.lastTime = stime()
    self.odd = false
end

--[[
Create a new scrolling layer

:param speed: float - rate of movment compared to the value put in `scrollTo`. Ex: 0.5
:returns: ParallaxLayer
]]--
function ParallaxView:newLayer(speed)     
    local layer = ParallaxLayer:new(speed)
    self.numLayers = self.numLayers + 1    
    self.layers[self.numLayers] = layer
    self.view:insert(layer.view)
    return layer
end

--[[
Add a column to an existing layer
]]--
function ParallaxView:addCol(layerNum, displayObj)
    return self.layers[layerNum]:addCol(displayObj)
end

--[[
Scroll the ParallaxView

:param x: float - x coordinate of "camera"
:param y: float - y coordinate of "camera" (default 0)
:param scale: float - scale of ParallaxView, used for camera zoooms (default 1) 
]]--
function ParallaxView:scrollTo(x, y, scale)
    local y = y or 0
    local scale = scale or 1

    self.odd = not self.odd

    local t = stime()
    local delta
    delta, self.lastTime = t - self.lastTime, t

    -- At 60 fps we can afford to render half of the layers on the even frames
    -- and the other half on the odd frames
    -- local start = self.odd and 1 or 2
    -- for i=start,self.numLayers,2 do
    --     local layer = self.layers[i]
    --     layer:scrollTo(x, y, scale)
    -- end

    for i=1,self.numLayers do
        local layer = self.layers[i]
        layer:scrollTo(x, y, scale)
    end

    -- BUG (Corona Version 2011.703) dispatchEvent before there are listeners causes this error:
    -- Runtime error
    --     ?:0: attempt to index a nil value
    -- stack traceback:
    --     [C]: ?
    --     ?: in function '?'
    --     ?: in function <?:215>

    if not self.odd then
        self.view:dispatchEvent{
            name = 'parallaxScroll', 
            target = self, 
            x = x,
            y = y,
            scale = scale,
            time = t,
            deltaTime = delta
        }    
    end
end

function ParallaxView:addEventListener(...)
    return self.view:addEventListener(...)
end

return ParallaxView