local min = math.min
local max = math.max
local floor = math.floor
local sformat = string.format

-- TODO Add graphs http://developer.anscamobile.com/forum/2011/02/28/fspmemory-profiler-swfprofiler-ported-corona

local _M = {}

local function fpsText(fps, minLastFps, maxLastFps, avgFps)
    return sformat('%02d (min %02d max %02d avg %02d)', fps, minLastFps, maxLastFps, avgFps)
end

local function memText()    
    return sformat('%.2fkb', collectgarbage('count'))
end

local function txtMemText()
    return sformat('%.4fmb', system.getInfo("textureMemoryUsed")/1000000)
end

local function touch(x, y)
    return sformat('%dx%d', x, y)
end

local function makeLabels(labels)
    local group = display.newGroup()

    local y = -3
    local x = 20
    for i=1,#labels do
        local label = labels[i]
        local width = label.width
        local labelText = display.newText(label.label .. ':', x, y, system.nativeFont, 10)
        local valueText = display.newText('-', x, y + 13, system.nativeFont, 12)

        labelText:setTextColor(255,255,255, 200)
        valueText:setTextColor(255,255,255, 200)

        local labelGroup = display.newGroup()
        labelGroup:insert(labelText)
        labelGroup:insert(valueText)

        if label.onTap then
            labelGroup:addEventListener('tap', label.onTap)
        end

        group:insert(labelGroup)

        -- labelText:setReferencePoint(display.CenterLeftReferencePoint)
        -- labelText.x = 0

        -- valueText:setReferencePoint(display.CenterLeftReferencePoint)
        -- valueText.x = 50

        local startX = valueText.x
        group[label.id] = {}
        group[label.id].set = function(value)
            valueText.text = value
            valueText.x = startX + valueText.contentWidth/2
        end

        group[label.id].warn = function()
            valueText:setTextColor(255,0,0,200)
        end

        group[label.id].clear = function()
            valueText:setTextColor(255,255,255,200)
        end

        x = x + width
    end

    return group
end

local function averager(len)
  local t = {}  
  local numT = 0
  local function average(n)
    if numT == len then 
        table.remove(t, 1) 
        numT = numT - 1
    end

    numT = numT + 1
    t[numT] = n
    
    local sum = 0
    for i=1,numT do
        sum = sum + t[i]
    end
    return sum / numT
  end

  return average
end

function _M:new()
    local xClosed = display.contentWidth - 18    
    local group = display.newGroup()    
    group.x = xClosed
    local width, height = display.contentWidth, 30

    local background = display.newRect(0, 0, width - 18, height)
    background:setFillColor(0, 0, 0, 150)
    background.x = width/2 + 9
    background.y = height/2

    group:insert(background)

    local pull = display.newRect(0, 0, 18, height)
    pull:setFillColor(0, 0, 0, 175)

    group:insert(pull)

    local arrow = display.newLine(12, 8, 6, height / 2)
    arrow:append(12, height - 8)
    arrow:setColor(255, 255, 255, 200)
    arrow.width = 3

    group:insert(pull)
    group:insert(arrow)

    local isOpen = false
    local function close()
        if group.x ~= xClosed then
            transition.to(group, {x = xClosed, time = 200, transition = easing.outQuad})
            transition.to(arrow, {xScale = 1, x = 12, time = 700, transition = easing.outQuad})
            
            if isOpen then
                isOpen = false
                group:dispatchEvent({name='close', target=group})
            end
        end
    end

    local function open()
        if group.x ~= 0 then
            transition.to(group, {x = 0, time = 200, transition = easing.outQuad})
            transition.to(arrow, {xScale = -1, x = 6, time = 700, transition = easing.outQuad})

            if not isOpen then
                isOpen = true
                group:dispatchEvent({name='open', target=group})
            end
        end
    end
                
    local function drag(event)
        local phase = event.phase

        if phase == 'began' then
            display.getCurrentStage():setFocus(pull)
        elseif phase == 'moved' then        
            group.x = max(0, min(event.x, xClosed))
        elseif phase == 'ended' or phase == 'cancelled' then
            if (event.x - event.xStart) > 50 then
                close()
            elseif (event.x - event.xStart) < -50 then
                open()
            elseif isOpen then
                open()
            else
                close()
            end

            display.getCurrentStage():setFocus(nil)
        end

        return true
    end

    pull:addEventListener('touch', drag)

    local function freeMem()
        print('Free memory')
        collectgarbage()
    end

    local stats = makeLabels{
        { id = 'Mem', label = 'Memory', width = 80, onTap=freeMem },
        { id = 'TexMem', label = 'Texture Mem.', width = 100 },
        { id = 'Touch', label = 'Touch', width = 80 },
        { id = 'FPS', label = 'FPS', width = 200 },
    }

    group:insert(stats)

    local lastFps = nil
    local minLastFps = 1000
    local maxLastFps = 0
    local avgFps = 0
    local prevTime = system.getTimer()
    local fpsDelay = 2000
    local nextFpsTime = prevTime + fpsDelay
    local maxSavedFps = 30

    local fpsData = averager(10)
    local function calc(dt, frames, it)
        fps = frames / (dt / 1000)
        avgFps = fpsData(fps)

        if (it % 10) == 0 then
            minLastFps = fps
            maxLastFps = fps            
        else
            minLastFps = min(fps, minLastFps)
            maxLastFps = max(fps, maxLastFps)
        end

        stats.Mem.set(memText())
        stats.TexMem.set(txtMemText())        
        stats.FPS.set(fpsText(fps, minLastFps, maxLastFps, avgFps))
    end

    local frames = 0 
    local iterations = 0
    local function enterFrame(event)
        frames = frames + 1

        local time = event.time
        local dt = time - prevTime
                
        if dt >= 1000 then
            calc(dt, frames, iterations)
            frames = 0
            prevTime = time
            iterations = iterations + 1
        end        
    end    

    local function onTouch(event)
        stats.Touch.set(touch(event.x, event.y))
    end

    local calcTimer
    local function onOpen()
        -- calcTimer = timer.performWithDelay(500, calcMem, 0)
        Runtime:addEventListener('enterFrame', enterFrame)  
        
        stats.Mem.set('-')
        stats.TexMem.set('-')        
        stats.FPS.set('-')          
    end

    local function onClose()
        if calcTimer then
            timer.cancel(calcTimer)
            calcTimer = nil
        end

        Runtime:removeEventListener('enterFrame', enterFrame)    
    end

    
    group:addEventListener('open', onOpen)
    group:addEventListener('close', onClose)

    local touchRect = display.newRect(0, 0, display.contentWidth, display.contentHeight)
    touchRect:setFillColor(0, 0, 0, 0)

    touchRect:addEventListener('touch', onTouch)

    local function handleLowMemory(event)
        print('WARNING: Low memory!')
        open()
        stats.Mem.warn()
        stats.TexMem.warn()
    end

    Runtime:addEventListener('memoryWarning', handleLowMemory)

    return group
end

return _M