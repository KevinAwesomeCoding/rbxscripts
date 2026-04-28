local GAMES = {
    [113720203996283] = {
        "https://raw.githubusercontent.com/.../Park%20a%20Car%20Script.lua",
    },
    [89469502395769] = {
        "https://raw.githubusercontent.com/KevinAwesomeCoding/rbxscripts/refs/heads/main/Kick%20a%20Lucky%20Block%20Equip%20Best%20Pet.lua",
        "https://pastefy.app/AtOZNoxR/raw",
    },
}

-- ── Loader ──
local placeId = game.PlaceId
local scripts = GAMES[placeId]

if scripts then
    for i, url in ipairs(scripts) do
        print(string.format("[Loader] Running script %d/%d for PlaceId %d...", i, #scripts, placeId))
        local ok, err = pcall(function()
            loadstring(game:HttpGet(url))()
        end)
        if not ok then
            print("[Loader] ERROR on script", i, ":", err)
        end
    end
else
    print("[Loader] No script registered for PlaceId:", placeId)
end
