local Framework = require('server.utils')
local resourceName = GetCurrentResourceName()
local CreditScores = {}

local function saveCreditScores()
    SaveResourceFile(resourceName, 'credit_scores.json', json.encode(CreditScores), -1)
end

local function loanPaidLoop()
    local data = MySQL.query.await('SELECT * FROM players_loan WHERE status = 1', {})
    for k, v in pairs(data) do
        local loanDetails = json.decode(v.loan_details)
        for _, duesdata in pairs(loanDetails.dues) do
            if not duesdata.paid then
                if os.time() >= duesdata.time then
                    local hasRemoved = Framework:RemoveMoneyByIdentifier(v.citizenid, 'bank', tonumber(duesdata.amount), "banker-loan")
                    if not hasRemoved then
                        Framework:RemoveMoneyByIdentifierOffline(v.citizenid, tonumber(duesdata.amount))
                    end
                    if GetResourceState("snipe-banking") == "started" then
                        exports["snipe-banking"]:CreatePersonalTransactions(v.citizenid, tonumber(duesdata.amount), "Loan Payment for Loan ID: "..v.loan_id, "withdraw")
                    end
                    if Config.CreditScore.Enable then
                        HandleScores(v.citizenid, "remove", tonumber(duesdata.amount))
                    end
                    duesdata.paid = true
                    MySQL.Async.execute('UPDATE players_loan SET status = ? , loan_details = ? WHERE loan_id = ?',
                        { 3, json.encode(loanDetails), v.loan_id })
                end
            end
        end
    end
    SetTimeout(Config.LoanIntervals, loanPaidLoop)
end

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    saveCreditScores()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    if Config.AutomaticDeduction then Wait(5000) loanPaidLoop() end -- Start the loop to deduct loan payments
    if Config.PhoneMails.DueReminder then                -- Start the loop to send loan payment reminders on script restart
        local data = MySQL.query.await('SELECT * FROM players_loan WHERE status = 1', {})
        for k, v in pairs(data) do
            local loanDetails = json.decode(v.loan_details)
            for _, duesdata in pairs(loanDetails.dues) do
                if not duesdata.paid then
                    if os.time() >= (duesdata.time - (Config.PhoneMails.Time * 24 * 60 * 60)) and os.time() < duesdata.time then
                        -- convert dues.time into date
                        local date = os.date("%d-%m-%Y %H:%M:%S", duesdata.time)
                        local maildata = {
                            sender = "Banker",
                            subject = "#" .. v.loan_id .. " Loan Payment Reminder",
                            message = "You have a loan payment due . Please visit the bank to pay your loan before " ..
                                date .. ". Payment Amount : $" .. duesdata.amount .. ". ",
                        }
                        Framework:SendMail(v.citizenid, maildata)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= resourceName then return end
    saveCreditScores()
end)

CreateThread(function()
    Wait(100)
    local scores = json.decode(LoadResourceFile(resourceName, 'credit_scores.json'))
    if type(scores) == 'table' then
        CreditScores = scores
    else
        SaveResourceFile(resourceName, "credit_scores.json", '[]', -1)
        CreditScores = {}
    end
end)

function GetScores(cid)
    if not CreditScores[cid] then return 0 end
    return CreditScores[cid]
end

function HandleScores(cid, operation, amount)
    local score = 0
    -- Define the scoring rules based on the operation
    local scoringRules
    if operation == "add" then
        scoringRules = Config.CreditScore.Addon
    elseif operation == "remove" then
        scoringRules = Config.CreditScore.Deduct
    end
    -- Loop through scoring rules to calculate the score
    for k, v in pairs(scoringRules) do
        local nextKey = next(scoringRules, k) -- Get the next key
        local currentRange = scoringRules[k]
        if nextKey then
            local nextRange = scoringRules[nextKey]
            -- Check if 'amount' is within the current range
            if amount >= currentRange.amount and amount < nextRange.amount then
                score = currentRange.score
                break -- Exit the loop since we found the correct range
            end
        else
            -- If there is no next key, it means 'amount' is greater than or equal to the last range
            if amount >= currentRange.amount then
                score = currentRange.score
                break
            end
        end
    end
    -- Update the player's credit score
    if operation == "add" then
        CreditScores[cid] = (CreditScores[cid] or 0) + score
    else
        CreditScores[cid] = (CreditScores[cid] or 0) - score
        if CreditScores[cid] < 0 then
            CreditScores[cid] = 0
        end
    end
    saveCreditScores()
