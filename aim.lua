--[[
    UNIVERSAL AIM & ESP - v13.5 SILENT AIM METHOD
    - DIKEMBALIKAN: Pengaturan untuk memilih metode Silent Aim (Raycast, Mouse.Hit/Target, dll.) telah ditambahkan kembali ke UI.
    - LOGIC UPDATE: Script's hooks (inti dari silent aim) sekarang akan berjalan secara dinamis sesuai dengan metode yang dipilih di UI.
    - KODE: 100% ditulis dalam format lengkap dan tidak diringkas.
]]

--// ================== PERSIAPAN & INISIALISASI ==================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

--// Services
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local coreGui = game:GetService("CoreGui")
local camera = workspace.CurrentCamera
local localPlayer = players.LocalPlayer
local mouse = localPlayer:GetMouse()

--// Peringatan jika fungsi penting tidak ada
if not hookmetamethod or not getnamecallmethod or not newcclosure or not checkcaller then
    warn("PERINGATAN: Executor Anda tidak mendukung fungsi hook yang diperlukan untuk Silent Aim. Fitur Silent Aim mungkin tidak akan berfungsi.")
end

--// ================== PENGATURAN / FLAGS ==================
getgenv().flags = {
    -- CFrame Aim
    CFrameAimEnabled = true,
    CFrameAimFov = 100,
    CFrameAimSmoothness = 15,
    CFrameAimHitbox = "Head",
    CFrameAimKey = "Right Click",

    -- Silent Aim
    SilentAimEnabled = false,
    SilentAimFov = 130,
    HitChances = 100,
    SilentAimHitbox = "HumanoidRootPart",
    VisibleCheck = false,
    SilentAimKey = "Left Click",
    SilentAimMethod = "Raycast",

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
    
    -- Misc
    TeamCheck = false
}
local flags = getgenv().flags

--// Variabel Kontrol
local isCFrameAiming = false
local isSilentAiming = false

--// ================== LOGIKA AIM & ESP (STABIL) ==================

