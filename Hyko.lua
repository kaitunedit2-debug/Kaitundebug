--========================================================================--
-- Hyko by Huy - WindUI Edition (Optimized)
-- UI Engine: WindUI by Footagesus
-- Theme: Hyko White | Custom Background & Icon System
--========================================================================--

local Players         = game:GetService("Players")
local UIS             = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local Lighting        = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local TweenService    = game:GetService("TweenService")
local LP              = Players.LocalPlayer
local PlaceId         = game.PlaceId

print("[Hyko] Step 1: Initializing helpers")

--========================================================================--
-- [0] HELPERS
--========================================================================--
local function mountGui(gui)
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function()
        if gethui then gui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = game:GetService("CoreGui")
        else
            gui.Parent = LP:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
        end
    end)
    if not ok then
        pcall(function()
            gui.Parent = LP:FindFirstChildOfClass("PlayerGui")
                or game:GetService("CoreGui")
        end)
    end
end

local function applyWhiteGlow(target, cornerRadius, layers, intensity)
    if not target or not target.Parent then return end
    layers = layers or 3
    intensity = intensity or 1
    target.ClipsDescendants = false
    for i = 1, layers do
        local glow = Instance.new("Frame")
        glow.Name = "HykoGlowLayer"
        glow.BackgroundTransparency = 1
        glow.BorderSizePixel = 0
        glow.Size = UDim2.new(1, i * 6, 1, i * 6)
        glow.Position = UDim2.new(0, -i * 3, 0, -i * 3)
        glow.ZIndex = (target.ZIndex or 1) - i
        glow.Active = false
        glow.Parent = target

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, cornerRadius + i * 3)
        c.Parent = glow

        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(255, 255, 255)
        s.Thickness = 1.6
        s.Transparency = math.clamp(0.25 + (i - 1) * 0.22 + (1 - intensity) * 0.3, 0, 1)
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = glow
    end
end

print("[Hyko] Step 2: Loading WindUI engine")

--========================================================================--
-- [1] LOAD WINDUI
--========================================================================--
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

if not WindUI then
    warn("[Hyko] Failed to load WindUI library")
    return
end

print("[Hyko] Step 3: WindUI engine loaded successfully")

--========================================================================--
-- [2] MOVEMENT INPUT
--========================================================================--
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
    if UIS:IsKeyDown(Enum.KeyCode.W) then d += Vector3.new(0, 0, -1) end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d += Vector3.new(0, 0, 1)  end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d += Vector3.new(-1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d += Vector3.new(1, 0, 0)  end
    return d
end

--========================================================================--
-- [3] STATE MANAGEMENT
--========================================================================--
local homePos       = nil
local returningHome = false
local returnSpeed   = 120
local homeConn      = nil

local speedOn          = false
local antiRagdollOn    = false
local curSpeed          = 60
local antiRagdollSpeed  = 60
local fakeWalkSpeed     = 600

local lootOn       = false
local lootConn     = nil
local promptAdded  = nil
local savedPrompts = {}

local hitboxOn    = false
local hitboxSize  = 15
local hitboxData  = {}

local espOn    = false
local espColor = Color3.fromRGB(70, 130, 230)
local espList  = {}
local espLoop  = nil

--========================================================================--
-- [4] DRIVE SYSTEM (Anti-Ragdoll + Anti-Knockback)
--========================================================================--
local driveActive         = false
local driveConn           = nil
local drivePostConn       = nil
local driveRealHum        = nil
local driveFakeHum        = nil
local driveSavedCollide   = {}
local driveYLock          = true

local driveVelConstraint  = nil
local driveVelAttachment  = nil

local lastSafeY         = nil
local KILL_UP_VELOCITY  = 40
local MAX_ABOVE_GROUND  = 12
local MAX_ABOVE_SAFE    = 25

local function anyDriveRequested() return speedOn or antiRagdollOn end

local function activeMoveSpeed()
    if antiRagdollOn then return antiRagdollSpeed end
    if speedOn then return curSpeed end
    return 16
end

local function isBodyMover(d)
    return d:IsA("BodyVelocity") or d:IsA("BodyAngularVelocity") or d:IsA("BodyForce")
        or d:IsA("BodyThrust") or d:IsA("BodyPosition") or d:IsA("BodyGyro")
        or d:IsA("LinearVelocity") or d:IsA("AngularVelocity") or d:IsA("VectorForce")
        or d:IsA("Torque") or d:IsA("AlignPosition") or d:IsA("AlignOrientation")
        or d:IsA("RocketPropulsion")
end

local function buildFakeHumanoid(speed)
    local hum = Instance.new("Humanoid")
    hum.Name = "Humanoid"
    hum.WalkSpeed = speed
    hum.JumpPower = 50
    hum.UseJumpPower = true
    hum.Health = 100
    hum.MaxHealth = 100
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.BreakJointsOnDeath = false
    hum.RequiresNeck = false
    hum.EvaluateStateMachine = false
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)
    return hum
end

local driveRayParams = RaycastParams.new()
driveRayParams.FilterType = Enum.RaycastFilterType.Exclude
driveRayParams.IgnoreWater = true

--========================================================================--
-- ANTIFLING VELOCITY CONSTRAINT
--========================================================================--
local function createVelConstraint(hrp)
    if driveVelConstraint and driveVelConstraint.Parent then
        driveVelConstraint:Destroy()
    end
    if driveVelAttachment and driveVelAttachment.Parent then
        driveVelAttachment:Destroy()
    end

    local att = Instance.new("Attachment")
    att.Name = "HykoAntiFlingAttach"
    att.Parent = hrp
    driveVelAttachment = att

    local lv = Instance.new("LinearVelocity")
    lv.Name = "HykoAntiFlingVel"
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    lv.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
    pcall(function() lv.ForceLimitsEnabled = true end)
    lv.Parent = hrp
    driveVelConstraint = lv
end

local function destroyVelConstraint()
    if driveVelConstraint then
        pcall(function() driveVelConstraint:Destroy() end)
        driveVelConstraint = nil
    end
    if driveVelAttachment then
        pcall(function() driveVelAttachment:Destroy() end)
        driveVelAttachment = nil
    end
end

--========================================================================--
-- ANTI-RAGDOLL CORE
--========================================================================--
local function applyAntiRagdollDestroy()
    local c = LP.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            pcall(function() p:Destroy() end)
        end
    end
end

