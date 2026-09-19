--============================================================--
--  Hyko · iOS UI  v5  (Standalone Settings · No Glow · No Key)
--============================================================--

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local LP           = Players.LocalPlayer

--============================================================--
-- MOUNT
--============================================================--
local function mountGui(g)
    g.ResetOnSpawn = false
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function()
        if gethui then g.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(g); g.Parent = game:GetService("CoreGui")
        else
            g.Parent = LP:FindFirstChildOfClass("PlayerGui")
                or game:GetService("CoreGui")
        end
    end)
    if not ok then
        pcall(function()
            g.Parent = LP:FindFirstChildOfClass("PlayerGui")
                or game:GetService("CoreGui")
        end)
    end
end

--============================================================--
-- MOVE INPUT
--============================================================--
local Controls
pcall(function()
    local PM = require(LP.PlayerScripts:WaitForChild("PlayerModule", 5))
    Controls = PM:GetControls()
end)

local function readMove()
    if Controls then
        local ok, v = pcall(function() return Controls:GetMoveVector() end)
        if ok and v and v.Magnitude > 0.05 then
            return Vector3.new(v.X, 0, v.Z)
        end
    end
    local d = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then d += Vector3.new(0,0,-1) end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d += Vector3.new(0,0,1) end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d += Vector3.new(-1,0,0) end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d += Vector3.new(1,0,0) end
    return d
end

--============================================================--
-- ANTI-RAGDOLL
--============================================================--
local antiOn, antiSpeed = false, 60
local antiConn, antiPost, antiAdded
local realHum, fakeHum, velCon, velAtt
local lastSafeY
local bodySnap = {}

local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude
rayP.IgnoreWater = true

local function isMover(d)
    return d:IsA("BodyVelocity") or d:IsA("BodyAngularVelocity")
        or d:IsA("BodyForce") or d:IsA("BodyThrust")
        or d:IsA("BodyPosition") or d:IsA("BodyGyro")
        or d:IsA("LinearVelocity") or d:IsA("AngularVelocity")
        or d:IsA("VectorForce") or d:IsA("Torque")
        or d:IsA("AlignPosition") or d:IsA("AlignOrientation")
        or d:IsA("RocketPropulsion")
end

local function buildFakeHum()
    local h = Instance.new("Humanoid")
    h.WalkSpeed = 600; h.JumpPower = 50; h.UseJumpPower = true
    h.Health = 100; h.MaxHealth = 100
    h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    h.BreakJointsOnDeath = false; h.RequiresNeck = false
    h.EvaluateStateMachine = false
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        h:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)
    return h
end

local function snap(p)
    if bodySnap[p] then return end
    bodySnap[p] = { cc = p.CanCollide, m = p.Massless }
end

local function neutralize(char, root)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if p ~= root then
                snap(p)
                pcall(function()
                    if p.CanCollide then p.CanCollide = false end
                    if not p.Massless then p.Massless = true end
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end)
            end
            pcall(function() p.AssemblyAngularVelocity = Vector3.zero end)
        elseif isMover(p) and p.Name ~= "HykoVel" then
            pcall(function() p:Destroy() end)
        end
    end
end

local function restore(char)
    if not char then return end
    for p, s in pairs(bodySnap) do
        if p and p.Parent then
            pcall(function() p.CanCollide = s.cc; p.Massless = s.m end)
        end
    end
    bodySnap = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

local function makeVelCon(hrp)
    if velCon then pcall(function() velCon:Destroy() end) end
    if velAtt then pcall(function() velAtt:Destroy() end) end
    local a = Instance.new("Attachment")
    a.Name = "HykoAtt"; a.Parent = hrp; velAtt = a
    local lv = Instance.new("LinearVelocity")
    lv.Name = "HykoVel"; lv.Attachment0 = a
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    lv.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
    pcall(function() lv.ForceLimitsEnabled = true end)
    lv.Parent = hrp; velCon = lv
end

local function killVelCon()
    if velCon then pcall(function() velCon:Destroy() end) end
    if velAtt then pcall(function() velAtt:Destroy() end) end
    velCon, velAtt = nil, nil
end

