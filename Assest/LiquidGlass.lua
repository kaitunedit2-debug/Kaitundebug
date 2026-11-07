--[[
    Azure / LiquidGlass.lua
    Refined layered glass for GuiObjects: cool tint, depth, soft reflections,
    animated sheen and a subtle directional rim. This is a visual simulation;
    Roblox GUI does not expose true per-pixel refraction of the 3D scene.

    API:
        local Glass = LiquidGlass.new(guiObject, config?)
        Glass:Start()
        Glass:Stop()
        Glass:SetIntensity(0..1.5)
        Glass:SetTint(Color3)
        Glass:SetVisible(boolean)
        Glass:Destroy()

    Config:
        Corner        = UDim
        Tint          = Color3
        Intensity     = number (default 1)
        RimThickness  = number (default 1.25)
        Animate       = boolean (default true)
        FollowPointer = boolean (default true)
        ZIndex        = number (auto: target.ZIndex + 1)
        Visible       = boolean (default true)
        Frames        = { {GuiObject, BackgroundTransparency}, ... }
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

local function make(ClassName: string, Properties: { [string]: any }, Parent: Instance?)
    local Object = Instance.new(ClassName)
    for Property, Value in pairs(Properties) do
        Object[Property] = Value
    end
    Object.Parent = Parent
    return Object
end

local function makeLayer(Name: string, Parent: Instance, Corner: UDim, ZIndex: number, Properties: { [string]: any }?)
    local Frame = make("Frame", {
        Name = Name,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Active = false,
        Interactable = false,
        ZIndex = ZIndex,
    }, Parent)

    if Properties then
        for Property, Value in pairs(Properties) do
            Frame[Property] = Value
        end
    end

    make("UICorner", { CornerRadius = Corner }, Frame)
    return Frame
end

local Curves = {
    Tint = { { 0, 0.915 }, { 0.48, 0.95 }, { 1, 0.975 } },
    Depth = { { 0, 1 }, { 0.48, 1 }, { 1, 0.88 } },
    Specular = { { 0, 0.79 }, { 0.48, 0.94 }, { 1, 1 } },
    Blob = { { 0, 0.84 }, { 0.52, 0.96 }, { 1, 1 } },
    Sheen = { { 0, 1 }, { 0.37, 1 }, { 0.5, 0.82 }, { 0.63, 1 }, { 1, 1 } },
    Rim = { { 0, 0.1 }, { 0.28, 0.86 }, { 0.72, 0.86 }, { 1, 0.1 } },
    Glow = { { 0, 0.82 }, { 0.34, 1 }, { 0.66, 1 }, { 1, 0.82 } },
}

local function buildSequence(Intensity: number, Points: { { number } })
    local Keys = table.create(#Points)
    for Index, Point in ipairs(Points) do
        Keys[Index] = NumberSequenceKeypoint.new(
            Point[1],
            math.clamp(1 - (1 - Point[2]) * Intensity, 0, 1)
        )
    end
    return NumberSequence.new(Keys)
end

local function tintSequence(StartColor: Color3, EndColor: Color3)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, StartColor),
        ColorSequenceKeypoint.new(1, EndColor),
    })
end

local function addZIndexOffset(Target: GuiObject, Offset: number, Container: Instance, Saved: { any })
    local function adjust(Object)
        if not Object:IsA("GuiObject") then return end
        if Object == Container or Object:IsDescendantOf(Container) then return end

        local IsForeground = Object:IsA("TextLabel")
            or Object:IsA("TextButton")
            or Object:IsA("TextBox")
            or Object:IsA("ImageLabel")
            or Object:IsA("ImageButton")
            or (Object.Name == "Accent" and Object.Parent == Target)
        if not IsForeground or Object:GetAttribute("AzureGlassZAdjusted") then return end

        table.insert(Saved, { Object, Object.ZIndex, Object:GetAttribute("AzureGlassZAdjusted") })
        Object:SetAttribute("AzureGlassZAdjusted", true)
        Object.ZIndex = math.clamp(Object.ZIndex + Offset, 1, 10_000)
    end

    for _, Descendant in ipairs(Target:GetDescendants()) do
        adjust(Descendant)
    end

    return Target.DescendantAdded:Connect(function(Descendant)
        -- DescendantAdded can fire before the new instance is parented under the glass container.
        task.defer(function()
            if Descendant.Parent and not Descendant:IsDescendantOf(Container) then
                adjust(Descendant)
            end
        end)
    end)
