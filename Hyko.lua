--[[
    HYKO • ESP + FAST LOOT + AUTO LOOT + ANTI-RAGDOLL + FPS BOOST  (v7)
    Rebuilt inside lates-lib UI.

    Changes in v7
      · Show UI reverted: hides the entire lates-lib ScreenGui
        (notifications are hidden too — as requested)
      · Auto Loot fixed: on finding a ProximityPrompt it now forces
        HoldDuration = 0 (same trick Fast Loot uses) before firing,
        so it works in games that use hold prompts.
      · Everything else unchanged.
--]]

--// Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local LP               = Players.LocalPlayer

--============================================================--
-- LIBRARY (before/after GUI capture)
--============================================================--
local function collectGuis()
    local set = {}
    local containers = {}
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(containers, pg) end
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then table.insert(containers, h) end
    end
    pcall(function()
        local cg = game:GetService("CoreGui")
        if cg then table.insert(containers, cg) end
    end)
    for _, c in ipairs(containers) do
        pcall(function()
            for _, g in ipairs(c:GetChildren()) do
                if g:IsA("ScreenGui") then set[g] = true end
            end
        end)
    end
    return set
end

local guisBefore = collectGuis()

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/lxte/lates-lib/main/Main.lua"))()
local Window = Library:CreateWindow({
    Title            = "Hyko",
    Theme            = "Light",
    Size             = UDim2.fromOffset(570, 370),
    Transparency     = 0.2,
    Blurring         = true,
    MinimizeKeybind  = Enum.KeyCode.LeftAlt,
})

local libGui = nil
do
    for _ = 1, 40 do
        local now = collectGuis()
        for g in pairs(now) do
            if not guisBefore[g] then libGui = g break end
        end
        if libGui then break end
        task.wait(0.05)
    end
    if not libGui then
        local function watch(container)
            if not container then return end
            pcall(function()
                container.ChildAdded:Connect(function(child)
                    if libGui then return end
                    if child:IsA("ScreenGui") and not guisBefore[child] then
                        libGui = child
                    end
                end)
            end)
        end
        watch(LP:FindFirstChildOfClass("PlayerGui"))
        if gethui then
            local ok, h = pcall(gethui)
            if ok then watch(h) end
        end
    end
end

--============================================================--
-- THEMES
--============================================================--
local Themes = {
    Light = {
        Primary = Color3.fromRGB(232,232,232), Secondary = Color3.fromRGB(255,255,255),
        Component = Color3.fromRGB(245,245,245), Interactables = Color3.fromRGB(235,235,235),
        Tab = Color3.fromRGB(50,50,50), Title = Color3.fromRGB(0,0,0), Description = Color3.fromRGB(100,100,100),
        Shadow = Color3.fromRGB(255,255,255), Outline = Color3.fromRGB(210,210,210), Icon = Color3.fromRGB(100,100,100),
    },
    Dark = {
        Primary = Color3.fromRGB(30,30,30), Secondary = Color3.fromRGB(35,35,35),
        Component = Color3.fromRGB(40,40,40), Interactables = Color3.fromRGB(45,45,45),
        Tab = Color3.fromRGB(200,200,200), Title = Color3.fromRGB(240,240,240), Description = Color3.fromRGB(200,200,200),
        Shadow = Color3.fromRGB(0,0,0), Outline = Color3.fromRGB(40,40,40), Icon = Color3.fromRGB(220,220,220),
    },
    Void = {
        Primary = Color3.fromRGB(15,15,15), Secondary = Color3.fromRGB(20,20,20),
        Component = Color3.fromRGB(25,25,25), Interactables = Color3.fromRGB(30,30,30),
        Tab = Color3.fromRGB(200,200,200), Title = Color3.fromRGB(240,240,240), Description = Color3.fromRGB(200,200,200),
        Shadow = Color3.fromRGB(0,0,0), Outline = Color3.fromRGB(40,40,40), Icon = Color3.fromRGB(220,220,220),
    },
}

Window:SetTheme(Themes.Light)

Window:AddTabSection({ Name = "Main",     Order = 1 })
Window:AddTabSection({ Name = "Settings", Order = 2 })

local Visuals = Window:AddTab({
    Title = "Visuals", Section = "Main",
    Icon = "rbxassetid://11963373994",
})
local Utility = Window:AddTab({
    Title = "Utility", Section = "Main",
    Icon = "rbxassetid://11293977610",
})
local Settings = Window:AddTab({
    Title = "Settings", Section = "Settings",
    Icon = "rbxassetid://11293977610",
})

--============================================================--
-- HELPERS
--============================================================--
local function safeDestroy(x)
    if x then pcall(function() x:Destroy() end) end
end

local function disconnect(x)
    if x and typeof(x) == "RBXScriptConnection" then
        pcall(function() x:Disconnect() end)
    end
end

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Transparency = transparency or 0
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local function notify(title, desc, duration)
    pcall(function()
        Window:Notify({
            Title = title, Description = desc, Duration = duration or 3,
        })
    end)
