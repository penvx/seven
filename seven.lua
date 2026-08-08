local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Paleta de Cores para o Usuário
local ColorPalette = {
    Color3.fromRGB(255, 50, 50),   -- Vermelho
    Color3.fromRGB(50, 255, 50),   -- Verde
    Color3.fromRGB(50, 150, 255),  -- Azul
    Color3.fromRGB(255, 50, 255),  -- Rosa
    Color3.fromRGB(255, 255, 255), -- Branco
    Color3.fromRGB(255, 255, 50)   -- Amarelo
}

-- Configurações Globais
local Config = {
    Aimbot = { Enabled = false, Smoothness = 0.5, Prediction = 0.05, WallCheck = true, RandomHitbox = false },
    ESP = { Boxes = false, Tracers = false, Skeleton = false, HealthText = false, ColorIndex = 1 },
    FOV = { Visible = false, Radius = 150, ColorIndex = 1 },
    TeamCheck = false
}

local Hitboxes = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"}
local CurrentHitbox = "Head"

-- Conexões R15 e R6 para o Esqueleto
local SkeletonConnections = {
    -- R15
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    -- R6
    {"Head", "Torso"}, {"Torso", "Right Arm"}, {"Torso", "Left Arm"}, {"Torso", "Right Leg"}, {"Torso", "Left Leg"}
}

-- Cache de Desenhos
local ESP_Cache = {}
local FOV_Circle = Drawing.new("Circle")
FOV_Circle.Thickness = 1.5
FOV_Circle.NumSides = 60
FOV_Circle.Filled = false

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function UpdateRaycastFilter()
    local ignore = {LocalPlayer.Character, Camera}
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Transparency >= 0.5 or v.Name == "Glass") then
            table.insert(ignore, v)
        end
    end
    raycastParams.FilterDescendantsInstances = ignore
end

local function CreateESP(player)
    local drawings = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        Health = Drawing.new("Text"),
        Skeleton = {}
    }
    
    drawings.Box.Thickness = 1
    drawings.Box.Filled = false
    drawings.BoxOutline.Thickness = 3
    drawings.BoxOutline.Filled = false
    drawings.BoxOutline.Color = Color3.new(0,0,0)
    
    drawings.Tracer.Thickness = 1.5
    
    drawings.Health.Size = 16
    drawings.Health.Center = true
    drawings.Health.Outline = true
    drawings.Health.Color = Color3.new(1,1,1)

    for i = 1, #SkeletonConnections do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        table.insert(drawings.Skeleton, line)
    end
    
    ESP_Cache[player] = drawings
end

local function RemoveESP(player)
    if ESP_Cache[player] then
        for k, drawing in pairs(ESP_Cache[player]) do 
            if k == "Skeleton" then
                for _, line in pairs(drawing) do line:Remove() end
            else
                drawing:Remove() 
            end
        end
        ESP_Cache[player] = nil
    end
end

Players.PlayerRemoving:Connect(RemoveESP)
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end
Players.PlayerAdded:Connect(CreateESP)

local function IsVisible(targetPart)
    if not Config.Aimbot.WallCheck then return true end
    local origin = Camera.CFrame.Position
    UpdateRaycastFilter()
    local result = workspace:Raycast(origin, (targetPart.Position - origin).Unit * 1000, raycastParams)
    return result and result.Instance:IsDescendantOf(targetPart.Parent) or false
end

