--============================================================--
--  Hyko · iOS UI  v7
--  · New shield icon (Lucide, verified)
--  · Background theme: Light / Dark
--============================================================--

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local LP           = Players.LocalPlayer

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
-- COLOR PALETTES (light + dark)
--============================================================--
local LIGHT = {
    bg      = Color3.fromRGB(255, 255, 255),
    grad1   = Color3.fromRGB(255, 255, 255),
    grad2   = Color3.fromRGB(247, 249, 252),
    text    = Color3.fromRGB(15, 17, 22),
    sub     = Color3.fromRGB(140, 145, 155),
    divider = Color3.fromRGB(238, 240, 244),
    track   = Color3.fromRGB(230, 232, 238),
    stroke  = Color3.fromRGB(232, 234, 240),
    btnBg   = Color3.fromRGB(247, 248, 251),
    btnHov  = Color3.fromRGB(238, 241, 246),
    iconBtn = Color3.fromRGB(243, 245, 249),
    iconHov = Color3.fromRGB(232, 236, 242),
    sliderV = Color3.fromRGB(240, 244, 250),
}

local DARK = {
    bg      = Color3.fromRGB(24, 24, 27),
    grad1   = Color3.fromRGB(32, 32, 36),
    grad2   = Color3.fromRGB(20, 20, 23),
    text    = Color3.fromRGB(245, 245, 247),
    sub     = Color3.fromRGB(150, 152, 158),
    divider = Color3.fromRGB(52, 52, 56),
    track   = Color3.fromRGB(60, 60, 64),
    stroke  = Color3.fromRGB(58, 58, 62),
    btnBg   = Color3.fromRGB(44, 44, 48),
    btnHov  = Color3.fromRGB(56, 56, 60),
    iconBtn = Color3.fromRGB(40, 40, 44),
    iconHov = Color3.fromRGB(54, 54, 58),
    sliderV = Color3.fromRGB(40, 44, 52),
}

local COL = {}
for k, v in pairs(LIGHT) do COL[k] = v end

COL.accent = Color3.fromRGB(10, 132, 255)
COL.green  = Color3.fromRGB(52, 199, 89)
COL.red    = Color3.fromRGB(255, 69, 58)

--============================================================--
-- REGISTRIES
--============================================================--
local accentEls = {}
local bgEls = {}

local function regAccent(obj, prop)
    if obj then table.insert(accentEls, { o = obj, p = prop }) end
end

-- bg entries store { obj, prop, key }  where key is a LIGHT/DARK palette key
local function regBg(obj, prop, key)
    if obj then table.insert(bgEls, { o = obj, p = prop, k = key }) end
end

local function applyTheme(t)
    COL.accent = t.Accent
    for _, e in ipairs(accentEls) do
        pcall(function() e.o[e.p] = t.Accent end)
    end
end

local isDark = false

local function setDark(dark)
    isDark = dark
    local src = dark and DARK or LIGHT
    for k, v in pairs(src) do COL[k] = v end
    for _, e in ipairs(bgEls) do
        pcall(function() e.o[e.p] = src[e.k] end)
    end
end

--============================================================--
-- THEMES (accent)
--============================================================--
local THEMES = {
    { Accent = Color3.fromRGB(10, 132, 255)  },
    { Accent = Color3.fromRGB(52, 199, 89)   },
    { Accent = Color3.fromRGB(139, 92, 246)  },
    { Accent = Color3.fromRGB(236, 72, 153)  },
    { Accent = Color3.fromRGB(255, 69, 58)   },
    { Accent = Color3.fromRGB(255, 159, 10)  },
    { Accent = Color3.fromRGB(48, 176, 199)  },
    { Accent = Color3.fromRGB(90, 100, 115)  },
}

--============================================================--
-- EASING
--============================================================--
local EASE = {
    smooth = TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    quick  = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    fade   = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    slide  = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    seg    = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

--============================================================--
-- DIMENSIONS
--============================================================--
local W_COL, H_COL = 104, 50
local W_EXP, H_EXP = 300, 400

--============================================================--
-- SCREEN
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
regBg(main, "BackgroundColor3", "bg")

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, H_COL / 2)
corner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COL.stroke
mainStroke.Thickness = 1
mainStroke.Transparency = 0.25
mainStroke.Parent = main
regBg(mainStroke, "Color", "stroke")

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COL.grad1),
    ColorSequenceKeypoint.new(1, COL.grad2),
})
mainGrad.Rotation = 90
mainGrad.Parent = main

