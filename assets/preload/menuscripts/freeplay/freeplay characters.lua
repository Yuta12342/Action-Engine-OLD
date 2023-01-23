--[[
    Local freeplay variables:
        curSelectedDifficulty
        curSelectedDifficultyString
        curSongSelected
]]
function onCreatePost()
    makeLuaSprite('offset', nil, 700, 0)

    makeAnimatedLuaSprite('gf', 'characters/GF_assets', 700, 0)
    addAnimationByPrefix('gf', 'idle', 'GF Dancing Beat0', 24, true)
    scaleObject('gf', 0.75, 0.75)
    screenCenter('gf', 'y')
    setScrollFactor('gf', 0, 0)
    addLuaSprite('gf', true)

    makeAnimatedLuaSprite('dad', 'characters/DADDY_DEAREST', 850, 0)
    addAnimationByPrefix('dad', 'idle', 'Dad idle dance0', 24, true)
    setProperty('dad.flipX', true)
    scaleObject('dad', 0.75, 0.75)
    screenCenter('dad', 'y')
    setScrollFactor('dad', 0, 0)
    addLuaSprite('dad', true)
    
    makeAnimatedLuaSprite('spooky_kids', 'characters/spooky_kids_assets', 850, 0)
    addAnimationByPrefix('spooky_kids', 'idle', 'spooky dance idle', 24, true)
    setProperty('spooky_kids.flipX', true)
    scaleObject('spooky_kids', 0.75, 0.75)
    setProperty('spooky_kids.angle', -2)
    screenCenter('spooky_kids', 'y')
    setScrollFactor('spooky_kids', 0, 0)
    addLuaSprite('spooky_kids', true)

    makeAnimatedLuaSprite('monster', 'characters/Monster_Assets', 850, 0)
    addAnimationByPrefix('monster', 'idle', 'monster idle', 24, true)
    setProperty('monster.flipX', true)
    scaleObject('monster', 0.75, 0.75)
    setProperty('monster.angle', -5)
    screenCenter('monster', 'y')
    setScrollFactor('monster', 0, 0)
    addLuaSprite('monster', true)
    
    makeAnimatedLuaSprite('pico', 'characters/Pico_FNF_assetss', 850, 0)
    addAnimationByPrefix('pico', 'idle', 'Pico Idle Dance0', 24, true)
    --setProperty('pico.flipX', true)
    scaleObject('pico', 0.75, 0.75)
    screenCenter('pico', 'y')
    setScrollFactor('pico', 0, 0)
    addLuaSprite('pico', true)
    
    makeAnimatedLuaSprite('mom', 'characters/Mom_Assets', 850, 0)
    addAnimationByPrefix('mom', 'idle', 'Mom Idle0', 24, true)
    setProperty('mom.flipX', true)
    scaleObject('mom', 0.75, 0.75)
    screenCenter('mom', 'y')
    setScrollFactor('mom', 0, 0)
    addLuaSprite('mom', true)
    
    makeAnimatedLuaSprite('parents', 'characters/mom_dad_christmas_assets', 600, 0)
    addAnimationByPrefix('parents', 'idle', 'Parent Christmas Idle0', 24, true)
    setProperty('parents.flipX', true)
    scaleObject('parents', 0.75, 0.75)
    screenCenter('parents', 'y')
    setScrollFactor('parents', 0, 0)
    addLuaSprite('parents', true)
    
    makeAnimatedLuaSprite('monsterChristmas', 'characters/monsterChristmas', 950, 0)
    addAnimationByPrefix('monsterChristmas', 'idle', 'monster idle', 24, true)
    setProperty('monsterChristmas.flipX', true)
    scaleObject('monsterChristmas', 0.75, 0.75)
    setProperty('monsterChristmas.angle', -5)
    screenCenter('monsterChristmas', 'y')
    setScrollFactor('monsterChristmas', 0, 0)
    addLuaSprite('monsterChristmas', true)
    
    makeAnimatedLuaSprite('senpai', 'characters/senpai', 700, 0)
    addAnimationByPrefix('senpai', 'idleNorm', 'Senpai Idle instance 10', 24, true)
    addAnimationByPrefix('senpai', 'idleAngor', 'Angry Senpai Idle instance 10', 24, true)
    setProperty('senpai.flipX', true)
    setProperty('senpai.antialiasing', false)
    scaleObject('senpai', 4.75, 4.75)
    screenCenter('senpai', 'y')
    setScrollFactor('senpai', 0, 0)
    addLuaSprite('senpai', true)
    
    makeAnimatedLuaSprite('spirit', 'characters/spirit', 700, 0)
    addAnimationByPrefix('spirit', 'idle', 'idle spirit_', 24, true)
    setProperty('spirit.flipX', true)
    setProperty('spirit.antialiasing', false)
    scaleObject('spirit', 4.75, 4.75)
    screenCenter('spirit', 'y')
    setScrollFactor('spirit', 0, 0)
    addLuaSprite('spirit', true)
    
    makeAnimatedLuaSprite('tankman', 'characters/tankmanCaptain', 850, 0)
    addAnimationByPrefix('tankman', 'idle', 'Tankman Idle Dance 10', 24, true)
    --setProperty('tankman.flipX', true)
    scaleObject('tankman', 0.75, 0.75)
    screenCenter('tankman', 'y')
    setScrollFactor('tankman', 0, 0)
    addLuaSprite('tankman', true)
