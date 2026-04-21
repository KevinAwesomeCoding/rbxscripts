-- Services
local players          = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local runService       = game:GetService("RunService")
local httpService      = game:GetService("HttpService")
local tweenService     = game:GetService("TweenService")
local vim              = game:GetService("VirtualInputManager")
local starterGui       = game:GetService("StarterGui")

local player = players.LocalPlayer

-- ── ANTI-AFK ──────────────────────────────────────────────────────────────
local VirtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
task.spawn(function()
    task.wait(2)  -- wait for game to finish loading before showing notification
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title    = "AntiAFK loaded!",
            Text     = "Made by w4ckj",
            Button1  = "Thanks",
            Duration = 5,
        })
    end)
end)

-- ── STATE ──────────────────────────────────────────────────────────────────

local autoRemoveEnabled = false
local dragging          = false
local minSpeed, maxSpeed = 1, 150
local currentSpeed      = 16
local lastRatio         = (16 - 1) / (150 - 1)

local autoBuyEnabled  = false
local autoBuyRunning  = false
local carQueue        = {}
local dropdownOpen    = false

local autoCashEnabled = false
local autoCashRunning = false

local autoAdsEnabled  = false

-- ── TELEPORT METHODS ───────────────────────────────────────────────────────
local TELEPORT_METHODS = {
    { id = "anchor_snap",    label = "1. Anchor & Snap"       },
    { id = "heartbeat_lerp", label = "2. Heartbeat Lerp"      },
    { id = "player_only",    label = "3. Player Only"         },
    { id = "seated_root",    label = "4. Seated Root Move"    },
    { id = "skip",           label = "5. Skip (No Teleport)"  },
}
local currentMethodIndex = 1

local SAVE_FILE = "ObstacleRemover_Save.json"

-- ── CAR DATA (name + display label with rarity & price) ───────────────────

local carData = {
    -- Common
    { name = "1990 Toyato Helix",     display = "1990 Toyato Helix (Common) - Free"         },
    { name = "Volken Caddy Pick",     display = "Volken Caddy Pick (Common) - $8K"           },
    { name = "Mini Coopa",            display = "Mini Coopa (Common) - $16K"                 },
    { name = "Hondo NSX-R",           display = "Hondo NSX-R (Common) - $24K"                },
    { name = "Shinmei Apex 86R",      display = "Shinmei Apex 86R (Common) - $32K"           },
    { name = "Classic Pickup",        display = "Classic Pickup (Common) - $45K"             },
    { name = "Bugbyte Runner",        display = "Bugbyte Runner (Common) - $60K"             },
    -- Rare
    { name = "1970 Dodger Charger",   display = "1970 Dodger Charger (Rare) - $60K"          },
    { name = "Chevel Express",        display = "Chevel Express (Rare) - $100K"              },
    { name = "Dorge Charger X",       display = "Dorge Charger X (Rare) - $140K"             },
    { name = "Vandrix Comet XTR",     display = "Vandrix Comet XTR (Rare) - $180K"           },
    { name = "Bravus E3 Classic",     display = "Bravus E3 Classic (Rare) - $220K"           },
    { name = "Ironhoof Stallion GT",  display = "Ironhoof Stallion GT (Rare) - $260K"        },
    { name = "Crown Regent",          display = "Crown Regent (Rare) - $320K"                },
    { name = "Chromed '58 Royale",    display = "Chromed '58 Royale (Rare) - $420K"          },
    -- Epic
    { name = "Volk Buster",           display = "Volk Buster (Epic) - $300K"                 },
    { name = "Fiatto Ducana",         display = "Fiatto Ducana (Epic) - $400K"               },
    { name = "Audiq Q8S",             display = "Audiq Q8S (Epic) - $500K"                   },
    { name = "Tayoka Minari XS",      display = "Tayoka Minari XS (Epic) - $600K"            },
    { name = "Ravenbolt GTX500",      display = "Ravenbolt GTX500 (Epic) - $700K"            },
    { name = "Vornox Viperon S",      display = "Vornox Viperon S (Epic) - $800K"            },
    { name = "Hikaru S14 Driftline",  display = "Hikaru S14 Driftline (Epic) - $900K"        },
    { name = "Gravel-Sprint MK2",     display = "Gravel-Sprint MK2 (Epic) - $1.1M"           },
    -- Legendary
    { name = "Porcha Cayana",         display = "Porcha Cayana (Legendary) - $1M"            },
    { name = "Forda Raptora",         display = "Forda Raptora (Legendary) - $1.83M"         },
    { name = "Audi RS E-Torq",        display = "Audi RS E-Torq (Legendary) - $2.67M"        },
    { name = "Zamira S30 Heritage",   display = "Zamira S30 Heritage (Legendary) - $3.5M"    },
    { name = "Strato Lynx Rally",     display = "Strato Lynx Rally (Legendary) - $4.33M"     },
    { name = "Corvantis C3 Razorfin", display = "Corvantis C3 Razorfin (Legendary) - $5.17M" },
    { name = "Brutalion Roadmaster",  display = "Brutalion Roadmaster (Legendary) - $6M"     },
    { name = "Iron Titan",            display = "Iron Titan (Legendary) - $6.8M"             },
    { name = "Highland Bull",         display = "Highland Bull (Legendary) - $7.6M"          },
    { name = "Jimmy",                 display = "Jimmy (Legendary) - $8.4M"                  },
    { name = "Hercules",              display = "Hercules (Legendary) - $9.5M"               },
    -- Mythical
    { name = "Ford F-150 Raptura",    display = "Ford F-150 Raptura (Mythical) - $10M"       },
    { name = "Foyota Yarix",          display = "Foyota Yarix (Mythical) - $22M"             },
    { name = "Lamborgino Huraka",     display = "Lamborgino Huraka (Mythical) - $34M"        },
    { name = "Sukari Escadra V",      display = "Sukari Escadra V (Mythical) - $46M"         },
    { name = "Astoria Rapids V12",    display = "Astoria Rapids V12 (Mythical) - $58M"       },
    { name = "Korcha 9R Carrera-X",   display = "Korcha 9R Carrera-X (Mythical) - $70M"      },
    { name = "Iron Howler",           display = "Iron Howler (Mythical) - $85M"              },
    { name = "Aegis Response Rig",    display = "Aegis Response Rig (Mythical) - $78M"       },
    { name = "Interceptor Blaze",     display = "Interceptor Blaze (Mythical) - $84M"        },
    -- Godly
    { name = "Mizukai Evozen X",      display = "Mizukai Evozen X (Godly) - $120M"           },
    { name = "Nightcat Howler",       display = "Nightcat Howler (Godly) - $280M"            },
    { name = "Mercedez Sprinta",      display = "Mercedez Sprinta (Godly) - $230M"           },
    { name = "McLaren 720X",          display = "McLaren 720X (Godly) - $360M"               },
    { name = "V10 Phantomfang",       display = "V10 Phantomfang (Godly) - $560M"            },
    { name = "Shinmei Supraxis RZ",   display = "Shinmei Supraxis RZ (Godly) - $490M"        },
    { name = "Midnight Hauler",       display = "Midnight Hauler (Godly) - $680M"            },
    { name = "Lambera Murcana V12",   display = "Lambera Murcana V12 (Godly) - $620M"        },
    { name = "Borealis B2",           display = "Borealis B2 (Godly) - $820M"                },
    { name = "Ferono Testara V8",     display = "Ferono Testara V8 (Godly) - $750M"          },
    { name = "Machstorm '67",         display = "Machstorm '67 (Godly) - $900M"              },
    -- Secret
    { name = "Bugati Chyren",         display = "Bugati Chyren (Secret) - $1B"               },
    { name = "Crimson 812",           display = "Crimson 812 (Secret) - $1.42B"              },
    { name = "Endurance Wraith",      display = "Endurance Wraith (Secret) - $1.8B"          },
    { name = "Masario MCX20",         display = "Masario MCX20 (Secret) - $3B"               },
    { name = "Ramp Reaper",           display = "Ramp Reaper (Secret) - $3.8B"               },
    { name = "Rotary Revenant",       display = "Rotary Revenant (Secret) - $5.2B"           },
    { name = "Lambera Countrex 5000", display = "Lambera Countrex 5000 (Secret) - $5B"       },
    { name = "Skyward Valkyr",        display = "Skyward Valkyr (Secret) - $6.6B"            },
    { name = "Hikarion Skystream R",  display = "Hikarion Skystream R (Secret) - $7B"        },
    { name = "Irontrack Scout",       display = "Irontrack Scout (Secret) - $8.4B"           },
    -- Exclusive
    { name = "Hot Rod Veloce",        display = "Hot Rod Veloce (Exclusive) - $25B"          },
    { name = "Neon Synthesis V12",    display = "Neon Synthesis V12 (Exclusive) - $32B"      },
    { name = "Maclaren OneX Hyper",   display = "Maclaren OneX Hyper (Exclusive) - $40B"     },
    { name = "Obsidian Circuitblade", display = "Obsidian Circuitblade (Exclusive) - $55B"   },
    { name = "Kronis CXX HyperSport", display = "Kronis CXX HyperSport (Exclusive) - $70B"  },
    { name = "AeroPulse F2 '24",      display = "AeroPulse F2 '24 (Exclusive) - $85B"        },
    { name = "Ferono F4 Stradale",    display = "Ferono F4 Stradale (Exclusive) - $100B"     },
    { name = "Apex AP-0",             display = "Apex AP-0 (Exclusive) - $130B"              },
    { name = "Hotdog",                display = "Hotdog (Exclusive) - $120B"                 },
    { name = "WW Plane",              display = "WW Plane (Exclusive) - $160B"               },
    -- Hacker
    { name = "Baby Car",              display = "Baby Car (Hacker) - $750B"                  },
    { name = "Nyan Cat",              display = "Nyan Cat (Hacker) - $1T"                    },
    { name = "Space Shuttle",         display = "Space Shuttle (Hacker) - $3T"               },
    { name = "Saurus Stalker",        display = "Saurus Stalker (Hacker) - $5T"              },
    { name = "Lotusfire Exige",       display = "Lotusfire Exige (Hacker) - $8.5T"           },
}