local function GetClosestTarget()
    local target, shortestFOV = nil, Config.FOV.Radius
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- Randomização de Hitbox (Garante imprecisão humana)
    if Config.Aimbot.RandomHitbox then
        CurrentHitbox = Hitboxes[math.random(1, #Hitboxes)]
    else
        CurrentHitbox = "Head"
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or (Config.TeamCheck and player.Team == LocalPlayer.Team) then continue end
        local character = player.Character
        if not character then continue end
        
        local targetPart = character:FindFirstChild(CurrentHitbox) or character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        
        if targetPart and humanoid and humanoid.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen and IsVisible(targetPart) then
                local mag = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                if mag < shortestFOV then
                    target = targetPart
                    shortestFOV = mag
                end
            end
        end
    end
    return target
end

-- Renderização Otimizada (RenderStepped para evitar lag de ESP)
RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local espColor = ColorPalette[Config.ESP.ColorIndex]
    
    FOV_Circle.Position = screenCenter
    FOV_Circle.Radius = Config.FOV.Radius
    FOV_Circle.Color = ColorPalette[Config.FOV.ColorIndex]
    FOV_Circle.Visible = Config.FOV.Visible

    for player, drawings in pairs(ESP_Cache) do
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChild("Humanoid")
        
        local isAlive = character and head and hrp and hum and hum.Health > 0
        
        if isAlive then
            local rootPos, rootVis = Camera:WorldToViewportPoint(hrp.Position)
            local headPos, headVis = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local legPos, legVis = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            
            if rootVis or headVis then
                -- Box ESP (Calculado no mesmo frame da câmera para não ter lag)
                if Config.ESP.Boxes then
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 1.8
                    
                    drawings.BoxOutline.Size = Vector2.new(width, height)
                    drawings.BoxOutline.Position = Vector2.new(rootPos.X - width / 2, rootPos.Y - height / 2)
                    drawings.BoxOutline.Visible = true
                    
                    drawings.Box.Size = drawings.BoxOutline.Size
                    drawings.Box.Position = drawings.BoxOutline.Position
                    drawings.Box.Color = espColor
                    drawings.Box.Visible = true
                else
                    drawings.Box.Visible = false
                    drawings.BoxOutline.Visible = false
                end
                
                -- Vida % em Texto
                if Config.ESP.HealthText then
                    local height = math.abs(headPos.Y - legPos.Y)
                    drawings.Health.Text = string.format("Life: %d%%", math.floor((hum.Health / hum.MaxHealth) * 100))
                    drawings.Health.Position = Vector2.new(rootPos.X, rootPos.Y + (height / 2) + 5)
                    drawings.Health.Visible = true
                else
                    drawings.Health.Visible = false
                end

                -- Tracers
                if Config.ESP.Tracers then
                    drawings.Tracer.From = Vector2.new(screenCenter.X, Camera.ViewportSize.Y)
                    drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                    drawings.Tracer.Color = espColor
                    drawings.Tracer.Visible = true
                else
                    drawings.Tracer.Visible = false
                end

                -- Skeleton ESP
                if Config.ESP.Skeleton then
                    for i, connection in ipairs(SkeletonConnections) do
                        local part1 = character:FindFirstChild(connection[1])
                        local part2 = character:FindFirstChild(connection[2])
                        if part1 and part2 then
                            local p1, v1 = Camera:WorldToViewportPoint(part1.Position)
                            local p2, v2 = Camera:WorldToViewportPoint(part2.Position)
                            if v1 or v2 then
                                drawings.Skeleton[i].From = Vector2.new(p1.X, p1.Y)
                                drawings.Skeleton[i].To = Vector2.new(p2.X, p2.Y)
                                drawings.Skeleton[i].Color = espColor
                                drawings.Skeleton[i].Visible = true
                            else
                                drawings.Skeleton[i].Visible = false
                            end
                        else
                            drawings.Skeleton[i].Visible = false
                        end
                    end
                else
                    for _, line in pairs(drawings.Skeleton) do line.Visible = false end
                end
            end
        else
            drawings.Box.Visible = false
            drawings.BoxOutline.Visible = false
            drawings.Tracer.Visible = false
            drawings.Health.Visible = false
            for _, line in pairs(drawings.Skeleton) do line.Visible = false end
        end
    end

    -- Aimbot Otimizado (Correção de Wobble)
    if Config.Aimbot.Enabled then
        local target = GetClosestTarget()
        if target then
            -- Previsão suavizada para evitar que a mira trema
            local velocity = target.AssemblyLinearVelocity or Vector3.zero
            local predictedPos = target.Position + (velocity * Config.Aimbot.Prediction)
            local lookVector = (predictedPos - Camera.CFrame.Position).Unit
            
            local targetCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + lookVector)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
        end
    end
end)

---------------------------------------------------------
-- UI CONFIGURAÇÃO (SAVE/LOAD & ÍCONES)
---------------------------------------------------------
local UI = Instance.new("ScreenGui")
UI.Name = "N_Y_X_Universal"
UI.Parent = gethui and gethui() or game:GetService("CoreGui")

local Main = Instance.new("Frame", UI)
Main.Size = UDim2.new(0, 340, 0, 420)
Main.Position = UDim2.new(0.5, -170, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(255, 50, 50)
MainStroke.Thickness = 2

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = " EZ AIM - ADVANCED"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.BackgroundTransparency = 1

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -20, 1, -50)
Scroll.Position = UDim2.new(0, 10, 0, 40)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 2
Scroll.CanvasSize = UDim2.new(0, 0, 2.5, 0)
local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 5)

-- Componentes da UI
local function CreateToggle(name, iconId, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
    btn.Text = ""
    Instance.new("UICorner", btn)
    
    local Icon = Instance.new("ImageLabel", btn)
    Icon.Size = UDim2.new(0, 20, 0, 20)
    Icon.Position = UDim2.new(0, 10, 0.5, -10)
    Icon.BackgroundTransparency = 1
    Icon.Image = iconId
    Icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    
    local Label = Instance.new("TextLabel", btn)
    Label.Size = UDim2.new(1, -50, 1, 0)
    Label.Position = UDim2.new(0, 40, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.Font = Enum.Font.GothamBold
    Label.TextColor3 = Color3.fromRGB(255, 50, 50)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        Label.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 50, 50)
        callback(state)
    end)
    return function(v) state = v; Label.TextColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(255, 50, 50); callback(state) end
end

