--[[
    UNIVERSAL SCRIPT - v15.3 (FIXED v6 by Gemini)
    - DROPDOWN FIX: Memperbaiki error pada elemen Dropdown dengan menambahkan logika untuk menentukan dan mengatur nilai default. Ini menyelesaikan masalah hilangnya fitur UI.
    - UI UPDATE: Mengubah input "Tombol Toggle" Silent Aim dari Bind menjadi Dropdown.
    - OPTIMIZATION: Mengimplementasikan sistem caching untuk Silent Aim untuk menghilangkan lag.
]]

--// ================== PERSIAPAN & INISIALISASI ==================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

--// Services
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")
local coreGui = game:GetService("CoreGui")
local camera = workspace.CurrentCamera
local localPlayer = players.LocalPlayer
local mouse = localPlayer:GetMouse()

--// Peringatan jika fungsi penting tidak ada
if not hookmetamethod or not getnamecallmethod or not newcclosure or not checkcaller then
    warn("PERINGATAN: Executor Anda tidak mendukung fungsi hook yang diperlukan untuk Silent Aim.")
end
if not isfolder or not makefolder or not writefile or not readfile or not listfiles then
    warn("PERINGATAN: Executor Anda tidak mendukung fungsi file. Fitur Config tidak akan berfungsi.")
end

--// ================== PENGATURAN & VARIABEL GLOBAL ==================
getgenv().SETTINGS = {
    -- CFrame Aim
    CFrameAimEnabled = false,
    CFrameAimFov = 100,
    CFrameAimSmoothness = 0.2,
    CFrameAimHitbox = "Head",
    CFrameAimKey = "Right Click",

    -- Silent Aim
    SilentAimEnabled = true,
    SilentAimToggleKey = Enum.KeyCode.RightAlt,
    SilentAimFov = 130,
    SilentAimHitChance = 100,
    SilentAimHitbox = "HumanoidRootPart",
    SilentAimVisibleCheck = false,
    SilentAimMethod = "Raycast",
    SilentAimPrediction = false,
    SilentAimPredictionAmount = 0.165,

    -- ESP
    ESPEnabled = true,
    ESPBox = true,
    ESPNames = true,
    ESPSnaplines = true,
    ESPHealth = true,
    ESPColor = Color3.fromRGB(255, 0, 0),
    espThickness = 2,
    espTransparency = 0.5,
    
    -- Visuals
    DrawFov = false,
    FovColor = Color3.fromRGB(255, 255, 255),
    ShowTarget = false,
    TargetColor = Color3.fromRGB(54, 57, 241),
    
    -- Misc
    TeamCheck = false
}
local SETTINGS = getgenv().SETTINGS

--// Variabel Kontrol
local isCFrameAiming = false
local ValidTargetParts = {"Head", "HumanoidRootPart"}
local MainFileName = "UniversalAimScript"
local espConnections = {}
local cachedSilentAimTarget = nil
local updateCounter = 0

--// Objek Visual
local fov_circle;
pcall(function()
    fov_circle = Drawing.new("Circle")
    fov_circle.Thickness = 1
    fov_circle.NumSides = 100
    fov_circle.Filled = false
    fov_circle.Visible = false
end)

local target_box;
pcall(function()
    target_box = Drawing.new("Square")
    target_box.Visible = false
    target_box.Thickness = 2
    target_box.Size = Vector2.new(8, 8)
    target_box.Filled = false
end)


--// ================== FUNGSI HELPER & LOGIKA UTAMA ==================

local function isValidTarget(player)
    if not player or player == localPlayer then return false end
    if SETTINGS.TeamCheck and player.Team and localPlayer.Team and player.Team == localPlayer.Team then return false end
    
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    
    return humanoid and root and humanoid.Health > 0
end

local function getTargetForCFrameAim()
    local nearest = nil
    local shortestDistance = SETTINGS.CFrameAimFov
    local mousePosition = userInputService:GetMouseLocation()

    for _, player in ipairs(players:GetPlayers()) do
        if isValidTarget(player) then
            local character = player.Character
            local targetPart = character:FindFirstChild(SETTINGS.CFrameAimHitbox) or character:FindFirstChild("HumanoidRootPart")
            if targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (mousePosition - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        nearest = { targetPosition = targetPart.Position }
                    end
                end
            end
        end
    end
    return nearest
end

local function updateCFrameAim()
    if not SETTINGS.CFrameAimEnabled or not isCFrameAiming then return end
    
    local target = getTargetForCFrameAim()
    if not target then return end

    local smoothnessFactor = math.clamp(SETTINGS.CFrameAimSmoothness, 0.01, 1)
    camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, target.targetPosition), smoothnessFactor)