local function getDisplayForName(carName)
    for _, entry in ipairs(carData) do
        if entry.name == carName then return entry.display end
    end
    return carName
end

-- ── SAVE / LOAD ────────────────────────────────────────────────────────────

local function saveSettings()
    pcall(function()
        local data = {
            autoRemoveEnabled = autoRemoveEnabled,
            currentSpeed      = currentSpeed,
            carQueue          = carQueue,
            autoBuyEnabled    = autoBuyEnabled,
            autoCashEnabled   = autoCashEnabled,
            autoAdsEnabled    = autoAdsEnabled,
        }
        writefile(SAVE_FILE, httpService:JSONEncode(data))
    end)
end

local function loadSettings()
    local ok, data = pcall(function()
        if isfile(SAVE_FILE) then
            return httpService:JSONDecode(readfile(SAVE_FILE))
        end
    end)
    return (ok and data) or {}
end

-- ── GUI SETUP ──────────────────────────────────────────────────────────────
-- Frame is taller (660) to accommodate the new Auto Cash section.

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ObstacleRemover"
screenGui.Parent = game.CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 820)
frame.Position = UDim2.new(0.4, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = false
frame.Parent = screenGui

-- Title bar
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
titleLabel.Text = "Obstacle Remover"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = frame

-- Delete Obstacles
local deleteButton = Instance.new("TextButton")
deleteButton.Size = UDim2.new(0, 221, 0, 30)
deleteButton.Position = UDim2.new(0, 20, 0, 38)
deleteButton.Text = "Delete Obstacles"
deleteButton.Font = Enum.Font.Gotham
deleteButton.TextSize = 13
deleteButton.Parent = frame

-- Auto Remove
local autoButton = Instance.new("TextButton")
autoButton.Size = UDim2.new(0, 221, 0, 30)
autoButton.Position = UDim2.new(0, 20, 0, 76)
autoButton.Text = "Auto Remove: OFF"
autoButton.Font = Enum.Font.Gotham
autoButton.TextSize = 13
autoButton.Parent = frame

-- Speed label
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 221, 0, 20)
speedLabel.Position = UDim2.new(0, 20, 0, 118)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "WalkSpeed: 16"
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 13
speedLabel.Parent = frame

-- Speed slider track
local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(0, 221, 0, 16)
sliderTrack.Position = UDim2.new(0, 20, 0, 144)
sliderTrack.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = sliderTrack
end

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(lastRatio, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = sliderFill
end

local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.new(0, 24, 0, 24)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.Position = UDim2.new(lastRatio, 0, 0.5, 0)
sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderKnob.BorderSizePixel = 0
sliderKnob.ZIndex = 2
sliderKnob.Parent = sliderTrack
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = sliderKnob
end

-- ── DIVIDER HELPER ────────────────────────────────────────────────────────

local function makeDivider(yPos)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 234, 0, 1)
    d.Position = UDim2.new(0, 13, 0, yPos)
    d.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    d.BorderSizePixel = 0
    d.Parent = frame
end

makeDivider(198)

-- ── AUTO BUY SECTION ───────────────────────────────────────────────────────

local carSelectLabel = Instance.new("TextLabel")
carSelectLabel.Size = UDim2.new(0, 221, 0, 20)
carSelectLabel.Position = UDim2.new(0, 20, 0, 208)
carSelectLabel.BackgroundTransparency = 1
carSelectLabel.Text = "Target Car:"
carSelectLabel.TextColor3 = Color3.new(1, 1, 1)
carSelectLabel.TextXAlignment = Enum.TextXAlignment.Left
carSelectLabel.Font = Enum.Font.GothamBold
carSelectLabel.TextSize = 13
carSelectLabel.Parent = frame

-- Dropdown button
local dropdownButton = Instance.new("TextButton")
dropdownButton.Size = UDim2.new(0, 221, 0, 30)
dropdownButton.Position = UDim2.new(0, 20, 0, 234)
dropdownButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
dropdownButton.TextColor3 = Color3.new(1, 1, 1)
dropdownButton.Text = "▼   Select a car..."
dropdownButton.Font = Enum.Font.Gotham
dropdownButton.TextSize = 11
dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
dropdownButton.ZIndex = 3
dropdownButton.Parent = frame
do
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,8); p.Parent = dropdownButton
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = dropdownButton
end

