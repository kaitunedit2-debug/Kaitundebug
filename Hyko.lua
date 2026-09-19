--============================================================--
--  Hyko · iOS Dropdown UI  v3  (Polished Redesign)
--  Key : "Hyko"
--============================================================--

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local LP           = Players.LocalPlayer

--============================================================--
-- [1] MOUNT
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
-- [2] MOVE INPUT
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
-- [3] ANTI-RAGDOLL ENGINE
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
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

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
-- [4] FAST LOOT
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
-- [5] FPS BOOST
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
-- [6] PALETTE + THEMES
--============================================================--
local COL = {
    bg      = Color3.fromRGB(255, 255, 255),
    card    = Color3.fromRGB(249, 250, 252),
    text    = Color3.fromRGB(15, 17, 22),
    sub     = Color3.fromRGB(140, 145, 155),
    divider = Color3.fromRGB(238, 240, 244),
    track   = Color3.fromRGB(230, 232, 238),
    accent  = Color3.fromRGB(10, 132, 255),
    green   = Color3.fromRGB(52, 199, 89),
    red     = Color3.fromRGB(255, 69, 58),
    stroke  = Color3.fromRGB(232, 234, 240),
    shadow  = Color3.fromRGB(0, 0, 0),
}

local THEMES = {
    { Name = "Blue",   Accent = Color3.fromRGB(10, 132, 255)  },
    { Name = "Green",  Accent = Color3.fromRGB(52, 199, 89)   },
    { Name = "Violet", Accent = Color3.fromRGB(139, 92, 246)  },
    { Name = "Rose",   Accent = Color3.fromRGB(236, 72, 153)  },
    { Name = "Crimson",Accent = Color3.fromRGB(255, 69, 58)   },
    { Name = "Amber",  Accent = Color3.fromRGB(255, 159, 10)  },
    { Name = "Teal",   Accent = Color3.fromRGB(48, 176, 199)  },
    { Name = "Slate",  Accent = Color3.fromRGB(90, 100, 115)  },
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
-- [7] EASING
--============================================================--
local EASE = {
    smooth  = TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    spring  = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    quick   = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    fade    = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    slide   = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

--============================================================--
-- [8] DIMENSIONS
--============================================================--
local W_COL, H_COL = 120, 58
local W_EXP, H_EXP = 340, 420

--============================================================--
-- [9] KEY SYSTEM  (elegant)
--============================================================--
local VALID_KEY = "hyko"

local keyGui = Instance.new("ScreenGui")
keyGui.Name = "HykoKey"
keyGui.IgnoreGuiInset = true
keyGui.DisplayOrder = 999
mountGui(keyGui)

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
backdrop.BackgroundTransparency = 0.35
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Parent = keyGui

local keyCard = Instance.new("Frame")
keyCard.AnchorPoint = Vector2.new(0.5, 0.5)
keyCard.Position = UDim2.fromScale(0.5, 0.5)
keyCard.Size = UDim2.fromOffset(340, 290)
keyCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
keyCard.BackgroundTransparency = 0.02
keyCard.BorderSizePixel = 0
keyCard.ZIndex = 2
keyCard.Parent = keyGui

local kcCorner = Instance.new("UICorner")
kcCorner.CornerRadius = UDim.new(0, 24)
kcCorner.Parent = keyCard

local kcStroke = Instance.new("UIStroke")
kcStroke.Color = Color3.fromRGB(255, 255, 255)
kcStroke.Thickness = 1
kcStroke.Transparency = 0.55
kcStroke.Parent = keyCard

-- soft outer glow (single layer)
do
    local g = Instance.new("Frame")
    g.BackgroundTransparency = 1
    g.BorderSizePixel = 0
    g.Size = UDim2.new(1, 12, 1, 12)
    g.Position = UDim2.new(0, -6, 0, -6)
    g.ZIndex = 1
    g.Parent = keyCard
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 30); c.Parent = g
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Thickness = 1.2; s.Transparency = 0.6
    s.Parent = g
end

-- logo circle
local kLogo = Instance.new("Frame")
kLogo.Size = UDim2.fromOffset(56, 56)
kLogo.Position = UDim2.new(0.5, -28, 0, 30)
kLogo.BackgroundColor3 = COL.accent
kLogo.BorderSizePixel = 0
kLogo.ZIndex = 3
kLogo.Parent = keyCard

local kLogoCorner = Instance.new("UICorner")
kLogoCorner.CornerRadius = UDim.new(1, 0)
kLogoCorner.Parent = kLogo

local kLogoTxt = Instance.new("TextLabel")
kLogoTxt.Size = UDim2.fromScale(1, 1)
kLogoTxt.BackgroundTransparency = 1
kLogoTxt.Text = "H"
kLogoTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
kLogoTxt.Font = Enum.Font.GothamBold
kLogoTxt.TextSize = 28
kLogoTxt.ZIndex = 4
kLogoTxt.Parent = kLogo
reg(kLogo, "BackgroundColor3")

local kTitle = Instance.new("TextLabel")
kTitle.Size = UDim2.new(1, 0, 0, 26)
kTitle.Position = UDim2.fromOffset(0, 98)
kTitle.BackgroundTransparency = 1
kTitle.Text = "Hyko"
kTitle.TextColor3 = COL.text
kTitle.Font = Enum.Font.GothamBold
kTitle.TextSize = 22
kTitle.ZIndex = 3
kTitle.Parent = keyCard

local kSub = Instance.new("TextLabel")
kSub.Size = UDim2.new(1, 0, 0, 16)
kSub.Position = UDim2.fromOffset(0, 126)
kSub.BackgroundTransparency = 1
kSub.Text = "Enter your access key"
kSub.TextColor3 = COL.sub
kSub.Font = Enum.Font.GothamMedium
kSub.TextSize = 11
kSub.ZIndex = 3
kSub.Parent = keyCard

-- input
local kInputWrap = Instance.new("Frame")
kInputWrap.Size = UDim2.new(1, -56, 0, 46)
kInputWrap.Position = UDim2.fromOffset(28, 162)
kInputWrap.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
kInputWrap.BorderSizePixel = 0
kInputWrap.ZIndex = 3
kInputWrap.Parent = keyCard

local kIWCorner = Instance.new("UICorner")
kIWCorner.CornerRadius = UDim.new(0, 14)
kIWCorner.Parent = kInputWrap

local kIWStroke = Instance.new("UIStroke")
kIWStroke.Color = COL.stroke
kIWStroke.Thickness = 1
kIWStroke.Transparency = 0.25
kIWStroke.Parent = kInputWrap

local kInput = Instance.new("TextBox")
kInput.Size = UDim2.new(1, -28, 1, 0)
kInput.Position = UDim2.fromOffset(14, 0)
kInput.BackgroundTransparency = 1
kInput.PlaceholderText = "Access key"
kInput.Text = ""
kInput.TextColor3 = COL.text
kInput.PlaceholderColor3 = COL.sub
kInput.Font = Enum.Font.GothamBold
kInput.TextSize = 14
kInput.TextXAlignment = Enum.TextXAlignment.Left
kInput.ClearTextOnFocus = false
kInput.ZIndex = 4
kInput.Parent = kInputWrap

-- unlock button
local kBtn = Instance.new("TextButton")
kBtn.Size = UDim2.new(1, -56, 0, 46)
kBtn.Position = UDim2.fromOffset(28, 218)
kBtn.BackgroundColor3 = COL.accent
kBtn.BorderSizePixel = 0
kBtn.Text = "Unlock"
kBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
kBtn.Font = Enum.Font.GothamBold
kBtn.TextSize = 14
kBtn.AutoButtonColor = false
kBtn.ZIndex = 3
kBtn.Parent = keyCard
reg(kBtn, "BackgroundColor3")

local kBtnCorner = Instance.new("UICorner")
kBtnCorner.CornerRadius = UDim.new(0, 14)
kBtnCorner.Parent = kBtn

kBtn.MouseEnter:Connect(function()
    TweenService:Create(kBtn, EASE.quick,
        { BackgroundColor3 = COL.accent:Lerp(Color3.new(1,1,1), 0.15) }):Play()
end)
kBtn.MouseLeave:Connect(function()
    TweenService:Create(kBtn, EASE.quick,
        { BackgroundColor3 = COL.accent }):Play()
end)

--============================================================--
-- [10] MAIN GUI
--============================================================--
local screen = Instance.new("ScreenGui")
screen.Name = "HykoLite"
screen.IgnoreGuiInset = true
screen.Enabled = false
mountGui(screen)

local main = Instance.new("Frame")
main.Name = "HykoMain"
main.AnchorPoint = Vector2.new(1, 0)
main.Position = UDim2.new(1, -22, 0, 22)
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
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Thickness = 1
mainStroke.Transparency = 0.35
mainStroke.Parent = main

-- gradient inside card for subtle depth
local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(247,249,252)),
})
mainGrad.Rotation = 90
mainGrad.Parent = main

