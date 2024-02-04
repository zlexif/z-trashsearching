local QBCore = exports['qb-core']:GetCoreObject()

local function GetRandomItem()
    local total = 0
    for _, v in ipairs(Config.Items) do
        total = total + v.probability
    end
    local chance = math.random(total)
    local runningTotal = 0
    for _, v in ipairs(Config.Items) do
        runningTotal = runningTotal + v.probability
        if chance <= runningTotal then
            return v.item
        end
    end
    return nil 
end

RegisterServerEvent('z-trash:server:RewardItem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local item = GetRandomItem()
    if item then
        Player.Functions.AddItem(item, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "add")
    else
        TriggerClientEvent('QBCore:Notify', src, 'You found nothing', 'error')
    end
end)
