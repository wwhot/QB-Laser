local QBCore = exports['qb-core']:GetCoreObject()

-- CONFIGURATION
local Config = { 
    MaxDistance = 950.0, 
    BaseDotSize = 0.01,     
    MaxDotSize = 0.06,      
    LightRange = 0.2,       
    LightIntensity = 0.8,   
    BeamAlpha = 150,        
    SyncInterval = 15,      -- Extremely fast updates (15ms)
}

-- EXPORT: Use Item
exports('useLaserItem', function(data, slot)
    local ped = PlayerPedId()
    if GetSelectedPedWeapon(ped) == `WEAPON_UNARMED` then
        lib.notify({type = 'error', description = 'Hold a gun first!'})
        return
    end

    local input = lib.inputDialog('Laser Sight', {
        { type = 'select', label = 'Color', options = {
            { value = 'red', label = 'Red' }, { value = 'green', label = 'Green' },
            { value = 'blue', label = 'Blue' }, { value = 'yellow', label = 'Yellow' },
            { value = 'teal', label = 'Teal' }, { value = 'pink', label = 'Pink' }
        }}
    })
    if input then TriggerServerEvent('qb-laser:server:attachLaser', input[1]) end
end)

-- COMMANDS
RegisterCommand('removelaser', function() TriggerServerEvent('qb-laser:server:removeLaser') end)
RegisterCommand('togglelaser', function() TriggerServerEvent('qb-laser:server:toggle') end)
RegisterKeyMapping('togglelaser', 'Toggle Laser', 'keyboard', 'E')

-- HELPER: Math
local function RotationToDirection(rotation)
    local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
    return direction
end

-- [[ THREAD 1: TARGET BROADCASTER ]]
-- Calculates where YOUR laser hits and sends that exact XYZ to the server.
CreateThread(function()
    local lastHit = vector3(0,0,0)
    
    while true do
        local sleep = 200
        local ped = PlayerPedId()
        local state = Entity(ped).state

        if state.laserActive and IsPlayerFreeAiming(PlayerId()) then
            sleep = Config.SyncInterval
            
            -- 1. Calculate Local Hit Point (The Truth)
            local camRot = GetGameplayCamRot()
            local camDir = RotationToDirection(camRot)
            local camPos = GetGameplayCamCoord()
            
            local endPos = camPos + (camDir * Config.MaxDistance)
            local handle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, endPos.x, endPos.y, endPos.z, -1, ped, 0)
            local _, hit, hitCoords = GetShapeTestResult(handle)
            
            local finalHit = (hit == 1) and hitCoords or endPos
            
            -- 2. Send to Network if it changed (Optimization)
            if #(finalHit - lastHit) > 0.05 then
                Entity(ped).state:set('laserHitSpot', finalHit, true)
                lastHit = finalHit
            end
        end
        Wait(sleep)
    end
end)

-- [[ THREAD 2: RENDER LOOP ]]
CreateThread(function()
    while true do
        local sleep = 500
        local activePlayers = GetActivePlayers()
        local myId = PlayerId()
        
        for _, player in ipairs(activePlayers) do
            local ped = GetPlayerPed(player)
            local state = Entity(ped).state
            
            if state.laserActive and state.laserColor then
                if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then
                    
                    local isAiming = false
                    if player == myId then
                        isAiming = IsPlayerFreeAiming(player)
                    else
                        isAiming = IsPedAimingFromCover(ped) or GetPedConfigFlag(ped, 78, 1) or IsPedShooting(ped)
                    end

                    if isAiming then
                        sleep = 0
                        local origin, target
                        local weaponEntity = GetCurrentPedWeaponEntityIndex(ped)
                        
                        -- [[ 1. ORIGIN (Gun Muzzle) ]]
                        if weaponEntity and DoesEntityExist(weaponEntity) then
                            local muzzleIndex = GetEntityBoneIndexByName(weaponEntity, "gun_muzzle")
                            if muzzleIndex ~= -1 then
                                origin = GetWorldPositionOfEntityBone(weaponEntity, muzzleIndex)
                            else
                                origin = GetEntityCoords(weaponEntity)
                            end
                        else
                            origin = GetPedBoneCoords(ped, 57005)
                        end

                        -- [[ 2. TARGET (Coordinate Sync) ]]
                        if player == myId then
                            -- LOCAL: Calculate Fresh (Zero Latency)
                            local camRot = GetGameplayCamRot()
                            local camDir = RotationToDirection(camRot)
                            local camPos = GetGameplayCamCoord()
                            local endPos = camPos + (camDir * Config.MaxDistance)
                            local handle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, endPos.x, endPos.y, endPos.z, -1, ped, 0)
                            local _, hit, hitCoords = GetShapeTestResult(handle)
                            target = (hit == 1) and hitCoords or endPos
                        else
                            -- NETWORKED: Read the Synced XYZ
                            -- We blindly trust the coordinate they sent us. 
                            -- If they say "Hit is at 100,50,5", we draw to 100,50,5.
                            local syncedHit = state.laserHitSpot
                            
                            if syncedHit then
                                target = syncedHit
                            else
                                -- Fallback (If packet loss): Use Head Rotation
                                local pedRot = GetEntityRotation(ped, 2)
                                local direction = RotationToDirection(pedRot)
                                local headPos = GetPedBoneCoords(ped, 31086)
                                local endPos = headPos + (direction * Config.MaxDistance)
                                local handle = StartShapeTestRay(headPos.x, headPos.y, headPos.z, endPos.x, endPos.y, endPos.z, -1, ped, 0)
                                local _, hit, hitCoords = GetShapeTestResult(handle)
                                target = (hit == 1) and hitCoords or endPos
                            end
                        end

                        -- [[ 3. DRAW ]]
                        local r, g, b = table.unpack(state.laserColor)
                        local dist = #(origin - target)
                        local currentSize = math.min(Config.MaxDotSize, Config.BaseDotSize + (dist * 0.0003))

                        -- Beam
                        DrawLine(origin.x, origin.y, origin.z, target.x, target.y, target.z, r, g, b, Config.BeamAlpha)

                        -- Dot
                        DrawMarker(28, target.x, target.y, target.z, 
                            0, 0, 0, 0, 0, 0, 
                            currentSize, currentSize, currentSize, 
                            r, g, b, 200, 
                            false, false, 2, nil, nil, false
                        )

                        -- Glow
                        DrawLightWithRange(target.x, target.y, target.z, r, g, b, Config.LightIntensity, Config.LightRange)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)