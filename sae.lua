--========================================================================--
-- Hyko by Huy
-- Local Script - Rayfield UI (Light Theme)
-- Main: Speed + Anti-Ragdoll + Click TP + Fast Loot + Hitbox + Return Home
-- Visual: ESP Players + FPS Boost (Advanced)
-- Server Hop: Hop Once + Auto Hop + Server Browser
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

--========================================================================--
-- [1] LOAD RAYFIELD (with Key System)
--========================================================================--
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Hyko by Huy",
    LoadingTitle = "Hyko by Huy",
    LoadingSubtitle = "Speed",
    Theme = "Light",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "HykoConfig"
    },
    KeySystem = true,
    KeySettings = {
        Title = "Hyko by Huy",
        Subtitle = "Key Required",
        Note = "Enter the key to continue",
        FileName = "HykoKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = { "OP" }
    }
})

local MainTab    = Window:CreateTab("Main", 4483362458)
local VisualTab  = Window:CreateTab("Visual", 4483362458)
local HopTab     = Window:CreateTab("Server Hop", 4483362458)

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
-- [3] RETURN HOME STATE
--========================================================================--
local homePos       = nil
local returningHome = false
local returnSpeed   = 120
local homeConn      = nil

--========================================================================--
-- [4] CORE DRIVE SYSTEM (Speed + Anti-Ragdoll + Click TP)
--========================================================================--
-- Common mechanism:
--   1. Real Humanoid removed locally -> no engine ragdoll / no physics.
--   2. Fake Humanoid (EvaluateStateMachine=false) injected for scripts.
--   3. All body parts locked: angular velocity zero, CanCollide off (except
--      HRP), external BodyMovers destroyed.
--   4. Movement driven manually through AssemblyLinearVelocity.
--   5. Y-lock keeps the character glued to the ground.
-- Anti-Ragdoll adds: body parts are hidden (Transparency = 1) and joints
-- neutralised so the body is visually removed while HRP keeps driving.
--========================================================================--
local driveActive       = false
local driveConn         = nil
local driveRealHum      = nil
local driveFakeHum      = nil
local driveSavedCollide = {}
local driveSavedTrans   = {}
local driveYLock        = true

local speedOn          = false
local antiRagdollOn    = false
local clickTPOn        = false

local curSpeed          = 60
local antiRagdollSpeed  = 60
local fakeWalkSpeed     = 600
local clickTPSpeed      = 150

local function anyDriveRequested()
    return speedOn or antiRagdollOn or clickTPOn
end

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
    return hum
end

local driveRayParams = RaycastParams.new()
driveRayParams.FilterType = Enum.RaycastFilterType.Exclude
driveRayParams.IgnoreWater = true

-- Click TP state
local clickTPActive = false
local clickTPTarget = nil
local clickTPBeam   = nil
local clickTPMarker = nil

local function destroyClickTPVisual()
    if clickTPBeam and clickTPBeam.Parent then clickTPBeam:Destroy() end
    if clickTPMarker and clickTPMarker.Parent then clickTPMarker:Destroy() end
    clickTPBeam = nil
    clickTPMarker = nil
end

local function createClickTPVisual(targetPos)
    destroyClickTPVisual()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local marker = Instance.new("Part")
    marker.Name = "HykoClickTPMarker"
    marker.Shape = Enum.PartType.Ball
    marker.Size = Vector3.new(2, 2, 2)
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanQuery = false
    marker.CanTouch = false
    marker.Material = Enum.Material.Neon
    marker.Color = Color3.fromRGB(70, 130, 230)
    marker.Transparency = 0.3
    marker.Position = targetPos
    marker.Parent = workspace

    local att0 = Instance.new("Attachment")
    att0.Parent = marker

    local att1 = Instance.new("Attachment")
    att1.Parent = hrp

    local beam = Instance.new("Beam")
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Width0 = 0.4
    beam.Width1 = 0.4
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.Color = ColorSequence.new(Color3.fromRGB(70, 130, 230))
    beam.Transparency = NumberSequence.new(0.15)
    beam.Parent = marker

    clickTPMarker = marker
    clickTPBeam = beam
end

-- Anti-Ragdoll hide body
local function applyHideBody()
    local c = LP.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            if driveSavedTrans[p] == nil then
                driveSavedTrans[p] = p.Transparency
            end
            pcall(function() p.Transparency = 1 end)
        end
    end
end

local function restoreHideBody()
    for p, t in pairs(driveSavedTrans) do
        if p and p.Parent then
            pcall(function() p.Transparency = t end)
        end
    end
    driveSavedTrans = {}
end

