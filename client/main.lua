local Framework = require('client.utils')

function AlertBoxConfirmation(data)
    local alert = lib.alertDialog({
        header = data.header,
        content = data.content,
        centered = true,
        cancel = true
    })
    if not alert then return false end
    if alert == "confirm" then
        return true
    end
    return false
end

function SendMail(data)
    local input = lib.inputDialog("Send Mail", {
        {
            type = 'textarea',
            label = 'Subject',
            description = 'Enter the Subject you want to send',
            default = "#" .. data.loan_id .. " Loan Payment Reminder",
            required = true,
        },
        {
            type = 'textarea',
            label = 'Message',
            description = 'Enter the message you want to send',
            default = "You have a loan payment due . Please visit the bank to pay the amount",
            required = true,
        },
    })
    if not input then return end
    local sendMail = {
        subject = input[1],
        message = input[2],
        citizenid = data.citizenid,
    }
    TriggerServerEvent("loan-system:server:sendMail", sendMail)
end

function OpenMenu()
    local scores = lib.callback.await('loan-system:server:getMyScores', false)
    if Config.CreditScore.Enable then
        TriggerServerEvent("loan-system:server:firstTimeCredits")
    end
    lib.registerMenu({
        id = 'personal_menu',
        title = 'Loan Menu',
        position = 'top-right',
        onClose = function(keyPressed)
        end,
        options = {
            { label = 'Request Loan',              description = 'Request for a loan' },
            { label = 'My Loans',                  description = 'View your loans' },
            { label = 'Credit Scores : ' .. scores },
        }
    }, function(selected, scrollIndex, args)
        if selected == 1 then
            OpenRequestLoan(scores)
        elseif selected == 2 then
            OpenMyLoans()
        elseif selected == 3 then
            OpenMenu()
        end
    end)
    lib.showMenu('personal_menu')
end

function OpenMyLoans()
    local data = lib.callback.await('loan-system:server:getMyLoans', false)
    OpenRequestLoanDetails(data)
end