local function healthy()
    if not fakeHum or not fakeHum.Parent then return end
    pcall(function()
        if fakeHum.PlatformStand then fakeHum.PlatformStand = false end
        if fakeHum.Sit then fakeHum.Sit = false end
        fakeHum.AutoRotate = true
        local st = fakeHum:GetState()
        if st == Enum.HumanoidStateType.Ragdoll
            or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.Physics
            or st == Enum.HumanoidStateType.PlatformStanding then
            fakeHum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

local function heartbeat()
    local ch = LP.Character; if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
    local cam = workspace.CurrentCamera; if not cam then return end

    if not fakeHum or fakeHum.Parent ~= ch then
        fakeHum = buildFakeHum(); fakeHum.Parent = ch
    end
    if fakeHum.WalkSpeed ~= 600 then
        pcall(function() fakeHum.WalkSpeed = 600 end)
    end
    if realHum and realHum.Parent == ch then
        pcall(function() realHum.Parent = nil end)
    end

    healthy()
    neutralize(ch, root)
    if not velCon or not velCon.Parent then makeVelCon(root) end
    pcall(function() root:SetNetworkOwner(LP) end)

    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude > 0.01 then
        root.CFrame = CFrame.new(root.Position, root.Position + flat.Unit)
    end
    root.AssemblyAngularVelocity = Vector3.zero

    rayP.FilterDescendantsInstances = {ch}
    local origin = root.Position + Vector3.new(0, 4, 0)
    local res = workspace:Raycast(origin, Vector3.new(0, -120, 0), rayP)
    local gy
    if res then gy = res.Position.Y + 3.5; lastSafeY = gy end

    local vel = root.AssemblyLinearVelocity
    if vel.Y > 40 then
        vel = Vector3.new(vel.X, 0, vel.Z)
        root.AssemblyLinearVelocity = vel
    end

    if gy then
        if root.Position.Y > gy + 12 then
            root.CFrame = CFrame.new(root.Position.X, gy, root.Position.Z)
                * (root.CFrame - root.Position)
            root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
        end
    elseif lastSafeY and root.Position.Y > lastSafeY + 25 then
        root.CFrame = CFrame.new(root.Position.X, lastSafeY, root.Position.Z)
            * (root.CFrame - root.Position)
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
    end

    local mv = readMove()
    local target
    if mv.Magnitude < 0.05 then
        target = Vector3.zero
    else
        local wd = cam.CFrame.LookVector * (-mv.Z) + cam.CFrame.RightVector * mv.X
        wd = Vector3.new(wd.X, 0, wd.Z)
        target = wd.Magnitude > 0.01 and wd.Unit * antiSpeed or Vector3.zero
    end

    if velCon and velCon.Parent then
        velCon.VectorVelocity = target
    else
        root.AssemblyLinearVelocity =
            target + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
    end

    if gy then
        local delta = gy - root.Position.Y
        if math.abs(delta) < 8 then
            root.CFrame = CFrame.new(root.Position.X, gy, root.Position.Z)
                * (root.CFrame - root.Position)
            local cv = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(cv.X, 0, cv.Z)
        end
    end
end

local function postSim()
    if not velCon or not velCon.Parent then return end
    local c = LP.Character; if not c then return end
    local root = c:FindFirstChild("HumanoidRootPart"); if not root then return end
    local want, cur = velCon.VectorVelocity, root.AssemblyLinearVelocity
    local dx, dz = cur.X - want.X, cur.Z - want.Z
    if (dx*dx + dz*dz) > 4 then
        root.AssemblyLinearVelocity = Vector3.new(want.X, cur.Y, want.Z)
    end
end

local function startAnti()
    if antiConn then return end
    local c = LP.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    realHum = hum
    pcall(function() realHum.Parent = nil end)
    fakeHum = buildFakeHum(); fakeHum.Parent = c

    pcall(function() workspace.CurrentCamera.CameraSubject = hrp end)
    pcall(function() hrp:SetNetworkOwner(LP) end)

    lastSafeY = hrp.Position.Y
    bodySnap = {}
    neutralize(c, hrp)
    makeVelCon(hrp)

    antiAdded = c.DescendantAdded:Connect(function(d)
        if not antiOn then return end
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            task.defer(function()
                if antiOn and d.Parent then
                    snap(d)
                    pcall(function()
                        if d.CanCollide then d.CanCollide = false end
                        if not d.Massless then d.Massless = true end
                        d.AssemblyLinearVelocity = Vector3.zero
                        d.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end)
        elseif isMover(d) and d.Name ~= "HykoVel" then
            task.defer(function()
                if antiOn then pcall(function() d:Destroy() end) end
            end)
        end
    end)

    antiConn = (RunService.PreSimulation or RunService.Heartbeat):Connect(heartbeat)
    antiPost = (RunService.PostSimulation or RunService.Stepped):Connect(postSim)
end

local function stopAnti()
    if antiAdded then antiAdded:Disconnect() antiAdded = nil end
    if antiConn then antiConn:Disconnect() antiConn = nil end
    if antiPost then antiPost:Disconnect() antiPost = nil end
    killVelCon()
    local c = LP.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        restore(c)
        if fakeHum and fakeHum.Parent then
            pcall(function() fakeHum:Destroy() end)
        end
        fakeHum = nil
        if realHum and realHum.Parent == nil then
            pcall(function()
                realHum.Parent = c
                realHum.WalkSpeed = 16; realHum.JumpPower = 50
                realHum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
        realHum = nil
    end
    lastSafeY = nil
end

--============================================================--
-- FAST LOOT
--============================================================--
local lootOn, lootConn, promptAdd
local savedHold = {}

local function fastPrompt(p)
    if not p:IsA("ProximityPrompt") then return end
    if savedHold[p] == nil then savedHold[p] = p.HoldDuration end
    pcall(function() p.HoldDuration = 0 end)
end

local function restorePrompts()
    for p, h in pairs(savedHold) do
        if p and p.Parent then pcall(function() p.HoldDuration = h end) end
    end
    savedHold = {}
end

local lootP = OverlapParams.new()
lootP.FilterType = Enum.RaycastFilterType.Exclude

local function enableLoot()
    if lootConn then return end
    task.spawn(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then fastPrompt(d) end
        end
    end)
    promptAdd = workspace.DescendantAdded:Connect(function(d)
        if lootOn and d:IsA("ProximityPrompt") then fastPrompt(d) end
    end)
    lootConn = UIS.InputBegan:Connect(function(input, gpe)
        if not lootOn or gpe then return end
        if input.KeyCode ~= Enum.KeyCode.E then return end
        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        lootP.FilterDescendantsInstances = {c}
        local parts = workspace:GetPartBoundsInRadius(hrp.Position, 32, lootP)
        local best, bd = nil, math.huge
        for _, part in ipairs(parts) do
            for _, d in ipairs(part:GetChildren()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist <= d.MaxActivationDistance + 4 and dist < bd then
                        best, bd = d, dist
                    end
                end
            end
            for _, att in ipairs(part:GetChildren()) do
                if att:IsA("Attachment") then
                    for _, d in ipairs(att:GetChildren()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist <= d.MaxActivationDistance + 4 and dist < bd then
                                best, bd = d, dist
                            end
                        end
                    end
                end
            end
        end
        if best then pcall(function() fireproximityprompt(best) end) end
    end)
end

local function disableLoot()
    if lootConn then lootConn:Disconnect() lootConn = nil end
    if promptAdd then promptAdd:Disconnect() promptAdd = nil end
    restorePrompts()
end

--============================================================--
-- FPS BOOST
--============================================================--
local boostOn, boostConn
local savedQuality, savedCap, origLighting
local savedAtmos, disabledLights = {}, {}

local function isHyko(d)
    return d and d.Name and string.sub(d.Name, 1, 4) == "Hyko"
end

local function safeRemove(d)
    if isHyko(d) then return false end
    local c = LP.Character
    if c and d:IsDescendantOf(c) then return false end
    for _, pl in ipairs(Players:GetPlayers()) do
        local pc = pl.Character
        if pc and d:IsDescendantOf(pc) then return false end
    end
    return true
end

local function isFX(d)
    return d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
        or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")
        or d:IsA("Explosion") or d:IsA("SurfaceAppearance")
        or d:IsA("Decal") or d:IsA("Texture")
end

local function killFX(d)
    if not d or not d.Parent or not safeRemove(d) then return end
    pcall(function() d:Destroy() end)
end

local function disableLight(l)
    if disabledLights[l] ~= nil then return end
    local ok, v = pcall(function() return l.Enabled end)
    if not ok then return end
    disabledLights[l] = v
    pcall(function() l.Enabled = false end)
end

local function saveLighting()
    origLighting = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows,
        Shadows = Lighting.Shadows, FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
        EnvD = Lighting.EnvironmentDiffuseScale,
        EnvS = Lighting.EnvironmentSpecularScale,
        Exposure = Lighting.ExposureCompensation,
    }
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Shadows = false
        Lighting.Brightness = 0.5
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.ExposureCompensation = -0.6
        Lighting.Ambient = Color3.fromRGB(235,235,240)
        Lighting.OutdoorAmbient = Color3.fromRGB(235,235,240)
        Lighting.FogColor = Color3.fromRGB(240,240,245)
        Lighting.FogStart = 55; Lighting.FogEnd = 210
    end)
end

local function restoreLighting()
    if not origLighting then return end
    pcall(function()
        Lighting.Ambient = origLighting.Ambient
        Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
        Lighting.Brightness = origLighting.Brightness
        Lighting.GlobalShadows = origLighting.GlobalShadows
        Lighting.Shadows = origLighting.Shadows
        Lighting.FogEnd = origLighting.FogEnd
        Lighting.FogStart = origLighting.FogStart
        Lighting.FogColor = origLighting.FogColor
        Lighting.EnvironmentDiffuseScale = origLighting.EnvD
        Lighting.EnvironmentSpecularScale = origLighting.EnvS
        Lighting.ExposureCompensation = origLighting.Exposure
    end)
    for a, s in pairs(savedAtmos) do
        if a and a.Parent then
            pcall(function()
                a.Density = s.Density; a.Haze = s.Haze; a.Glare = s.Glare
            end)
        end
    end
    savedAtmos = {}
    for l, st in pairs(disabledLights) do
        if l and l.Parent then pcall(function() l.Enabled = st end) end
    end
    disabledLights = {}
    origLighting = nil
end

local function stripLighting()
    for _, d in ipairs(Lighting:GetChildren()) do
        if d:IsA("Atmosphere") then
            savedAtmos[d] = { Density = d.Density, Haze = d.Haze, Glare = d.Glare }
            pcall(function() d.Density = 0; d.Haze = 0; d.Glare = 0 end)
        elseif d:IsA("PostEffect") then
            disableLight(d)
        elseif d:IsA("Sky") then
            for _, ch in ipairs(d:GetChildren()) do
                pcall(function() ch:Destroy() end)
            end
        elseif d:IsA("Clouds") then
            pcall(function() d.Cover = 0; d.Density = 0 end)
        end
    end
end

local function scanFX()
    for _, d in ipairs(workspace:GetDescendants()) do
        if isFX(d) then killFX(d)
        elseif d:IsA("PointLight") or d:IsA("SpotLight")
            or d:IsA("SurfaceLight") then
            disableLight(d)
        elseif d:IsA("Highlight") and not isHyko(d) then
            killFX(d)
        end
    end
end

local function enableBoost()
    if boostOn then return end
    boostOn = true
    pcall(function()
        local r = settings().Rendering
        savedQuality = r.QualityLevel
        r.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        local r = settings().Rendering
        savedCap = r.FramerateCap
        r.FramerateCap = 240
    end)
    pcall(saveLighting); pcall(stripLighting)
    pcall(function()
        local T = workspace.Terrain
        T.WaterWaveSize = 0; T.WaterWaveSpeed = 0
        T.WaterReflectance = 0; T.WaterTransparency = 1
        T.Decoration = false
    end)
    task.spawn(function() pcall(scanFX) end)
    boostConn = workspace.DescendantAdded:Connect(function(d)
        if not boostOn or isHyko(d) then return end
        if isFX(d) then
            task.defer(function() if boostOn then killFX(d) end end)
        elseif d:IsA("PointLight") or d:IsA("SpotLight")
            or d:IsA("SurfaceLight") then
            task.defer(function() if boostOn then disableLight(d) end end)
        elseif d:IsA("Highlight") and not isHyko(d) then
            task.defer(function() if boostOn then killFX(d) end end)
        end
    end)
end

local function disableBoost()
    if not boostOn then return end
    boostOn = false
    if boostConn then boostConn:Disconnect() boostConn = nil end
    pcall(function()
        if savedQuality then
            settings().Rendering.QualityLevel = savedQuality
            savedQuality = nil
        end
    end)
    pcall(function()
        if savedCap then
            settings().Rendering.FramerateCap = savedCap
            savedCap = nil
        end
    end)
    pcall(restoreLighting)
end

local function freeRAM()
    for _ = 1, 3 do
        pcall(function()
            if collectgarbage then collectgarbage("collect") end
        end)
    end
end

--============================================================--
-- PALETTE + THEMES
--============================================================--
local COL = {
    bg      = Color3.fromRGB(255, 255, 255),
    card    = Color3.fromRGB(250, 251, 253),
    text    = Color3.fromRGB(15, 17, 22),
    sub     = Color3.fromRGB(140, 145, 155),
    divider = Color3.fromRGB(238, 240, 244),
    track   = Color3.fromRGB(230, 232, 238),
    accent  = Color3.fromRGB(10, 132, 255),
    green   = Color3.fromRGB(52, 199, 89),
    red     = Color3.fromRGB(255, 69, 58),
    stroke  = Color3.fromRGB(232, 234, 240),
}

local THEMES = {
    { Name = "Blue",    Accent = Color3.fromRGB(10, 132, 255)  },
    { Name = "Green",   Accent = Color3.fromRGB(52, 199, 89)   },
    { Name = "Violet",  Accent = Color3.fromRGB(139, 92, 246)  },
    { Name = "Rose",    Accent = Color3.fromRGB(236, 72, 153)  },
    { Name = "Crimson", Accent = Color3.fromRGB(255, 69, 58)   },
    { Name = "Amber",   Accent = Color3.fromRGB(255, 159, 10)  },
    { Name = "Teal",    Accent = Color3.fromRGB(48, 176, 199)  },
    { Name = "Slate",   Accent = Color3.fromRGB(90, 100, 115)  },
}

local themeEls = {}
local function reg(el, prop)
    if el then table.insert(themeEls, { o = el, p = prop }) end
end

local function applyTheme(t)
    COL.accent = t.Accent
    for _, e in ipairs(themeEls) do
        pcall(function() e.o[e.p] = t.Accent end)
    end
end

--============================================================--
-- EASING
--============================================================--
local EASE = {
    smooth = TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    quick  = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    fade   = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    slide  = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

--============================================================--
-- DIMENSIONS
--============================================================--
local W_COL, H_COL = 104, 50
local W_EXP, H_EXP = 296, 348

--============================================================--
-- MAIN SCREEN
--============================================================--
local screen = Instance.new("ScreenGui")
screen.Name = "HykoLite"
screen.IgnoreGuiInset = true
mountGui(screen)

local main = Instance.new("Frame")
main.AnchorPoint = Vector2.new(1, 0)
main.Position = UDim2.new(1, -20, 0, 20)
main.Size = UDim2.fromOffset(W_COL, H_COL)
main.BackgroundColor3 = COL.bg
main.BackgroundTransparency = 0.02
main.BorderSizePixel = 0
main.ClipsDescendants = false
main.ZIndex = 10
main.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, H_COL / 2)
corner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COL.stroke
mainStroke.Thickness = 1
mainStroke.Transparency = 0.25
mainStroke.Parent = main

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(247,249,252)),
})
mainGrad.Rotation = 90
mainGrad.Parent = main

