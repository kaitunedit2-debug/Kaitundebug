--[[
    Azure / Blur.lua
    Lightweight shared Roblox background blur.

    API:
        local Blur = require/loadstring(...)()
        local effect = Blur.new(guiObject, intensity?, options?)
        effect:Show(time?)
        effect:Hide(time?)
        effect:SetIntensity(0..1)
        effect:IsVisible()
        effect:Destroy()

    Options:
        Size    = 22       -- maximum BlurEffect.Size (0..56)
        Visible = true

    A single Lighting.BlurEffect is shared by active windows. The 3D scene is
    blurred smoothly while ScreenGui text and controls stay crisp. Roblox's
    built-in BlurEffect is scene-wide; it cannot blur only the pixels behind
    one individual GuiObject.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Blur = {}
Blur.__index = Blur

local Shared = {
    Effect = nil,
    Instances = {},
    Tween = nil,
    Generation = 0,
}

local function highestSize()
    local Size = 0
    for Object in pairs(Shared.Instances) do
        if not Object._destroyed and Object._visible then
            Size = math.max(Size, Object._intensity * Object._maxSize)
        end
    end
    return math.clamp(Size, 0, 56)
end

local function getEffect()
    if Shared.Effect and Shared.Effect.Parent then
        return Shared.Effect
    end

    local Existing = Lighting:FindFirstChild("AzureBackgroundBlur")
    local Effect = Existing and Existing:IsA("BlurEffect") and Existing or Instance.new("BlurEffect")
    Effect.Name = "AzureBackgroundBlur"
    Effect.Size = 0
    Effect.Parent = Lighting
    Shared.Effect = Effect
    return Effect
end

local function refreshShared(Time)
    local Target = highestSize()
    local Effect = Shared.Effect

    if Target <= 0 then
        if not Effect or not Effect.Parent then
            Shared.Effect = nil
            return
        end
        if Shared.Tween then
            Shared.Tween:Cancel()
            Shared.Tween = nil
        end

        Shared.Generation += 1
        local Generation = Shared.Generation
        local Fade = TweenService:Create(
            Effect,
            TweenInfo.new(Time or 0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { Size = 0 }
        )
        Shared.Tween = Fade
        Fade.Completed:Connect(function()
            if Shared.Generation == Generation and highestSize() <= 0 and Shared.Effect == Effect then
                Shared.Effect = nil
                if Effect.Parent then Effect:Destroy() end
            end
        end)
        Fade:Play()
        return
    end

    Effect = getEffect()
    if Shared.Tween then
        Shared.Tween:Cancel()
        Shared.Tween = nil
    end

    Shared.Generation += 1
    local Fade = TweenService:Create(
        Effect,
        TweenInfo.new(Time or 0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Size = Target }
    )
    Shared.Tween = Fade
    Fade:Play()
end

function Blur.new(Target: GuiObject, Intensity: number?, Options: { [string]: any }?)
    assert(typeof(Target) == "Instance" and Target:IsA("GuiObject"), "[Blur] target must be a GuiObject")
    Options = Options or {}

    local Self = setmetatable({
        target = Target,
        _intensity = math.clamp(tonumber(Intensity) or 1, 0, 1),
        _maxSize = math.clamp(tonumber(Options.Size) or 22, 0, 56),
        _visible = false,
        _destroyed = false,
        _conns = {},
        root = nil, -- retained as an API field for compatibility with older callers
    }, Blur)

    table.insert(Self._conns, Target:GetPropertyChangedSignal("Visible"):Connect(function()
        if Target.Visible then
            if Options.AutoTrackVisibility ~= false and not Self._visible then
                Self:Show(0.2)
            end
        elseif Options.AutoTrackVisibility ~= false and Self._visible then
            Self:Hide(0.2)
        end
    end))

    table.insert(Self._conns, Target.Destroying:Connect(function()
        Self:Destroy()
    end))

    if Options.Visible ~= false and Target.Visible then
        Self:Show(0)
    end

    return Self
end

function Blur:Show(Time: number?)
    if self._destroyed or self._visible then return end
    self._visible = true
    Shared.Instances[self] = true
    refreshShared(Time)
end

function Blur:Hide(Time: number?)
    if self._destroyed or not self._visible then return end
    self._visible = false
    Shared.Instances[self] = nil
    refreshShared(Time)
end

function Blur:IsVisible()
    return self._visible
end

function Blur:SetIntensity(Value: number)
    self._intensity = math.clamp(tonumber(Value) or 0, 0, 1)
    if self._visible then
        refreshShared(0.2)
    end
end

Blur.setBlurIntensity = Blur.SetIntensity

function Blur:SetSize(Value: number)
    self._maxSize = math.clamp(tonumber(Value) or 0, 0, 56)
    if self._visible then
        refreshShared(0.2)
    end
end

function Blur:Destroy()
    if self._destroyed then return end
    self:Hide(0.2)
    self._destroyed = true

    for _, Connection in ipairs(self._conns) do
        Connection:Disconnect()
    end
    table.clear(self._conns)
end

return Blur