end

local function getClosestPlayerForSilentAim()
    local Closest = nil
    local shortestDistance = SETTINGS.SilentAimFov

    for _, Player in ipairs(players:GetPlayers()) do
        if isValidTarget(Player) then
            if SETTINGS.SilentAimVisibleCheck and not IsPlayerVisible(Player) then continue end

            local Character = Player.Character
            local targetPartToTest = Character:FindFirstChild(SETTINGS.SilentAimHitbox) or Character:FindFirstChild("HumanoidRootPart")
            
            if targetPartToTest then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPartToTest.Position)
                if onScreen then
                    local distance = (userInputService:GetMouseLocation() - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if distance < shortestDistance then
                        if SETTINGS.SilentAimHitbox == "Random" then
                            Closest = Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]
                        else
                            Closest = targetPartToTest
                        end
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    return Closest
end

local ExpectedArguments = {
    FindPartOnRay = { ArgCountRequired = 2, Args = {"Instance", "Ray", "Instance", "boolean", "boolean"} },
    Raycast = { ArgCountRequired = 3, Args = {"Instance", "Vector3", "Vector3", "RaycastParams"} }
}
local function CalculateChance(Percentage)
    return (math.random() * 100) <= Percentage
end
local function ValidateArguments(Args, RayMethod)
    if #Args < RayMethod.ArgCountRequired then return false end
    local Matches = 0
    for Pos, Argument in ipairs(Args) do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end
local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end
local function IsPlayerVisible(Player)
    local PC = Player.Character
    local LPC = localPlayer.Character
    if not (PC and LPC) then return false end
    
    local PR = PC:FindFirstChild(SETTINGS.SilentAimHitbox) or PC:FindFirstChild("HumanoidRootPart")
    if not PR then return false end
    
    return #camera:GetPartsObscuringTarget({PR.Position},{LPC,PC})==0
end

local function manageEspForPlayer(player)
    print("DEBUG: Memulai manajemen ESP untuk " .. player.Name)
    
    local allDrawings = {}
    local connection = nil

    local function destroyEsp()
        if connection and connection.Connected then
            print("DEBUG: Koneksi ESP untuk " .. player.Name .. " diputus.")
            connection:Disconnect()
        end
        connection = nil
        
        for i, obj in ipairs(allDrawings) do
            obj:Remove()
        end
        allDrawings = {}
    end

    local function createCharacterEsp(character)
        destroyEsp()

        if not Drawing or not Drawing.new then return end

        print("DEBUG: Membuat objek ESP baru untuk karakter " .. player.Name)
        local box = Drawing.new("Square"); table.insert(allDrawings, box)
        local tracer = Drawing.new("Line"); table.insert(allDrawings, tracer)
        local name = Drawing.new("Text"); table.insert(allDrawings, name)
        local healthBar = Drawing.new("Square"); table.insert(allDrawings, healthBar)

        for _, obj in ipairs(allDrawings) do
            obj.Visible = false
        end
        name.Size, name.Center, name.Outline = 16, true, true
        healthBar.Filled = true
        box.Filled = true
        
        connection = runService.RenderStepped:Connect(function()
            if not character or not character.Parent or not isValidTarget(player) or not SETTINGS.ESPEnabled then
                for _, obj in ipairs(allDrawings) do
                    obj.Visible = false
                end
                return
            end
            
            box.Color, tracer.Color, name.Color = SETTINGS.ESPColor, SETTINGS.ESPColor, SETTINGS.ESPColor
            box.Thickness, tracer.Thickness = SETTINGS.espThickness, SETTINGS.espThickness
            box.Transparency, tracer.Transparency = SETTINGS.espTransparency, SETTINGS.espTransparency

            local root = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if not root or not humanoid then return end

            local vector, onScreen = camera:WorldToViewportPoint(root.Position)
            if not onScreen then
                for _, obj in ipairs(allDrawings) do obj.Visible = false end
                return
            end

            local boxSizeY, boxSizeX = 3000 / vector.Z, 2000 / vector.Z
            
            box.Visible = SETTINGS.ESPBox
            if box.Visible then
                box.Size, box.Position = Vector2.new(boxSizeX, boxSizeY), Vector2.new(vector.X - boxSizeX / 2, vector.Y - boxSizeY / 2)
            end
            
            tracer.Visible = SETTINGS.ESPSnaplines
            if tracer.Visible then
                tracer.From, tracer.To = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y), Vector2.new(vector.X, vector.Y)
            end
            
            name.Visible = SETTINGS.ESPNames
            if name.Visible then
                name.Position, name.Text = Vector2.new(vector.X, vector.Y - boxSizeY/2 - 5), player.Name
            end
            
            healthBar.Visible = SETTINGS.ESPHealth
            if healthBar.Visible then
                local hp = humanoid.Health / humanoid.MaxHealth
                healthBar.Position = Vector2.new(vector.X - boxSizeX/2 - 7, vector.Y - boxSizeY/2)
                healthBar.Size = Vector2.new(5, boxSizeY * hp)
                healthBar.Color = Color3.fromHSV(hp / 3, 1, 1)
            end
        end)
    end

    player.CharacterAdded:Connect(createCharacterEsp)
    player.CharacterRemoving:Connect(destroyEsp)

    if player.Character then
        createCharacterEsp(player.Character)
    end
