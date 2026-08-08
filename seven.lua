local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Configurações Globais
local Config = {
    Aimbot = { Enabled = false, Smoothness = 0.5, Prediction = 0.0, WallCheck = true, RandomHitbox = false },
    ESP = { Boxes = false, Tracers = false, Skeleton = false, HealthText = false, Color = Color3.fromRGB(255, 50, 50) },
    FOV = { Visible = false, Radius = 150, Color = Color3.fromRGB(255, 255, 255) },
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

-- Otimização Raycast
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

-- Cache de Desenhos (Drawing API)
local ESP_Cache = {}
local FOV_Circle = Drawing.new("Circle")
FOV_Circle.Thickness = 1.5
FOV_Circle.NumSides = 60
FOV_Circle.Filled = false

local function CreateESP(player)
    local drawings = {
        Box = Drawing.new("Square"), BoxOutline = Drawing.new("Square"),
        Tracer = Drawing.new("Line"), Health = Drawing.new("Text"),
        Skeleton = {}
    }
    drawings.Box.Thickness = 1; drawings.Box.Filled = false
    drawings.BoxOutline.Thickness = 3; drawings.BoxOutline.Filled = false; drawings.BoxOutline.Color = Color3.new(0,0,0)
    drawings.Tracer.Thickness = 1.5
    drawings.Health.Size = 15; drawings.Health.Center = true; drawings.Health.Outline = true; drawings.Health.Color = Color3.new(1,1,1)

    for i = 1, #SkeletonConnections do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        table.insert(drawings.Skeleton, line)
    end
    ESP_Cache[player] = drawings
end

local function RemoveESP(player)
    if ESP_Cache[player] then
        for k, d in pairs(ESP_Cache[player]) do 
            if k == "Skeleton" then for _, l in pairs(d) do l:Remove() end else d:Remove() end
        end
        ESP_Cache[player] = nil
    end
end

Players.PlayerRemoving:Connect(RemoveESP)
for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then CreateESP(p) end end
Players.PlayerAdded:Connect(CreateESP)

local function IsVisible(targetPart)
    if not Config.Aimbot.WallCheck then return true end
    UpdateRaycastFilter()
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, (targetPart.Position - origin).Unit * 2000, raycastParams)
    return result and result.Instance:IsDescendantOf(targetPart.Parent) or false
end