-- ── SEARCH BOX (overlay, shown when dropdown is open) ─────────────────────
-- Sits directly below the dropdown button, above the scroll list.
-- ZIndex 12 — above everything so it always captures input.

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0, 221, 0, 28)
searchBox.Position = UDim2.new(0, 20, 0, 266)   -- right below dropdown button
searchBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
searchBox.BorderSizePixel = 0
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.PlaceholderText = "Search cars..."
searchBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 11
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.ZIndex = 12
searchBox.Visible = false
searchBox.Parent = frame
do
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 8)
    p.Parent = searchBox
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = searchBox
end

-- Dropdown scroll list (starts 32px below search box)
local dropdownList = Instance.new("ScrollingFrame")
dropdownList.Size = UDim2.new(0, 221, 0, 152)
dropdownList.Position = UDim2.new(0, 20, 0, 298)   -- 266 + 28 + 4
dropdownList.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
dropdownList.BorderSizePixel = 0
dropdownList.ScrollBarThickness = 4
dropdownList.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
dropdownList.ZIndex = 10
dropdownList.Visible = false
dropdownList.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = dropdownList
    local l = Instance.new("UIListLayout"); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = dropdownList
end

local pendingCar = nil

-- Build dropdown items; keep references so search can show/hide them
local dropdownButtons = {}

for i, entry in ipairs(carData) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundTransparency = 1
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = entry.display
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 11
    btn.LayoutOrder = i
    btn.Parent = dropdownList
    do
        local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,8); p.Parent = btn
    end
    btn.MouseEnter:Connect(function()
        btn.BackgroundTransparency = 0
        btn.BackgroundColor3 = Color3.fromRGB(70,70,70)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundTransparency = 1
    end)
    btn.MouseButton1Click:Connect(function()
        pendingCar = entry.name
        dropdownButton.Text = "▼   " .. entry.display
        dropdownList.Visible = false
        searchBox.Visible = false
        searchBox.Text = ""
        dropdownOpen = false
        -- Restore all buttons for next open
        for _, b in ipairs(dropdownButtons) do b.Visible = true end
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, #carData * 26)
    end)
    dropdownButtons[i] = btn
end
dropdownList.CanvasSize = UDim2.new(0, 0, 0, #carData * 26)

-- ── SEARCH FILTERING ──────────────────────────────────────────────────────

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = searchBox.Text:lower()
    local visCount = 0
    for _, btn in ipairs(dropdownButtons) do
        local match = (query == "") or (btn.Text:lower():find(query, 1, true) ~= nil)
        btn.Visible = match
        if match then visCount += 1 end
    end
    dropdownList.CanvasSize = UDim2.new(0, 0, 0, visCount * 26)
    dropdownList.CanvasPosition = Vector2.zero  -- scroll back to top on each keystroke
end)

-- Add to Queue button
local addQueueButton = Instance.new("TextButton")
addQueueButton.Size = UDim2.new(0, 221, 0, 28)
addQueueButton.Position = UDim2.new(0, 20, 0, 272)
addQueueButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
addQueueButton.TextColor3 = Color3.new(1, 1, 1)
addQueueButton.Text = "+ Add to Priority Queue"
addQueueButton.Font = Enum.Font.Gotham
addQueueButton.TextSize = 12
addQueueButton.ZIndex = 2
addQueueButton.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = addQueueButton
end

-- Priority Queue label
local queueLabel = Instance.new("TextLabel")
queueLabel.Size = UDim2.new(0, 221, 0, 20)
queueLabel.Position = UDim2.new(0, 20, 0, 308)
queueLabel.BackgroundTransparency = 1
queueLabel.Text = "Priority Queue (top = first):"
queueLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
queueLabel.TextXAlignment = Enum.TextXAlignment.Left
queueLabel.Font = Enum.Font.GothamBold
queueLabel.TextSize = 11
queueLabel.ZIndex = 2
queueLabel.Parent = frame

-- Queue scroll frame
local queueScroll = Instance.new("ScrollingFrame")
queueScroll.Size = UDim2.new(0, 221, 0, 115)
queueScroll.Position = UDim2.new(0, 20, 0, 334)
queueScroll.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
queueScroll.BorderSizePixel = 0
queueScroll.ScrollBarThickness = 4
queueScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
queueScroll.ZIndex = 2
queueScroll.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = queueScroll
    local l = Instance.new("UIListLayout"); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = queueScroll
end

-- Auto Buy toggle
local autoBuyButton = Instance.new("TextButton")
autoBuyButton.Size = UDim2.new(0, 221, 0, 30)
autoBuyButton.Position = UDim2.new(0, 20, 0, 458)
autoBuyButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
autoBuyButton.TextColor3 = Color3.new(1, 1, 1)
autoBuyButton.Text = "Auto Buy: OFF"
autoBuyButton.Font = Enum.Font.Gotham
autoBuyButton.TextSize = 13
autoBuyButton.ZIndex = 2
autoBuyButton.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = autoBuyButton
end

-- Status label (shared by Auto Buy)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 221, 0, 20)
statusLabel.Position = UDim2.new(0, 20, 0, 496)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.ZIndex = 2
statusLabel.Parent = frame

makeDivider(524)

-- ── AUTO CASH SECTION ──────────────────────────────────────────────────────

local cashSectionLabel = Instance.new("TextLabel")
cashSectionLabel.Size = UDim2.new(0, 221, 0, 18)
cashSectionLabel.Position = UDim2.new(0, 20, 0, 531)
cashSectionLabel.BackgroundTransparency = 1
cashSectionLabel.Text = "Auto Cash:"
cashSectionLabel.TextColor3 = Color3.new(1, 1, 1)
cashSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
cashSectionLabel.Font = Enum.Font.GothamBold
cashSectionLabel.TextSize = 13
cashSectionLabel.ZIndex = 2
cashSectionLabel.Parent = frame

local autoCashButton = Instance.new("TextButton")
autoCashButton.Size = UDim2.new(0, 221, 0, 30)
autoCashButton.Position = UDim2.new(0, 20, 0, 553)
autoCashButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
autoCashButton.TextColor3 = Color3.new(1, 1, 1)
autoCashButton.Text = "Auto Cash: OFF"
autoCashButton.Font = Enum.Font.Gotham
autoCashButton.TextSize = 13
autoCashButton.ZIndex = 2
autoCashButton.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = autoCashButton
end

local cashStatusLabel = Instance.new("TextLabel")
cashStatusLabel.Size = UDim2.new(0, 221, 0, 20)
cashStatusLabel.Position = UDim2.new(0, 20, 0, 591)
cashStatusLabel.BackgroundTransparency = 1
cashStatusLabel.Text = "Cash: Idle"
cashStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
cashStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
cashStatusLabel.Font = Enum.Font.Gotham
cashStatusLabel.TextSize = 11
cashStatusLabel.ZIndex = 2
cashStatusLabel.Parent = frame

makeDivider(618)

-- ── FLY SECTION ────────────────────────────────────────────────────────────