local function updateGrad()
    local src = isDark and DARK or LIGHT
    mainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, src.grad1),
        ColorSequenceKeypoint.new(1, src.grad2),
    })
end

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
regAccent(fpsNum, "TextColor3")

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
regBg(fpsTag, "TextColor3", "sub")

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
regBg(title, "TextColor3", "text")

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
regBg(subtitle, "TextColor3", "sub")

--============================================================--
-- HEADER BUTTONS
--============================================================--
local ICON_GEAR = "rbxassetid://6031280882"
local ICON_BACK = "rbxassetid://6031091004"

local setBtn = Instance.new("TextButton")
setBtn.Size = UDim2.fromOffset(26, 26)
setBtn.AnchorPoint = Vector2.new(1, 0)
setBtn.Position = UDim2.new(1, -42, 0, 12)
setBtn.BackgroundColor3 = COL.iconBtn
setBtn.BorderSizePixel = 0
setBtn.Text = ""
setBtn.AutoButtonColor = false
setBtn.ZIndex = 40
setBtn.Visible = false
setBtn.Parent = main
regBg(setBtn, "BackgroundColor3", "iconBtn")

local setCorner = Instance.new("UICorner")
setCorner.CornerRadius = UDim.new(1, 0); setCorner.Parent = setBtn

local setStroke = Instance.new("UIStroke")
setStroke.Color = COL.stroke; setStroke.Thickness = 1
setStroke.Transparency = 0.25; setStroke.Parent = setBtn
regBg(setStroke, "Color", "stroke")

local setIcon = Instance.new("ImageLabel")
setIcon.Size = UDim2.fromOffset(14, 14)
setIcon.Position = UDim2.fromOffset(6, 6)
setIcon.BackgroundTransparency = 1
setIcon.Image = ICON_GEAR
setIcon.ImageColor3 = COL.text
setIcon.ZIndex = 41
setIcon.Parent = setBtn
regBg(setIcon, "ImageColor3", "text")

setBtn.MouseEnter:Connect(function()
    local src = isDark and DARK or LIGHT
    TweenService:Create(setBtn, EASE.quick,
        { BackgroundColor3 = src.iconHov }):Play()
end)
setBtn.MouseLeave:Connect(function()
    local src = isDark and DARK or LIGHT
    TweenService:Create(setBtn, EASE.quick,
        { BackgroundColor3 = src.iconBtn }):Play()
end)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(26, 26)
minBtn.AnchorPoint = Vector2.new(1, 0)
minBtn.Position = UDim2.new(1, -10, 0, 12)
minBtn.BackgroundColor3 = COL.iconBtn
minBtn.BorderSizePixel = 0
minBtn.Text = "−"
minBtn.TextColor3 = COL.text
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.AutoButtonColor = false
minBtn.ZIndex = 40
minBtn.Visible = false
minBtn.Parent = main
regBg(minBtn, "BackgroundColor3", "iconBtn")
regBg(minBtn, "TextColor3", "text")

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(1, 0); minCorner.Parent = minBtn

local minStroke = Instance.new("UIStroke")
minStroke.Color = COL.stroke; minStroke.Thickness = 1
minStroke.Transparency = 0.25; minStroke.Parent = minBtn
regBg(minStroke, "Color", "stroke")

minBtn.MouseEnter:Connect(function()
    local src = isDark and DARK or LIGHT
    TweenService:Create(minBtn, EASE.quick,
        { BackgroundColor3 = src.iconHov }):Play()
end)
minBtn.MouseLeave:Connect(function()
    local src = isDark and DARK or LIGHT
    TweenService:Create(minBtn, EASE.quick,
        { BackgroundColor3 = src.iconBtn }):Play()
end)

--============================================================--
-- BODY + PAGES
--============================================================--
local body = Instance.new("CanvasGroup")
body.Size = UDim2.new(1, -24, 1, -72)
body.Position = UDim2.fromOffset(12, 56)
body.BackgroundTransparency = 1
body.GroupTransparency = 1
body.ZIndex = 11
body.Parent = main

