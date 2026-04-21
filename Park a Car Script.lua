-- Services
local players          = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local runService       = game:GetService("RunService")
local httpService      = game:GetService("HttpService")
local tweenService     = game:GetService("TweenService")
local vim              = game:GetService("VirtualInputManager")
local starterGui       = game:GetService("StarterGui")

local player = players.LocalPlayer

-- ── WEBHOOK SETUP ─────────────────────────────────────────────────────────

local WEBHOOK_URL    = "YOUR_WEBHOOK_HERE"
local webhookEnabled = false

-- ── WEBHOOK FILTER TABLES (edit these to control notifications) ───────────
-- 1. Specific cars by display name (empty = no car filter)
local webhookFilterCars = {
    -- e.g. "Porcha Cayana",
}
-- 2. Rarities (empty = no rarity filter)
local webhookFilterRarities = {
    -- e.g. "Legendary", "Godly", "Secret",
}
-- 3. Types from nameEffect.Type StringValue (empty = no type filter)
local webhookFilterTypes = {
    -- e.g. "Special",
}

-- A notification fires if the car matches ANY active filter.
-- If ALL three tables are empty, every car in SpawnedCars will notify.
local webhookSeen = {}  -- keyed by car instance, prevents duplicate fires

-- ── CAR ICON MAP (MeshId → thumbnail) ────────────────────────────────────

local carIconMap = {
    ["Car1"]  = "110216476511999",
    ["Car2"]  = "126365735065041",
    ["Car3"]  = "78620792236154",
    ["Car4"]  = "129219317176062",
    ["Car5"]  = "88363247535066",
    ["Car6"]  = "107308563107794",
    ["Car7"]  = "129235040695348",
    ["Car8"]  = "131100542718300",
    ["Car9"]  = "132321111811051",
    ["Car10"] = "126935589498772",
    ["Car11"] = "80362695680079",
    ["Car12"] = "97546942625129",
    ["Car13"] = "112891411975011",
    ["Car14"] = "75638163978874",
    ["Car15"] = "97546942625129",
    ["Car16"] = "71158203604487",
    ["Car17"] = "132694860140953",
    ["Car18"] = "83344620020319",
    ["Car19"] = "138579119820087",
    ["Car20"] = "116719541206004",
    ["Car21"] = "94026463693744",
    ["Car22"] = "85040913800778",
    ["Car23"] = "112969039325805",
    ["Car24"] = "126634224136626",
    ["Car25"] = "81125038487604",
    ["Car26"] = "93868763106186",
    ["Car27"] = "129366716917946",
    ["Car28"] = "122436859768901",
    ["Car29"] = "115946421868832",
    ["Car30"] = "104543648746618",
    ["Car31"] = "136565410362916",
    ["Car32"] = "116792736022199",
    ["Car33"] = "130241990440579",
    ["Car34"] = "119035735686043",
    ["Car35"] = "132068269634363",
    ["Car36"] = "89016076663074",
    ["Car37"] = "83806329101173",
    ["Car38"] = "137058080211001",
    ["Car39"] = "79828807639787",
    ["Car40"] = "125269961496015",
    ["Car41"] = "139111721708519",
    ["Car42"] = "70713214528468",
    ["Car43"] = "82786447061148",
    ["Car44"] = "134505076193249",
    ["Car45"] = "105508380412372",
    -- Car46 = no mesh (regular Part), skip thumbnail
    ["Car47"] = "95686459489330",
    ["Car48"] = "91534411122197",
    ["Car49"] = "131039314426017",
    ["Car50"] = "93050137848574",
    ["Car51"] = "115484277550691",
    ["Car52"] = "5918550231",
    ["Car53"] = "103467991603728",
    ["Car54"] = "84639568702831",
    ["Car55"] = "118083709561576",
    ["Car56"] = "140121436178414",
    ["Car57"] = "123469320030830",
    ["Car58"] = "74905098064755",
    ["Car59"] = "110252179148935",
    ["Car60"] = "95182435311562",
    ["Car61"] = "88109308171720",
    ["Car62"] = "87385161299883",
    ["Car63"] = "94646532699196",
    ["Car64"] = "104164872354511",
    ["Car65"] = "138235415873443",
    ["Car66"] = "102484034422180",
    ["Car67"] = "124099900794686",
    ["Car68"] = "77742951526690",
    ["Car69"] = "73428282872460",
    ["Car70"] = "108064288159576",
    ["Car71"] = "134530398411830",
    ["Car72"] = "137703479538833",
    ["Car73"] = "87640643649210",
    ["Car74"] = "105954369453774",
    ["Car75"] = "128065278451851",
    ["Car76"] = "126585364491830",
    ["Car77"] = "76993910664036",
    ["Car78"] = "71340455257310",
    ["Car79"] = "131594019389205",
}