local function forceHumanoidHealthy()
    if not driveFakeHum or not driveFakeHum.Parent then return end
    pcall(function()
        if driveFakeHum.PlatformStand then driveFakeHum.PlatformStand = false end
        if driveFakeHum.Sit then driveFakeHum.Sit = false end
        driveFakeHum.AutoRotate = true
        local st = driveFakeHum:GetState()
        if st == Enum.HumanoidStateType.Ragdoll
            or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.Physics
            or st == Enum.HumanoidStateType.PlatformStanding then
            driveFakeHum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

--========================================================================--
-- DRIVE HEARTBEAT
--========================================================================--
local function driveHeartbeat()
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    if not driveFakeHum or driveFakeHum.Parent ~= ch then
        driveFakeHum = buildFakeHumanoid(fakeWalkSpeed)
        driveFakeHum.Parent = ch
    end
    if driveFakeHum.WalkSpeed ~= fakeWalkSpeed then
        pcall(function() driveFakeHum.WalkSpeed = fakeWalkSpeed end)
    end
    if driveRealHum and driveRealHum.Parent == ch then
        pcall(function() driveRealHum.Parent = nil end)
    end

    if antiRagdollOn then
        forceHumanoidHealthy()
        applyAntiRagdollDestroy()

        if not driveVelConstraint or not driveVelConstraint.Parent then
            createVelConstraint(root)
        end
        pcall(function() root:SetNetworkOwner(LP) end)
    else
        if driveVelConstraint then
            destroyVelConstraint()
        end
    end

    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.AssemblyAngularVelocity = Vector3.zero end)
            if p ~= root then
                pcall(function() p.AssemblyLinearVelocity = Vector3.zero end)
            end
        elseif isBodyMover(p) then
            if p.Name ~= "HykoAntiFlingVel" then
                pcall(function() p:Destroy() end)
            end
        end
    end

    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude > 0.01 then
        root.CFrame = CFrame.new(root.Position, root.Position + flat.Unit)
    end
    root.AssemblyAngularVelocity = Vector3.zero

    driveRayParams.FilterDescendantsInstances = {ch}
    local origin = root.Position + Vector3.new(0, 4, 0)
    local result = workspace:Raycast(origin, Vector3.new(0, -120, 0), driveRayParams)
    local groundY = nil
    if result then
        groundY = result.Position.Y + 3.5
        lastSafeY = groundY
    end

    if antiRagdollOn then
        local vel = root.AssemblyLinearVelocity

        if vel.Y > KILL_UP_VELOCITY then
            vel = Vector3.new(vel.X, 0, vel.Z)
            root.AssemblyLinearVelocity = vel
        end

        if groundY then
            if root.Position.Y > groundY + MAX_ABOVE_GROUND then
                root.CFrame = CFrame.new(root.Position.X, groundY, root.Position.Z)
                    * (root.CFrame - root.Position)
                root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
            end
        elseif lastSafeY and root.Position.Y > lastSafeY + MAX_ABOVE_SAFE then
            root.CFrame = CFrame.new(root.Position.X, lastSafeY, root.Position.Z)
                * (root.CFrame - root.Position)
            root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
        end
    end

    local useConstraint = antiRagdollOn
        and driveVelConstraint and driveVelConstraint.Parent

    if not returningHome then
        local v = readMove()
        local camCF = cam.CFrame

        local targetHoriz
        if v.Magnitude < 0.05 then
            targetHoriz = Vector3.zero
        else
            local worldDir = camCF.LookVector * (-v.Z) + camCF.RightVector * v.X
            worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)
            if worldDir.Magnitude > 0.01 then
                targetHoriz = worldDir.Unit * activeMoveSpeed()
            else
                targetHoriz = Vector3.zero
            end
        end

        if useConstraint then
            driveVelConstraint.VectorVelocity = targetHoriz
        else
            local curY = root.AssemblyLinearVelocity.Y
            root.AssemblyLinearVelocity = targetHoriz + Vector3.new(0, curY, 0)
        end
    else
        if useConstraint then
            driveVelConstraint.VectorVelocity = Vector3.zero
        end
    end

    if driveYLock and groundY then
        local delta = groundY - root.Position.Y
        if math.abs(delta) < 8 then
            root.CFrame = CFrame.new(root.Position.X, groundY, root.Position.Z)
                * (root.CFrame - root.Position)
            local cv = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(cv.X, 0, cv.Z)
        end
    end
end

--========================================================================--
-- POST-SIMULATION
--========================================================================--
local function drivePostSim()
    if not antiRagdollOn then return end
    if not driveVelConstraint or not driveVelConstraint.Parent then return end
    local c = LP.Character
    if not c then return end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local want = driveVelConstraint.VectorVelocity
    local cur = root.AssemblyLinearVelocity
    local dx = cur.X - want.X
    local dz = cur.Z - want.Z
    if (dx * dx + dz * dz) > 4 then
        root.AssemblyLinearVelocity = Vector3.new(want.X, cur.Y, want.Z)
    end
end

local function startDrive()
    if driveActive then return true end
    local c = LP.Character
    if not c then return false end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end

    driveRealHum = hum
    pcall(function() driveRealHum.Parent = nil end)

    driveFakeHum = buildFakeHumanoid(fakeWalkSpeed)
    driveFakeHum.Parent = c

    pcall(function() workspace.CurrentCamera.CameraSubject = hrp end)
    pcall(function() hrp:SetNetworkOwner(LP) end)

    lastSafeY = hrp.Position.Y

    driveSavedCollide = {}
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p ~= hrp then
            if antiRagdollOn then
                pcall(function() p:Destroy() end)
            else
                driveSavedCollide[p] = p.CanCollide
                pcall(function() p.CanCollide = false end)
            end
        end
    end

    local driveEvent = RunService.PreSimulation or RunService.Heartbeat
    driveConn = driveEvent:Connect(driveHeartbeat)

    local postEvent = RunService.PostSimulation or RunService.Stepped
    drivePostConn = postEvent:Connect(drivePostSim)

    c.DescendantAdded:Connect(function(d)
        if not driveActive then return end
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            if antiRagdollOn then
                task.defer(function()
                    if driveActive and antiRagdollOn then
                        pcall(function() d:Destroy() end)
                    end
                end)
            else
                if driveSavedCollide[d] == nil then
                    driveSavedCollide[d] = d.CanCollide
                end
                pcall(function() d.CanCollide = false end)
            end
        elseif isBodyMover(d) then
            if d.Name ~= "HykoAntiFlingVel" then
                task.defer(function()
                    if driveActive then
                        pcall(function() d:Destroy() end)
                    end
                end)
            end
        end
    end)

    driveActive = true
    if antiRagdollOn then
        applyAntiRagdollDestroy()
        createVelConstraint(hrp)
    end
    return true
end

local function stopDrive()
    if not driveActive then return end
    driveActive = false
    if driveConn then driveConn:Disconnect() driveConn = nil end
    if drivePostConn then drivePostConn:Disconnect() drivePostConn = nil end

    destroyVelConstraint()

    local c = LP.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        if driveFakeHum and driveFakeHum.Parent then
            pcall(function() driveFakeHum:Destroy() end)
        end
        driveFakeHum = nil
        if driveRealHum and driveRealHum.Parent == nil then
            pcall(function()
                driveRealHum.Parent = c
                driveRealHum.WalkSpeed = 16
                driveRealHum.JumpPower = 50
            end)
        end
        driveRealHum = nil
        for part, can in pairs(driveSavedCollide) do
            if part and part.Parent then
                pcall(function() part.CanCollide = can end)
            end
        end
    end
    driveSavedCollide = {}
end

local function refreshDrive()
    if anyDriveRequested() and not driveActive then
        startDrive()
    elseif not anyDriveRequested() and driveActive then
        stopDrive()
    end
end

--========================================================================--
-- [5] FAST LOOT
--========================================================================--
local function applyFastPrompt(p)
    if not p:IsA("ProximityPrompt") then return end
    if savedPrompts[p] == nil then savedPrompts[p] = p.HoldDuration end
    pcall(function() p.HoldDuration = 0 end)
end

local function restorePrompts()
    for p, hold in pairs(savedPrompts) do
        if p and p.Parent then pcall(function() p.HoldDuration = hold end) end
    end
    savedPrompts = {}
end

local lootRadiusParams = OverlapParams.new()
lootRadiusParams.FilterType = Enum.RaycastFilterType.Exclude