end

--// ================== UI BARU MENGGUNAKAN DISCORDLIB ==================
local function CreateUI()
    local success, DiscordLib = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/UI-Libs/main/discord%20lib.txt"))()
    end)

    if not success or not DiscordLib then
        warn("Gagal memuat DiscordLib UI. Error: " .. tostring(DiscordLib))
        return
    end
    
    local win = DiscordLib:Window("Universal Script v15.3")
    local CFrameAim_Toggle, SilentAim_Toggle

    -- SERVER: AIM
    local AimServer = win:Server("Aim", "http://www.roblox.com/asset/?id=6031393359")
    
    local CFrameChannel = AimServer:Channel("CFrame Aim")
    CFrameAim_Toggle = CFrameChannel:Toggle("Aktifkan", SETTINGS.CFrameAimEnabled, function(bool)
        SETTINGS.CFrameAimEnabled = bool
        if bool and SilentAim_Toggle then
            SETTINGS.SilentAimEnabled = false
            SilentAim_Toggle:Set(false)
        end
    end)
    CFrameChannel:Slider("FOV", 10, 500, SETTINGS.CFrameAimFov, function(val)
        SETTINGS.CFrameAimFov = val
    end)
    CFrameChannel:Slider("Smoothness", 0.01, 1, SETTINGS.CFrameAimSmoothness, function(val)
        SETTINGS.CFrameAimSmoothness = val
    end)
    CFrameChannel:Dropdown("Target Part", {"Head", "Torso"}, function(selection)
        SETTINGS.CFrameAimHitbox = selection
    end)
    CFrameChannel:Dropdown("Tombol Hold", {"Right Click", "Left Click", "X"}, function(selection)
        SETTINGS.CFrameAimKey = selection
    end)

    local SilentChannel = AimServer:Channel("Silent Aim")
    SilentAim_Toggle = SilentChannel:Toggle("Aktifkan", SETTINGS.SilentAimEnabled, function(bool)
        SETTINGS.SilentAimEnabled = bool
        if not bool then
            cachedSilentAimTarget = nil
        end
    end)

    --// << ====================== BLOK UI YANG DIPERBAIKI ======================
    local keyOptions = {"Right Alt", "Left Alt", "Caps Lock", "Mouse Button 4", "Mouse Button 5"}
    local keyEnumMap = {
        ["Right Alt"] = Enum.KeyCode.RightAlt,
        ["Left Alt"] = Enum.KeyCode.LeftAlt,
        ["Caps Lock"] = Enum.KeyCode.CapsLock,
        ["Mouse Button 4"] = Enum.KeyCode.MouseButton4,
        ["Mouse Button 5"] = Enum.KeyCode.MouseButton5
    }

    -- Logika baru untuk mencari nama default dari setting yang ada
    local defaultKeyName = "Right Alt" -- Fallback default
    for keyName, keyCode in pairs(keyEnumMap) do
        if keyCode == SETTINGS.SilentAimToggleKey then
            defaultKeyName = keyName
            break
        end
    end

    SilentChannel:Dropdown("Tombol Toggle", keyOptions, function(selection)
        if keyEnumMap[selection] then
            SETTINGS.SilentAimToggleKey = keyEnumMap[selection]
        end
    end):Set(defaultKeyName) -- Menambahkan .Set() untuk mengatur nilai default
    --// << ==================== AKHIR BLOK YANG DIPERBAIKI =====================

    SilentChannel:Slider("FOV", 10, 500, SETTINGS.SilentAimFov, function(val)
        SETTINGS.SilentAimFov = val
    end)
    SilentChannel:Slider("Hit Chance", 0, 100, SETTINGS.SilentAimHitChance, function(val)
        SETTINGS.SilentAimHitChance = val
    end)
    SilentChannel:Dropdown("Target Part", {"HumanoidRootpart", "Head", "Random"}, function(selection)
        SETTINGS.SilentAimHitbox = selection
    end)
    SilentChannel:Dropdown("Metode", {"Raycast", "Mouse.Hit/Target", "FindPartOnRay"}, function(selection)
        SETTINGS.SilentAimMethod = selection
    end)
    
    -- SERVER: VISUALS
    local VisualsServer = win:Server("Visuals", "http://www.roblox.com/asset/?id=3130635425")
    
    local ESPChannel = VisualsServer:Channel("Player ESP")
    ESPChannel:Toggle("Aktifkan ESP", SETTINGS.ESPEnabled, function(b) SETTINGS.ESPEnabled = b; print("DEBUG: ESP diubah ke:", b) end)
    ESPChannel:Toggle("Box", SETTINGS.ESPBox, function(b) SETTINGS.ESPBox = b; print("DEBUG: ESP Box diubah ke:", b) end)
    ESPChannel:Toggle("Nama", SETTINGS.ESPNames, function(b) SETTINGS.ESPNames = b end)
    ESPChannel:Toggle("Garis", SETTINGS.ESPSnaplines, function(b) SETTINGS.ESPSnaplines = b end)
    ESPChannel:Toggle("Darah", SETTINGS.ESPHealth, function(b) SETTINGS.ESPHealth = b end)
    ESPChannel:Colorpicker("Warna ESP", SETTINGS.ESPColor, function(c) SETTINGS.ESPColor = c end)

    local FovChannel = VisualsServer:Channel("FOV & Target")
    FovChannel:Toggle("Tampilkan FOV", SETTINGS.DrawFov, function(b) SETTINGS.DrawFov = b end)
    FovChannel:Colorpicker("Warna FOV", SETTINGS.FovColor, function(c) SETTINGS.FovColor = c end)
    FovChannel:Toggle("Tampilkan Target", SETTINGS.ShowTarget, function(b) SETTINGS.ShowTarget = b end)
    FovChannel:Colorpicker("Warna Target", SETTINGS.TargetColor, function(c) SETTINGS.TargetColor = c end)
    
    -- SERVER: MISC
    local MiscServer = win:Server("Misc", "http://www.roblox.com/asset/?id=394239836")
    
    local ChecksChannel = MiscServer:Channel("Checks")
    ChecksChannel:Toggle("Team Check", SETTINGS.TeamCheck, function(b) SETTINGS.TeamCheck = b end)
    ChecksChannel:Toggle("Visible Check (Silent)", SETTINGS.SilentAimVisibleCheck, function(b) SETTINGS.SilentAimVisibleCheck = b end)

    local PredictionChannel = MiscServer:Channel("Prediction (Silent)")
    PredictionChannel:Toggle("Aktifkan", SETTINGS.SilentAimPrediction, function(b) SETTINGS.SilentAimPrediction = b end)
    PredictionChannel:Slider("Amount", 0, 1, SETTINGS.SilentAimPredictionAmount, function(v) SETTINGS.SilentAimPredictionAmount = v end)