-- Rarity embed colors
local rarityColors = {
    ["Common"]    = 0x888888,
    ["Rare"]      = 0x4444FF,
    ["Epic"]      = 0xAA00FF,
    ["Legendary"] = 0xFFD700,
    ["Mythical"]  = 0xFF00FF,
    ["Godly"]     = 0xFF4444,
    ["Secret"]    = 0x222222,
    ["Exclusive"] = 0x00FFFF,
    ["Hacker"]    = 0x00FF00,
}

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

-- ── FILTER STATE ───────────────────────────────────────────────────────────
local rarityFilter   = {}   -- e.g. {"Legendary", "Mythical"}
local pendingCarTypes = {}  -- set of selected types for next queue addition, e.g. {"Gold","Rainbow"}
                            -- empty = Any (match all types)
-- Buy-limit tables: carName → limit (number or nil = infinite)
local carBuyLimit   = {}   -- carName → how many times to buy (nil = unlimited)
local carBuyCount   = {}   -- carName → how many times bought so far

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

-- Map from car display name → car key (Car1, Car2, …)
-- Index position in carData matches the car number.
local carNameToKey = {}
for i, entry in ipairs(carData) do
    carNameToKey[entry.name] = "Car" .. i
end

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
            rarityFilter      = rarityFilter,
            carBuyLimit       = carBuyLimit,
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
frame.Size = UDim2.new(0, 260, 0, 1220)
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

-- ── RARITY FILTER SECTION ──────────────────────────────────────────────────

local rarityFilterLabel = Instance.new("TextLabel")
rarityFilterLabel.Size = UDim2.new(0, 221, 0, 18)
rarityFilterLabel.Position = UDim2.new(0, 20, 0, 531)
rarityFilterLabel.BackgroundTransparency = 1
rarityFilterLabel.Text = "Rarity Filter (Auto-Queue):"
rarityFilterLabel.TextColor3 = Color3.new(1, 1, 1)
rarityFilterLabel.TextXAlignment = Enum.TextXAlignment.Left
rarityFilterLabel.Font = Enum.Font.GothamBold
rarityFilterLabel.TextSize = 12
rarityFilterLabel.ZIndex = 2
rarityFilterLabel.Parent = frame

-- Rarity toggle buttons — 3 per row
local RARITIES = {
    "Common", "Rare", "Epic",
    "Legendary", "Mythical", "Godly",
    "Secret", "Exclusive", "Hacker"
}
local rarityToggleButtons = {}
local RARITY_BTN_W = 68
local RARITY_BTN_H = 20
local RARITY_COLS  = 3
local RARITY_START_Y = 553

for idx, rarity in ipairs(RARITIES) do
    local col = (idx - 1) % RARITY_COLS
    local row = math.floor((idx - 1) / RARITY_COLS)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, RARITY_BTN_W, 0, RARITY_BTN_H)
    btn.Position = UDim2.new(0, 20 + col * (RARITY_BTN_W + 4), 0, RARITY_START_Y + row * (RARITY_BTN_H + 3))
    btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = rarity
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 9
    btn.ZIndex = 2
    btn.Parent = frame
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = btn
    end
    rarityToggleButtons[rarity] = btn
end

-- Active rarity filter summary label
local rarityActiveLabel = Instance.new("TextLabel")
rarityActiveLabel.Size = UDim2.new(0, 221, 0, 14)
rarityActiveLabel.Position = UDim2.new(0, 20, 0, RARITY_START_Y + 3 * (RARITY_BTN_H + 3) + 2)
rarityActiveLabel.BackgroundTransparency = 1
rarityActiveLabel.Text = "Rarity Filter: (none)"
rarityActiveLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
rarityActiveLabel.TextXAlignment = Enum.TextXAlignment.Left
rarityActiveLabel.Font = Enum.Font.Gotham
rarityActiveLabel.TextSize = 9
rarityActiveLabel.ZIndex = 2
rarityActiveLabel.Parent = frame

local RARITY_SECTION_END = RARITY_START_Y + 3 * (RARITY_BTN_H + 3) + 20  -- ~622

