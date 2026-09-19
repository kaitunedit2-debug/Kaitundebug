--============================================================--
--  Hyko Lite · iOS Dropdown UI
--  Features : Fast Loot  ·  Anti-Ragdoll (Hard Lock)
--  Header   : Local player avatar + name
--============================================================--

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LP           = Players.LocalPlayer

--============================================================--
-- [1] GUI MOUNT
--============================================================--
local function mountGui(gui)
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function()
        if gethui then
            gui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = game:GetService("CoreGui")
        else
            gui.Parent = LP:FindFirstChildOfClass("PlayerGui")
                or game:GetService("CoreGui")
        end
    end)
    if not ok then
        pcall(function()
            gui.Parent = LP:FindFirstChildOfClass("PlayerGui")
                or game:GetService("CoreGui")
        end)
    end
end

--============================================================--
-- [2] MOVEMENT INPUT
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
    if UIS:IsKeyDown(Enum.KeyCode.W) then d += Vector3.new(0, 0, -1) end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d += Vector3.new(0, 0, 1)  end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d += Vector3.new(-1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d += Vector3.new(1, 0, 0)  end
    return d
end

--============================================================--
-- [3] ANTI-RAGDOLL ENGINE
--============================================================--
local antiOn        = false
local antiSpeed     = 60
local fakeWalkSpeed = 600
local antiConn      = nil
local antiPost      = nil
local antiAdded     = nil
local realHum       = nil
local fakeHum       = nil

local velConstraint = nil
local velAttachment = nil

local lastSafeY          = nil
local KILL_UP_VELOCITY   = 40
local MAX_ABOVE_GROUND   = 12
local MAX_ABOVE_SAFE     = 25

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isBodyMover(d)
    return d:IsA("BodyVelocity") or d:IsA("BodyAngularVelocity")
        or d:IsA("BodyForce") or d:IsA("BodyThrust")
        or d:IsA("BodyPosition") or d:IsA("BodyGyro")
        or d:IsA("LinearVelocity") or d:IsA("AngularVelocity")
        or d:IsA("VectorForce") or d:IsA("Torque")
        or d:IsA("AlignPosition") or d:IsA("AlignOrientation")
        or d:IsA("RocketPropulsion")
end

local function buildFakeHumanoid()
    local h = Instance.new("Humanoid")
    h.Name = "Humanoid"
    h.WalkSpeed = fakeWalkSpeed
    h.JumpPower = 50
    h.UseJumpPower = true
    h.Health = 100
    h.MaxHealth = 100
    h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    h.BreakJointsOnDeath = false
    h.RequiresNeck = false
    h.EvaluateStateMachine = false
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        h:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)
    return h
end

local function stripBody(char, root)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p ~= root then
            pcall(function() p:Destroy() end)
        end
    end
end

local function createVelConstraint(hrp)
    if velConstraint then pcall(function() velConstraint:Destroy() end) end
    if velAttachment then pcall(function() velAttachment:Destroy() end) end

    local att = Instance.new("Attachment")
    att.Name = "HykoAntiFlingAttach"
    att.Parent = hrp
    velAttachment = att

    local lv = Instance.new("LinearVelocity")
    lv.Name = "HykoAntiFlingVel"
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    lv.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
    pcall(function() lv.ForceLimitsEnabled = true end)
    lv.Parent = hrp
    velConstraint = lv
end

local function destroyVelConstraint()
    if velConstraint then
        pcall(function() velConstraint:Destroy() end)
        velConstraint = nil
    end
    if velAttachment then
        pcall(function() velAttachment:Destroy() end)
        velAttachment = nil
    end
end

local function forceHealthy()
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

