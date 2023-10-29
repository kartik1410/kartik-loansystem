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

if Config.Framework == 'esx' then
    local ESX = exports.es_extended:getSharedObject()

    function Framework:HasAccess()
        local data = ESX.GetPlayerData()
        for _, v in pairs(Config.BankerJob) do
            if data.job.name == v then
                return true
            end
        end
        return false
    end

end

return Framework