end

local Theme = {
    accent = Color3.fromRGB(10, 132, 255),
    panel  = Color3.fromRGB(255, 255, 255),
    stroke = Color3.fromRGB(226, 229, 235),
    text   = Color3.fromRGB(17, 19, 24),
    sub    = Color3.fromRGB(125, 130, 140),
}

--============================================================--
-- ESP
--============================================================--
local espOn            = false
local ESP_MAX_DISTANCE = 1200
local ESP_UPDATE_INTERVAL = 0.20

local espEntries     = {}
local espConnections = {}
local espFolder = Instance.new("Folder")
espFolder.Name = "HykoESP"
espFolder.Parent = workspace

local function getRootHum(char)
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if root and hum and hum.Health > 0 then return root, hum end
end

local function makeESP(plr)
    if not espOn or plr == LP then return end
    local char = plr.Character
    local root, hum = getRootHum(char)
    if not root then return end

    local old = espEntries[plr]
    if old and old.character == char then return end
    if old then
        safeDestroy(old.highlight)
        safeDestroy(old.billboard)
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "HykoESPHighlight"
    highlight.Adornee = char
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.88
    highlight.OutlineTransparency = 0.08
    highlight.FillColor = Theme.accent
    highlight.OutlineColor = Theme.accent
    highlight.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HykoESPNameTag"
    billboard.Adornee = root
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = ESP_MAX_DISTANCE
    billboard.Size = UDim2.fromOffset(128, 27)
    billboard.StudsOffset = Vector3.new(0, 2.7, 0)
    billboard.Parent = espFolder

    local card = Instance.new("Frame")
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Theme.panel
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel = 0
    card.Parent = billboard
    makeCorner(card, 6)
    local stroke = makeStroke(card, Theme.stroke, 0.30, 1)

    local accentDot = Instance.new("Frame")
    accentDot.Size = UDim2.fromOffset(4, 4)
    accentDot.Position = UDim2.fromOffset(7, 6)
    accentDot.BackgroundColor3 = Theme.accent
    accentDot.BorderSizePixel = 0
    accentDot.Parent = card
    makeCorner(accentDot, 3)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.fromOffset(16, 1)
    nameLabel.Size = UDim2.new(1, -22, 0, 13)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 8
    nameLabel.TextColor3 = Theme.text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Text = plr.DisplayName
    nameLabel.Parent = card

    local subLabel = Instance.new("TextLabel")
    subLabel.BackgroundTransparency = 1
    subLabel.Position = UDim2.fromOffset(16, 14)
    subLabel.Size = UDim2.new(1, -22, 0, 10)
    subLabel.Font = Enum.Font.GothamMedium
    subLabel.TextSize = 7
    subLabel.TextColor3 = Theme.sub
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Text = "-- m  •  100%"
    subLabel.Parent = card

    espEntries[plr] = {
        player = plr, character = char, root = root, hum = hum,
        highlight = highlight, billboard = billboard, card = card,
        stroke = stroke, accentDot = accentDot,
        nameLabel = nameLabel, subLabel = subLabel,
    }
end

local function removeESP(plr)
    local e = espEntries[plr]
    if not e then return end
    safeDestroy(e.highlight)
    safeDestroy(e.billboard)
    espEntries[plr] = nil
end

local function updateESPEntry(e, myRoot)
    if not e or not e.player then return end
    local plr = e.player
    local char = plr.Character
    local root, hum = getRootHum(char)
    if not root then removeESP(plr); return end
    if e.character ~= char then
        makeESP(plr)
        e = espEntries[plr]
        if not e then return end
        root, hum = getRootHum(char)
        if not root then return end
    end

    e.billboard.MaxDistance = ESP_MAX_DISTANCE

    local distance = myRoot and (myRoot.Position - root.Position).Magnitude or 0
    local visible  = distance <= ESP_MAX_DISTANCE
    e.highlight.Enabled = visible
    e.billboard.Enabled = visible

    e.highlight.FillColor   = Theme.accent
    e.highlight.OutlineColor = Theme.accent
    e.stroke.Color           = Theme.stroke
    e.card.BackgroundColor3  = Theme.panel
    e.accentDot.BackgroundColor3 = Theme.accent
    e.nameLabel.TextColor3   = Theme.text
    e.subLabel.TextColor3    = Theme.sub

    local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    e.subLabel.Text = string.format("%dm  •  %d%%",
        math.floor(distance + 0.5), math.floor(hp * 100 + 0.5))
end

local function bindPlayerESP(plr)
    if plr == LP then return end
    disconnect(espConnections[plr])
    espConnections[plr] = plr.CharacterAdded:Connect(function()
        task.wait(0.10)
        if espOn then makeESP(plr) end
    end)
    task.defer(function() if espOn then makeESP(plr) end end)
end

