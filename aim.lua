-- Services
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local httpService = game:GetService("HttpService")

-- Wait for game to load
if not game:IsLoaded() then 
    game.Loaded:Wait()
end

-- Constants
local SETTINGS = {
    smoothness = 0.5,
    maxDistance = 1000,
    aimFov = 100,
    triggerKey = Enum.KeyCode.X,
    triggerType = "Key", -- "Key", "MouseButton1", "MouseButton2"
    targetPart = "Head", -- "Head", "Torso", "Legs"
    targetOffsets = {
        Head = Vector3.new(0, 0.5, 0),
        Torso = Vector3.new(0, 0, 0),
        Legs = Vector3.new(0, -2.5, 0),
        Neck = Vector3.new(0, 0.3, 0)
    },
    magicBullet = false,
    magicBulletEnabled = false,
    espEnabled = true,
    espColor = Color3.fromRGB(255, 0, 0),
    espThickness = 1,
    espTransparency = 0.5,
    snapLines = true,
    boxEsp = true,
    nameEsp = true,
    healthBar = true,
    noRecoil = false,
    -- Universal Silent Aim Settings
    silentAim = false,
    silentAimMethod = "Mouse.Hit/Target", -- Changed default for better compatibility
    silentAimFOV = 130,
    silentAimHitChance = 100,
    silentAimTeamCheck = false,
    silentAimVisibleCheck = false,
    silentAimTargetPart = "HumanoidRootPart",
    silentAimPrediction = false,
    silentAimPredictionAmount = 0.165,
    -- New smooth settings
    smoothSilentAim = not isMobile, -- Disable smooth for mobile to reduce lag
    silentAimSmoothness = isMobile and 0.3 or 0.8, -- Faster for mobile
    restoreMousePosition = not isMobile, -- Disable restore for mobile
}

-- Variables
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()
local isAiming = false
local enabled = false

-- Silent Aim variables
local silentAiming = false
local originalMousePos = Vector2.new(0, 0)
local restoreMouse = false

-- Mobile optimization variables
local isMobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
local lastSilentAimTime = 0
local silentAimCooldown = isMobile and 0.1 or 0.01 -- Longer cooldown for mobile

-- Universal Silent Aim Variables
local ExpectedArguments = {
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = {"Instance", "Ray", "table", "boolean", "boolean"}
    },
    FindPartOnRayWithWhitelist = {
        ArgCountRequired = 3,
        Args = {"Instance", "Ray", "table", "boolean"}
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = {"Instance", "Ray", "Instance", "boolean", "boolean"}
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = {"Instance", "Vector3", "Vector3", "RaycastParams"}
    }
}

-- ESP Container
local espFolder = Instance.new("Folder")
espFolder.Name = "ESP"
espFolder.Parent = game:GetService("CoreGui")

-- Universal Silent Aim Functions
local function calculateChance(percentage)
    percentage = math.floor(percentage)
    local chance = math.floor(math.random() * 100) / 100
    return chance <= percentage / 100
end

local function getPositionOnScreen(vector)
    local vec3, onScreen = camera:WorldToScreenPoint(vector)
    return Vector2.new(vec3.X, vec3.Y), onScreen
end

local function validateArguments(args, rayMethod)
    local matches = 0
    if #args < rayMethod.ArgCountRequired then
        return false
    end
    for pos, argument in pairs(args) do
        if typeof(argument) == rayMethod.Args[pos] then
            matches = matches + 1
        end
    end
    return matches >= rayMethod.ArgCountRequired
end

local function getDirection(origin, position)
    return (position - origin).Unit * 1000
end

local function getMousePosition()
    return userInputService:GetMouseLocation()
end

local function isPlayerVisible(player)
    if not SETTINGS.silentAimVisibleCheck then return true end
    
    local playerCharacter = player.Character
    local localPlayerCharacter = localPlayer.Character
    
    if not (playerCharacter and localPlayerCharacter) then return false end 
    
    local playerRoot = playerCharacter:FindFirstChild(SETTINGS.silentAimTargetPart) or playerCharacter:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot then return false end 
    
    local castPoints = {playerRoot.Position}
    local ignoreList = {localPlayerCharacter, playerCharacter}
    local obscuringObjects = #camera:GetPartsObscuringTarget(castPoints, ignoreList)
    
    return obscuringObjects == 0
end

local function getClosestPlayerForSilentAim()
    if not SETTINGS.silentAimTargetPart then return nil end
    local closest = nil
    local distanceToMouse = math.huge
    
    for _, player in pairs(players:GetPlayers()) do
        if player == localPlayer then continue end
        if SETTINGS.silentAimTeamCheck and player.Team == localPlayer.Team then continue end

        local character = player.Character
        if not character then continue end
        
        if not isPlayerVisible(player) then continue end

        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then continue end

        local screenPosition, onScreen = getPositionOnScreen(humanoidRootPart.Position)
        if not onScreen then continue end

        local distance = (getMousePosition() - screenPosition).Magnitude
        if distance <= SETTINGS.silentAimFOV and distance < distanceToMouse then
            local targetPart = character:FindFirstChild(SETTINGS.silentAimTargetPart)
            if targetPart then
                closest = targetPart
                distanceToMouse = distance
            end
        end
    end
    return closest
end