local pageMain = Instance.new("CanvasGroup")
pageMain.Size = UDim2.fromScale(1, 1)
pageMain.BackgroundTransparency = 1
pageMain.GroupTransparency = 0
pageMain.ZIndex = 11
pageMain.Parent = body

local pageSettings = Instance.new("CanvasGroup")
pageSettings.Size = UDim2.fromScale(1, 1)
pageSettings.BackgroundTransparency = 1
pageSettings.GroupTransparency = 1
pageSettings.Visible = false
pageSettings.ZIndex = 11
pageSettings.Parent = body

--============================================================--
-- SHARED BUILDERS
--============================================================--
local function sectionLabel(parent, y, txt)
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
    l.Parent = parent
    regBg(l, "TextColor3", "sub")
    return l
end

local function makeIconTile(parent, x, y, assetId, size)
    size = size or 32
    local tile = Instance.new("Frame")
    tile.Size = UDim2.fromOffset(size, size)
    tile.Position = UDim2.fromOffset(x, y)
    tile.BackgroundColor3 = COL.accent
    tile.BorderSizePixel = 0
    tile.ZIndex = 13
    tile.Parent = parent
    regAccent(tile, "BackgroundColor3")

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, size * 0.32); tc.Parent = tile

    local grad = Instance.new("UIGradient")
    grad.Rotation = 135
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.4),
    })
    grad.Parent = tile

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromOffset(size * 0.56, size * 0.56)
    img.Position = UDim2.fromOffset(size * 0.22, size * 0.22)
    img.BackgroundTransparency = 1
    img.Image = assetId
    img.ImageColor3 = Color3.fromRGB(255, 255, 255)
    img.ZIndex = 14
    img.Parent = tile

    return tile, img
end

local function makeSwitch(parent, xOff, y)
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(44, 26)
    track.AnchorPoint = Vector2.new(1, 0)
    track.Position = UDim2.new(1, xOff, 0, y)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.ZIndex = 14
    track.Parent = parent
    regBg(track, "BackgroundColor3", "track")

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

local function makeSlider(parent, y, min, max, default, onChange)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.fromOffset(0, y)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.ZIndex = 13
    track.Parent = parent
    regBg(track, "BackgroundColor3", "track")

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COL.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 14
    fill.Parent = track
    regAccent(fill, "BackgroundColor3")

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
-- FEATURE ROW BUILDER
--============================================================--
local function featureRow(parent, y, tileAsset, titleTxt, subTxt, isShield)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 54)
    row.Position = UDim2.fromOffset(0, y)
    row.BackgroundTransparency = 1
    row.ZIndex = 12
    row.Parent = parent

    -- icon tile
    local tile = Instance.new("Frame")
    tile.Size = UDim2.fromOffset(32, 32)
    tile.Position = UDim2.fromOffset(2, 11)
    tile.BackgroundColor3 = COL.accent
    tile.BorderSizePixel = 0
    tile.ZIndex = 13
    tile.Parent = row
    regAccent(tile, "BackgroundColor3")

    local tcorner = Instance.new("UICorner")
    tcorner.CornerRadius = UDim.new(0, 10); tcorner.Parent = tile

    local grad = Instance.new("UIGradient")
    grad.Rotation = 135
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.4),
    })
    grad.Parent = tile

    if isShield then
        -- vector shield (100% offline, always renders)
        local container = Instance.new("Frame")
        container.Size = UDim2.fromOffset(20, 20)
        container.Position = UDim2.fromOffset(6, 6)
        container.BackgroundTransparency = 1
        container.ZIndex = 14
        container.Parent = tile

        -- top half — rounded square
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, 0, 0.62, 0)
        body.Position = UDim2.fromOffset(0, 0)
        body.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        body.BorderSizePixel = 0
        body.ZIndex = 15
        body.Parent = container

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 6); bc.Parent = body

        -- bottom point — rotated square (diamond) partially hidden
        local point = Instance.new("Frame")
        point.Size = UDim2.fromOffset(14, 14)
        point.AnchorPoint = Vector2.new(0.5, 0.5)
        point.Position = UDim2.new(0.5, 0, 0.72, 0)
        point.Rotation = 45
        point.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        point.BorderSizePixel = 0
        point.ZIndex = 15
        point.Parent = container

        local pc = Instance.new("UICorner")
        pc.CornerRadius = UDim.new(0, 2); pc.Parent = point

        -- inner notch (a tiny accent circle to hint the "lock" look)
        local notch = Instance.new("Frame")
        notch.Size = UDim2.fromOffset(6, 6)
        notch.AnchorPoint = Vector2.new(0.5, 0.5)
        notch.Position = UDim2.new(0.5, 0, 0.42, 0)
        notch.BackgroundColor3 = COL.accent
        notch.BorderSizePixel = 0
        notch.ZIndex = 17
        notch.Parent = container
        regAccent(notch, "BackgroundColor3")

        local nc = Instance.new("UICorner")
        nc.CornerRadius = UDim.new(1, 0); nc.Parent = notch
    else
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromOffset(18, 18)
        img.Position = UDim2.fromOffset(7, 7)
        img.BackgroundTransparency = 1
        img.Image = tileAsset
        img.ImageColor3 = Color3.fromRGB(255, 255, 255)
        img.ZIndex = 14
        img.Parent = tile
    end

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
    t.Parent = row
    regBg(t, "TextColor3", "text")

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
    st.Parent = row
    regBg(st, "TextColor3", "sub")

    return row
