local QBCore = exports['qb-core']:GetCoreObject()

-- CONFIGURATION
local rgbColors = {
    ['red'] = {255, 0, 0},
    ['green'] = {0, 255, 0},
    ['blue'] = {0, 0, 255},
    ['yellow'] = {255, 255, 0},
    ['pink'] = {255, 105, 180},
    ['purple'] = {128, 0, 128},
    ['teal'] = {0, 255, 255}
}

-- [[ EVENT: ATTACH LASER ]]
-- Consumes the item and applies metadata to the current weapon
RegisterNetEvent('qb-laser:server:attachLaser', function(colorName)
    local src = source
    local ped = GetPlayerPed(src)
    local weapon = exports.ox_inventory:GetCurrentWeapon(src)

    if not weapon then 
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Hold a gun first.'})
        return 
    end
    
    -- Check if weapon already has a laser
    if weapon.metadata and weapon.metadata.laserAttached then
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='This weapon already has a laser!'})
        return
    end

    -- Attempt to remove the item from inventory
    local success = exports.ox_inventory:RemoveItem(src, 'taser_laser', 1)
    
    if success then
        local metadata = weapon.metadata or {}
        metadata.laserAttached = true
        metadata.laserColorName = colorName
        metadata.laserRGB = rgbColors[colorName] or {255, 0, 0}
        
        exports.ox_inventory:SetMetadata(src, weapon.slot, metadata)

        -- Sync state globally via State Bags
        Entity(ped).state:set('laserColor', metadata.laserRGB, true)
        Entity(ped).state:set('laserActive', true, true)
        
        TriggerClientEvent('ox_lib:notify', src, {type='success', description='Laser attached! Tap E to toggle.'})
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='You do not have a laser item.'})
    end
end)

-- [[ EVENT: REMOVE LASER ]]
-- Strips metadata and gives the item back to the player
RegisterNetEvent('qb-laser:server:removeLaser', function()
    local src = source
    local ped = GetPlayerPed(src)
    local weapon = exports.ox_inventory:GetCurrentWeapon(src)

    if weapon and weapon.metadata and weapon.metadata.laserAttached then
        local metadata = weapon.metadata
        
        -- 1. Strip the laser-specific metadata
        metadata.laserAttached = nil
        metadata.laserColorName = nil
        metadata.laserRGB = nil
        
        exports.ox_inventory:SetMetadata(src, weapon.slot, metadata)

        -- 2. Kill the visual state immediately
        Entity(ped).state:set('laserActive', false, true)
        Entity(ped).state:set('laserColor', nil, true)

        -- 3. Give the item back
        local canAdd = exports.ox_inventory:AddItem(src, 'taser_laser', 1)
        
        if canAdd then
            TriggerClientEvent('ox_lib:notify', src, {type='success', description='Laser removed and returned to inventory.'})
        else
            -- Note: If inventory is full, this may fail depending on ox_inventory config
            TriggerClientEvent('ox_lib:notify', src, {type='warning', description='Laser removed, but your inventory was full!'})
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='This weapon does not have a laser attached.'})
    end
end)

-- [[ EVENT: TOGGLE LASER ]]
-- Simple on/off switch for the player currently holding the weapon
RegisterNetEvent('qb-laser:server:toggle', function()
    local src = source
    local ped = GetPlayerPed(src)
    local weapon = exports.ox_inventory:GetCurrentWeapon(src)
    
    if weapon and weapon.metadata and weapon.metadata.laserAttached then
        local currentState = Entity(ped).state.laserActive
        Entity(ped).state:set('laserActive', not currentState, true)
        
        -- Ensure the color is still synced if turning back on
        if not currentState then
            Entity(ped).state:set('laserColor', weapon.metadata.laserRGB, true)
        end
    end
end)