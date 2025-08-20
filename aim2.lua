--[[
    MINIMAL UI DEBUG SCRIPT (v11-TEST)
    Tujuan: Hanya untuk merender UI dan melihat di mana error terjadi via konsol.
    SCRIPT INI TIDAK PUNYA FUNGSI AIM ATAU ESP SAMA SEKALI.
]]

--// Services
if not game:IsLoaded() then game.Loaded:Wait() end
local coreGui = game:GetService("CoreGui")

print("MEMULAI UI DEBUG SCRIPT v11...")

local function CreateUI()
    print("Mencoba memuat DiscordLib...")
    local success, DiscordLib = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/UI-Libs/main/discord%20lib.txt"))()
    end)

    if not success or not DiscordLib then
        warn("GAGAL MEMUAT DISCORDLIB UI. Error: " .. tostring(DiscordLib))
        return
    end
    print("DiscordLib berhasil dimuat.")
    
    local win = DiscordLib:Window("UI DEBUG v11")
    local AimServer = win:Server("Aim", "http://www.roblox.com/asset/?id=6031393359")
    
    -- Channel Silent Aim (Grup Tes)
    local SilentChannel = AimServer:Channel("Silent Aim")
    
    print("1. Membuat Toggle 'Aktifkan'...")
    pcall(function()
        SilentChannel:Toggle("Aktifkan", true, function(bool) end)
    end)
    print("...Toggle 'Aktifkan' selesai.")

    print("2. Membuat Dropdown 'Tombol Toggle'...")
    pcall(function()
        local keyOptions = {"Right Alt", "Left Alt", "Caps Lock", "Mouse Button 4", "Mouse Button 5"}
        SilentChannel:Dropdown("Tombol Toggle", keyOptions, function(selection) end)
    end)
    print("...Dropdown 'Tombol Toggle' selesai.")

    print("3. Membuat Slider 'FOV'...")
    pcall(function()
        SilentChannel:Slider("FOV", 10, 500, 130, function(val) end)
    end)
    print("...Slider 'FOV' selesai.")

    print("4. Membuat Slider 'Hit Chance'...")
    pcall(function()
        SilentChannel:Slider("Hit Chance", 0, 100, 100, function(val) end)
    end)
    print("...Slider 'Hit Chance' selesai.")

    print("5. Membuat Dropdown 'Target Part'...")
    pcall(function()
        SilentChannel:Dropdown("Target Part", {"HumanoidRootPart", "Head", "Random"}, function(selection) end)
    end)
    print("...Dropdown 'Target Part' selesai.")

    print("6. Membuat Dropdown 'Metode'...")
    pcall(function()
        SilentChannel:Dropdown("Metode", {"Raycast", "Mouse.Hit/Target", "FindPartOnRay"}, function(selection) end)
    end)
    print("...Dropdown 'Metode' selesai.")
    
    print("DEBUG FINAL: SEMUA PROSES PEMBUATAN UI SELESAI TANPA ERROR.")
end

pcall(CreateUI)