--============================================================--
-- HEADER
--============================================================--
local avatarWrap = Instance.new("Frame")
avatarWrap.Size = UDim2.fromOffset(30, 30)
avatarWrap.Position = UDim2.fromOffset(10, 10)
avatarWrap.BackgroundColor3 = Color3.fromRGB(240, 242, 246)
avatarWrap.BorderSizePixel = 0
avatarWrap.ZIndex = 12
avatarWrap.Parent = main

local avCorner = Instance.new("UICorner")
avCorner.CornerRadius = UDim.new(1, 0); avCorner.Parent = avatarWrap

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size = UDim2.fromScale(1, 1)
avatarImg.BackgroundTransparency = 1
avatarImg.ZIndex = 13
avatarImg.Parent = avatarWrap

local avImgCorner = Instance.new("UICorner")
avImgCorner.CornerRadius = UDim.new(1, 0); avImgCorner.Parent = avatarImg

local avStroke = Instance.new("UIStroke")
avStroke.Color = Color3.fromRGB(255, 255, 255)
avStroke.Thickness = 2; avStroke.Transparency = 0.15
avStroke.Parent = avatarWrap

task.spawn(function()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(
            LP.UserId, Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150)
    end)
    if ok and img and img ~= "" then avatarImg.Image = img; return end
    local ok2, img2 = pcall(function()
        return Players:GetUserThumbnailAsync(
            LP.UserId, Enum.ThumbnailType.AvatarBust,
            Enum.ThumbnailSize.Size150x150)
    end)
    if ok2 and img2 and img2 ~= "" then avatarImg.Image = img2 end