-- Function to check if target valid for aim assist
local function isValidTargetAimAssist(player)
    if not player or player == localPlayer then return false end
    if player.Team == localPlayer.Team then return false end
    
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    
    return humanoid 
        and root 
        and humanoid.Health > 0 
        and character:FindFirstChild("Head")
end

-- Function to get nearest enemy in FOV for aim assist
local function getNearestEnemyInFOV()
    local nearest = nil
    local minAngle = math.rad(SETTINGS.aimFov)
    local myCharacter = localPlayer.Character
    local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
    
    if not myRoot then return nil end
    
    for _, player in pairs(players:GetPlayers()) do
        if isValidTargetAimAssist(player) then
            local character = player.Character
            local head = character:FindFirstChild("Head")
            local root = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            
            if head and root and humanoid and humanoid.Health > 0 then
                -- Get target position based on selected part
                local targetPos
                if SETTINGS.targetPart == "Head" then
                    targetPos = head.Position
                elseif SETTINGS.targetPart == "Torso" then
                    targetPos = root.Position
                elseif SETTINGS.targetPart == "Neck" then
                    targetPos = head.Position + SETTINGS.targetOffsets.Neck
                else
                    targetPos = root.Position + Vector3.new(0, -2.5, 0)
                end
                
                -- Apply offset
                targetPos = targetPos + (SETTINGS.targetOffsets[SETTINGS.targetPart] or Vector3.new(0, 0, 0))
                
                -- Calculate angle to target
                local toTarget = (targetPos - camera.CFrame.Position).Unit
                local dot = camera.CFrame.LookVector:Dot(toTarget)
                local angle = math.acos(math.clamp(dot, -1, 1))
                
                -- Check if in FOV and closer than current nearest
                if angle < minAngle then
                    local distance = (root.Position - myRoot.Position).Magnitude
                    if distance < SETTINGS.maxDistance then
                        minAngle = angle
                        nearest = {
                            player = player,
                            character = character,
                            root = root,
                            head = head,
                            targetPosition = targetPos,
                            distance = distance,
                            humanoid = humanoid
                        }
                    end
                end
            end
        end
    end
    return nearest
end

-- Function to get target position
local function getTargetPosition(target)
    return target.targetPosition
end

-- Function to check if Silent Aim should be active
local function shouldUseSilentAim()
    return SETTINGS.silentAim and userInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

-- Function to perform aim assist
local function updateAim()
    if not enabled or not isAiming then return end
    
    local target = getNearestEnemyInFOV()
    if not target then return end
    
    -- Get target position
    local targetPos = getTargetPosition(target)
    
    -- Calculate new CFrame to look at target
    local newCFrame = CFrame.new(camera.CFrame.Position, targetPos)
    
    -- Smooth interpolation
    local smoothness = math.clamp(SETTINGS.smoothness, 0.1, 1)
    camera.CFrame = camera.CFrame:Lerp(newCFrame, smoothness)
end

-- No recoil function
local function removeRecoil()
    if SETTINGS.noRecoil then
        local character = localPlayer.Character
        if character then
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    for _, child in ipairs(tool:GetDescendants()) do
                        if child:IsA("Script") and child.Name:lower():find("recoil") then
                            child.Disabled = true
                        end
                    end
                end
            end
        end
    end
end