-- soft glow (single layer)
do
    local g = Instance.new("Frame")
    g.BackgroundTransparency = 1
    g.BorderSizePixel = 0
    g.Size = UDim2.new(1, 10, 1, 10)
    g.Position = UDim2.new(0, -5, 0, -5)
    g.ZIndex = 9
    g.Parent = main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, H_COL / 2 + 5); c.Parent = g
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Thickness = 1.2; s.Transparency = 0.65
    s.Parent = g
end

--============================================================--
-- [11] HEADER
--============================================================--
local avatarWrap = Instance.new("Frame")
avatarWrap.Size = UDim2.fromOffset(34, 34)
avatarWrap.Position = UDim2.fromOffset(12, 12)
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
avStroke.Thickness = 2
avStroke.Transparency = 0.15
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
statusDot.Size = UDim2.fromOffset(10, 10)
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

-- FPS counter
local fpsWrap = Instance.new("Frame")
fpsWrap.Size = UDim2.fromOffset(56, 34)
fpsWrap.Position = UDim2.fromOffset(54, 12)
fpsWrap.BackgroundTransparency = 1
fpsWrap.ZIndex = 12
fpsWrap.Parent = main

local fpsNum = Instance.new("TextLabel")
fpsNum.Size = UDim2.new(1, 0, 0, 22)
fpsNum.BackgroundTransparency = 1
fpsNum.Text = "60"
fpsNum.TextColor3 = COL.accent
fpsNum.Font = Enum.Font.GothamBold
fpsNum.TextSize = 18
fpsNum.TextXAlignment = Enum.TextXAlignment.Left
fpsNum.ZIndex = 13
fpsNum.Parent = fpsWrap
reg(fpsNum, "TextColor3")