local function driveHeartbeat()
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    -- Ensure fake Humanoid is present, real Humanoid is gone
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

    -- Lock all body parts + destroy external BodyMovers
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.AssemblyAngularVelocity = Vector3.zero end)
            if p ~= root then
                pcall(function() p.AssemblyLinearVelocity = Vector3.zero end)
            end
        elseif isBodyMover(p) then
            pcall(function() p:Destroy() end)
        end
    end

    -- Anti-Ragdoll: keep body hidden
    if antiRagdollOn then
        applyHideBody()
    end

    -- Face camera direction
    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude > 0.01 then
        root.CFrame = CFrame.new(root.Position, root.Position + flat.Unit)
    end
    root.AssemblyAngularVelocity = Vector3.zero

    -- Priority 1: Click TP
    if clickTPActive and clickTPTarget then
        local diff = clickTPTarget - root.Position
        diff = Vector3.new(diff.X, 0, diff.Z)
        if diff.Magnitude < 3 then
            clickTPActive = false
            clickTPTarget = nil
            destroyClickTPVisual()
            root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
            Rayfield:Notify({
                Title = "Hyko by Huy",
                Content = "Arrived at destination",
                Duration = 2
            })
        else
            root.AssemblyLinearVelocity = diff.Unit * clickTPSpeed
                + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        end
    -- Priority 2: Return Home (velocity set by homeConn)
    elseif returningHome then
        -- handled by homeConn
    -- Priority 3: Input movement (Speed / Anti-Ragdoll)
    else
        local v = readMove()
        if v.Magnitude < 0.05 then
            root.AssemblyLinearVelocity = Vector3.new(
                0, root.AssemblyLinearVelocity.Y, 0)
        else
            local camCF = cam.CFrame
            local worldDir = camCF.LookVector * (-v.Z) + camCF.RightVector * v.X
            worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)
            if worldDir.Magnitude > 0.01 then
                root.AssemblyLinearVelocity = worldDir.Unit * activeMoveSpeed()
                    + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
            end
        end
    end

    -- Y-lock to ground
    if driveYLock then
        driveRayParams.FilterDescendantsInstances = {ch}
        local origin = root.Position + Vector3.new(0, 4, 0)
        local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), driveRayParams)
        if result then
            local targetY = result.Position.Y + 3.5
            local delta = targetY - root.Position.Y
            if math.abs(delta) < 8 and delta > 0 then
                root.CFrame = CFrame.new(root.Position.X, targetY, root.Position.Z)
                    * (root.CFrame - root.Position)
                root.AssemblyLinearVelocity = Vector3.new(
                    root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            end
        end
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

    driveSavedCollide = {}
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p ~= hrp then
            driveSavedCollide[p] = p.CanCollide
            pcall(function() p.CanCollide = false end)
        end
    end

    driveConn = RunService.Heartbeat:Connect(driveHeartbeat)

    c.DescendantAdded:Connect(function(d)
        if not driveActive then return end
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            if driveSavedCollide[d] == nil then
                driveSavedCollide[d] = d.CanCollide
            end
            pcall(function() d.CanCollide = false end)
            if antiRagdollOn and driveSavedTrans[d] == nil then
                driveSavedTrans[d] = d.Transparency
                pcall(function() d.Transparency = 1 end)
            end
        elseif isBodyMover(d) then
            task.defer(function()
                if driveActive then
                    pcall(function() d:Destroy() end)
                end
            end)
        end
    end)

    driveActive = true
    if antiRagdollOn then
        applyHideBody()
    end
    return true
end

local function stopDrive()
    if not driveActive then return end
    driveActive = false

    if driveConn then
        driveConn:Disconnect()
        driveConn = nil
    end

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
        restoreHideBody()
    end

    driveSavedCollide = {}
end

local function refreshDrive()
    if anyDriveRequested() and not driveActive then
        startDrive()
    elseif not anyDriveRequested() and driveActive then
        stopDrive()
    elseif driveActive then
        -- Anti-Ragdoll toggled off while Speed still on -> unhide body
        if not antiRagdollOn then
            restoreHideBody()
        end
    end
end

--========================================================================--
-- [5] CLICK TP INPUT
--========================================================================--
local clickTPInputConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not clickTPOn then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    local cam = workspace.CurrentCamera
    if not cam then return end
    local mouseLoc = UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {LP.Character}
    if clickTPMarker then table.insert(filterList, clickTPMarker) end
    params.FilterDescendantsInstances = filterList
    params.IgnoreWater = true

    local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
    if result then
        clickTPTarget = result.Position + Vector3.new(0, 3, 0)
        clickTPActive = true
        createClickTPVisual(result.Position)
    end
end)

--========================================================================--
-- [6] FAST LOOT
--========================================================================--
local lootOn       = false
local lootConn     = nil
local promptAdded  = nil
local savedPrompts = {}

local function applyFastPrompt(p)
    if not p:IsA("ProximityPrompt") then return end
    if savedPrompts[p] == nil then
        savedPrompts[p] = p.HoldDuration
    end
    pcall(function() p.HoldDuration = 0 end)
end

local function restorePrompts()
    for p, hold in pairs(savedPrompts) do
        if p and p.Parent then
            pcall(function() p.HoldDuration = hold end)
        end
    end
    savedPrompts = {}
end

local function enableLoot()
    if lootConn then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        applyFastPrompt(d)
    end
    promptAdded = workspace.DescendantAdded:Connect(function(d)
        if lootOn then applyFastPrompt(d) end
    end)

    lootConn = UIS.InputBegan:Connect(function(input, gpe)
        if not lootOn then return end
        if gpe then return end
        if input.KeyCode ~= Enum.KeyCode.E then return end
        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local best, bestDist = nil, math.huge
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                local par = d.Parent
                local pos
                if par and par:IsA("BasePart") then
                    pos = par.Position
                elseif par and par:IsA("Attachment") and par.Parent and par.Parent:IsA("BasePart") then
                    pos = par.Parent.Position
                end
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist <= d.MaxActivationDistance + 4 and dist < bestDist then
                        best, bestDist = d, dist
                    end
                end
            end
        end
        if best then
            pcall(function() fireproximityprompt(best) end)
        end
    end)