-- Debug function
local function testFunctions()
    print("=== TESTING FUNCTIONS ===")
    print("Game loaded:", game:IsLoaded())
    print("LocalPlayer:", localPlayer and localPlayer.Name or "nil")
    print("Camera:", camera and "OK" or "nil")
    print("Mouse:", mouse and "OK" or "nil")
    print("SETTINGS exists:", SETTINGS ~= nil)
    print("Players in game:", #players:GetPlayers())
    
    -- Test hook functions
    print("hookmetamethod:", hookmetamethod and "Available" or "Missing")
    print("getnamecallmethod:", getnamecallmethod and "Available" or "Missing")
    print("newcclosure:", newcclosure and "Available" or "Missing")
    print("checkcaller:", checkcaller and "Available" or "Missing")
    
    -- Test alternative hook methods
    print("hookfunction:", hookfunction and "Available" or "Missing")
    print("replaceclosure:", replaceclosure and "Available" or "Missing")
    print("getgc:", getgc and "Available" or "Missing")
    print("debug.getmetatable:", debug and debug.getmetatable and "Available" or "Missing")
    print("setreadonly:", setreadonly and "Available" or "Missing")
    print("getrawmetatable:", getrawmetatable and "Available" or "Missing")
    print("mousemoveabs:", mousemoveabs and "Available" or "Missing")
    print("mousemoverel:", mousemoverel and "Available" or "Missing")
    
    -- Test if we can access workspace methods directly
    local wsSuccess, wsmt = pcall(function() return getrawmetatable and getrawmetatable(workspace) end)
    print("workspace metatable:", wsSuccess and wsmt and "Available" or "Missing")
    
    -- Check alternative hooks status
    print("Alternative Hooks Status:")
    print("  - Direct Hook:", alternativeHooks.directHook and "Active" or "Inactive")
    print("  - Mouse Hook:", alternativeHooks.mouseHook and "Active" or "Inactive")
    print("  - Raycast Hook:", alternativeHooks.raycastHook and "Active" or "Inactive")
    
    -- Test calculations
    print("calculateChance(100):", calculateChance(100))
    print("getClosestPlayerForSilentAim():", getClosestPlayerForSilentAim() ~= nil and "Target found" or "No target")
    print("shouldUseSilentAim():", shouldUseSilentAim())
    print("SETTINGS.silentAim:", SETTINGS.silentAim)
    
    -- Test UI
    print("ScreenGui:", ScreenGui and "Created" or "Missing")
    print("MainFrame:", MainFrame and "Created" or "Missing")
    
    print("========================")
end

-- Universal Silent Aim Hooks (Protected)
print("🔧 Setting up hooks...")
local hookSuccess = false
local oldNamecall, oldIndex

-- Alternative Silent Aim Methods
local alternativeHooks = {
    mouseHook = false,
    raycastHook = false,
    directHook = false
}

-- Method 1: Try standard hookmetamethod
local success, hookError = pcall(function()
    -- Check if functions exist first
    if not hookmetamethod or not getnamecallmethod or not newcclosure then
        error("Required hook functions not available")
    end
    
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
        local args = {...}
        
        -- Safe call to getnamecallmethod
        local success, method = pcall(getnamecallmethod)
        if not success then
            return oldNamecall(...)
        end
        
        local self = args[1]
        
        if not SETTINGS or not SETTINGS.silentAim then
            return oldNamecall(...)
        end
        
        local chance = calculateChance(SETTINGS.silentAimHitChance)
        
        if SETTINGS.silentAim and self == workspace and chance then
            -- Check if checkcaller exists and use it safely
            local callerCheck = true
            if checkcaller then
                local success, result = pcall(checkcaller)
                callerCheck = success and not result
            end
            
            if callerCheck then
                local hitPart = getClosestPlayerForSilentAim()
                if hitPart then
                    print("🎯 Silent Aim Hook Active - Method:", method, "Target:", hitPart.Parent.Name)
                    
                    if method == "FindPartOnRayWithIgnoreList" and SETTINGS.silentAimMethod == method then
                        if validateArguments(args, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                            local ray = args[2]
                            local origin = ray.Origin
                            local direction = getDirection(origin, hitPart.Position)
                            args[2] = Ray.new(origin, direction)
                            return oldNamecall(unpack(args))
                        end
                    elseif method == "FindPartOnRayWithWhitelist" and SETTINGS.silentAimMethod == method then
                        if validateArguments(args, ExpectedArguments.FindPartOnRayWithWhitelist) then
                            local ray = args[2]
                            local origin = ray.Origin
                            local direction = getDirection(origin, hitPart.Position)
                            args[2] = Ray.new(origin, direction)
                            return oldNamecall(unpack(args))
                        end
                    elseif (method == "FindPartOnRay" or method == "findPartOnRay") and SETTINGS.silentAimMethod:lower() == method:lower() then
                        if validateArguments(args, ExpectedArguments.FindPartOnRay) then
                            local ray = args[2]
                            local origin = ray.Origin
                            local direction = getDirection(origin, hitPart.Position)
                            args[2] = Ray.new(origin, direction)
                            return oldNamecall(unpack(args))
                        end
                    elseif method == "Raycast" and SETTINGS.silentAimMethod == method then
                        if validateArguments(args, ExpectedArguments.Raycast) then
                            local origin = args[2]
                            args[3] = getDirection(origin, hitPart.Position)
                            return oldNamecall(unpack(args))
                        end
                    end
                end
            end
        end
        return oldNamecall(...)
    end))
    
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, index)
        if not SETTINGS or not SETTINGS.silentAim or not mouse then
            return oldIndex(self, index)
        end
        
        -- Check if checkcaller exists and use it safely
        local callerCheck = true
        if checkcaller then
            local success, result = pcall(checkcaller)
            callerCheck = success and not result
        end
        
        if self == mouse and callerCheck and SETTINGS.silentAim and SETTINGS.silentAimMethod == "Mouse.Hit/Target" then
            local hitPart = getClosestPlayerForSilentAim()
            if hitPart then
                print("🎯 Mouse Hook Active - Index:", index, "Target:", hitPart.Parent.Name)
                
                if index == "Target" or index == "target" then 
                    return hitPart
                elseif index == "Hit" or index == "hit" then 
                    if SETTINGS.silentAimPrediction then
                        return hitPart.CFrame + (hitPart.Velocity * SETTINGS.silentAimPredictionAmount)
                    else
                        return hitPart.CFrame
                    end
                elseif index == "X" or index == "x" then 
                    return self.X 
                elseif index == "Y" or index == "y" then 
                    return self.Y 
                elseif index == "UnitRay" then 
                    return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)
                end
            end
        end

        return oldIndex(self, index)
    end))
    
    hookSuccess = true
end)