local flySectionLabel = Instance.new("TextLabel")
flySectionLabel.Size = UDim2.new(0, 221, 0, 18)
flySectionLabel.Position = UDim2.new(0, 20, 0, 625)
flySectionLabel.BackgroundTransparency = 1
flySectionLabel.Text = "Vehicle Fly:"
flySectionLabel.TextColor3 = Color3.new(1, 1, 1)
flySectionLabel.TextXAlignment = Enum.TextXAlignment.Left
flySectionLabel.Font = Enum.Font.GothamBold
flySectionLabel.TextSize = 13
flySectionLabel.ZIndex = 2
flySectionLabel.Parent = frame

local flyButton = Instance.new("TextButton")
flyButton.Size = UDim2.new(0, 221, 0, 30)
flyButton.Position = UDim2.new(0, 20, 0, 647)
flyButton.BackgroundColor3 = Color3.fromRGB(80, 40, 150)
flyButton.TextColor3 = Color3.new(1, 1, 1)
flyButton.Text = "🛸  Open Fly GUI"
flyButton.Font = Enum.Font.Gotham
flyButton.TextSize = 13
flyButton.ZIndex = 2
flyButton.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = flyButton
end

makeDivider(685)

-- ── AUTO REMOVE ADS SECTION ────────────────────────────────────────────────

local autoAdsButton = Instance.new("TextButton")
autoAdsButton.Size = UDim2.new(0, 221, 0, 30)
autoAdsButton.Position = UDim2.new(0, 20, 0, 695)
autoAdsButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
autoAdsButton.TextColor3 = Color3.new(1, 1, 1)
autoAdsButton.Text = "🚫  Auto Remove Ads: OFF"
autoAdsButton.Font = Enum.Font.Gotham
autoAdsButton.TextSize = 12
autoAdsButton.ZIndex = 2
autoAdsButton.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = autoAdsButton
end

-- Rejoin
local rejoinButton = Instance.new("TextButton")
rejoinButton.Size = UDim2.new(0, 221, 0, 30)
rejoinButton.Position = UDim2.new(0, 20, 0, 733)
rejoinButton.BackgroundColor3 = Color3.fromRGB(150, 80, 20)
rejoinButton.TextColor3 = Color3.new(1, 1, 1)
rejoinButton.Text = "🔄  Rejoin"
rejoinButton.Font = Enum.Font.Gotham
rejoinButton.TextSize = 13
rejoinButton.ZIndex = 2
rejoinButton.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = rejoinButton
end

makeDivider(771)

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 221, 0, 25)
closeButton.Position = UDim2.new(0, 20, 0, 781)
closeButton.Text = "Close"
closeButton.Font = Enum.Font.Gotham
closeButton.TextSize = 13
closeButton.Parent = frame

-- ── STATUS HELPERS ─────────────────────────────────────────────────────────

local function setStatus(text, color)
    statusLabel.Text = "Status: " .. text
    statusLabel.TextColor3 = color or Color3.fromRGB(160, 160, 160)
end

local function setCashStatus(text, color)
    cashStatusLabel.Text = "Cash: " .. text
    cashStatusLabel.TextColor3 = color or Color3.fromRGB(160, 160, 160)
end

-- ── QUEUE UI ───────────────────────────────────────────────────────────────

local function rebuildQueueUI()
    for _, child in ipairs(queueScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for i, carName in ipairs(carQueue) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = i % 2 == 0 and 0 or 1
        row.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.ZIndex = 3
        row.Parent = queueScroll

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -30, 1, 0)
        lbl.Position = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "#" .. i .. "  " .. getDisplayForName(carName)
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.ZIndex = 4
        lbl.Parent = row

        local xBtn = Instance.new("TextButton")
        xBtn.Size = UDim2.new(0, 22, 0, 22)
        xBtn.Position = UDim2.new(1, -26, 0.5, -11)
        xBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        xBtn.TextColor3 = Color3.new(1, 1, 1)
        xBtn.Text = "✕"
        xBtn.Font = Enum.Font.GothamBold
        xBtn.TextSize = 10
        xBtn.ZIndex = 5
        xBtn.Parent = row
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = xBtn
        end

        local capturedName = carName
        xBtn.MouseButton1Click:Connect(function()
            for j, n in ipairs(carQueue) do
                if n == capturedName then
                    table.remove(carQueue, j)
                    break
                end
            end
            rebuildQueueUI()
            saveSettings()
        end)
    end
    queueScroll.CanvasSize = UDim2.new(0, 0, 0, #carQueue * 26)
end

-- ── CORE FUNCTIONS ─────────────────────────────────────────────────────────

local function removeAll()
    for _, obj in pairs(game:GetDescendants()) do
        if obj.Name == "OBSTACLES" or obj.Name == "Obstacles" then
            obj:Destroy()
        elseif obj.Name == "Humps" and obj:IsA("Model") then
            obj:Destroy()
        elseif obj.Name == "Meshes/QuickBump" then
            if obj.Parent and obj.Parent:IsA("Model") then
                obj.Parent:Destroy()
            end
        end
    end
end

local function setSpeed(ratio)
    lastRatio    = ratio
    currentSpeed = math.floor(minSpeed + (ratio * (maxSpeed - minSpeed)))
    speedLabel.Text = "WalkSpeed: " .. currentSpeed
    sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
    sliderKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
end

runService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = currentSpeed
    end
end)

local function getRatio(inputX, track)
    return math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
end

-- ── AUTO BUY FUNCTIONS ─────────────────────────────────────────────────────

local function findCarInWorld(carName)
    local spawnedCars = workspace:FindFirstChild("SpawnedCars")
    if not spawnedCars then return nil end
    for _, slot in pairs(spawnedCars:GetChildren()) do
        local ok, label = pcall(function()
            return slot:FindFirstChild("nameEffect"):FindFirstChild("PartName"):FindFirstChild("NameLabel")
        end)
        if ok and label and label:IsA("TextLabel") and label.Text == carName then
            return slot
        end
    end
    return nil
end

local function findHighestPriorityCar()
    for _, carName in ipairs(carQueue) do
        local model = findCarInWorld(carName)
        if model then
            return carName, model
        end
    end
    return nil, nil
end

local function teleportNearCar(carModel)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pivot
    if carModel.PrimaryPart then
        pivot = carModel.PrimaryPart.CFrame
    else
        for _, v in ipairs(carModel:GetDescendants()) do
            if v:IsA("BasePart") then pivot = v.CFrame; break end
        end
    end
    if pivot then
        root.CFrame = pivot * CFrame.new(0, 3, 4)
    end
end

-- ── VEHICLE FLY-TO-SPOT ───────────────────────────────────────────────────

local FLY_SPEED    = 80
local ARRIVE_DIST  = 6
local FLY_VEL_NAME = "AutoBuyFlyVelocity"
local FLY_GYRO_NAME= "AutoBuyFlyGyro"

local function setupFlyHandlers(rootPart)
    local ev = rootPart:FindFirstChild(FLY_VEL_NAME)
    local eg = rootPart:FindFirstChild(FLY_GYRO_NAME)
    if ev then ev:Destroy() end
    if eg then eg:Destroy() end

    local vel = Instance.new("BodyVelocity")
    vel.Name     = FLY_VEL_NAME
    vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    vel.Velocity = Vector3.zero
    vel.Parent   = rootPart

    local gyro = Instance.new("BodyGyro")
    gyro.Name      = FLY_GYRO_NAME
    gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    gyro.P         = 1000
    gyro.D         = 50
    gyro.CFrame    = rootPart.CFrame
    gyro.Parent    = rootPart

    return vel, gyro