local function enableLoot()
    if lootConn then return end

    task.spawn(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then applyFastPrompt(d) end
        end
    end)

    promptAdded = workspace.DescendantAdded:Connect(function(d)
        if lootOn and d:IsA("ProximityPrompt") then
            applyFastPrompt(d)
        end
    end)

    lootConn = UIS.InputBegan:Connect(function(input, gpe)
        if not lootOn or gpe then return end
        if input.KeyCode ~= Enum.KeyCode.E then return end

        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        lootRadiusParams.FilterDescendantsInstances = {c}
        local parts = workspace:GetPartBoundsInRadius(hrp.Position, 32, lootRadiusParams)

        local best, bestDist = nil, math.huge
        for _, part in ipairs(parts) do
            for _, d in ipairs(part:GetChildren()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist <= d.MaxActivationDistance + 4 and dist < bestDist then
                        best, bestDist = d, dist
                    end
                end
            end
            for _, attach in ipairs(part:GetChildren()) do
                if attach:IsA("Attachment") then
                    for _, d in ipairs(attach:GetChildren()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist <= d.MaxActivationDistance + 4 and dist < bestDist then
                                best, bestDist = d, dist
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
    if promptAdded then promptAdded:Disconnect() promptAdded = nil end
    restorePrompts()
end

--========================================================================--
-- [6] HITBOX EXPANDER
--========================================================================--
local function expandHitbox(pl)
    if pl == LP then return end
    local c = pl.Character
    if not c then return end
    local data = hitboxData[pl]
    if not data then data = { parts = {}, trans = {} } hitboxData[pl] = data end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
            if data.parts[p] == nil then
                data.parts[p] = p.Size
                data.trans[p] = p.Transparency
            end
            pcall(function()
                p.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                p.Transparency = 0.7
            end)
        end
    end
end

local function restoreHitbox(pl)
    local data = hitboxData[pl]
    if not data then return end
    for p, size in pairs(data.parts) do
        if p and p.Parent then
            pcall(function()
                p.Size = size
                p.Transparency = data.trans[p] or 0
            end)
        end
    end
    hitboxData[pl] = nil
end

local function enableHitboxAll()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP then pcall(expandHitbox, pl) end
    end
end

local function restoreHitboxAll()
    for pl in pairs(hitboxData) do pcall(restoreHitbox, pl) end
    hitboxData = {}
end

local hitboxLoop = nil
local function startHitboxLoop()
    if hitboxLoop then return end
    hitboxLoop = task.spawn(function()
        while hitboxOn do
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then pcall(expandHitbox, pl) end
            end
            task.wait(0.5)
        end
    end)
end

local function stopHitboxLoop() hitboxOn = false end

--========================================================================--
-- [7] ESP SYSTEM
--========================================================================--
local function removeESP(pl)
    local e = espList[pl]
    if not e then return end
    if e.highlight then e.highlight:Destroy() end
    if e.billboard then e.billboard:Destroy() end
    if e.conn then e.conn:Disconnect() end
    espList[pl] = nil
end

local function removeAllESP()
    for pl in pairs(espList) do removeESP(pl) end
    espList = {}
end

local function createESP(pl)
    if pl == LP or espList[pl] then return end
    local c = pl.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "HykoESP"
    highlight.Adornee = c
    highlight.FillColor = espColor
    highlight.FillTransparency = 0.6
    highlight.OutlineColor = espColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = c

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HykoESPName"
    billboard.Size = UDim2.new(0, 200, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = hrp
    billboard.Parent = c

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = pl.Name
    label.TextColor3 = espColor
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard

    local conn = pl.CharacterAdded:Connect(function()
        task.wait(0.5)
        if espOn then removeESP(pl) createESP(pl) end
    end)

    espList[pl] = { highlight = highlight, billboard = billboard, conn = conn }
end

local function enableESP()
    espOn = true
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP then createESP(pl) end
    end
    espLoop = task.spawn(function()
        while espOn do
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP and not espList[pl] then createESP(pl) end
            end
            task.wait(0.5)
        end
    end)
end

local function disableESP()
    espOn = false
    removeAllESP()
end

--========================================================================--
-- [8] FPS BOOST
--========================================================================--
local fpsOn              = false
local fpsAddedConn       = nil
local removedEffects     = {}
local disabledLights     = {}
local origLighting       = nil
local origTerrain        = nil
local savedQuality       = nil
local savedFrameRateCap  = nil
local savedAtmos         = {}
local fogBlur            = nil
local colorFix           = nil

local function isHykoObject(d)
    if not d or not d.Name then return false end
    return string.sub(d.Name, 1, 4) == "Hyko"
end

local function isEffect(d)
    if isHykoObject(d) then return false end
    return d:IsA("ParticleEmitter")
        or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke")
        or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Explosion")
        or d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture")
end

local function isSafeToRemove(d)
    if isHykoObject(d) then return false end
    local c = LP and LP.Character
    if c and d:IsDescendantOf(c) then return false end
    for _, pl in ipairs(Players:GetPlayers()) do
        local pc = pl.Character
        if pc and d:IsDescendantOf(pc) then return false end
    end
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    if pg and d:IsDescendantOf(pg) then
        if d:IsA("ScreenGui") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
            return false
        end
    end
    return true
end

local function removeEffect(d)
    if not d or not d.Parent then return end
    if removedEffects[d] then return end
    if not isSafeToRemove(d) then return end
    removedEffects[d] = true
    pcall(function() d:Destroy() end)
end

local function disableLightInstance(l)
    if disabledLights[l] ~= nil then return end
    local ok, val = pcall(function() return l.Enabled end)
    if not ok then return end
    disabledLights[l] = val
    pcall(function() l.Enabled = false end)
end

local function saveAndReduceLighting()
    origLighting = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows,
        Shadows = Lighting.Shadows, FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        ClockTime = Lighting.ClockTime, ExposureCompensation = Lighting.ExposureCompensation,
        ShadowSoftness = Lighting.ShadowSoftness,
    }
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Shadows = false
        Lighting.Brightness = 0.5
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.ExposureCompensation = -0.6
        Lighting.ShadowSoftness = 0
        Lighting.Ambient = Color3.fromRGB(235, 235, 240)
        Lighting.OutdoorAmbient = Color3.fromRGB(235, 235, 240)
        Lighting.FogColor = Color3.fromRGB(240, 240, 245)
        Lighting.FogStart = 55
        Lighting.FogEnd   = 210
    end)

    for _, d in ipairs(Lighting:GetChildren()) do
        if d:IsA("Atmosphere") then
            savedAtmos[d] = {
                Density = d.Density, Haze = d.Haze, Glare = d.Glare,
                Offset = d.Offset, Color = d.Color, Decay = d.Decay,
            }
            pcall(function()
                d.Density = 0
                d.Haze = 0
                d.Glare = 0
                d.Decay = Color3.fromRGB(0, 0, 0)
                d.Color = Color3.fromRGB(255, 255, 255)
            end)
        elseif d:IsA("PostEffect") then
            disableLightInstance(d)
        end
    end

    for _, d in ipairs(Lighting:GetChildren()) do
        if d:IsA("Sky") then
            for _, child in ipairs(d:GetChildren()) do
                pcall(function() child:Destroy() end)
            end
        elseif d:IsA("Clouds") then
            pcall(function()
                d.Cover = 0
                d.Density = 0
            end)
        end
    end

    pcall(function()
        local blur = Instance.new("BlurEffect")
        blur.Name = "HykoFPSBlur"
        blur.Size = 24
        blur.Parent = Lighting
        fogBlur = blur
    end)
    pcall(function()
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "HykoFPSColor"
        cc.Brightness = 0
        cc.Contrast = -0.1
        cc.Saturation = -0.25
        cc.TintColor = Color3.fromRGB(240, 240, 245)
        cc.Parent = Lighting
        colorFix = cc
    end)
end

local function restoreLighting()
    if fogBlur and fogBlur.Parent then fogBlur:Destroy() end
    fogBlur = nil
    if colorFix and colorFix.Parent then colorFix:Destroy() end
    colorFix = nil
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
        Lighting.EnvironmentDiffuseScale = origLighting.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = origLighting.EnvironmentSpecularScale
        Lighting.ClockTime = origLighting.ClockTime
        Lighting.ExposureCompensation = origLighting.ExposureCompensation
        if origLighting.ShadowSoftness then
            Lighting.ShadowSoftness = origLighting.ShadowSoftness
        end
    end)
    for a, st in pairs(savedAtmos) do
        if a and a.Parent then
            pcall(function()
                a.Density = st.Density
                a.Haze = st.Haze
                a.Glare = st.Glare
                a.Offset = st.Offset
                a.Color = st.Color
                a.Decay = st.Decay
            end)
        end
    end
    savedAtmos = {}
    for l, state in pairs(disabledLights) do
        if l and l.Parent then pcall(function() l.Enabled = state end) end
    end
    disabledLights = {}
    origLighting = nil
end

local function saveAndReduceTerrain()
    local T = workspace.Terrain
    origTerrain = {
        WaterWaveSize = T.WaterWaveSize, WaterWaveSpeed = T.WaterWaveSpeed,
        WaterReflectance = T.WaterReflectance, WaterTransparency = T.WaterTransparency,
        Decoration = T.Decoration,
    }
    pcall(function()
        T.WaterWaveSize = 0
        T.WaterWaveSpeed = 0
        T.WaterReflectance = 0
        T.WaterTransparency = 1
        T.Decoration = false
    end)
end

local function restoreTerrain()
    if not origTerrain then return end
    pcall(function()
        local T = workspace.Terrain
        T.WaterWaveSize = origTerrain.WaterWaveSize
        T.WaterWaveSpeed = origTerrain.WaterWaveSpeed
        T.WaterReflectance = origTerrain.WaterReflectance
        T.WaterTransparency = origTerrain.WaterTransparency
        T.Decoration = origTerrain.Decoration
    end)
    origTerrain = nil
end

local function scanAndRemoveEffects()
    for _, d in ipairs(workspace:GetDescendants()) do
        if isEffect(d) then
            removeEffect(d)
        elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
            disableLightInstance(d)
        elseif d:IsA("Highlight") and not isHykoObject(d) then
            removeEffect(d)
        end
    end
end

local function enableFPSBoost()
    if fpsOn then return end
    fpsOn = true

    pcall(function()
        local r = settings().Rendering
        savedQuality = r.QualityLevel
        r.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        local r = settings().Rendering
        savedFrameRateCap = r.FramerateCap
        r.FramerateCap = 240
    end)

    pcall(saveAndReduceLighting)
    pcall(saveAndReduceTerrain)

    task.spawn(function()
        pcall(scanAndRemoveEffects)
    end)

    fpsAddedConn = workspace.DescendantAdded:Connect(function(d)
        if not fpsOn or isHykoObject(d) then return end
        if isEffect(d) then
            task.defer(function() if fpsOn then removeEffect(d) end end)
        elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
            task.defer(function() if fpsOn then disableLightInstance(d) end end)
        elseif d:IsA("Highlight") and not isHykoObject(d) then
            task.defer(function() if fpsOn then removeEffect(d) end end)
        end
    end)
end

local function disableFPSBoost()
    fpsOn = false
    if fpsAddedConn then fpsAddedConn:Disconnect() fpsAddedConn = nil end

    pcall(function()
        if savedQuality then
            settings().Rendering.QualityLevel = savedQuality
            savedQuality = nil
        end
    end)
    pcall(function()
        if savedFrameRateCap then
            settings().Rendering.FramerateCap = savedFrameRateCap
            savedFrameRateCap = nil
        end
    end)

    pcall(restoreLighting)
    pcall(restoreTerrain)
    removedEffects = {}
end

--========================================================================--
-- [9] FPS DISPLAY
--========================================================================--
local FPSDisplayGui     = nil
local fpsDisplayOn      = false
local fpsDisplayConn    = nil
local fpsFrameCount     = 0
local fpsLastClock      = 0
local fpsRefs           = {}

local FPS_COLOR_HIGH = Color3.fromRGB(46, 204, 113)
local FPS_COLOR_MID  = Color3.fromRGB(241, 196, 15)
local FPS_COLOR_LOW  = Color3.fromRGB(231, 76, 60)

local function fpsColorFor(fps)
    if fps >= 45 then return FPS_COLOR_HIGH end
    if fps >= 25 then return FPS_COLOR_MID end
    return FPS_COLOR_LOW
end

local function createFPSDisplay()
    if FPSDisplayGui then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "HykoFPSDisplay"
    mountGui(gui)

    local main = Instance.new("Frame")
    main.Name = "HykoFPSMain"
    main.Size = UDim2.fromOffset(170, 70)
    main.Position = UDim2.new(1, -190, 0, 20)
    main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    main.BackgroundTransparency = 0.05
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ZIndex = 5
    main.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(232, 234, 238)
    stroke.Thickness = 1
    stroke.Parent = main

    applyWhiteGlow(main, 12, 3, 1)

    local dot = Instance.new("Frame")
    dot.Name = "HykoFPSDot"
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.fromOffset(12, 12)
    dot.BackgroundColor3 = FPS_COLOR_HIGH
    dot.BorderSizePixel = 0
    dot.ZIndex = 6
    dot.Parent = main
    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(1, 0)
    dc.Parent = dot

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -30, 0, 20)
    header.Position = UDim2.fromOffset(26, 6)
    header.BackgroundTransparency = 1
    header.Text = "PERFORMANCE"
    header.TextColor3 = Color3.fromRGB(120, 124, 130)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 9
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 6
    header.Parent = main

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -24, 0, 1)
    sep.Position = UDim2.fromOffset(12, 26)
    sep.BackgroundColor3 = Color3.fromRGB(232, 234, 238)
    sep.BorderSizePixel = 0
    sep.ZIndex = 6
    sep.Parent = main

    local fpsNum = Instance.new("TextLabel")
    fpsNum.Name = "HykoFPSNumber"
    fpsNum.Size = UDim2.fromOffset(70, 34)
    fpsNum.Position = UDim2.fromOffset(12, 30)
    fpsNum.BackgroundTransparency = 1
    fpsNum.Text = "0"
    fpsNum.TextColor3 = FPS_COLOR_HIGH
    fpsNum.Font = Enum.Font.GothamBold
    fpsNum.TextSize = 24
    fpsNum.TextXAlignment = Enum.TextXAlignment.Left
    fpsNum.ZIndex = 6
    fpsNum.Parent = main

    local fpsUnit = Instance.new("TextLabel")
    fpsUnit.Size = UDim2.fromOffset(30, 20)
    fpsUnit.Position = UDim2.fromOffset(62, 40)
    fpsUnit.BackgroundTransparency = 1
    fpsUnit.Text = "FPS"
    fpsUnit.TextColor3 = Color3.fromRGB(120, 124, 130)
    fpsUnit.Font = Enum.Font.GothamMedium
    fpsUnit.TextSize = 11
    fpsUnit.TextXAlignment = Enum.TextXAlignment.Left
    fpsUnit.ZIndex = 6
    fpsUnit.Parent = main

    local ping = Instance.new("TextLabel")
    ping.Name = "HykoFPSPing"
    ping.Size = UDim2.fromOffset(80, 20)
    ping.Position = UDim2.new(1, -90, 0, 40)
    ping.BackgroundTransparency = 1
    ping.Text = "0 ms"
    ping.TextColor3 = Color3.fromRGB(120, 124, 130)
    ping.Font = Enum.Font.GothamMedium
    ping.TextSize = 12
    ping.TextXAlignment = Enum.TextXAlignment.Right
    ping.ZIndex = 6
    ping.Parent = main

    FPSDisplayGui = gui
    fpsRefs.number = fpsNum
    fpsRefs.ping   = ping
    fpsRefs.dot    = dot