local function enableESP()
    if espOn then return end
    espOn = true
    for _, plr in ipairs(Players:GetPlayers()) do bindPlayerESP(plr) end
    espConnections.added = Players.PlayerAdded:Connect(bindPlayerESP)
    espConnections.removing = Players.PlayerRemoving:Connect(function(plr)
        disconnect(espConnections[plr])
        espConnections[plr] = nil
        removeESP(plr)
    end)
end

local function disableESP()
    if not espOn then return end
    espOn = false
    for plr, conn in pairs(espConnections) do
        if typeof(conn) == "RBXScriptConnection" then disconnect(conn) end
        espConnections[plr] = nil
    end
    for plr in pairs(espEntries) do removeESP(plr) end
end

task.spawn(function()
    while true do
        task.wait(ESP_UPDATE_INTERVAL)
        if espOn then
            local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            for _, e in pairs(espEntries) do updateESPEntry(e, myRoot) end
        end
    end
end)

--============================================================--
-- FAST LOOT
--============================================================--
local lootOn = false
local lootConnection
local promptAddedConnection
local savedPromptHold = {}

local function optimizePrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if savedPromptHold[prompt] == nil then
        savedPromptHold[prompt] = prompt.HoldDuration
    end
    pcall(function() prompt.HoldDuration = 0 end)
end

local function restorePrompts()
    for prompt, old in pairs(savedPromptHold) do
        if prompt and prompt.Parent then
            pcall(function() prompt.HoldDuration = old end)
        end
    end
    table.clear(savedPromptHold)
end

local function enableLoot()
    if lootOn then return end
    lootOn = true
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then optimizePrompt(obj) end
    end
    disconnect(promptAddedConnection)
    promptAddedConnection = workspace.DescendantAdded:Connect(function(obj)
        if lootOn and obj:IsA("ProximityPrompt") then optimizePrompt(obj) end
    end)
end

local function disableLoot()
    lootOn = false
    disconnect(promptAddedConnection); promptAddedConnection = nil
    disconnect(lootConnection); lootConnection = nil
    restorePrompts()
end

--============================================================--
-- AUTO LOOT (nearest, forces HoldDuration = 0 before firing)
--============================================================--
local autoLootOn      = false
local autoLootRadius  = 32
local autoLootRunning = false
local autoSavedHold   = {}

local lootRayParams = OverlapParams.new()
lootRayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Force instant activation on prompts auto loot touches.
-- Prefer Fast Loot's saved table if Fast Loot already owns the prompt.
local function autoOptimizePrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if savedPromptHold[prompt] == nil and autoSavedHold[prompt] == nil then
        autoSavedHold[prompt] = prompt.HoldDuration
    end
    pcall(function() prompt.HoldDuration = 0 end)
end

local function restoreAutoPrompts()
    for prompt, old in pairs(autoSavedHold) do
        if prompt and prompt.Parent and savedPromptHold[prompt] == nil then
            pcall(function() prompt.HoldDuration = old end)
        end
    end
    table.clear(autoSavedHold)
end

local function findNearestPrompt()
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    lootRayParams.FilterDescendantsInstances = {c}
    local parts = workspace:GetPartBoundsInRadius(hrp.Position, autoLootRadius, lootRayParams)
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
    return best
end

local function autoLootLoop()
    if autoLootRunning then return end
    autoLootRunning = true
    task.spawn(function()
        while autoLootOn do
            local prompt = findNearestPrompt()
            if prompt then
                -- Make it instant (Fast Loot trick) then fire.
                autoOptimizePrompt(prompt)
                pcall(function() fireproximityprompt(prompt) end)
            end
            task.wait(0.08)
        end
        autoLootRunning = false
    end)
end

local function enableAutoLoot()
    if autoLootOn then return end
    autoLootOn = true
    autoLootLoop()
end

local function disableAutoLoot()
    if not autoLootOn then return end
    autoLootOn = false
    task.wait(0.15)
    restoreAutoPrompts()
end

--============================================================--
-- FPS BOOST (fog removed, stronger)
--============================================================--
local boostOn = false
local boostBusy = false
local boostConnections = {}

local boostSaved = {
    quality = nil, cap = nil, lighting = nil, terrain = nil,
    effects = {}, lights = {}, atmospheres = {}, shadows = {},
    reflect = {}, decals = {}, fidelity = {},
    sky = nil, skyChildren = {}, clouds = {},
}

local function isBoostSafe(d)
    if not d or not d.Parent then return false end
    if d.Name and d.Name:sub(1, 4) == "Hyko" then return false end
    local c = LP.Character
    if c and d:IsDescendantOf(c) then return false end
    for _, pl in ipairs(Players:GetPlayers()) do
        local pc = pl.Character
        if pc and d:IsDescendantOf(pc) then return false end
    end
    return true
end

local function saveOnce(tbl, obj, value)
    if tbl[obj] == nil then tbl[obj] = value end
end