local function isValidTarget(player) if not player or player == localPlayer then return false end; if flags.TeamCheck and player.Team and localPlayer.Team and player.Team == localPlayer.Team then return false end; local character = player.Character; local humanoid = character and character:FindFirstChild("Humanoid"); local root = character and character:FindFirstChild("HumanoidRootPart"); return humanoid and root and humanoid.Health > 0 end
local function getTargetForCFrameAim() local nearest = nil; local shortestDistance = flags.CFrameAimFov; local mousePosition = userInputService:GetMouseLocation(); for _, player in ipairs(players:GetPlayers()) do if isValidTarget(player) then local character = player.Character; local targetPart = character:FindFirstChild(flags.CFrameAimHitbox) or character:FindFirstChild("HumanoidRootPart"); if targetPart then local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position); if onScreen then local distance = (mousePosition - Vector2.new(screenPos.X, screenPos.Y)).Magnitude; if distance < shortestDistance then shortestDistance = distance; nearest = { targetPosition = targetPart.Position } end end end end end; return nearest end
local function updateCFrameAim() if not flags.CFrameAimEnabled or not isCFrameAiming then return end; local target = getTargetForCFrameAim(); if not target then return end; local smoothnessFactor = math.clamp(flags.CFrameAimSmoothness / 100, 0.01, 1); camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, target.targetPosition), smoothnessFactor) end
local function getClosestPlayerForSilentAim() local closestPlayerPart = nil; local shortestDistance = flags.SilentAimFov; for _, player in ipairs(players:GetPlayers()) do if isValidTarget(player) then if flags.VisibleCheck and not IsPlayerVisible(player) then continue end; local character = player.Character; local targetPart = character:FindFirstChild(flags.SilentAimHitbox) or character:FindFirstChild("HumanoidRootPart"); if targetPart then local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position); if onScreen then local distance = (userInputService:GetMouseLocation() - Vector2.new(screenPos.X, screenPos.Y)).Magnitude; if distance < shortestDistance then shortestDistance = distance; closestPlayerPart = targetPart end end end end end; return closestPlayerPart end
local ExpectedArguments = { FindPartOnRay = { ArgCountRequired = 2, Args = {"Instance", "Ray", "Instance", "boolean", "boolean"} }, Raycast = { ArgCountRequired = 3, Args = {"Instance", "Vector3", "Vector3", "RaycastParams"} } }; local function CalculateChance(Percentage) return (math.random() * 100) <= Percentage end; local function ValidateArguments(Args, RayMethod) if #Args < RayMethod.ArgCountRequired then return false end; local M=0; for P,A in ipairs(Args) do if typeof(A)==RayMethod.Args[P] then M=M+1 end end; return M >= RayMethod.ArgCountRequired end; local function getDirection(Origin, Position) return (Position - Origin).Unit * 1000 end; local function IsPlayerVisible(Player) local PC,LPC=Player.Character,localPlayer.Character; if not (PC and LPC) then return false end; local PR=PC:FindFirstChild(flags.SilentAimHitbox)or PC:FindFirstChild("HumanoidRootPart"); if not PR then return false end; return #camera:GetPartsObscuringTarget({PR.Position},{LPC,PC})==0 end
local function createEspBox(player) if not Drawing or not Drawing.new then return end; local allDrawings = {}; local box = Drawing.new("Square"); table.insert(allDrawings, box); local tracer = Drawing.new("Line"); table.insert(allDrawings, tracer); local name = Drawing.new("Text"); table.insert(allDrawings, name); local healthBar = Drawing.new("Square"); table.insert(allDrawings, healthBar); for _, obj in ipairs(allDrawings) do obj.Visible = false end; name.Size, name.Center, name.Outline = 16, true, true; healthBar.Filled = true; local connection; connection = runService.RenderStepped:Connect(function() box.Color, tracer.Color, name.Color = flags.ESPColor, flags.ESPColor, flags.ESPColor; local character = player.Character; if not flags.ESPEnabled or not character or not isValidTarget(player) then for _, obj in ipairs(allDrawings) do obj.Visible = false end; return end; local root, humanoid = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("Humanoid"); if not root or not humanoid then return end; local vector, onScreen = camera:WorldToViewportPoint(root.Position); if not onScreen then for _, obj in ipairs(allDrawings) do obj.Visible = false end; return end; local boxSizeY, boxSizeX = 3000 / vector.Z, 2000 / vector.Z; box.Visible = flags.ESPBox; if box.Visible then box.Size, box.Position = Vector2.new(boxSizeX, boxSizeY), Vector2.new(vector.X - boxSizeX / 2, vector.Y - boxSizeY / 2) end; tracer.Visible = flags.ESPSnaplines; if tracer.Visible then tracer.From, tracer.To = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y), Vector2.new(vector.X, vector.Y) end; name.Visible = flags.ESPNames; if name.Visible then name.Position, name.Text = Vector2.new(vector.X, vector.Y - boxSizeY/2 - 5), player.Name end; healthBar.Visible = flags.ESPHealth; if healthBar.Visible then local hp = humanoid.Health / humanoid.MaxHealth; healthBar.Position = Vector2.new(vector.X - boxSizeX/2 - 7, vector.Y - boxSizeY/2); healthBar.Size = Vector2.new(5, boxSizeY * hp); healthBar.Color = Color3.fromHSV(hp / 3, 1, 1) end end); player.CharacterAdded:Connect(function() if connection then connection.Enabled = true end end); player.CharacterRemoving:Connect(function() for _, obj in ipairs(allDrawings) do obj.Visible = false end; if connection then connection.Enabled = false end end) end


