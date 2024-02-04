local QBCore = exports['qb-core']:GetCoreObject()
local searchedProps = {} 
local isInteracting = false


function CustomNotify(msg, type, length)
    if Config.Notifications == "ps" then
        exports['ps-ui']:Notify(msg, type, length)
    elseif Config.Notifications == "qb" then
        QBCore.Functions.Notify(msg, type, length)
    elseif Config.Notifications == "k5" then
        exports["k5_notify"]:notify(type, msg, type, length)
    else
        print("Invalid notification type specified in Config.")
    end
end

local function GetPropKey(entity)
    local coords = GetEntityCoords(entity)
    local model = GetEntityModel(entity)
    return model .. "_" .. math.floor(coords.x) .. "_" .. math.floor(coords.y) .. "_" .. math.floor(coords.z)
end

local function IsPropOnCooldown(entity)
    local currentTime = GetGameTimer()
    local propKey = GetPropKey(entity)
    if searchedProps[propKey] and searchedProps[propKey] > currentTime then
        return true
    end
    return false
end

local function SetPropOnCooldown(entity)
    local cooldownDuration = Config.CooldownDuration
    local propKey = GetPropKey(entity)
    searchedProps[propKey] = GetGameTimer() + cooldownDuration
end


local function WalkToEntityAndSearch(entity, onComplete)
    local playerPed = PlayerPedId()
    local propCoords = GetEntityCoords(entity)
    TaskGoStraightToCoord(playerPed, propCoords.x, propCoords.y, propCoords.z, 1.0, -1, GetEntityHeading(entity), 0.5)

    Citizen.CreateThread(function()
        local reached = false
        while not reached do
            Citizen.Wait(500) 
            local playerCoords = GetEntityCoords(playerPed)
            if #(playerCoords - propCoords) < 1.5 then 
                reached = true
                ClearPedTasks(playerPed)
                
                PlayAnimation(playerPed, "amb@prop_human_bum_bin@base", "base")
                
                Citizen.Wait(1500)
                
                PlayAnimation(playerPed, "amb@prop_human_bum_bin@idle_a", "idle_a")
                
                if onComplete then
                    onComplete()
                end
            end
        end
    end)
end

local function PlayAnimation(ped, dict, anim)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(10)
    end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 49, 0, false, false, false)
end

local function WalkToEntityAndSearch(entity, onComplete)
    local playerPed = PlayerPedId()
    local propCoords = GetEntityCoords(entity)
    TaskGoStraightToCoord(playerPed, propCoords.x, propCoords.y, propCoords.z, 1.0, -1, GetEntityHeading(entity), 0.5)

    Citizen.CreateThread(function()
        local reached = false
        while not reached do
            Citizen.Wait(500) 
            local playerCoords = GetEntityCoords(playerPed)
            if #(playerCoords - propCoords) < 1.5 then 
                reached = true
                ClearPedTasks(playerPed)
                
                PlayAnimation(playerPed, "amb@prop_human_bum_bin@base", "base")
                
                Citizen.Wait(1500) 
                
                PlayAnimation(playerPed, "amb@prop_human_parking_meter@male@idle_a", "idle_a")
                
                if onComplete then
                    onComplete()
                end
            end
        end
    end)
end


local function SpawnAttackingCatNearProp(propEntity)
    local propCoords = GetEntityCoords(propEntity)
    local catModel = GetHashKey("a_c_rottweiler")

    RequestModel(catModel)
    while not HasModelLoaded(catModel) do
        Citizen.Wait(1)
    end

    local spawnCoords = {
        x = propCoords.x + math.random(-2, 2),
        y = propCoords.y + math.random(-2, 2),
        z = propCoords.z
    }
    local catPed = CreatePed(28, catModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, true)

    if DoesEntityExist(catPed) then
        TaskCombatPed(catPed, PlayerPedId(), 0, 16)
        SetEntityAsNoLongerNeeded(catPed)
        SetModelAsNoLongerNeeded(catModel)
    end
end

local function SearchGarbage()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local entity, distance = QBCore.Functions.GetClosestObject(coords, Config.GarbageProps)
    
    if entity and distance < 2.0 then
        if IsPropOnCooldown(entity) then
            CustomNotify("You've already searched this. Try another.", "error")
            return
        end
        
        if isInteracting then
            CustomNotify("You are already searching.", "error")
            return
        end

        local requiredItem = Config.RequiredItem
        local requiredItemLabel = QBCore.Shared.Items[requiredItem].label or requiredItem
        
        local hasItem = exports['qb-inventory']:HasItem(requiredItem)
        
        if not hasItem then
            CustomNotify("You need a " .. requiredItemLabel .. " to search.", "error")
            return
        end

        isInteracting = true

        WalkToEntityAndSearch(entity, function()
            QBCore.Functions.Progressbar("search_garbage", "Searching garbage...", 5000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- On complete
                ClearPedTasks(PlayerPedId()) -- Stop animation
                SetPropOnCooldown(entity) -- Set this specific prop on cooldown
                TriggerServerEvent('z-trash:server:RewardItem')

                if math.random(1, 100) <= Config.AttackChance then 
                    SpawnAttackingCatNearProp(entity)
                end

                isInteracting = false
            end, function() -- On cancel
                ClearPedTasks(PlayerPedId()) -- Stop animation if cancelled
                CustomNotify("Cancelled", "error")
                isInteracting = false
            end)
        end)
    else
        CustomNotify("No garbage nearby to search.", "error")
    end
end




Citizen.CreateThread(function()
    for _, propModel in ipairs(Config.GarbageProps) do
        exports['qb-target']:AddTargetModel(propModel, {
            options = {
                {
                    event = "z-trash:client:SearchGarbage",
                    icon = "fas fa-search",
                    label = "Search Garbage",
                },
            },
            distance = 2.5,
        })
    end
end)

RegisterNetEvent('z-trash:client:SearchGarbage', SearchGarbage)
