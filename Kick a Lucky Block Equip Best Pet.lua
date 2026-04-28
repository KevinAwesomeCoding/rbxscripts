local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Network = require(ReplicatedStorage.Shared.Packages.Network)

local okE, EntitiesData = pcall(require, ReplicatedStorage.Shared.Data.EntitiesData)
local okM, MutationData = pcall(require, ReplicatedStorage.Shared.Data.MutationData)

local running = false

local PICKUP_DELAY = 0.03
local POST_PICKUP_DELAY = 0.15
local EQUIP_DELAY = 0.08
local PLACE_DELAY = 0.08

local function addLine(lines, ...)
    local t = {}
    for i = 1, select("#", ...) do
        t[#t + 1] = tostring(select(i, ...))
    end
    lines[#lines + 1] = table.concat(t, " ")
end

local function isBrainrotTool(tool)
    return okE
        and tool
        and tool:IsA("Tool")
        and EntitiesData.Brainrots
        and EntitiesData.Brainrots[tool.Name] ~= nil
end

local function getBaseCPS(tool)
    if not isBrainrotTool(tool) then
        return 0
    end

    local data = EntitiesData.Brainrots[tool.Name]
    local cps = data.CPS

    if typeof(cps) == "table" and type(cps.first) == "number" and type(cps.second) == "number" then
        return cps.first * (10 ^ cps.second)
    end

    if type(cps) == "number" then
        return cps
    end

    return 0
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

local function getValue(tool)
    return getBaseCPS(tool) * getLevelMultiplier(tool) * getMutationMultiplier(tool)
end

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    for _, model in ipairs(plots:GetChildren()) do
        if model:GetAttribute("Owner") == player.Name then
            return model
        end
    end

    return nil
end

local function getOrderedSlots(plot)
    local slotsFolder = plot and plot:FindFirstChild("Slots")
    if not slotsFolder then return {} end

    local slots = {}
    for _, child in ipairs(slotsFolder:GetChildren()) do
        local n = tonumber(child.Name:match("^Slot(%d+)$"))
        if n then
            table.insert(slots, {index = n, slot = child})
        end
    end

    table.sort(slots, function(a, b)
        return a.index < b.index
    end)

    return slots
end

local function collectBrainrots(lines)
    local pets = {}

    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if isBrainrotTool(tool) then
                local level = tool:GetAttribute("Level") or 1
                local mutation = tool:GetAttribute("Mutation") or "None"
                local baseCPS = getBaseCPS(tool)
                local levelMult = getLevelMultiplier(tool)
                local mutMult = getMutationMultiplier(tool)
                local value = baseCPS * levelMult * mutMult

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

local function outputDebug(lines)
    local out = table.concat(lines, "\n")
    print(out)
end

local function autoEquip()
    local lines = {}
    addLine(lines, "[AutoEquip] Starting...")

    local plot = getMyPlot()
    if not plot then
        addLine(lines, "[AutoEquip] No plot found.")
        outputDebug(lines)
        return
    end

    local orderedSlots = getOrderedSlots(plot)
    addLine(lines, "[AutoEquip] Base slots found:", #orderedSlots)

    for _, entry in ipairs(orderedSlots) do
        if entry.slot:FindFirstChild("PlacedPart") then
            addLine(lines, "[Pickup] Base slot", entry.index)
            Network.FireServer("S_Interact", entry.index)
            task.wait(PICKUP_DELAY)
        end
    end

    addLine(lines, "[AutoEquip] Waiting for backpack update...")
    task.wait(POST_PICKUP_DELAY)

    local pets = collectBrainrots(lines)
    addLine(lines, "[AutoEquip] Brainrots found:", #pets)

    addLine(lines, "[AutoEquip] Ranked order:")
    for i, pet in ipairs(pets) do
        addLine(
            lines,
            "#" .. i,
            pet.tool.Name,
            "| Lv:" .. tostring(pet.level),
            "| Mut:" .. tostring(pet.mutation),
            "| Val:" .. string.format("%.0f", pet.value)
        )
    end

    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        addLine(lines, "[AutoEquip] No humanoid found.")
        outputDebug(lines)
        return
    end

    local placeCount = math.min(#orderedSlots, #pets)
    for i = 1, placeCount do
        local slotIndex = orderedSlots[i].index
        local tool = pets[i].tool

        if tool and tool.Parent == player.Backpack then
            addLine(lines, "[Place]", tool.Name, "-> base slot", slotIndex)
            humanoid:EquipTool(tool)
            task.wait(EQUIP_DELAY)
            Network.FireServer("S_Interact", slotIndex)
            task.wait(PLACE_DELAY)
        else
            addLine(lines, "[Missed Before Place]", tool and tool.Name or "nil", "for slot", slotIndex)
        end
    end

    addLine(lines, "[AutoEquip] Done.")
    outputDebug(lines)
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

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = btn

local function runAutoEquip()
    if running then return end
    running = true

    btn.Active = false
    btn.Text = "⏳ Running..."

    local ok, err = pcall(autoEquip)
    if not ok then
        warn("[AutoEquip] ERROR:", err)
    end

    btn.Text = "Auto Equip Best"
    btn.Active = true
    running = false
end

btn.Activated:Connect(runAutoEquip)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.P then
        runAutoEquip()
    end
end)