--// ================== UI BARU MENGGUNAKAN JANLIB (DENGAN METHODE SILENT AIM) ==================
local function CreateUI()
    local success, library = pcall(function()
        return loadstring(game:HttpGet('https://raw.githubusercontent.com/dawid-scripts/UI-Libs/main/discord%20lib.txt'))()
    end)
    if not success or not library then warn("Gagal memuat DiscordLib UI Library. UI tidak akan muncul. Error: " .. tostring(library)); return end
    
    local win = library:Window("Universal Script v13.5")
    local CFrameAim_Toggle, SilentAim_Toggle

    local AimServer = win:Server("Aim", "http://www.roblox.com/asset/?id=6031393359")
    
    local CFrameChannel = AimServer:Channel("CFrame Aim")
    CFrameAim_Toggle = CFrameChannel:Toggle("Aktifkan", flags.CFrameAimEnabled, function(bool) flags.CFrameAimEnabled = bool; if bool and SilentAim_Toggle then flags.SilentAimEnabled = false; SilentAim_Toggle:Set(false) end end)
    CFrameChannel:Slider("FOV", 10, 500, flags.CFrameAimFov, function(val) flags.CFrameAimFov = val end)
    CFrameChannel:Slider("Smoothness", 0, 100, flags.CFrameAimSmoothness, function(val) flags.CFrameAimSmoothness = val end)
    CFrameChannel:Dropdown("Target Part", {"Head", "Torso"}, function(selection) flags.CFrameAimHitbox = selection end)
    CFrameChannel:Dropdown("Tombol Hold", {"Right Click", "Left Click", "X"}, function(selection) flags.CFrameAimKey = selection end)

    local SilentChannel = AimServer:Channel("Silent Aim")
    SilentAim_Toggle = SilentChannel:Toggle("Aktifkan", flags.SilentAimEnabled, function(bool) flags.SilentAimEnabled = bool; if bool and CFrameAim_Toggle then flags.CFrameAimEnabled = false; CFrameAim_Toggle:Set(false) end end)
    SilentChannel:Slider("FOV", 10, 500, flags.SilentAimFov, function(val) flags.SilentAimFov = val end)
    SilentChannel:Slider("Hit Chance", 0, 100, flags.HitChances, function(val) flags.HitChances = val end)
    SilentChannel:Dropdown("Target Part", {"HumanoidRootPart", "Head"}, function(selection) flags.SilentAimHitbox = selection end)
    SilentChannel:Dropdown("Tombol Hold", {"Left Click", "Right Click", "X"}, function(selection) flags.SilentAimKey = selection end)
    SilentChannel:Dropdown("Metode", {"Raycast", "Mouse.Hit/Target", "FindPartOnRay"}, function(selection) flags.SilentAimMethod = selection end)
    SilentChannel:Toggle("Cek Terlihat", flags.VisibleCheck, function(bool) flags.VisibleCheck = bool end)

    local VisualsServer = win:Server("Visuals", "http://www.roblox.com/asset/?id=3130635425")
    local ESPChannel = VisualsServer:Channel("Player ESP"); ESPChannel:Toggle("Aktifkan ESP", flags.ESPEnabled, function(bool) flags.ESPEnabled = bool end); ESPChannel:Toggle("Box", flags.ESPBox, function(bool) flags.ESPBox = bool end); ESPChannel:Toggle("Nama", flags.ESPNames, function(bool) flags.ESPNames = bool end); ESPChannel:Toggle("Garis", flags.ESPSnaplines, function(bool) flags.ESPSnaplines = bool end); ESPChannel:Toggle("Darah", flags.ESPHealth, function(bool) flags.ESPHealth = bool end); ESPChannel:Colorpicker("Warna ESP", flags.ESPColor, function(color) flags.ESPColor = color end)
    local FovChannel = VisualsServer:Channel("FOV Circle"); FovChannel:Toggle("Tampilkan FOV", flags.DrawFov, function(bool) flags.DrawFov = bool end); FovChannel:Colorpicker("Warna FOV", flags.FovColor, function(color) flags.FovColor = color end)

    local SettingsServer = win:Server("Settings", "http://www.roblox.com/asset/?id=394239836")
    local MiscChannel = SettingsServer:Channel("Misc")
    MiscChannel:Toggle("Cek Tim", flags.TeamCheck, function(bool) flags.TeamCheck = bool end)
end

--// ================== PUSAT KONTROL & INISIALISASI ==================
pcall(CreateUI)

local function setupEsp() local function connectPlayer(player) if player ~= localPlayer then pcall(createEspBox, player) end end; for _, player in ipairs(players:GetPlayers()) do connectPlayer(player) end; players.PlayerAdded:Connect(connectPlayer) end
setupEsp()

