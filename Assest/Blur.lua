-- Azure Blur.lua | shared, tweened Lighting blur
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Blur = {}
Blur.__index = Blur
local Active = {}
local Effect
local Tween
local Generation = 0

local function targetSize()
    local amount = 0
    for object in pairs(Active) do
        if not object._destroyed and object._shown then
            amount = math.max(amount, object._intensity * object._size)
        end
    end
    return math.clamp(amount, 0, 56)
end

local function getEffect()
    if Effect and Effect.Parent then return Effect end
    Effect = Lighting:FindFirstChild("Azure_Blur")
    if not Effect or not Effect:IsA("BlurEffect") then
        Effect = Instance.new("BlurEffect")
        Effect.Name = "Azure_Blur"
        Effect.Parent = Lighting
    end
    Effect.Size = 0
    return Effect
end

local function update(duration)
    Generation += 1
    local id = Generation
    if Tween then Tween:Cancel(); Tween = nil end
    local size = targetSize()
    local fx = getEffect()
    Tween = TweenService:Create(fx, TweenInfo.new(duration or 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = size})
    Tween.Completed:Connect(function()
        if id == Generation and targetSize() <= 0 and fx.Parent then
            fx:Destroy()
            if Effect == fx then Effect = nil end
        end
    end)
    Tween:Play()
end

function Blur.new(target, intensity, options)
    assert(typeof(target) == "Instance" and target:IsA("GuiObject"), "Blur.new expects a GuiObject")
    options = options or {}
    local self = setmetatable({
        target = target,
        _intensity = math.clamp(tonumber(intensity) or 1, 0, 1),
        _size = math.clamp(tonumber(options.Size) or 28, 0, 56),
        _shown = false,
        _destroyed = false,
        _connections = {},
    }, Blur)
    if options.AutoTrackVisibility ~= false then
        table.insert(self._connections, target:GetPropertyChangedSignal("Visible"):Connect(function()
            if target.Visible then self:Show() else self:Hide() end
        end))
    end
    table.insert(self._connections, target.Destroying:Connect(function() self:Destroy() end))
    if options.Visible == true and target.Visible then self:Show(0) end
    return self
end

function Blur:Show(duration)
    if self._destroyed then return end
    self._shown = true
    Active[self] = true
    update(duration)
end
function Blur:Hide(duration)
    if self._destroyed then return end
    self._shown = false
    Active[self] = nil
    update(duration)
end
function Blur:SetIntensity(value)
    self._intensity = math.clamp(tonumber(value) or 0, 0, 1)
    if self._shown then update(0.2) end
end
Blur.setBlurIntensity = Blur.SetIntensity
function Blur:SetSize(value)
    self._size = math.clamp(tonumber(value) or 0, 0, 56)
    if self._shown then update(0.2) end
end
function Blur:IsVisible() return self._shown end
function Blur:Destroy()
    if self._destroyed then return end
    self:Hide(0.18)
    self._destroyed = true
    for _, connection in ipairs(self._connections) do connection:Disconnect() end
    table.clear(self._connections)
end
return Blur
