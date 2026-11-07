-- Azure LiquidGlass.lua | visible layered glass simulation for Roblox GUI
-- This is a GUI material simulation, not true refraction of the 3D scene.
local TweenService = game:GetService("TweenService")
local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

local function create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    create("UICorner", {CornerRadius = radius}, parent)
end

function LiquidGlass.new(target, config)
    assert(typeof(target) == "Instance" and target:IsA("GuiObject"), "LiquidGlass.new expects a GuiObject")
    config = config or {}
    local previous = target:FindFirstChild("LiquidGlass")
    if previous then previous:Destroy() end

    local radius = config.Corner or (target:FindFirstChildOfClass("UICorner") and target:FindFirstChildOfClass("UICorner").CornerRadius) or UDim.new(0, 12)
    local baseZ = tonumber(config.ZIndex) or (target.ZIndex + 1)
    local intensity = math.clamp(tonumber(config.Intensity) or 1, 0, 1.5)
    local tint = typeof(config.Tint) == "Color3" and config.Tint or Color3.fromRGB(205, 225, 255)
    local self = setmetatable({target = target, intensity = intensity, visible = config.Visible ~= false, destroyed = false, connections = {}, tweens = {}}, LiquidGlass)

    -- Keep all existing content above the glass while preserving relative Z order.
    local savedZ = {}
    for _, item in ipairs(target:GetDescendants()) do
        if item:IsA("GuiObject") then
            savedZ[item] = item.ZIndex
            item.ZIndex = math.clamp(item.ZIndex + 12, 1, 10000)
        end
    end
    self.savedZ = savedZ

    local container = create("Frame", {
        Name = "LiquidGlass", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
        ZIndex = baseZ, Visible = self.visible, Active = false,
    }, target)
    self.container = container
    corner(container, radius)

    local tintLayer = create("Frame", {
        Name = "GlassTint", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        BackgroundColor3 = tint, BackgroundTransparency = 0.68,
        ZIndex = baseZ, Active = false,
    }, container)
    corner(tintLayer, radius)
    create("UIGradient", {
        Rotation = 105,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(0.48, tint),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(125,165,220)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.28),
            NumberSequenceKeypoint.new(0.52, 0.62),
            NumberSequenceKeypoint.new(1, 0.78),
        }),
    }, tintLayer)

    local reflection = create("Frame", {
        Name = "GlassReflection", Size = UDim2.new(1, 0, 0.42, 0),
        BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.78,
        BorderSizePixel = 0, ZIndex = baseZ + 1, Active = false,
    }, container)
    corner(reflection, radius)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.22),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, reflection)

    local rim = create("UIStroke", {
        Color = Color3.fromRGB(238, 247, 255), Thickness = 1.15,
        Transparency = 0.28, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, container)
    self.rim = rim
    self.tintLayer = tintLayer
    self.reflection = reflection

    table.insert(self.connections, target:GetPropertyChangedSignal("Visible"):Connect(function()
        if not self.destroyed then self.container.Visible = self.visible and target.Visible end
    end))
    if config.Animate ~= false then
        local sweep = create("Frame", {
            Name = "GlassSheen", BackgroundColor3 = Color3.new(1,1,1),
            BackgroundTransparency = 0.88, BorderSizePixel = 0,
            Size = UDim2.new(0.24, 0, 1.5, 0), Position = UDim2.new(-0.35, 0, -0.25, 0),
            Rotation = 18, ZIndex = baseZ + 2, Active = false,
        }, container)
        corner(sweep, radius)
        self.sweep = sweep
        task.spawn(function()
            while not self.destroyed do
                if self.visible and target.Visible then
                    sweep.Position = UDim2.new(-0.35, 0, -0.25, 0)
                    local tween = TweenService:Create(sweep, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = UDim2.new(1.1, 0, -0.25, 0)})
                    tween:Play(); tween.Completed:Wait()
                    task.wait(2.2)
                else task.wait(0.25) end
            end
        end)
    end
    self:SetIntensity(intensity)
    return self
end

function LiquidGlass:SetIntensity(value)
    self.intensity = math.clamp(tonumber(value) or 0, 0, 1.5)
    if self.tintLayer then
        self.tintLayer.BackgroundTransparency = 1 - (0.24 * self.intensity)
        self.rim.Transparency = math.clamp(0.62 - 0.28 * self.intensity, 0.08, 0.9)
        self.reflection.BackgroundTransparency = math.clamp(0.9 - 0.18 * self.intensity, 0.55, 0.98)
    end
end
function LiquidGlass:SetTint(color)
    if typeof(color) == "Color3" and self.tintLayer then self.tintLayer.BackgroundColor3 = color end
end
function LiquidGlass:SetVisible(value)
    if self.destroyed then return end
    self.visible = value == true
    self.container.Visible = self.visible and self.target.Visible
end
function LiquidGlass:Start() self:SetVisible(true) end
function LiquidGlass:Stop() self:SetVisible(false) end
function LiquidGlass:Destroy()
    if self.destroyed then return end
    self.destroyed = true
    for _, connection in ipairs(self.connections) do connection:Disconnect() end
    for object, z in pairs(self.savedZ or {}) do
        if object and object.Parent then object.ZIndex = z end
    end
    if self.container then self.container:Destroy() end
end
return LiquidGlass