local fpsTag = Instance.new("TextLabel")
fpsTag.Size = UDim2.new(1, 0, 0, 12)
fpsTag.Position = UDim2.fromOffset(0, 22)
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

-- name + handle (expanded)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 180, 0, 18)
title.Position = UDim2.fromOffset(54, 12)
title.BackgroundTransparency = 1
title.Text = LP.DisplayName
title.TextColor3 = COL.text
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTruncate = Enum.TextTruncate.AtEnd
title.TextTransparency = 1
title.ZIndex = 12
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(0, 180, 0, 14)
subtitle.Position = UDim2.fromOffset(54, 30)
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

-- header action buttons
local function makeHeaderBtn(icon, xoff)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(28, 28)
    b.AnchorPoint = Vector2.new(1, 0)
    b.Position = UDim2.new(1, xoff, 0, 15)
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
    img.Size = UDim2.fromOffset(14, 14)
    img.Position = UDim2.fromOffset(7, 7)
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

local setBtn, setIcon = makeHeaderBtn("rbxassetid://6031280882", -46)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(28, 28)
minBtn.AnchorPoint = Vector2.new(1, 0)
minBtn.Position = UDim2.new(1, -12, 0, 15)
minBtn.BackgroundColor3 = Color3.fromRGB(243, 245, 249)
minBtn.BorderSizePixel = 0
minBtn.Text = "−"
minBtn.TextColor3 = COL.text
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 20
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
-- [12] BODY
--============================================================--
local body = Instance.new("CanvasGroup")
body.Size = UDim2.new(1, -28, 1, -80)
body.Position = UDim2.fromOffset(14, 62)
body.BackgroundTransparency = 1
body.GroupTransparency = 1
body.ZIndex = 11
body.Parent = main