end

local function disableLoot()
    if lootConn then lootConn:Disconnect() lootConn = nil end
    if promptAdded then promptAdded:Disconnect() promptAdded = nil end
    restorePrompts()
end

--========================================================================--
-- [7] HITBOX EXPAND
--========================================================================--
local hitboxOn    = false
local hitboxSize  = 15
local hitboxData  = {}

local function expandHitbox(pl)
    if pl == LP then return end
    local c = pl.Character
    if not c then return end
    local data = hitboxData[pl]
    if not data then
        data = { parts = {}, trans = {} }
        hitboxData[pl] = data
    end
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
        if pl ~= LP then
            pcall(expandHitbox, pl)
        end
    end
end

local function restoreHitboxAll()
    for pl in pairs(hitboxData) do
        pcall(restoreHitbox, pl)
    end
    hitboxData = {}
end

local hitboxLoop = nil
local function startHitboxLoop()
    if hitboxLoop then return end
    hitboxLoop = task.spawn(function()
        while hitboxOn do
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    pcall(expandHitbox, pl)
                end
            end
            task.wait(0.5)
        end
    end)
end

local function stopHitboxLoop()
    hitboxOn = false
end

Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function()
        if hitboxOn then
            task.wait(0.5)
            pcall(expandHitbox, pl)
        end
    end)
end)
for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LP then
        pl.CharacterAdded:Connect(function()
            if hitboxOn then
                task.wait(0.5)
                pcall(expandHitbox, pl)
            end
        end)
    end
end

--========================================================================--
-- [8] ESP PLAYERS
--========================================================================--
local espOn    = false
local espColor = Color3.fromRGB(70, 130, 230)
local espList  = {}
local espLoop  = nil

local function removeESP(pl)
    local e = espList[pl]
    if not e then return end
    if e.highlight then e.highlight:Destroy() end
    if e.billboard then e.billboard:Destroy() end
    if e.conn then e.conn:Disconnect() end
    espList[pl] = nil
end

local function removeAllESP()
    for pl in pairs(espList) do
        removeESP(pl)
    end
    espList = {}
end

local function createESP(pl)
    if pl == LP then return end
    if espList[pl] then return end
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
        if espOn then
            removeESP(pl)
            createESP(pl)
        end
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
                if pl ~= LP and not espList[pl] then
                    createESP(pl)
                end
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
-- [9] FPS BOOST - ADVANCED
--========================================================================--
local fpsOn              = false
local fpsLoop            = nil
local fpsAddedConn       = nil
local removedEffects     = {}
local disabledPostFX     = {}
local origLighting       = nil
local origTerrain        = nil
local savedQuality       = nil
local savedFrameRateCap  = nil

local function isEffect(d)
    return d:IsA("ParticleEmitter")
        or d:IsA("Trail")
        or d:IsA("Beam")
        or d:IsA("Smoke")
        or d:IsA("Fire")
        or d:IsA("Sparkles")
        or d:IsA("Explosion")
        or d:IsA("SurfaceAppearance")
        or d:IsA("SelectionBox")
        or d:IsA("SelectionSphere")
        or d:IsA("Decal")
        or d:IsA("Texture")
end

local function isSafeToRemove(d)
    local c = LP.Character
    if c and d:IsDescendantOf(c) then return false end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character and d:IsDescendantOf(pl.Character) then return false end
    end
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg and d:IsDescendantOf(pg) then
        if d:IsA("ScreenGui") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
            return false
        end
    end
    return true
end

local function removeEffect(d)
    if not isSafeToRemove(d) then return end
    if removedEffects[d] then return end
    removedEffects[d] = true
    pcall(function() d:Destroy() end)
end

local function saveAndReduceLighting()
    origLighting = {
        Ambient                   = Lighting.Ambient,
        OutdoorAmbient            = Lighting.OutdoorAmbient,
        Brightness                = Lighting.Brightness,
        GlobalShadows             = Lighting.GlobalShadows,
        Shadows                   = Lighting.Shadows,
        FogEnd                    = Lighting.FogEnd,
        FogStart                  = Lighting.FogStart,
        FogColor                  = Lighting.FogColor,
        EnvironmentDiffuseScale   = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale  = Lighting.EnvironmentSpecularScale,
        ClockTime                 = Lighting.ClockTime,
        ExposureCompensation      = Lighting.ExposureCompensation,
    }
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Shadows = false
        Lighting.Brightness = 1
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
        Lighting.ExposureCompensation = 0
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    end)
    for _, d in ipairs(Lighting:GetChildren()) do
        if d:IsA("PostEffect") or d:IsA("Atmosphere") or d:IsA("Sky") then
            if disabledPostFX[d] == nil then
                disabledPostFX[d] = d.Enabled
                pcall(function() d.Enabled = false end)
            end
        end
    end
    for _, d in ipairs(Lighting:GetChildren()) do
        if d:IsA("Sky") then
            for _, child in ipairs(d:GetChildren()) do
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local function restoreLighting()
    if not origLighting then return end
    pcall(function()
        Lighting.Ambient                   = origLighting.Ambient
        Lighting.OutdoorAmbient            = origLighting.OutdoorAmbient
        Lighting.Brightness                = origLighting.Brightness
        Lighting.GlobalShadows             = origLighting.GlobalShadows
        Lighting.Shadows                   = origLighting.Shadows
        Lighting.FogEnd                    = origLighting.FogEnd
        Lighting.FogStart                  = origLighting.FogStart
        Lighting.FogColor                  = origLighting.FogColor
        Lighting.EnvironmentDiffuseScale   = origLighting.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale  = origLighting.EnvironmentSpecularScale
        Lighting.ClockTime                 = origLighting.ClockTime
        Lighting.ExposureCompensation      = origLighting.ExposureCompensation
    end)
    for fx, state in pairs(disabledPostFX) do
        if fx and fx.Parent then
            pcall(function() fx.Enabled = state end)
        end
    end
    disabledPostFX = {}
    origLighting = nil