end

local function destroyFPSDisplay()
    if FPSDisplayGui then FPSDisplayGui:Destroy() FPSDisplayGui = nil end
    fpsRefs = {}
end

local function startFPSDisplay()
    if fpsDisplayConn then return end
    createFPSDisplay()
    fpsDisplayOn = true
    fpsFrameCount = 0
    fpsLastClock = os.clock()

    fpsDisplayConn = RunService.RenderStepped:Connect(function()
        fpsFrameCount = fpsFrameCount + 1
        local now = os.clock()
        local elapsed = now - fpsLastClock
        if elapsed >= 0.5 then
            local fps = math.floor(fpsFrameCount / elapsed + 0.5)
            fpsFrameCount = 0
            fpsLastClock = now

            local pingMs = 0
            pcall(function()
                pingMs = math.floor(LP:GetNetworkPing() * 1000 + 0.5)
            end)

            if fpsRefs.number and fpsRefs.number.Parent then
                fpsRefs.number.Text = tostring(fps)
                local col = fpsColorFor(fps)
                fpsRefs.number.TextColor3 = col
                if fpsRefs.dot and fpsRefs.dot.Parent then
                    fpsRefs.dot.BackgroundColor3 = col
                end
            end
            if fpsRefs.ping and fpsRefs.ping.Parent then
                fpsRefs.ping.Text = tostring(pingMs) .. " ms"
                if pingMs < 80 then
                    fpsRefs.ping.TextColor3 = Color3.fromRGB(120, 124, 130)
                elseif pingMs < 200 then
                    fpsRefs.ping.TextColor3 = FPS_COLOR_MID
                else
                    fpsRefs.ping.TextColor3 = FPS_COLOR_LOW
                end
            end
        end
    end)