end

--============================================================--
-- PAGE 1 : MAIN
--============================================================--
sectionLabel(pageMain, 0, "FEATURES")

featureRow(pageMain, 16, "rbxassetid://6031075931", "Fast Loot",
    "Auto-collect · Key E", false)
local lootSwitch = makeSwitch(pageMain, -4, 30)

featureRow(pageMain, 78, nil, "Anti-Ragdoll",
    "Server-safe body", true)
local antiSwitch = makeSwitch(pageMain, -4, 92)

sectionLabel(pageMain, 148, "SPEED CONTROL")

local sliderValue = Instance.new("TextLabel")
sliderValue.Size = UDim2.new(0, 52, 0, 20)
sliderValue.Position = UDim2.new(1, -52, 0, 164)
sliderValue.BackgroundColor3 = COL.accent
sliderValue.BackgroundTransparency = 0.88
sliderValue.Text = tostring(antiSpeed)
sliderValue.TextColor3 = COL.accent
sliderValue.Font = Enum.Font.GothamBold
sliderValue.TextSize = 11
sliderValue.ZIndex = 13
sliderValue.Parent = pageMain
regAccent(sliderValue, "TextColor3")

local svCorner = Instance.new("UICorner")
svCorner.CornerRadius = UDim.new(0, 7); svCorner.Parent = sliderValue

local sliderHost = Instance.new("Frame")
sliderHost.Size = UDim2.new(1, 0, 0, 6)
sliderHost.Position = UDim2.fromOffset(0, 194)
sliderHost.BackgroundTransparency = 1
sliderHost.ZIndex = 13
sliderHost.Parent = pageMain

local speedSlider = makeSlider(sliderHost, 0, 20, 800, antiSpeed, function(v)
    antiSpeed = v
    sliderValue.Text = tostring(v)
end)

--============================================================--
-- PAGE 2 : SETTINGS
--============================================================--
sectionLabel(pageSettings, 0, "ACCENT COLOR")

local swatchRow = Instance.new("Frame")
swatchRow.Size = UDim2.new(1, 0, 0, 26)
swatchRow.Position = UDim2.fromOffset(0, 18)
swatchRow.BackgroundTransparency = 1
swatchRow.ZIndex = 12
swatchRow.Parent = pageSettings

local swatchStrokes = {}
for i, th in ipairs(THEMES) do
    local sw = Instance.new("TextButton")
    sw.Size = UDim2.fromOffset(26, 26)
    sw.Position = UDim2.fromOffset((i - 1) * 33, 0)
    sw.BackgroundColor3 = th.Accent
    sw.BorderSizePixel = 0
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.ZIndex = 13
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
            { Size = UDim2.fromOffset(30, 30),
              Position = UDim2.fromOffset((i - 1) * 33 - 2, -2) }):Play()
    end)
    sw.MouseLeave:Connect(function()
        TweenService:Create(sw, EASE.quick,
            { Size = UDim2.fromOffset(26, 26),
              Position = UDim2.fromOffset((i - 1) * 33, 0) }):Play()
    end)
    sw.MouseButton1Click:Connect(function()
        applyTheme(th)
        for j, st in ipairs(swatchStrokes) do
            st.Transparency = (j == i) and 0 or 0.75
        end
    end)