-- Helper to refresh the rarity label and button colours (defined later, after rarityFilter exists)
local function refreshRarityUI()
    if #rarityFilter == 0 then
        rarityActiveLabel.Text = "Rarity Filter: (none)"
    else
        rarityActiveLabel.Text = "Rarity Filter: " .. table.concat(rarityFilter, ", ")
    end
    for _, r in ipairs(RARITIES) do
        local btn = rarityToggleButtons[r]
        local active = false
        for _, f in ipairs(rarityFilter) do
            if f == r then active = true; break end
        end
        btn.BackgroundColor3 = active
            and Color3.fromRGB(0, 130, 200)
            or  Color3.fromRGB(55, 55, 55)
    end
end

makeDivider(RARITY_SECTION_END)

-- ── TYPE FILTER SECTION ────────────────────────────────────────────────────
-- Type is per-queue-entry, selected before clicking "+ Add to Priority Queue".
-- Multiple types can be selected at once. "Any" clears all specific types.

local TYPE_SECTION_Y = RARITY_SECTION_END + 7

local typeFilterSectionLabel = Instance.new("TextLabel")
typeFilterSectionLabel.Size = UDim2.new(0, 221, 0, 16)
typeFilterSectionLabel.Position = UDim2.new(0, 20, 0, TYPE_SECTION_Y)
typeFilterSectionLabel.BackgroundTransparency = 1
typeFilterSectionLabel.Text = "Car Type (for next queue entry):"
typeFilterSectionLabel.TextColor3 = Color3.new(1, 1, 1)
typeFilterSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
typeFilterSectionLabel.Font = Enum.Font.GothamBold
typeFilterSectionLabel.TextSize = 12
typeFilterSectionLabel.ZIndex = 2
typeFilterSectionLabel.Parent = frame

-- 5 toggle buttons: Any, Gold, Diamond, Rainbow, Galaxy
-- Any = no type filter (matches all). Specific types can be multi-selected.
local CAR_TYPES    = { "Any", "Gold", "Diamond", "Rainbow", "Galaxy" }
local typeRadioButtons = {}
local TYPE_BTN_W   = 39
local TYPE_BTN_H   = 22

for idx, typeName in ipairs(CAR_TYPES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, TYPE_BTN_W, 0, TYPE_BTN_H)
    btn.Position = UDim2.new(0, 20 + (idx - 1) * (TYPE_BTN_W + 4), 0, TYPE_SECTION_Y + 20)
    -- "Any" is highlighted by default (pendingCarTypes is empty = any)
    btn.BackgroundColor3 = idx == 1
        and Color3.fromRGB(0, 130, 200)
        or  Color3.fromRGB(55, 55, 55)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = typeName
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 9
    btn.ZIndex = 2
    btn.Parent = frame
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = btn
    end
    typeRadioButtons[typeName] = btn
end

-- Refresh button highlights to match pendingCarTypes
local function refreshTypeRadioUI()
    local anySelected = (#pendingCarTypes == 0)
    typeRadioButtons["Any"].BackgroundColor3 = anySelected
        and Color3.fromRGB(0, 130, 200)
        or  Color3.fromRGB(55, 55, 55)
    for _, typeName in ipairs(CAR_TYPES) do
        if typeName ~= "Any" then
            local active = false
            for _, t in ipairs(pendingCarTypes) do
                if t == typeName then active = true; break end
            end
            typeRadioButtons[typeName].BackgroundColor3 = active
                and Color3.fromRGB(0, 130, 200)
                or  Color3.fromRGB(55, 55, 55)
        end
    end
end

local TYPE_SECTION_END = TYPE_SECTION_Y + 50

makeDivider(TYPE_SECTION_END)

-- ── AUTO CASH SECTION ──────────────────────────────────────────────────────

local AUTO_CASH_Y = TYPE_SECTION_END + 7

local cashSectionLabel = Instance.new("TextLabel")
cashSectionLabel.Size = UDim2.new(0, 221, 0, 18)
cashSectionLabel.Position = UDim2.new(0, 20, 0, AUTO_CASH_Y)
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
autoCashButton.Position = UDim2.new(0, 20, 0, AUTO_CASH_Y + 22)
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
cashStatusLabel.Position = UDim2.new(0, 20, 0, AUTO_CASH_Y + 60)
cashStatusLabel.BackgroundTransparency = 1
cashStatusLabel.Text = "Cash: Idle"
cashStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
cashStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
cashStatusLabel.Font = Enum.Font.Gotham
cashStatusLabel.TextSize = 11
cashStatusLabel.ZIndex = 2
cashStatusLabel.Parent = frame

local AUTO_CASH_DIVIDER = AUTO_CASH_Y + 87
makeDivider(AUTO_CASH_DIVIDER)

-- ── FLY SECTION ────────────────────────────────────────────────────────────

local FLY_SECTION_Y = AUTO_CASH_DIVIDER + 7

local flySectionLabel = Instance.new("TextLabel")
flySectionLabel.Size = UDim2.new(0, 221, 0, 18)
flySectionLabel.Position = UDim2.new(0, 20, 0, FLY_SECTION_Y)
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
flyButton.Position = UDim2.new(0, 20, 0, FLY_SECTION_Y + 22)
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

local FLY_DIVIDER = FLY_SECTION_Y + 60
makeDivider(FLY_DIVIDER)

-- ── AUTO REMOVE ADS SECTION ────────────────────────────────────────────────

local ADS_SECTION_Y = FLY_DIVIDER + 7

local autoAdsButton = Instance.new("TextButton")
autoAdsButton.Size = UDim2.new(0, 221, 0, 30)
autoAdsButton.Position = UDim2.new(0, 20, 0, ADS_SECTION_Y)
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
rejoinButton.Position = UDim2.new(0, 20, 0, ADS_SECTION_Y + 38)
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

local CLOSE_DIVIDER = ADS_SECTION_Y + 76
makeDivider(CLOSE_DIVIDER)

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 221, 0, 25)
closeButton.Position = UDim2.new(0, 20, 0, CLOSE_DIVIDER + 6)
closeButton.Text = "Close"
closeButton.Font = Enum.Font.Gotham
closeButton.TextSize = 13
closeButton.Parent = frame

