local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Configurações Globais
local Config = {
    Aimbot = { Enabled = false, Smoothness = 1, Prediction = 0.0, WallCheck = true, RandomHitbox = false },
    ESP = { Boxes = false, Tracers = false, Skeleton = false, HealthText = false, Color = Color3.fromRGB(255, 50, 50) }, 
    FOV = { Visible = false, Radius = 150, Color = Color3.fromRGB(255, 255, 255) },
    TeamCheck = false
}

local Hitboxes = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"}
local CurrentHitbox = "Head"

local Skeletons = {
    R15 = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}
    },
    R6 = {
        {"Head", "Torso"}, {"Torso", "Right Arm"}, {"Torso", "Left Arm"}, {"Torso", "Right Leg"}, {"Torso", "Left Leg"}
    }
}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
local IgnoreCache = {}

-- Atualiza o filtro de vidro/partes invisíveis a cada 2 segundos (não pesa nada)
task.spawn(function()
    while task.wait(2) do
        if not LocalPlayer.Character then continue end
        local ignore = {LocalPlayer.Character, Camera}
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and (v.Transparency >= 0.5 or v.Name == "Glass") then
                table.insert(ignore, v)
            end
        end
        IgnoreCache = ignore
        raycastParams.FilterDescendantsInstances = IgnoreCache
    end
end)

local function IsVisible(targetPart)
    if not Config.Aimbot.WallCheck or not LocalPlayer.Character then return true end
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, (targetPart.Position - origin).Unit * 2000, raycastParams)
    return result and result.Instance:IsDescendantOf(targetPart.Parent) or false
end

