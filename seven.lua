local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Configurações Globais
local Config = {
    Aimbot = { Enabled = false, Smoothness = 0.5, Prediction = 0.05, WallCheck = true, Part = "Head" },
    ESP = { Boxes = false, Tracers = false, Color = Color3.fromRGB(255, 50, 50) },
    FOV = { Visible = false, Radius = 150, Color = Color3.fromRGB(255, 50, 50) },
    TeamCheck = false
}

-- Cache e Garbage Collection
local ESP_Cache = {}
local FOV_Circle = Drawing.new("Circle")
FOV_Circle.Visible = false
FOV_Circle.Thickness = 1.5
FOV_Circle.NumSides = 60
FOV_Circle.Filled = false

-- Parâmetros de Raycast (Otimizado)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = true

local function UpdateRaycastFilter()
    local ignore = {LocalPlayer.Character, Camera}
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Transparency >= 0.5 or v.Name == "Glass" then
            table.insert(ignore, v)
        end
    end
    raycastParams.FilterDescendantsInstances = ignore
end

-- Gerenciamento de Memória ESP
local function CreateESP(player)
    local drawings = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        Tracer = Drawing.new("Line")
    }
    
    drawings.Box.Thickness = 1
    drawings.Box.Filled = false
    drawings.BoxOutline.Thickness = 3
    drawings.BoxOutline.Filled = false
    drawings.BoxOutline.Color = Color3.new(0,0,0)
    
    drawings.Tracer.Thickness = 1.5
    
    ESP_Cache[player] = drawings
end

local function RemoveESP(player)
    if ESP_Cache[player] then
        for _, drawing in pairs(ESP_Cache[player]) do drawing:Remove() end
        ESP_Cache[player] = nil
    end
end

Players.PlayerRemoving:Connect(RemoveESP)
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end
Players.PlayerAdded:Connect(function(p)
    CreateESP(p)
end)

-- WallCheck via Raycast (Nova API)
local function IsVisible(targetPart)
    if not Config.Aimbot.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * 1000
    
    UpdateRaycastFilter()
    local result = workspace:Raycast(origin, direction, raycastParams)
    
    if result and result.Instance then
        return result.Instance:IsDescendantOf(targetPart.Parent)
    end
    return true
end

-- Lógica de Mira
local function GetClosestTarget()
    local target, shortestFOV = nil, Config.FOV.Radius
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local character = player.Character
        if not character then continue end
        
        local targetPart = character:FindFirstChild(Config.Aimbot.Part)
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

-- Main Loop (RenderStepped)
RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- Atualiza FOV
    FOV_Circle.Position = screenCenter
    FOV_Circle.Radius = Config.FOV.Radius
    FOV_Circle.Color = Config.FOV.Color
    FOV_Circle.Visible = Config.FOV.Visible

    -- Atualiza ESP
    for player, drawings in pairs(ESP_Cache) do
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChild("Humanoid")
        
        local isAlive = character and head and hrp and hum and hum.Health > 0
        local onScreen = false
        local pos = Vector3.zero
        
        if isAlive then
            pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        end
        
        if isAlive and onScreen and (Config.ESP.Boxes or Config.ESP.Tracers) then
            local rootPos, rootVis = Camera:WorldToViewportPoint(hrp.Position)
            local headPos, headVis = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local legPos, legVis = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            
            if Config.ESP.Boxes then
                local height = math.abs(headPos.Y - legPos.Y)
                local width = height / 2
                
                drawings.BoxOutline.Size = Vector2.new(width, height)
                drawings.BoxOutline.Position = Vector2.new(rootPos.X - width / 2, rootPos.Y - height / 2)
                drawings.BoxOutline.Visible = true
                
                drawings.Box.Size = drawings.BoxOutline.Size
                drawings.Box.Position = drawings.BoxOutline.Position
                drawings.Box.Color = Config.ESP.Color
                drawings.Box.Visible = true
            else
                drawings.Box.Visible = false
                drawings.BoxOutline.Visible = false
            end
            
            if Config.ESP.Tracers then
                drawings.Tracer.From = Vector2.new(screenCenter.X, Camera.ViewportSize.Y)
                drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                drawings.Tracer.Color = Config.ESP.Color
                drawings.Tracer.Visible = true
            else
                drawings.Tracer.Visible = false
            end
        else
            drawings.Box.Visible = false
            drawings.BoxOutline.Visible = false
            drawings.Tracer.Visible = false
        end
    end

    -- Atualiza Aimbot
    if Config.Aimbot.Enabled then
        local target = GetClosestTarget()
        if target then
            -- Previsão de Movimento (Prediction)
            local targetVelocity = target.AssemblyLinearVelocity or Vector3.zero
            local predictedPos = target.Position + (targetVelocity * Config.Aimbot.Prediction)
            
            local targetCFrame = CFrame.new(Camera.CFrame.Position, predictedPos)
            -- Suavização (Lerp)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
        end
    end