-- Webhook Notify toggle
local webhookButton = Instance.new("TextButton")
webhookButton.Size = UDim2.new(0, 221, 0, 30)
webhookButton.Position = UDim2.new(0, 20, 0, CLOSE_DIVIDER + 39)
webhookButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
webhookButton.TextColor3 = Color3.new(1, 1, 1)
webhookButton.Text = "Webhook Notify: OFF"
webhookButton.Font = Enum.Font.Gotham
webhookButton.TextSize = 12
webhookButton.ZIndex = 2
webhookButton.Parent = frame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = webhookButton
end

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
    for i, entry in ipairs(carQueue) do
        -- Support both new {name, types} tables and legacy bare strings / old {name, type}
        local carName
        local carTypes  -- list of type strings, empty = Any
        if type(entry) == "table" then
            carName  = entry.name
            if type(entry.types) == "table" then
                carTypes = entry.types
            elseif type(entry.type) == "string" and entry.type ~= "" then
                carTypes = { entry.type }  -- migrate old single-type format
            else
                carTypes = {}
            end
        else
            carName  = entry
            carTypes = {}
        end
        local typeDisplay = (#carTypes == 0) and "Any" or table.concat(carTypes, "/")

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundTransparency = i % 2 == 0 and 0 or 1
        row.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.ZIndex = 3
        row.Parent = queueScroll

        -- "#1  Porcha Cayana — Gold/Rainbow" label (top half)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -54, 0, 18)
        lbl.Position = UDim2.new(0, 6, 0, 2)
        lbl.BackgroundTransparency = 1
        lbl.Text = "#" .. i .. "  " .. carName .. " — " .. typeDisplay
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.ZIndex = 4
        lbl.Parent = row

        -- Buy count display (bottom half)
        local buyCountLbl = Instance.new("TextLabel")
        buyCountLbl.Size = UDim2.new(0, 80, 0, 14)
        buyCountLbl.Position = UDim2.new(0, 6, 0, 21)
        buyCountLbl.BackgroundTransparency = 1
        local limit = carBuyLimit[carName]
        local count = carBuyCount[carName] or 0
        if limit then
            buyCountLbl.Text = "Bought: " .. count .. "/" .. limit
            buyCountLbl.TextColor3 = count >= limit
                and Color3.fromRGB(255, 80, 80)
                or  Color3.fromRGB(100, 220, 100)
        else
            buyCountLbl.Text = "Limit: ∞"
            buyCountLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
        end
        buyCountLbl.Font = Enum.Font.Gotham
        buyCountLbl.TextSize = 9
        buyCountLbl.TextXAlignment = Enum.TextXAlignment.Left
        buyCountLbl.ZIndex = 4
        buyCountLbl.Parent = row

        -- Limit text box
        local limitBox = Instance.new("TextBox")
        limitBox.Size = UDim2.new(0, 38, 0, 14)
        limitBox.Position = UDim2.new(0, 90, 0, 21)
        limitBox.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        limitBox.BorderSizePixel = 0
        limitBox.TextColor3 = Color3.new(1, 1, 1)
        limitBox.PlaceholderText = "Limit"
        limitBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
        limitBox.Text = limit and tostring(limit) or ""
        limitBox.Font = Enum.Font.Gotham
        limitBox.TextSize = 9
        limitBox.ClearTextOnFocus = false
        limitBox.ZIndex = 5
        limitBox.Parent = row
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,3); c.Parent = limitBox
        end

        -- Confirm limit button
        local setBtn = Instance.new("TextButton")
        setBtn.Size = UDim2.new(0, 22, 0, 14)
        setBtn.Position = UDim2.new(0, 132, 0, 21)
        setBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 180)
        setBtn.TextColor3 = Color3.new(1, 1, 1)
        setBtn.Text = "✓"
        setBtn.Font = Enum.Font.GothamBold
        setBtn.TextSize = 9
        setBtn.ZIndex = 5
        setBtn.Parent = row
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,3); c.Parent = setBtn
        end

        -- Remove button (×)
        local xBtn = Instance.new("TextButton")
        xBtn.Size = UDim2.new(0, 22, 0, 32)
        xBtn.Position = UDim2.new(1, -26, 0.5, -16)
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
        local capturedIdx  = i
        setBtn.MouseButton1Click:Connect(function()
            local val = tonumber(limitBox.Text)
            if val and val >= 1 then
                carBuyLimit[capturedName] = math.floor(val)
            else
                carBuyLimit[capturedName] = nil
                limitBox.Text = ""
            end
            saveSettings()
            rebuildQueueUI()
        end)

        xBtn.MouseButton1Click:Connect(function()
            table.remove(carQueue, capturedIdx)
            carBuyLimit[capturedName] = nil
            carBuyCount[capturedName] = nil
            rebuildQueueUI()
            saveSettings()
        end)
    end
    queueScroll.CanvasSize = UDim2.new(0, 0, 0, #carQueue * 38)
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

local function isInQueue(name)
    for _, entry in ipairs(carQueue) do
        local entryName = type(entry) == "table" and entry.name or entry
        if entryName == name then return true end
    end
    return false
end

-- Read the short car name from a spawned slot via NameLabel
local function getCarNameFromSlot(slot)
    local ok, label = pcall(function()
        return slot:FindFirstChild("nameEffect"):FindFirstChild("PartName"):FindFirstChild("NameLabel")
    end)
    if ok and label and label:IsA("TextLabel") then
        return label.Text
    end
    return nil
end

-- Read the Type StringValue from a spawned slot
local function getCarTypeFromSlot(slot)
    local t = ""
    pcall(function()
        local sv = slot:FindFirstChild("nameEffect") and
                   slot:FindFirstChild("nameEffect"):FindFirstChild("Type")
        if sv and sv:IsA("StringValue") then t = sv.Value end
    end)
    return t
end

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

-- Scan SpawnedCars and auto-add any rarity filter matches to carQueue.
-- Type is per-entry, not a global filter, so only rarity is injected here.
local function injectFilterMatches()
    local spawnedCars = workspace:FindFirstChild("SpawnedCars")
    if not spawnedCars then return end

    for _, slot in pairs(spawnedCars:GetChildren()) do
        local carName = getCarNameFromSlot(slot)
        if carName and not isInQueue(carName) then
            local displayStr = getDisplayForName(carName)
            local rarity     = displayStr:match("%((.-)%)") or ""

            local matched = false
            for _, r in ipairs(rarityFilter) do
                if r == rarity then matched = true; break end
            end

            if matched then
                -- Rarity-injected entries use Any type (match any type on the spot)
                table.insert(carQueue, { name = carName, type = "" })
                rebuildQueueUI()
                saveSettings()
            end
        end
    end
end

local function findHighestPriorityCar()
    -- Inject rarity filter matches before scanning
    injectFilterMatches()

    local spawnedCars = workspace:FindFirstChild("SpawnedCars")
    if not spawnedCars then return nil, nil end

    -- Priority 1: explicit carQueue entries in order, matching name AND types
    for _, entry in ipairs(carQueue) do
        local carName  = type(entry) == "table" and entry.name or entry
        -- Resolve types list — support old {type=""} single-type format
        local wantTypes
        if type(entry) == "table" then
            if type(entry.types) == "table" then
                wantTypes = entry.types
            elseif type(entry.type) == "string" and entry.type ~= "" then
                wantTypes = { entry.type }
            else
                wantTypes = {}
            end
        else
            wantTypes = {}
        end

        for _, slot in pairs(spawnedCars:GetChildren()) do
            local slotName = getCarNameFromSlot(slot)
            if slotName == carName then
                if #wantTypes == 0 then
                    -- Any type matches
                    return carName, slot
                else
                    local slotType = getCarTypeFromSlot(slot)
                    for _, wt in ipairs(wantTypes) do
                        if slotType == wt then
                            return carName, slot
                        end
                    end
                end
            end
        end
    end

    -- Priority 2: rarity-filter fallback
    if #rarityFilter > 0 then
        for _, slot in pairs(spawnedCars:GetChildren()) do
            local carName = getCarNameFromSlot(slot)
            if carName and not isInQueue(carName) then
                local displayStr = getDisplayForName(carName)
                local rarity     = displayStr:match("%((.-)%)") or ""
                for _, r in ipairs(rarityFilter) do
                    if r == rarity then
                        return carName, slot
                    end
                end
            end
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
local ARRIVE_DIST  = 1.5
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

    -- Hold to bleed momentum — zeroes velocity every frame for 0.65 s
    if rootPart and rootPart.Parent and vel and vel.Parent then
        vel.Velocity = Vector3.zero
        pcall(function()
            rootPart.AssemblyLinearVelocity  = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end)
        local holdConn
        local holdTime = 0
        holdConn = runService.Heartbeat:Connect(function(dt)
            holdTime += dt
            pcall(function()
                vel.Velocity = Vector3.zero
                rootPart.AssemblyLinearVelocity  = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end)
            if holdTime >= 0.65 then holdConn:Disconnect() end
        end)
        task.wait(0.7)
    end

    -- ── FINAL ALIGNMENT SNAP ──────────────────────────────────────────────────
    -- Override the car's orientation so its LookVector matches Hit.CFrame.LookVector
    -- (= +X in Stage 1). This gives alignment_score = 1.0.
    pcall(function()
        local hit = workspace.Stages["1Stage"].STAGE.ParkSpot.Hit

        -- Build a CFrame at the park position with Hit's exact rotation
        local hitRotOnly = hit.CFrame - hit.CFrame.Position  -- strip translation
        local snappedCFrame = CFrame.new(parkPos) * hitRotOnly

        -- Hold orientation and zero velocity for 0.5 s, then hard-snap
        local snapConn
        local snapTime = 0
        snapConn = runService.Heartbeat:Connect(function(dt)
            snapTime += dt
            pcall(function()
                rootPart.AssemblyLinearVelocity  = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
                vel.Velocity = Vector3.zero
                gyro.CFrame  = snappedCFrame
            end)
            if snapTime >= 0.5 then
                snapConn:Disconnect()
                -- Final hard snap
                pcall(function()
                    rootPart.CFrame = snappedCFrame
                    rootPart.AssemblyLinearVelocity  = Vector3.zero
                    rootPart.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end)
        task.wait(0.55)
    end)

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

    -- ── Buy-limit tracking ──────────────────────────────────────────────────
    carBuyCount[carName] = (carBuyCount[carName] or 0) + 1
    local limit = carBuyLimit[carName]
    if limit and carBuyCount[carName] >= limit then
        -- Remove from queue — limit reached
        for j, n in ipairs(carQueue) do
            if n == carName then table.remove(carQueue, j); break end
        end
        carBuyLimit[carName] = nil
        carBuyCount[carName] = nil
        rebuildQueueUI()
        saveSettings()
        setStatus("Limit reached for " .. carName .. "! Removed.", Color3.fromRGB(80, 220, 100))
    else
        rebuildQueueUI()  -- refresh count display
        setStatus("Done! Scanning...", Color3.fromRGB(80, 220, 100))
    end

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

-- ── WEBHOOK FUNCTIONS ─────────────────────────────────────────────────────

-- Parse the rarity string out of a display string like "Car Name (Rarity) - $Price"
local function parseRarityFromDisplay(displayStr)
    return displayStr:match("%((.-)%)")
end

-- Send a Discord embed for a spotted car
local function sendWebhookNotification(carDisplayName, carKey)
    if not webhookEnabled then return end
    if WEBHOOK_URL == "YOUR_WEBHOOK_HERE" then return end

    local rarity   = parseRarityFromDisplay(carDisplayName) or "Unknown"
    local color    = rarityColors[rarity] or 0x888888
    local meshId   = carIconMap[carKey]
    local thumbUrl = meshId and (
        "https://www.roblox.com/asset-thumbnail/image?assetId="
        .. meshId .. "&width=420&height=420&format=png"
    ) or nil

    local embedFields = {
        title       = "🚗 Car Spotted!",
        description = carDisplayName,
        color       = color,
        footer      = { text = "Spotted by " .. player.Name },
    }
    if thumbUrl then
        embedFields.thumbnail = { url = thumbUrl }
    end

    local body = httpService:JSONEncode({ embeds = { embedFields } })
    pcall(function()
        request({
            Url     = WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })
    end)
end

-- Check whether a spawned car instance matches any active filter.
-- Returns the car's display name if it matches, nil otherwise.
local function getWebhookMatchDisplay(slot)
    -- Get display name from the in-world NameLabel
    local ok, label = pcall(function()
        return slot:FindFirstChild("nameEffect"):FindFirstChild("PartName"):FindFirstChild("NameLabel")
    end)
    if not (ok and label and label:IsA("TextLabel")) then return nil end
    local carName = label.Text  -- this is the short name, e.g. "Porcha Cayana"

    -- Get the display string from carData
    local displayStr = getDisplayForName(carName)
    local rarity     = parseRarityFromDisplay(displayStr) or ""

    -- Get type from nameEffect.Type StringValue
    local carType = ""
    pcall(function()
        local typeVal = slot:FindFirstChild("nameEffect") and
                        slot:FindFirstChild("nameEffect"):FindFirstChild("Type")
        if typeVal and typeVal:IsA("StringValue") then
            carType = typeVal.Value
        end
    end)

    -- Determine whether ANY active filter matches (empty table = matches all)
    local hasCarsFilter     = #webhookFilterCars > 0
    local hasRarityFilter   = #webhookFilterRarities > 0
    local hasTypeFilter     = #webhookFilterTypes > 0
    local anyFilterActive   = hasCarsFilter or hasRarityFilter or hasTypeFilter

    if not anyFilterActive then
        return displayStr  -- no filters: always match
    end

    -- Car-name filter
    if hasCarsFilter then
        for _, n in ipairs(webhookFilterCars) do
            if n == carName then return displayStr end
        end
    end
    -- Rarity filter
    if hasRarityFilter then
        for _, r in ipairs(webhookFilterRarities) do
            if r == rarity then return displayStr end
        end
    end
    -- Type filter
    if hasTypeFilter then
        for _, t in ipairs(webhookFilterTypes) do
            if t == carType then return displayStr end
        end
    end

    return nil
end

-- Scan all cars in SpawnedCars and fire webhook for any new matches.
local function scanSpawnedCarsForWebhook()
    if not webhookEnabled then return end
    local spawnedCars = workspace:FindFirstChild("SpawnedCars")
    if not spawnedCars then return end

    for _, slot in pairs(spawnedCars:GetChildren()) do
        if not webhookSeen[slot] then
            local displayStr = getWebhookMatchDisplay(slot)
            if displayStr then
                webhookSeen[slot] = true
                -- Resolve car key from display string via carNameToKey
                -- Extract the short name from display e.g. "Porcha Cayana (Legendary)…"
                local shortName = displayStr:match("^(.-)%s*%(")
                local carKey    = shortName and carNameToKey[shortName] or nil
                -- Also try the model's own Name property (Car1, Car2…) as fallback
                if not carKey then
                    pcall(function()
                        local modelName = slot.Name  -- "Car1", "Car2", etc.
                        if carIconMap[modelName] or modelName:match("^Car%d+$") then
                            carKey = modelName
                        end
                    end)
                end
                task.spawn(function()
                    sendWebhookNotification(displayStr, carKey or "")
                end)
            end
        end
    end

    -- Clean up seen table entries whose instances have been removed
    for inst in pairs(webhookSeen) do
        if not inst.Parent then
            webhookSeen[inst] = nil
        end
    end
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
    if isInQueue(pendingCar) then
        setStatus("Already in queue!", Color3.fromRGB(255, 160, 50))
        task.delay(2, function()
            setStatus(autoBuyEnabled and "Scanning..." or "Idle")
        end)
        return
    end
    -- Copy the current pendingCarTypes list into the entry
    local entryTypes = {}
    for _, t in ipairs(pendingCarTypes) do
        table.insert(entryTypes, t)
    end
    table.insert(carQueue, { name = pendingCar, types = entryTypes })
    rebuildQueueUI()
    saveSettings()
    local typeDisplay = #entryTypes == 0 and "Any" or table.concat(entryTypes, "/")
    setStatus("Added: " .. pendingCar .. " — " .. typeDisplay, Color3.fromRGB(80, 220, 100))
    task.delay(2, function()
        setStatus(autoBuyEnabled and "Scanning..." or "Idle")
    end)
end)

-- Rarity toggle buttons
for _, rarity in ipairs(RARITIES) do
    rarityToggleButtons[rarity].MouseButton1Click:Connect(function()
        -- Toggle in rarityFilter
        local found = false
        for i, r in ipairs(rarityFilter) do
            if r == rarity then
                table.remove(rarityFilter, i)
                found = true
                break
            end
        end
        if not found then
            table.insert(rarityFilter, rarity)
        end
        refreshRarityUI()
        saveSettings()
    end)
end

-- Type toggle buttons — multi-select; "Any" clears all specific selections
for _, typeName in ipairs(CAR_TYPES) do
    typeRadioButtons[typeName].MouseButton1Click:Connect(function()
        if typeName == "Any" then
            -- Any clears all specific types
            pendingCarTypes = {}
        else
            -- Toggle this type in/out of pendingCarTypes
            local found = false
            for i, t in ipairs(pendingCarTypes) do
                if t == typeName then
                    table.remove(pendingCarTypes, i)
                    found = true
                    break
                end
            end
            if not found then
                table.insert(pendingCarTypes, typeName)
            end
            -- If nothing is selected after toggle, implicitly revert to Any
            -- (leave pendingCarTypes empty = Any; UI will reflect this)
        end
        refreshTypeRadioUI()
    end)
end

-- Auto Buy toggle
autoBuyButton.MouseButton1Click:Connect(function()
    if #carQueue == 0 and #rarityFilter == 0 then
        setStatus("Add cars or set a rarity filter first!", Color3.fromRGB(255, 100, 100))
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

-- Webhook Notify toggle
webhookButton.MouseButton1Click:Connect(function()
    webhookEnabled = not webhookEnabled
    if webhookEnabled then
        webhookButton.Text = "Webhook Notify: ON"
        webhookButton.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
    else
        webhookButton.Text = "Webhook Notify: OFF"
        webhookButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        -- Clear seen table so re-enabling will re-detect current cars
        webhookSeen = {}
    end
end)

-- ── LIVE AD INTERCEPTION ───────────────────────────────────────────────────

-- Catch FavoriteItem / PromptSetFavorite the instant it appears in CoreGui.
-- Strategy: whenever ANYTHING is added to CoreGui, wait 0.15 s for the full
-- dialog tree to build, then do a broad scan of ALL CoreGui descendants for a
-- TextButton whose text is "No" that also has a "Yes" sibling — confirming it
-- is a two-button confirmation prompt, not some unrelated game UI.
local _favoriteDebounce = false
game.CoreGui.DescendantAdded:Connect(function()
    if not autoAdsEnabled then return end
    if _favoriteDebounce then return end
    task.spawn(function()
        task.wait(0.15)
        if not autoAdsEnabled then return end
        pcall(function()
            for _, btn in ipairs(game.CoreGui:GetDescendants()) do
                if btn:IsA("TextButton") and btn.Text == "No" then
                    local parent = btn.Parent
                    if parent then
                        for _, sibling in ipairs(parent:GetChildren()) do
                            if sibling:IsA("TextButton") and sibling.Text == "Yes" then
                                _favoriteDebounce = true
                                btn.MouseButton1Click:Fire()
                                task.delay(1, function() _favoriteDebounce = false end)
                                return
                            end
                        end
                    end
                end
            end
        end)
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
        -- Always inject rarity filter matches into the queue when active
        if #rarityFilter > 0 then
            injectFilterMatches()
        end
        -- Auto Buy — trigger if queue has entries (filters may have just filled it)
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
        -- Webhook car scanner
        scanSpawnedCarsForWebhook()
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

    if saved.rarityFilter and type(saved.rarityFilter) == "table" then
        rarityFilter = saved.rarityFilter
        refreshRarityUI()
    end

    if saved.carBuyLimit and type(saved.carBuyLimit) == "table" then
        carBuyLimit = saved.carBuyLimit
        rebuildQueueUI()  -- re-render rows with restored limits
    end

    if saved.autoBuyEnabled and (#carQueue > 0 or #rarityFilter > 0) then
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