local function antiHeartbeat()
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    if not fakeHum or fakeHum.Parent ~= ch then
        fakeHum = buildFakeHumanoid()
        fakeHum.Parent = ch
    end
    if fakeHum.WalkSpeed ~= fakeWalkSpeed then
        pcall(function() fakeHum.WalkSpeed = fakeWalkSpeed end)
    end
    if realHum and realHum.Parent == ch then
        pcall(function() realHum.Parent = nil end)
    end

    forceHealthy()
    stripBody(ch, root)

    if not velConstraint or not velConstraint.Parent then
        createVelConstraint(root)
    end
    pcall(function() root:SetNetworkOwner(LP) end)

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

    rayParams.FilterDescendantsInstances = {ch}
    local origin = root.Position + Vector3.new(0, 4, 0)
    local result = workspace:Raycast(origin, Vector3.new(0, -120, 0), rayParams)
    local groundY = nil
    if result then
        groundY = result.Position.Y + 3.5
        lastSafeY = groundY
    end

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

    local mv = readMove()
    local targetHoriz
    if mv.Magnitude < 0.05 then
        targetHoriz = Vector3.zero
    else
        local wd = cam.CFrame.LookVector * (-mv.Z) + cam.CFrame.RightVector * mv.X
        wd = Vector3.new(wd.X, 0, wd.Z)
        if wd.Magnitude > 0.01 then
            targetHoriz = wd.Unit * antiSpeed
        else
            targetHoriz = Vector3.zero
        end
    end

    if velConstraint and velConstraint.Parent then
        velConstraint.VectorVelocity = targetHoriz
    else
        local cy = root.AssemblyLinearVelocity.Y
        root.AssemblyLinearVelocity = targetHoriz + Vector3.new(0, cy, 0)
    end

    if groundY then
        local delta = groundY - root.Position.Y
        if math.abs(delta) < 8 then
            root.CFrame = CFrame.new(root.Position.X, groundY, root.Position.Z)
                * (root.CFrame - root.Position)
            local cv = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(cv.X, 0, cv.Z)
        end
    end
end

local function antiPostSim()
    if not velConstraint or not velConstraint.Parent then return end
    local c = LP.Character
    if not c then return end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local want = velConstraint.VectorVelocity
    local cur = root.AssemblyLinearVelocity
    local dx = cur.X - want.X
    local dz = cur.Z - want.Z
    if (dx * dx + dz * dz) > 4 then
        root.AssemblyLinearVelocity = Vector3.new(want.X, cur.Y, want.Z)
    end
end

local function startAnti()
    if antiConn then return end
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    realHum = hum
    pcall(function() realHum.Parent = nil end)

    fakeHum = buildFakeHumanoid()
    fakeHum.Parent = c

    pcall(function() workspace.CurrentCamera.CameraSubject = hrp end)
    pcall(function() hrp:SetNetworkOwner(LP) end)

    lastSafeY = hrp.Position.Y
    stripBody(c, hrp)
    createVelConstraint(hrp)

    antiAdded = c.DescendantAdded:Connect(function(d)
        if not antiOn then return end
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            task.defer(function()
                if antiOn then pcall(function() d:Destroy() end) end
            end)
        elseif isBodyMover(d) and d.Name ~= "HykoAntiFlingVel" then
            task.defer(function()
                if antiOn then pcall(function() d:Destroy() end) end
            end)
        end
    end)

    antiConn = (RunService.PreSimulation or RunService.Heartbeat):Connect(antiHeartbeat)
    antiPost = (RunService.PostSimulation or RunService.Stepped):Connect(antiPostSim)
end

local function stopAnti()
    if antiAdded then antiAdded:Disconnect() antiAdded = nil end
    if antiConn then antiConn:Disconnect() antiConn = nil end
    if antiPost then antiPost:Disconnect() antiPost = nil end
    destroyVelConstraint()

    local c = LP.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        if fakeHum and fakeHum.Parent then
            pcall(function() fakeHum:Destroy() end)
        end
        fakeHum = nil
        if realHum and realHum.Parent == nil then
            pcall(function()
                realHum.Parent = c
                realHum.WalkSpeed = 16
                realHum.JumpPower = 50
            end)
        end
        realHum = nil
    end
    lastSafeY = nil
end

--============================================================--
-- [4] FAST LOOT ENGINE
--============================================================--
local lootOn     = false
local lootConn   = nil
local promptAdd  = nil
local savedHold  = {}

local function applyFastPrompt(p)
    if not p:IsA("ProximityPrompt") then return end
    if savedHold[p] == nil then savedHold[p] = p.HoldDuration end
    pcall(function() p.HoldDuration = 0 end)
end

local function restorePrompts()
    for p, h in pairs(savedHold) do
        if p and p.Parent then
            pcall(function() p.HoldDuration = h end)
        end
    end
    savedHold = {}
end

local lootParams = OverlapParams.new()
lootParams.FilterType = Enum.RaycastFilterType.Exclude