function OpenBankerMenu()
    local data = lib.callback.await('loan-system:server:getLoans', false)
    local options = {
        { label = #data.All .. ' Total Requests', close = false },
        {
            label = 'Search Loans',
            description = 'Search Loans Using CitizenID or Loan ID',
            args = {
                data = data.All }
        },
        {
            label = 'Requested Loans',
            description = #data.Pending .. ' Requests Pending',
            args = {
                data = data.Pending }
        },
        {
            label = 'Approved Loans',
            description = #data.Approved .. ' Requests Approved',
            args = {
                data = data.Approved }
        },
        {
            label = 'Rejected Loans',
            description = #data.Rejected .. ' Requests Rejected',
            args = {
                data = data.Rejected }
        },
        {
            label = 'Paid Loans',
            description = #data.Paid .. ' Loans Paid Off',
            args = {
                data = data.Paid }
        },
    }
    lib.registerMenu({
        id = 'banker_menu',
        title = 'Banker Menu',
        position = 'top-right',
        onClose = function(keyPressed)
        end,
        options = options
    }, function(selected, scrollIndex, args)
        if not args then return end
        if selected == 2 then
            SearchLoans(args.data)
        elseif args.data == "Reset" then
            local input = lib.inputDialog("Welcome to Pacific Bank!", {
                {
                    type = 'input',
                    label = 'Citizen ID',
                    description = 'Enter the Citizen ID of the player',
                    required = true,
                },
            })
            if not input then return end
            local cid = tostring(input[1])
            TriggerServerEvent("loan-system:server:resetCreditScore", cid)
        else
            OpenRequestLoanDetails(args.data, "Banker")
        end
    end)
    lib.showMenu('banker_menu')
end

function SearchLoans(data)
    local input = lib.inputDialog("Search Loans", {
        { type = 'input', label = 'Search' },
    })
    if not input then return end
    local searchid = tostring(input[1])
    local searchdata = {}
    for k, v in pairs(data) do
        if tostring(v.loan_id) == searchid or tostring(v.citizenid) == searchid then
            table.insert(searchdata, v)
        end
    end
    if #searchdata == 0 then
        lib.notify({ description = "No Loans Found", type = "error" })
        OpenBankerMenu()
        return
    end
    OpenRequestLoanDetails(searchdata, "Banker")
end

function OpenRequestLoan(scores)
    local input = lib.inputDialog("Welcome to Pacific Bank!", {
        {
            type = 'select',
            label = 'Type of Loan',
            description = 'Select the type of loan you are requesting',
            required = true,
            default = 1,
            options = Config.LoanTypes,
        },
        {
            type = 'number',
            label = 'Amount',
            description = 'Enter the Amount you want to loan',
            required = true,
        },
        {
            type = 'textarea',
            label = 'Reason',
            description = 'Enter the reason for the loan',
            required = true,
        },
        {
            type = 'select',
            label = 'Duration',
            description = 'Enter the duration of the loan',
            required = true,
            default = 1,
            options = Config.Duration,
        },
    })
    if not input then return end

    local interest -- The variable to store the interest rate

    -- Check if credit scoring is enabled in the configuration
    if Config.CreditScore then
        if scores < 0 then
            lib.notify({ description = "You have been blacklisted ! Contact Bank Manager", type = "error" })
            return
        end
        local creditScoreRequirement = Config.CreditScore.CreditScoreRequirementForLoans
        local loanRequirement = Config.CreditScore.Requirement[input[1]]

        if not loanRequirement then -- check if the loan type is configured
            lib.notify({
                description = "Requirements for this loan type are not configured yet! Please contact the bank manager",
                type = "error"
            })
            return
        end
        -- Check if there is a credit score requirement for the specific loan type
        if creditScoreRequirement and loanRequirement then
            -- Check if the player's credit score is below the requirement
            if scores < loanRequirement then
                lib.notify({ description = "You are not eligible", type = "error" })
                OpenRequestLoan()
                return
            end
        end
        local optLoans = Config.CreditScore.OptLoan[input[1]]
        -- Check if loan options are configured for the specific loan type
        if not optLoans then
            lib.notify({
                description = "Requirements for this loan type are not configured yet! Please contact the bank manager",
                type = "error"
            })
            return
        end
        -- Loop through the credit scoring options for the loan type
        for k, v in pairs(optLoans) do
            local nextKey = next(optLoans, k) -- Get the next key
            local currentRange = optLoans[k]
            if nextKey then
                local nextRange = optLoans[nextKey]
                -- Check if the requested loan amount exceeds the maximum allowed
                if scores >= currentRange.minCreditScore and scores < nextRange.minCreditScore and not (scores >= nextRange.minCreditScore) then
                    interest = currentRange.interest

                    if input[2] > currentRange.maxAmount then
                        lib.notify({
                            description = "You are not eligible! You can take loan upto $" .. currentRange
                                .maxAmount,
                            type = "error"
                        })
                        return
                    end
                end
            else
                -- Check if the requested loan amount exceeds the maximum allowed
                if scores >= currentRange.minCreditScore then
                    interest = currentRange.interest
                    if input[2] > currentRange.maxAmount then
                        lib.notify({
                            description = "You are not eligible! You can take loan upto $" .. currentRange
                                .maxAmount,
                            type = "error"
                        })
                        return
                    end
                end
            end
        end
    else
        -- If credit scoring is not enabled, use the default loan types and interest rates
        for k, v in pairs(Config.LoanTypes) do
            if v.value == input[1] then
                interest = v.interest
            end
        end
    end
    if not interest then interest = Config.CreditScore.DefaultInterest end
    local data = {
        type = input[1],
        amount = input[2],
        reason = input[3],
        duration = input[4],
        interest = tonumber(input[2] * input[4] * interest),
        interestpercent = interest,
    }
    local alertdata = {
        header = 'Hello there',
        content = 'Are you sure you want to request a loan of $' ..
            data.amount .. ' for ' .. data.duration .. ' weeks with total interest of $' .. (data.interest) .. ' ?',
    }
    local confirm = AlertBoxConfirmation(alertdata)
    if confirm then
        TriggerServerEvent('loan-system:server:requestLoan', data)
    end
end

function OpenRequestLoanDetails(data, menu)
    local options = {}
    for k, v in pairs(data) do
        local loandetails = json.decode(v.loan_details)
        table.insert(options,
            {
                label = "#" .. v.loan_id .. " | Amount $" .. loandetails.amount,
                description = "Loan Duration : " .. loandetails.duration .. " Weeks",
                args = { data = v }
            })
    end
    if #options == 0 then
        lib.notify({ description = "No Application Found", type = "error" })
        if menu == "Banker" then
            OpenBankerMenu()
        else
            OpenMenu()
        end
        return
    end
    lib.registerMenu({
        id = 'banker_loandetails',
        title = 'Loan Applications',
        position = 'top-right',
        onClose = function(keyPressed)
            if menu == "Banker" then
                OpenBankerMenu()
            else
                OpenMenu()
            end
        end,
        options = options
    }, function(selected, scrollIndex, args)
        ViewLoanDetails(data, args, menu)
    end)
    lib.showMenu('banker_loandetails')
end

function ViewLoanDetails(prevdata, prevargs, menu)
    local data = prevargs.data
    local loandetails = json.decode(data.loan_details)
    local status = ''
    local actionOptions = { 'Accept', 'Reject' }
    if data.status == 0 then
        status = 'Pending'
    elseif data.status == 1 then
        status = 'Approved'
    elseif data.status == 2 then
        status = 'Rejected'
    end
    local options = {
        { label = 'Loan ID : #' .. data.loan_id,                          close = false },
        { label = 'Loan Type : ' .. loandetails.loantype,                 close = false },
        { label = 'Amount Requested: $' .. loandetails.requestedamount,   close = false },
        { label = 'Loan Interest : ' .. loandetails.interest .. '%',      close = false },
        { label = 'Total Amount : $' .. loandetails.amount,               close = false },
        { label = 'Remaining Amount : $' .. loandetails.remainingamount,  close = false },
        { label = 'Reason : ' .. loandetails.reason,                      close = false },
        { label = 'Status : ' .. status,                                  close = false },
        { label = 'Request Time : ' .. loandetails.requestedtime,         close = false },
        { label = 'Loan Duration : ' .. loandetails.duration .. ' Weeks', close = false },
    }
    if data.status == 1 or data.status == 3 then -- When Status is approved or paid
        local values = {}
        table.insert(options,
            { label = 'Loan Approved : ' .. loandetails.starttime, close = false })
        table.insert(options, {
            label = 'Loan Paid Off : ' .. loandetails.endtime,
            close = false
        })
        for k, v in pairs(loandetails.dues) do
            if not v.paid then
                table.insert(values, '#' .. k .. ': ' .. v.time .. " | $" .. v.amount)
            end
        end
        if #values ~= 0 then
            table.insert(options, { label = "Dues", values = values, close = false })
        end
        if loandetails.remainingamount > 0 and not menu then
            table.insert(options, 1, { label = 'Pay Amount', args = { data = "PayAmount" } })
        end
        if menu then
            table.insert(options, 1, { label = 'Send Mail', args = { data = "sendMail" } })
        end
    end
    ----------------------------------------------------------
    if data.status == 0 then -- When Status is pending
        if menu == "Banker" then
            table.insert(options, 1,
                { label = 'Action #' .. data.loan_id, values = actionOptions, args = { data = data } })
        end
    end
    if data.status == 2 then -- When Status is rejected
        if loandetails.rejectionReason then
            table.insert(options, { label = 'Reason for Rejection : ' .. loandetails.rejectionReason, close = false })
        end
    end
    ----------------------------------------------------------
    if menu == "Banker" then
        table.insert(options, 3, {
            label = 'Citizen Details : ' .. loandetails.name .. " | " .. data.citizenid,
            close = false
        })
    end
    lib.registerMenu({
        id = 'view_requested',
        title = loandetails.name .. "'s Loan Details",
        position = 'top-right',
        imageSize = 'large',
        onClose = function(keyPressed)
            OpenRequestLoanDetails(prevdata, menu)
        end,
        options = options
    }, function(selected, scrollIndex, args)
        if not args then return end
        if args.data == "PayAmount" then
            local values = {}
            for k, v in pairs(loandetails.dues) do
                if not v.paid then
                    table.insert(values, { amount = v.amount, time = v.time, due = v.due })
                end
            end
            if #values == 0 then
                lib.notify({ description = "No Dues Found", type = "error" })
                ViewLoanDetails(prevdata, prevargs, menu)
                return
            end
            if values[1] then
                data.payamount = values[1].amount
                data.due = values[1].due
                local alertdata = {
                    header = 'Hello there',
                    content = 'Are you sure you want to pay $' .. data.payamount .. ' for due #' .. data.due .. ' ?',
                }
                local confirm = AlertBoxConfirmation(alertdata)
                if confirm then
                    TriggerServerEvent("loan-system:server:payLoan", data)
                end
            end
        elseif args.data == "sendMail" then
            SendMail(data)
        else
            local action = actionOptions[scrollIndex]
            if not action then return end
            if action == "Accept" then
                TriggerServerEvent("loan-system:server:approveLoan", args.data)
            elseif action == "Reject" then
                local input = lib.inputDialog("Welcome to Pacific Bank!", {
                    {
                        type = 'textarea',
                        label = 'Reason',
                        description = 'Enter the reason for the loan',
                        required = true,
                    },
                })
                if not input then return end
                local rejectionReason = input[1]
                args.data.rejectionReason = rejectionReason
                TriggerServerEvent("loan-system:server:rejectLoan", args.data)
            end
        end
    end)
    lib.showMenu('view_requested')
end

CreateThread(function()
    for index, data in pairs(Config.TargetZones) do
        Framework:AddBoxZone(data, index)
    end
end)