end

lib.callback.register('loan-system:server:getLoans', function(source)
    local data = MySQL.query.await('SELECT * FROM players_loan', {})
    local returnData = {
        Pending = {},
        Approved = {},
        Rejected = {},
        Paid = {},
        All = {}
    }
    for k, v in pairs(data) do
        if v.status == 0 then
            table.insert(returnData.Pending, v)
        elseif v.status == 1 then
            table.insert(returnData.Approved, v)
        elseif v.status == 2 then
            table.insert(returnData.Rejected, v)
        elseif v.status == 3 then
            table.insert(returnData.Paid, v)
        end
        table.insert(returnData.All, v)
    end
    return returnData
end)

lib.callback.register('loan-system:server:getMyLoans', function(source)
    local Player = Framework:GetPlayer(source)
    local cid = Player.citizenid
    local data = MySQL.query.await('SELECT * FROM players_loan WHERE citizenid =?', { cid })
    return data
end)

lib.callback.register('loan-system:server:getMyScores', function(source)
    local Player = Framework:GetPlayer(source)
    if not Player then return false end
    local cid = Player.citizenid
    local data = GetScores(cid)
    return data
end)

RegisterNetEvent("loan-system:server:requestLoan", function(data)
    local src = source
    local Player = Framework:GetPlayer(src)
    if not Player then return end
    local cid = Player.citizenid
    local totalamount = tonumber(data.amount) + tonumber(data.interest)
    if data.amount < 0 then
        TriggerClientEvent("ox_lib:notify", source, {
            description = "You can't request a negative amount!",
            type = "error"
        })
        return
    end

    local saveData = {
        name = Player.fullname,
        loantype = data.type,
        amount = totalamount,
        remainingamount = totalamount,
        reason = data.reason,
        duration = data.duration,
        requestedamount = data.amount,
        interest = data.interestpercent,
        requestedtime = os.time(),
    }
    MySQL.Async.execute('INSERT INTO players_loan (citizenid, loan_details) VALUES (?, ?)', {
        cid,
        json.encode(saveData),
    })
    TriggerClientEvent("ox_lib:notify", source, {
        description = "Loan Request Successfully Sent to the Bank!",
        type = "success"
    })
end)

RegisterNetEvent('loan-system:server:approveLoan', function(data)
    local src = source
    local cid = data.citizenid
    local loanDetails = json.decode(data.loan_details)
    local intervals = {}
    local totalmoney = 0
    for i = 1, tonumber(loanDetails.duration) do
        local intervaltime = os.time() + (i * 7 * 24 * 60 * 60)
        local money = tonumber(string.format("%.0f", loanDetails.amount / tonumber(loanDetails.duration)))
        if i == tonumber(loanDetails.duration) then
            money = tonumber(loanDetails.amount) - tonumber(totalmoney)
        end
        table.insert(intervals, { amount = money, time = intervaltime, paid = false, due = i })
        totalmoney = totalmoney + tonumber(string.format("%.0f", loanDetails.amount / tonumber(loanDetails.duration)))
    end
    loanDetails.starttime = os.time()
    loanDetails.endtime = os.time() + tonumber(loanDetails.duration * 7 * 24 * 60 * 60)
    loanDetails.dues = intervals
    MySQL.Async.execute('UPDATE players_loan SET status = 1, loan_details = ? WHERE loan_id = ?', {
        json.encode(loanDetails),
        data.loan_id,
    })
    local hasRemoved = Framework:AddMoneyByIdentifier(cid, 'bank', tonumber(loanDetails.requestedamount), "banker-loan")
    if not hasRemoved then
        Framework:AddMoneyByIdentifierOffline(cid, tonumber(loanDetails.requestedamount))
    end
    if GetResourceState("snipe-banking") == "started" then
        exports["snipe-banking"]:CreatePersonalTransactions(cid, tonumber(loanDetails.requestedamount), "Loan Approved for Loan ID: "..data.loan_id, "deposit")
    end

    if Config.PhoneMails.ApproveMail then
        local maildata = {
            sender = "Banker",
            subject = "#" .. data.loan_id .. " Loan Approved",
            message = "Your loan request has been approved. Please check your Bank Amount. Loan Amount : $" ..
                loanDetails.requestedamount .. ". ",
        }
        Framework:SendMail(cid, maildata)
    end
    TriggerClientEvent("ox_lib:notify", src, {
        description = "#" .. data.loan_id .. " Loan Request Approved!",
        type = "success"
    })
end)