end)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.fromOffset(9, 9)
statusDot.AnchorPoint = Vector2.new(1, 1)
statusDot.Position = UDim2.new(1, 1, 1, 1)
statusDot.BackgroundColor3 = COL.green
statusDot.BorderSizePixel = 0
statusDot.Visible = false
statusDot.ZIndex = 14
statusDot.Parent = avatarWrap

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0); dotCorner.Parent = statusDot

local dotStroke = Instance.new("UIStroke")
dotStroke.Color = Color3.fromRGB(255, 255, 255)
dotStroke.Thickness = 2; dotStroke.Parent = statusDot

-- FPS
local fpsWrap = Instance.new("Frame")
fpsWrap.Size = UDim2.fromOffset(52, 30)
fpsWrap.Position = UDim2.fromOffset(48, 10)
fpsWrap.BackgroundTransparency = 1
fpsWrap.ZIndex = 12
fpsWrap.Parent = main

local fpsNum = Instance.new("TextLabel")
fpsNum.Size = UDim2.new(1, 0, 0, 20)
fpsNum.BackgroundTransparency = 1
fpsNum.Text = "60"
fpsNum.TextColor3 = COL.accent
fpsNum.Font = Enum.Font.GothamBold
fpsNum.TextSize = 16
fpsNum.TextXAlignment = Enum.TextXAlignment.Left
fpsNum.ZIndex = 13
fpsNum.Parent = fpsWrap
reg(fpsNum, "TextColor3")

local fpsTag = Instance.new("TextLabel")
fpsTag.Size = UDim2.new(1, 0, 0, 11)
fpsTag.Position = UDim2.fromOffset(0, 20)
fpsTag.BackgroundTransparency = 1
fpsTag.Text = "FPS"
fpsTag.TextColor3 = COL.sub
fpsTag.Font = Enum.Font.GothamMedium
fpsTag.TextSize = 9
fpsTag.TextXAlignment = Enum.TextXAlignment.Left
fpsTag.ZIndex = 13
fpsTag.Parent = fpsWrap

do
    local frames, lastClock, lastFPS = 0, os.clock(), -1
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        local el = now - lastClock
        if el >= 0.75 then
            local f = math.floor(frames / el + 0.5)
            frames, lastClock = 0, now
            if f ~= lastFPS and fpsNum.Parent then
                lastFPS = f
                fpsNum.Text = tostring(f)
                if f >= 45 then fpsNum.TextColor3 = COL.green
                elseif f >= 25 then fpsNum.TextColor3 = Color3.fromRGB(255,159,10)
                else fpsNum.TextColor3 = COL.red end
            end
        end
    end)
end

-- name + handle
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 150, 0, 16)
title.Position = UDim2.fromOffset(48, 11)
title.BackgroundTransparency = 1
title.Text = LP.DisplayName
title.TextColor3 = COL.text
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTruncate = Enum.TextTruncate.AtEnd
title.TextTransparency = 1
title.ZIndex = 12
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(0, 150, 0, 13)
subtitle.Position = UDim2.fromOffset(48, 27)
subtitle.BackgroundTransparency = 1
subtitle.Text = "@" .. LP.Name
subtitle.TextColor3 = COL.sub
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextTruncate = Enum.TextTruncate.AtEnd
subtitle.TextTransparency = 1
subtitle.ZIndex = 12
subtitle.Parent = main

-- header buttons
local function makeHeaderBtn(icon, xoff)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(26, 26)
    b.AnchorPoint = Vector2.new(1, 0)
    b.Position = UDim2.new(1, xoff, 0, 12)
    b.BackgroundColor3 = Color3.fromRGB(243, 245, 249)
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.ZIndex = 40
    b.Visible = false
    b.Parent = main

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0); c.Parent = b

    local s = Instance.new("UIStroke")
    s.Color = COL.stroke; s.Thickness = 1; s.Transparency = 0.25
    s.Parent = b

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromOffset(13, 13)
    img.Position = UDim2.fromOffset(6.5, 6.5)
    img.BackgroundTransparency = 1
    img.Image = icon
    img.ImageColor3 = COL.text
    img.ZIndex = 41
    img.Parent = b

    b.MouseEnter:Connect(function()
        TweenService:Create(b, EASE.quick,
            { BackgroundColor3 = Color3.fromRGB(232, 236, 242) }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, EASE.quick,
            { BackgroundColor3 = Color3.fromRGB(243, 245, 249) }):Play()
    end)

    return b, img
end

