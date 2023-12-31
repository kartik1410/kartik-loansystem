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
        return true
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
        return true
    end
end

if Config.Framework == 'esx' then
    local ESX = exports.es_extended:getSharedObject()

    function Framework:GetPlayer(source)
        local player = ESX.GetPlayerFromId(source)
        if not player then return false end
        local _data = {
            citizenid = player.identifier,
            fullname = player.getName()
        }
        return _data
    end

    function Framework:AddMoneyByIdentifier(identifier, type, amount, reason)
        local player = ESX.GetPlayerFromIdentifier(identifier)
        if not player then return false end
        player.addAccountMoney(type, amount)
        return true
    end

    function Framework:AddMoneyByIdentifierOffline(identifier, amount)
        local moneyData = MySQL.Sync.fetchAll('SELECT accounts FROM users WHERE identifier = ?', {identifier })
        if not moneyData[1] then return false end
        local moneyInfo = json.decode(moneyData[1].accounts)
        moneyInfo.bank = math.floor((moneyInfo.bank + amount))
        MySQL.Async.execute('UPDATE users SET accounts = ? WHERE identifier = ?',{ json.encode(moneyInfo), identifier })
        return true
    end

    function Framework:RemoveMoneyByIdentifier(identifier, type, amount, reason)
        local player = ESX.GetPlayerFromIdentifier(identifier)
        if not player then return false end
        if player.getAccount(type).money < amount then return false end
        player.removeAccountMoney(type, amount)
        return true
    end

    function Framework:RemoveMoneyByIdentifierOffline(identifier, amount)
        local moneyData = MySQL.Sync.fetchAll('SELECT accounts FROM users WHERE identifier = ?', {identifier })
        if not moneyData[1] then return false end
        local moneyInfo = json.decode(moneyData[1].accounts)
        moneyInfo.bank = math.floor((moneyInfo.bank - amount))
        MySQL.Async.execute('UPDATE users SET accounts = ? WHERE identifier = ?',{ json.encode(moneyInfo), identifier })
        return true
    end
end

if Config.Phone == 'qb' then
    function Framework:SendMail(citizenId, data)
        local maildata = {
            sender = data.sender,
            subject = data.subject,
            message = data.message,
        }
        exports['qb-phone']:sendNewMailToOffline(citizenId, maildata)
    end
end

if Config.Phone == 'qs' then
    function Framework:SendMail(identifier, data)
        local maildata = {
            sender = data.sender,
            subject = data.subject,
            message = data.message,
        }
        TriggerEvent('qs-smartphone:server:sendNewMailToOffline', identifier, maildata)
    end
end

if Config.Phone == 'none' then
    function Framework:SendMail(identifier, data) end
end

return Framework