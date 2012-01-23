local sformat = string.format
local sprite = require 'sprite'
local cipr = require 'cipr'
local class = cipr.import('cipr.class')

local SpriteSheet = class.class('cipr.ui.SpriteSheet')

--[[
:param image: path to source image
:param sheetData:

local objectsSpriteSheet = SpriteSheet('sprites/objects.png', require('sprites-objects').getSpriteSheetData())

]]--
function SpriteSheet:initialize(image, sheetData)
    self.sheetData = sheetData
    self.image = image
    self.spriteSheet = sprite.newSpriteSheetFromData(self.image, self.sheetData)
    self.spriteSet = sprite.newSpriteSet(self.spriteSheet, 1, #self.sheetData.frames)

    self._frameIndex = {}
    self._frameNumIndex = {}
    for i=1,#self.sheetData.frames do
        local f = self.sheetData.frames[i]
        sprite.add(self.spriteSet, f.name, i, 1, 1)
        self._frameIndex[f.name] = f
        self._frameNumIndex[f.name] = i
    end    
end

--[[
Returns a single sprite frame (no animation) with the correct
width and height for the frame.
]]--
function SpriteSheet:newSpriteCel(name)
    local frame = self:getFrameData(name)
    
    local s = sprite.newSprite( self.spriteSet )
    s:prepare(name)
    
    -- Overwrite width and height with the original image's height
    s.width = frame.spriteSourceSize.width
    s.height = frame.spriteSourceSize.height
    -- s.contentWidth = s.width
    -- s.contentHeight = s.height
    return s
end

function SpriteSheet:addAnimation(nameTemplate, numFrames, time, loop)
    local frames = {}
    for i=1,numFrames do
        local name = sformat(nameTemplate, i)
        frames[#frames+1] = self._frameNumIndex[name]
    end

    local set = sprite.newSpriteMultiSet({
        { sheet = self.spriteSheet, frames = frames }  
    })

    sprite.add(set, nameTemplate, 1, #frames, time, loop)

    return function()
        local s = sprite.newSprite(set)
        s:prepare(nameTemplate)
        return s
    end
end

function SpriteSheet:getFrameData(name)
    assert(name, 'Name must not be empty.')

    local frame = self._frameIndex[name]
    if not frame then
        error('Could not find frame ' .. name)
    end
    
    return frame
end

function SpriteSheet:destroy()
    self.spriteSheet:dispose()
end    


return SpriteSheet