local setBtn, setIcon = makeHeaderBtn("rbxassetid://6031280882", -42)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(26, 26)
minBtn.AnchorPoint = Vector2.new(1, 0)
minBtn.Position = UDim2.new(1, -10, 0, 12)
minBtn.BackgroundColor3 = Color3.fromRGB(243, 245, 249)
minBtn.BorderSizePixel = 0
minBtn.Text = "−"
minBtn.TextColor3 = COL.text
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.AutoButtonColor = false
minBtn.ZIndex = 40
minBtn.Visible = false
minBtn.Parent = main

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(1, 0); minCorner.Parent = minBtn

local minStroke = Instance.new("UIStroke")
minStroke.Color = COL.stroke; minStroke.Thickness = 1
minStroke.Transparency = 0.25; minStroke.Parent = minBtn

minBtn.MouseEnter:Connect(function()
    TweenService:Create(minBtn, EASE.quick,
        { BackgroundColor3 = Color3.fromRGB(232, 236, 242) }):Play()
end)
minBtn.MouseLeave:Connect(function()
    TweenService:Create(minBtn, EASE.quick,
        { BackgroundColor3 = Color3.fromRGB(243, 245, 249) }):Play()
end)

--============================================================--
-- BODY
--============================================================--
local body = Instance.new("CanvasGroup")
body.Size = UDim2.new(1, -24, 1, -72)
body.Position = UDim2.fromOffset(12, 56)
body.BackgroundTransparency = 1
body.GroupTransparency = 1
body.ZIndex = 11
body.Parent = main

local function sectionLabel(y, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 12)
    l.Position = UDim2.fromOffset(4, y)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = COL.sub
    l.Font = Enum.Font.GothamBold
    l.TextSize = 9
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 12
    l.Parent = body
    return l
end

-- plain row (no side bar, no border card)
local function featureRow(parent, y, icon, titleTxt, subTxt)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 54)
    wrap.Position = UDim2.fromOffset(0, y)
    wrap.BackgroundTransparency = 1
    wrap.ZIndex = 12
    wrap.Parent = parent

    local tile = Instance.new("Frame")
    tile.Size = UDim2.fromOffset(32, 32)
    tile.Position = UDim2.fromOffset(2, 11)
    tile.BackgroundColor3 = COL.accent
    tile.BorderSizePixel = 0
    tile.ZIndex = 13
    tile.Parent = wrap
    reg(tile, "BackgroundColor3")

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 10); tc.Parent = tile

    local grad = Instance.new("UIGradient")
    grad.Rotation = 135
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.4),
    })
    grad.Parent = tile

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromOffset(16, 16)
    img.Position = UDim2.fromOffset(8, 8)
    img.BackgroundTransparency = 1
    img.Image = icon
    img.ImageColor3 = Color3.fromRGB(255, 255, 255)
    img.ZIndex = 14
    img.Parent = tile

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -120, 0, 15)
    t.Position = UDim2.fromOffset(42, 10)
    t.BackgroundTransparency = 1
    t.Text = titleTxt
    t.TextColor3 = COL.text
    t.Font = Enum.Font.GothamBold
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 13
    t.Parent = wrap

    local st = Instance.new("TextLabel")
    st.Size = UDim2.new(1, -120, 0, 12)
    st.Position = UDim2.fromOffset(42, 28)
    st.BackgroundTransparency = 1
    st.Text = subTxt
    st.TextColor3 = COL.sub
    st.Font = Enum.Font.GothamMedium
    st.TextSize = 9
    st.TextXAlignment = Enum.TextXAlignment.Left
    st.ZIndex = 13
    st.Parent = wrap

    return wrap
end

-- iOS switch
local function makeSwitch(parent, y)
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(44, 26)
    track.AnchorPoint = Vector2.new(1, 0)
    track.Position = UDim2.new(1, -4, 0, y)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.ZIndex = 14
    track.Parent = parent

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

    local knobShadow = Instance.new("Frame")
    knobShadow.Size = UDim2.fromOffset(22, 22)
    knobShadow.Position = UDim2.fromOffset(2, 2.5)
    knobShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    knobShadow.BackgroundTransparency = 0.85
    knobShadow.BorderSizePixel = 0
    knobShadow.ZIndex = 14
    knobShadow.Parent = track

    local ksc = Instance.new("UICorner")
    ksc.CornerRadius = UDim.new(1, 0); ksc.Parent = knobShadow

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(22, 22)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 15
    knob.Parent = track

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromScale(1, 1)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 16
    btn.Parent = track

    local state = false
    local function apply(anim)
        local bg  = state and COL.green or COL.track
        local pos = state and UDim2.new(1, -24, 0, 2) or UDim2.fromOffset(2, 2)
        local spos = state and UDim2.new(1, -24, 0, 2.5) or UDim2.fromOffset(2, 2.5)
        if anim then
            TweenService:Create(track, EASE.quick, { BackgroundColor3 = bg }):Play()
            TweenService:Create(knob, EASE.quick, { Position = pos }):Play()
            TweenService:Create(knobShadow, EASE.quick, { Position = spos }):Play()
        else
            track.BackgroundColor3 = bg; knob.Position = pos; knobShadow.Position = spos
        end
    end
    apply(false)

    return {
        button = btn,
        setState = function(v, a) state = v apply(a) end,
        getState = function() return state end,
    }
end