local function enableLoot()
    if lootConn then return end
    task.spawn(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then applyFastPrompt(d) end
        end
    end)
    promptAdd = workspace.DescendantAdded:Connect(function(d)
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
        lootParams.FilterDescendantsInstances = {c}
        local parts = workspace:GetPartBoundsInRadius(hrp.Position, 32, lootParams)
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
            for _, att in ipairs(part:GetChildren()) do
                if att:IsA("Attachment") then
                    for _, d in ipairs(att:GetChildren()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist <= d.MaxActivationDistance + 4
                                and dist < bestDist then
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
    if promptAdd then promptAdd:Disconnect() promptAdd = nil end
    restorePrompts()
end

--============================================================--
-- [5] PALETTE
--============================================================--
local COL = {
    bg      = Color3.fromRGB(255, 255, 255),
    text    = Color3.fromRGB(26, 28, 34),
    sub     = Color3.fromRGB(146, 150, 156),
    divider = Color3.fromRGB(240, 242, 245),
    track   = Color3.fromRGB(228, 230, 234),
    accent  = Color3.fromRGB(64, 128, 232),
    green   = Color3.fromRGB(52, 199, 89),
    stroke  = Color3.fromRGB(230, 232, 236),
}

--============================================================--
-- [6] DIMENSIONS
--============================================================--
local W_COL = 56
local H_COL = 56
local W_EXP = 300
local H_EXP = 260

--============================================================--
-- [7] SCREEN + ROOT
--============================================================--
local screen = Instance.new("ScreenGui")
screen.Name = "HykoLite"
screen.IgnoreGuiInset = true
mountGui(screen)

local main = Instance.new("Frame")
main.Name = "HykoLiteMain"
main.AnchorPoint = Vector2.new(1, 0)
main.Position    = UDim2.new(1, -22, 0, 22)
main.Size        = UDim2.fromOffset(W_COL, H_COL)
main.BackgroundColor3     = COL.bg
main.BackgroundTransparency = 0.03
main.BorderSizePixel      = 0
main.ClipsDescendants     = false
main.ZIndex = 10
main.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, W_COL / 2)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = COL.stroke
stroke.Thickness = 1
stroke.Transparency = 0.35
stroke.Parent = main

do
    for i = 1, 2 do
        local g = Instance.new("Frame")
        g.BackgroundTransparency = 1
        g.BorderSizePixel = 0
        g.Size     = UDim2.new(1, i * 7, 1, i * 7)
        g.Position = UDim2.new(0, -i * 3.5, 0, -i * 3.5)
        g.ZIndex   = 10 - i
        g.Parent   = main
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, W_COL / 2 + i * 4)
        c.Parent = g
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(255, 255, 255)
        s.Thickness = 1.2
        s.Transparency = 0.6 + (i - 1) * 0.15
        s.Parent = g
    end
end

--============================================================--
-- [8] HEADER AVATAR
--============================================================--
local avatarWrap = Instance.new("Frame")
avatarWrap.Name = "AvatarWrap"
avatarWrap.Size = UDim2.fromOffset(30, 30)
avatarWrap.Position = UDim2.fromOffset(13, 13)
avatarWrap.BackgroundColor3 = Color3.fromRGB(240, 242, 245)
avatarWrap.BorderSizePixel = 0
avatarWrap.ZIndex = 12
avatarWrap.Parent = main

local avatarCorner = Instance.new("UICorner")
avatarCorner.CornerRadius = UDim.new(1, 0)
avatarCorner.Parent = avatarWrap

local avatarImg = Instance.new("ImageLabel")
avatarImg.Name = "Avatar"
avatarImg.Size = UDim2.fromScale(1, 1)
avatarImg.BackgroundTransparency = 1
avatarImg.Image = ""
avatarImg.ZIndex = 13
avatarImg.Parent = avatarWrap

local avatarImgCorner = Instance.new("UICorner")
avatarImgCorner.CornerRadius = UDim.new(1, 0)
avatarImgCorner.Parent = avatarImg

local avatarStroke = Instance.new("UIStroke")
avatarStroke.Color = Color3.fromRGB(255, 255, 255)
avatarStroke.Thickness = 2
avatarStroke.Transparency = 0.2
avatarStroke.Parent = avatarWrap