end

function LiquidGlass.new(Target: GuiObject, Config: { [string]: any }?)
    assert(typeof(Target) == "Instance" and Target:IsA("GuiObject"), "[LiquidGlass] target must be a GuiObject")
    Config = Config or {}

    local Existing = Target:FindFirstChild("LiquidGlass")
    if Existing then Existing:Destroy() end

    local TargetCorner = Target:FindFirstChildOfClass("UICorner")
    local Corner = Config.Corner or (TargetCorner and TargetCorner.CornerRadius) or UDim.new(0, 14)
    local RimThickness = math.clamp(tonumber(Config.RimThickness) or 1.25, 0.5, 4)
    local InitialVisible = Config.Visible ~= false
    local BaseZ = tonumber(Config.ZIndex) or (Target.ZIndex + 1)
    local ZBump = math.clamp(tonumber(Config.ContentZIndexOffset) or 8, 2, 32)

    local Self = setmetatable({
        target = Target,
        _intensity = math.clamp(tonumber(Config.Intensity) or 1, 0, 1.5),
        _animate = Config.Animate ~= false,
        _follow = Config.FollowPointer ~= false,
        _corner = Corner,
        _rimThickness = RimThickness,
        _angle = 38,
        _pointer = nil,
        _running = false,
        _visible = InitialVisible,
        _destroyed = false,
        _conns = {},
        _restore = {},
        _zRestore = {},
        _layers = {},
    }, LiquidGlass)

    local Container = make("Frame", {
        Name = "LiquidGlass",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Active = false,
        Interactable = false,
        ClipsDescendants = true,
        ZIndex = BaseZ,
        Visible = InitialVisible,
    }, Target)
    Self.container = Container

    -- Keep text, controls and future-added UI above the glass layers.
    table.insert(Self._conns, addZIndexOffset(Target, ZBump, Container, Self._zRestore))

    local Layers = Self._layers
    local Intensity = Self._intensity
    local CoolWhite = Color3.fromRGB(233, 243, 255)
    local IceBlue = Color3.fromRGB(186, 216, 255)
    local DeepBlue = Color3.fromRGB(13, 28, 50)

    -- 1. Main cool tint.
    Layers.Tint = makeLayer("Tint", Container, Corner, BaseZ, {
        BackgroundColor3 = Config.Tint or Color3.fromRGB(226, 238, 255),
    })
    Layers.TintGradient = make("UIGradient", {
        Rotation = 92,
        Color = tintSequence(CoolWhite, IceBlue),
        Transparency = buildSequence(Intensity, Curves.Tint),
    }, Layers.Tint)

    -- 2. Gentle lower depth to give the panel a little thickness.
    Layers.Depth = makeLayer("Depth", Container, Corner, BaseZ, {
        BackgroundColor3 = DeepBlue,
    })
    Layers.DepthGradient = make("UIGradient", {
        Rotation = 90,
        Color = tintSequence(DeepBlue, Color3.fromRGB(4, 11, 23)),
        Transparency = buildSequence(Intensity, Curves.Depth),
    }, Layers.Depth)

    -- 3. A broad upper reflection.
    Layers.Specular = makeLayer("Specular", Container, Corner, BaseZ, {
        Size = UDim2.fromScale(1, 0.58),
        BackgroundColor3 = CoolWhite,
    })
    Layers.SpecularGradient = make("UIGradient", {
        Rotation = 90,
        Color = tintSequence(Color3.new(1, 1, 1), IceBlue),
        Transparency = buildSequence(Intensity, Curves.Specular),
    }, Layers.Specular)

    -- 4. Soft diffuse highlight near the upper-left edge.
    Layers.Blob = makeLayer("Blob", Container, UDim.new(1, 0), BaseZ, {
        Position = UDim2.fromScale(-0.17, -0.42),
        Size = UDim2.fromScale(0.76, 0.76),
        Rotation = -17,
        BackgroundColor3 = IceBlue,
    })
    Layers.BlobGradient = make("UIGradient", {
        Rotation = 58,
        Color = tintSequence(CoolWhite, IceBlue),
        Transparency = buildSequence(Intensity, Curves.Blob),
    }, Layers.Blob)

    -- 5. A restrained diagonal sheen that sweeps occasionally.
    Layers.Sheen = makeLayer("Sheen", Container, Corner, BaseZ, {
        BackgroundColor3 = Color3.new(1, 1, 1),
    })
    Layers.SheenGradient = make("UIGradient", {
        Rotation = 24,
        Offset = Vector2.new(-1, 0),
        Color = tintSequence(Color3.new(1, 1, 1), CoolWhite),
        Transparency = buildSequence(Intensity, Curves.Sheen),
    }, Layers.Sheen)

    -- 6. Soft glow and a crisp reflective rim.
    local function strokeLayer(Name: string, Thickness: number, Curve, ZOffset: number)
        local Inset = Thickness
        local Frame = make("Frame", {
            Name = Name,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -Inset * 2, 1, -Inset * 2),
            Active = false,
            Interactable = false,
            ZIndex = BaseZ,
        }, Container)
        make("UICorner", {
            CornerRadius = UDim.new(Corner.Scale, math.max(Corner.Offset - Inset, 0)),
        }, Frame)

        local Stroke = make("UIStroke", {
            Color = CoolWhite,
            Thickness = Thickness,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            LineJoinMode = Enum.LineJoinMode.Round,
        }, Frame)
        local Gradient = make("UIGradient", {
            Rotation = Self._angle + ZOffset,
            Color = tintSequence(Color3.new(1, 1, 1), IceBlue),
            Transparency = buildSequence(Intensity, Curve),
        }, Stroke)
        return Frame, Gradient
    end

    Layers.Glow, Layers.GlowGradient = strokeLayer("Glow", RimThickness * 3.2, Curves.Glow, 0)
    Layers.Rim, Layers.RimGradient = strokeLayer("Rim", RimThickness, Curves.Rim, 8)

    -- Optional frame transparency changes are reversible on Destroy.
    if Config.Frames then
        for _, Entry in ipairs(Config.Frames) do
            local Frame, Transparency = Entry[1], Entry[2]
            if typeof(Frame) == "Instance" and Frame:IsA("GuiObject") then
                table.insert(Self._restore, { Frame, Frame.BackgroundTransparency })
                Frame.BackgroundTransparency = math.clamp(tonumber(Transparency) or Frame.BackgroundTransparency, 0, 1)
            end
        end
    end

    if Self._follow then
        table.insert(Self._conns, UserInputService.InputChanged:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
                Self._pointer = Vector2.new(Input.Position.X, Input.Position.Y)
            end
        end))
        table.insert(Self._conns, UserInputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.Touch then
                Self._pointer = Vector2.new(Input.Position.X, Input.Position.Y)
            end
        end))
    end

    table.insert(Self._conns, Target:GetPropertyChangedSignal("Visible"):Connect(function()
        if Target.Visible and Self._visible then
            Self:Start()
        else
            Self:Stop()
        end
    end))
    table.insert(Self._conns, Target.Destroying:Connect(function()
        Self:Destroy()
    end))

    if Target.Visible and InitialVisible then
        Self:Start()
    end

    return Self
