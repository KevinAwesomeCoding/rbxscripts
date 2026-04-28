local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Network = require(ReplicatedStorage.Shared.Packages.Network)

local okE, EntitiesData = pcall(require, ReplicatedStorage.Shared.Data.EntitiesData)
local okM, MutationData = pcall(require, ReplicatedStorage.Shared.Data.MutationData)

local function getValue(tool)
    local level = tool:GetAttribute("Level") or 1
    local mutation = tool:GetAttribute("Mutation") or "None"
    
    local baseCPS = 0
    if okE and EntitiesData.Brainrots and EntitiesData.Brainrots[tool.Name] then
        local cpsTable = EntitiesData.Brainrots[tool.Name].CPS
        if typeof(cpsTable) == "table" and cpsTable.first and cpsTable.second then
            baseCPS = cpsTable.first * (10 ^ cpsTable.second)
        end
    end

    local levelMult = 1
    if type(EntitiesData.GetMultiplierPerLevel) == "function" then
        local ok, r = pcall(EntitiesData.GetMultiplierPerLevel, level)
        if ok and type(r) == "number" then levelMult = r end
    end

    local mutMult = 1
    if okM and MutationData.Buffs and MutationData.Buffs[mutation] then
        mutMult = MutationData.Buffs[mutation].Value or 1
    end
    
    return baseCPS * levelMult * mutMult
end

local function getMyPlot()
    for _, model in ipairs(workspace.Plots:GetChildren()) do
        if model:GetAttribute("Owner") == player.Name then return model end
    end
end

local function autoEquip()
    local plot = getMyPlot()
    if not plot then print("[AutoEquip] No plot found!") return end

    local slotCount = #plot.Slots:GetChildren()
    
    for i = 1, slotCount do
        local slot = plot.Slots:FindFirstChild("Slot" .. i)
        if slot and slot:FindFirstChild("PlacedPart") then
            Network.FireServer("S_Interact", i)
            task.wait(0.3)
        end
    end

    task.wait(2)

    local pets = {}
    local lines = {} 
    
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and okE and EntitiesData.Brainrots and EntitiesData.Brainrots[tool.Name] then
            local v = getValue(tool)
            table.insert(pets, { tool = tool, value = v })
            table.insert(lines, tool.Name .. " | Val: " .. string.format("%.0f", v))
        end
    end

    table.sort(pets, function(a, b) return a.value > b.value end)
    

    if setclipboard then setclipboard(table.concat(lines, "\n")) end


    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for i = 1, math.min(slotCount, #pets) do
            local tool = pets[i].tool
            if tool and tool.Parent then
                humanoid:EquipTool(tool)
                task.wait(0.6)
                Network.FireServer("S_Interact", i)
                task.wait(0.4)
            end
        end
    end
end


if player.PlayerGui:FindFirstChild("AutoEquipGui") then player.PlayerGui.AutoEquipGui:Destroy() end
local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "AutoEquipGui"
sg.ResetOnSpawn = false

local btn = Instance.new("TextButton", sg)
btn.Size = UDim2.new(0, 155, 0, 36)
btn.Position = UDim2.new(1, -165, 0, 20)
btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45) 
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Gotham
btn.TextSize = 14
btn.Text = "Auto Equip Best"
btn.Parent = sg
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

btn.MouseButton1Click:Connect(autoEquip)