local function loadAvatar()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(
            LP.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
    end)
    if ok and img and img ~= "" then
        avatarImg.Image = img
        return
    end
    local ok2, img2 = pcall(function()
        return Players:GetUserThumbnailAsync(
            LP.UserId,
            Enum.ThumbnailType.AvatarBust,
            Enum.ThumbnailSize.Size150x150
        )
    end)
    if ok2 and img2 and img2 ~= "" then
        avatarImg.Image = img2
    end
end

task.spawn(function()
    task.wait(0.2)
    loadAvatar()
end)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.fromOffset(10, 10)
statusDot.AnchorPoint = Vector2.new(1, 1)
statusDot.Position = UDim2.new(1, 2, 1, 2)
statusDot.BackgroundColor3 = COL.green
statusDot.BorderSizePixel = 0
statusDot.Visible = false
statusDot.ZIndex = 14
statusDot.Parent = avatarWrap

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

local dotStroke = Instance.new("UIStroke")
dotStroke.Color = Color3.fromRGB(255, 255, 255)
dotStroke.Thickness = 2
dotStroke.Parent = statusDot

--============================================================--
-- [9] HEADER TEXT
--============================================================--
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 160, 0, 18)
title.Position = UDim2.fromOffset(52, 12)
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
subtitle.Size = UDim2.new(0, 160, 0, 14)
subtitle.Position = UDim2.fromOffset(52, 29)
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

--============================================================--
-- [10] MINIMIZE BUTTON
--============================================================--
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(26, 26)
minBtn.AnchorPoint = Vector2.new(1, 0)
minBtn.Position = UDim2.new(1, -14, 0, 14)
minBtn.BackgroundColor3 = Color3.fromRGB(245, 246, 248)
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
minCorner.CornerRadius = UDim.new(1, 0)
minCorner.Parent = minBtn

local minStroke = Instance.new("UIStroke")
minStroke.Color = COL.stroke
minStroke.Thickness = 1
minStroke.Transparency = 0.3
minStroke.Parent = minBtn

--============================================================--
-- [11] BODY
--============================================================--
local body = Instance.new("CanvasGroup")
body.Size = UDim2.new(1, -32, 1, -78)
body.Position = UDim2.fromOffset(16, 60)
body.BackgroundTransparency = 1
body.GroupTransparency = 1
body.ZIndex = 11
body.Parent = main

--============================================================--
-- [12] WIDGET BUILDERS
--============================================================--
local function makeRowGlyph(parent, y, glyphType)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.fromOffset(30, 30)
    wrap.Position = UDim2.fromOffset(0, y)
    wrap.BackgroundColor3 = Color3.fromRGB(243, 245, 248)
    wrap.BorderSizePixel = 0
    wrap.ZIndex = 13
    wrap.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 9)
    c.Parent = wrap

    if glyphType == "loot" then
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromOffset(16, 16)
        img.Position = UDim2.fromOffset(7, 7)
        img.BackgroundTransparency = 1
        img.Image = "rbxassetid://6031075931"
        img.ImageColor3 = COL.accent
        img.ZIndex = 14
        img.Parent = wrap
    elseif glyphType == "shield" then
        local sh = Instance.new("Frame")
        sh.Size = UDim2.fromOffset(16, 16)
        sh.Position = UDim2.fromOffset(7, 7)
        sh.BackgroundColor3 = COL.accent
        sh.BorderSizePixel = 0
        sh.ZIndex = 14
        sh.Parent = wrap

        local shc = Instance.new("UICorner")
        shc.CornerRadius = UDim.new(0, 4)
        shc.Parent = sh

        local notch = Instance.new("Frame")
        notch.Size = UDim2.fromOffset(6, 6)
        notch.AnchorPoint = Vector2.new(0.5, 0.5)
        notch.Position = UDim2.new(0.5, 0, 0.5, 0)
        notch.BackgroundColor3 = Color3.fromRGB(243, 245, 248)
        notch.BorderSizePixel = 0
        notch.ZIndex = 15
        notch.Parent = sh

        local nc = Instance.new("UICorner")
        nc.CornerRadius = UDim.new(1, 0)
        nc.Parent = notch
    end
end