-- Method 2: Alternative hook using getrawmetatable
if not hookSuccess then
    print("⚠️ Trying alternative hook method...")
    local success2, altError = pcall(function()
        if getrawmetatable then
            local mt = getrawmetatable(game)
            if mt then
                if setreadonly then setreadonly(mt, false) end
                
                local oldNamecallAlt = mt.__namecall
                mt.__namecall = function(...)
                    local args = {...}
                    local self = args[1]
                    local method = tostring(args[#args]):gsub(".*:", ""):lower()
                    
                    if SETTINGS and SETTINGS.silentAim and self == workspace then
                        local hitPart = getClosestPlayerForSilentAim()
                        if hitPart and calculateChance(SETTINGS.silentAimHitChance) then
                            if method:find("raycast") or method:find("findpart") then
                                print("🎯 Alt Hook Active - Method:", method, "Target:", hitPart.Parent.Name)
                                -- Modify raycast direction
                                if args[2] and args[3] then
                                    args[3] = getDirection(args[2], hitPart.Position)
                                elseif args[2] and args[2].Origin then
                                    args[2] = Ray.new(args[2].Origin, getDirection(args[2].Origin, hitPart.Position))
                                end
                            end
                        end
                    end
                    
                    return oldNamecallAlt(...)
                end
                
                if setreadonly then setreadonly(mt, true) end
                alternativeHooks.directHook = true
                hookSuccess = true
                print("✅ Alternative hook method successful!")
            end
        end
    end)
    
    if not hookSuccess then
        print("⚠️ Alternative hook failed:", altError or "Unknown error")
    end
end

-- Method 3: Mouse simulation approach
if not hookSuccess then
    print("⚠️ Trying mouse simulation method...")
    local mouseSimSuccess = pcall(function()
        -- This method simulates mouse movement instead of hooking
        alternativeHooks.mouseHook = true
        hookSuccess = true
        print("✅ Mouse simulation method activated!")
    end)
end

if hookSuccess and success then
    print("✅ Hooks set up successfully!")
elseif alternativeHooks.directHook then
    print("✅ Alternative direct hook active!")
elseif alternativeHooks.mouseHook then
    print("✅ Mouse simulation method active!")
else
    print("⚠️ Hook setup failed:", hookError or "Unknown error")
    print("⚠️ Silent Aim will not work, but other features will still function")
    SETTINGS.silentAim = false -- Disable silent aim if hooks failed
end

-- Input handling
userInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- Toggle Silent Aim with Z key
    if input.KeyCode == Enum.KeyCode.Z then
        SETTINGS.silentAim = not SETTINGS.silentAim
        print("🎯 Universal Silent Aim:", SETTINGS.silentAim and "ENABLED" or "DISABLED")
        return
    end
    
    -- Toggle Aim Assist with HOME key  
    if input.KeyCode == Enum.KeyCode.Home then
        enabled = not enabled
        print("🎯 Aim Assist:", enabled and "ENABLED" or "DISABLED")
        return
    end
    
    -- Toggle ESP with END key
    if input.KeyCode == Enum.KeyCode.End then
        SETTINGS.espEnabled = not SETTINGS.espEnabled
        print("👁️ ESP:", SETTINGS.espEnabled and "ENABLED" or "DISABLED")
        return
    end
    
    if SETTINGS.triggerType == "Key" and input.KeyCode == SETTINGS.triggerKey then
        isAiming = true
    elseif SETTINGS.triggerType == "MouseButton1" and input.UserInputType == Enum.UserInputType.MouseButton1 then
        isAiming = true
    elseif SETTINGS.triggerType == "MouseButton2" and input.UserInputType == Enum.UserInputType.MouseButton2 then
        isAiming = true
    end
end)

userInputService.InputEnded:Connect(function(input, processed)
    if processed then return end
    
    if SETTINGS.triggerType == "Key" and input.KeyCode == SETTINGS.triggerKey then
        isAiming = false
    elseif SETTINGS.triggerType == "MouseButton1" and input.UserInputType == Enum.UserInputType.MouseButton1 then
        isAiming = false
    elseif SETTINGS.triggerType == "MouseButton2" and input.UserInputType == Enum.UserInputType.MouseButton2 then
        isAiming = false
    end
end)

-- Create UI (Protected)
print("🎨 Creating UI...")
local uiSuccess = false
local ScreenGui, MainFrame

local success, uiError = pcall(function()
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AimAssistGui"
    ScreenGui.ResetOnSpawn = false
    
    -- Try to parent to CoreGui, fallback to PlayerGui
    local success = pcall(function()
        ScreenGui.Parent = game:GetService("CoreGui")
    end)
    
    if not success then
        ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")
        print("⚠️ Using PlayerGui instead of CoreGui")
    end

    -- Detect if mobile
    local isMobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    
    if isMobile then
        -- Mobile layout: larger and touch-friendly
        MainFrame.Size = UDim2.new(0, 280, 0, 750) -- Increased height for presets
        MainFrame.Position = UDim2.new(0.5, -140, 0, 20)
    else
        -- PC layout: compact side panel
        MainFrame.Size = UDim2.new(0, 200, 0, 1350)
        MainFrame.Position = UDim2.new(1, -220, 0.5, -675)
    end
    
    MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Text = "Universal Aim System"
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 16
    Title.Parent = MainFrame
    
    -- Hotkey info label  
    local HotkeyInfo = Instance.new("TextLabel")
    
    if isMobile then
        HotkeyInfo.Size = UDim2.new(1, 0, 0, 100)
        HotkeyInfo.Text = "📱 MOBILE MODE:\nTap buttons below\nTo toggle features\n\n⚠️ Reduced lag mode"
    else
        HotkeyInfo.Size = UDim2.new(1, 0, 0, 80)
        HotkeyInfo.Text = "🎮 HOTKEYS:\nZ = Silent Aim ON/OFF\nHOME = Aim Assist ON/OFF\nEND = ESP ON/OFF\n\n✅ Mouse Simulation Ready!"
    end
    
    HotkeyInfo.Position = UDim2.new(0, 0, 0, 30)
    HotkeyInfo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    HotkeyInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    HotkeyInfo.Font = Enum.Font.SourceSans
    HotkeyInfo.TextSize = isMobile and 14 or 12
    HotkeyInfo.TextYAlignment = Enum.TextYAlignment.Top
    HotkeyInfo.Parent = MainFrame
    
    uiSuccess = true
    print("✅ UI Frame created successfully!")
end)

if not uiSuccess then
    print("❌ UI creation failed:", uiError or "Unknown error")
    print("❌ Script will not work properly")
    return
end

-- Create toggle function
local function createToggle(name, default, y)
    local toggle = Instance.new("TextButton")
    
    if isMobile then
        toggle.Size = UDim2.new(0.9, 0, 0, 40) -- Larger for touch
        toggle.TextSize = 16
    else
        toggle.Size = UDim2.new(0.9, 0, 0, 25)
        toggle.TextSize = 14
    end
    
    toggle.Position = UDim2.new(0.05, 0, 0, y)
    toggle.BackgroundColor3 = default and Color3.fromRGB(60, 180, 75) or Color3.fromRGB(180, 60, 60)
    toggle.Text = name .. ": " .. (default and "ON" or "OFF")
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.SourceSans
    toggle.Parent = MainFrame
    
    local value = default
    toggle.MouseButton1Click:Connect(function()
        value = not value
        toggle.BackgroundColor3 = value and Color3.fromRGB(60, 180, 75) or Color3.fromRGB(180, 60, 60)
        toggle.Text = name .. ": " .. (value and "ON" or "OFF")
        
        if name == "Aim Assist" then
            enabled = value
            print("Aim Assist:", value)
        elseif name == "Magic Bullet" then
            SETTINGS.magicBulletEnabled = value
            SETTINGS.magicBullet = value
            print("Magic Bullet:", value)
        elseif name == "Universal Silent Aim" then
            SETTINGS.silentAim = value
            print("Universal Silent Aim:", value)
        elseif name == "ESP" then
            SETTINGS.espEnabled = value
            print("ESP:", value)
        elseif name == "Snap Lines" then
            SETTINGS.snapLines = value
        elseif name == "Box ESP" then
            SETTINGS.boxEsp = value
        elseif name == "Name ESP" then
            SETTINGS.nameEsp = value
        elseif name == "Health Bar" then
            SETTINGS.healthBar = value
        elseif name == "No Recoil" then
            SETTINGS.noRecoil = value
            print("No Recoil:", value)
        elseif name == "Silent Aim Team Check" then
            SETTINGS.silentAimTeamCheck = value
            print("Silent Aim Team Check:", value)
        elseif name == "Silent Aim Visible Check" then
            SETTINGS.silentAimVisibleCheck = value
            print("Silent Aim Visible Check:", value)
        elseif name == "Silent Aim Prediction" then
            SETTINGS.silentAimPrediction = value
            print("Silent Aim Prediction:", value)
        elseif name == "Smooth Silent Aim" then
            SETTINGS.smoothSilentAim = value
            print("Smooth Silent Aim:", value)
        elseif name == "Restore Mouse Position" then
            SETTINGS.restoreMousePosition = value
            print("Restore Mouse Position:", value)
        end
    end)
    return toggle
end

-- Create slider function
local function createSlider(name, min, max, default, y)
    local sliderFrame = Instance.new("Frame")
    
    if isMobile then
        sliderFrame.Size = UDim2.new(0.9, 0, 0, 60) -- Larger for mobile
    else
        sliderFrame.Size = UDim2.new(0.9, 0, 0, 40)
    end
    
    sliderFrame.Position = UDim2.new(0.05, 0, 0, y)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = MainFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, isMobile and 25 or 20)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = isMobile and 16 or 14
    label.Parent = sliderFrame
    
    local slider = Instance.new("TextButton")
    
    if isMobile then
        slider.Size = UDim2.new(1, 0, 0, 25) -- Thicker slider for touch
        slider.Position = UDim2.new(0, 0, 0, 30)
    else
        slider.Size = UDim2.new(1, 0, 0, 4)
        slider.Position = UDim2.new(0, 0, 0.7, 0)
    end
    
    slider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    slider.Text = ""
    slider.AutoButtonColor = false
    slider.Parent = sliderFrame
    
    -- Add corner radius for mobile
    if isMobile then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = slider
    end
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
    fill.Parent = slider
    
    -- Mobile corner radius for fill too
    if isMobile then
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 8)
        fillCorner.Parent = fill
    end
    
    local dragging = false
    
    -- Mobile-friendly touch handling
    local function updateSlider(input)
        if dragging then
            local percent = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            local value = min + (max - min) * percent
            fill.Size = UDim2.new(percent, 0, 1, 0)
            
            -- Round values for better display
            local displayValue
            if max > 10 then
                displayValue = math.floor(value)
            else
                displayValue = math.floor(value * 100) / 100
            end
            
            label.Text = name .. ": " .. displayValue
            
            if name == "Smoothness" then
                SETTINGS.smoothness = value
            elseif name == "FOV" then
                SETTINGS.aimFov = value
            elseif name == "Max Distance" then
                SETTINGS.maxDistance = value
            elseif name == "Silent Aim FOV" then
                SETTINGS.silentAimFOV = value
            elseif name == "Silent Aim Hit Chance" then
                SETTINGS.silentAimHitChance = value
            elseif name == "Silent Aim Smoothness" then
                SETTINGS.silentAimSmoothness = value
            elseif name == "Silent Aim Prediction Amount" then
                SETTINGS.silentAimPredictionAmount = value
            end
        end
    end
    
    -- Touch/Mouse down
    slider.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    -- Touch/Mouse up
    userInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- Mouse moved (PC)
    slider.MouseMoved:Connect(function()
        if not isMobile then
            updateSlider(userInputService:GetMouseLocation())
        end
    end)
    
    -- Touch moved (Mobile)
    userInputService.TouchMoved:Connect(function(touch, gameProcessed)
        if isMobile and dragging and not gameProcessed then
            updateSlider(touch)
        end
    end)
    
    -- Direct tap/click for quick adjustments (Mobile)
    slider.MouseButton1Click:Connect(function()
        if isMobile then
            local mousePos = userInputService:GetMouseLocation()
            updateSlider({Position = mousePos})
        end
    end)