local function GetClosestTarget()
    if not LocalPlayer.Character then return nil end
    local target, shortestFOV = nil, Config.FOV.Radius
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    CurrentHitbox = Config.Aimbot.RandomHitbox and Hitboxes[math.random(1, #Hitboxes)] or "Head"

    local potentialTargets = {}

    -- PASSO 1: Acha quem tá no FOV primeiro (Custo de CPU quase zero)
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or (Config.TeamCheck and player.Team == LocalPlayer.Team) then continue end
        local char = player.Character
        if not char then continue end
        
        local targetPart = char:FindFirstChild(CurrentHitbox) or char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
        if targetPart and humanoid and humanoid.Health > 0 then
            local pos, vis, z = GetScreenPos(targetPart.Position)
            if vis and z > 0 then
                local mag = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                if mag < shortestFOV then
                    table.insert(potentialTargets, {part = targetPart, dist = mag})
                end
            end
        end
    end

    -- Ordena pela distância da mira
    table.sort(potentialTargets, function(a, b) return a.dist < b.dist end)

    -- PASSO 2: Raycast APENAS no alvo mais próximo. Evita spam de Raycast por frame.
    for _, data in ipairs(potentialTargets) do
        if IsVisible(data.part) then
            return data.part
        end
    end
    return nil
end


local ESP_Cache = {}
local FOV_Circle = Drawing.new("Circle")
FOV_Circle.Thickness = 1.5; FOV_Circle.NumSides = 60; FOV_Circle.Filled = false

local function CreateESP(player)
    local drawings = {
        Box = Drawing.new("Square"), BoxOutline = Drawing.new("Square"),
        Tracer = Drawing.new("Line"), Health = Drawing.new("Text"),
        Skeleton = {}
    }
    drawings.Box.Thickness = 1; drawings.Box.Filled = false
    drawings.BoxOutline.Thickness = 3; drawings.BoxOutline.Filled = false; drawings.BoxOutline.Color = Color3.new(0,0,0)
    drawings.Tracer.Thickness = 1.5
    drawings.Health.Size = 16; drawings.Health.Center = true; drawings.Health.Outline = true; drawings.Health.Color = Color3.new(1,1,1)

    for i = 1, 14 do 
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

-- Função corrigida para alinhar o Drawing na tela Mobile
local function GetScreenPos(position)
    local pos, vis = Camera:WorldToViewportPoint(position)
    local inset = game:GetService("GuiService"):GetGuiInset()
    -- Subtrai o Notch/Topbar globalmente, sem o usuário precisar de slider
    return Vector2.new(pos.X + inset.X, pos.Y + inset.Y), vis, pos.Z
end


-- Loop de ESP
 RunService.RenderStepped:Connect(function(dt)
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
        
        if char and head and hrp and hum and hum.Health > 0 then
            local rootPos, rootVis, rootZ = GetScreenPos(hrp.Position)
            local headPos, headVis, headZ = GetScreenPos(head.Position + Vector3.new(0, 0.5, 0))
            local legPos, legVis, legZ = GetScreenPos(hrp.Position - Vector3.new(0, 3, 0))
            
            if rootVis and rootZ > 0 then
                local height = math.abs(headPos.Y - legPos.Y)
                local width = height / 1.8

                -- Box
                if Config.ESP.Boxes then
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
                
                -- Health
                if Config.ESP.HealthText then
                    drawings.Health.Text = tostring(math.floor(hum.Health)) .. "%"
                    drawings.Health.Position = Vector2.new(rootPos.X, rootPos.Y + (height / 2) + 5)
                    drawings.Health.Visible = true
                else
                    drawings.Health.Visible = false
                end

                -- Tracers
                if Config.ESP.Tracers then
                    drawings.Tracer.From = Vector2.new(screenCenter.X, Camera.ViewportSize.Y)
                    drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                    drawings.Tracer.Color = Config.ESP.Color
                    drawings.Tracer.Visible = true
                else
                    drawings.Tracer.Visible = false
                end

                -- Skeleton
                if Config.ESP.Skeleton then
                    local rigType = hum.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6"
                    local connections = Skeletons[rigType]
                    for i = 1, 14 do
                        if i <= #connections then
                            local p1, p2 = char:FindFirstChild(connections[i][1]), char:FindFirstChild(connections[i][2])
                            if p1 and p2 then
                                local pos1, vis1, z1 = GetScreenPos(p1.Position)
                                local pos2, vis2, z2 = GetScreenPos(p2.Position)
                                if vis1 and vis2 and z1 > 0 and z2 > 0 then
                                    drawings.Skeleton[i].From = pos1
                                    drawings.Skeleton[i].To = pos2
                                    drawings.Skeleton[i].Color = Config.ESP.Color
                                    drawings.Skeleton[i].Visible = true
                                else
                                    drawings.Skeleton[i].Visible = false
                                end
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
            -- Se o personagem não estiver vivo, esconde tudo
            drawings.Box.Visible = false
            drawings.BoxOutline.Visible = false
            drawings.Tracer.Visible = false
            drawings.Health.Visible = false
            for _, line in pairs(drawings.Skeleton) do line.Visible = false end
        end
    end



    -- Aimbot 
    if Config.Aimbot.Enabled then
    local target = GetClosestTarget()
    if target then
        local targetPos = target.Position
        if Config.Aimbot.Prediction > 0 then
            local vel = target.AssemblyLinearVelocity or Vector3.zero
            if vel.Magnitude > 150 then vel = vel.Unit * 150 end
            targetPos = targetPos + (vel * Config.Aimbot.Prediction)
        end

        local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        if Config.Aimbot.Smoothness >= 1 then
            Camera.CFrame = targetCFrame
        else
            -- Suavização exponencial (independente de FPS)
            local smoothFactor = 1 - math.exp(-Config.Aimbot.Smoothness * 15 * dt)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothFactor)
        end
    end
end
---------------------------------------------------------
-- UI MODERNA SEM EMOJIS
---------------------------------------------------------
local UI = Instance.new("ScreenGui")
UI.Name = "EZ_UI"
UI.IgnoreGuiInset = true

-- Fix pro Delta: Tenta CoreGui, se ele bloquear, força no PlayerGui
local success, targetParent = pcall(function()
    return gethui and gethui() or game:GetService("CoreGui")
end)

if success and targetParent then
    UI.Parent = targetParent
else
    UI.Parent = LocalPlayer:WaitForChild("PlayerGui")
end


-- Botão Flutuante (redondo com ícone de mira)
local FloatingBtn = Instance.new("ImageButton", UI)
FloatingBtn.Size = UDim2.new(0, 55, 0, 55)
FloatingBtn.Position = UDim2.new(0, 15, 0, 40)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
FloatingBtn.Image = "rbxassetid://6031763426" -- ícone de mira
FloatingBtn.ImageColor3 = Color3.fromRGB(255, 50, 50)
FloatingBtn.ScaleType = Enum.ScaleType.Fit
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(1, 0)
FloatingBtn.ZIndex = 2

-- Painel Principal (com transparência)
local Main = Instance.new("Frame", UI)
Main.Size = UDim2.new(0, 360, 0, 500)
Main.Position = UDim2.new(0.5, -180, 1.2, 0)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
Main.BackgroundTransparency = 0.25
Main.ClipsDescendants = true
Main.Visible = false
Main.ZIndex = 1
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 20)

-- Fundo escuro por baixo (para dar contraste)
local Backdrop = Instance.new("Frame", Main)
Backdrop.Size = UDim2.new(1, 0, 1, 0)
Backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Backdrop.BackgroundTransparency = 0.4
Backdrop.ZIndex = 0
Instance.new("UICorner", Backdrop)

-- Título
local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -50, 0, 45)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "EZ MOBILE"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 2