end

local function stopFPSDisplay()
    fpsDisplayOn = false
    if fpsDisplayConn then fpsDisplayConn:Disconnect() fpsDisplayConn = nil end
    destroyFPSDisplay()
end

--========================================================================--
-- [10] RETURN HOME BUTTON
--========================================================================--
local ReturnBtnGui = nil
local ReturnBtn = nil
local returnBtnConn = nil

local function destroyReturnHomeButton()
    if returnBtnConn then
        returnBtnConn:Disconnect()
        returnBtnConn = nil
    end
    if ReturnBtnGui then
        ReturnBtnGui:Destroy()
        ReturnBtnGui = nil
        ReturnBtn = nil
    end
end

local function createReturnHomeButton()
    if ReturnBtnGui then return end

    ReturnBtnGui = Instance.new("ScreenGui")
    ReturnBtnGui.Name = "HykoReturnHome"
    ReturnBtnGui.ResetOnSpawn = false
    ReturnBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mountGui(ReturnBtnGui)

    local wrap = Instance.new("Frame")
    wrap.Name = "HykoReturnWrap"
    wrap.Size = UDim2.fromOffset(180, 52)
    wrap.Position = UDim2.new(0.5, -90, 0, 24)
    wrap.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    wrap.BackgroundTransparency = 0.05
    wrap.BorderSizePixel = 0
    wrap.ZIndex = 5
    wrap.Active = true
    wrap.Parent = ReturnBtnGui

    local wc = Instance.new("UICorner")
    wc.CornerRadius = UDim.new(0, 14)
    wc.Parent = wrap

    local ws = Instance.new("UIStroke")
    ws.Color = Color3.fromRGB(232, 234, 238)
    ws.Thickness = 1
    ws.Parent = wrap

    applyWhiteGlow(wrap, 14, 3, 1)

    local iconWrap = Instance.new("Frame")
    iconWrap.Size = UDim2.fromOffset(34, 34)
    iconWrap.Position = UDim2.new(0, 12, 0.5, -17)
    iconWrap.BackgroundColor3 = Color3.fromRGB(70, 130, 230)
    iconWrap.BorderSizePixel = 0
    iconWrap.ZIndex = 6
    iconWrap.Parent = wrap
    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(1, 0)
    ic.Parent = iconWrap

    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "H"
    iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconText.Font = Enum.Font.GothamBold
    iconText.TextSize = 18
    iconText.ZIndex = 7
    iconText.Parent = iconWrap

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 18)
    title.Position = UDim2.fromOffset(56, 9)
    title.BackgroundTransparency = 1
    title.Text = "Return Home"
    title.TextColor3 = Color3.fromRGB(28, 30, 36)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 6
    title.Parent = wrap

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -60, 0, 14)
    subtitle.Position = UDim2.fromOffset(56, 27)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Tap to teleport"
    subtitle.TextColor3 = Color3.fromRGB(150, 154, 160)
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextSize = 10
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 6
    subtitle.Parent = wrap

    local chev = Instance.new("TextLabel")
    chev.Size = UDim2.fromOffset(20, 20)
    chev.Position = UDim2.new(1, -28, 0.5, -10)
    chev.BackgroundTransparency = 1
    chev.Text = ">"
    chev.TextColor3 = Color3.fromRGB(180, 184, 190)
    chev.Font = Enum.Font.GothamBold
    chev.TextSize = 18
    chev.ZIndex = 6
    chev.Parent = wrap

    local clickButton = Instance.new("TextButton")
    clickButton.Name = "ClickArea"
    clickButton.Size = UDim2.fromScale(1, 1)
    clickButton.Position = UDim2.fromScale(0, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.BorderSizePixel = 0
    clickButton.Text = ""
    clickButton.AutoButtonColor = false
    clickButton.ZIndex = 10
    clickButton.Parent = wrap

    ReturnBtn = wrap
    returnBtnConn = clickButton.Activated:Connect(function()
        beginReturnHome()
    end)

    local dragging = false
    local dragStart, startPos
    clickButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = wrap.Position
        end
    end)
    clickButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            wrap.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    clickButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    wrap.Position = UDim2.new(0.5, -90, 0, -60)
    TweenService:Create(wrap, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -90, 0, 24)
    }):Play()
end

--========================================================================--
-- [11] RETURN HOME LOGIC
--========================================================================--
local homeStatusPara = nil
local homeCFrame = nil

local function updateHomeStatus()
    if not homeStatusPara then return end
    pcall(function()
        if homePos then
            homeStatusPara:SetDesc(string.format("X: %.1f  Y: %.1f  Z: %.1f",
                homePos.X, homePos.Y, homePos.Z))
        else
            homeStatusPara:SetDesc("Not set")
        end
    end)
end

local function notify(title, content, icon)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Icon = icon or "info",
            Duration = 3,
        })
    end)
end

local function stopHomeLoop()
    if homeConn then
        homeConn:Disconnect()
        homeConn = nil
    end
end

local function setHome()
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then
        notify("Hyko", "Character not found", "alert-triangle")
        return
    end
    homeCFrame = hrp.CFrame
    homePos = homeCFrame.Position
    updateHomeStatus()
    notify("Hyko", string.format("Home set at %.1f, %.1f, %.1f",
        homePos.X, homePos.Y, homePos.Z), "check-circle")
end

local function clearHome()
    homePos = nil
    homeCFrame = nil
    returningHome = false
    stopHomeLoop()
    updateHomeStatus()
    notify("Hyko", "Home position cleared", "check-circle")
end

