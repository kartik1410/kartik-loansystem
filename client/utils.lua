local Framework = {}

if Config.Framework == 'qb' then
    local QBCore = exports['qb-core']:GetCoreObject()
    local PlayerData = QBCore.Functions.GetPlayerData()

    function Framework:HasAccess()
        for _, v in pairs(Config.BankerJob) do
            if PlayerData.job.name == v then
                return true
            end
        end
        return false
    end

    RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
        PlayerData = val
    end)
end

return Framework