end

local div1 = Instance.new("Frame")
div1.Size = UDim2.new(1, 0, 0, 1)
div1.Position = UDim2.fromOffset(0, 56)
div1.BackgroundColor3 = COL.divider
div1.BorderSizePixel = 0
div1.ZIndex = 12
div1.Parent = pageSettings
regBg(div1, "BackgroundColor3", "divider")

-- BACKGROUND THEME SECTION
sectionLabel(pageSettings, 66, "BACKGROUND")

local segWrap = Instance.new("Frame")
segWrap.Size = UDim2.new(1, 0, 0, 34)
segWrap.Position = UDim2.fromOffset(0, 84)
segWrap.BackgroundColor3 = COL.track
segWrap.BorderSizePixel = 0
segWrap.ZIndex = 12
segWrap.Parent = pageSettings
regBg(segWrap, "BackgroundColor3", "track")

local segCorner = Instance.new("UICorner")
segCorner.CornerRadius = UDim.new(0, 10); segCorner.Parent = segWrap

-- sliding indicator
local segInd = Instance.new("Frame")
segInd.Size = UDim2.new(0.5, -3, 1, -6)
segInd.Position = UDim2.fromOffset(3, 3)
segInd.BackgroundColor3 = COL.bg
segInd.BorderSizePixel = 0
segInd.ZIndex = 13
segInd.Parent = segWrap
regBg(segInd, "BackgroundColor3", "bg")

local segIndCorner = Instance.new("UICorner")
segIndCorner.CornerRadius = UDim.new(0, 8); segIndCorner.Parent = segInd

local segIndShadow = Instance.new("Frame")
segIndShadow.Size = UDim2.new(1, 0, 1, 2)
segIndShadow.Position = UDim2.fromOffset(0, 1)
segIndShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
segIndShadow.BackgroundTransparency = 0.9
segIndShadow.BorderSizePixel = 0
segIndShadow.ZIndex = 12
segIndShadow.Parent = segInd

local segIndShCorner = Instance.new("UICorner")
segIndShCorner.CornerRadius = UDim.new(0, 8); segIndShCorner.Parent = segIndShadow

local segLightBtn = Instance.new("TextButton")
segLightBtn.Size = UDim2.new(0.5, 0, 1, 0)
segLightBtn.Position = UDim2.fromOffset(0, 0)
segLightBtn.BackgroundTransparency = 1
segLightBtn.Text = "Light"
segLightBtn.TextColor3 = COL.text
segLightBtn.Font = Enum.Font.GothamBold
segLightBtn.TextSize = 11
segLightBtn.AutoButtonColor = false
segLightBtn.ZIndex = 14
segLightBtn.Parent = segWrap
regBg(segLightBtn, "TextColor3", "text")

local segDarkBtn = Instance.new("TextButton")
segDarkBtn.Size = UDim2.new(0.5, 0, 1, 0)
segDarkBtn.Position = UDim2.new(0.5, 0, 0, 0)
segDarkBtn.BackgroundTransparency = 1
segDarkBtn.Text = "Dark"
segDarkBtn.TextColor3 = COL.sub
segDarkBtn.Font = Enum.Font.GothamBold
segDarkBtn.TextSize = 11
segDarkBtn.AutoButtonColor = false
segDarkBtn.ZIndex = 14
segDarkBtn.Parent = segWrap
regBg(segDarkBtn, "TextColor3", "sub")

local function setSegment(dark)
    local target = dark and UDim2.new(0.5, 1, 0, 3) or UDim2.fromOffset(3, 3)
    TweenService:Create(segInd, EASE.seg, { Position = target }):Play()
    local src = dark and DARK or LIGHT
    TweenService:Create(segLightBtn, EASE.seg,
        { TextColor3 = dark and src.sub or src.text }):Play()
    TweenService:Create(segDarkBtn, EASE.seg,
        { TextColor3 = dark and src.text or src.sub }):Play()
end

segLightBtn.MouseButton1Click:Connect(function()
    if not isDark then return end
    setDark(false)
    setSegment(false)
    updateGrad()
end)