-- Botão Fechar
local CloseBtn = Instance.new("ImageButton", Main)
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -45, 0, 5)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Image = "rbxassetid://6031094846" -- ícone X
CloseBtn.ImageColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.ZIndex = 2
CloseBtn.MouseButton1Click:Connect(function()
    Main:TweenPosition(UDim2.new(0.5, -180, 1.2, 0), "In", "Quart", 0.3, true, function()
        Main.Visible = false
        FloatingBtn.Visible = true
    end)
end)

-- Abrir o menu ao clicar no botão flutuante
FloatingBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    FloatingBtn.Visible = false
    Main:TweenPosition(UDim2.new(0.5, -180, 0.5, -250), "Out", "Quart", 0.4, true)
end)

-- Sistema de Abas
local TabFrame = Instance.new("Frame", Main)
TabFrame.Size = UDim2.new(1, 0, 0, 40)
TabFrame.Position = UDim2.new(0, 0, 0, 45)
TabFrame.BackgroundTransparency = 1
TabFrame.ZIndex = 2

local TabButtons = {}
local TabContents = {}
local function CreateTab(name, iconId)
    local btn = Instance.new("ImageButton", TabFrame)
    btn.Size = UDim2.new(0, 60, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Image = iconId
    btn.ImageColor3 = Color3.fromRGB(180, 180, 180)
    btn.ScaleType = Enum.ScaleType.Fit
    btn.ZIndex = 3
    
    local label = Instance.new("TextLabel", btn)
    label.Size = UDim2.new(1, 0, 0, 15)
    label.Position = UDim2.new(0, 0, 1, -15)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextColor3 = Color3.fromRGB(180, 180, 180)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 3
    
    local content = Instance.new("ScrollingFrame", Main)
    content.Size = UDim2.new(1, -10, 1, -90)
    content.Position = UDim2.new(0, 5, 0, 85)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 2
    content.CanvasSize = UDim2.new(0, 0, 2, 0)
    content.Visible = false
    content.ZIndex = 2
    content.BottomImage = "rbxassetid://0" -- remove setas padrão
    content.MidImage = "rbxassetid://0"
    content.TopImage = "rbxassetid://0"
    
    table.insert(TabButtons, btn)
    table.insert(TabContents, content)
    return content
end

local tabAim = CreateTab("AIM", "rbxassetid://6031763426")
local tabESP = CreateTab("ESP", "rbxassetid://6031932273")
local tabFOV = CreateTab("FOV", "rbxassetid://6031232211")

-- Distribuir as abas igualmente
local tabCount = #TabButtons
for i, btn in ipairs(TabButtons) do
    btn.Position = UDim2.new((i-1)/tabCount, 0, 0, 0)
    btn.Size = UDim2.new(1/tabCount, 0, 1, 0)
end

local function SelectTab(index)
    for i, content in ipairs(TabContents) do
        content.Visible = (i == index)
        TabButtons[i].ImageColor3 = (i == index) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(180, 180, 180)
        local label = TabButtons[i]:FindFirstChild("TextLabel")
        if label then label.TextColor3 = TabButtons[i].ImageColor3 end
    end
end
SelectTab(1)

for i, btn in ipairs(TabButtons) do
    btn.MouseButton1Click:Connect(function() SelectTab(i) end)
end

-- ========== FUNÇÕES DE UI MELHORADAS ==========

-- Toggle com switch (iOS style)
local function CreateToggle(parent, name, iconId, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BackgroundTransparency = 0.3
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local icon = Instance.new("ImageLabel", frame)
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 10, 0.5, -10)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Switch
    local switch = Instance.new("Frame", frame)
    switch.Size = UDim2.new(0, 45, 0, 25)
    switch.Position = UDim2.new(1, -55, 0.5, -12.5)
    switch.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", switch)
    thumb.Size = UDim2.new(0, 21, 0, 21)
    thumb.Position = UDim2.new(0, 2, 0.5, -10.5)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    
    local state = false
    local function updateSwitch()
        switch.BackgroundColor3 = state and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(80, 80, 80)
        thumb.Position = state and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
    end
    updateSwitch()
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 2
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        updateSwitch()
        callback(state)
    end)
    
    return function(v) state = v; updateSwitch(); callback(state) end
