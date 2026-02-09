local QBCore = exports['qb-core']:GetCoreObject()

local rgbColors = {
    ['red'] = {255, 0, 0},
    ['green'] = {0, 255, 0},
    ['blue'] = {0, 0, 255},
    ['yellow'] = {255, 255, 0},
    ['pink'] = {255, 105, 180},
    ['purple'] = {128, 0, 128},
    ['teal'] = {0, 255, 255}
}

-- ATTACH: Consumes item and sets metadata
RegisterNetEvent('qb-laser:server:attachLaser', function(colorName)
    local src = source
    local ped = GetPlayerPed(src)
    local weapon = exports.ox_inventory:GetCurrentWeapon(src)

    if not weapon then 
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='Hold a gun first.'})
        return 
    end
    
    -- REMOVE ITEM: This ensures the taser_laser is taken from you
    local success = exports.ox_inventory:RemoveItem(src, 'taser_laser', 1)
    
    if success then
        local metadata = weapon.metadata or {}
        metadata.laserAttached = true
        metadata.laserColorName = colorName
        metadata.laserRGB = rgbColors[colorName] or {255, 0, 0}
        
        exports.ox_inventory:SetMetadata(src, weapon.slot, metadata)

        -- Sync state globally
        Entity(ped).state:set('laserColor', metadata.laserRGB, true)
        Entity(ped).state:set('laserActive', true, true)
        
        TriggerClientEvent('ox_lib:notify', src, {type='success', description='Laser attached! Tap E to toggle.'})
    else
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='You do not have a laser item.'})
    end
end)

-- TOGGLE: Server-side switch
RegisterNetEvent('qb-laser:server:toggle', function()
    local src = source
    local ped = GetPlayerPed(src)
    local weapon = exports.ox_inventory:GetCurrentWeapon(src)
    
    if weapon and weapon.metadata and weapon.metadata.laserAttached then
        local currentState = Entity(ped).state.laserActive
        Entity(ped).state:set('laserActive', not currentState, true)
        if not currentState then
            Entity(ped).state:set('laserColor', weapon.metadata.laserRGB, true)
        end
    end
end)