end

local function saveAndReduceTerrain()
    local T = workspace.Terrain
    origTerrain = {
        WaterWaveSize      = T.WaterWaveSize,
        WaterWaveSpeed     = T.WaterWaveSpeed,
        WaterReflectance   = T.WaterReflectance,
        WaterTransparency  = T.WaterTransparency,
        Decoration         = T.Decoration,
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

local function reduceAllMeshParts()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("MeshPart") then
            pcall(function()
                d.RenderFidelity = Enum.RenderFidelity.Performance
                d.CastShadow = false
            end)
        elseif d:IsA("BasePart") then
            pcall(function()
                if d:IsDescendantOf(workspace) then
                    d.CastShadow = false
                end
            end)
        end
    end
end

local function scanAndRemoveEffects()
    for _, d in ipairs(workspace:GetDescendants()) do
        if isEffect(d) then
            removeEffect(d)
        end
    end
end

local function enableFPSBoost()
    fpsOn = true

    pcall(function()
        savedQuality = settings().Rendering.QualityLevel
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    pcall(function()
        savedFrameRateCap = settings().Rendering.FramerateCap
        settings().Rendering.FramerateCap = 240
    end)

    saveAndReduceLighting()
    saveAndReduceTerrain()
    scanAndRemoveEffects()
    reduceAllMeshParts()

    fpsAddedConn = workspace.DescendantAdded:Connect(function(d)
        if fpsOn and isEffect(d) then
            removeEffect(d)
        end
    end)

    fpsLoop = task.spawn(function()
        while fpsOn do
            scanAndRemoveEffects()
            reduceAllMeshParts()
            task.wait(3)
        end
    end)
end

local function disableFPSBoost()
    fpsOn = false
    if fpsAddedConn then fpsAddedConn:Disconnect() fpsAddedConn = nil end
    if fpsLoop then pcall(function() task.cancel(fpsLoop) end) fpsLoop = nil end

    if savedQuality then
        pcall(function() settings().Rendering.QualityLevel = savedQuality end)
        savedQuality = nil
    end
    if savedFrameRateCap then
        pcall(function() settings().Rendering.FramerateCap = savedFrameRateCap end)
        savedFrameRateCap = nil
    end

    restoreLighting()
    restoreTerrain()
    removedEffects = {}
end

--========================================================================--
-- [10] EXTERNAL RETURN HOME BUTTON
--========================================================================--
local ReturnBtnGui = nil
local ReturnBtn = nil

local function createReturnHomeButton()
    if ReturnBtnGui then return end

    ReturnBtnGui = Instance.new("ScreenGui")
    ReturnBtnGui.Name = "HykoReturnHome"
    ReturnBtnGui.ResetOnSpawn = false
    ReturnBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if gethui then
        ReturnBtnGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ReturnBtnGui)
        ReturnBtnGui.Parent = game.CoreGui
    else
        ReturnBtnGui.Parent = LP:FindFirstChildOfClass("PlayerGui") or game.CoreGui
    end

    ReturnBtn = Instance.new("TextButton")
    ReturnBtn.Name = "ReturnHomeBtn"
    ReturnBtn.Size = UDim2.fromOffset(140, 42)
    ReturnBtn.Position = UDim2.new(0.5, -70, 0, 20)
    ReturnBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ReturnBtn.BackgroundTransparency = 0.05
    ReturnBtn.Text = ""
    ReturnBtn.AutoButtonColor = false
    ReturnBtn.Active = true
    ReturnBtn.Draggable = true
    ReturnBtn.Parent = ReturnBtnGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = ReturnBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(232, 234, 238)
    stroke.Thickness = 1
    stroke.Parent = ReturnBtn

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.fromOffset(22, 42)
    icon.Position = UDim2.fromOffset(10, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "H"
    icon.TextColor3 = Color3.fromRGB(70, 130, 230)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 20
    icon.TextXAlignment = Enum.TextXAlignment.Center
    icon.Parent = ReturnBtn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.fromOffset(34, 0)
    label.BackgroundTransparency = 1
    label.Text = "Return Home"
    label.TextColor3 = Color3.fromRGB(28, 30, 36)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = ReturnBtn

    ReturnBtn.MouseEnter:Connect(function()
        TweenService:Create(ReturnBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.fromRGB(70, 130, 230),
            BackgroundTransparency = 0
        }):Play()
        TweenService:Create(label, TweenInfo.new(0.15), {
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        TweenService:Create(icon, TweenInfo.new(0.15), {
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(70, 130, 230)
        }):Play()
    end)

    ReturnBtn.MouseLeave:Connect(function()
        TweenService:Create(ReturnBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.05
        }):Play()
        TweenService:Create(label, TweenInfo.new(0.15), {
            TextColor3 = Color3.fromRGB(28, 30, 36)
        }):Play()
        TweenService:Create(icon, TweenInfo.new(0.15), {
            TextColor3 = Color3.fromRGB(70, 130, 230)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(232, 234, 238)
        }):Play()
    end)

    ReturnBtn.MouseButton1Down:Connect(function()
        TweenService:Create(ReturnBtn, TweenInfo.new(0.08), {
            Size = UDim2.fromOffset(136, 40)
        }):Play()
    end)
    ReturnBtn.MouseButton1Up:Connect(function()
        TweenService:Create(ReturnBtn, TweenInfo.new(0.08), {
            Size = UDim2.fromOffset(140, 42)
        }):Play()
    end)

    ReturnBtn.Position = UDim2.new(0.5, -70, 0, -50)
    TweenService:Create(ReturnBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -70, 0, 20)
    }):Play()