-- section label
local function sectionLabel(y, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 14)
    l.Position = UDim2.fromOffset(0, y)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = COL.sub
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 12
    l.Parent = body
    return l
end

-- feature card (mini card containing a single feature)
local function featureCard(y, icon, titleTxt, subTxt)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 60)
    card.Position = UDim2.fromOffset(0, y)
    card.BackgroundColor3 = COL.card
    card.BorderSizePixel = 0
    card.ZIndex = 12
    card.Parent = body

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 14); c.Parent = card

    local s = Instance.new("UIStroke")
    s.Color = COL.stroke; s.Thickness = 1; s.Transparency = 0.5
    s.Parent = card

    -- icon tile
    local tile = Instance.new("Frame")
    tile.Size = UDim2.fromOffset(36, 36)
    tile.Position = UDim2.fromOffset(12, 12)
    tile.BackgroundColor3 = COL.accent
    tile.BorderSizePixel = 0
    tile.ZIndex = 13
    tile.Parent = card
    reg(tile, "BackgroundColor3")

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 11); tc.Parent = tile

    local tileGrad = Instance.new("UIGradient")
    tileGrad.Rotation = 135
    tileGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.35),
    })
    tileGrad.Parent = tile

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromOffset(18, 18)
    img.Position = UDim2.fromOffset(9, 9)
    img.BackgroundTransparency = 1
    img.Image = icon
    img.ImageColor3 = Color3.fromRGB(255, 255, 255)
    img.ZIndex = 14
    img.Parent = tile

    -- title
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -140, 0, 16)
    t.Position = UDim2.fromOffset(60, 12)
    t.BackgroundTransparency = 1
    t.Text = titleTxt
    t.TextColor3 = COL.text
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 13
    t.Parent = card

    local st = Instance.new("TextLabel")
    st.Size = UDim2.new(1, -140, 0, 13)
    st.Position = UDim2.fromOffset(60, 32)
    st.BackgroundTransparency = 1
    st.Text = subTxt
    st.TextColor3 = COL.sub
    st.Font = Enum.Font.GothamMedium
    st.TextSize = 10
    st.TextXAlignment = Enum.TextXAlignment.Left
    st.ZIndex = 13
    st.Parent = card

    return card
end

-- toggle switch (refined iOS)
local function makeSwitch(parent, y)
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(48, 28)
    track.AnchorPoint = Vector2.new(1, 0)
    track.Position = UDim2.new(1, -12, 0, y)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.ZIndex = 14
    track.Parent = parent

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

    -- knob with shadow
    local knobShadow = Instance.new("Frame")
    knobShadow.Size = UDim2.fromOffset(24, 24)
    knobShadow.Position = UDim2.fromOffset(2, 2)
    knobShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    knobShadow.BackgroundTransparency = 0.85
    knobShadow.BorderSizePixel = 0
    knobShadow.ZIndex = 14
    knobShadow.Parent = track

    local ksc = Instance.new("UICorner")
    ksc.CornerRadius = UDim.new(1, 0); ksc.Parent = knobShadow

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(24, 24)
    knob.Position = UDim2.fromOffset(2, 1.5)
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
        local pos = state and UDim2.new(1, -26, 0, 1.5) or UDim2.fromOffset(2, 1.5)
        local spos = state and UDim2.new(1, -26, 0, 2)   or UDim2.fromOffset(2, 2)
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