end
function changeSelectedSong(name)
    if name == "Senpai" then 
        playAnim('senpai', 'idleNorm', true)
    elseif name == "Roses" then
        playAnim('senpai', 'idleAngor', true)
    end
    if offset == 700 then
        doTweenX('offsetOut', 'offset', 0, 1, 'quartOut')
    end
    --debugPrint(name)
end
function onUpdate(elapsed)
    offset = getProperty('offset.x')
    if curSongSelected == "Tutorial" then
        setProperty('gf.visible', true)
    else
        setProperty('gf.visible', false)
    end
    if curSongSelected == "Bopeebo" or curSongSelected == "Fresh" or curSongSelected == "Dad Battle" then
        setProperty('dad.visible', true)
    else
        setProperty('dad.visible', false)
    end
    if curSongSelected == "Spookeez" or curSongSelected == "South" then
        setProperty('spooky_kids.visible', true)
    else
        setProperty('spooky_kids.visible', false)
    end
    if curSongSelected == "Monster" then
        setProperty('monster.visible', true)
    else
        setProperty('monster.visible', false)
    end
    if curSongSelected == "Pico" or curSongSelected == "Philly Nice" or curSongSelected == "Blammed" then
        setProperty('pico.visible', true)
    else
        setProperty('pico.visible', false)
    end
    if curSongSelected == "Satin Panties" or curSongSelected == "High" or curSongSelected == "Milf" then
        setProperty('mom.visible', true)
    else
        setProperty('mom.visible', false)
    end
    if curSongSelected == "Cocoa" or curSongSelected == "Eggnog" then
        setProperty('parents.visible', true)
    else
        setProperty('parents.visible', false)
    end
    if curSongSelected == "Winter Horrorland" then
        setProperty('monsterChristmas.visible', true)
    else
        setProperty('monsterChristmas.visible', false)
    end
    if curSongSelected == "Senpai" or curSongSelected == "Roses" then
        setProperty('senpai.visible', true)
    else
        setProperty('senpai.visible', false)
    end
    if curSongSelected == "Thorns"  then
        setProperty('spirit.visible', true)
    else
        setProperty('spirit.visible', false)
    end
    if curSongSelected == "Ugh" or curSongSelected == "Guns" or curSongSelected == "Stress" then
        setProperty('tankman.visible', true)
    else
        setProperty('tankman.visible', false)
    end
    setProperty('gf.x', 700 + offset)
    setProperty('dad.x', 850 + offset)
    setProperty('spooky_kids.x', 850 + offset)
    setProperty('monster.x', 850 + offset)
    setProperty('pico.x', 850 + offset)
    setProperty('mom.x', 850 + offset)
    setProperty('parents.x', 600 + offset)
    setProperty('monsterChristmas.x', 950 + offset)
    setProperty('senpai.x', 700 + offset)
    setProperty('spirit.x', 700 + offset)
    setProperty('tankman.x', 850 + offset)
end
function changeDifficulty(diffInt, diffName)
    --debugPrint("Name: " .. diffName .. ", Value: " .. diffInt)
end