end)

---------------------------------------------------------
-- UI MOBILE/PC FRIENDLY (SEM KEYBINDS)
---------------------------------------------------------
local UI = Instance.new("ScreenGui")
UI.Name = "N_Y_X_Universal"
UI.Parent = gethui and gethui() or game:GetService("CoreGui")
UI.ResetOnSpawn = false

-- Botão Flutuante (Mobile e PC)
local ToggleBtn = Instance.new("ImageButton", UI)
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Position = UDim2.new(0, 20, 0, 20)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
ToggleBtn.Image = "rbxassetid://6031091004" -- Ícone Vetorial de Escudo/Sistema
ToggleBtn.ImageColor3 = Color3.fromRGB(255, 50, 50)
ToggleBtn.Active = true
ToggleBtn.Draggable = true
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0.5, 0)
local ToggleStroke = Instance.new("UIStroke", ToggleBtn)
ToggleStroke.Color = Color3.fromRGB(255, 50, 50)
ToggleStroke.Thickness = 2

-- Painel Principal
local Main = Instance.new("Frame", UI)
Main.Size = UDim2.new(0, 320, 0, 350)
Main.Position = UDim2.new(0.5, -160, 0.5, -175)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
Main.Visible = false
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(255, 50, 50)
MainStroke.Thickness = 2

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = " EZ AIM - MOBILE/PC"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.BackgroundTransparency = 1

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -20, 1, -50)
Scroll.Position = UDim2.new(0, 10, 0, 40)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 2
Scroll.CanvasSize = UDim2.new(0, 0, 1.5, 0)
local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 5)

-- Função Base para Botões com Ícones
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
    
    local Status = Instance.new("TextLabel", btn)
    Status.Size = UDim2.new(0, 40, 1, 0)
    Status.Position = UDim2.new(1, -50, 0, 0)
    Status.BackgroundTransparency = 1
    Status.Text = "OFF"
    Status.Font = Enum.Font.GothamBold
    Status.TextColor3 = Color3.fromRGB(160, 160, 160)
    Status.TextSize = 12
    
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        Status.Text = state and "ON" or "OFF"
        Status.TextColor3 = state and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(160, 160, 160)
        callback(state)
    end)
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
            dragging = true
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

-- Interação da UI
ToggleBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

-- Adicionando Toggles (Com ícones Feather SVG convertidos para AssetID)
CreateToggle("Aimbot Mobile/PC", "rbxassetid://6031763426", function(s) Config.Aimbot.Enabled = s end) -- Mira
CreateToggle("Wall Check", "rbxassetid://6031265976", function(s) Config.Aimbot.WallCheck = s end) -- Escudo
CreateToggle("Visual Box ESP", "rbxassetid://6031201502", function(s) Config.ESP.Boxes = s end) -- Olho
CreateToggle("Tracers", "rbxassetid://6031201502", function(s) Config.ESP.Tracers = s end) -- Olho
CreateToggle("Show FOV", "rbxassetid://6031763426", function(s) Config.FOV.Visible = s end) -- Mira

-- Sliders para controle Granular (Crucial para Mobile)
CreateSlider("Aimbot Smoothness", 0.01, 1, 0.5, function(v) Config.Aimbot.Smoothness = v end)
CreateSlider("Aimbot Prediction", 0, 0.2, 0.05, function(v) Config.Aimbot.Prediction = v end)
CreateSlider("FOV Radius", 50, 500, 150, function(v) Config.FOV.Radius = v end)