end

-- Create dropdown function
local function createDropdown(name, options, default, y)
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Size = UDim2.new(0.9, 0, 0, 50)
    dropdownFrame.Position = UDim2.new(0.05, 0, 0, y)
    dropdownFrame.BackgroundTransparency = 1
    dropdownFrame.Parent = MainFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.Parent = dropdownFrame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 25)
    button.Position = UDim2.new(0, 0, 0.5, 0)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.Text = default
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 14
    button.Parent = dropdownFrame

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Size = UDim2.new(1, 0, 0, #options * 25)
    optionsFrame.Position = UDim2.new(0, 0, 1, 0)
    optionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    optionsFrame.Visible = false
    optionsFrame.ZIndex = 5
    optionsFrame.Parent = button

    for i, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 25)
        optionButton.Position = UDim2.new(0, 0, 0, (i-1) * 25)
        optionButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        optionButton.Text = option
        optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionButton.Font = Enum.Font.SourceSans
        optionButton.TextSize = 14
        optionButton.ZIndex = 5
        optionButton.Parent = optionsFrame

        optionButton.MouseButton1Click:Connect(function()
            button.Text = option
            optionsFrame.Visible = false
            
            if name == "Trigger Key" then
                if option == "Left Click" then
                    SETTINGS.triggerType = "MouseButton1"
                elseif option == "Right Click" then
                    SETTINGS.triggerType = "MouseButton2"
                else
                    SETTINGS.triggerType = "Key"
                    SETTINGS.triggerKey = Enum.KeyCode[option]
                end
                print("Trigger Key changed to:", option)
            elseif name == "Target Point" then
                SETTINGS.targetPart = option
                print("Target Point changed to:", option)
            elseif name == "Silent Aim Method" then
                SETTINGS.silentAimMethod = option
                print("Silent Aim Method changed to:", option)
            elseif name == "Silent Aim Target" then
                SETTINGS.silentAimTargetPart = option
                print("Silent Aim Target changed to:", option)
            end
        end)
    end

    button.MouseButton1Click:Connect(function()
        optionsFrame.Visible = not optionsFrame.Visible
    end)

    return button