end

local function destroyReturnHomeButton()
    if ReturnBtnGui then
        ReturnBtnGui:Destroy()
        ReturnBtnGui = nil
        ReturnBtn = nil
    end
end

--========================================================================--
-- [11] RETURN HOME LOGIC
--========================================================================--
local homeStatusPara = nil

local function updateHomeStatus()
    if not homeStatusPara then return end
    if homePos then
        homeStatusPara:Set({
            Title = "Home Position",
            Content = string.format("X: %.1f  Y: %.1f  Z: %.1f",
                homePos.X, homePos.Y, homePos.Z)
        })
    else
        homeStatusPara:Set({
            Title = "Home Position",
            Content = "Not set"
        })
    end
end

local function setHome()
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = "Character not found",
            Duration = 3
        })
        return
    end
    homePos = hrp.Position
    updateHomeStatus()
    Rayfield:Notify({
        Title = "Hyko by Huy",
        Content = string.format("Home set at %.1f, %.1f, %.1f",
            homePos.X, homePos.Y, homePos.Z),
        Duration = 3
    })
end

local function clearHome()
    homePos = nil
    updateHomeStatus()
    Rayfield:Notify({
        Title = "Hyko by Huy",
        Content = "Home cleared",
        Duration = 2
    })
end

local function startHomeLoop()
    if homeConn then return end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LP.Character}
    rayParams.IgnoreWater = true

    homeConn = RunService.Heartbeat:Connect(function()
        if not returningHome or not homePos then return end

        local c = LP.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        rayParams.FilterDescendantsInstances = {c}

        local diff = homePos - hrp.Position
        local flatDiff = Vector3.new(diff.X, 0, diff.Z)

        if flatDiff.Magnitude < 3 then
            returningHome = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            Rayfield:Notify({
                Title = "Hyko by Huy",
                Content = "Arrived at home",
                Duration = 3
            })
            return
        end

        local dir = flatDiff.Unit
        hrp.AssemblyLinearVelocity = dir * returnSpeed
            + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)

        if driveYLock then
            local origin = hrp.Position + Vector3.new(0, 4, 0)
            local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
            if result then
                local targetY = result.Position.Y + 3.5
                local delta = targetY - hrp.Position.Y
                if math.abs(delta) < 8 and delta > 0 then
                    hrp.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z)
                        * (hrp.CFrame - hrp.Position)
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
                end
            end
        end
    end)
end

local function stopHomeLoop()
    if homeConn then
        homeConn:Disconnect()
        homeConn = nil
    end
end

local function beginReturnHome()
    if not homePos then
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = "No home position set",
            Duration = 3
        })
        return
    end
    if returningHome then
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = "Already returning home",
            Duration = 2
        })
        return
    end
    returningHome = true
    startHomeLoop()
    Rayfield:Notify({
        Title = "Hyko by Huy",
        Content = "Returning to home...",
        Duration = 3
    })
end

local function cancelReturnHome()
    if not returningHome then
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = "Not currently returning home",
            Duration = 2
        })
        return
    end
    returningHome = false
    stopHomeLoop()
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    Rayfield:Notify({
        Title = "Hyko by Huy",
        Content = "Return Home stopped",
        Duration = 2
    })
end

task.spawn(function()
    while not ReturnBtn do task.wait(0.1) end
    ReturnBtn.MouseButton1Click:Connect(function()
        beginReturnHome()
    end)
end)

--========================================================================--
-- [12] SERVER HOP
--========================================================================--
local hopThreshold   = 1
local autoHopOn      = false
local autoHopThread  = nil
local serverBrowser  = nil
local serverCache    = {}
local currentSort    = "players_asc"

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
    if not serverId then return false, "No server id" end
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, serverId, LP)
    end)
    return ok, err
