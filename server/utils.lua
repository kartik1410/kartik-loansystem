local Framework = {}

if Config.Framework == 'qb' then
    local QBCore = exports['qb-core']:GetCoreObject()

    function Framework:GetPlayer(source)
        if not source then return false end
        local player = (type(source) == 'number') and QBCore.Functions.GetPlayer(source)
        if player then
            return {
                citizenid = player.PlayerData.citizenid,
                fullname = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
            }
        else
            local result = MySQL.single.await([[
                SELECT citizenid,
                    CONCAT (JSON_UNQUOTE(JSON_EXTRACT (charinfo, '$.firstname')), ' ', JSON_UNQUOTE (JSON_EXTRACT (charinfo, '$.lastname'))) AS fullname
                FROM players WHERE citizenid = ? LIMIT 1
            ]], { source })
            return {
                citizenid = result.citizenid,
                fullname = result.fullname
            }
        end
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
        if not source then return false end
        local player = (type(source) == 'number') and ESX.GetPlayerFromId(source)
        if player then
            return {
                citizenid = player.identifier,
                fullname = player.getName()
            }
        else
            local result = MySQL.single.await([[
                SELECT citizenid,
                    CONCAT(firstname, ' ', lastname) as fullname
                FROM users WHERE identifier = ?LIMIT 1
            ]], { source })
            return {
                citizenid = result.citizenid,
                fullname = result.fullname
            }
        end
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

if Config.Phone == 'lb' then
    function Framework:SendMail(identifier, data)
        local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(identifier)
        if not phoneNumber then return false end
        local mailId = exports["lb-phone"]:GetEmailAddress(phoneNumber)
        exports["lb-phone"]:SendMail({
            to = mailId,
            sender = data.sender,
            subject = data.subject,
            message = data.message,
        })
    end
end

if Config.Phone == 'none' then
    function Framework:SendMail(identifier, data) end
end

return Framework