end

-- Key options
local keyOptions = {"X", "E", "R", "T", "F", "C", "Left Click", "Right Click"}
local targetOptions = {"Head", "Torso", "Legs", "Neck"}
local silentAimMethods = {"Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse.Hit/Target"}
local silentAimTargets = {"Head", "HumanoidRootPart"}

-- Create UI Elements (Mobile optimized)
if isMobile then
    -- Mobile: Essential features only to reduce lag
    createToggle("Aim Assist", false, 140)
    createToggle("Universal Silent Aim", false, 190) 
    createToggle("ESP", true, 240)
    createToggle("Smooth Silent Aim", false, 290) -- Off by default for mobile
    
    -- Mobile-friendly sliders with bigger touch targets
    createSlider("Smoothness", 0.1, 1, SETTINGS.smoothness, 350)
    createSlider("FOV", 30, 180, SETTINGS.aimFov, 430)
    createSlider("Silent Aim FOV", 30, 360, SETTINGS.silentAimFOV, 510)
    
    -- Quick preset buttons for mobile
    local presetFrame = Instance.new("Frame")
    presetFrame.Size = UDim2.new(0.9, 0, 0, 80)
    presetFrame.Position = UDim2.new(0.05, 0, 0, 590)
    presetFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    presetFrame.Parent = MainFrame
    
    local presetCorner = Instance.new("UICorner")
    presetCorner.CornerRadius = UDim.new(0, 10)
    presetCorner.Parent = presetFrame
    
    local presetTitle = Instance.new("TextLabel")
    presetTitle.Size = UDim2.new(1, 0, 0, 25)
    presetTitle.BackgroundTransparency = 1
    presetTitle.Text = "📱 Quick Presets"
    presetTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    presetTitle.Font = Enum.Font.SourceSansBold
    presetTitle.TextSize = 14
    presetTitle.Parent = presetFrame
    
    -- Preset buttons
    local function createPresetButton(text, callback, x)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3, -5, 0, 35)
        btn.Position = UDim2.new(x, 0, 0, 40)
        btn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 12
        btn.Parent = presetFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        return btn
    end
    
    createPresetButton("🎯 Legit", function()
        SETTINGS.smoothness = 0.3
        SETTINGS.aimFov = 60
        SETTINGS.silentAimFOV = 90
        print("📱 Legit preset applied!")
    end, 0.02)
    
    createPresetButton("⚡ Rage", function()
        SETTINGS.smoothness = 0.8
        SETTINGS.aimFov = 120
        SETTINGS.silentAimFOV = 180
        print("📱 Rage preset applied!")
    end, 0.35)
    
    createPresetButton("🔧 Reset", function()
        SETTINGS.smoothness = 0.5
        SETTINGS.aimFov = 100
        SETTINGS.silentAimFOV = 130
        print("📱 Settings reset!")
    end, 0.68)
    