-- Slider
local function makeSlider(parent, y, min, max, default, onChange)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.fromOffset(0, y)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.ZIndex = 13
    track.Parent = parent

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COL.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 14
    fill.Parent = track
    reg(fill, "BackgroundColor3")

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill

    local knobShadow = Instance.new("Frame")
    knobShadow.Size = UDim2.fromOffset(20, 20)
    knobShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    knobShadow.Position = UDim2.new(0, 0, 0.5, 1.5)
    knobShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    knobShadow.BackgroundTransparency = 0.82
    knobShadow.BorderSizePixel = 0
    knobShadow.ZIndex = 14
    knobShadow.Parent = track

    local ksc = Instance.new("UICorner")
    ksc.CornerRadius = UDim.new(1, 0); ksc.Parent = knobShadow

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 15
    knob.Parent = track

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 26, 3, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Position = UDim2.new(0.5, 0, 0.5, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 16
    btn.Parent = track

    local value = default
    local function apply(v)
        local t = math.clamp((v - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(t, 0, 1, 0)
        knob.Position = UDim2.new(t, 0, 0.5, 0)
        knobShadow.Position = UDim2.new(t, 0, 0.5, 1.5)
    end
    apply(value)

    local dragging = false
    local function update(absX)
        local sx = track.AbsolutePosition.X
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local t = math.clamp((absX - sx) / w, 0, 1)
        value = math.floor(min + t * (max - min) + 0.5)
        apply(value)
        if onChange then onChange(value) end
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            TweenService:Create(knob, EASE.quick,
                { Size = UDim2.fromOffset(24, 24) }):Play()
            update(input.Position.X)
        end
    end)
    btn.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            update(input.Position.X)
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            TweenService:Create(knob, EASE.quick,
                { Size = UDim2.fromOffset(20, 20) }):Play()
        end
    end)

    return { set = function(v) value = v apply(v) end, get = function() return value end }
end

--============================================================--
-- BODY CONTENT
--============================================================--
sectionLabel(0, "FEATURES")

local lootWrap = featureRow(body, 16,
    "rbxassetid://6031075931", "Fast Loot", "Auto-collect · Key E")
local lootSwitch = makeSwitch(lootWrap, 14)

local antiWrap = featureRow(body, 78,
    "rbxassetid://6035075453", "Anti-Ragdoll", "Server-safe body")
local antiSwitch = makeSwitch(antiWrap, 14)

sectionLabel(144, "SPEED CONTROL")

local sliderValue = Instance.new("TextLabel")
sliderValue.Size = UDim2.new(0, 52, 0, 20)
sliderValue.Position = UDim2.new(1, -52, 0, 160)
sliderValue.BackgroundColor3 = COL.accent
sliderValue.BackgroundTransparency = 0.88
sliderValue.Text = tostring(antiSpeed)
sliderValue.TextColor3 = COL.accent
sliderValue.Font = Enum.Font.GothamBold
sliderValue.TextSize = 11
sliderValue.ZIndex = 13
sliderValue.Parent = body
reg(sliderValue, "TextColor3")

local svCorner = Instance.new("UICorner")
svCorner.CornerRadius = UDim.new(0, 7); svCorner.Parent = sliderValue

local sliderHost = Instance.new("Frame")
sliderHost.Size = UDim2.new(1, 0, 0, 6)
sliderHost.Position = UDim2.fromOffset(0, 190)
sliderHost.BackgroundTransparency = 1
sliderHost.ZIndex = 13
sliderHost.Parent = body

local speedSlider = makeSlider(sliderHost, 0, 20, 800, antiSpeed, function(v)
    antiSpeed = v
    sliderValue.Text = tostring(v)
end)

--============================================================--
-- SETTINGS WINDOW  (standalone, appears to the LEFT of main card)
--============================================================--
local settingsWindow = Instance.new("Frame")
settingsWindow.Name = "HykoSettings"
settingsWindow.AnchorPoint = Vector2.new(1, 0)
settingsWindow.Size = UDim2.fromOffset(260, 320)
settingsWindow.BackgroundColor3 = COL.bg
settingsWindow.BackgroundTransparency = 0.02
settingsWindow.BorderSizePixel = 0
settingsWindow.ClipsDescendants = false
settingsWindow.Visible = false
settingsWindow.ZIndex = 20
settingsWindow.Parent = screen

local swCorner = Instance.new("UICorner")
swCorner.CornerRadius = UDim.new(0, 20); swCorner.Parent = settingsWindow

local swStroke = Instance.new("UIStroke")
swStroke.Color = COL.stroke
swStroke.Thickness = 1; swStroke.Transparency = 0.25
swStroke.Parent = settingsWindow

local swGrad = Instance.new("UIGradient")
swGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(247,249,252)),
})
swGrad.Rotation = 90
swGrad.Parent = settingsWindow

-- Header bar (draggable)
local swHeader = Instance.new("Frame")
swHeader.Size = UDim2.new(1, 0, 0, 40)
swHeader.Position = UDim2.fromOffset(0, 0)
swHeader.BackgroundTransparency = 1
swHeader.ZIndex = 21
swHeader.Parent = settingsWindow

local swHeaderBtn = Instance.new("TextButton")
swHeaderBtn.Size = UDim2.new(1, 0, 1, 0)
swHeaderBtn.BackgroundTransparency = 1
swHeaderBtn.Text = ""
swHeaderBtn.AutoButtonColor = false
swHeaderBtn.ZIndex = 22
swHeaderBtn.Parent = swHeader

local swTitle = Instance.new("TextLabel")
swTitle.Size = UDim2.new(1, -60, 0, 20)
swTitle.Position = UDim2.fromOffset(16, 12)
swTitle.BackgroundTransparency = 1
swTitle.Text = "Settings"
swTitle.TextColor3 = COL.text
swTitle.Font = Enum.Font.GothamBold
swTitle.TextSize = 14
swTitle.TextXAlignment = Enum.TextXAlignment.Left
swTitle.ZIndex = 21
swTitle.Parent = swHeader

local swClose = Instance.new("TextButton")
swClose.Size = UDim2.fromOffset(24, 24)
swClose.AnchorPoint = Vector2.new(1, 0)
swClose.Position = UDim2.new(1, -12, 0, 8)
swClose.BackgroundColor3 = Color3.fromRGB(243, 245, 249)
swClose.BorderSizePixel = 0
swClose.Text = "×"
swClose.TextColor3 = COL.text
swClose.Font = Enum.Font.GothamBold
swClose.TextSize = 16
swClose.AutoButtonColor = false
swClose.ZIndex = 25
swClose.Parent = swHeader

local swCloseCorner = Instance.new("UICorner")
swCloseCorner.CornerRadius = UDim.new(1, 0); swCloseCorner.Parent = swClose

swClose.MouseEnter:Connect(function()
    TweenService:Create(swClose, EASE.quick,
        { BackgroundColor3 = Color3.fromRGB(232, 236, 242) }):Play()
end)
swClose.MouseLeave:Connect(function()
    TweenService:Create(swClose, EASE.quick,
        { BackgroundColor3 = Color3.fromRGB(243, 245, 249) }):Play()
end)

-- divider under header
local swDivH = Instance.new("Frame")
swDivH.Size = UDim2.new(1, -24, 0, 1)
swDivH.Position = UDim2.fromOffset(12, 40)
swDivH.BackgroundColor3 = COL.divider
swDivH.BorderSizePixel = 0
swDivH.ZIndex = 21
swDivH.Parent = settingsWindow

-- Content
local swContent = Instance.new("Frame")
swContent.Size = UDim2.new(1, -32, 1, -56)
swContent.Position = UDim2.fromOffset(16, 48)
swContent.BackgroundTransparency = 1
swContent.ZIndex = 21
swContent.Parent = settingsWindow

-- Accent
local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, 0, 0, 12)
themeLabel.Position = UDim2.fromOffset(0, 0)
themeLabel.BackgroundTransparency = 1
themeLabel.Text = "ACCENT COLOR"
themeLabel.TextColor3 = COL.sub
themeLabel.Font = Enum.Font.GothamBold
themeLabel.TextSize = 9
themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.ZIndex = 22
themeLabel.Parent = swContent