local function beginReturnHome()
    if not homeCFrame then
        notify("Hyko", "No home position set", "alert-triangle")
        return
    end
    if returningHome then
        notify("Hyko", "Already returning home", "info")
        return
    end

    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then
        notify("Hyko", "Character not found", "alert-triangle")
        return
    end

    returningHome = true
    stopHomeLoop()

    local ok = pcall(function()
        c:PivotTo(homeCFrame)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    returningHome = false
    if ok then
        notify("Hyko", "Arrived at home position", "check-circle")
    else
        notify("Hyko", "Teleport to home failed", "alert-triangle")
    end
end

local function cancelReturnHome()
    returningHome = false
    stopHomeLoop()
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    notify("Hyko", "Return Home cancelled", "stop-circle")
end

--========================================================================--
-- [12] SERVER HOP
--========================================================================--
local hopThreshold   = 1
local autoHopOn      = false
local autoHopThread  = nil

local function fetchServers()
    local url = "https://games.roblox.com/v1/games/" .. PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok or not raw or raw == "" then return nil end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or not data or not data.data then return nil end
    return data.data
end

local function getRandomServerId()
    local data = fetchServers()
    if not data or #data == 0 then return nil end
    local currentId = tostring(game.JobId)
    local candidates = {}
    for _, s in ipairs(data) do
        if s.id and tostring(s.id) ~= currentId then
            table.insert(candidates, tostring(s.id))
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

local function teleportToServer(serverId)
    if not serverId then return false, "No valid server ID" end
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, serverId, LP)
    end)
    return ok, err
end

local function hopOnce()
    local currentCount = #Players:GetPlayers()
    if currentCount <= hopThreshold then
        notify("Hyko Server Hop",
            "Current server meets condition (" .. currentCount .. " players)", "info")
        return false
    end
    notify("Hyko Server Hop", "Searching for a new server...", "search")
    local serverId = getRandomServerId()
    if not serverId then
        notify("Hyko Server Hop", "Failed to fetch server list", "alert-triangle")
        return false
    end
    local ok, err = teleportToServer(serverId)
    if not ok then
        notify("Hyko Server Hop", "Error: " .. tostring(err):sub(1, 60), "alert-triangle")
        return false
    end
    return true
end

--========================================================================--
-- [13] WHITE THEME
--========================================================================--
print("[Hyko] Step 4: Registering custom white theme")

WindUI:AddTheme({
    Name = "Hyko White",
    Accent = Color3.fromHex("#3B82F6"),
    Background = Color3.fromHex("#FFFFFF"),
    Outline = Color3.fromHex("#E5E7EB"),
    Text = Color3.fromHex("#1F2937"),
    Placeholder = Color3.fromHex("#9CA3AF"),
    Button = Color3.fromHex("#F3F4F6"),
    Icon = Color3.fromHex("#6B7280"),
    Dialog = Color3.fromHex("#F9FAFB"),
})

--========================================================================--
-- [14] WINDUI WINDOW
--========================================================================--
print("[Hyko] Step 5: Constructing WindUI main window")

local DEFAULT_BG_ID = 16390378968
local DEFAULT_ICON_ID = 71999030813587

local THEME_IMAGE_IDS = {
    16390378968, 16390374415, 16390370650, 16390287533, 16390276131,
    16149300225, 14780540796, 18218895340, 18218912026, 16992985181,
    16992999181, 138174781911258, 76881226512385, 18287051021,
    18287017762, 94766951507843, 16751151478, 16751045189, 115744147858434,
    133251082112509, 127176659817333, 18218963907, 16992991374, 16992994321
}

local Window = WindUI:CreateWindow({
    Title = "Hyko by Huy",
    Author = "by Huy",
    Theme = "Hyko White",
    Folder = "HykoConfig",
    Size = UDim2.fromOffset(620, 480),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    ToggleKey = Enum.KeyCode.RightShift,
    Transparent = true,
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = false,
    ScrollBarEnabled = true,
})

--========================================================================--
-- APPLY CUSTOM BACKGROUND & ICON (ImageTransparency = 0.75)
--========================================================================--
local function applyThemeToWindUI(bgId, iconId)
    task.spawn(function()
        -- Wait longer for WindUI to fully render
        task.wait(1.5)
        local iconAsset = "rbxassetid://" .. tostring(iconId)
        local bgAsset   = "rbxassetid://" .. tostring(bgId)
        
        -- Find WindUI ScreenGui reliably
        local windGui = Window.Gui
        if not windGui then
            -- Search helper function
            local function findWindGuiIn(container)
                if not container then return nil end
                for _, gui in ipairs(container:GetChildren()) do
                    if gui:IsA("ScreenGui") then
                        -- Check for typical WindUI structure
                        local hasMain = gui:FindFirstChild("Main", true) 
                            or gui:FindFirstChild("Root", true)
                            or gui:FindFirstChild("Window", true)
                        if hasMain then return gui end
                        -- Check by name patterns
                        local guiName = gui.Name:lower()
                        if string.find(guiName, "wind") or string.find(guiName, "ui") then
                            return gui
                        end
                    end
                end
                return nil
            end
            windGui = findWindGuiIn(gethui and gethui())
                or findWindGuiIn(game:GetService("CoreGui"))
                or findWindGuiIn(LP:FindFirstChildOfClass("PlayerGui"))
        end
        if not windGui then
            warn("[Hyko] WindUI ScreenGui reference not found")
            return
        end
        
        -- Find main container frame reliably
        local mainFrame = windGui:FindFirstChild("Main", true) 
            or windGui:FindFirstChild("Root", true)
            or windGui:FindFirstChild("MainFrame", true)
            or windGui:FindFirstChild("Window", true)
        if not mainFrame then
            -- Find the largest Frame that is a direct child
            local largestFrame = nil
            local largestSize = 0
            for _, d in ipairs(windGui:GetChildren()) do
                if d:IsA("Frame") then
                    local size = d.AbsoluteSize.X * d.AbsoluteSize.Y
                    if size > largestSize then
                        largestSize = size
                        largestFrame = d
                    end
                end
            end
            mainFrame = largestFrame
        end
        if not mainFrame then
            warn("[Hyko] Main container frame not found")
            return
        end

        -- BACKGROUND IMAGE - ensure it's behind everything
        local oldBg = mainFrame:FindFirstChild("HykoBg")
        if oldBg then oldBg:Destroy() end

        local bg = Instance.new("ImageLabel")
        bg.Name = "HykoBg"
        bg.Size = UDim2.fromScale(1, 1)
        bg.Position = UDim2.fromScale(0, 0)
        bg.BackgroundTransparency = 1
        bg.Image = bgAsset
        bg.ImageTransparency = 0.75 -- Keep original transparency
        bg.ScaleType = Enum.ScaleType.Crop
        bg.ZIndex = 0 -- Place at absolute bottom layer
        bg.Parent = mainFrame

        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(0, 12)
        bgCorner.Parent = bg

        -- Ensure all other elements are above background
        for _, d in ipairs(mainFrame:GetDescendants()) do
            if d ~= bg and d:IsA("GuiObject") then
                if d.ZIndex <= bg.ZIndex then
                    d.ZIndex = bg.ZIndex + 2
                end
            end
        end

        -- ICON APPLY - only target the title bar icon, not all ImageLabels
        local iconApplied = false
        local targetIcon = nil
        
        -- Strategy 1: Find icon in title bar area (small ImageLabel near top-left)
        local mainAbsPos = mainFrame.AbsolutePosition
        for _, d in ipairs(mainFrame:GetDescendants()) do
            if d:IsA("ImageLabel") and d ~= bg then
                local absPos = d.AbsolutePosition
                local relY = absPos.Y - mainAbsPos.Y
                local relX = absPos.X - mainAbsPos.X
                -- Title bar icons are typically small and near top-left corner
                if relY >= 0 and relY < 50 and relX >= 0 and relX < 50 
                    and d.AbsoluteSize.X <= 32 and d.AbsoluteSize.Y <= 32 then
                    targetIcon = d
                    break
                end
            end
        end
        
        -- Strategy 2: Look for ImageLabel with icon/logo/title in name
        if not targetIcon then
            for _, d in ipairs(mainFrame:GetDescendants()) do
                if d:IsA("ImageLabel") and d ~= bg then
                    local name = d.Name:lower()
                    if string.find(name, "icon") or string.find(name, "logo") 
                        or string.find(name, "title") or string.find(name, "image") then
                        targetIcon = d
                        break
                    end
                end
            end
        end
        
        -- Strategy 3: Find first small ImageLabel that looks like an icon
        if not targetIcon then
            for _, d in ipairs(mainFrame:GetDescendants()) do
                if d:IsA("ImageLabel") and d ~= bg 
                    and d.AbsoluteSize.X <= 40 and d.AbsoluteSize.Y <= 40 then
                    targetIcon = d
                    break
                end
            end
        end
        
        if targetIcon then
            targetIcon.Image = iconAsset
            targetIcon.ImageTransparency = 0
            targetIcon.Visible = true
            iconApplied = true
        end
        
        -- Fallback: Create custom icon in title bar area if no suitable icon found
        if not iconApplied then
            local oldIcon = mainFrame:FindFirstChild("HykoIcon")
            if oldIcon then oldIcon:Destroy() end
            
            local iconLbl = Instance.new("ImageLabel")
            iconLbl.Name = "HykoIcon"
            iconLbl.Size = UDim2.fromOffset(24, 24)
            iconLbl.Position = UDim2.fromOffset(16, 14)
            iconLbl.BackgroundTransparency = 1
            iconLbl.Image = iconAsset
            iconLbl.ImageTransparency = 0
            iconLbl.Visible = true
            iconLbl.ZIndex = 500 -- High enough to be visible above all
            iconLbl.Parent = mainFrame
            iconApplied = true
        end
        
        if iconApplied then
            print("[Hyko] Background (Transparency 0.75) and Icon applied successfully!")
        else
            warn("[Hyko] Background applied, but icon could not be placed")
        end
    end)