end

function LiquidGlass:_setAngle(Angle: number)
    self._angle = Angle
    self._layers.RimGradient.Rotation = Angle
    self._layers.GlowGradient.Rotation = Angle
end

function LiquidGlass:Start()
    if self._running or self._destroyed or not self._visible then return end
    if not self.target.Visible then return end

    self._running = true
    self._beat = RunService.Heartbeat:Connect(function(DeltaTime)
        if self._destroyed or not self._visible or not self.target.Visible then return end
        if self.target.AbsoluteSize.X < 2 or self.target.AbsoluteSize.Y < 2 then return end

        local Goal
        if self._follow and self._pointer then
            local Center = self.target.AbsolutePosition + self.target.AbsoluteSize / 2
            Goal = math.deg(math.atan2(self._pointer.Y - Center.Y, self._pointer.X - Center.X))
        else
            Goal = self._angle + 10 * DeltaTime
        end

        local Delta = (Goal - self._angle + 180) % 360 - 180
        self:_setAngle(self._angle + Delta * math.min(DeltaTime * 7, 1))
    end)

    if self._animate then
        local Token = {}
        self._sheenToken = Token
        task.spawn(function()
            local Gradient = self._layers.SheenGradient
            local Randomizer = Random.new()
            while self._sheenToken == Token and Gradient.Parent and self._visible and self.target.Visible do
                Gradient.Offset = Vector2.new(-1, 0)
                local Sweep = TweenService:Create(
                    Gradient,
                    TweenInfo.new(1.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { Offset = Vector2.new(1, 0) }
                )
                Sweep:Play()
                Sweep.Completed:Wait()

                local Pause = 3.8 + Randomizer:NextNumber() * 2.8
                local Elapsed = 0
                while Elapsed < Pause and self._sheenToken == Token do
                    Elapsed += task.wait(0.2)
                end
            end
        end)
    end
end

function LiquidGlass:Stop()
    if not self._running then
        self._sheenToken = nil
        return
    end

    self._running = false
    self._sheenToken = nil
    if self._beat then
        self._beat:Disconnect()
        self._beat = nil
    end
end

function LiquidGlass:SetIntensity(Value: number)
    self._intensity = math.clamp(tonumber(Value) or 0, 0, 1.5)
    local Layers = self._layers
    for Name, Curve in pairs(Curves) do
        local Gradient = Layers[Name .. "Gradient"]
        if Gradient then
            Gradient.Transparency = buildSequence(self._intensity, Curve)
        end
    end
end

function LiquidGlass:SetTint(Color: Color3)
    if typeof(Color) == "Color3" then
        self._layers.Tint.BackgroundColor3 = Color
    end
end

function LiquidGlass:SetVisible(Value: boolean)
    if self._destroyed then return end
    self._visible = Value == true
    self.container.Visible = self._visible
    if self._visible and self.target.Visible then
        self:Start()
    else
        self:Stop()
    end
end

function LiquidGlass:Destroy()
    if self._destroyed then return end
    self:Stop()
    self._destroyed = true

    for _, Connection in ipairs(self._conns) do
        Connection:Disconnect()
    end
    table.clear(self._conns)

    for _, Entry in ipairs(self._restore) do
        if Entry[1] and Entry[1].Parent then
            Entry[1].BackgroundTransparency = Entry[2]
        end
    end
    table.clear(self._restore)

    for _, Entry in ipairs(self._zRestore) do
        local Object, OriginalZIndex, OriginalAttribute = Entry[1], Entry[2], Entry[3]
        if Object and Object.Parent then
            Object.ZIndex = OriginalZIndex
            Object:SetAttribute("AzureGlassZAdjusted", OriginalAttribute)
        end
    end
    table.clear(self._zRestore)

    if self.container then
        self.container:Destroy()
    end
end

return LiquidGlass