end

local function hopOnce()
    local currentCount = #Players:GetPlayers()

    if currentCount <= hopThreshold then
        Rayfield:Notify({
            Title = "Hyko Server Hop",
            Content = "Current server meets condition (" .. currentCount .. " players)",
            Duration = 3
        })
        return false
    end

    Rayfield:Notify({
        Title = "Hyko Server Hop",
        Content = "Searching for a new server...",
        Duration = 3
    })

    local serverId = getRandomServerId()
    if not serverId then
        Rayfield:Notify({
            Title = "Hyko Server Hop",
            Content = "Failed to fetch server list",
            Duration = 3
        })
        return false
    end

    local ok, err = teleportToServer(serverId)
    if not ok then
        Rayfield:Notify({
            Title = "Hyko Server Hop",
            Content = "Error: " .. tostring(err):sub(1, 60),
            Duration = 4
        })
        return false
    end

    return true
end

--========================================================================--
-- [13] UI - MAIN TAB
--========================================================================--
MainTab:CreateSection("Speed")

MainTab:CreateSlider({
    Name = "Speed Value",
    Range = {10, 800},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 60,
    Flag = "SpeedValue",
    Callback = function(value)
        curSpeed = value
    end
})

MainTab:CreateSlider({
    Name = "Fake WalkSpeed",
    Range = {16, 1000},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 600,
    Flag = "FakeWalk",
    Callback = function(value)
        fakeWalkSpeed = value
        if driveFakeHum and driveFakeHum.Parent then
            pcall(function() driveFakeHum.WalkSpeed = fakeWalkSpeed end)
        end
    end
})

MainTab:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = false,
    Flag = "SpeedToggle",
    Callback = function(state)
        speedOn = state
        refreshDrive()
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = state and "Speed enabled" or "Speed disabled",
            Duration = 2
        })
    end
})

MainTab:CreateSection("Anti-Ragdoll")

MainTab:CreateSlider({
    Name = "Anti-Ragdoll Speed",
    Range = {10, 800},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 60,
    Flag = "AntiRagdollSpeed",
    Callback = function(value)
        antiRagdollSpeed = value
    end
})

MainTab:CreateToggle({
    Name = "Enable Anti-Ragdoll (Hide Body)",
    CurrentValue = false,
    Flag = "AntiRagdollToggle",
    Callback = function(state)
        antiRagdollOn = state
        refreshDrive()
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = state and "Anti-Ragdoll enabled" or "Anti-Ragdoll disabled",
            Duration = 2
        })
    end
})

MainTab:CreateSection("Click TP")

MainTab:CreateSlider({
    Name = "Click TP Speed",
    Range = {10, 800},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 150,
    Flag = "ClickTPSpeed",
    Callback = function(value)
        clickTPSpeed = value
    end
})

MainTab:CreateToggle({
    Name = "Enable Click TP (Mouse Left)",
    CurrentValue = false,
    Flag = "ClickTPToggle",
    Callback = function(state)
        clickTPOn = state
        if not state then
            clickTPActive = false
            clickTPTarget = nil
            destroyClickTPVisual()
        end
        refreshDrive()
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = state and "Click TP enabled - click to teleport"
                or "Click TP disabled",
            Duration = 3
        })
    end
})

MainTab:CreateSection("Loot")

MainTab:CreateToggle({
    Name = "Enable Fast Loot (Key E)",
    CurrentValue = false,
    Flag = "LootToggle",
    Callback = function(state)
        if state then
            lootOn = true
            enableLoot()
        else
            lootOn = false
            disableLoot()
        end
    end
})

MainTab:CreateSection("Hitbox Expand")

MainTab:CreateSlider({
    Name = "Hitbox Size",
    Range = {1, 50},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 15,
    Flag = "HitboxSize",
    Callback = function(value)
        hitboxSize = value
    end
})

MainTab:CreateToggle({
    Name = "Enable Hitbox Expand (Players)",
    CurrentValue = false,
    Flag = "HitboxToggle",
    Callback = function(state)
        if state then
            hitboxOn = true
            enableHitboxAll()
            startHitboxLoop()
        else
            stopHitboxLoop()
            restoreHitboxAll()
        end
    end
})

MainTab:CreateSection("Return Home")

homeStatusPara = MainTab:CreateParagraph({
    Title = "Home Position",
    Content = "Not set"
})

MainTab:CreateSlider({
    Name = "Return Speed",
    Range = {10, 800},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 120,
    Flag = "ReturnSpeed",
    Callback = function(value)
        returnSpeed = value
    end
})

MainTab:CreateToggle({
    Name = "Show Return Home Button",
    CurrentValue = false,
    Flag = "ShowReturnBtn",
    Callback = function(state)
        if state then
            createReturnHomeButton()
        else
            destroyReturnHomeButton()
        end
    end
})

MainTab:CreateButton({
    Name = "Set Home (current position)",
    Flag = "SetHome",
    Callback = function()
        setHome()
    end
})

MainTab:CreateButton({
    Name = "Return Home",
    Flag = "ReturnHomeBtn",
    Callback = function()
        beginReturnHome()
    end
})

