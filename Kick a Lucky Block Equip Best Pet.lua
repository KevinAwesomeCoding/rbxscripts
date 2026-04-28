-- Auto Equip Best Pets LocalScript
-- Paste into a LocalScript in StarterPlayerScripts or execute via executor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Network = require(ReplicatedStorage.Shared.Packages.Network)

-- ─────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────

local function parseCoins(str)
	if not str then return 0 end
	local parts = str:split(", ")
	local m, e = tonumber(parts[1]), tonumber(parts[2])
	if not m or not e then return 0 end
	return m * (10 ^ e)
end

local function getPetValue(tool)
	local ok, result = pcall(function()
		local EntitiesData = require(ReplicatedStorage.Objects.Data.EntitiesData)
		local MutationData = require(ReplicatedStorage.Objects.Data.MutationData)
		local baseCPS = EntitiesData.Brainrots[tool.Name].CPS
		local mutation = tool:GetAttribute("Mutation") or "None"
		local multiplier = 1
		if MutationData[mutation] then
			multiplier = MutationData[mutation].Multiplier
				or MutationData[mutation].multiplier
				or MutationData[mutation]
				or 1
		elseif MutationData.Multipliers and MutationData.Multipliers[mutation] then
			multiplier = MutationData.Multipliers[mutation]
		end
		if type(multiplier) ~= "number" then multiplier = 1 end
		return baseCPS * multiplier
	end)
	if ok and result and result > 0 then return result end
	return parseCoins(tool:GetAttribute("Coins"))
end

local function getMyPlot()
	for _, model in ipairs(workspace.Plots:GetChildren()) do
		if model:GetAttribute("Owner") == player.Name then return model end
	end
	return nil
end

-- ─────────────────────────────────────────────
-- MAIN LOGIC
-- ─────────────────────────────────────────────

local function autoEquipBest()
	local plot = getMyPlot()
	if not plot then print("[AutoEquip] Plot not found") return end

	local slotCount = #plot.Slots:GetChildren()
	local rankedPets = {}
	local usedTools = {}

	-- Unequip all slots, capture direct tool references + real coin values
	for i = 1, slotCount do
		pcall(function()
			local slot = plot.Slots:FindFirstChild("Slot" .. i)
			if slot and slot:FindFirstChild("PlacedPart") then
				local coinValue = parseCoins(slot.PlacedPart:GetAttribute("Coins"))

				-- Snapshot backpack BEFORE unequip
				local before = {}
				for _, t in ipairs(player.Backpack:GetChildren()) do
					if t:IsA("Tool") then before[t] = true end
				end

				Network.FireServer("S_Interact", i)
				task.wait(0.4)

				-- Move anything held in character to backpack
				for _, item in ipairs(player.Character:GetChildren()) do
					if item:IsA("Tool") then item.Parent = player.Backpack end
				end
				task.wait(0.15)

				-- The NEW tool in backpack = the one that just came from the slot
				for _, t in ipairs(player.Backpack:GetChildren()) do
					if t:IsA("Tool") and not before[t] and not usedTools[t] then
						table.insert(rankedPets, { tool = t, value = coinValue })
						usedTools[t] = true
						break
					end
				end
			end
		end)
	end

	task.wait(1)

	-- Add remaining backpack pets that were never placed
	for _, tool in ipairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") and not usedTools[tool] then
			table.insert(rankedPets, { tool = tool, value = getPetValue(tool) })
			usedTools[tool] = true
		end
	end

	table.sort(rankedPets, function(a, b) return a.value > b.value end)

	-- Equip best N pets into slots
	local filled = 0
	for i = 1, math.min(slotCount, #rankedPets) do
		pcall(function()
			local tool = rankedPets[i].tool
			if not tool or not tool.Parent then return end
			tool.Parent = player.Character
			task.wait(0.2)
			Network.FireServer("S_Interact", i)
			task.wait(0.3)
			if tool.Parent == player.Character then tool.Parent = player.Backpack end
			filled += 1
		end)
	end

	print(string.format("[AutoEquip] Done! Filled %d / %d slots", filled, slotCount))
end

-- ─────────────────────────────────────────────
-- GUI
-- ─────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoEquipGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 150, 0, 35)
button.Position = UDim2.new(1, -160, 0, 20)
button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.Gotham
button.TextSize = 14
button.Text = "Auto Equip Best"
button.ZIndex = 10
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = button

button.MouseButton1Click:Connect(function()
	button.Active = false
	button.AutoButtonColor = false
	button.Text = "⏳ Running..."
	local ok, err = pcall(autoEquipBest)
	if not ok then print("[AutoEquip] Error:", err) end
	button.Text = "Auto Equip Best"
	button.Active = true
	button.AutoButtonColor = true
end)

print("[AutoEquip] Script loaded. Click the button in the top-right to run.")