else
    -- PC: Full feature set
    createToggle("Aim Assist", false, 120)
    createToggle("Magic Bullet", false, 150)
    createToggle("Universal Silent Aim", false, 180)
    createToggle("ESP", true, 210)
    createToggle("Box ESP", true, 240)
    createToggle("Name ESP", true, 270)
    createToggle("Snap Lines", true, 300)
    createToggle("Health Bar", true, 330)
    createToggle("No Recoil", false, 360)
    createToggle("Silent Aim Team Check", false, 390)
    createToggle("Silent Aim Visible Check", false, 420)
    createToggle("Silent Aim Prediction", false, 450)
    createToggle("Smooth Silent Aim", true, 480)
    createToggle("Restore Mouse Position", true, 510)

    createDropdown("Trigger Key", keyOptions, "X", 540)
    createDropdown("Target Point", targetOptions, "Head", 610)
    createDropdown("Silent Aim Method", silentAimMethods, "Mouse.Hit/Target", 680)
    createDropdown("Silent Aim Target", silentAimTargets, "HumanoidRootPart", 750)

    createSlider("Smoothness", 0.1, 1, SETTINGS.smoothness, 820)
    createSlider("FOV", 30, 180, SETTINGS.aimFov, 890)
    createSlider("Max Distance", 100, 2000, SETTINGS.maxDistance, 960)
    createSlider("Silent Aim FOV", 30, 360, SETTINGS.silentAimFOV, 1030)
    createSlider("Silent Aim Hit Chance", 0, 100, SETTINGS.silentAimHitChance, 1100)
    createSlider("Silent Aim Smoothness", 0.1, 1, SETTINGS.silentAimSmoothness, 1170)
    createSlider("Silent Aim Prediction Amount", 0.1, 1, SETTINGS.silentAimPredictionAmount, 1240)
end

-- Test button
local testBtn = Instance.new("TextButton")
testBtn.Size = UDim2.new(0.9, 0, 0, isMobile and 50 or 35)
testBtn.Position = UDim2.new(0.05, 0, 1, isMobile and -140 or -130)
testBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
testBtn.Text = "🔧 TEST FUNCTIONS 🔧"
testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
testBtn.Font = Enum.Font.SourceSansBold
testBtn.TextSize = isMobile and 16 or 14
testBtn.Parent = MainFrame

testBtn.MouseButton1Click:Connect(function()
    testFunctions()
end)

-- Panic button
local panicBtn = Instance.new("TextButton")
panicBtn.Size = UDim2.new(0.9, 0, 0, isMobile and 50 or 35)
panicBtn.Position = UDim2.new(0.05, 0, 1, isMobile and -80 or -85)
panicBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
panicBtn.Text = "🚨 PANIC BUTTON 🚨"
panicBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
panicBtn.Font = Enum.Font.SourceSansBold
panicBtn.TextSize = isMobile and 16 or 14
panicBtn.Parent = MainFrame

panicBtn.MouseButton1Click:Connect(function()
    if ScreenGui then ScreenGui:Destroy() end
    if espFolder then espFolder:Destroy() end
    enabled = false
    SETTINGS.silentAim = false
    print("🚨 Script destroyed!")
end)