local swatchRow1 = Instance.new("Frame")
swatchRow1.Size = UDim2.new(1, 0, 0, 26)
swatchRow1.Position = UDim2.fromOffset(0, 18)
swatchRow1.BackgroundTransparency = 1
swatchRow1.ZIndex = 22
swatchRow1.Parent = swContent

local swatchRow2 = Instance.new("Frame")
swatchRow2.Size = UDim2.new(1, 0, 0, 26)
swatchRow2.Position = UDim2.fromOffset(0, 50)
swatchRow2.BackgroundTransparency = 1
swatchRow2.ZIndex = 22
swatchRow2.Parent = swContent

local swatchStrokes = {}
for i, th in ipairs(THEMES) do
    local row = (i <= 4) and swatchRow1 or swatchRow2
    local idx = ((i - 1) % 4)

    local sw = Instance.new("TextButton")
    sw.Size = UDim2.fromOffset(26, 26)
    sw.Position = UDim2.fromOffset(idx * 32, 0)
    sw.BackgroundColor3 = th.Accent
    sw.BorderSizePixel = 0
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.ZIndex = 23
    sw.Parent = row

    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(1, 0); sc.Parent = sw

    local ss = Instance.new("UIStroke")
    ss.Color = Color3.fromRGB(255, 255, 255)
    ss.Thickness = 2
    ss.Transparency = (i == 1) and 0 or 0.75
    ss.Parent = sw

    swatchStrokes[i] = ss

    sw.MouseEnter:Connect(function()
        TweenService:Create(sw, EASE.quick,
            { Size = UDim2.fromOffset(30, 30),
              Position = UDim2.fromOffset(idx * 32 - 2, -2) }):Play()
    end)
    sw.MouseLeave:Connect(function()
        TweenService:Create(sw, EASE.quick,
            { Size = UDim2.fromOffset(26, 26),
              Position = UDim2.fromOffset(idx * 32, 0) }):Play()
    end)
    sw.MouseButton1Click:Connect(function()
        applyTheme(th)
        for j, st in ipairs(swatchStrokes) do
            st.Transparency = (j == i) and 0 or 0.75
        end
    end)
end

-- divider
local swDiv1 = Instance.new("Frame")
swDiv1.Size = UDim2.new(1, 0, 0, 1)
swDiv1.Position = UDim2.fromOffset(0, 90)
swDiv1.BackgroundColor3 = COL.divider
swDiv1.BorderSizePixel = 0
swDiv1.ZIndex = 22
swDiv1.Parent = swContent

-- FPS Boost row
local boostRow = Instance.new("Frame")
boostRow.Size = UDim2.new(1, 0, 0, 54)
boostRow.Position = UDim2.fromOffset(0, 100)
boostRow.BackgroundTransparency = 1
boostRow.ZIndex = 22
boostRow.Parent = swContent

local bTile = Instance.new("Frame")
bTile.Size = UDim2.fromOffset(32, 32)
bTile.Position = UDim2.fromOffset(0, 11)
bTile.BackgroundColor3 = COL.accent
bTile.BorderSizePixel = 0
bTile.ZIndex = 23
bTile.Parent = boostRow
reg(bTile, "BackgroundColor3")

local btc = Instance.new("UICorner")
btc.CornerRadius = UDim.new(0, 10); btc.Parent = bTile

local bImg = Instance.new("ImageLabel")
bImg.Size = UDim2.fromOffset(16, 16)
bImg.Position = UDim2.fromOffset(8, 8)
bImg.BackgroundTransparency = 1
bImg.Image = "rbxassetid://6031094678"
bImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
bImg.ZIndex = 24
bImg.Parent = bTile

local bTitle = Instance.new("TextLabel")
bTitle.Size = UDim2.new(1, -70, 0, 15)
bTitle.Position = UDim2.fromOffset(44, 10)
bTitle.BackgroundTransparency = 1
bTitle.Text = "FPS Boost Ultra"
bTitle.TextColor3 = COL.text
bTitle.Font = Enum.Font.GothamBold
bTitle.TextSize = 12
bTitle.TextXAlignment = Enum.TextXAlignment.Left
bTitle.ZIndex = 23
bTitle.Parent = boostRow

local bSub = Instance.new("TextLabel")
bSub.Size = UDim2.new(1, -70, 0, 12)
bSub.Position = UDim2.fromOffset(44, 27)
bSub.BackgroundTransparency = 1
bSub.Text = "Reduce graphics"
bSub.TextColor3 = COL.sub
bSub.Font = Enum.Font.GothamMedium
bSub.TextSize = 9
bSub.TextXAlignment = Enum.TextXAlignment.Left
bSub.ZIndex = 23
bSub.Parent = boostRow

local fpsSwitch = makeSwitch(boostRow, 14)

-- action buttons
local function actionBtn(parent, y, txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.Position = UDim2.fromOffset(0, y)
    b.BackgroundColor3 = Color3.fromRGB(247, 248, 251)
    b.BorderSizePixel = 0
    b.Text = txt
    b.TextColor3 = COL.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.AutoButtonColor = false
    b.ZIndex = 23
    b.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 11); c.Parent = b

    local s = Instance.new("UIStroke")
    s.Color = COL.stroke; s.Thickness = 1; s.Transparency = 0.4
    s.Parent = b

    b.MouseEnter:Connect(function()
        TweenService:Create(b, EASE.quick,
            { BackgroundColor3 = Color3.fromRGB(238, 241, 246) }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, EASE.quick,
            { BackgroundColor3 = Color3.fromRGB(247, 248, 251) }):Play()
    end)

    return b
end

local purgeBtn = actionBtn(swContent, 164, "Purge World Effects")
purgeBtn.MouseButton1Click:Connect(function()
    task.spawn(function() pcall(scanFX) end)
end)

local ramBtn = actionBtn(swContent, 204, "Free Memory")
ramBtn.MouseButton1Click:Connect(freeRAM)

--============================================================--
-- SETTINGS POSITIONING
--============================================================--
-- Places the settings window to the LEFT of the main card,
-- vertically centered with it. Follows the main card when dragged.
local function updateSettingsPosition()
    local mAbs = main.AbsolutePosition
    local mSize = main.AbsoluteSize
    local gap = 12
    local swW = 260
    -- position: right edge of settings window = left edge of main - gap
    settingsWindow.Position = UDim2.fromOffset(
        mAbs.X - swW - gap,
        mAbs.Y + (mSize.Y - 320) / 2
    )
end