end

-- ── NO-CLIP HELPERS ───────────────────────────────────────────────────────

local noClipOriginal = {}

local function enableNoClip(char)
    noClipOriginal = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            noClipOriginal[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.SeatPart then
        local vehicle = hum.SeatPart.Parent
        for _, part in ipairs(vehicle:GetDescendants()) do
            if part:IsA("BasePart") and noClipOriginal[part] == nil then
                noClipOriginal[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    end
end

local function disableNoClip()
    for part, original in pairs(noClipOriginal) do
        if part and part.Parent then
            part.CanCollide = original
        end
    end
    noClipOriginal = {}
end

local function removeFlyHandlers(rootPart)
    local ev = rootPart and rootPart:FindFirstChild(FLY_VEL_NAME)
    local eg = rootPart and rootPart:FindFirstChild(FLY_GYRO_NAME)
    if ev then ev:Destroy() end
    if eg then eg:Destroy() end
end

local function flyToPosition(rootPart, vel, gyro, targetPos, timeoutSecs)
    local elapsed = 0
    local done = Instance.new("BindableEvent")
    local conn

    conn = runService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if not rootPart or not rootPart.Parent or not vel or not vel.Parent then
            conn:Disconnect(); done:Fire(); return
        end

        local diff = targetPos - rootPart.Position
        local dist = diff.Magnitude

        if dist < ARRIVE_DIST or elapsed > timeoutSecs then
            vel.Velocity = Vector3.zero
            pcall(function() rootPart.AssemblyLinearVelocity  = Vector3.zero end)
            pcall(function() rootPart.AssemblyAngularVelocity = Vector3.zero end)
            conn:Disconnect(); done:Fire(); return
        end

        local flatDir = Vector3.new(diff.X, 0, diff.Z)
        if flatDir.Magnitude > 0.1 then
            gyro.CFrame = CFrame.new(Vector3.zero, flatDir)
        end

        vel.Velocity = diff.Unit * FLY_SPEED
    end)

    done.Event:Wait()
    done:Destroy()
end

-- ── VEHICLE CENTER OFFSET HELPER ──────────────────────────────────────────

local function getVehicleToPivotOffset(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.SeatPart then return Vector3.zero end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return Vector3.zero end

    local seat     = hum.SeatPart
    local bodyPart = seat.Parent
    local vehicle  = bodyPart and bodyPart.Parent

    if vehicle and vehicle:IsA("Model") and vehicle.PrimaryPart then
        return root.Position - vehicle.PrimaryPart.Position
    end

    if vehicle then
        local outer = vehicle.Parent
        if outer and outer:IsA("Model") and outer.PrimaryPart then
            return root.Position - outer.PrimaryPart.Position
        end
    end

    return Vector3.zero
end

local function flyCarToSpot()
    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and not hum.SeatPart then
        for _ = 1, 10 do
            task.wait(0.5)
            char = player.Character
            if not char then return end
            hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.SeatPart then break end
        end
    end

    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local vehicleOffset = getVehicleToPivotOffset(char)

    enableNoClip(char)
    local vel, gyro = setupFlyHandlers(rootPart)

    -- Waypoint 1: Cash transition
    local cashPos
    local ok1 = pcall(function()
        cashPos = workspace.Stages["1Stage"].Transition.Cash.Position + Vector3.new(0, 4, 0)
    end)
    if ok1 and cashPos then
        setStatus("Flying to Cash...", Color3.fromRGB(255, 200, 50))
        flyToPosition(rootPart, vel, gyro, cashPos, 20)
        task.wait(0.3)
    end

    -- Waypoint 2: ParkSpot.Hit — vehicle-center aligned
    -- Hit box: center (84.9033, 5.568, -420.467), size 10.69 × 7.07 × 20.51
    -- vehicleOffset corrects for seat position so the car body lands on center.
    local parkPos
    local ok2 = pcall(function()
        local hit = workspace.Stages["1Stage"].STAGE.ParkSpot.Hit
        parkPos = hit.Position + vehicleOffset + Vector3.new(0, 2, 0)
    end)
    if ok2 and parkPos then
        setStatus("Flying to ParkSpot...", Color3.fromRGB(255, 200, 50))
        flyToPosition(rootPart, vel, gyro, parkPos, 20)
    else
        setStatus("ParkSpot not found!", Color3.fromRGB(255, 80, 80))
    end

    -- Hold to bleed momentum
    if rootPart and rootPart.Parent and vel and vel.Parent then
        vel.Velocity = Vector3.zero
        local holdConn
        local holdTime = 0
        holdConn = runService.Heartbeat:Connect(function(dt)
            holdTime += dt
            pcall(function()
                vel.Velocity = Vector3.zero
                rootPart.AssemblyLinearVelocity  = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end)
            if holdTime >= 0.6 then holdConn:Disconnect() end
        end)
        task.wait(0.65)
    end

    disableNoClip()
    removeFlyHandlers(rootPart)
end

-- ── PRICE & CASH HELPERS ──────────────────────────────────────────────────
-- Parse the dollar amount out of a display string like "$1.83M" → 1830000.
-- Supports K / M / B / T suffixes and "Free".

local function parseDisplayPrice(displayStr)
    if displayStr:find("Free") then return 0 end
    local numStr, suffix = displayStr:match("%$([%d%.]+)([KMBTkmbt]?)")
    if not numStr then return math.huge end
    local n = tonumber(numStr) or 0
    suffix = suffix:upper()
    if     suffix == "K" then n = n * 1e3
    elseif suffix == "M" then n = n * 1e6
    elseif suffix == "B" then n = n * 1e9
    elseif suffix == "T" then n = n * 1e12
    end
    return n
end

local function getPriceForCar(carName)
    for _, entry in ipairs(carData) do
        if entry.name == carName then
            return parseDisplayPrice(entry.display)
        end
    end
    return 0  -- unknown car → assume free / already paid
end

-- Read the player's current cash from leaderstats.
-- The game uses a StringValue that looks like "$1,234,567" or a NumberValue.
-- We try both patterns and all common stat names.
local function getPlayerCash()
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return 0 end
    local candidates = { "Cash", "Money", "Coins", "Balance", "cash", "money" }
    for _, name in ipairs(candidates) do
        local stat = ls:FindFirstChild(name)
        if stat then
            if stat:IsA("NumberValue") or stat:IsA("IntValue") then
                return stat.Value
            elseif stat:IsA("StringValue") then
                -- strip "$", ",", spaces then parse
                local clean = stat.Value:gsub("[$,% ]", "")
                -- handle K/M/B/T suffixes on the string value too
                local n, suf = clean:match("([%d%.]+)([KMBTkmbt]?)")
                if n then
                    local v = tonumber(n) or 0
                    suf = suf:upper()
                    if     suf == "K" then v = v * 1e3
                    elseif suf == "M" then v = v * 1e6
                    elseif suf == "B" then v = v * 1e9
                    elseif suf == "T" then v = v * 1e12
                    end
                    return v
                end
            end
        end
    end
    return 0
end

-- Format a number into a short human-readable string (e.g. 1500000 → "$1.5M")
local function formatCash(n)
    if n >= 1e12 then return "$" .. string.format("%.2g", n/1e12) .. "T"
    elseif n >= 1e9  then return "$" .. string.format("%.2g", n/1e9)  .. "B"
    elseif n >= 1e6  then return "$" .. string.format("%.2g", n/1e6)  .. "M"
    elseif n >= 1e3  then return "$" .. string.format("%.2g", n/1e3)  .. "K"
    else return "$" .. tostring(math.floor(n))
    end
end

-- Perform one full cash-collect sweep (all Collect parts in the plot).
-- Returns number of parts touched, or -1 if base not found.
local function doOneCashSweep()
    if not findAndCachePlayerPlot() then return -1 end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end

    local originalCF    = root.CFrame
    local collideStates = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            collideStates[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local touched = 0
    for _, collectPart in ipairs(cachedCollectParts) do
        if collectPart and collectPart.Parent then
            root.CFrame = CFrame.new(collectPart.Position + Vector3.new(0, 2, 0))
            task.wait(0.5)
            touched += 1
        end
    end

    for part, orig in pairs(collideStates) do
        if part and part.Parent then part.CanCollide = orig end
    end
    root.CFrame = originalCF
    return touched
end

-- ── PERFORM AUTO BUY ───────────────────────────────────────────────────────

local function performAutoBuy(carName, carModel)
    autoBuyRunning = true

    -- ── Funds check ────────────────────────────────────────────────────────
    local required = getPriceForCar(carName)
    if required > 0 then
        local current = getPlayerCash()
        if current < required then
            -- Not enough — collect cash until we reach the target amount.
            -- We use the existing plot detection; if the base isn't found we
            -- skip collection and attempt the buy anyway (server will reject it
            -- if truly insufficient, so this is non-destructive).
            setStatus("Need " .. formatCash(required) .. " — collecting cash...",
                Color3.fromRGB(255, 160, 50))

            -- Make sure the plot is cached before looping
            if not findAndCachePlayerPlot() then
                setStatus("Base not found — attempting buy anyway...",
                    Color3.fromRGB(255, 80, 80))
                task.wait(2)
            else
                while autoBuyEnabled do
                    current = getPlayerCash()
                    if current >= required then break end

                    local stillNeeded = required - current
                    setStatus(
                        "Need " .. formatCash(stillNeeded) .. " more — collecting...",
                        Color3.fromRGB(255, 160, 50)
                    )

                    local swept = doOneCashSweep()
                    if swept < 0 then
                        -- Base disappeared mid-loop
                        cachedPlotFolder   = nil
                        cachedCollectParts = {}
                        setStatus("Lost base — retrying...", Color3.fromRGB(255, 80, 80))
                    end

                    task.wait(5)  -- regen cooldown between sweeps
                end

                if not autoBuyEnabled then
                    autoBuyRunning = false
                    return
                end
            end
        end
    end

    -- ── Proceed with purchase ───────────────────────────────────────────────
    setStatus("Found " .. carName .. "!", Color3.fromRGB(255, 200, 50))
    teleportNearCar(carModel)
    task.wait(0.4)

    setStatus("Holding E (1/2)...", Color3.fromRGB(255, 200, 50))
    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(5.1)
    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    task.wait(0.6)

    setStatus("Holding E (2/2)...", Color3.fromRGB(255, 200, 50))
    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(5.1)
    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    task.wait(0.5)

    flyCarToSpot()

    task.wait(2)
    setStatus("Done! Scanning...", Color3.fromRGB(80, 220, 100))
    task.wait(2)
    setStatus("Scanning...", Color3.fromRGB(160, 160, 160))
    autoBuyRunning = false
end

-- ── AUTO CASH FUNCTIONS ────────────────────────────────────────────────────
--
-- CONFIRMED HIERARCHY (from RBXLX analysis):
--
--   workspace.Plots
--     └── [1-6]           ← plot folder  (direct child of Plots)
--           └── Floors
--                 └── [1,2,3...]   ← floor folder
--                       ├── CarSpots
--                       │     └── [1-8]   ← slot folder
--                       │           └── Model → Model
--                       │                 └── Part "Collect"  ← green cash button
--                       └── Name (Folder)
--                             └── Model
--                                   └── Part "PlayerName"
--                                         └── SurfaceGui "GUI"
--                                               └── TextLabel
--                                                     .Text = "PlayerName's Plot"
--
-- DETECTION:
--   Scan workspace.Plots descendants for a TextLabel whose .Text equals
--   player.Name .. "'s Plot".  Walk UP exactly 7 levels to reach the
--   plot-level folder (direct child of Plots).  Then collect ALL Part
--   instances named "Collect" anywhere under that plot folder — one per
--   CarSpot slot, across every floor.
--
-- COLLECTION:
--   For each Collect part: save position + disable character collision
--   (no-clip), teleport HRP onto the part, wait for the server Touched
--   handler to fire, restore collision + return to original position.
--   Repeat every 5 seconds (matches in-game cash regen cooldown).

local cachedPlotFolder   = nil   -- the plot-level folder once found
local cachedCollectParts = {}    -- all Collect parts inside that plot

-- Walk up 'levels' ancestors from obj, return nil if out of bounds.
local function walkUp(obj, levels)
    local cur = obj
    for _ = 1, levels do
        if not cur then return nil end
        cur = cur.Parent
    end
    return cur
end

-- Scan Plots for the plot folder owned by this player, cache all Collect parts.
local function findAndCachePlayerPlot()
    -- Invalidate if the cached folder is gone
    if cachedPlotFolder and not cachedPlotFolder.Parent then
        cachedPlotFolder   = nil
        cachedCollectParts = {}
    end
    if cachedPlotFolder then return true end  -- still valid

    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end

    local targetText = player.Name .. "'s Plot"

    for _, obj in pairs(plots:GetDescendants()) do
        -- The owner TextLabel has no explicit Name; match by class + text
        if obj:IsA("TextLabel") and obj.Text == targetText then
            -- Runtime-confirmed (debug output):
            --   walkUp 1 = GUI (SurfaceGui)
            --   walkUp 2 = PlayerName (Model)
            --   walkUp 3 = Name (Folder)
            --   walkUp 4 = plot Folder (direct child of Plots) <-- correct
            local plotFolder = walkUp(obj, 4)
            if plotFolder and plotFolder.Parent == plots then
                -- Collect ALL "Collect" BaseParts under this plot
                local parts = {}
                for _, desc in pairs(plotFolder:GetDescendants()) do
                    if desc.Name == "Collect" and desc:IsA("BasePart") then
                        table.insert(parts, desc)
                    end
                end
                if #parts > 0 then
                    cachedPlotFolder   = plotFolder
                    cachedCollectParts = parts
                    return true
                end
            end
        end
    end

    return false
end

-- Disable character collision, teleport to part, wait for touch, restore.
-- Returns true on success.
local function touchCollectPart(collectPart, originalCF, collideStates)
    if not collectPart or not collectPart.Parent then return false end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    root.CFrame = CFrame.new(collectPart.Position + Vector3.new(0, 2, 0))
    task.wait(0.5)  -- hold for server Touched to fire

    return true
end

local function runAutoCash()
    autoCashRunning = true

    setCashStatus("Finding your base...", Color3.fromRGB(255, 200, 50))

    -- Retry up to 5 times (game may still be loading plots on join)
    local found = false
    for attempt = 1, 5 do
        if findAndCachePlayerPlot() then
            found = true
            break
        end
        setCashStatus("Searching... (attempt " .. attempt .. ")", Color3.fromRGB(255, 160, 50))
        task.wait(3)
    end

    if not found then
        setCashStatus("Base not found! Disable and retry.", Color3.fromRGB(255, 80, 80))
        autoCashRunning = false
        return
    end

    setCashStatus("Found " .. #cachedCollectParts .. " slot(s)! Collecting...",
        Color3.fromRGB(80, 220, 100))

    while autoCashEnabled do
        -- Re-validate cache each cycle in case of map reload
        local swept = doOneCashSweep()
        if swept < 0 then
            cachedPlotFolder   = nil
            cachedCollectParts = {}
            setCashStatus("Lost base, searching...", Color3.fromRGB(255, 160, 50))
            task.wait(3)
        else
            setCashStatus("Collected " .. swept .. " slot(s)! Next in 5s...",
                Color3.fromRGB(80, 220, 100))
            task.wait(5)
            if autoCashEnabled then
                setCashStatus("Collecting...", Color3.fromRGB(160, 160, 160))
            end
        end
    end

    setCashStatus("Idle", Color3.fromRGB(160, 160, 160))
    autoCashRunning = false
end

-- ── AUTO-REMOVE ADS LOGIC ─────────────────────────────────────────────────
--
-- Ad sources identified from game script analysis:
--
--  1. Favorite Item prompt  — CoreGui dialog triggered by
--       MarketplaceService:PromptSetFavorite(game.PlaceId, ...) on join.
--       Auto-clicks "No" the moment the dialog spawns.
--
--  2. Bundle popup          — PlayerGui.Windows.Bundle  (Enabled flag)
--       Re-shown every 600 s (TimeForBundleButtonToReappear = 600) with a
--       60-second "last chance" burst (LastChanceDuration = 60).
--
--  3. HUD Bundle button     — PlayerGui.Right.Bundle   (Visible flag)
--       Appears on the same 600-second cycle as the popup.
--
--  4. Spin popup            — PlayerGui.Windows.Spin   (Enabled flag)
--       Shown on join and on certain game events.
--
--  5. Robux Shop popup      — PlayerGui.Windows.RobuxShop (Enabled flag)
--       Triggered by in-game shop-open events.
--
-- Strategy: dual guard —
--   (a) DescendantAdded listeners on CoreGui & PlayerGui react instantly.
--   (b) A 0.5-second polling loop catches anything that slips through
--       (e.g. the game re-enabling Bundle.Enabled between poll ticks).

local function suppressAds()
    -- PlayerGui ad windows
    local pg = players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        pcall(function()
            local wins = pg:FindFirstChild("Windows")
            if wins then
                local bundle = wins:FindFirstChild("Bundle")
                if bundle and bundle.Enabled then bundle.Enabled = false end

                local spin = wins:FindFirstChild("Spin")
                if spin and spin.Enabled then spin.Enabled = false end

                local robux = wins:FindFirstChild("RobuxShop")
                if robux and robux.Enabled then robux.Enabled = false end
            end

            -- HUD bundle button (lives in PlayerGui.Right)
            local right = pg:FindFirstChild("Right")
            if right then
                local bundleBtn = right:FindFirstChild("Bundle")
                if bundleBtn and bundleBtn.Visible then
                    bundleBtn.Visible = false
                end
            end
        end)
    end

    -- CoreGui: dismiss any active Favorite Item / PromptSetFavorite dialog
    -- by auto-clicking the "No" button if the prompt is currently open.
    pcall(function()
        for _, obj in pairs(game.CoreGui:GetDescendants()) do
            if obj:IsA("TextButton") and obj.Text == "No" then
                local ancestor = obj.Parent
                while ancestor and ancestor ~= game.CoreGui do
                    local n = ancestor.Name:lower()
                    if n:find("favor") or n:find("prompt") or n:find("dialog") then
                        obj.MouseButton1Click:Fire()
                        break
                    end
                    ancestor = ancestor.Parent
                end
            end
        end
    end)
end

-- ── CONNECTIONS ────────────────────────────────────────────────────────────

-- Speed slider
sliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        setSpeed(getRatio(input.Position.X, sliderTrack))
    end
end)
sliderTrack.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        setSpeed(getRatio(input.Position.X, sliderTrack))
    end
end)
userInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragging then
            dragging = false
            saveSettings()
        end
    end
end)
userInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        setSpeed(getRatio(input.Position.X, sliderTrack))
    end
