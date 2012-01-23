local cipr = require 'cipr'
local class = cipr.import('cipr.class')
local DisplayGroupMixin = cipr.import('cipr.ui.mixins.DisplayGroupMixin')

--[[
Make a button out of any display object.
]]--

local Button = class.class('cipr.ui.widgets.Button'):include(DisplayGroupMixin)

-- For each of the properties, call the setter associated with that property name.
-- For example, a property `foo` will be passed to `setFoo()`. If no setter exists,
-- it will try to set the property directly. Ex `obj.foo = value`.
function set(target, properties)
    for key, value in pairs(properties) do
        local funcName = 'set' .. key:gsub('^%l', string.upper)

        local func = target[funcName]
        if func then
            func(target, unpack(value))
        else
            target[key] = value
        end
    end
end

local function makeRect(config)
    local rect = display.newRect(0, 0, 100, 20)
    local r, g, b, a = unpack(config.color)
    
    rect:setFillColor(r, g, b, a or 255)
    
    local size, r, g, b, a = unpack(config.border)    
    rect:setStrokeColor(r, g, b, a or 255)
    rect.strokeWidth = size
    rect:setReferencePoint(display.CenterReferencePoint)
    rect.x = 0
    rect.y = 0
    
    return rect
end

local function initObj(obj)
    if obj.cobj then
        local o = obj.cobj
        obj.cobj = nil
        o:setReferencePoint(display.CenterReferencePoint)
        o.x = 0
        o.y = 0
        set(o, obj)
        return o
    else
        obj.x = 0
        obj.y = 0
        return obj
    end
end

function Button:initialize(config)
    self._config = config
    self.isFocus = false
    
    if config.parent then
        config.parent:insert(self)
    end
    
    self.backgrounds = {
        objs = {},
        activate = function(self, bg)
            for _, v in pairs(self.objs) do
                v.isVisible = false
            end
            
            self.objs[bg].isVisible = true
        end
    }
    
    if config.background then
        self.backgrounds.objs.default = initObj(config.background)
        self:insert(self.backgrounds.objs.default)
    else        
        self.backgrounds.objs.default = makeRect{color={0, 0, 0}, border={3, 255, 255, 255}}
        self:insert(self.backgrounds.objs.default)        
    end

    self.btnWidth = self.backgrounds.objs.default.width

    if config.pressedBackground then
        self.backgrounds.objs.pressed = initObj(config.pressedBackground)
        self:insert(self.backgrounds.objs.pressed)
    elseif config.background then
        self.backgrounds.objs.pressed = self.backgrounds.objs.default
    else
        self.backgrounds.objs.pressed = makeRect{color={200, 200, 200}, border={3, 255, 255, 255}}
        self:insert(self.backgrounds.objs.pressed)
    end
    
    if config.text then
        self:setText(config.text)
    end
    
    self.backgrounds:activate('default')
    
    for _, k in pairs({'x', 'y', 'xScale', 'yScale'}) do
        if config[k] then
            self[k] = config[k]
        end
    end
    
        
    self:addEventListener('touch', self)
end

function Button:setText(config)
    local size = 10
    local color = {255, 255, 255}
    local font = system.nativeFont
    local text = ''
    local align = 'center'
    local padding = 0

    if type(config) == 'table' then
        color = config.color or color
        size  = config.size or size
        font  = config.font or font
        text  = config.text or text
        align = config.align or align
        padding = config.padding or padding
    else
        text = config
    end

    if self.textBox and self.textBox.font ~= font then
        -- Remove the text and redraw it for the new font
        display.remove(self.textBox)
        self.textBox = nil
    end

    local refPoint = display.CenterReferencePoint
    if align == 'left' then
        refPoint = display.CenterLeftReferencePoint
    elseif align == 'right' then
        refPoint = display.CenterRightReferencePoint
    end

    if not self.textContainer then
        self.textContainer = display.newGroup()
        self:insert(self.textContainer)
    end

    if not self.textBox then
        self.textBox = display.newText(text, 0, 0, font, size)
        self.textBox.font = font
        self.textContainer:insert(self.textBox)
    end
    
    self.textBox:setTextColor(unpack(color))    
    self.textBox.text = text
    self.textBox.size = size

    self.textContainer:setReferencePoint(refPoint)

    if align == 'left' then
        self.textContainer.x = (self.btnWidth / -2) + padding
        self.textContainer.y = 0
    elseif align == 'right' then
        self.textContainer.x = (self.btnWidth / 2) - padding
        self.textContainer.y = 0
    else
        self.textContainer.x = 0
        self.textContainer.y = 0
    end
end

function Button:_onEvent(event)
    if self._config.onEvent then
        return self._config.onEvent(event)
    end
end

function Button:_onPress(event)
    local buttonEvent = { phase = 'press' }
    
    if self:_onEvent(buttonEvent) then
        -- event was handled
        return true
    end
    
    if  self._config.onPress then
        return self._config.onPress(buttonEvent)
    end
end

function Button:_onRelease(event)
    local buttonEvent = { phase = 'release' }
    
    if self:_onEvent(buttonEvent) then
        -- event was handled
        return true
    end
    
    if self._config.onRelease then
        return self._config.onRelease(buttonEvent)
    end
end

function Button:touch(event)
    local phase = event.phase
    local result
    
    if 'began' == phase then
        self.backgrounds:activate('pressed')
        
        result = self:_onPress(event)

        -- Subsequent touch events will target button even if they are outside the contentBounds of button
        display.getCurrentStage():setFocus( self, event.id )
        self.isFocus = true
    
    elseif self.isFocus then
        local bounds = self.contentBounds
        local x, y = event.x, event.y
        local isWithinBounds = 
            bounds.xMin <= x and bounds.xMax >= x and bounds.yMin <= y and bounds.yMax >= y

        if 'moved' == phase then
            if isWithinBounds then
                self.backgrounds:activate('pressed')
            else
                self.backgrounds:activate('default')
            end        
        elseif 'ended' == phase or 'cancelled' == phase then 
            self.backgrounds:activate('default')
        
            if 'ended' == phase then
                -- Only consider this a 'click' if the user lifts their finger inside button's contentBounds
                if isWithinBounds then
                    result = self:_onRelease(event)
                end
            end
        
            -- Allow touch events to be sent normally to the objects they 'hit'
            display.getCurrentStage():setFocus( self, nil )
            self.isFocus = false
        end
    end
    
    return true
end

return Button