-- slider
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
    knobShadow.Position = UDim2.new(0, 0, 0.5, 1)
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
        knobShadow.Position = UDim2.new(t, 0, 0.5, 1)
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
-- [13] BODY CONTENT
--============================================================--
sectionLabel(0, "FEATURES")

local lootCard = featureCard(18, "rbxassetid://6031075931", "Fast Loot",
    "Auto-collect prompts · Key E")
local lootSwitch = makeSwitch(lootCard, 16)

local antiCard = featureCard(86, "rbxassetid://6035075453", "Anti-Ragdoll",
    "Server-safe body · hard lock")
local antiSwitch = makeSwitch(antiCard, 16)

sectionLabel(158, "SPEED CONTROL")

local sliderValue = Instance.new("TextLabel")
sliderValue.Size = UDim2.new(0, 60, 0, 22)
sliderValue.Position = UDim2.new(1, -60, 0, 174)
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
svCorner.CornerRadius = UDim.new(0, 8); svCorner.Parent = sliderValue

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, 0, 0, 6)
sliderTrack.Position = UDim2.fromOffset(0, 208)
sliderTrack.BackgroundTransparency = 1
sliderTrack.ZIndex = 13
sliderTrack.Parent = body

local speedSlider = makeSlider(sliderTrack, 0, 20, 800, antiSpeed, function(v)
    antiSpeed = v
    sliderValue.Text = tostring(v)
end)

--============================================================--
-- [14] SETTINGS PANEL (drawer)
--============================================================--
local settingsPanel = Instance.new("Frame")
settingsPanel.Name = "HykoSettings"
settingsPanel.Size = UDim2.new(1, 0, 0, 268)
settingsPanel.Position = UDim2.new(0, 0, 1, 8)
settingsPanel.BackgroundColor3 = COL.bg
settingsPanel.BackgroundTransparency = 0.02
settingsPanel.BorderSizePixel = 0
settingsPanel.ZIndex = 18
settingsPanel.Visible = false
settingsPanel.Parent = main

local spCorner = Instance.new("UICorner")
spCorner.CornerRadius = UDim.new(0, 22); spCorner.Parent = settingsPanel

local spStroke = Instance.new("UIStroke")
spStroke.Color = Color3.fromRGB(255, 255, 255)
spStroke.Thickness = 1; spStroke.Transparency = 0.4
spStroke.Parent = settingsPanel

-- small divider at top
local spTopLine = Instance.new("Frame")
spTopLine.Size = UDim2.new(0, 40, 0, 4)
spTopLine.Position = UDim2.new(0.5, -20, 0, 8)
spTopLine.BackgroundColor3 = Color3.fromRGB(215, 218, 224)
spTopLine.BorderSizePixel = 0
spTopLine.ZIndex = 19
spTopLine.Parent = settingsPanel

local spTopCorner = Instance.new("UICorner")
spTopCorner.CornerRadius = UDim.new(1, 0); spTopCorner.Parent = spTopLine

-- Theme section
local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, -32, 0, 14)
themeLabel.Position = UDim2.fromOffset(20, 24)
themeLabel.BackgroundTransparency = 1
themeLabel.Text = "ACCENT COLOR"
themeLabel.TextColor3 = COL.sub
themeLabel.Font = Enum.Font.GothamBold
themeLabel.TextSize = 10
themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.ZIndex = 19
themeLabel.Parent = settingsPanel

local swatchRow = Instance.new("Frame")
swatchRow.Size = UDim2.new(1, -32, 0, 30)
swatchRow.Position = UDim2.fromOffset(20, 44)
swatchRow.BackgroundTransparency = 1
swatchRow.ZIndex = 19
swatchRow.Parent = settingsPanel

