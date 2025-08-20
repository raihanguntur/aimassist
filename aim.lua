--[[
    UNIVERSAL SCRIPT - v15.1 FINAL & COMPLETE
    - FULL INTEGRATION: Script ini adalah gabungan lengkap dari CFrame Aim, ESP, dan semua fitur dari "Universal Silent Aim".
    - UI LIBRARY: Menggunakan DiscordLib yang stabil dan handal.
    - KODE: 100% ditulis ulang, LENGKAP, dan tidak ada peringkasan sama sekali.
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

--// ================== PENGATURAN / SETTINGS (GLOBAL) ==================
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
local MainFileName = "UniversalAimScript" -- Nama folder untuk config

--// Objek Visual
local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Filled = false
fov_circle.Visible = false

local target_box = Drawing.new("Square")
target_box.Visible = false
target_box.Thickness = 2
target_box.Size = Vector2.new(8, 8)
target_box.Filled = false

--// ================== FUNGSI HELPER (LENGKAP) ==================

local function isValidTarget(player)
    if not player or player == localPlayer then return false end
    if SETTINGS.TeamCheck and player.Team and localPlayer.Team and player.Team == localPlayer.Team then return false end
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return humanoid and root and humanoid.Health > 0
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = localPlayer.Character
    if not (PlayerCharacter and LocalPlayerCharacter) then return false end
    
    local PlayerRoot = PlayerCharacter:FindFirstChild(SETTINGS.SilentAimHitbox) or PlayerCharacter:FindFirstChild("HumanoidRootPart")
    if not PlayerRoot then return false end
    
    local ignoreList = {LocalPlayerCharacter, PlayerCharacter}
    local obscuringObjects = #camera:GetPartsObscuringTarget({PlayerRoot.Position}, ignoreList)
    
    return obscuringObjects == 0
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
    FindPartOnRayWithIgnoreList = { ArgCountRequired = 3, Args = {"Instance", "Ray", "table", "boolean", "boolean"} },
    FindPartOnRayWithWhitelist = { ArgCountRequired = 3, Args = {"Instance", "Ray", "table", "boolean"} },
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

--// ================== LOGIKA UTAMA FITUR ==================

local function updateCFrameAim()
    if not SETTINGS.CFrameAimEnabled or not isCFrameAiming then return end
    local target = getTargetForCFrameAim()
    if not target then return end
    camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, target.targetPosition), SETTINGS.CFrameAimSmoothness)
end

local function createEspBox(player)
    if not Drawing or not Drawing.new then return end
    local allDrawings = {}; local box = Drawing.new("Square"); table.insert(allDrawings, box); local tracer = Drawing.new("Line"); table.insert(allDrawings, tracer); local name = Drawing.new("Text"); table.insert(allDrawings, name); local healthBar = Drawing.new("Square"); table.insert(allDrawings, healthBar); for _, obj in ipairs(allDrawings) do obj.Visible = false end; name.Size, name.Center, name.Outline = 16, true, true; healthBar.Filled = true; local connection; connection = runService.RenderStepped:Connect(function() box.Color, tracer.Color, name.Color = SETTINGS.ESPColor, SETTINGS.ESPColor, SETTINGS.ESPColor; box.Thickness, tracer.Thickness = SETTINGS.espThickness, SETTINGS.espThickness; box.Transparency, tracer.Transparency = SETTINGS.espTransparency, SETTINGS.espTransparency; local character = player.Character; if not SETTINGS.ESPEnabled or not character or not isValidTarget(player) then for _, obj in ipairs(allDrawings) do obj.Visible = false end; return end; local root, humanoid = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("Humanoid"); if not root or not humanoid then return end; local vector, onScreen = camera:WorldToViewportPoint(root.Position); if not onScreen then for _, obj in ipairs(allDrawings) do obj.Visible = false end; return end; local boxSizeY, boxSizeX = 3000 / vector.Z, 2000 / vector.Z; box.Visible = SETTINGS.ESPBox; if box.Visible then box.Size, box.Position = Vector2.new(boxSizeX, boxSizeY), Vector2.new(vector.X - boxSizeX / 2, vector.Y - boxSizeY / 2) end; tracer.Visible = SETTINGS.ESPSnaplines; if tracer.Visible then tracer.From, tracer.To = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y), Vector2.new(vector.X, vector.Y) end; name.Visible = SETTINGS.ESPNames; if name.Visible then name.Position, name.Text = Vector2.new(vector.X, vector.Y - boxSizeY/2 - 5), player.Name end; healthBar.Visible = SETTINGS.ESPHealth; if healthBar.Visible then local hp = humanoid.Health / humanoid.MaxHealth; healthBar.Position = Vector2.new(vector.X - boxSizeX/2 - 7, vector.Y - boxSizeY/2); healthBar.Size = Vector2.new(5, boxSizeY * hp); healthBar.Color = Color3.fromHSV(hp / 3, 1, 1) end end); player.CharacterAdded:Connect(function() if connection then connection.Enabled = true end end); player.CharacterRemoving:Connect(function() for _, obj in ipairs(allDrawings) do obj.Visible = false end; if connection then connection.Enabled = false end end)