local function parseKeySelection(selection) if selection == "Right Click" then return "Mouse", Enum.UserInputType.MouseButton2 elseif selection == "Left Click" then return "Mouse", Enum.UserInputType.MouseButton1 elseif selection == "X" then return "Key", Enum.KeyCode.X end; return nil, nil end
userInputService.InputBegan:Connect(function(input, processed) if processed then return end; local cframeType, cframeKey = parseKeySelection(flags.CFrameAimKey); if cframeType == "Key" and input.KeyCode == cframeKey then isCFrameAiming = true elseif cframeType == "Mouse" and input.UserInputType == cframeKey then isCFrameAiming = true end; local silentType, silentKey = parseKeySelection(flags.SilentAimKey); if silentType == "Key" and input.KeyCode == silentKey then isSilentAiming = true elseif silentType == "Mouse" and input.UserInputType == silentKey then isSilentAiming = true end end)
userInputService.InputEnded:Connect(function(input, processed) if processed then return end; local cframeType, cframeKey = parseKeySelection(flags.CFrameAimKey); if cframeType == "Key" and input.KeyCode == cframeKey then isCFrameAiming = false elseif cframeType == "Mouse" and input.UserInputType == cframeKey then isCFrameAiming = false end; local silentType, silentKey = parseKeySelection(flags.SilentAimKey); if silentType == "Key" and input.KeyCode == silentKey then isSilentAiming = false elseif silentType == "Mouse" and input.UserInputType == silentKey then isSilentAiming = false end end)

local fov_circle; pcall(function() fov_circle = Drawing.new("Circle"); fov_circle.Thickness = 1; fov_circle.NumSides = 100; fov_circle.Filled = false; fov_circle.Visible = false; fov_circle.ZIndex = 9999; fov_circle.Transparency = 1 end)

runService.RenderStepped:Connect(function()
    updateCFrameAim()
    if fov_circle then
        local currentFov = flags.CFrameAimEnabled and flags.CFrameAimFov or flags.SilentAimFov
        fov_circle.Radius = currentFov
        fov_circle.Visible = flags.DrawFov and (flags.CFrameAimEnabled or flags.SilentAimEnabled)
        fov_circle.Position = userInputService:GetMouseLocation()
        fov_circle.Color = flags.FovColor
    end
end)

if hookmetamethod and getnamecallmethod then
    local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(...)
        local method = getnamecallmethod()
        local args = {...}
        local self = args[1]
        
        if flags.SilentAimEnabled and isSilentAiming and self == workspace and not checkcaller() and CalculateChance(flags.HitChances) then
            local hitPart = getClosestPlayerForSilentAim()
            if hitPart then
                if flags.SilentAimMethod == "Raycast" and method == "Raycast" then
                    if ValidateArguments(args, ExpectedArguments.Raycast) then args[3] = getDirection(args[2], hitPart.Position); return oldNamecall(unpack(args)) end
                elseif flags.SilentAimMethod == "FindPartOnRay" and (method == "FindPartOnRay" or method == "findPartOnRay") then
                     if ValidateArguments(args, ExpectedArguments.FindPartOnRay) then local ray = args[2]; args[2] = Ray.new(ray.Origin, getDirection(ray.Origin, hitPart.Position)); return oldNamecall(unpack(args)) end
                end
            end
        end
        return oldNamecall(...)
    end)
    
    local oldIndex; oldIndex = hookmetamethod(game, "__index", function(self, index)
        if flags.SilentAimEnabled and isSilentAiming and flags.SilentAimMethod == "Mouse.Hit/Target" and self == mouse and not checkcaller() then
            local hitPart = getClosestPlayerForSilentAim()
            if hitPart then
                if index == "Target" or index == "target" then return hitPart end
                if index == "Hit" or index == "hit" then return hitPart.CFrame end
            end
        end
        return oldIndex(self, index)
    end)
end

print("✅ Script v13.5 (Silent Aim Method) Berhasil Dimuat!")
