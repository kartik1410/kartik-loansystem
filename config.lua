Config = {}

Config.debug = false

Config.Framework = 'qb' -- 'qb', 'qbox', 'esx'
Config.Phone = 'qb'     -- 'qb', 'qs', 'lb', 'road', 'yseries', 'none'
Config.Target = 'ox'    -- 'qb', 'ox'

if Config.Target == 'qb' then
    Config.TargetZones = {
        [1] = {
            name = 'Pacific Bank', -- Name of the bank
            coords = vector3(241.6, 226.2, 106.0),
            length = 3,
            width = 3,
            heading = 0,
            minZ = 104.0,
            maxZ = 108.0,
        }
    }
elseif Config.Target == 'ox' then
    Config.TargetZones = {
        [1] = {
            name = 'Pacific Bank', -- Name of the bank
            coords = vec3(241.6, 226.2, 106.0),
            size = vec3(1, 1, 2),
            rotation = 341.75,
        }
    }
end

Config.BankerJobs = { -- Job that can approve or decline loans
    -- ['job_name'] = grade_level,
    ["banker"] = 0,
}

Config.LoanIntervals = 10 * 60 * 1000 -- 10 minutes
Config.AutomaticDeduction = true      -- Automatically deduct if payment is not made after the due date

Config.LoanTypes = {
    { label = 'Personal Loan', value = 'Personal Loan', interest = 0.05 }, -- Interest is applied weekly as selected by the user in the duration.
    { label = 'Business Loan', value = 'Business Loan', interest = 0.1 },  -- Interest should be below 1.0, i.e., divided by 100.
    { label = 'Home Loan',     value = 'Home Loan',     interest = 0.15 },
}

Config.Duration = {
    { label = '1 Week',  value = 1 }, -- Duration is in weeks.
    { label = '2 Weeks', value = 2 },
    { label = '3 Weeks', value = 3 },
}

Config.CreditScore = {
    Enable                         = true, -- If True, It Will enable increaing and decreasing credit score
    CreditScoreRequirementForLoans = true, -- If True, It Will Check Credit Score For Loans
    Requirement                    = {     -- Only if CreditScoreRequirementForLoans set to true
        ['Personal Loan'] = 0,
        ['Business Loan'] = 600,
        ['Home Loan'] = 100,
    },
    DefaultCreditScore             = 500,                               -- Default Credit Score
    MaxCreditScore                 = 900,                               -- Maximum Credit Scores
    DefaultInterest                = 0.08,                              -- Default Interest
    OptLoan                        = {
        ['Personal Loan'] = {                                           -- In this case, if the player has a credit score of 500, the interest rate will be 0.5 and the maximum amount will be 2000
            { minCreditScore = 500, interest = 0.5, maxAmount = 2000 }, -- minCreditScore = Minimum Credit Score Required, interest = Interest Rate, maxAmount = Maximum Amount
            { minCreditScore = 600, interest = 0.2, maxAmount = 200000 },
        },
        ['Business Loan'] = { -- In this case, if the player has a credit score of 600, the interest rate will be 0.15 and the maximum amount will be 200000
            { minCreditScore = 600, interest = 0.15, maxAmount = 200000 },
            { minCreditScore = 700, interest = 0.25, maxAmount = 1000000 },
        },
        ['Home Loan'] = { -- In this case, if the player has a credit score of 700, the interest rate will be 0.30 and the maximum amount will be 5000000
            { minCreditScore = 700, interest = 0.30, maxAmount = 5000000 },
            { minCreditScore = 800, interest = 0.40, maxAmount = 10000000 },
        },
    },
    Addon                          = {  -- If a player pays the loan on time, their credit score will increase by score and if they don't pay the loan on time, their credit score will decrease by score
        { score = 100, amount = 0 },    -- If player's dues is between 0 - 1000 and they pay on time, their credit score will increase by 100
        { score = 200, amount = 1000 }, -- If player's dues is between 1000 - 2000 and they pay on time, their credit score will increase by 200
        { score = 300, amount = 2000 },
        { score = 400, amount = 3000 },
    },
    Deduct                         = { -- If a player pays the loan on time, their credit score will increase by score and if they don't pay the loan on time, their credit score will decrease by score
        { score = 100, amount = 0 },   -- If player's dues is between 0 - 1000 and they don't pay on time, their credit score will decrease by 100
        { score = 200, amount = 500 }, -- If player's dues is between 1000 - 2000 and they don't pay on time, their credit score will decrease by 200
        { score = 300, amount = 200 },
        { score = 500, amount = 1000 },

    },
}

Config.PhoneMails = {
    DueReminder = true, -- If True, It Will Send Reminder To The Player When Loan Is Due
    Time = 20,          -- It Means Amount Days Before The Loan Is Due Per Restart or Script Restart
    ApproveMail = true, -- If True, It Will Send Mail To The Player When Loan Is Approved
    DeclineMail = true, -- If True, It Will Send Mail To The Player When Loan Is Declined
}