local swatchStrokes = {}
for i, th in ipairs(THEMES) do
    local sw = Instance.new("TextButton")
    sw.Size = UDim2.fromOffset(28, 28)
    sw.Position = UDim2.fromOffset((i - 1) * 34, 0)
    sw.BackgroundColor3 = th.Accent
    sw.BorderSizePixel = 0
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.ZIndex = 20
    sw.Parent = swatchRow

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
            { Size = UDim2.fromOffset(32, 32),
              Position = UDim2.fromOffset((i - 1) * 34 - 2, -2) }):Play()
    end)
    sw.MouseLeave:Connect(function()
        TweenService:Create(sw, EASE.quick,
            { Size = UDim2.fromOffset(28, 28),
              Position = UDim2.fromOffset((i - 1) * 34, 0) }):Play()
    end)
    sw.MouseButton1Click:Connect(function()
        applyTheme(th)
        for j, st in ipairs(swatchStrokes) do
            st.Transparency = (j == i) and 0 or 0.75
        end
    end)
end

-- divider
local spDiv = Instance.new("Frame")
spDiv.Size = UDim2.new(1, -32, 0, 1)
spDiv.Position = UDim2.fromOffset(20, 88)
spDiv.BackgroundColor3 = COL.divider
spDiv.BorderSizePixel = 0
spDiv.ZIndex = 19
spDiv.Parent = settingsPanel

-- FPS Boost row
local boostRow = Instance.new("Frame")
boostRow.Size = UDim2.new(1, -32, 0, 60)
boostRow.Position = UDim2.fromOffset(20, 100)
boostRow.BackgroundTransparency = 1
boostRow.ZIndex = 19
boostRow.Parent = settingsPanel

local bTile = Instance.new("Frame")
bTile.Size = UDim2.fromOffset(36, 36)
bTile.Position = UDim2.fromOffset(0, 12)
bTile.BackgroundColor3 = COL.accent
bTile.BorderSizePixel = 0
bTile.ZIndex = 20
bTile.Parent = boostRow
reg(bTile, "BackgroundColor3")

local btc = Instance.new("UICorner")
btc.CornerRadius = UDim.new(0, 11); btc.Parent = bTile

local bImg = Instance.new("ImageLabel")
bImg.Size = UDim2.fromOffset(18, 18)
bImg.Position = UDim2.fromOffset(9, 9)
bImg.BackgroundTransparency = 1
bImg.Image = "rbxassetid://6031094678"
bImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
bImg.ZIndex = 21
bImg.Parent = bTile

local bTitle = Instance.new("TextLabel")
bTitle.Size = UDim2.new(1, -70, 0, 16)
bTitle.Position = UDim2.fromOffset(48, 12)
bTitle.BackgroundTransparency = 1
bTitle.Text = "FPS Boost Ultra"
bTitle.TextColor3 = COL.text
bTitle.Font = Enum.Font.GothamBold
bTitle.TextSize = 13
bTitle.TextXAlignment = Enum.TextXAlignment.Left
bTitle.ZIndex = 20
bTitle.Parent = boostRow

local bSub = Instance.new("TextLabel")
bSub.Size = UDim2.new(1, -70, 0, 13)
bSub.Position = UDim2.fromOffset(48, 32)
bSub.BackgroundTransparency = 1
bSub.Text = "Reduce graphics · strip effects"
bSub.TextColor3 = COL.sub
bSub.Font = Enum.Font.GothamMedium
bSub.TextSize = 10
bSub.TextXAlignment = Enum.TextXAlignment.Left
bSub.ZIndex = 20
bSub.Parent = boostRow

local fpsSwitch = makeSwitch(boostRow, 16)

-- action buttons
local function actionBtn(parent, y, txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -40, 0, 38)
    b.Position = UDim2.fromOffset(20, y)
    b.BackgroundColor3 = Color3.fromRGB(247, 248, 251)
    b.BorderSizePixel = 0
    b.Text = txt
    b.TextColor3 = COL.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.ZIndex = 20
    b.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12); c.Parent = b

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