MainTab:CreateButton({
    Name = "Stop Return Home",
    Flag = "StopReturnHome",
    Callback = function()
        cancelReturnHome()
    end
})

MainTab:CreateButton({
    Name = "Clear Home",
    Flag = "ClearHome",
    Callback = function()
        clearHome()
    end
})

MainTab:CreateSection("Info")
MainTab:CreateParagraph({
    Title = "Notes",
    Content = "Speed and Anti-Ragdoll share the same drive system:\n"
        .. "- Real Humanoid is removed locally, fake Humanoid is injected "
        .. "(EvaluateStateMachine = false).\n"
        .. "- Movement is driven manually every Heartbeat through "
        .. "AssemblyLinearVelocity.\n\n"
        .. "Anti-Ragdoll adds:\n"
        .. "- Every BasePart except HumanoidRootPart is hidden (Transparency = 1) "
        .. "so the body visually disappears and cannot be ragdolled.\n"
        .. "- All body parts' velocities are zeroed every frame and external "
        .. "BodyMovers are destroyed.\n\n"
        .. "Click TP:\n"
        .. "- Enable the toggle, then left-click anywhere in the world.\n"
        .. "- A blue beam and marker appear at the clicked spot.\n"
        .. "- The character moves to that spot at the Click TP Speed.\n\n"
        .. "Fast Loot sets ProximityPrompt HoldDuration to 0 and fires the "
        .. "nearest prompt with Key E.\n\n"
        .. "Hitbox Expand enlarges other players and makes them semi-transparent.\n\n"
        .. "Return Home is triggered by button, and can also be triggered from "
        .. "the external floating Return Home button."
})

--========================================================================--
-- [14] UI - VISUAL TAB
--========================================================================--
VisualTab:CreateSection("ESP")

VisualTab:CreateColorPicker({
    Name = "ESP Color",
    Color = espColor,
    Flag = "ESPColor",
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
    end
})

VisualTab:CreateToggle({
    Name = "Enable ESP Players",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(state)
        if state then
            enableESP()
        else
            disableESP()
        end
    end
})

VisualTab:CreateSection("FPS Boost")

VisualTab:CreateToggle({
    Name = "Enable FPS Boost (Advanced)",
    CurrentValue = false,
    Flag = "FPSToggle",
    Callback = function(state)
        if state then
            enableFPSBoost()
            Rayfield:Notify({
                Title = "Hyko by Huy",
                Content = "FPS Boost enabled",
                Duration = 3
            })
        else
            disableFPSBoost()
            Rayfield:Notify({
                Title = "Hyko by Huy",
                Content = "FPS Boost disabled",
                Duration = 3
            })
        end
    end
})

VisualTab:CreateButton({
    Name = "Clean Effects Now",
    Flag = "CleanEffects",
    Callback = function()
        scanAndRemoveEffects()
        reduceAllMeshParts()
        Rayfield:Notify({
            Title = "Hyko by Huy",
            Content = "Effects cleared",
            Duration = 2
        })
    end
})

VisualTab:CreateSection("Info")
VisualTab:CreateParagraph({
    Title = "FPS Boost Details",
    Content = "Lowers rendering quality to minimum, disables all lighting shadows and post effects, "
        .. "disables Skybox children, reduces terrain water detail, strips particle emitters, trails, "
        .. "beams, smoke, fire, sparkles, explosions, surface appearances, selection boxes, decals "
        .. "and textures outside player characters, and lowers render fidelity of all MeshParts."
})

--========================================================================--
-- [15] UI - SERVER HOP TAB
--========================================================================--
HopTab:CreateSection("Status")

local statusParagraph = HopTab:CreateParagraph({
    Title = "Server Information",
    Content = "Current Players: " .. #Players:GetPlayers()
        .. "\nJob ID: " .. tostring(game.JobId):sub(1, 20) .. "..."
})

task.spawn(function()
    while Window do
        task.wait(2)
        pcall(function()
            statusParagraph:Set({
                Title = "Server Information",
                Content = "Current Players: " .. #Players:GetPlayers()
                    .. "\nJob ID: " .. tostring(game.JobId):sub(1, 20) .. "..."
            })
        end)
    end
end)

HopTab:CreateSection("Configuration")

HopTab:CreateInput({
    Name = "Hop Threshold (players)",
    CurrentValue = "1",
    PlaceholderText = "Enter number",
    RemoveTextAfterFocusLost = false,
    Flag = "HopThreshold",
    Callback = function(text)
        local n = tonumber(text)
        if n and n >= 1 then
            hopThreshold = math.floor(n)
        end
    end
})

HopTab:CreateSection("Actions")

HopTab:CreateButton({
    Name = "Hop Once",
    Flag = "HopOnce",
    Callback = function()
        task.spawn(function()
            hopOnce()
        end)
    end
})

HopTab:CreateToggle({
    Name = "Auto Hop",
    CurrentValue = false,
    Flag = "AutoHop",
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
    end
})

--========================================================================--
-- [16] SERVER BROWSER WINDOW
--========================================================================--
local function formatJobId(id)
    if not id then return "N/A" end
    local str = tostring(id)
    if #str > 12 then
        return str:sub(1, 10) .. "..."
    end
    return str
end