end

-- Initialize default Icon + Background
task.spawn(function()
    task.wait(1.5)
    applyThemeToWindUI(DEFAULT_BG_ID, DEFAULT_ICON_ID)
end)

print("[Hyko] Step 6: Window created successfully")

--========================================================================--
-- [15] TABS
--========================================================================--
local MainTab   = Window:Tab({ Title = "Main",       Icon = "layout-dashboard" })
local VisualTab = Window:Tab({ Title = "Visual",     Icon = "eye" })
local HopTab    = Window:Tab({ Title = "Server Hop", Icon = "server" })
local ThemeTab  = Window:Tab({ Title = "Theme",      Icon = "palette" })
local ConfigTab = Window:Tab({ Title = "Config",     Icon = "settings" })

if ThemeTab and ThemeTab.BuildThemeSection then
    ThemeTab:BuildThemeSection()
end
if ConfigTab and ConfigTab.BuildConfigSection then
    ConfigTab:BuildConfigSection()
end

print("[Hyko] Step 7: Navigation tabs registered")

--========================================================================--
-- [16] MAIN TAB
--========================================================================--
MainTab:Section({ Title = "Speed Controls", Box = true })

MainTab:Slider({
    Title = "Speed Value",
    Desc = "Main movement speed",
    Icon = "gauge",
    Step = 1,
    Value = { Min = 10, Max = 800, Default = 60 },
    Callback = function(value) curSpeed = value end,
})

MainTab:Slider({
    Title = "Fake WalkSpeed",
    Desc = "Displayed WalkSpeed on local fake Humanoid",
    Icon = "footprints",
    Step = 1,
    Value = { Min = 16, Max = 1000, Default = 600 },
    Callback = function(value)
        fakeWalkSpeed = value
        if driveFakeHum and driveFakeHum.Parent then
            pcall(function() driveFakeHum.WalkSpeed = fakeWalkSpeed end)
        end
    end,
})

MainTab:Toggle({
    Title = "Enable Speed",
    Desc = "Enable high-speed movement engine",
    Icon = "zap",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        speedOn = state
        refreshDrive()
        notify("Hyko", state and "Speed enabled" or "Speed disabled",
            state and "play" or "pause")
    end,
})

MainTab:Section({ Title = "Anti-Ragdoll & Anti-Knockback", Box = true })

MainTab:Slider({
    Title = "Anti-Ragdoll Speed",
    Desc = "Movement speed while Anti-Ragdoll is active",
    Icon = "shield",
    Step = 1,
    Value = { Min = 10, Max = 800, Default = 60 },
    Callback = function(value) antiRagdollSpeed = value end,
})

MainTab:Toggle({
    Title = "Enable Anti-Ragdoll (Hard Lock)",
    Desc = "Destroys character body parts + applies velocity constraint against knockback",
    Icon = "shield-check",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        antiRagdollOn = state
        refreshDrive()
        notify("Hyko",
            state and "Anti-Ragdoll enabled" or "Anti-Ragdoll disabled",
            state and "shield-check" or "shield-off")
    end,
})

MainTab:Section({ Title = "Loot System", Box = true })

MainTab:Toggle({
    Title = "Enable Fast Loot (Key E)",
    Desc = "Sets prompt HoldDuration to 0 and auto-fires nearest interaction",
    Icon = "package",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state then lootOn = true enableLoot()
        else lootOn = false disableLoot() end
    end,
})

MainTab:Section({ Title = "Hitbox Expander", Box = true })

MainTab:Slider({
    Title = "Hitbox Size",
    Desc = "Target size for other players' hitboxes",
    Icon = "target",
    Step = 1,
    Value = { Min = 1, Max = 50, Default = 15 },
    Callback = function(value) hitboxSize = value end,
})

MainTab:Toggle({
    Title = "Enable Player Hitbox Expander",
    Desc = "Enlarges character hitboxes for all other players",
    Icon = "crosshair",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state then
            hitboxOn = true
            enableHitboxAll()
            startHitboxLoop()
        else
            stopHitboxLoop()
            restoreHitboxAll()
        end
    end,
})

MainTab:Section({ Title = "Return Home", Box = true })

homeStatusPara = MainTab:Paragraph({
    Title = "Home Location",
    Desc = "Not set",
    Icon = "map-pin",
})

MainTab:Slider({
    Title = "Return Speed",
    Desc = "Teleportation velocity when returning home",
    Icon = "navigation",
    Step = 1,
    Value = { Min = 10, Max = 800, Default = 120 },
    Callback = function(value) returnSpeed = value end,
})

MainTab:Toggle({
    Title = "Show Floating Return Button",
    Desc = "On-screen quick access button for home teleportation",
    Icon = "home",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state then
            createReturnHomeButton()
        else
            destroyReturnHomeButton()
        end
    end,
})

MainTab:Button({
    Title = "Set Home (Current Location)",
    Desc = "Saves your character's current coordinates",
    Icon = "map-pin",
    Callback = function() setHome() end,
})

MainTab:Button({
    Title = "Return Home",
    Desc = "Teleport back to saved home coordinates",
    Icon = "home",
    Callback = function() beginReturnHome() end,
})

MainTab:Button({
    Title = "Cancel Return",
    Desc = "Stop the return home teleportation",
    Icon = "stop-circle",
    Callback = function() cancelReturnHome() end,
})

MainTab:Button({
    Title = "Clear Home",
    Desc = "Remove saved home position",
    Icon = "trash-2",
    Callback = function() clearHome() end,
})

MainTab:Section({ Title = "System Information", Box = true })
MainTab:Paragraph({
    Title = "Notes",
    Desc = "• Speed & Anti-Ragdoll operate on a unified local humanoid engine.\n"
        .. "• Anti-Ragdoll neutralizes body physics and fling attempts.\n"
        .. "• Fast Loot bypasses interaction delays instantly.\n"
        .. "• Hitbox Expander enlarges player body bounds.",
    Icon = "info",
})