local purgeBtn = actionBtn(settingsPanel, 168, "Purge World Effects")
purgeBtn.MouseButton1Click:Connect(function()
    task.spawn(function() pcall(scanFX) end)
end)

local ramBtn = actionBtn(settingsPanel, 214, "Free Memory")
ramBtn.MouseButton1Click:Connect(freeRAM)

--============================================================--
-- [15] STATE
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
-- [16] EXPAND / COLLAPSE  (with token race protection)
--============================================================--
local expanded = false
local animToken = 0
local settingsOpen = false

local function setSettings(open)
    if settingsOpen == open then return end
    settingsOpen = open
    if open then
        settingsPanel.Visible = true
        settingsPanel.Position = UDim2.new(0, 0, 1, -8)
        TweenService:Create(settingsPanel, EASE.slide,
            { Position = UDim2.new(0, 0, 1, 8) }):Play()
    else
        local t = TweenService:Create(settingsPanel, EASE.fade,
            { Position = UDim2.new(0, 0, 1, -8) })
        t.Completed:Connect(function()
            if not settingsOpen then settingsPanel.Visible = false end
        end)
        t:Play()
    end
end

local function setExpanded(state)
    animToken = animToken + 1
    local my = animToken
    expanded = state

    if not state then setSettings(false) end

    local tSize = state and UDim2.fromOffset(W_EXP, H_EXP)
                       or UDim2.fromOffset(W_COL, H_COL)
    local tRadius = state and UDim.new(0, 24)
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
-- [17] HEADER DRAG + TAP
--============================================================--
local headerBtn = Instance.new("TextButton")
headerBtn.Size = UDim2.new(1, 0, 0, 56)
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

minBtn.MouseButton1Click:Connect(function()
    setExpanded(false)
end)

setBtn.MouseButton1Click:Connect(function()
    if not expanded then
        setExpanded(true)
        task.wait(0.5)
    end
    setSettings(not settingsOpen)
end)

--============================================================--
-- [18] RESPAWN
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
-- [19] KEY LOGIC
--============================================================--
local unlocked = false

local function tryUnlock()
    if unlocked then return end
    local typed = string.lower(kInput.Text or ""):gsub("%s", "")
    if typed == VALID_KEY then
        unlocked = true
        kInput.Text = ""
        kBtn.Text = "Unlocked"
        kBtn.BackgroundColor3 = COL.green

        TweenService:Create(keyCard, EASE.smooth,
            { Size = UDim2.fromOffset(300, 240) }):Play()
        TweenService:Create(backdrop, EASE.smooth,
            { BackgroundTransparency = 1 }):Play()

        task.wait(0.42)
        keyGui.Enabled = false
        screen.Enabled = true
        setExpanded(true)
    else
        kInput.Text = ""
        kInputWrap.BackgroundColor3 = Color3.fromRGB(255, 235, 233)
        TweenService:Create(kInputWrap, TweenInfo.new(0.35),
            { BackgroundColor3 = Color3.fromRGB(245, 247, 250) }):Play()

        local base = keyCard.Position
        task.spawn(function()
            for _, off in ipairs({ -8, 8, -5, 5, -2, 2, 0 }) do
                keyCard.Position = UDim2.new(
                    base.X.Scale, base.X.Offset + off,
                    base.Y.Scale, base.Y.Offset)
                task.wait(0.028)
            end
            keyCard.Position = base
        end)
    end
end

kBtn.MouseButton1Click:Connect(tryUnlock)
kInput.FocusLost:Connect(function(enter)
    if enter then tryUnlock() end
end)

task.spawn(function()
    task.wait(0.5)
    pcall(function() kInput:CaptureFocus() end)
end)

--============================================================--
-- [20] BOOT
--============================================================--
keyGui.Enabled = true
screen.Enabled = false

keyCard.Size = UDim2.fromOffset(300, 250)
TweenService:Create(keyCard, EASE.spring,
    { Size = UDim2.fromOffset(340, 290) }):Play()

print("[Hyko] v3 loaded · Key: Hyko")