local function makeRowLabel(parent, y, titleTxt, subTxt)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -130, 0, 16)
    t.Position = UDim2.fromOffset(40, y - 1)
    t.BackgroundTransparency = 1
    t.Text = titleTxt
    t.TextColor3 = COL.text
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 13
    t.Parent = parent

    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -130, 0, 13)
    s.Position = UDim2.fromOffset(40, y + 15)
    s.BackgroundTransparency = 1
    s.Text = subTxt
    s.TextColor3 = COL.sub
    s.Font = Enum.Font.GothamMedium
    s.TextSize = 10
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.ZIndex = 13
    s.Parent = parent
end

local function makeDivider(parent, y)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, 0, 0, 1)
    d.Position = UDim2.fromOffset(0, y)
    d.BackgroundColor3 = COL.divider
    d.BorderSizePixel = 0
    d.ZIndex = 12
    d.Parent = parent
end

local function makeSwitch(parent, y)
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(44, 26)
    track.AnchorPoint = Vector2.new(1, 0)
    track.Position = UDim2.new(1, 0, 0, y)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.ZIndex = 14
    track.Parent = parent

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0)
    tc.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(22, 22)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 15
    knob.Parent = track

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    local ks = Instance.new("UIStroke")
    ks.Color = Color3.fromRGB(0, 0, 0)
    ks.Transparency = 0.9
    ks.Thickness = 1
    ks.Parent = knob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromScale(1, 1)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 16
    btn.Parent = track

    local state = false
    local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local function apply(anim)
        local bg  = state and COL.green or COL.track
        local pos = state and UDim2.new(1, -24, 0, 2) or UDim2.fromOffset(2, 2)
        if anim then
            TweenService:Create(track, ti, { BackgroundColor3 = bg }):Play()
            TweenService:Create(knob,  ti, { Position = pos }):Play()
        else
            track.BackgroundColor3 = bg
            knob.Position = pos
        end
    end
    apply(false)

    return {
        button   = btn,
        setState = function(v, anim) state = v apply(anim) end,
        getState = function() return state end,
    }
end

local function makeSlider(parent, y, min, max, default, onChange)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 5)
    track.Position = UDim2.fromOffset(0, y)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.ZIndex = 13
    track.Parent = parent

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0)
    tc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COL.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 14
    fill.Parent = track

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 15
    knob.Parent = track

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    local ks = Instance.new("UIStroke")
    ks.Color = Color3.fromRGB(0, 0, 0)
    ks.Transparency = 0.85
    ks.Thickness = 1
    ks.Parent = knob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 24, 3, 0)
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
    end
    apply(value)

    local dragging = false
    local function updateFromX(absX)
        local sx = track.AbsolutePosition.X
        local w  = track.AbsoluteSize.X
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
            updateFromX(input.Position.X)
        end
    end)
    btn.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            updateFromX(input.Position.X)
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        set = function(v) value = v apply(v) end,
        get = function() return value end,
    }
end

--============================================================--
-- [13] BODY CONTENT
--============================================================--
makeRowGlyph(body, 8, "loot")
makeRowLabel(body, 8, "Fast Loot", "Auto-collect prompts · Key E")
local lootSwitch = makeSwitch(body, 12)

makeDivider(body, 56)

makeRowGlyph(body, 72, "shield")
makeRowLabel(body, 72, "Anti-Ragdoll", "Hard lock · body-strip · anti-fling")
local antiSwitch = makeSwitch(body, 76)

makeDivider(body, 120)

local sliderLabel = Instance.new("TextLabel")
sliderLabel.Size = UDim2.new(1, -60, 0, 16)
sliderLabel.Position = UDim2.fromOffset(0, 134)
sliderLabel.BackgroundTransparency = 1
sliderLabel.Text = "Movement Speed"
sliderLabel.TextColor3 = COL.text
sliderLabel.Font = Enum.Font.GothamBold
sliderLabel.TextSize = 12
sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
sliderLabel.ZIndex = 13
sliderLabel.Parent = body

local sliderValueLbl = Instance.new("TextLabel")
sliderValueLbl.Size = UDim2.new(0, 60, 0, 16)
sliderValueLbl.Position = UDim2.new(1, -60, 0, 134)
sliderValueLbl.BackgroundTransparency = 1
sliderValueLbl.Text = tostring(antiSpeed)
sliderValueLbl.TextColor3 = COL.accent
sliderValueLbl.Font = Enum.Font.GothamBold
sliderValueLbl.TextSize = 12
sliderValueLbl.TextXAlignment = Enum.TextXAlignment.Right
sliderValueLbl.ZIndex = 13
sliderValueLbl.Parent = body