-- ESP Functions
local function createEspBox(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = SETTINGS.espColor
    box.Thickness = SETTINGS.espThickness
    box.Transparency = SETTINGS.espTransparency
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = SETTINGS.espColor
    tracer.Thickness = SETTINGS.espThickness
    tracer.Transparency = SETTINGS.espTransparency

    local name = Drawing.new("Text")
    name.Visible = false
    name.Color = SETTINGS.espColor
    name.Size = 16
    name.Center = true
    name.Outline = true

    local healthBar = Drawing.new("Square")
    healthBar.Visible = false
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = SETTINGS.espThickness
    healthBar.Filled = true

    local function updateEsp()
        if not SETTINGS.espEnabled then
            box.Visible = false
            tracer.Visible = false
            name.Visible = false
            healthBar.Visible = false
            return
        end

        if not isValidTargetAimAssist(player) then
            box.Visible = false
            tracer.Visible = false
            name.Visible = false
            healthBar.Visible = false
            return
        end

        local character = player.Character
        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        local head = character:FindFirstChild("Head")

        if not root or not humanoid or not head then return end

        local vector, onScreen = camera:WorldToViewportPoint(root.Position)
        if not onScreen then
            box.Visible = false
            tracer.Visible = false
            name.Visible = false
            healthBar.Visible = false
            return
        end

        -- Update Box ESP
        if SETTINGS.boxEsp then
            local size = Vector2.new(2000 / vector.Z, 3000 / vector.Z)
            box.Size = size
            box.Position = Vector2.new(vector.X - size.X / 2, vector.Y - size.Y / 2)
            box.Visible = true
        else
            box.Visible = false
        end

        -- Update Snap Lines
        if SETTINGS.snapLines then
            tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            tracer.To = Vector2.new(vector.X, vector.Y)
            tracer.Visible = true
        else
            tracer.Visible = false
        end

        -- Update Name ESP
        if SETTINGS.nameEsp then
            name.Position = Vector2.new(vector.X, vector.Y - 40)
            name.Text = player.Name
            name.Visible = true
        else
            name.Visible = false
        end

        -- Update Health Bar
        if SETTINGS.healthBar then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local barSize = Vector2.new(2, 3000 / vector.Z)
            healthBar.Size = Vector2.new(barSize.X, barSize.Y * healthPercent)
            healthBar.Position = Vector2.new(vector.X - 20, vector.Y - barSize.Y / 2)
            healthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
            healthBar.Visible = true
        else
            healthBar.Visible = false
        end
    end

    runService.RenderStepped:Connect(updateEsp)
end

-- Create ESP for all players
for _, player in ipairs(players:GetPlayers()) do
    if player ~= localPlayer then
        createEspBox(player)
    end
end

players.PlayerAdded:Connect(createEspBox)

-- Main loop
runService.RenderStepped:Connect(function()
    -- Update Aim Assist
    updateAim()
    
    -- Update No Recoil
    removeRecoil()
    
    -- Optimized Silent Aim for Mobile: Reduced lag version
    if SETTINGS.silentAim and alternativeHooks.mouseHook then
        local currentTime = tick()
        local isLeftClickPressed = userInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        
        -- Mobile optimization: Rate limiting
        if isMobile and (currentTime - lastSilentAimTime) < silentAimCooldown then
            return -- Skip this frame to reduce lag
        end
        
        if isLeftClickPressed and not silentAiming then
            -- Start silent aiming
            silentAiming = true
            lastSilentAimTime = currentTime
            
            if not isMobile then
                originalMousePos = getMousePosition()
            end
            
            local target = getClosestPlayerForSilentAim()
            if target and calculateChance(SETTINGS.silentAimHitChance) then
                local targetPos = target.Position
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
                
                if onScreen then
                    if isMobile then
                        -- Mobile: Instant movement only, no smoothing
                        if mousemoveabs then
                            mousemoveabs(screenPos.X, screenPos.Y)
                            print("🎯 Mobile Silent Aim - Target:", target.Parent.Name)
                        end
                    elseif SETTINGS.smoothSilentAim then
                        -- PC: Smooth movement 
                        spawn(function()
                            local startPos = originalMousePos
                            local endPos = Vector2.new(screenPos.X, screenPos.Y)
                            local smoothness = SETTINGS.silentAimSmoothness or 0.8
                            
                            for i = 0, 1, 0.2 do -- Reduced iterations for performance
                                if not userInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then break end
                                
                                local lerpPos = startPos:Lerp(endPos, i * smoothness)
                                
                                if mousemoveabs then
                                    mousemoveabs(lerpPos.X, lerpPos.Y)
                                end
                                
                                if isMobile then
                                    wait(0.02) -- Longer wait for mobile
                                else
                                    wait(0.001)
                                end
                            end
                            
                            -- Final position
                            if mousemoveabs then
                                mousemoveabs(endPos.X, endPos.Y)
                            end
                            
                            print("🎯 Smooth Silent Aim - Target:", target.Parent.Name)
                        end)
                    else
                        -- Instant movement
                        if mousemoveabs then
                            mousemoveabs(screenPos.X, screenPos.Y)
                            print("🎯 Instant Silent Aim - Target:", target.Parent.Name)
                        end
                    end
                end
            end
        elseif not isLeftClickPressed and silentAiming then
            -- Stop silent aiming
            silentAiming = false
            
            -- Only restore on PC, not mobile to reduce lag
            if not isMobile and SETTINGS.restoreMousePosition and mousemoveabs then
                spawn(function()
                    local currentPos = getMousePosition()
                    local targetPos = originalMousePos
                    
                    for i = 0, 1, 0.3 do -- Faster restoration
                        local lerpPos = currentPos:Lerp(targetPos, i)
                        mousemoveabs(lerpPos.X, lerpPos.Y)
                        wait(0.01)
                    end
                    
                    mousemoveabs(targetPos.X, targetPos.Y)
                end)
            end
        end
    end
    
    -- Debug: Print target info occasionally
    if SETTINGS.silentAim and math.random(1, 300) == 1 then -- Print every 5 seconds roughly
        local target = getClosestPlayerForSilentAim()
        if target then
            print("🎯 Silent Aim target available:", target.Parent.Name)
            if alternativeHooks.mouseHook then
                print("🎯 Using Mouse Simulation method")
            elseif alternativeHooks.directHook then
                print("🎯 Using Alternative Hook method")
            end
        end
    end
end)

print("✅ Universal Aim System loaded successfully!")
print("📋 Features: Aim Assist, Magic Bullet, Universal Silent Aim, ESP")
print("🎮 HOTKEYS:")
print("   🎯 Z = Toggle Silent Aim")
print("   🎯 HOME = Toggle Aim Assist") 
print("   👁️ END = Toggle ESP")
print("🔧 Use the TEST FUNCTIONS button to verify everything is working")