end)

-- Delete / Auto Remove
deleteButton.MouseButton1Click:Connect(removeAll)

autoButton.MouseButton1Click:Connect(function()
    autoRemoveEnabled = not autoRemoveEnabled
    autoButton.Text = autoRemoveEnabled and "Auto Remove: ON" or "Auto Remove: OFF"
    saveSettings()
end)

-- Dropdown toggle (also shows/hides search box)
dropdownButton.MouseButton1Click:Connect(function()
    dropdownOpen = not dropdownOpen
    searchBox.Visible   = dropdownOpen
    dropdownList.Visible = dropdownOpen
    if dropdownOpen then
        -- Reset search on open
        searchBox.Text = ""
        for _, b in ipairs(dropdownButtons) do b.Visible = true end
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, #carData * 26)
    end
end)

-- Add to queue
addQueueButton.MouseButton1Click:Connect(function()
    if not pendingCar then
        setStatus("Pick a car from the dropdown first!", Color3.fromRGB(255, 100, 100))
        task.delay(2, function() setStatus("Idle") end)
        return
    end
    for _, n in ipairs(carQueue) do
        if n == pendingCar then
            setStatus("Already in queue!", Color3.fromRGB(255, 160, 50))
            task.delay(2, function()
                setStatus(autoBuyEnabled and "Scanning..." or "Idle")
            end)
            return
        end
    end
    table.insert(carQueue, pendingCar)
    rebuildQueueUI()
    saveSettings()
    setStatus("Added: " .. pendingCar, Color3.fromRGB(80, 220, 100))
    task.delay(2, function()
        setStatus(autoBuyEnabled and "Scanning..." or "Idle")
    end)
end)

