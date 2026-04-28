local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Network = require(ReplicatedStorage.Shared.Packages.Network)

local okE, EntitiesData = pcall(require, ReplicatedStorage.Shared.Data.EntitiesData)
local okM, MutationData = pcall(require, ReplicatedStorage.Shared.Data.MutationData)

local function addLine(lines, ...)
    local t = {}
    for i = 1, select("#", ...) do
        t[#t + 1] = tostring(select(i, ...))
    end
    lines[#lines + 1] = table.concat(t, " ")
end

local function getBaseCPS(tool)
    if not okE or not EntitiesData.Brainrots then return 0 end
    local data = EntitiesData.Brainrots[tool.Name]
    if not data then return 0 end

    local cps = data.CPS
    if typeof(cps) == "table" and cps.first and cps.second then
        return cps.first * (10 ^ cps.second)
    end

    if type(cps) == "number" then
        return cps
    end

    return 0
end

local function getMutationMultiplier(tool)
    local mutation = tool:GetAttribute("Mutation") or "None"
    if okM and MutationData.Buffs and MutationData.Buffs[mutation] then
        local buff = MutationData.Buffs[mutation]
        if type(buff) == "table" and type(buff.Value) == "number" then
            return buff.Value
        end
    end
    return 1
end

local function getLevelMultiplier(tool)
    local level = tool:GetAttribute("Level") or 1
    if okE and type(EntitiesData.GetMultiplierPerLevel) == "function" then
        local ok, result = pcall(EntitiesData.GetMultiplierPerLevel, level)
        if ok and type(result) == "number" then
            return result
        end
    end
    return 1
end

local function isBrainrotTool(tool)
    return okE
        and tool
        and tool:IsA("Tool")
        and EntitiesData.Brainrots
        and EntitiesData.Brainrots[tool.Name] ~= nil
end

local function getValue(tool)
    local baseCPS = getBaseCPS(tool)
    local levelMult = getLevelMultiplier(tool)
    local mutMult = getMutationMultiplier(tool)
    return baseCPS * levelMult * mutMult
end

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    for _, model in ipairs(plots:GetChildren()) do
        if model:GetAttribute("Owner") == player.Name then
            return model
        end
    end
end

local function getSlotCount(plot)
    local slots = plot and plot:FindFirstChild("Slots")
    if not slots then return 0 end
    return #slots:GetChildren()
end

local function pullAllPlacedBrainrots(plot, lines)
    local slotsFolder = plot:FindFirstChild("Slots")
    if not slotsFolder then return end

    addLine(lines, "[AutoEquip] Pulling from ALL base slots...")

    for i = 1, #slotsFolder:GetChildren() do
        local slot = slotsFolder:FindFirstChild("Slot" .. i)
        if slot and slot:FindFirstChild("PlacedPart") then
            addLine(lines, "[AutoEquip] Pickup from base slot", i)
            Network.FireServer("S_Interact", i)
            task.wait(0.3)
        end
    end
end

local function collectBrainrots(lines)
    local pets = {}

    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if isBrainrotTool(tool) then
                local value = getValue(tool)
                local level = tool:GetAttribute("Level") or 1
                local mutation = tool:GetAttribute("Mutation") or "None"
                local baseCPS = getBaseCPS(tool)

                table.insert(pets, {
                    tool = tool,
                    value = value,
                    level = level,
                    mutation = mutation,
                    baseCPS = baseCPS,
                })

                addLine(
                    lines,
                    "[Brainrot]",
                    tool.Name,
                    "| Lv:" .. tostring(level),
                    "| Mut:" .. tostring(mutation),
                    "| Base:" .. tostring(baseCPS),
                    "| Val:" .. string.format("%.0f", value)
                )
            else
                addLine(lines, "[Skip Non-Brainrot]", tool.Name)
            end
        end
    end

    table.sort(pets, function(a, b)
        return a.value > b.value
    end)

    return pets
end

local function placeBest(plot, pets, lines)
    local slotCount = getSlotCount(plot)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        addLine(lines, "[AutoEquip] No humanoid found.")
        return
    end

    local placed = 0
    for i = 1, math.min(slotCount, #pets) do
        local entry = pets[i]
        local tool = entry.tool

        if tool and tool.Parent == player.Backpack then
            addLine(lines, "[AutoEquip] Placing", tool.Name, "into base slot", i)
            humanoid:EquipTool(tool)
            task.wait(0.8)
            Network.FireServer("S_Interact", i)
            task.wait(0.6)
            placed += 1
        else
            addLine(lines, "[AutoEquip] Missing tool before place:", entry.tool and entry.tool.Name or "nil")
        end
    end

    addLine(lines, "[AutoEquip] Placed", placed, "brainrots.")
end

local function copyLines(lines)
    local out = table.concat(lines, "\n")
    if setclipboard then
        pcall(setclipboard, out)
        print("Copied debug output to clipboard!")
    end
    print(out)
end

local function autoEquip()
    local lines = {}
    addLine(lines, "[AutoEquip] Starting...")

    local plot = getMyPlot()
    if not plot then
        addLine(lines, "[AutoEquip] No plot found.")
        copyLines(lines)
        return
    end

    addLine(lines, "[AutoEquip] Plot found.")
    addLine(lines, "[AutoEquip] Base slots:", getSlotCount(plot))

    pullAllPlacedBrainrots(plot, lines)

    addLine(lines, "[AutoEquip] Waiting for backpack refill...")
    task.wait(2.5)

    local pets = collectBrainrots(lines)
    addLine(lines, "[AutoEquip] Brainrots found:", #pets)

    addLine(lines, "[AutoEquip] Ranked order:")
    for i, entry in ipairs(pets) do
        addLine(
            lines,
            "#" .. i,
            entry.tool.Name,
            "| Lv:" .. tostring(entry.level),
            "| Mut:" .. tostring(entry.mutation),
            "| Val:" .. string.format("%.0f", entry.value)
        )
    end

    placeBest(plot, pets, lines)
    addLine(lines, "[AutoEquip] Done.")
    copyLines(lines)
end

if player.PlayerGui:FindFirstChild("AutoEquipGui") then
    player.PlayerGui.AutoEquipGui:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name = "AutoEquipGui"
sg.ResetOnSpawn = false
sg.Parent = player.PlayerGui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 155, 0, 36)
btn.Position = UDim2.new(1, -165, 0, 20)
btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Gotham
btn.TextSize = 14
btn.Text = "Auto Equip Best"
btn.Parent = sg
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

btn.MouseButton1Click:Connect(function()
    btn.Active = false
    btn.Text = "⏳ Running..."
    local ok, err = pcall(autoEquip)
    if not ok then
        warn("[AutoEquip] ERROR:", err)
    end
    btn.Text = "Auto Equip Best"
    btn.Active = true
end)