local function GetClosestTarget()
    local target, shortestFOV = nil, Config.FOV.Radius
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    CurrentHitbox = Config.Aimbot.RandomHitbox and Hitboxes[math.random(1, #Hitboxes)] or "Head"

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or (Config.TeamCheck and player.Team == LocalPlayer.Team) then continue end
        local char = player.Character
        if not char then continue end
        
        local targetPart = char:FindFirstChild(CurrentHitbox) or char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
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

-- Loop Principal RenderStepped (Sincronizado perfeitamente com a Câmera)
RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    FOV_Circle.Position = screenCenter
    FOV_Circle.Radius = Config.FOV.Radius
    FOV_Circle.Color = Config.FOV.Color
    FOV_Circle.Visible = Config.FOV.Visible

    for player, drawings in pairs(ESP_Cache) do
        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        local isAlive = char and head and hrp and hum and hum.Health > 0
        
        if isAlive then
            local rootPos, rootVis = Camera:WorldToViewportPoint(hrp.Position)
            local headPos, headVis = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local legPos, legVis = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            
            if rootVis or headVis then
                if Config.ESP.Boxes then
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 1.8
                    drawings.BoxOutline.Size = Vector2.new(width, height)
                    drawings.BoxOutline.Position = Vector2.new(rootPos.X - width / 2, rootPos.Y - height / 2)
                    drawings.BoxOutline.Visible = true
                    drawings.Box.Size = drawings.BoxOutline.Size; drawings.Box.Position = drawings.BoxOutline.Position
                    drawings.Box.Color = Config.ESP.Color; drawings.Box.Visible = true
                else
                    drawings.Box.Visible = false; drawings.BoxOutline.Visible = false
                end
                
                if Config.ESP.HealthText then
                    drawings.Health.Text = tostring(math.floor(hum.Health)) .. "%"
                    drawings.Health.Position = Vector2.new(rootPos.X, rootPos.Y + (math.abs(headPos.Y - legPos.Y) / 2) + 5)
                    drawings.Health.Visible = true
                else
                    drawings.Health.Visible = false
                end

                if Config.ESP.Tracers then
                    drawings.Tracer.From = Vector2.new(screenCenter.X, Camera.ViewportSize.Y)
                    drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                    drawings.Tracer.Color = Config.ESP.Color; drawings.Tracer.Visible = true
                else
                    drawings.Tracer.Visible = false
                end

                -- Esqueleto com correção de profundidade (Evita bugar na tela)
                if Config.ESP.Skeleton then
                    for i, conn in ipairs(SkeletonConnections) do
                        local p1, p2 = char:FindFirstChild(conn[1]), char:FindFirstChild(conn[2])
                        if p1 and p2 then
                            local pos1, vis1 = Camera:WorldToViewportPoint(p1.Position)
                            local pos2, vis2 = Camera:WorldToViewportPoint(p2.Position)
                            -- Checa se ambas as partes têm profundidade positiva (Z > 0)
                            if vis1 and vis2 and pos1.Z > 0 and pos2.Z > 0 then
                                drawings.Skeleton[i].From = Vector2.new(pos1.X, pos1.Y)
                                drawings.Skeleton[i].To = Vector2.new(pos2.X, pos2.Y)
                                drawings.Skeleton[i].Color = Config.ESP.Color
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
            drawings.Box.Visible = false; drawings.BoxOutline.Visible = false
            drawings.Tracer.Visible = false; drawings.Health.Visible = false
            for _, line in pairs(drawings.Skeleton) do line.Visible = false end
        end
    end

    -- Aimbot 100% Liso (Wobble Fixado)
    if Config.Aimbot.Enabled then
        local target = GetClosestTarget()
        if target then
            local targetPos = target.Position
            -- Predição limitada para não absorver spikes lagados da engine
            if Config.Aimbot.Prediction > 0 then
                local vel = target.AssemblyLinearVelocity or Vector3.zero
                if vel.Magnitude > 150 then vel = vel.Unit * 150 end -- Clamp
                targetPos = targetPos + (vel * Config.Aimbot.Prediction)
            end
            local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
        end
    end
end)

---------------------------------------------------------
-- INTERFACE GRÁFICA (UI COM BOTÃO FLUTUANTE)
---------------------------------------------------------
local UI = Instance.new("ScreenGui")
UI.Name = "N_Y_X_Universal"
UI.Parent = gethui and gethui() or game:GetService("CoreGui")

-- Botão Flutuante (EZ)
local FloatingBtn = Instance.new("Frame", UI)
FloatingBtn.Size = UDim2.new(0, 45, 0, 45)
FloatingBtn.Position = UDim2.new(0, 20, 0, 20)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
FloatingBtn.Active = true
FloatingBtn.Draggable = true
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(0.5, 0)
local FloatStroke = Instance.new("UIStroke", FloatingBtn)
FloatStroke.Color = Color3.fromRGB(255, 50, 50)
FloatStroke.Thickness = 2
local FloatClick = Instance.new("TextButton", FloatingBtn)
FloatClick.Size = UDim2.new(1,0,1,0); FloatClick.BackgroundTransparency = 1
FloatClick.Text = "EZ"; FloatClick.Font = Enum.Font.GothamBold; FloatClick.TextColor3 = Color3.fromRGB(255, 50, 50)
FloatClick.TextSize = 16

-- Painel Principal (Inicia Oculto)
local Main = Instance.new("Frame", UI)
Main.Size = UDim2.new(0, 340, 0, 420)
local HiddenPos = UDim2.new(0.5, -170, 1.2, 0)
local VisiblePos = UDim2.new(0.5, -170, 0.5, -210)
Main.Position = HiddenPos
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
Main.Visible = false
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(255, 50, 50)
MainStroke.Thickness = 2

-- Lógica de Abrir/Fechar
FloatClick.MouseButton1Click:Connect(function()
    Main.Visible = true; FloatingBtn.Visible = false
    Main:TweenPosition(VisiblePos, "Out", "Quart", 0.4, true)
end)

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -40, 0, 40)
Title.Text = " EZ AIM - ADVANCED"
Title.Font = Enum.Font.GothamBold; Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255, 50, 50); Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", Main)
CloseBtn.Size = UDim2.new(0, 40, 0, 40)
CloseBtn.Position = UDim2.new(1, -40, 0, 0)
CloseBtn.BackgroundTransparency = 1; CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
CloseBtn.TextSize = 18
CloseBtn.MouseButton1Click:Connect(function()
    Main:TweenPosition(HiddenPos, "In", "Quart", 0.4, true, function()
        Main.Visible = false; FloatingBtn.Visible = true
    end)
end)

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -20, 1, -50); Scroll.Position = UDim2.new(0, 10, 0, 40)
Scroll.BackgroundTransparency = 1; Scroll.ScrollBarThickness = 2
Scroll.CanvasSize = UDim2.new(0, 0, 3.2, 0) -- Aumentado pra caber os pickers
local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 5)