local function CreateActionBtn(name, iconId, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
    btn.Text = ""
    Instance.new("UICorner", btn)
    
    local Icon = Instance.new("ImageLabel", btn)
    Icon.Size = UDim2.new(0, 20, 0, 20)
    Icon.Position = UDim2.new(0, 10, 0.5, -10)
    Icon.BackgroundTransparency = 1
    Icon.Image = iconId
    Icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    
    local Label = Instance.new("TextLabel", btn)
    Label.Size = UDim2.new(1, -50, 1, 0)
    Label.Position = UDim2.new(0, 40, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.Font = Enum.Font.GothamBold
    Label.TextColor3 = Color3.fromRGB(255, 50, 50)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    btn.MouseButton1Click:Connect(callback)
end

local function CreateSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame", Scroll)
    frame.Size = UDim2.new(1, 0, 0, 45)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
    Instance.new("UICorner", frame)
    
    local Label = Instance.new("TextLabel", frame)
    Label.Size = UDim2.new(1, -10, 0, 20)
    Label.Position = UDim2.new(0, 10, 0, 5)
    Label.BackgroundTransparency = 1
    Label.Text = name .. ": " .. tostring(default)
    Label.Font = Enum.Font.GothamBold
    Label.TextColor3 = Color3.fromRGB(255, 50, 50)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local Bar = Instance.new("TextButton", frame)
    Bar.Size = UDim2.new(1, -20, 0, 10)
    Bar.Position = UDim2.new(0, 10, 0, 25)
    Bar.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
    Bar.Text = ""
    Instance.new("UICorner", Bar)
    
    local Fill = Instance.new("Frame", Bar)
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    Instance.new("UICorner", Fill)
    
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos * 100) / 100
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        Label.Text = name .. ": " .. tostring(value)
        callback(value)
    end
    
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input) dragging = false end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging then update(input) end
    end)
end

-- Toggles de Aimbot
local T_Aim = CreateToggle("Aimbot Mobile/PC", "rbxassetid://6031763426", function(s) Config.Aimbot.Enabled = s end)
local T_Wall = CreateToggle("Wall Check", "rbxassetid://6031265976", function(s) Config.Aimbot.WallCheck = s end)
local T_Rand = CreateToggle("Randomize Hitbox", "rbxassetid://6031068433", function(s) Config.Aimbot.RandomHitbox = s end)
CreateSlider("Aimbot Smoothness", 0.01, 1, 0.5, function(v) Config.Aimbot.Smoothness = v end)
CreateSlider("Aimbot Prediction", 0, 0.2, 0.05, function(v) Config.Aimbot.Prediction = v end)

-- Toggles de Visuals
local T_FOV = CreateToggle("Show FOV", "rbxassetid://6031763426", function(s) Config.FOV.Visible = s end)
CreateSlider("FOV Radius", 50, 500, 150, function(v) Config.FOV.Radius = v end)
local T_Box = CreateToggle("Visual Box ESP", "rbxassetid://6031201502", function(s) Config.ESP.Boxes = s end)
local T_Skel = CreateToggle("Skeleton ESP", "rbxassetid://6031932273", function(s) Config.ESP.Skeleton = s end)
local T_Tracer = CreateToggle("Tracers", "rbxassetid://6031201502", function(s) Config.ESP.Tracers = s end)
local T_Health = CreateToggle("Health Text ESP", "rbxassetid://6031094359", function(s) Config.ESP.HealthText = s end)

-- Configuração de Cores
CreateActionBtn("Change ESP Color", "rbxassetid://6031072946", function()
    Config.ESP.ColorIndex = Config.ESP.ColorIndex >= #ColorPalette and 1 or Config.ESP.ColorIndex + 1
end)
CreateActionBtn("Change FOV Color", "rbxassetid://6031072946", function()
    Config.FOV.ColorIndex = Config.FOV.ColorIndex >= #ColorPalette and 1 or Config.FOV.ColorIndex + 1
end)

-- Sistema de Save/Load
local ConfigName = "N_Y_X_Config.json"
CreateActionBtn("Save Config", "rbxassetid://6031280882", function()
    if writefile then writefile(ConfigName, HttpService:JSONEncode(Config)) end
end)
CreateActionBtn("Load Config", "rbxassetid://6031236746", function()
    if readfile and isfile and isfile(ConfigName) then
        local saved = HttpService:JSONDecode(readfile(ConfigName))
        if saved then 
            Config = saved
            -- Sincroniza a UI (somente Toggles suportam atualização visual rápida aqui)
            T_Aim(Config.Aimbot.Enabled)
            T_Wall(Config.Aimbot.WallCheck)
            T_Rand(Config.Aimbot.RandomHitbox)
            T_FOV(Config.FOV.Visible)
            T_Box(Config.ESP.Boxes)
            T_Skel(Config.ESP.Skeleton)
            T_Tracer(Config.ESP.Tracers)
            T_Health(Config.ESP.HealthText)
        end
    end
end)