-- Auto Buy toggle
autoBuyButton.MouseButton1Click:Connect(function()
    if #carQueue == 0 then
        setStatus("Add cars to the queue first!", Color3.fromRGB(255, 100, 100))
        task.delay(2, function() setStatus("Idle") end)
        return
    end
    autoBuyEnabled = not autoBuyEnabled
    if autoBuyEnabled then
        autoBuyButton.Text = "Auto Buy: ON"
        autoBuyButton.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
        setStatus("Scanning...", Color3.fromRGB(160, 160, 160))
    else
        autoBuyButton.Text = "Auto Buy: OFF"
        autoBuyButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        autoBuyRunning = false
        setStatus("Idle")
    end
    saveSettings()
end)

-- Auto Cash toggle
autoCashButton.MouseButton1Click:Connect(function()
    autoCashEnabled = not autoCashEnabled
    if autoCashEnabled then
        autoCashButton.Text = "Auto Cash: ON"
        autoCashButton.BackgroundColor3 = Color3.fromRGB(0, 150, 50)
        if not autoCashRunning then
            task.spawn(runAutoCash)
        end
    else
        autoCashButton.Text = "Auto Cash: OFF"
        autoCashButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        setCashStatus("Idle")
    end
    saveSettings()
end)

-- Auto Ads toggle
autoAdsButton.MouseButton1Click:Connect(function()
    autoAdsEnabled = not autoAdsEnabled
    if autoAdsEnabled then
        autoAdsButton.Text = "🚫  Auto Remove Ads: ON"
        autoAdsButton.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
        suppressAds()
    else
        autoAdsButton.Text = "🚫  Auto Remove Ads: OFF"
        autoAdsButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    end
    saveSettings()
end)