end

--// ================== PUSAT KONTROL & INISIALISASI ==================
pcall(CreateUI)

local function setupEsp()
    print("DEBUG: Memulai setup ESP untuk semua pemain...")
    local function connectPlayer(player)
        if player ~= localPlayer then
            pcall(manageEspForPlayer, player)
        end
    end
    for _, player in ipairs(players:GetPlayers()) do
        connectPlayer(player)
    end
    players.PlayerAdded:Connect(connectPlayer)
    print("DEBUG: Setup ESP selesai.")
end
setupEsp()

local function parseKeySelection(selection)
    if selection == "Right Click" then return "Mouse", Enum.UserInputType.MouseButton2
    elseif selection == "Left Click" then return "Mouse", Enum.UserInputType.MouseButton1
    elseif selection == "X" then return "Key", Enum.KeyCode.X
    end
    return nil, nil
end

userInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    local cframeType, cframeKey = parseKeySelection(SETTINGS.CFrameAimKey)
    if cframeType == "Key" and input.KeyCode == cframeKey then
        isCFrameAiming = true
    elseif cframeType == "Mouse" and input.UserInputType == cframeKey then
        isCFrameAiming = true
    end

    if input.KeyCode == SETTINGS.SilentAimToggleKey then
        SETTINGS.SilentAimEnabled = not SETTINGS.SilentAimEnabled
        if not SETTINGS.SilentAimEnabled then
            cachedSilentAimTarget = nil
        end
    end
