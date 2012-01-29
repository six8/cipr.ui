=======
Cipr UI
=======

User interface utilities for Corona

Installation
============

Installation is done with `cipr <http://github.com/six8/corona-cipr>`_

::

    cipr install git://github.com/six8/cipr.ui.git

Usage
=====

Some examples. See `Getting started with Cipr <http://devdetails.com/2012/01/24/getting-started-with-cipr/>`_
for more examples.

See source for full functionality.


EffectChain
-----------

Transitions are a powerful feature of Corona. Often you need to run several transitions on a single object before finally destroying it. In this example, we'll create a mini-particle engine that will use EffectChain to power animations.

::

    local EffectChain = cipr.import 'cipr.ui.EffectChain'
    local random = math.random

    local particleGroup = display.newGroup()

    -- EffectChains are re-usable
    local popBubble = EffectChain():
        fadeIn{time=500}:
        transition{y=10, time=400, transition=easing.inExpo}:
        scale{scale=4, alpha=0,time=200}:
        call(display.remove)

    --[[
    Create a randomly sized particle and make it float and pop
    ]]--
    local function addNewParticle()
        local x = random(20, display.contentWidth - 20)
        local y = random(100, display.contentHeight - 20)
        local particle = display.newCircle(particleGroup, x, y, random(5, 20))
        particle:setFillColor(255, 255, 255, 200)

        -- Clone the EffectChain for this particle and play it
        popBubble:on(particle):play()
    end 

    timer.performWithDelay(100, addNewParticle, -2)

ParallaxView
------------

Almost every 2D game has a Parallax background. ParallaxView makes it easy to create these types of backgrounds.

::

    local ParallaxView = cipr.import 'cipr.ui.widgets.ParallaxView'

    local background = display.newGroup()

    local pview = ParallaxView(display.contentWidth, display.contentHeight)
    background:insert(pview)
    background.y = display.contentHeight

    -- This layer moves at 1/4 the speed
    local layer1 = pview:newLayer(0.25)

    local bgA = display.newRect(0, 0, 400, 220)
    bgA:setFillColor(120, 120, 120)

    local bgB = display.newRect(0, 0, 400, 280)
    bgB:setFillColor(140, 140, 140)

    local bgC = display.newRect(0, 0, 400, 200)
    bgC:setFillColor(160, 160, 160)

    layer1:addCol(bgA)
    layer1:addCol(bgB)
    layer1:addCol(bgC)  

    -- This layer moves at half the speed
    local layer2 = pview:newLayer(0.5)

    -- A layer must have at least 2 columns. The width of all 
    -- the cols combined must be at least the width of the view
    -- in order to loop properly
    local bg1 = display.newRect(0, 0, 300, 120)
    bg1:setFillColor(90, 90, 90)

    local bg2 = display.newRect(0, 0, 300, 80)
    bg2:setFillColor(50, 50, 50)

    local bg3 = display.newRect(0, 0, 300, 100)
    bg3:setFillColor(75, 75, 75)

    layer2:addCol(bg1)
    layer2:addCol(bg2)
    layer2:addCol(bg3)


    local x = 0
    local function enterFrame()
        x = x + 10
        pview:scrollTo(x, 0, 1)    
    end

    Runtime:addEventListener('enterFrame', enterFrame)