-- Rejoin
rejoinButton.MouseButton1Click:Connect(function()
    rejoinButton.Text = "Rejoining..."
    rejoinButton.BackgroundColor3 = Color3.fromRGB(100, 50, 10)
    task.delay(0.3, function()
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, players.LocalPlayer)
        end)
    end)
end)
game.DescendantAdded:Connect(function(obj)
    if not autoRemoveEnabled then return end
    task.wait()
    if obj and obj.Parent then
        if obj.Name == "OBSTACLES" or obj.Name == "Obstacles" then
            obj:Destroy()
        elseif obj.Name == "Humps" and obj:IsA("Model") then
            obj:Destroy()
        elseif obj.Name == "Meshes/QuickBump" then
            if obj.Parent and obj.Parent:IsA("Model") then obj.Parent:Destroy() end
        end
    end
end)

closeButton.MouseButton1Click:Connect(function()
    autoCashEnabled = false
    autoBuyEnabled  = false
    autoAdsEnabled  = false
    screenGui:Destroy()
end)

-- ── LIVE AD INTERCEPTION ───────────────────────────────────────────────────

-- Catch FavoriteItem / PromptSetFavorite the instant it appears in CoreGui.
-- The game calls MarketplaceService:PromptSetFavorite on join (and possibly
-- on other events). The CoreGui dialog contains a "No" TextButton — we fire
-- a click on it immediately so the player never sees it.
game.CoreGui.DescendantAdded:Connect(function(obj)
    if not autoAdsEnabled then return end
    task.wait()  -- let the dialog finish constructing
    if not obj or not obj.Parent then return end
    pcall(function()
        -- Walk up to find a container whose name suggests a prompt/dialog
        local cur = obj
        local isFavoriteDialog = false
        for _ = 1, 6 do
            if not cur then break end
            local n = cur.Name:lower()
            if n:find("favor") or n:find("promptset") or n:find("dialog") or n:find("modal") then
                isFavoriteDialog = true
                break
            end
            cur = cur.Parent
        end
        if not isFavoriteDialog and not (obj:IsA("ScreenGui") and obj.Name:lower():find("favor")) then
            return
        end
        -- Search for the "No" button in the dialog subtree
        local root = obj:IsA("ScreenGui") and obj or obj.Parent
        if not root then return end
        for _, btn in pairs(root:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text == "No" then
                btn.MouseButton1Click:Fire()
                return
            end
        end
    end)
end)

-- Catch Bundle / Spin / RobuxShop the instant they become enabled in PlayerGui.
players.LocalPlayer.PlayerGui.DescendantAdded:Connect(function(obj)
    if not autoAdsEnabled then return end
    task.wait()
    if not obj or not obj.Parent then return end
    pcall(function()
        local n = obj.Name
        -- Hide HUD bundle button when it appears
        if (n == "Bundle" or n == "BundleButton") and obj:IsA("GuiObject") then
            obj.Visible = false
        end
        -- Disable Windows children when they're added/re-added
        if (n == "Bundle" or n == "Spin" or n == "RobuxShop") and obj:IsA("ScreenGui") then
            obj.Enabled = false
        end
    end)
end)

-- Fly GUI — loads the external Fe Vehicle Fly script via loadstring
flyButton.MouseButton1Click:Connect(function()
    flyButton.Text = "Loading..."
    flyButton.BackgroundColor3 = Color3.fromRGB(60, 30, 110)
    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet(
                "https://raw.githubusercontent.com/ScpGuest666/Random-Roblox-script/refs/heads/main/Roblox%20Fe%20Vehicle%20Fly%20GUI%20script"
            ))()
        end)
        if ok then
            flyButton.Text = "🛸  Fly GUI Loaded ✓"
            flyButton.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
        else
            flyButton.Text = "Load Failed — retry"
            flyButton.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
            warn("Fly GUI load error: " .. tostring(err))
        end
    end)
end)

-- ── AUTO BUY + ADS SCAN LOOP ───────────────────────────────────────────────

task.spawn(function()
    while task.wait(0.5) do
        -- Auto Buy
        if autoBuyEnabled and not autoBuyRunning and #carQueue > 0 then
            local carName, carModel = findHighestPriorityCar()
            if carName and carModel then
                task.spawn(function()
                    performAutoBuy(carName, carModel)
                end)
            end
        end
        -- Ad suppression polling (runs every 0.5 s — well within the game's
        -- 600-second bundle re-show timer, so it will always catch re-enables)
        if autoAdsEnabled then
            suppressAds()
        end
    end
end)

-- ── APPLY SAVED SETTINGS ──────────────────────────────────────────────────

task.spawn(function()
    task.wait(1)

    local saved = loadSettings()
    if not saved or next(saved) == nil then return end

    if saved.autoRemoveEnabled then
        autoRemoveEnabled = true
        autoButton.Text = "Auto Remove: ON"
    end

    if saved.currentSpeed then
        local ratio = (saved.currentSpeed - minSpeed) / (maxSpeed - minSpeed)
        setSpeed(math.clamp(ratio, 0, 1))
    end

    if saved.carQueue and type(saved.carQueue) == "table" then
        carQueue = saved.carQueue
        rebuildQueueUI()
    end

    if saved.autoBuyEnabled and #carQueue > 0 then
        autoBuyEnabled = true
        autoBuyButton.Text = "Auto Buy: ON"
        autoBuyButton.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
        setStatus("Scanning...", Color3.fromRGB(160, 160, 160))
    end

    if saved.autoCashEnabled then
        autoCashEnabled = true
        autoCashButton.Text = "Auto Cash: ON"
        autoCashButton.BackgroundColor3 = Color3.fromRGB(0, 150, 50)
        task.spawn(runAutoCash)
    end

    if saved.autoAdsEnabled then
        autoAdsEnabled = true
        autoAdsButton.Text = "🚫  Auto Remove Ads: ON"
        autoAdsButton.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
        suppressAds()
    end
end)

-- ── AUTO-DELETE ON LOAD ────────────────────────────────────────────────────

task.spawn(function()
    task.wait(0.5)
    removeAll()
end)