RegisterNetEvent('loan-system:server:rejectLoan', function(data)
    local src = source
    local cid = data.citizenid
    local loanDetails = json.decode(data.loan_details)
    loanDetails.rejectionReason = data.rejectionReason
    MySQL.Async.execute('UPDATE players_loan SET status = 2, loan_details = ?  WHERE loan_id = ?', {
        json.encode(loanDetails),
        data.loan_id,
    })
    if Config.PhoneMails.DeclineMail then
        local maildata = {
            sender = "Banker",
            subject = "#" .. data.loan_id .. " Loan Declined",
            message = "Your loan request has been declined. Reason : " ..
                data.rejectionReason .. ". Loan Amount : $" .. loanDetails.requestedamount .. ". ",
        }
        Framework:SendMail(cid, maildata)
    end
    TriggerClientEvent("ox_lib:notify", src, {
        description = "#" .. data.loan_id .. " Loan Request Rejected!",
        type = "error"
    })
end)

RegisterNetEvent("loan-system:server:payLoan", function(data)
    local src = source
    local cid = data.citizenid
    local loanDetails = json.decode(data.loan_details)
    if Framework:RemoveMoneyByIdentifier(cid, 'bank', tonumber(data.payamount), "banker-loan") then
        if GetResourceState("snipe-banking") == "started" then
            exports["snipe-banking"]:CreatePersonalTransactions(cid, tonumber(data.payamount), "Loan Payment for Loan ID: "..data.loan_id, "withdraw")
        end
        loanDetails.remainingamount = tonumber(loanDetails.remainingamount) - tonumber(data.payamount)
        for k, v in pairs(loanDetails.dues) do
            if v.due == tonumber(data.due) then
                v.paid = true
                if Config.CreditScore.Enable then
                    if os.time() > v.time then
                        HandleScores(cid, "remove", tonumber(data.payamount))
                    else
                        HandleScores(cid, "add", tonumber(data.payamount))
                    end
                end
            end
        end
        if tonumber(loanDetails.remainingamount) == 0 then
            MySQL.Async.execute('UPDATE players_loan SET status= ?, loan_details = ? WHERE loan_id = ?', {
                3,
                json.encode(loanDetails),
                data.loan_id,
            })
        else
            MySQL.Async.execute('UPDATE players_loan SET loan_details = ? WHERE loan_id = ?', {
                json.encode(loanDetails),
                data.loan_id,
            })
        end


        TriggerClientEvent("ox_lib:notify", src, {
            description = "Loan Payment Successful!",
            type = "success"
        })
    else
        TriggerClientEvent("ox_lib:notify", src, {
            description = "Loan Payment Failed!",
            type = "error"
        })
    end
end)

RegisterNetEvent("loan-system:server:sendMail", function(data)
    local src = source
    local cid = data.citizenid
    local maildata = {
        sender = "Pacific Bank",
        subject = data.subject,
        message = data.message,
    }
    Framework:SendMail(cid, maildata)
    TriggerClientEvent("ox_lib:notify", src, {
        description = "Mail Sent!",
        type = "success"
    })
end)

RegisterNetEvent("loan-system:server:firstTimeCredits", function()
    local Player = Framework:GetPlayer(source)
    if not Player then return end
    local cid = Player.citizenid
    if not CreditScores[cid] then
        CreditScores[cid] = Config.CreditScore.DefaultCreditScore
        saveCreditScores()
    end
end)

MySQL.ready(function()
    local success, result = pcall(MySQL.query.await, "SELECT 1 FROM players_loan LIMIT 1") 
    if not success then
        -- Create 'players_loan' table if it doesn't exist
        success, result = pcall(MySQL.query, [[
            CREATE TABLE IF NOT EXISTS `players_loan` (
                `loan_id` int(11) NOT NULL AUTO_INCREMENT,
                `citizenid` varchar(50) NOT NULL DEFAULT '0',
                `loan_details` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`loan_details`)),
                `status` int(11) NOT NULL DEFAULT 0,
                PRIMARY KEY (`loan_id`)
              )
        ]])
        if not success then
            return print(result)
        end
        print("Created table 'players_loan' in MySQL database.")
    end
end)