local function optimizeVisual(obj)
    if not boostOn or not isBoostSafe(obj) then return end

    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
        or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        saveOnce(boostSaved.effects, obj, obj.Enabled)
        pcall(function()
            obj.Enabled = false
            if obj:IsA("ParticleEmitter") then obj:Clear() end
        end)
        return
    end

    if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
        saveOnce(boostSaved.lights, obj, {Enabled = obj.Enabled, Shadows = obj.Shadows})
        pcall(function() obj.Enabled = false; obj.Shadows = false end)
        return
    end

    if obj:IsA("PostEffect") then
        saveOnce(boostSaved.effects, obj, obj.Enabled)
        pcall(function() obj.Enabled = false end)
        return
    end

    if obj:IsA("Atmosphere") then
        saveOnce(boostSaved.atmospheres, obj,
            {Density = obj.Density, Haze = obj.Haze, Glare = obj.Glare})
        pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
        return
    end

    if obj:IsA("Clouds") then
        saveOnce(boostSaved.clouds, obj, {Cover = obj.Cover, Density = obj.Density})
        pcall(function() obj.Cover = 0; obj.Density = 0 end)
        return
    end

    if obj:IsA("Decal") or obj:IsA("Texture") then
        saveOnce(boostSaved.decals, obj, obj.Transparency)
        pcall(function() obj.Transparency = 1 end)
        return
    end

    if obj:IsA("BasePart") then
        saveOnce(boostSaved.shadows, obj, obj.CastShadow)
        pcall(function() obj.CastShadow = false end)

        if obj.Reflectance > 0 then
            saveOnce(boostSaved.reflect, obj, obj.Reflectance)
            pcall(function() obj.Reflectance = 0 end)
        end

        if obj:IsA("MeshPart") then
            saveOnce(boostSaved.fidelity, obj, obj.RenderFidelity)
            pcall(function() obj.RenderFidelity = Enum.RenderFidelity.Performance end)
        end
        return
    end
end

local function optimizeLighting()
    if not boostSaved.lighting then
        boostSaved.lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            Brightness = Lighting.Brightness,
            EnvD = Lighting.EnvironmentDiffuseScale,
            EnvS = Lighting.EnvironmentSpecularScale,
            Exposure = Lighting.ExposureCompensation,
        }
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0.5
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.ExposureCompensation = -0.5
    end)

    for _, o in ipairs(Lighting:GetDescendants()) do
        if o:IsA("Atmosphere") then
            saveOnce(boostSaved.atmospheres, o,
                {Density = o.Density, Haze = o.Haze, Glare = o.Glare})
            pcall(function() o.Density = 0; o.Haze = 0; o.Glare = 0 end)
        elseif o:IsA("PostEffect") then
            saveOnce(boostSaved.effects, o, o.Enabled)
            pcall(function() o.Enabled = false end)
        elseif o:IsA("Clouds") then
            saveOnce(boostSaved.clouds, o, {Cover = o.Cover, Density = o.Density})
            pcall(function() o.Cover = 0; o.Density = 0 end)
        elseif o:IsA("Sky") then
            if not boostSaved.sky then
                boostSaved.sky = o
                for _, ch in ipairs(o:GetChildren()) do
                    boostSaved.skyChildren[ch] = true
                    pcall(function() ch.Parent = nil end)
                end
            end
        end
    end
end

local function restoreLighting()
    local s = boostSaved.lighting
    if s then
        pcall(function()
            Lighting.GlobalShadows = s.GlobalShadows
            Lighting.Brightness = s.Brightness
            Lighting.EnvironmentDiffuseScale = s.EnvD
            Lighting.EnvironmentSpecularScale = s.EnvS
            Lighting.ExposureCompensation = s.Exposure
        end)
    end
    boostSaved.lighting = nil

    if boostSaved.sky and boostSaved.sky.Parent then
        for ch in pairs(boostSaved.skyChildren) do
            if ch and ch.Parent == nil then
                pcall(function() ch.Parent = boostSaved.sky end)
            end
        end
    end
    boostSaved.sky = nil
    boostSaved.skyChildren = {}
end

local function optimizeTerrain()
    local t = workspace:FindFirstChildOfClass("Terrain")
    if not t or boostSaved.terrain then return end
    boostSaved.terrain = {
        WaterWaveSize = t.WaterWaveSize, WaterWaveSpeed = t.WaterWaveSpeed,
        WaterReflectance = t.WaterReflectance, WaterTransparency = t.WaterTransparency,
        Decoration = t.Decoration,
    }
    pcall(function()
        t.WaterWaveSize = 0; t.WaterWaveSpeed = 0
        t.WaterReflectance = 0; t.WaterTransparency = 1
        t.Decoration = false
    end)
end

local function restoreTerrain()
    local t = workspace:FindFirstChildOfClass("Terrain")
    local s = boostSaved.terrain
    if t and s then
        pcall(function()
            t.WaterWaveSize = s.WaterWaveSize; t.WaterWaveSpeed = s.WaterWaveSpeed
            t.WaterReflectance = s.WaterReflectance; t.WaterTransparency = s.WaterTransparency
            t.Decoration = s.Decoration
        end)
    end
    boostSaved.terrain = nil
