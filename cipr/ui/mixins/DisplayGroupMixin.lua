require 'middleclass-extras'
local Indexable = Indexable

local DisplayGroup = {}
local proxyKeys = {
    -- See http://developer.anscamobile.com/reference/index/common-properties
    alpha = 'alpha',
    contentBounds = 'contentBounds',
    contentHeight = 'contentHeight',
    contentWidth = 'contentWidth',
    height = 'height',
    isHitTestMasked = 'isHitTestMasked',
    isHitTestable = 'isHitTestable',
    isVisible = 'isVisible',
    maskRotation = 'maskRotation',
    maskScaleX = 'maskScaleX',
    maskScaleY = 'maskScaleY',
    maskX = 'maskX',
    maskY = 'maskY',
    parent = 'parent',
    rotation = 'rotation',
    width = 'width',
    x = 'x',
    xOrigin = 'xOrigin',
    xReference = 'xReference',
    xScale = 'xScale',
    y = 'y',
    yOrigin = 'yOrigin',
    yReference = 'yReference',
    yScale = 'yScale',
    textContainer = 'textContainer',
    textBox = 'textBox'
}

local proxyReadKeys = {
    -- See http://developer.anscamobile.com/content/group-display-objects
    numChildren = 'numChildren',
}

for k, v in pairs(proxyKeys) do
    proxyReadKeys[k] = v
end

local proxyMethods = {
    -- See http://developer.anscamobile.com/content/group-display-objects
    insert = 'insert',
    remove = 'remove',
    -- See http://developer.anscamobile.com/content/common-methods
--    addEventListener = 'addEventListener',
    contentToLocal = 'contentToLocal',
    dispatchEvent = 'dispatchEvent',
    localToContent = 'localToContent',
    removeEventListener = 'removeEventListener',
    removeSelf = 'removeSelf',
    rotate = 'rotate',
    scale = 'scale',
    setMask = 'setMask',
    setReferencePoint = 'setReferencePoint',
    toBack = 'toBack',
    toFront = 'toFront',
    translate = 'translate',
}

local function _modifyClassDictionaryLookup(theClass)
    local classDict = theClass.__classDict

    for key, name in pairs(proxyMethods) do
        -- Make sure viewFunc is called on view instance
        classDict[key] = function(mySelf, ...)
            local f = mySelf.__view__[name]
            f(mySelf.__view__, ...)
        end
    end
end

local function _modifyClassAllocate(theClass)
    local oldAllocate = theClass.allocate

    function theClass.allocate(theClass, ...)
        local instance = oldAllocate(theClass, ...)
        local view = display.newGroup()
        rawset(instance, '__view__', view)
        rawset(instance, '__localKeys__', {})
        rawset(instance, '_proxy', view._proxy)
        rawset(instance, '_class', view._class)

        local mt = getmetatable(instance)
        local prevIndex = mt.__newindex

        mt.__newindex = function(self, name, value)
            local pk = proxyKeys[name]
            if pk then
                self.__view__[pk] = value
            else
                self.__localKeys__[name] = true
                rawset(self, name, value)
            end
        end

        return instance
    end
end

function DisplayGroup:included(theClass)
    if includes(DisplayGroup, theClass) then return end

    Indexable:included(theClass)
    _modifyClassAllocate(theClass)
    _modifyClassDictionaryLookup(theClass)
end

--[[
Called when accessing an attribute that doesn't exist on the class directly
]]--
function DisplayGroup:index(name)
    local pk = proxyReadKeys[name]
    if pk then
        return self.__view__[pk]
    elseif self.__localKeys__[name] then
        -- Previously set, but at some point set to nil
        return nil
    else
        print(string.format('Trying to access a non-property %s', name))
        return nil
    end
end

function DisplayGroup:addEventListener(eventName, listener)
    local callback
    if type(listener) == 'table' then
        local instance = listener
        local eventHandler = listener[eventName]
        callback = function(event)
            -- Make sure target is self
            if event.target == self.__view__ then
                event.target = self
            end
                    
            return eventHandler(instance, event)
        end
    else
        callback = function(event)
            -- Make sure target is self
            if event.target == self.__view__ then
                event.target = self
            end
            
            return listener(event)
        end
    end

    self.__view__:addEventListener(eventName, callback)
end

return DisplayGroup