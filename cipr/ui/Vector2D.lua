-- Adapted from https://gist.github.com/1006414 and http://www.brandontreb.com/autonomous-steering-behaviors-corona-sdk/
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local rad = math.rad
local deg = math.deg
local atan2 = math.atan2
local atan = math.atan

Vector2D = {}

local function points(args)
    if #args == 1 then
        -- Another vector
        return args[1]
    elseif #args == 2 then
        -- X/Y
        return {x = args[1], y = args[2]}
    else
        return nil
    end    
end

function Vector2D:new(x, y)  
  local object = { x = x, y = y }
  setmetatable(object, { __index = Vector2D })  
  return object
end

function Vector2D:copy()
    return Vector2D:new(self.x, self.y)
end

function Vector2D:magnitude()
    return sqrt(self.x^2 + self.y^2)
end

function Vector2D:normalize()
    local temp
    temp = self:magnitude()
    if temp > 0 then
        self.x = self.x / temp
        self.y = self.y / temp
    end
end

function Vector2D:limit(l)
    if self.x > l then
        self.x = l      
    end
    
    if self.y > l then
        self.y = l      
    end
end

function Vector2D:equals(vec)
    if self.x == vec.x and self.y == vec.y then
        return true
    else
        return false
    end
end

function Vector2D:__add(vec)
    self.x = self.x + vec.x
    self.y = self.y + vec.y
end

function Vector2D:add(x, y)
    self.x = self.x + x
    self.y = self.y + y    
end

function Vector2D:__sub(vec)
    self.x = self.x - vec.x
    self.y = self.y - vec.y
end

function Vector2D:sub(x, y)
    self.x = self.x - x
    self.y = self.y - y
end

function Vector2D:__mul(s)
    self.x = self.x * s
    self.y = self.y * s
end

function Vector2D:mul(x, y)
    self.x = self.x * x
    self.y = self.y * y
end

function Vector2D:div(s)
    self.x = self.x / s
    self.y = self.y / s
end

function Vector2D:dot(other)
    return self.x * other.x + self.y * other.y
end

function Vector2D:dist(other)
    local xfactor = other.x-self.x
    local yfactor = other.y-self.y
    return sqrt((xfactor*xfactor) + (yfactor*yfactor))

    -- return sqrt( (other.x - self.x) + (other.y - self.y) )
end

function Vector2D:rotate(deg)
    ang = rad( deg )
    return Vector2D:new( self.x * cos( ang ) - self.y * sin( ang ), self.x * sin( ang ) + self.y * cos( ang ) )
end

function Vector2D:angle(other)
    local radians
    if other then
        radians = atan2(other.y - self.y, other.x - self.x)
    else
        radians = atan2(self.y, self.x)
    end
    
    return deg(radians)
end
    

return Vector2D