end)

userInputService.InputEnded:Connect(function(input, processed)
    if processed then return end

    local cframeType, cframeKey = parseKeySelection(SETTINGS.CFrameAimKey)
    if cframeType == "Key" and input.KeyCode == cframeKey then
        isCFrameAiming = false
    elseif cframeType == "Mouse" and input.UserInputType == cframeKey then
        isCFrameAiming = false
    end
end)

runService.RenderStepped:Connect(function()
    updateCFrameAim()
    
    updateCounter = updateCounter + 1
    if updateCounter >= 5 then
        updateCounter = 0
        if SETTINGS.SilentAimEnabled then
            cachedSilentAimTarget = getClosestPlayerForSilentAim()
        end
    end
    
    if fov_circle then
        fov_circle.Visible = SETTINGS.DrawFov
        fov_circle.Color = SETTINGS.FovColor
        fov_circle.Radius = SETTINGS.SilentAimEnabled and SETTINGS.SilentAimFov or SETTINGS.CFrameAimFov
        fov_circle.Position = userInputService:GetMouseLocation()
    end

    if target_box then
        target_box.Visible = SETTINGS.ShowTarget and SETTINGS.SilentAimEnabled and cachedSilentAimTarget and true or false
        if target_box.Visible then
            local screenPos, onScreen = camera:WorldToViewportPoint(cachedSilentAimTarget.Position)
            if onScreen then
                target_box.Position = Vector2.new(screenPos.X - 4, screenPos.Y - 4)
                target_box.Color = SETTINGS.TargetColor
            else
                target_box.Visible = false
            end
        end
    end
end)

if hookmetamethod and getnamecallmethod then
    local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(...)
        local method = getnamecallmethod()
        local args = {...}
        local self = args[1]
        
        if SETTINGS.SilentAimEnabled and self == workspace and not checkcaller() and CalculateChance(SETTINGS.SilentAimHitChance) then
            local hitPart = cachedSilentAimTarget
            if hitPart then
                if SETTINGS.SilentAimMethod == "Raycast" and method == "Raycast" then
                    if ValidateArguments(args, ExpectedArguments.Raycast) then
                        args[3] = getDirection(args[2], hitPart.Position)
                        return oldNamecall(unpack(args))
                    end
                elseif (SETTINGS.SilentAimMethod:find("FindPartOnRay")) and (method:find("FindPartOnRay")) then
                    local ray = args[2]
                    if ray then
                        args[2] = Ray.new(ray.Origin, getDirection(ray.Origin, hitPart.Position + (hitPart.Velocity * SETTINGS.SilentAimPredictionAmount)))
                        return oldNamecall(unpack(args))
                    end
                end
            end
        end
        return oldNamecall(...)
    end)
    
    local oldIndex; oldIndex = hookmetamethod(game, "__index", function(self, index)
        if SETTINGS.SilentAimEnabled and self == mouse and not checkcaller() and SETTINGS.SilentAimMethod == "Mouse.Hit/Target" then
            local hitPart = cachedSilentAimTarget
            if hitPart then
                if index:lower() == "target" then return hitPart end
                if index:lower() == "hit" then
                    if SETTINGS.SilentAimPrediction then
                        return hitPart.CFrame + (hitPart.Velocity * SETTINGS.SilentAimPredictionAmount)
                    else
                        return hitPart.CFrame
                    end
                end
            end
        end
        return oldIndex(self, index)
    end)
end

print("✅ DROPDOWN UI FIXED (v6) - Script Berhasil Dimuat!")