-- Componentes Base
local function CreateToggle(name, iconId, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 35); btn.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
    btn.Text = ""; Instance.new("UICorner", btn)
    local Icon = Instance.new("ImageLabel", btn)
    Icon.Size = UDim2.new(0, 20, 0, 20); Icon.Position = UDim2.new(0, 10, 0.5, -10)
    Icon.BackgroundTransparency = 1; Icon.Image = iconId; Icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    local Label = Instance.new("TextLabel", btn)
    Label.Size = UDim2.new(1, -50, 1, 0); Label.Position = UDim2.new(0, 40, 0, 0)
    Label.BackgroundTransparency = 1; Label.Text = name; Label.Font = Enum.Font.GothamBold
    Label.TextColor3 = Color3.fromRGB(255, 50, 50); Label.TextSize = 14; Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        Label.TextColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(255, 50, 50)
        callback(state)
    end)
    return function(v) state = v; Label.TextColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(255, 50, 50); callback(state) end
end

local function CreateSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame", Scroll)
    frame.Size = UDim2.new(1, 0, 0, 45); frame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
    Instance.new("UICorner", frame)
    local Label = Instance.new("TextLabel", frame)
    Label.Size = UDim2.new(1, -10, 0, 20); Label.Position = UDim2.new(0, 10, 0, 5)
    Label.BackgroundTransparency = 1; Label.Text = name .. ": " .. tostring(default)
    Label.Font = Enum.Font.GothamBold; Label.TextColor3 = Color3.fromRGB(255, 50, 50)
    Label.TextSize = 12; Label.TextXAlignment = Enum.TextXAlignment.Left
    local Bar = Instance.new("TextButton", frame)
    Bar.Size = UDim2.new(1, -20, 0, 10); Bar.Position = UDim2.new(0, 10, 0, 25)
    Bar.BackgroundColor3 = Color3.fromRGB(15, 15, 17); Bar.Text = ""; Instance.new("UICorner", Bar)
    local Fill = Instance.new("Frame", Bar)
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0); Fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    Instance.new("UICorner", Fill)
    
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos * 100) / 100
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        Label.Text = name .. ": " .. tostring(value)
        callback(value)
    end
    Bar.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = true; update(inp) end end)
    UserInputService.InputEnded:Connect(function(inp) dragging = false end)
    UserInputService.InputChanged:Connect(function(inp) if dragging then update(inp) end end)
end

