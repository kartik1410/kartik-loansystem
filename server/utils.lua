local Framework = {}

if Config.Framework == 'qb' then
    local QBCore = exports['qb-core']:GetCoreObject()

    function Framework:GetPlayer(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return false end
        local _data = {
            citizenid = player.PlayerData.citizenid,
            fullname = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
        }
        return _data
    end

    function Framework:AddMoneyByIdentifier(citizenId, type, amount, reason)
        local player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
        if not player then return false end
        return player.Functions.AddMoney(type, amount, reason)
    end

    function Framework:AddMoneyByIdentifierOffline(citizenId, amount)
        local moneyData = MySQL.Sync.fetchAll('SELECT money FROM players WHERE citizenid = ?', {citizenId })
        if not moneyData[1] then return false end
        local moneyInfo = json.decode(moneyData[1].money)
        moneyInfo.bank = math.floor((moneyInfo.bank + amount))
        MySQL.Async.execute('UPDATE players SET money = ? WHERE citizenid = ?',{ json.encode(moneyInfo), citizenId })
    end

    function Framework:RemoveMoneyByIdentifier(citizenId, type, amount, reason)
        local player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
        if not player then return false end
        return player.Functions.RemoveMoney(type, amount, reason)
    end

    function Framework:RemoveMoneyByIdentifierOffline(citizenId, amount)
        local moneyData = MySQL.Sync.fetchAll('SELECT money FROM players WHERE citizenid = ?', {citizenId })
        if not moneyData[1] then return false end
        local moneyInfo = json.decode(moneyData[1].money)
        moneyInfo.bank = math.floor((moneyInfo.bank - amount))
        MySQL.Async.execute('UPDATE players SET money = ? WHERE citizenid = ?',{ json.encode(moneyInfo), citizenId })
    end

    function Framework:SendMail(citizenId, data)
    if Config.Phone == "QB" then
        exports['qb-phone']:sendNewMailToOffline(citizenId, data)
    elseif Config.Phone == "QS" then
        TriggerEvent('qs-smartphone:server:sendNewMailToOffline', citizenId, data)
    end
end

end

return Framework