segDarkBtn.MouseButton1Click:Connect(function()
    if isDark then return end
    setDark(true)
    setSegment(true)
    updateGrad()
end)

local div2 = Instance.new("Frame")
div2.Size = UDim2.new(1, 0, 0, 1)
div2.Position = UDim2.fromOffset(0, 128)
div2.BackgroundColor3 = COL.divider
div2.BorderSizePixel = 0
div2.ZIndex = 12
div2.Parent = pageSettings
regBg(div2, "BackgroundColor3", "divider")

-- FPS Boost row
featureRow(pageSettings, 138, "rbxassetid://6031094678", "FPS Boost Ultra",
    "Reduce graphics", false)
local fpsSwitch = makeSwitch(pageSettings, -4, 152)

-- action buttons
local function actionBtn(parent, y, txt, iconAsset)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.Position = UDim2.fromOffset(0, y)
    b.BackgroundColor3 = COL.btnBg
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.ZIndex = 13
    b.Parent = parent
    regBg(b, "BackgroundColor3", "btnBg")

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 11); c.Parent = b

    local s = Instance.new("UIStroke")
    s.Color = COL.stroke; s.Thickness = 1; s.Transparency = 0.4
    s.Parent = b
    regBg(s, "Color", "stroke")

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.fromOffset(14, 14)
    icon.Position = UDim2.fromOffset(12, 11)
    icon.BackgroundTransparency = 1
    icon.Image = iconAsset
    icon.ImageColor3 = COL.accent
    icon.ZIndex = 14
    icon.Parent = b
    regAccent(icon, "ImageColor3")

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -40, 1, 0)
    lbl.Position = UDim2.fromOffset(34, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt
    lbl.TextColor3 = COL.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 14
    lbl.Parent = b
    regBg(lbl, "TextColor3", "text")

    b.MouseEnter:Connect(function()
        local src = isDark and DARK or LIGHT
        TweenService:Create(b, EASE.quick,
            { BackgroundColor3 = src.btnHov }):Play()
    end)
    b.MouseLeave:Connect(function()
        local src = isDark and DARK or LIGHT
        TweenService:Create(b, EASE.quick,
            { BackgroundColor3 = src.btnBg }):Play()
    end)

    return b
end

local purgeBtn = actionBtn(pageSettings, 204, "Purge World Effects",
    "rbxassetid://6031094678")
purgeBtn.MouseButton1Click:Connect(function()
    task.spawn(function() pcall(scanFX) end)
end)

local ramBtn = actionBtn(pageSettings, 246, "Free Memory",
    "rbxassetid://6031075931")
ramBtn.MouseButton1Click:Connect(freeRAM)

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
-- PAGE SWAP
--============================================================--
local showingSettings = false
local pageBusy = false

local function swapPage(toSettings)
    if pageBusy then return end
    if showingSettings == toSettings then return end
    pageBusy = true
    showingSettings = toSettings

    local fromPage = toSettings and pageMain or pageSettings
    local toPage   = toSettings and pageSettings or pageMain

    local fromEnd   = UDim2.fromOffset(toSettings and -14 or 14, 0)
    local toStart   = UDim2.fromOffset(toSettings and 14 or -14, 0)
    local toEnd     = UDim2.fromOffset(0, 0)

    toPage.Position = toStart
    toPage.Visible = true

    TweenService:Create(toPage, EASE.slide, {
        Position = toEnd,
        GroupTransparency = 0,
    }):Play()
    TweenService:Create(fromPage, EASE.slide, {
        Position = fromEnd,
        GroupTransparency = 1,
    }):Play()

    setIcon.Image = toSettings and ICON_BACK or ICON_GEAR

    task.delay(0.32, function()
        fromPage.Visible = false
        fromPage.Position = UDim2.fromOffset(0, 0)
        pageBusy = false
    end)
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

    if not state and showingSettings then
        pageMain.Visible = true
        pageMain.Position = UDim2.fromOffset(0, 0)
        pageMain.GroupTransparency = 0
        pageSettings.Visible = false
        pageSettings.GroupTransparency = 1
        showingSettings = false
        setIcon.Image = ICON_GEAR
    end

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
-- DRAG
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
    if not expanded then
        setExpanded(true)
        return
    end
    swapPage(not showingSettings)
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

print("[Hyko] v7 loaded · Vector shield · Light/Dark background")