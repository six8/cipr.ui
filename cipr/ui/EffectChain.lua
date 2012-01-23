local cipr = require 'cipr'
local class = cipr.import('cipr.class')
local log = cipr.import('cipr.logging').getLogger(...)

--[[
An EffectChain allows you to chain many UI transitions together with
a simple interface.

Intitialize::

    local cipr = require 'cipr'
    local EffectChain = cipr.import('cipr.ui.EffectChain')

Bob up and down::

    local bob
    bob = EffectChain(obj):transition{
        y = y-200, time=2000, rotation=180, transition=easing.inOutQuad
    }:transition{
        y = y, time=2000, rotation=0, transition=easing.inOutQuad
    }:loop()
        
    bob:play()

Explode::

    pop = EffectChain(obj):scale{scale=4, alpha=0,time=200}:set{alpha=obj.alpha,isVisible=false}
    pop:play()

Blink::
    
    EffectChain(obj):blink{times=5}:play()

]]--

-- For each of the properties, call the setter associated with that property name.
-- For example, a property `foo` will be passed to `setFoo()`. If no setter exists,
-- it will try to set the property directly. Ex `obj.foo = value`.
local function set(target, properties)
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


local EffectChain = class.class('EffectChain')

function EffectChain:initialize(target)
    self.target = target
    self.paused = false
    self.tasks = {}
    self.pos = 0
    self.playing = false
    self.looping = false
    
    local this = self
    -- a convenience if you need to pass the play method as a callback
    self.playCallback = function()
        this:play()
    end
end

function EffectChain:on(target)
    local c = self:_clone()
    c.target = target
    return c
end

function EffectChain:addTask(cfg)
    self.tasks[#self.tasks+1] = cfg
end

function EffectChain:addTasks(tasks)
    for i=1,#tasks do
        self.tasks[#self.tasks+1] = tasks[i]
    end
end

function EffectChain:blink(cfg)
    local c = self:_clone()

    cfg = cfg or {}
    cfg.time = cfg.time or 200
    cfg.alpha = cfg.alpha or 0.5
    cfg.times = cfg.times or 2

    local onCfg = {}
    onCfg.time = cfg.time
    onCfg.alpha = 1

    for i=1,cfg.times do
        c:addTask{ type = 'transition.to', args = cfg }
        c:addTask{ type = 'transition.to', args = onCfg }
    end
    
    return c
end

function EffectChain:set(values)
    local c = self:_clone()

    c:addTask{ type = 'setter', values = values}
    
    return c
end

function EffectChain:transition(cfg)
    local c = self:_clone()

    cfg = cfg or {}
            
    c:addTask{ type = 'transition.to', args = cfg }    
    
    return c
end

function EffectChain:scale(cfg)
    local c = self:_clone()

    cfg = cfg or {}
    cfg.time = cfg.time or 300
    cfg.xScale = cfg.xScale or cfg.scale or 1
    cfg.yScale = cfg.yScale or cfg.scale or 1
    cfg.scale = nil
    
    c:addTask{ type = 'transition.to', args = cfg }    
    
    return c
end

function EffectChain:fadeOut(cfg)
    local c = self:_clone()

    cfg = cfg or {}
    cfg.time = cfg.time or 300
    cfg.alpha = 0

    c:addTask{ type = 'transition.to', args = cfg }
    -- Reset alpha and hide
    c:addTask{ type = 'setter', values = { alpha = 1, isVisible = false }}
    
    return c
end

function EffectChain:fadeIn(cfg)
    local c = self:_clone()

    cfg = cfg or {}
    cfg.time = cfg.time or 300
    cfg.alpha = 1
    
    c:addTask{ type = 'setter', values = { alpha = 0, isVisible = true }}
    c:addTask{ type = 'transition.to', args = cfg}
    
    return c
end

function EffectChain:loop()
    local c = self:_clone()
    c.looping = true
    return c 
end


function EffectChain:verticalStretchIn(cfg)
    local c = self:_clone()

    cfg = cfg or {}
    cfg.time = cfg.time or 300
    cfg.yScale = 1
    
    c:addTask{ type = 'setter', values = { alpha = 1, isVisible = true, yScale = 0.1 }}
    c:addTask{ type = 'transition.to', args = cfg}
    
    return c
end


local function isCallable(obj)
    return type(obj) == 'function' or (
        type(obj) == 'table' and obj.__call
    )
end

function EffectChain:call(callback, ...)
    assert(isCallable(callback), 'You must supply a callback function, got ' .. tostring(callback))

    local c = self:_clone()
    c:addTask{ type = 'callback', callback = callback, args = {...} }
    
    return c
end

function EffectChain:_clone()
    local c = EffectChain(self.target)
    c.looping = self.looping
    c:addTasks(self.tasks)
    return c
end

function EffectChain:_next()
    if self.paused then
        return
    end

    self.pos = self.pos + 1
    local task = self.tasks[self.pos]
    if not task then
        self.playing = false
        
        if self.looping then
            return self:play() 
        else
            return
        end                        
    end
    
    local this = self
    local transDone = function()
        self._trans = nil
        this._next(this)
    end

    if task.type == 'setter' then
        set(self.target, task.values)
        return self:_next()
    elseif task.type == 'transition.to' then
        local args = task.args
        args.onComplete = transDone
        
        self._trans = transition.to(self.target, args)
    elseif task.type == 'callback' then        
        local args = task.args        
        if not args then
            args = {self.target}
        end

        task.callback(unpack(args))
        return self:_next()
    end
end

function EffectChain:__call()
    self:play()
end

function EffectChain:pause()
    self.paused = true
    self.playing = false
    if self._trans then
        transition.cancel(self._trans)
        self._trans = nil
    end
end
    
function EffectChain:play()
    if self.playing then
        error('already playing')
    end

    self.pos = 0
    self.playing = true
    self.paused = false
    self:_next()
end

return EffectChain