-- RGB Color Picker Avançado
local function CreateColorPicker(name, iconId, configRef, configKey)
    local frame = Instance.new("Frame", Scroll)
    frame.Size = UDim2.new(1, 0, 0, 100); frame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
    Instance.new("UICorner", frame)
    
    local Icon = Instance.new("ImageLabel", frame)
    Icon.Size = UDim2.new(0, 20, 0, 20); Icon.Position = UDim2.new(0, 10, 0, 10)
    Icon.BackgroundTransparency = 1; Icon.Image = iconId; Icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    
    local Label = Instance.new("TextLabel", frame)
    Label.Size = UDim2.new(1, -50, 0, 20); Label.Position = UDim2.new(0, 40, 0, 10)
    Label.BackgroundTransparency = 1; Label.Text = name
    Label.Font = Enum.Font.GothamBold; Label.TextColor3 = Color3.fromRGB(255, 50, 50)
    Label.TextSize = 14; Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local Preview = Instance.new("Frame", frame)
    Preview.Size = UDim2.new(0, 20, 0, 20); Preview.Position = UDim2.new(1, -30, 0, 10)
    Preview.BackgroundColor3 = configRef[configKey]; Instance.new("UICorner", Preview)
    
    local r, g, b = configRef[configKey].R * 255, configRef[configKey].G * 255, configRef[configKey].B * 255

    local function MakeColorSlider(yPos, colorName, barColor, startVal, updateCallback)
        local Bar = Instance.new("TextButton", frame)
        Bar.Size = UDim2.new(1, -20, 0, 10); Bar.Position = UDim2.new(0, 10, 0, yPos)
        Bar.BackgroundColor3 = Color3.fromRGB(15, 15, 17); Bar.Text = ""; Instance.new("UICorner", Bar)
        local Fill = Instance.new("Frame", Bar)
        Fill.Size = UDim2.new(startVal/255, 0, 1, 0); Fill.BackgroundColor3 = barColor; Instance.new("UICorner", Fill)
        
        local dragging = false
        Bar.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = true end end)
        UserInputService.InputEnded:Connect(function(inp) dragging = false end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                local pos = math.clamp((inp.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                Fill.Size = UDim2.new(pos, 0, 1, 0)
                updateCallback(pos * 255)
            end
        end)
    end
    
    local function UpdateGlobalColor()
        local newColor = Color3.fromRGB(r, g, b)
        Preview.BackgroundColor3 = newColor
        configRef[configKey] = newColor
    end

    MakeColorSlider(40, "R", Color3.fromRGB(255, 50, 50), r, function(val) r = val; UpdateGlobalColor() end)
    MakeColorSlider(60, "G", Color3.fromRGB(50, 255, 50), g, function(val) g = val; UpdateGlobalColor() end)
    MakeColorSlider(80, "B", Color3.fromRGB(50, 50, 255), b, function(val) b = val; UpdateGlobalColor() end)
end

local function CreateActionBtn(name, iconId, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 35); btn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
    btn.Text = ""; Instance.new("UICorner", btn)
    local Icon = Instance.new("ImageLabel", btn)
    Icon.Size = UDim2.new(0, 20, 0, 20); Icon.Position = UDim2.new(0, 10, 0.5, -10)
    Icon.BackgroundTransparency = 1; Icon.Image = iconId; Icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    local Label = Instance.new("TextLabel", btn)
    Label.Size = UDim2.new(1, -50, 1, 0); Label.Position = UDim2.new(0, 40, 0, 0)
    Label.BackgroundTransparency = 1; Label.Text = name; Label.Font = Enum.Font.GothamBold
    Label.TextColor3 = Color3.fromRGB(255, 50, 50); Label.TextSize = 14; Label.TextXAlignment = Enum.TextXAlignment.Left
    btn.MouseButton1Click:Connect(callback)
end

-- ================= CONSTRUÇÃO DA UI =================
-- Toggles (Todos com Ícones)
local T_Aim = CreateToggle("Aimbot Master", "rbxassetid://6031763426", function(s) Config.Aimbot.Enabled = s end)
local T_Wall = CreateToggle("Wall Check Strict", "rbxassetid://6031265976", function(s) Config.Aimbot.WallCheck = s end)
local T_Rand = CreateToggle("Randomize Target Bone", "rbxassetid://6031068433", function(s) Config.Aimbot.RandomHitbox = s end)
CreateSlider("Aimbot Smoothness", 0.01, 1, 0.5, function(v) Config.Aimbot.Smoothness = v end)
CreateSlider("Aimbot Prediction", 0, 0.2, 0.0, function(v) Config.Aimbot.Prediction = v end)

local T_FOV = CreateToggle("Draw FOV Circle", "rbxassetid://6031232211", function(s) Config.FOV.Visible = s end)
CreateSlider("FOV Radius", 50, 500, 150, function(v) Config.FOV.Radius = v end)

local T_Box = CreateToggle("Box ESP", "rbxassetid://6031201502", function(s) Config.ESP.Boxes = s end)
local T_Skel = CreateToggle("Skeleton ESP", "rbxassetid://6031932273", function(s) Config.ESP.Skeleton = s end)
local T_Tracer = CreateToggle("Tracers", "rbxassetid://6031302821", function(s) Config.ESP.Tracers = s end)
local T_Health = CreateToggle("Health Value", "rbxassetid://6031094359", function(s) Config.ESP.HealthText = s end)

-- Color Pickers Reais
CreateColorPicker("ESP RGB Color", "rbxassetid://6031072946", Config.ESP, "Color")
CreateColorPicker("FOV RGB Color", "rbxassetid://6031072946", Config.FOV, "Color")

-- Save / Load System
local ConfigName = "N_Y_X_Config_V2.json"
CreateActionBtn("Save Config", "rbxassetid://6031280882", function()
    if writefile then
        -- Converte as cores para hex antes de salvar no json
        local saveCfg = {
            Aimbot = Config.Aimbot,
            FOV = {Visible = Config.FOV.Visible, Radius = Config.FOV.Radius},
            ESP = {Boxes = Config.ESP.Boxes, Tracers = Config.ESP.Tracers, Skeleton = Config.ESP.Skeleton, HealthText = Config.ESP.HealthText}
        }
        writefile(ConfigName, HttpService:JSONEncode(saveCfg))
    end
end)
CreateActionBtn("Load Config", "rbxassetid://6031236746", function()
    if readfile and isfile and isfile(ConfigName) then
        local saved = HttpService:JSONDecode(readfile(ConfigName))
        if saved then 
            Config.Aimbot = saved.Aimbot
            Config.FOV.Visible = saved.FOV.Visible
            Config.FOV.Radius = saved.FOV.Radius
            Config.ESP.Boxes = saved.ESP.Boxes
            Config.ESP.Tracers = saved.ESP.Tracers
            Config.ESP.Skeleton = saved.ESP.Skeleton
            Config.ESP.HealthText = saved.ESP.HealthText
            
            -- Sync UI Toggles
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