print("[Hyko] Step 8: Main tab configured")

--========================================================================--
-- [17] VISUAL TAB
--========================================================================--
VisualTab:Section({ Title = "Player ESP", Box = true })

VisualTab:Colorpicker({
    Title = "ESP Color",
    Desc = "Highlight and billboard tag color",
    Icon = "palette",
    Color = espColor,
    Callback = function(color)
        espColor = color
        for _, e in pairs(espList) do
            if e.highlight then
                e.highlight.FillColor = color
                e.highlight.OutlineColor = color
            end
            if e.billboard then
                local lbl = e.billboard:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.TextColor3 = color end
            end
        end
    end,
})

VisualTab:Toggle({
    Title = "Enable Player ESP",
    Desc = "Highlights and displays name tags above players",
    Icon = "radar",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state then enableESP() else disableESP() end
    end,
})

VisualTab:Section({ Title = "FPS Optimization", Box = true })

VisualTab:Toggle({
    Title = "Enable FPS Boost Ultra++",
    Desc = "Reduces rendering settings and suppresses heavy visual effects",
    Icon = "rocket",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state then
            local ok, err = pcall(enableFPSBoost)
            if not ok then
                notify("Hyko", "FPS Boost error: " .. tostring(err):sub(1, 60), "alert-triangle")
            else
                notify("Hyko", "FPS Boost Ultra++ enabled", "rocket")
            end
        else
            pcall(disableFPSBoost)
            notify("Hyko", "FPS Boost disabled", "stop-circle")
        end
    end,
})

VisualTab:Button({
    Title = "Purge World Effects",
    Desc = "Manually removes particles, lights, and dynamic shadows",
    Icon = "sparkles",
    Callback = function()
        task.spawn(function()
            pcall(scanAndRemoveEffects)
        end)
        notify("Hyko", "World visual effects cleared", "sparkles")
    end,
})

VisualTab:Section({ Title = "Performance Overlay", Box = true })

VisualTab:Toggle({
    Title = "Show Performance Display",
    Desc = "Draggable FPS and Ping monitoring overlay",
    Icon = "activity",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        if state then
            startFPSDisplay()
            notify("Hyko", "Performance Display activated", "activity")
        else
            stopFPSDisplay()
            notify("Hyko", "Performance Display deactivated", "stop-circle")
        end
    end,
})

VisualTab:Section({ Title = "Optimization Overview", Box = true })
VisualTab:Paragraph({
    Title = "FPS Boost Ultra++ Details",
    Desc = "• Forces minimum rendering quality level & unlocks 240 FPS cap.\n"
        .. "• Disables global dynamic shadows, atmospheric effects & sky items.\n"
        .. "• Applies customized soft fog and blur filters for performance gain.",
    Icon = "info",
})

print("[Hyko] Step 9: Visual tab configured")

--========================================================================--
-- [18] SERVER HOP TAB
--========================================================================--
HopTab:Section({ Title = "Server Status", Box = true })

local statusPara = HopTab:Paragraph({
    Title = "Server Information",
    Desc = "Current Players: " .. #Players:GetPlayers()
        .. "\nJob ID: " .. tostring(game.JobId):sub(1, 20) .. "...",
    Icon = "server",
})

task.spawn(function()
    while Window do
        task.wait(2)
        pcall(function()
            statusPara:SetDesc("Current Players: " .. #Players:GetPlayers()
                .. "\nJob ID: " .. tostring(game.JobId):sub(1, 20) .. "...")
        end)
    end
end)

HopTab:Section({ Title = "Hop Configuration", Box = true })

HopTab:Input({
    Title = "Hop Player Threshold",
    Desc = "Minimum player count before triggering server hop",
    Placeholder = "Enter number",
    Icon = "users",
    Value = "1",
    Callback = function(text)
        local n = tonumber(text)
        if n and n >= 1 then hopThreshold = math.floor(n) end
    end,
})

HopTab:Section({ Title = "Actions", Box = true })

HopTab:Button({
    Title = "Hop Server Once",
    Desc = "Teleports to a random public game server",
    Icon = "refresh-cw",
    Callback = function() task.spawn(function() hopOnce() end) end,
})

HopTab:Toggle({
    Title = "Enable Auto Server Hop",
    Desc = "Automatically searches and teleports to new servers periodically",
    Icon = "repeat",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        autoHopOn = state
        if state then
            autoHopThread = task.spawn(function()
                while autoHopOn do
                    local count = #Players:GetPlayers()
                    if count <= hopThreshold then
                        task.wait(3)
                    else
                        hopOnce()
                        task.wait(5)
                    end
                end
            end)
        else
            if autoHopThread then
                pcall(function() task.cancel(autoHopThread) end)
                autoHopThread = nil
            end
        end
    end,
})

HopTab:Section({ Title = "Server Hop Overview", Box = true })
HopTab:Paragraph({
    Title = "Usage Guide",
    Desc = "• Hop Once: Instantly finds and connects to an active public instance.\n"
        .. "• Auto Hop: Continuously monitors player counts and hops when necessary.",
    Icon = "info",
})

print("[Hyko] Step 10: Server Hop tab configured")

--========================================================================--
-- [19] THEME TAB (CUSTOM BACKGROUNDS)
--========================================================================--
ThemeTab:Section({ Title = "Background Preset Selector", Box = true })

ThemeTab:Paragraph({
    Title = "Custom Background Library",
    Desc = "Use the slider to browse through curated background images.\n"
        .. "Applied background transparency is locked at 0.75.",
    Icon = "image",
})

ThemeTab:Slider({
    Title = "Background Selector",
    Desc = "Slide to apply a different background preset",
    Icon = "layout",
    Step = 1,
    Value = { Min = 1, Max = #THEME_IMAGE_IDS, Default = 1 },
    Callback = function(value)
        local selectedId = THEME_IMAGE_IDS[value]
        if selectedId then
            applyThemeToWindUI(selectedId, DEFAULT_ICON_ID)
            notify("Hyko", "Background updated to ID: " .. tostring(selectedId), "image")
        end
    end,
})

ThemeTab:Section({ Title = "Active Settings", Box = true })

ThemeTab:Paragraph({
    Title = "Preset Status",
    Desc = "Default Background Asset ID: 16390378968\nImage Transparency: 0.75",
    Icon = "info",
})

print("[Hyko] Step 11: Theme tab configured")

--========================================================================--
-- [20] EVENTS & CONNECTIONS
--========================================================================--
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if driveActive then
        pcall(function()
            if driveConn then driveConn:Disconnect() driveConn = nil end
            if drivePostConn then drivePostConn:Disconnect() drivePostConn = nil end
            destroyVelConstraint()
            driveActive = false
            driveRealHum = nil
            driveFakeHum = nil
            driveSavedCollide = {}
            lastSafeY = nil
            refreshDrive()
        end)
    end
    if lootOn then
        pcall(function()
            disableLoot()
            lootOn = true
            enableLoot()
        end)
    end
    if returningHome then
        pcall(function()
            stopHomeLoop()
        end)
    end
end)

Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function()
        if hitboxOn then task.wait(0.5) pcall(expandHitbox, pl) end
        if espOn then task.wait(0.5) pcall(createESP, pl) end
    end)
end)

for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LP then
        pl.CharacterAdded:Connect(function()
            if hitboxOn then task.wait(0.5) pcall(expandHitbox, pl) end
        end)
    end
end

print("[Hyko] All modules loaded and initialized successfully - WindUI Edition")