local speedSlider = makeSlider(body, 164, 20, 800, antiSpeed, function(v)
    antiSpeed = v
    sliderValueLbl.Text = tostring(v)
end)

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, 0, 0, 14)
note.Position = UDim2.fromOffset(0, 190)
note.BackgroundTransparency = 1
note.Text = "Press T · Drag header to move"
note.TextColor3 = COL.sub
note.Font = Enum.Font.GothamMedium
note.TextSize = 10
note.TextXAlignment = Enum.TextXAlignment.Left
note.ZIndex = 13
note.Parent = body

--============================================================--
-- [14] STATE
--============================================================--
local function updateStatusDot()
    statusDot.Visible = antiOn or lootOn
end

local function toggleAnti()
    local s = not antiOn
    antiSwitch.setState(s, true)
    antiOn = s
    if s then startAnti() else stopAnti() end
    updateStatusDot()
end

local function toggleLoot()
    local s = not lootOn
    lootSwitch.setState(s, true)
    lootOn = s
    if s then enableLoot() else disableLoot() end
    updateStatusDot()
end

lootSwitch.button.Activated:Connect(toggleLoot)
antiSwitch.button.Activated:Connect(toggleAnti)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Enum.KeyCode.T then
        toggleAnti()
    end
end)

--============================================================--
-- [15] EXPAND / COLLAPSE
--============================================================--
local expanded  = false
local animating = false

local function setExpanded(state)
    if animating then return end
    animating = true
    expanded = state

    local targetSize   = state and UDim2.fromOffset(W_EXP, H_EXP)
                              or UDim2.fromOffset(W_COL, H_COL)
    local targetRadius = state and UDim.new(0, 22)
                              or UDim.new(0, W_COL / 2)
    local info = TweenInfo.new(0.36, Enum.EasingStyle.Quart,
                                Enum.EasingDirection.Out)

    TweenService:Create(main,   info, { Size = targetSize }):Play()
    TweenService:Create(corner, info, { CornerRadius = targetRadius }):Play()
    TweenService:Create(title,    info,
        { TextTransparency = state and 0 or 1 }):Play()
    TweenService:Create(subtitle, info,
        { TextTransparency = state and 0 or 1 }):Play()

    minBtn.Visible = true
    TweenService:Create(minBtn, info, {
        BackgroundTransparency = state and 0 or 1,
        TextTransparency       = state and 0 or 1,
    }):Play()

    if state then
        body.Visible = true
        TweenService:Create(body, info, { GroupTransparency = 0 }):Play()
    else
        TweenService:Create(body, info, { GroupTransparency = 1 }):Play()
    end

    task.delay(0.36, function()
        animating = false
        if not expanded then
            body.Visible = false
            minBtn.Visible = false
        end
    end)
end

--============================================================--
-- [16] HEADER DRAG + TAP
--============================================================--
local headerBtn = Instance.new("TextButton")
headerBtn.Name = "HeaderButton"
headerBtn.Size = UDim2.new(1, 0, 0, 56)
headerBtn.Position = UDim2.fromOffset(0, 0)
headerBtn.BackgroundTransparency = 1
headerBtn.Text = ""
headerBtn.AutoButtonColor = false
headerBtn.ZIndex = 30
headerBtn.Parent = main

local dragStart, dragStartPos, dragging = nil, nil, false

headerBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        dragStartPos = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            dragStartPos.X.Scale,  dragStartPos.X.Offset + delta.X,
            dragStartPos.Y.Scale,  dragStartPos.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        local moved = (input.Position - dragStart).Magnitude
        dragging = false
        dragStart, dragStartPos = nil, nil
        if moved < 6 then
            setExpanded(not expanded)
        end
    end
end)

minBtn.MouseButton1Click:Connect(function()
    if not animating then setExpanded(false) end
end)

--============================================================--
-- [17] RESPAWN SAFETY
--============================================================--
LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    if antiOn then
        antiConn = nil
        antiPost = nil
        antiAdded = nil
        fakeHum = nil
        realHum = nil
        velConstraint = nil
        velAttachment = nil
        startAnti()
    end
    if lootOn then
        disableLoot()
        enableLoot()
    end
end)

print("[Hyko Lite] Loaded · Player: " .. LP.Name)