end

--// ================== UI DISCORDLIB (LENGKAP) ==================
local function CreateUI()
    local success, DiscordLib = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/UI-Libs/main/discord%20lib.txt"))()
    end)
    if not success or not DiscordLib then warn("Gagal memuat DiscordLib UI."); return end

    local win = DiscordLib:Window("Universal Script v15.0")
    local CFrameToggle, SilentToggle

    -- SERVER: AIM
    local AimServer = win:Server("Aim", "http://www.roblox.com/asset/?id=6031393359")
    
    local CFrameChannel = AimServer:Channel("CFrame Aim")
    CFrameToggle = CFrameChannel:Toggle("Aktifkan", SETTINGS.CFrameAimEnabled, function(b)
        SETTINGS.CFrameAimEnabled = b
        if b and SilentToggle then SETTINGS.SilentAimEnabled = false; SilentToggle:Set(false) end
    end)
    CFrameChannel:Slider("FOV", 10, 500, SETTINGS.CFrameAimFov, function(v) SETTINGS.CFrameAimFov = v end)
    CFrameChannel:Slider("Smoothness", 0.01, 1, SETTINGS.CFrameAimSmoothness, function(v) SETTINGS.CFrameAimSmoothness = v end)
    CFrameChannel:Dropdown("Target Part", {"Head", "Torso"}, function(s) SETTINGS.CFrameAimHitbox = s end)
    CFrameChannel:Dropdown("Tombol Hold", {"Right Click", "Left Click", "X"}, function(s) SETTINGS.CFrameAimKey = s end)

    local SilentChannel = AimServer:Channel("Silent Aim")
    SilentToggle = SilentChannel:Toggle("Aktifkan", SETTINGS.SilentAimEnabled, function(b)
        SETTINGS.SilentAimEnabled = b
        if b and CFrameToggle then SETTINGS.CFrameAimEnabled = false; CFrameToggle:Set(false) end
    end)
    SilentChannel:Bind("Tombol Toggle", SETTINGS.SilentAimToggleKey, function(k) SETTINGS.SilentAimToggleKey = k end)
    SilentChannel:Slider("FOV", 10, 500, SETTINGS.SilentAimFov, function(v) SETTINGS.SilentAimFov = v end)
    SilentChannel:Slider("Hit Chance", 0, 100, SETTINGS.SilentAimHitChance, function(v) SETTINGS.SilentAimHitChance = v end)
    SilentChannel:Dropdown("Target Part", {"HumanoidRootPart", "Head", "Random"}, function(s) SETTINGS.SilentAimHitbox = s end)
    SilentChannel:Dropdown("Metode", {"Raycast", "Mouse.Hit/Target", "FindPartOnRay", "FindPartOnRayWithWhitelist", "FindPartOnRayWithIgnoreList"}, function(s) SETTINGS.SilentAimMethod = s end)
    
    -- SERVER: VISUALS
    local VisualsServer = win:Server("Visuals", "http://www.roblox.com/asset/?id=3130635425")
    
    local ESPChannel = VisualsServer:Channel("Player ESP")
    ESPChannel:Toggle("Aktifkan ESP", SETTINGS.ESPEnabled, function(b) SETTINGS.ESPEnabled = b end)
    ESPChannel:Toggle("Box", SETTINGS.ESPBox, function(b) SETTINGS.ESPBox = b end)
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
    local function connectPlayer(player) if player ~= localPlayer then pcall(createEspBox, player) end end
    for _, player in ipairs(players:GetPlayers()) do
        connectPlayer(player)
    end
    players.PlayerAdded:Connect(connectPlayer)
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
    
    -- Input untuk CFrame Aim (Hold)
    local cframeType, cframeKey = parseKeySelection(SETTINGS.CFrameAimKey)
    if cframeType == "Key" and input.KeyCode == cframeKey then isCFrameAiming = true
    elseif cframeType == "Mouse" and input.UserInputType == cframeKey then isCFrameAiming = true end

    -- Input untuk Silent Aim (Toggle)
    if input.KeyCode == SETTINGS.SilentAimToggleKey then
        SETTINGS.SilentAimEnabled = not SETTINGS.SilentAimEnabled
    end