end

-- Slider com thumb e barra mais grossa
local function CreateSlider(parent, name, iconId, min, max, default, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 56)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BackgroundTransparency = 0.3
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local icon = Instance.new("ImageLabel", frame)
    icon.Size = UDim2.new(0, 16, 0, 16)
    icon.Position = UDim2.new(0, 10, 0, 8)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -40, 0, 20)
    label.Position = UDim2.new(0, 35, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(default)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Barra de fundo
    local bar = Instance.new("Frame", frame)
    bar.Size = UDim2.new(1, -20, 0, 16)
    bar.Position = UDim2.new(0, 10, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    
    -- Preenchimento
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    -- Thumb (bolinha)
    local thumb = Instance.new("Frame", bar)
    thumb.Size = UDim2.new(0, 18, 0, 18)
    thumb.Position = UDim2.new((default - min) / (max - min), -9, 0.5, -9)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    local thumbStroke = Instance.new("UIStroke", thumb)
    thumbStroke.Color = Color3.fromRGB(255, 50, 50)
    thumbStroke.Thickness = 2
    
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos * 100) / 100
        fill.Size = UDim2.new(pos, 0, 1, 0)
        thumb.Position = UDim2.new(pos, -9, 0.5, -9)
        label.Text = name .. ": " .. tostring(value)
        callback(value)
    end
    
    local function onInputBegin(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(inp)
        end
    end
    
    bar.InputBegan:Connect(onInputBegin)
    thumb.InputBegan:Connect(onInputBegin)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging then update(inp) end
    end)
end

-- Color Picker compacto
local function BuildRealColorPicker(parent, name, iconId, configRef, configKey)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 165)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BackgroundTransparency = 0.3
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local icon = Instance.new("ImageLabel", frame)
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -50, 0, 20)
    label.Position = UDim2.new(0, 40, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Área de Saturação/Valor (100x100)
    local SVArea = Instance.new("ImageButton", frame)
    SVArea.Size = UDim2.new(0, 100, 0, 100)
    SVArea.Position = UDim2.new(0, 20, 0, 40)
    SVArea.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    SVArea.Image = "rbxassetid://0"
    SVArea.ZIndex = 1
    Instance.new("UICorner", SVArea).CornerRadius = UDim.new(0, 4)
    
    -- Gradiente branco
    local whiteGrad = Instance.new("Frame", SVArea)
    whiteGrad.Size = UDim2.new(1, 0, 1, 0)
    whiteGrad.BackgroundColor3 = Color3.new(1, 1, 1)
    whiteGrad.BackgroundTransparency = 0.5
    whiteGrad.ZIndex = 2
    local whiteGradUI = Instance.new("UIGradient", whiteGrad)
    whiteGradUI.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
    whiteGradUI.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    
    -- Gradiente preto
    local blackGrad = Instance.new("Frame", SVArea)
    blackGrad.Size = UDim2.new(1, 0, 1, 0)
    blackGrad.BackgroundColor3 = Color3.new(0, 0, 0)
    blackGrad.BackgroundTransparency = 0.5
    blackGrad.ZIndex = 3
    local blackGradUI = Instance.new("UIGradient", blackGrad)
    blackGradUI.Rotation = 90
    blackGradUI.Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0))
    blackGradUI.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    
    -- Cursor SV
    local SVCursor = Instance.new("Frame", SVArea)
    SVCursor.Size = UDim2.new(0, 8, 0, 8)
    SVCursor.Position = UDim2.new(1, -4, 0, -4)
    SVCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    SVCursor.ZIndex = 4
    Instance.new("UICorner", SVCursor).CornerRadius = UDim.new(1, 0)
    local cursorStroke = Instance.new("UIStroke", SVCursor)
    cursorStroke.Color = Color3.new(0, 0, 0)
    cursorStroke.Thickness = 1
    
    -- Barra de Matiz (15x100)
    local HueArea = Instance.new("ImageButton", frame)
    HueArea.Size = UDim2.new(0, 15, 0, 100)
    HueArea.Position = UDim2.new(0, 130, 0, 40)
    HueArea.BackgroundColor3 = Color3.new(1, 1, 1)
    HueArea.ZIndex = 1
    Instance.new("UICorner", HueArea).CornerRadius = UDim.new(0, 4)
    local hueGrad = Instance.new("UIGradient", HueArea)
    hueGrad.Rotation = 90
    hueGrad.Color = ColorSequence.new({
        NumberSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
        NumberSequenceKeypoint.new(0.16, Color3.fromRGB(255,255,0)),
        NumberSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
        NumberSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
        NumberSequenceKeypoint.new(0.66, Color3.fromRGB(0,0,255)),
        NumberSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
        NumberSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))
    })
    
    local HueCursor = Instance.new("Frame", HueArea)
    HueCursor.Size = UDim2.new(1, 4, 0, 4)
    HueCursor.Position = UDim2.new(0, -2, 0, -2)
    HueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    HueCursor.ZIndex = 2
    local hueCursorStroke = Instance.new("UIStroke", HueCursor)
    hueCursorStroke.Color = Color3.new(0, 0, 0)
    hueCursorStroke.Thickness = 1
    
    -- Preview (50x50)
    local Preview = Instance.new("Frame", frame)
    Preview.Size = UDim2.new(0, 50, 0, 50)
    Preview.Position = UDim2.new(0, 160, 0, 65)
    Preview.BackgroundColor3 = configRef[configKey]
    Preview.ZIndex = 1
    Instance.new("UICorner", Preview).CornerRadius = UDim.new(0, 4)
    local previewStroke = Instance.new("UIStroke", Preview)
    previewStroke.Color = Color3.new(1, 1, 1)
    previewStroke.Thickness = 1
    
    local h, s, v = 1, 1, 1
    local function UpdateColor()
        local c = Color3.fromHSV(h, s, v)
        Preview.BackgroundColor3 = c
        configRef[configKey] = c
    end
    
    local dragSV, dragHue = false, false
    local function onSVInput(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragSV = true
            local mx = math.clamp(inp.Position.X - SVArea.AbsolutePosition.X, 0, SVArea.AbsoluteSize.X)
            local my = math.clamp(inp.Position.Y - SVArea.AbsolutePosition.Y, 0, SVArea.AbsoluteSize.Y)
            SVCursor.Position = UDim2.new(0, mx - 4, 0, my - 4)
            s = mx / SVArea.AbsoluteSize.X
            v = 1 - (my / SVArea.AbsoluteSize.Y)
            UpdateColor()
        end
    end
    local function onHueInput(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragHue = true
            local my = math.clamp(inp.Position.Y - HueArea.AbsolutePosition.Y, 0, HueArea.AbsoluteSize.Y)
            HueCursor.Position = UDim2.new(0, -2, 0, my - 2)
            h = 1 - (my / HueArea.AbsoluteSize.Y)
            SVArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            UpdateColor()
        end
    end
    
    SVArea.InputBegan:Connect(onSVInput)
    HueArea.InputBegan:Connect(onHueInput)
    
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragSV = false
            dragHue = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            if dragSV then
                local mx = math.clamp(inp.Position.X - SVArea.AbsolutePosition.X, 0, SVArea.AbsoluteSize.X)
                local my = math.clamp(inp.Position.Y - SVArea.AbsolutePosition.Y, 0, SVArea.AbsoluteSize.Y)
                SVCursor.Position = UDim2.new(0, mx - 4, 0, my - 4)
                s = mx / SVArea.AbsoluteSize.X
                v = 1 - (my / SVArea.AbsoluteSize.Y)
                UpdateColor()
            elseif dragHue then
                local my = math.clamp(inp.Position.Y - HueArea.AbsolutePosition.Y, 0, HueArea.AbsoluteSize.Y)
                HueCursor.Position = UDim2.new(0, -2, 0, my - 2)
                h = 1 - (my / HueArea.AbsoluteSize.Y)
                SVArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                UpdateColor()
            end
        end
    end)
end

-- ========== CRIAÇÃO DOS CONTROLES NAS ABAS ==========

-- Aba AIM
CreateToggle(tabAim, "Aimbot Master", "rbxassetid://6031763426", function(s) Config.Aimbot.Enabled = s end)
CreateSlider(tabAim, "Smoothness", "rbxassetid://6031302821", 0.01, 1, 1, function(v) Config.Aimbot.Smoothness = v end)
CreateToggle(tabAim, "Wall Check", "rbxassetid://6031265976", function(s) Config.Aimbot.WallCheck = s end)
CreateToggle(tabAim, "Random Hitbox", "rbxassetid://6031068433", function(s) Config.Aimbot.RandomHitbox = s end)

-- Aba ESP
CreateToggle(tabESP, "Box ESP", "rbxassetid://6031201502", function(s) Config.ESP.Boxes = s end)
CreateToggle(tabESP, "Tracers", "rbxassetid://6031302821", function(s) Config.ESP.Tracers = s end)
CreateToggle(tabESP, "Skeleton", "rbxassetid://6031932273", function(s) Config.ESP.Skeleton = s end)
CreateToggle(tabESP, "Health Text", "rbxassetid://6031094359", function(s) Config.ESP.HealthText = s end)
BuildRealColorPicker(tabESP, "ESP Color", "rbxassetid://6031072946", Config.ESP, "Color")

-- Aba FOV
CreateToggle(tabFOV, "Draw FOV", "rbxassetid://6031232211", function(s) Config.FOV.Visible = s end)
CreateSlider(tabFOV, "FOV Radius", "rbxassetid://6031232211", 50, 500, 150, function(v) Config.FOV.Radius = v end)
BuildRealColorPicker(tabFOV, "FOV Color", "rbxassetid://6031072946", Config.FOV, "Color") 

-- Função auxiliar para botões de ação
local function CreateActionBtn(parent, name, iconId, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = Color3.fromRGB(40, 20, 25)
    frame.BackgroundTransparency = 0.3
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local icon = Instance.new("ImageLabel", frame)
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 10, 0.5, -10)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = Color3.fromRGB(255, 50, 50)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 40, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 2
    btn.MouseButton1Click:Connect(callback)
end

-- Agora sim, adicione os botões na aba FOV
local ConfigName = "EZ_MOBILE_CFG.json"

CreateActionBtn(tabFOV, "Save Config", "rbxassetid://6031280882", function()
    if writefile then
        local saveCfg = {
            Aimbot = Config.Aimbot,
            FOV = {Visible = Config.FOV.Visible, Radius = Config.FOV.Radius},
            ESP = {Boxes = Config.ESP.Boxes, Tracers = Config.ESP.Tracers, Skeleton = Config.ESP.Skeleton, HealthText = Config.ESP.HealthText}
        }
        writefile(ConfigName, HttpService:JSONEncode(saveCfg))
    end
end)

CreateActionBtn(tabFOV, "Load Config", "rbxassetid://6031236746", function()
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
        end
    end
end)