--============================================================--
-- STATE
--============================================================--
local function updateDot()
    statusDot.Visible = antiOn or lootOn or boostOn
end

lootSwitch.button.Activated:Connect(function()
    local s = not lootOn
    lootSwitch.setState(s, true); lootOn = s
    if s then enableLoot() else disableLoot() end
    updateDot()
end)

antiSwitch.button.Activated:Connect(function()
    local s = not antiOn
    antiSwitch.setState(s, true); antiOn = s
    if s then startAnti() else stopAnti() end
    updateDot()
end)

fpsSwitch.button.Activated:Connect(function()
    local s = not boostOn
    fpsSwitch.setState(s, true)
    if s then
        local ok = pcall(enableBoost)
        if not ok then fpsSwitch.setState(false, true) end
    else
        pcall(disableBoost)
    end
    updateDot()
end)

--============================================================--
-- SETTINGS OPEN/CLOSE
--============================================================--
local settingsOpen = false

local function setSettings(open)
    if settingsOpen == open then return end
    settingsOpen = open

    if open then
        updateSettingsPosition()
        settingsWindow.Visible = true
        settingsWindow.BackgroundTransparency = 1
        settingsWindow.Size = UDim2.fromOffset(220, 280)

        TweenService:Create(settingsWindow, EASE.spring, {
            Size = UDim2.fromOffset(260, 320),
        }):Play()
        TweenService:Create(settingsWindow, EASE.fade, {
            BackgroundTransparency = 0.02,
        }):Play()

        -- slight slide-in from left
        local basePos = settingsWindow.Position
        settingsWindow.Position = UDim2.new(
            basePos.X.Scale, basePos.X.Offset - 20,
            basePos.Y.Scale, basePos.Y.Offset)
        TweenService:Create(settingsWindow, EASE.slide, {
            Position = basePos,
        }):Play()
    else
        TweenService:Create(settingsWindow, EASE.fade, {
            BackgroundTransparency = 1,
        }):Play()
        local t = TweenService:Create(settingsWindow, EASE.quick, {
            Size = UDim2.fromOffset(220, 280),
        })
        t.Completed:Connect(function()
            if not settingsOpen then
                settingsWindow.Visible = false
                settingsWindow.Size = UDim2.fromOffset(260, 320)
            end
        end)
        t:Play()
    end
end

--============================================================--
-- EXPAND
--============================================================--
local expanded = false
local animToken = 0

local function setExpanded(state)
    animToken = animToken + 1
    local my = animToken
    expanded = state

    local tSize = state and UDim2.fromOffset(W_EXP, H_EXP)
                       or UDim2.fromOffset(W_COL, H_COL)
    local tRadius = state and UDim.new(0, 22)
                          or UDim.new(0, H_COL / 2)

    TweenService:Create(main, EASE.spring, { Size = tSize }):Play()
    TweenService:Create(corner, EASE.spring, { CornerRadius = tRadius }):Play()
    TweenService:Create(title, EASE.smooth,
        { TextTransparency = state and 0 or 1 }):Play()
    TweenService:Create(subtitle, EASE.smooth,
        { TextTransparency = state and 0 or 1 }):Play()
    TweenService:Create(fpsNum, EASE.smooth,
        { TextTransparency = state and 1 or 0 }):Play()
    TweenService:Create(fpsTag, EASE.smooth,
        { TextTransparency = state and 1 or 0 }):Play()

    minBtn.Visible = true
    setBtn.Visible = true
    TweenService:Create(minBtn, EASE.smooth, {
        BackgroundTransparency = state and 0 or 1,
        TextTransparency = state and 0 or 1,
    }):Play()
    TweenService:Create(setBtn, EASE.smooth, {
        BackgroundTransparency = state and 0 or 1,
    }):Play()
    TweenService:Create(setIcon, EASE.smooth, {
        ImageTransparency = state and 0 or 1,
    }):Play()

    if state then
        body.Visible = true
        TweenService:Create(body, EASE.smooth,
            { GroupTransparency = 0 }):Play()
    else
        TweenService:Create(body, EASE.smooth,
            { GroupTransparency = 1 }):Play()
    end

    task.delay(0.6, function()
        if my ~= animToken then return end
        if not expanded then
            body.Visible = false
            minBtn.Visible = false
            setBtn.Visible = false
        end
    end)
end

--============================================================--
-- DRAG (main card + settings follow)
--============================================================--
local headerBtn = Instance.new("TextButton")
headerBtn.Size = UDim2.new(1, 0, 0, 50)
headerBtn.Position = UDim2.fromOffset(0, 0)
headerBtn.BackgroundTransparency = 1
headerBtn.Text = ""
headerBtn.AutoButtonColor = false
headerBtn.ZIndex = 30
headerBtn.Parent = main

local dragStart, dragBasePos, dragging = nil, nil, false

headerBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        dragBasePos = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        main.Position = UDim2.new(
            dragBasePos.X.Scale, dragBasePos.X.Offset + d.X,
            dragBasePos.Y.Scale, dragBasePos.Y.Offset + d.Y)
        if settingsOpen then updateSettingsPosition() end
    end
end)

UIS.InputEnded:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        local moved = (input.Position - dragStart).Magnitude
        dragging = false
        dragStart, dragBasePos = nil, nil
        if moved < 6 then setExpanded(not expanded) end
    end
end)

minBtn.MouseButton1Click:Connect(function() setExpanded(false) end)

setBtn.MouseButton1Click:Connect(function()
    setSettings(not settingsOpen)
end)

swClose.MouseButton1Click:Connect(function()
    setSettings(false)
end)

-- drag settings window
local swDragStart, swDragBase, swDragging = nil, nil, false

swHeaderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        swDragging = true
        swDragStart = input.Position
        swDragBase = settingsWindow.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not swDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - swDragStart
        settingsWindow.Position = UDim2.new(
            swDragBase.X.Scale, swDragBase.X.Offset + d.X,
            swDragBase.Y.Scale, swDragBase.Y.Offset + d.Y)
    end
end)

UIS.InputEnded:Connect(function(input)
    if not swDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        swDragging = false
        swDragStart, swDragBase = nil, nil
    end
end)

--============================================================--
-- RESPAWN
--============================================================--
LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    if antiOn then
        antiConn, antiPost, antiAdded = nil, nil, nil
        fakeHum, realHum = nil, nil
        velCon, velAtt = nil, nil
        bodySnap = {}
        startAnti()
    end
    if lootOn then disableLoot(); enableLoot() end
end)

--============================================================--
-- BOOT
--============================================================--
setExpanded(true)

print("[Hyko] v5 loaded · Settings window standalone · No glow · No key system")