end

local function setQuality(low)
    local ok, s = pcall(function() return UserSettings():GetService("UserGameSettings") end)
    if not ok or not s then return end
    if low then
        if boostSaved.quality == nil then
            local got, cur = pcall(function() return s.SavedQualityLevel end)
            if got then boostSaved.quality = cur end
        end
        pcall(function() s.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
    elseif boostSaved.quality ~= nil then
        local old = boostSaved.quality
        pcall(function() s.SavedQualityLevel = old end)
        boostSaved.quality = nil
    end
    pcall(function()
        local r = settings().Rendering
        if low then
            if boostSaved.cap == nil then boostSaved.cap = r.FramerateCap end
            r.FramerateCap = 240
        elseif boostSaved.cap then
            r.FramerateCap = boostSaved.cap
            boostSaved.cap = nil
        end
    end)
end

local function scanExisting()
    boostBusy = true
    local list = workspace:GetDescendants()
    local batch = 350
    for i = 1, #list, batch do
        if not boostOn then break end
        for j = i, math.min(i + batch - 1, #list) do
            optimizeVisual(list[j])
        end
        RunService.Heartbeat:Wait()
    end
    boostBusy = false
end

local function enableBoost()
    if boostOn then return end
    boostOn = true
    setQuality(true)
    optimizeLighting()
    optimizeTerrain()
    disconnect(boostConnections.added)
    boostConnections.added = workspace.DescendantAdded:Connect(function(o)
        if boostOn then
            task.defer(function() if boostOn then optimizeVisual(o) end end)
        end
    end)
    task.spawn(scanExisting)
end

local function restoreBoost()
    for o, v in pairs(boostSaved.effects) do
        if o and o.Parent then pcall(function() o.Enabled = v end) end
    end
    for o, v in pairs(boostSaved.lights) do
        if o and o.Parent then pcall(function() o.Enabled = v.Enabled; o.Shadows = v.Shadows end) end
    end
    for o, v in pairs(boostSaved.atmospheres) do
        if o and o.Parent then pcall(function() o.Density = v.Density; o.Haze = v.Haze; o.Glare = v.Glare end) end
    end
    for o, v in pairs(boostSaved.clouds) do
        if o and o.Parent then pcall(function() o.Cover = v.Cover; o.Density = v.Density end) end
    end
    for o, v in pairs(boostSaved.shadows) do
        if o and o.Parent then pcall(function() o.CastShadow = v end) end
    end
    for o, v in pairs(boostSaved.reflect) do
        if o and o.Parent then pcall(function() o.Reflectance = v end) end
    end
    for o, v in pairs(boostSaved.decals) do
        if o and o.Parent then pcall(function() o.Transparency = v end) end
    end
    for o, v in pairs(boostSaved.fidelity) do
        if o and o.Parent then pcall(function() o.RenderFidelity = v end) end
    end
    boostSaved.effects = {}; boostSaved.lights = {}
    boostSaved.atmospheres = {}; boostSaved.clouds = {}
    boostSaved.shadows = {}; boostSaved.reflect = {}
    boostSaved.decals = {}; boostSaved.fidelity = {}
    restoreLighting(); restoreTerrain()
end

local function disableBoost()
    if not boostOn then return end
    boostOn = false
    disconnect(boostConnections.added); boostConnections.added = nil
    boostBusy = false
    restoreBoost()
    setQuality(false)
end

--============================================================--
-- ANTI-RAGDOLL
--============================================================--
local antiOn    = false
local antiSpeed = 60

local antiConn, antiPost, antiAdded, antiJumpConn, antiStateConn
local realHum, fakeHum
local moveAtt, moveVel, faceAtt, faceAlign
local lastSafeY, housekeeping = nil, 0
local bodySnap = {}

local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude
rayP.IgnoreWater = true

local KILL_UP, ABOVE_GROUND, UPRIGHT_THRESHOLD = 40, 12, 0.85

local BAD_STATES = {
    [Enum.HumanoidStateType.Ragdoll]          = true,
    [Enum.HumanoidStateType.FallingDown]      = true,
    [Enum.HumanoidStateType.Physics]          = true,
    [Enum.HumanoidStateType.PlatformStanding] = true,
    [Enum.HumanoidStateType.GettingUp]        = true,
}

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
        for name, enabled in pairs({
            Ragdoll = false, FallingDown = false, Physics = false,
            PlatformStanding = false, GettingUp = false,
            Climbing = false, Swimming = false,
        }) do
            h:SetStateEnabled(Enum.HumanoidStateType[name], enabled)
        end
    end)
    return h
end

local function snapPart(p)
    if bodySnap[p] then return end
    bodySnap[p] = { cc = p.CanCollide, m = p.Massless }
end

local function neutralizeBodyPart(p)
    snapPart(p)
    pcall(function()
        if p.CanCollide then p.CanCollide = false end
        if not p.Massless then p.Massless = true end
        p.AssemblyLinearVelocity = Vector3.zero
        p.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function buildBodyCache(char, root)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p ~= root then neutralizeBodyPart(p) end
    end
end

local function restoreAnti(char)
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

local function makeConstraints(root)
    if moveAtt then pcall(function() moveAtt:Destroy() end) end
    if moveVel then pcall(function() moveVel:Destroy() end) end
    if faceAtt then pcall(function() faceAtt:Destroy() end) end
    if faceAlign then pcall(function() faceAlign:Destroy() end) end

    local mAtt = Instance.new("Attachment")
    mAtt.Name = "HykoMoveAtt"; mAtt.Parent = root; moveAtt = mAtt

    local lv = Instance.new("LinearVelocity")
    lv.Name = "HykoMoveVel"; lv.Attachment0 = mAtt
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    lv.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
    pcall(function() lv.ForceLimitsEnabled = true end)
    lv.Parent = root; moveVel = lv

    local fAtt = Instance.new("Attachment")
    fAtt.Name = "HykoFaceAtt"; fAtt.Parent = root; faceAtt = fAtt

    local ao = Instance.new("AlignOrientation")
    ao.Name = "HykoFaceAlign"; ao.Attachment0 = fAtt
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.PrimaryAxisOnly = true; ao.RigidityEnabled = true
    ao.MaxTorque = 1e7; ao.Responsiveness = 100
    ao.Parent = root; faceAlign = ao
end

local function killConstraints()
    if moveAtt then pcall(function() moveAtt:Destroy() end) end
    if moveVel then pcall(function() moveVel:Destroy() end) end
    if faceAtt then pcall(function() faceAtt:Destroy() end) end
    if faceAlign then pcall(function() faceAlign:Destroy() end) end
    moveAtt, moveVel, faceAtt, faceAlign = nil, nil, nil, nil
end

local function resetState()
    if not fakeHum or not fakeHum.Parent then return end
    pcall(function()
        if fakeHum.PlatformStand then fakeHum.PlatformStand = false end
        if fakeHum.Sit then fakeHum.Sit = false end
        fakeHum.AutoRotate = false
        if BAD_STATES[fakeHum:GetState()] then
            fakeHum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

local function forceUpright(root, cam)
    if root.CFrame.UpVector.Y < UPRIGHT_THRESHOLD then
        local look = cam.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0.01 then
            root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
        end
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

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
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then d += Vector3.new(0,0,-1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then d += Vector3.new(0,0,1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then d += Vector3.new(-1,0,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then d += Vector3.new(1,0,0) end
    return d
end

local function heartbeat(dt)
    local ch = LP.Character; if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
    local cam = workspace.CurrentCamera; if not cam then return end

    if not fakeHum or fakeHum.Parent ~= ch then
        fakeHum = buildFakeHum(); fakeHum.Parent = ch
    end
    if realHum and realHum.Parent == ch then
        pcall(function() realHum.Parent = nil end)
    end

    if not moveVel or not moveVel.Parent or not faceAlign or not faceAlign.Parent then
        makeConstraints(root)
    end

    forceUpright(root, cam)

    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude > 0.01 then
        faceAlign.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
    end

    local mv = readMove()
    local target = Vector3.zero
    if mv.Magnitude > 0.05 then
        local wd = cam.CFrame.LookVector * (-mv.Z) + cam.CFrame.RightVector * mv.X
        wd = Vector3.new(wd.X, 0, wd.Z)
        if wd.Magnitude > 0.01 then target = wd.Unit * antiSpeed end
    end
    moveVel.VectorVelocity = target

    local vel = root.AssemblyLinearVelocity
    if vel.Y > KILL_UP then
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
    end

    housekeeping = housekeeping + dt
    if housekeeping >= 0.1 then
        housekeeping = 0
        resetState()
        for _, d in ipairs(ch:GetDescendants()) do
            if isMover(d) and d ~= moveVel and d ~= faceAlign then
                pcall(function() d:Destroy() end)
            end
        end
    end
end

local function postSim()
    if not antiOn then return end
    local ch = LP.Character; if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
    rayP.FilterDescendantsInstances = {ch}
    local origin = root.Position + Vector3.new(0, 4, 0)
    local res = workspace:Raycast(origin, Vector3.new(0, -120, 0), rayP)
    if res then
        local gy = res.Position.Y + 3.5
        lastSafeY = gy
        if root.Position.Y > gy + ABOVE_GROUND then
            local vel = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
            if root.Position.Y > gy + ABOVE_GROUND + 20 then
                root.CFrame = CFrame.new(root.Position.X, gy, root.Position.Z)
                    * (root.CFrame - root.Position)
            end
        end
    elseif lastSafeY and root.Position.Y > lastSafeY + 30 then
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
    end
end

local function doJump()
    if not antiOn then return end
    local ch = LP.Character; if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart"); if not root then return end
    rayP.FilterDescendantsInstances = {ch}
    if workspace:Raycast(root.Position, Vector3.new(0, -4, 0), rayP) then
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 55, vel.Z)
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

    antiStateConn = fakeHum.StateChanged:Connect(function(_, newState)
        if not antiOn then return end
        if BAD_STATES[newState] then
            task.defer(function()
                if antiOn and fakeHum and fakeHum.Parent then
                    pcall(function() fakeHum:ChangeState(Enum.HumanoidStateType.Running) end)
                end
            end)
        end
    end)

    pcall(function() workspace.CurrentCamera.CameraSubject = hrp end)
    pcall(function() hrp:SetNetworkOwner(LP) end)

    lastSafeY = hrp.Position.Y; housekeeping = 0
    bodySnap = {}
    buildBodyCache(c, hrp)
    makeConstraints(hrp)

    antiAdded = c.DescendantAdded:Connect(function(d)
        if not antiOn then return end
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            task.defer(function()
                if antiOn and d.Parent then neutralizeBodyPart(d) end
            end)
        elseif isMover(d) and d ~= moveVel and d ~= faceAlign then
            task.defer(function()
                if antiOn then pcall(function() d:Destroy() end) end
            end)
        end
    end)

    antiConn = RunService.Heartbeat:Connect(heartbeat)
    antiPost = RunService.PostSimulation:Connect(postSim)
    antiJumpConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Space then doJump() end
    end)
end

local function stopAnti()
    if antiAdded then antiAdded:Disconnect() antiAdded = nil end
    if antiConn then antiConn:Disconnect() antiConn = nil end
    if antiPost then antiPost:Disconnect() antiPost = nil end
    if antiJumpConn then antiJumpConn:Disconnect() antiJumpConn = nil end
    if antiStateConn then antiStateConn:Disconnect() antiStateConn = nil end
    killConstraints()

    local c = LP.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        restoreAnti(c)
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
-- UI WIRING
--============================================================--
Window:AddSection({ Name = "Player Visuals", Tab = Visuals })

Window:AddParagraph({
    Title       = "Player ESP",
    Description = "Unified outline, chams and compact nametags.\nClient-side only, restored on disable.",
    Tab         = Visuals,
})

Window:AddToggle({
    Title = "Enable Player ESP",
    Description = "Outline + Chams + Nametag for every player",
    Tab = Visuals, Default = false,
    Callback = function(state)
        if state then
            enableESP(); notify("Hyko • ESP", "Player ESP enabled", 3)
        else
            disableESP(); notify("Hyko • ESP", "Player ESP disabled", 3)
        end
    end,
})

Window:AddSlider({
    Title = "ESP Distance",
    Description = "Max distance for ESP rendering (studs)",
    Tab = Visuals,
    MinValue = 100, MaxValue = 5000, Default = 1200, AllowDecimals = false,
    Callback = function(v)
        ESP_MAX_DISTANCE = v
        for _, e in pairs(espEntries) do
            if e.billboard and e.billboard.Parent then
                pcall(function() e.billboard.MaxDistance = v end)
            end
        end
    end,
})

Window:AddSection({ Name = "Protection", Tab = Utility })

Window:AddParagraph({
    Title       = "Anti-Ragdoll",
    Description = "Hard-lock body: fake humanoid, neutralized parts, upright enforcement.",
    Tab         = Utility,
})

Window:AddToggle({
    Title = "Enable Anti-Ragdoll",
    Description = "Blocks Ragdoll / FallingDown / Physics / PlatformStanding / GettingUp",
    Tab = Utility, Default = false,
    Callback = function(state)
        if state then
            startAnti()
            notify("Hyko • Anti-Ragdoll", "Anti-Ragdoll enabled (speed " .. tostring(antiSpeed) .. ")", 3)
        else
            stopAnti()
            notify("Hyko • Anti-Ragdoll", "Anti-Ragdoll disabled", 3)
        end
    end,
})

Window:AddSlider({
    Title = "Speed",
    Description = "Anti-Ragdoll movement speed (default 60)",
    Tab = Utility,
    MinValue = 20, MaxValue = 800, Default = 60, AllowDecimals = false,
    Callback = function(v) antiSpeed = v end,
})

Window:AddSection({ Name = "Interaction", Tab = Utility })

Window:AddParagraph({
    Title       = "Fast Loot",
    Description = "Turns every ProximityPrompt hold into an instant (0s) interaction.",
    Tab         = Utility,
})

Window:AddToggle({
    Title = "Enable Fast Loot",
    Description = "Instant ProximityPrompt interaction",
    Tab = Utility, Default = false,
    Callback = function(state)
        if state then
            enableLoot(); notify("Hyko • Fast Loot", "Fast Loot enabled", 3)
        else
            disableLoot(); notify("Hyko • Fast Loot", "Fast Loot disabled", 3)
        end
    end,
})

Window:AddParagraph({
    Title       = "Auto Loot",
    Description = "Automatically forces HoldDuration = 0 on the nearest prompt\nin range and fires it.",
    Tab         = Utility,
})

Window:AddToggle({
    Title = "Enable Auto Loot",
    Description = "Auto-collect the nearest ProximityPrompt",
    Tab = Utility, Default = false,
    Callback = function(state)
        if state then
            enableAutoLoot()
            notify("Hyko • Auto Loot", "Auto Loot enabled (radius " .. tostring(autoLootRadius) .. ")", 3)
        else
            disableAutoLoot()
            notify("Hyko • Auto Loot", "Auto Loot disabled", 3)
        end
    end,
})

Window:AddSlider({
    Title = "Auto Loot Radius",
    Description = "Radius in studs to search for prompts (default 32)",
    Tab = Utility,
    MinValue = 5, MaxValue = 150, Default = 32, AllowDecimals = false,
    Callback = function(v) autoLootRadius = v end,
})

--// SETTINGS TAB
Window:AddSection({ Name = "Performance", Tab = Settings })

Window:AddParagraph({
    Title       = "FPS Boost",
    Description = "Aggressive client optimization: quality drop, shadows off,\nFX stripped, Decals/Textures hidden, MeshParts Performance,\nSky children removed, Clouds off, water flattened.",
    Tab         = Settings,
})

Window:AddToggle({
    Title = "Enable FPS Boost",
    Description = "Client-side graphics optimization (stronger)",
    Tab = Settings, Default = false,
    Callback = function(state)
        if state then
            enableBoost(); notify("Hyko • FPS Boost", "FPS Boost enabled (strong)", 3)
        else
            disableBoost(); notify("Hyko • FPS Boost", "FPS Boost disabled — restored", 3)
        end
    end,
})

Window:AddSection({ Name = "Interface", Tab = Settings })

Window:AddKeybind({
    Title = "Minimize Keybind",
    Description = "Set the keybind for minimizing the UI",
    Tab = Settings,
    Callback = function(Key)
        Window:SetSetting("Keybind", Key)
        notify("Hyko • Settings", "Minimize keybind set to " .. tostring(Key), 3)
    end,
})

Window:AddDropdown({
    Title = "Set Theme",
    Description = "Set the theme of the library",
    Tab = Settings,
    Options = {
        ["Light Mode"] = "Light",
        ["Dark Mode"]  = "Dark",
        ["Extra Dark"] = "Void",
    },
    Callback = function(theme)
        Window:SetTheme(Themes[theme])
        notify("Hyko • Theme", "Theme switched to " .. theme, 3)
    end,
})

Window:AddToggle({
    Title = "UI Blur",
    Description = "Requires Roblox graphics quality 8 or higher",
    Default = true, Tab = Settings,
    Callback = function(Boolean)
        Window:SetSetting("Blur", Boolean)
        notify("Hyko • Blur", Boolean and "UI blur enabled" or "UI blur disabled", 3)
    end,
})

Window:AddSlider({
    Title = "UI Transparency",
    Description = "Set the transparency of the UI",
    Tab = Settings, AllowDecimals = true, MaxValue = 1,
    Callback = function(Amount)
        Window:SetSetting("Transparency", Amount)
    end,
})

--============================================================--
-- GLASS "SHOW / HIDE UI" TOGGLE (TOP-RIGHT)
--   Reverted: hides the entire lates-lib ScreenGui (notifications too).
--============================================================--
do
    local pg = LP:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "HykoToggleGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = pg

    local btn = Instance.new("TextButton")
    btn.Name = "HykoShowUI"
    btn.AnchorPoint = Vector2.new(1, 0)
    btn.Position = UDim2.new(1, -18, 0, 18)
    btn.Size = UDim2.fromOffset(120, 40)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.35
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Active = true
    btn.Parent = gui
    makeCorner(btn, 12)

    local stroke = makeStroke(btn, Color3.fromRGB(255, 255, 255), 0.15, 1)

    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 0.55),
    })
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 240, 250)),
    })
    grad.Parent = btn

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.fromOffset(14, 16)
    dot.BackgroundColor3 = Color3.fromRGB(10, 132, 255)
    dot.BorderSizePixel = 0
    dot.Parent = btn
    makeCorner(dot, 4)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(30, 0)
    label.Size = UDim2.new(1, -38, 1, 0)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(17, 19, 24)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = "Hide UI"
    label.Parent = btn

    local uiVisible = true

    local function setVisible(v)
        uiVisible = v
        label.Text = v and "Hide UI" or "Show UI"
        dot.BackgroundColor3 = v and Color3.fromRGB(10, 132, 255)
                                 or Color3.fromRGB(160, 165, 175)
        if libGui and libGui.Parent then
            libGui.Enabled = v
        end
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.18}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.35}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.15}):Play()
    end)

    btn.Activated:Connect(function()
        setVisible(not uiVisible)
    end)

    local dragging, dragStart, startPos
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

notify(
    "Hyko Loaded",
    "ESP • Anti-Ragdoll • Fast Loot • Auto Loot • FPS Boost\nTop-right button toggles the UI",
    8
)