local function openServerBrowser()
    if serverBrowser then
        pcall(function() serverBrowser:Destroy() end)
        serverBrowser = nil
    end

    serverBrowser = Rayfield:CreateWindow({
        Name = "Server Browser",
        LoadingTitle = "Server Browser",
        LoadingSubtitle = "Hyko by Huy",
        Theme = "Light",
        ConfigurationSaving = { Enabled = false },
        KeySystem = false
    })

    local BrowserTab = serverBrowser:CreateTab("Servers", 4483362458)

    BrowserTab:CreateSection("Options")

    BrowserTab:CreateInput({
        Name = "Search (Job ID or players)",
        CurrentValue = "",
        PlaceholderText = "Type to search...",
        RemoveTextAfterFocusLost = false,
        Flag = "SearchServers",
        Callback = function() end
    })

    BrowserTab:CreateDropdown({
        Name = "Sort Order",
        Options = { "Players (Low to High)", "Players (High to Low)" },
        CurrentOption = { "Players (Low to High)" },
        Flag = "ServerSort",
        Callback = function(opt)
            local val = opt[1]
            if val == "Players (High to Low)" then
                currentSort = "players_desc"
            else
                currentSort = "players_asc"
            end
        end
    })

    local serverDropdown = BrowserTab:CreateDropdown({
        Name = "Servers",
        Options = { "Loading..." },
        CurrentOption = { "Loading..." },
        Flag = "ServerSelected",
        Callback = function() end
    })

    local infoPara = BrowserTab:CreateParagraph({
        Title = "Selected Server",
        Content = "No server selected"
    })

    BrowserTab:CreateButton({
        Name = "Refresh Server List",
        Flag = "RefreshServers",
        Callback = function()
            task.spawn(function()
                serverDropdown:Refresh({ "Loading..." }, true)

                local data = fetchServers()
                if not data or #data == 0 then
                    serverDropdown:Refresh({ "No servers found" }, true)
                    infoPara:Set({
                        Title = "Selected Server",
                        Content = "No servers found"
                    })
                    return
                end

                local currentId = tostring(game.JobId)
                local filtered = {}
                for _, s in ipairs(data) do
                    if tostring(s.id) ~= currentId then
                        table.insert(filtered, s)
                    end
                end

                if currentSort == "players_desc" then
                    table.sort(filtered, function(a, b)
                        return (a.playing or 0) > (b.playing or 0)
                    end)
                else
                    table.sort(filtered, function(a, b)
                        return (a.playing or 0) < (b.playing or 0)
                    end)
                end

                serverCache = filtered

                local opts = {}
                local map = {}
                for i, s in ipairs(filtered) do
                    local label = formatJobId(s.id) .. " | "
                        .. tostring(s.playing or 0) .. "/"
                        .. tostring(s.maxPlayers or "?") .. " players"
                    table.insert(opts, label)
                    map[label] = tostring(s.id)
                end
                serverCache._map = map

                if #opts == 0 then
                    opts = { "No servers found" }
                end

                serverDropdown:Refresh(opts, true)
            end)
        end
    })

    BrowserTab:CreateButton({
        Name = "Join Selected Server",
        Flag = "JoinServer",
        Callback = function()
            local selected = serverDropdown.CurrentOption
            if not selected or #selected == 0 then
                Rayfield:Notify({
                    Title = "Server Browser",
                    Content = "No server selected",
                    Duration = 3
                })
                return
            end
            local label = selected[1]
            local map = serverCache._map
            if not map or not map[label] then
                Rayfield:Notify({
                    Title = "Server Browser",
                    Content = "Invalid selection",
                    Duration = 3
                })
                return
            end
            local jobId = map[label]
            infoPara:Set({
                Title = "Selected Server",
                Content = "Joining " .. jobId
            })
            local ok, err = teleportToServer(jobId)
            if not ok then
                Rayfield:Notify({
                    Title = "Server Browser",
                    Content = "Error: " .. tostring(err):sub(1, 60),
                    Duration = 4
                })
            end
        end
    })

    BrowserTab:CreateSection("Info")
    BrowserTab:CreateParagraph({
        Title = "How to use",
        Content = "1. Click Refresh Server List.\n2. Pick a server from the Servers dropdown.\n3. Click Join Selected Server."
    })
end

HopTab:CreateSection("Server Browser")

HopTab:CreateButton({
    Name = "Open Server Browser",
    Flag = "OpenBrowser",
    Callback = function()
        openServerBrowser()
    end
})

HopTab:CreateSection("Info")
HopTab:CreateParagraph({
    Title = "Notes",
    Content = "Hop Once: teleports to a random public server if current player count is above threshold.\n"
        .. "Auto Hop: repeats the hop every few seconds when the condition is met.\n"
        .. "Server Browser: list public servers, sort by player count, search, and join."
})

--========================================================================--
-- [17] RESPAWN
--========================================================================--
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if driveActive then
        pcall(function()
            if driveConn then driveConn:Disconnect() driveConn = nil end
            driveActive = false
            driveRealHum = nil
            driveFakeHum = nil
            driveSavedCollide = {}
            driveSavedTrans = {}
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
            startHomeLoop()
        end)
    end
end)

print("[Hyko by Huy] Loaded")