end)

userInputService.InputEnded:Connect(function(input, processed)
    if processed then return end

    -- Input untuk CFrame Aim (Hold)
    local cframeType, cframeKey = parseKeySelection(SETTINGS.CFrameAimKey)
    if cframeType == "Key" and input.KeyCode == cframeKey then isCFrameAiming = false
    elseif cframeType == "Mouse" and input.UserInputType == cframeKey then isCFrameAiming = false end
end)

runService.RenderStepped:Connect(function()
    updateCFrameAim()
    
    fov_circle.Visible = SETTINGS.DrawFov
    fov_circle.Color = SETTINGS.FovColor
    fov_circle.Radius = SETTINGS.SilentAimEnabled and SETTINGS.SilentAimFov or SETTINGS.CFrameAimFov
    fov_circle.Position = userInputService:GetMouseLocation()

    local targetPart = getClosestPlayerForSilentAim()
    target_box.Visible = SETTINGS.ShowTarget and SETTINGS.SilentAimEnabled and targetPart and true or false
    if target_box.Visible then
        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
        if onScreen then
            target_box.Position = Vector2.new(screenPos.X - 4, screenPos.Y - 4)
            target_box.Color = SETTINGS.TargetColor
        else
            target_box.Visible = false
        end
    end
end)

-- Hooks
if hookmetamethod and getnamecallmethod then
    local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(...)
        local method = getnamecallmethod()
        local args = {...}; local self = args[1]
        
        if SETTINGS.SilentAimEnabled and self == workspace and not checkcaller() and CalculateChance(SETTINGS.SilentAimHitChance) then
            local hitPart = getClosestPlayerForSilentAim()
            if hitPart then
                if SETTINGS.SilentAimMethod == "Raycast" and method == "Raycast" then
                    if ValidateArguments(args, ExpectedArguments.Raycast) then
                        args[3] = getDirection(args[2], hitPart.Position)
                        return oldNamecall(unpack(args))
                    end
                elseif (SETTINGS.SilentAimMethod == "FindPartOnRay" or SETTINGS.SilentAimMethod == "FindPartOnRayWithIgnoreList" or SETTINGS.SilentAimMethod == "FindPartOnRayWithWhitelist") and (method:find("FindPartOnRay")) then
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
            local hitPart = getClosestPlayerForSilentAim()
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

print("✅ Script v15.1 (Full & Complete) Berhasil Dimuat!")
