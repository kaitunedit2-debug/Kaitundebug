--[[
	UI Library
	Rebuilt edition: Blur and Liquid Glass are built in (no extra asset files),
	mobile "Show UI" button, smooth minimize / restore animation.
	Based on the original library by Late.
]]

--// Connections
local GetService = game.GetService
local Connect = game.Loaded.Connect
local Clone = game.Clone
local Destroy = game.Destroy

if (not game:IsLoaded()) then
	local Loaded = game.Loaded
	Loaded.Wait(Loaded);
end

--// Important
local Setup = {
	Keybind = Enum.KeyCode.LeftControl,
	Transparency = 0.2,
	ThemeMode = "Dark",
	Size = nil,
}

local Theme = { --// (Dark Theme)
	--// Frames:
	Primary = Color3.fromRGB(30, 30, 30),
	Secondary = Color3.fromRGB(35, 35, 35),
	Component = Color3.fromRGB(40, 40, 40),
	Interactables = Color3.fromRGB(45, 45, 45),

	--// Text:
	Tab = Color3.fromRGB(200, 200, 200),
	Title = Color3.fromRGB(240,240,240),
	Description = Color3.fromRGB(200,200,200),

	--// Outlines:
	Shadow = Color3.fromRGB(0, 0, 0),
	Outline = Color3.fromRGB(40, 40, 40),

	--// Image:
	Icon = Color3.fromRGB(220, 220, 220),
}

--// Services & Functions
local LocalPlayer = GetService(game, "Players").LocalPlayer;
local Services = {
	Insert = GetService(game, "InsertService");
	Tween = GetService(game, "TweenService");
	Run = GetService(game, "RunService");
	Input = GetService(game, "UserInputService");
	Light = GetService(game, "Lighting");
}

local Player = {
	Mouse = LocalPlayer:GetMouse();
	GUI = LocalPlayer.PlayerGui;
}

local Ease = {
	Out = { EasingStyle = Enum.EasingStyle.Quint, EasingDirection = Enum.EasingDirection.Out },
	In = { EasingStyle = Enum.EasingStyle.Quint, EasingDirection = Enum.EasingDirection.In },
	InOut = { EasingStyle = Enum.EasingStyle.Quint, EasingDirection = Enum.EasingDirection.InOut },
	SineOut = { EasingStyle = Enum.EasingStyle.Sine, EasingDirection = Enum.EasingDirection.Out },
	SineIn = { EasingStyle = Enum.EasingStyle.Sine, EasingDirection = Enum.EasingDirection.In },
}

local Tween = function(Object : Instance, Speed : number, Properties : {},  Info : { EasingStyle: Enum?, EasingDirection: Enum? })
	local Style, Direction

	if Info then
		Style, Direction = Info["EasingStyle"], Info["EasingDirection"]
	else
		Style, Direction = Enum.EasingStyle.Sine, Enum.EasingDirection.Out
	end

	local Created = Services.Tween:Create(Object, TweenInfo.new(Speed, Style, Direction), Properties)
	Created:Play()

	return Created
end

local SetProperty = function(Object: Instance, Properties: {})
	for Index, Property in next, Properties do
		Object[Index] = (Property);
	end

	return Object
end

local Multiply = function(Value, Amount)
	local New = {
		Value.X.Scale * Amount;
		Value.X.Offset * Amount;
		Value.Y.Scale * Amount;
		Value.Y.Offset * Amount;
	}

	return UDim2.new(unpack(New))
end

local Color = function(Color, Factor, Mode)
	Mode = Mode or Setup.ThemeMode

	if Mode == "Light" then
		return Color3.fromRGB((Color.R * 255) - Factor, (Color.G * 255) - Factor, (Color.B * 255) - Factor)
	else
		return Color3.fromRGB((Color.R * 255) + Factor, (Color.G * 255) + Factor, (Color.B * 255) + Factor)
	end
end

--// Pointer (works for mouse and touch)
local TouchPointer = nil
local TouchDown = false

Connect(Services.Input.InputBegan, function(Input)
	if Input.UserInputType == Enum.UserInputType.Touch then
		TouchPointer = Vector2.new(Input.Position.X, Input.Position.Y)
		TouchDown = true
	end
end)

Connect(Services.Input.InputEnded, function(Input)
	if Input.UserInputType == Enum.UserInputType.Touch then
		TouchDown = false
	end
end)

Connect(Services.Input.InputChanged, function(Input)
	if Input.UserInputType == Enum.UserInputType.Touch then
		TouchPointer = Vector2.new(Input.Position.X, Input.Position.Y)
	end
end)

--// Last known pointer position (never nil)
local GetPointer = function()
	if Services.Input.MouseEnabled or not TouchPointer then
		return Services.Input:GetMouseLocation()
	end

	return TouchPointer
end

--// Pointer used for glow effects: mouse hover on desktop, finger only while it is touching on mobile
local GetHoverPointer = function()
	if Services.Input.MouseEnabled then
		return Services.Input:GetMouseLocation()
	end

	if TouchDown and TouchPointer then
		return TouchPointer
	end

	return nil
end

--// Drag & Resize
local ResizeHandle = nil --// Handle that is currently being used to resize

local Drag = function(Canvas, Content)
	if Canvas then
		local Dragging;
		local DragInput;
		local Start;
		local StartPosition;
		local Blocked;

		local function Update(input)
			local delta = input.Position - Start
			Canvas.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + delta.Y)
		end

		local function Begin(Input)
			Dragging = true
			Start = Input.Position
			StartPosition = Canvas.Position

			Connect(Input.Changed, function()
				if Input.UserInputState == Enum.UserInputState.End then
					Dragging = false
				end
			end)
		end

		--// On touch devices the content area scrolls, so it must not move the window
		if Content then
			Connect(Content.InputBegan, function(Input)
				Blocked = Input
			end)
		end

		Connect(Canvas.InputBegan, function(Input)
			local IsTouch = Input.UserInputType == Enum.UserInputType.Touch

			if Input.UserInputType == Enum.UserInputType.MouseButton1 or IsTouch then
				task.defer(function()
					if ResizeHandle then return end
					if IsTouch and Blocked == Input then return end

					Begin(Input)
				end)
			end
		end)

		Connect(Canvas.InputChanged, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				DragInput = Input
			end
		end)

		Connect(Services.Input.InputChanged, function(Input)
			if Input == DragInput and Dragging and not ResizeHandle then
				Update(Input)
			end
		end)
	end
end

local Resizing = {
	TopLeft = { X = Vector2.new(-1, 0),   Y = Vector2.new(0, -1)};
	TopRight = { X = Vector2.new(1, 0),    Y = Vector2.new(0, -1)};
	BottomLeft = { X = Vector2.new(-1, 0),   Y = Vector2.new(0, 1)};
	BottomRight = { X = Vector2.new(1, 0),    Y = Vector2.new(0, 1)};
}

local Resizeable = function(Tab, Minimum, Maximum)
	local Handles = Tab and Tab:FindFirstChild("Resize")
	if not Handles then return end

	local Origin, Size, UIPos = nil, nil, nil

	for Index, Handle in next, Handles:GetChildren() do
		if Resizing[Handle.Name] then
			Connect(Handle.InputBegan, function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					ResizeHandle = Handle
					Origin = Vector2.new(Input.Position.X, Input.Position.Y)
					Size = Tab.AbsoluteSize
					UIPos = Tab.Position
				end
			end)
		end
	end

	Connect(Services.Input.InputEnded, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			ResizeHandle = nil
		end
	end)

	Connect(Services.Input.InputChanged, function(Input)
		if not (ResizeHandle and Origin and Size and UIPos) then return end
		if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then return end

		local Delta = Vector2.new(Input.Position.X, Input.Position.Y) - Origin
		local Mode = Resizing[ResizeHandle.Name]
		local NewSize = Vector2.new(Size.X + Delta.X * Mode.X.X, Size.Y + Delta.Y * Mode.Y.Y)
		NewSize = Vector2.new(math.clamp(NewSize.X, Minimum.X, Maximum.X), math.clamp(NewSize.Y, Minimum.Y, Maximum.Y))

		local AnchorOffset = Vector2.new(Tab.AnchorPoint.X * Size.X, Tab.AnchorPoint.Y * Size.Y)
		local NewAnchorOffset = Vector2.new(Tab.AnchorPoint.X * NewSize.X, Tab.AnchorPoint.Y * NewSize.Y)
		local DeltaAnchorOffset = NewAnchorOffset - AnchorOffset

		Tab.Size = UDim2.new(0, NewSize.X, 0, NewSize.Y)
		Tab.Position = UDim2.new(
			UIPos.X.Scale,
			UIPos.X.Offset + DeltaAnchorOffset.X * Mode.X.X,
			UIPos.Y.Scale,
			UIPos.Y.Offset + DeltaAnchorOffset.Y * Mode.Y.Y
		)
	end)
end

--// Setup [UI]
local Screen

if (identifyexecutor) then
	Screen = Services.Insert:LoadLocalAsset("rbxassetid://18490507748");
else
	Screen = (script.Parent);
end

Screen.Main.Visible = false

pcall(function()
	Screen.IgnoreGuiInset = true --// Keeps GUI space identical to screen space (needed for blur + glass)
	Screen.ResetOnSpawn = false
end)

xpcall(function()
	Screen.Parent = game.CoreGui
end, function() 
	Screen.Parent = Player.GUI
end)

local GetViewport = function()
	if Screen.AbsoluteSize.X > 0 and Screen.AbsoluteSize.Y > 0 then
		return Screen.AbsoluteSize
	end

	local Camera = workspace.CurrentCamera
	return (Camera and Camera.ViewportSize) or Vector2.new(1280, 720)
end

local ResolveSize = function(Size)
	local View = GetViewport()
	return Vector2.new(Size.X.Scale * View.X + Size.X.Offset, Size.Y.Scale * View.Y + Size.Y.Offset)
end

local FitSize = function(Size)
	if typeof(Size) ~= "UDim2" then
		return UDim2.fromOffset(570, 370)
	end

	local View = GetViewport()
	local X, Y = Size.X.Offset, Size.Y.Offset

	if Size.X.Scale == 0 then X = math.min(X, math.floor(View.X * 0.94)) end
	if Size.Y.Scale == 0 then Y = math.min(Y, math.floor(View.Y * 0.88)) end

	return UDim2.new(Size.X.Scale, X, Size.Y.Scale, Y)
end

--// ============================================================
--// Blur (built in)
--// Real backdrop blur: DepthOfField + near-camera glass quad that follows a GUI region
--// ============================================================
local Blur = {}
Blur.__index = Blur

local BlurCounter = 0
local BlurDepth = 0.95

local MakeBlurPart = function()
	local Part = Instance.new("Part")
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = false
	Part.CanTouch = false
	Part.CastShadow = false
	Part.Massless = true
	Part.Material = Enum.Material.Glass
	Part.BrickColor = BrickColor.new("Institutional white")
	Part.Transparency = 0.98
	Part.TopSurface = Enum.SurfaceType.Smooth
	Part.BottomSurface = Enum.SurfaceType.Smooth
	Part.Size = Vector3.new(0.2, 0.2, 0.2)

	local Mesh = Instance.new("SpecialMesh")
	Mesh.Name = "WedgeMesh"
	Mesh.MeshType = Enum.MeshType.Wedge
	Mesh.Parent = Part

	return Part, Mesh
end

--// Draws one triangle out of two wedge parts
local DrawTriangle = function(V1, V2, V3, Slot0, Slot1)
	local S1 = (V1 - V2).Magnitude
	local S2 = (V2 - V3).Magnitude
	local S3 = (V3 - V1).Magnitude
	local SMax = math.max(S1, S2, S3)

	if SMax < 1e-5 then return end

	local A, B, C
	if S1 == SMax then
		A, B, C = V1, V2, V3
	elseif S2 == SMax then
		A, B, C = V2, V3, V1
	else
		A, B, C = V3, V1, V2
	end

	local AB = (A - B).Magnitude
	local Para = (B - A):Dot(C - A) / AB
	local Perp = math.sqrt(math.max((C - A).Magnitude ^ 2 - Para * Para, 0))
	local DifPara = AB - Para

	if Perp < 1e-5 then return end

	local St = CFrame.new(B, A)
	local Za = CFrame.Angles(math.pi / 2, 0, 0)

	local Cf0 = St
	local TopLook = (Cf0 * Za).LookVector
	local MidPoint = A + CFrame.new(A, B).LookVector * Para
	local NeededLook = CFrame.new(MidPoint, C).LookVector
	local Angle = math.acos(math.clamp(TopLook:Dot(NeededLook), -1, 1))
	local Ac = CFrame.Angles(0, 0, Angle)

	Cf0 = Cf0 * Ac
	if ((Cf0 * Za).LookVector - NeededLook).Magnitude > 0.01 then
		Cf0 = Cf0 * CFrame.Angles(0, 0, -2 * Angle)
	end
	Cf0 = Cf0 * CFrame.new(0, Perp / 2, -(DifPara + Para / 2))

	local Cf1 = St * Ac * CFrame.Angles(0, math.pi, 0)
	if ((Cf1 * Za).LookVector - NeededLook).Magnitude > 0.01 then
		Cf1 = Cf1 * CFrame.Angles(0, 0, 2 * Angle)
	end
	Cf1 = Cf1 * CFrame.new(0, Perp / 2, DifPara / 2)

	if Cf0.X ~= Cf0.X or Cf1.X ~= Cf1.X then return end

	Slot0.Mesh.Scale = Vector3.new(0, Perp / 0.2, Para / 0.2)
	Slot0.Part.CFrame = Cf0
	Slot1.Mesh.Scale = Vector3.new(0, Perp / 0.2, DifPara / 0.2)
	Slot1.Part.CFrame = Cf1
end

function Blur.new(Owner, Intensity, Inset)
	BlurCounter += 1

	local self = setmetatable({
		Owner = Owner,
		Intensity = math.clamp(Intensity or 1, 0, 1),
		BindId = "UILib_Blur_" .. BlurCounter,
		Camera = workspace.CurrentCamera,
		Slots = {},
		Visible = false,
		Destroyed = false,
		Bound = false,
		Version = 0,
		Tween = nil,
	}, Blur)

	self.Effect = Instance.new("DepthOfFieldEffect")
	self.Effect.Name = "UILibBlur"
	self.Effect.FarIntensity = 0
	self.Effect.FocusDistance = 51.6
	self.Effect.InFocusRadius = 50
	self.Effect.NearIntensity = 0
	self.Effect.Enabled = false
	self.Effect.Parent = Services.Light

	self.Folder = Instance.new("Folder")
	self.Folder.Name = "UILibBlurParts"

	for Index = 1, 4 do
		local Part, Mesh = MakeBlurPart()
		Part.Parent = self.Folder
		self.Slots[Index] = { Part = Part, Mesh = Mesh }
	end

	--// Region that the blur follows (slightly inset so the square corners stay hidden)
	self.Region = Instance.new("Frame")
	self.Region.Name = "BlurRegion"
	self.Region.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Region.Position = UDim2.fromScale(0.5, 0.5)
	Inset = Inset or 8
	self.Region.Size = UDim2.new(1, -Inset * 2, 1, -Inset * 2)
	self.Region.BackgroundTransparency = 1
	self.Region.BorderSizePixel = 0
	pcall(function() self.Region.Interactable = false end)
	self.Region.Parent = Owner

	return self
end

function Blur:_step()
	local Region = self.Region
	if not Region or not Region:IsDescendantOf(game) or not self.Owner.Visible then return end

	local Camera = workspace.CurrentCamera
	if not Camera then return end

	if Camera ~= self.Camera then
		self.Camera = Camera
		self.Folder.Parent = Camera
	end

	local Size, Position = Region.AbsoluteSize, Region.AbsolutePosition
	if Size.X < 2 or Size.Y < 2 then return end

	local TL, BR = Position, Position + Size
	local TR, BL = Vector2.new(BR.X, TL.Y), Vector2.new(TL.X, BR.Y)

	local V1 = Camera:ScreenPointToRay(TL.X, TL.Y, BlurDepth).Origin
	local V2 = Camera:ScreenPointToRay(TR.X, TR.Y, BlurDepth).Origin
	local V3 = Camera:ScreenPointToRay(BL.X, BL.Y, BlurDepth).Origin
	local V4 = Camera:ScreenPointToRay(BR.X, BR.Y, BlurDepth).Origin

	if V1.X ~= V1.X or V4.X ~= V4.X then return end

	DrawTriangle(V1, V2, V3, self.Slots[1], self.Slots[2])
	DrawTriangle(V3, V2, V4, self.Slots[3], self.Slots[4])
end

function Blur:_bind()
	if self.Bound then return end
	self.Bound = true

	Services.Run:BindToRenderStep(self.BindId, Enum.RenderPriority.Last.Value, function()
		self:_step()
	end)
end

function Blur:_unbind()
	if not self.Bound then return end
	self.Bound = false

	pcall(function()
		Services.Run:UnbindFromRenderStep(self.BindId)
	end)
end

function Blur:SetVisible(Visible, Duration)
	if self.Destroyed then return end

	Visible = not not Visible
	Duration = Duration or 0.3

	self.Visible = Visible
	self.Version += 1

	local Version = self.Version

	if self.Tween then
		self.Tween:Cancel()
	end

	if Visible then
		self.Effect.Enabled = true
		self.Folder.Parent = workspace.CurrentCamera
		self:_bind()

		self.Tween = Services.Tween:Create(self.Effect, TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { NearIntensity = self.Intensity })
		self.Tween:Play()
	else
		local Fade = Services.Tween:Create(self.Effect, TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { NearIntensity = 0 })
		self.Tween = Fade

		Connect(Fade.Completed, function()
			if self.Destroyed or self.Version ~= Version or self.Visible then return end

			self.Folder.Parent = nil
			self.Effect.Enabled = false
			self:_unbind()
		end)

		Fade:Play()
	end
end

function Blur:SetIntensity(Value)
	if self.Destroyed or type(Value) ~= "number" then return end

	self.Intensity = math.clamp(Value, 0, 1)

	if self.Visible then
		if self.Tween then self.Tween:Cancel() end
		self.Effect.NearIntensity = self.Intensity
	end
end

function Blur:Destroy()
	if self.Destroyed then return end

	self.Destroyed = true
	self:_unbind()

	if self.Tween then self.Tween:Cancel() end

	pcall(function()
		self.Effect:Destroy()
		self.Folder:Destroy()
		self.Region:Destroy()
	end)
end

--// ============================================================
--// Liquid Glass (built in)
--// Layered "water droplet" glass that lives inside the window:
--// body tint, thick edge lip, bright rim, edge dispersion, top sheen,
--// specular glints, bottom caustic, pointer light and a periodic sweep.
--// ============================================================
local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

local GlassCounter = 0
local White = Color3.new(1, 1, 1)
local DefaultTint = Color3.fromRGB(190, 225, 255)

local NewObject = function(Class, Properties, Parent)
	local Object = Instance.new(Class)

	for Property, Value in next, Properties do
		Object[Property] = Value
	end

	if Object:IsA("GuiObject") then
		pcall(function()
			Object.Interactable = false --// Never block input of the UI underneath
		end)
	end

	Object.Parent = Parent
	return Object
end

local InsetRadius = function(Radius, Amount)
	return UDim.new(Radius.Scale, math.max(Radius.Offset - Amount, 0))
end

local FadeValue = function(Base, Intensity)
	return math.clamp(1 - (1 - Base) * Intensity, 0, 1)
end

local BuildSequence = function(Points, Intensity)
	local Keys = table.create(#Points)

	for Index, Point in ipairs(Points) do
		Keys[Index] = NumberSequenceKeypoint.new(Point[1], FadeValue(Point[2], Intensity))
	end

	return NumberSequence.new(Keys)
end

function LiquidGlass:_frame(Name, Parent, Properties)
	Properties.Name = Name
	Properties.BorderSizePixel = 0
	Properties.BackgroundColor3 = Properties.BackgroundColor3 or White

	if Properties.BackgroundTransparency == nil then
		Properties.BackgroundTransparency = 1
	end

	return NewObject("Frame", Properties, Parent)
end

function LiquidGlass:_gradient(Parent, Rotation, Points)
	local Gradient = NewObject("UIGradient", {
		Rotation = Rotation,
		Transparency = BuildSequence(Points, self.Intensity),
	}, Parent)

	table.insert(self.Gradients, { Gradient, Points })
	return Gradient
end

function LiquidGlass:_fade(Object, Base)
	Object.BackgroundTransparency = FadeValue(Base, self.Intensity)
	table.insert(self.Fades, { Object, Base })
end

function LiquidGlass:_ring(Name, Distance, Thickness, Rotation, Points)
	--// UIStroke draws outside of its frame, so the frame is inset by the stroke thickness
	local Ring = self:_frame(Name, self.Front, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -Distance * 2, 1, -Distance * 2),
	})

	NewObject("UICorner", { CornerRadius = InsetRadius(self.Radius, Distance) }, Ring)

	local Stroke = NewObject("UIStroke", {
		Thickness = Thickness,
		Color = White,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, Ring)

	return self:_gradient(Stroke, Rotation, Points)
end

function LiquidGlass:_applyTint()
	local Tint = self.Tint
	local Light = Tint:Lerp(White, 0.55)

	self.BodyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, White:Lerp(Tint, 0.25)),
		ColorSequenceKeypoint.new(0.5, Tint),
		ColorSequenceKeypoint.new(1, White:Lerp(Tint, 0.5)),
	})

	self.RimGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, White),
		ColorSequenceKeypoint.new(0.5, Light),
		ColorSequenceKeypoint.new(1, White),
	})

	self.LipGradient.Color = ColorSequence.new(Light, Tint)
	self.Caustic.BackgroundColor3 = Light
	self.DotB.BackgroundColor3 = Light

	for _, Disc in ipairs(self.Discs) do
		Disc.BackgroundColor3 = White:Lerp(Tint, 0.35)
	end
end

function LiquidGlass:_build()
	local Window = self.Window

	local Back = self:_frame("LG_Back", Window, { Size = UDim2.fromScale(1, 1), ZIndex = -5, Visible = false })
	local Front = self:_frame("LG_Front", Window, { Size = UDim2.fromScale(1, 1), ZIndex = 10, Visible = false })

	self.Back, self.Front = Back, Front

	--// [Back] glass body: soft tint + depth
	local Body = self:_frame("LG_Body", Back, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0 })
	NewObject("UICorner", { CornerRadius = self.Radius }, Body)
	self.BodyGradient = self:_gradient(Body, 135, { { 0, 0.78 }, { 0.5, 0.92 }, { 1, 0.82 } })

	local Depth = self:_frame("LG_Depth", Back, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 25, 60),
		BackgroundTransparency = 0,
	})
	NewObject("UICorner", { CornerRadius = self.Radius }, Depth)
	self.Depth = Depth
	self.DepthPoints = { { 0, 1 }, { 0.55, 1 }, { 1, 0.86 } }
	self:_gradient(Depth, 90, self.DepthPoints)

	--// [Front] thick lip of the droplet
	self.LipGradient = self:_ring("LG_Lip", 8, 6, 45, {
		{ 0, 0.86 }, { 0.3, 0.97 }, { 0.55, 0.94 }, { 0.8, 0.97 }, { 1, 0.84 },
	})

	--// Bright rim (strongest at top-left and bottom-right)
	self.RimGradient = self:_ring("LG_Rim", 2, 2, 45, {
		{ 0, 0.08 }, { 0.35, 0.8 }, { 0.5, 0.92 }, { 0.65, 0.8 }, { 1, 0.08 },
	})

	--// Edge dispersion (like light through water)
	self.DispA = self:_ring("LG_DispA", 4, 1, 45, { { 0, 0.45 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0.85 } })
	self.DispA.Color = ColorSequence.new(Color3.fromRGB(110, 220, 255))
	self.DispB = self:_ring("LG_DispB", 5, 1, 45, { { 0, 0.85 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0.45 } })
	self.DispB.Color = ColorSequence.new(Color3.fromRGB(255, 140, 210))

	--// Top sheen (curvature of the droplet)
	local Sheen = self:_frame("LG_Sheen", Front, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -12, 0.32, 0),
		BackgroundTransparency = 0,
	})
	NewObject("UICorner", { CornerRadius = InsetRadius(self.Radius, 6) }, Sheen)
	self:_gradient(Sheen, 90, { { 0, 0.84 }, { 1, 1 } })

	--// Sharp specular streak
	self.Spec = self:_frame("LG_Spec", Front, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.new(0.62, 0, 0, 5),
		BackgroundTransparency = 0,
	})
	NewObject("UICorner", { CornerRadius = UDim.new(1, 0) }, self.Spec)
	self:_gradient(self.Spec, 0, { { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } })

	--// Small water-bead glints
	local DotA = self:_frame("LG_DotA", Front, { Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(7, 7) })
	NewObject("UICorner", { CornerRadius = UDim.new(1, 0) }, DotA)
	self:_fade(DotA, 0.35)

	local DotC = self:_frame("LG_DotC", Front, { Position = UDim2.fromOffset(31, 11), Size = UDim2.fromOffset(3, 3) })
	NewObject("UICorner", { CornerRadius = UDim.new(1, 0) }, DotC)
	self:_fade(DotC, 0.5)

	self.DotB = self:_frame("LG_DotB", Front, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -14),
		Size = UDim2.fromOffset(5, 5),
	})
	NewObject("UICorner", { CornerRadius = UDim.new(1, 0) }, self.DotB)
	self:_fade(self.DotB, 0.55)

	--// Bottom caustic (focused light)
	self.Caustic = self:_frame("LG_Caustic", Front, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.62, 0, 1, -6),
		Size = UDim2.new(0.5, 0, 0, 6),
		BackgroundTransparency = 0,
	})
	NewObject("UICorner", { CornerRadius = UDim.new(1, 0) }, self.Caustic)
	self:_gradient(self.Caustic, 0, { { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } })

	--// Pointer light: a soft radial glow built from many faint concentric discs,
	--// rendered inside one CanvasGroup so a single property controls its fade
	self.Glow = NewObject("CanvasGroup", {
		Name = "LG_Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Size = UDim2.fromOffset(200, 200),
		Visible = false,
	}, Front)

	self.Discs = {}

	local Steps = 18
	for Index = 1, Steps do
		local Ratio = 1 - ((Index - 1) / Steps) * 0.96
		local Amount = 0.010 + 0.026 * (Index / Steps) ^ 2

		local Disc = self:_frame("LG_Disc", self.Glow, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(Ratio, Ratio),
			BackgroundTransparency = 1 - Amount,
		})
		NewObject("UICorner", { CornerRadius = UDim.new(1, 0) }, Disc)
		table.insert(self.Discs, Disc)
	end

	--// Periodic light sweep
	self.Sweep = self:_frame("LG_Sweep", Front, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.2, 2),
		Rotation = 20,
		BackgroundTransparency = 0,
		Visible = false,
	})
	self:_gradient(self.Sweep, 0, { { 0, 1 }, { 0.5, 0.9 }, { 1, 1 } })

	if self.Compact then
		DotA.Visible, DotC.Visible, self.DotB.Visible = false, false, false
	end

	self:_applyTint()
end

function LiquidGlass.new(Window, Config)
	Config = Config or {}
	GlassCounter += 1

	local Corner = Window:FindFirstChildOfClass("UICorner")

	local self = setmetatable({
		Window = Window,
		Intensity = math.clamp(Config.Intensity or 1, 0, 1.5),
		Tint = Config.Tint or DefaultTint,
		Radius = (Corner and Corner.CornerRadius) or UDim.new(0, 12),
		GetPointer = Config.GetPointer,
		Compact = Config.Compact == true,

		Enabled = false,
		Destroyed = false,

		Gradients = {},
		Fades = {},
		Panels = {},

		_id = "UILib_Glass_" .. GlassCounter,
		_bound = false,
		_seen = false,
		_nx = 0, _ny = 0,
		_gx = 0, _gy = 0,
		_alpha = 0,
		_phase = math.random() * 9,
	}, LiquidGlass)

	for _, Panel in ipairs(Config.Panels or {}) do
		table.insert(self.Panels, { Object = Panel[1], Target = Panel[2] or 0.5, Original = nil })
	end

	self:_build()
	return self
end

function LiquidGlass:_applyPanels(On)
	for _, Panel in ipairs(self.Panels) do
		local Object = Panel.Object

		if Object then
			if On then
				if Panel.Original == nil then
					Panel.Original = Object.BackgroundTransparency
				end

				if Panel.Original < Panel.Target then
					Object.BackgroundTransparency = Panel.Original + (Panel.Target - Panel.Original) * math.clamp(self.Intensity, 0, 1)
				end
			elseif Panel.Original ~= nil then
				Object.BackgroundTransparency = Panel.Original
			end
		end
	end
end

function LiquidGlass:_refresh()
	for _, Info in ipairs(self.Gradients) do
		Info[1].Transparency = BuildSequence(Info[2], self.Intensity)
	end

	for _, Info in ipairs(self.Fades) do
		Info[1].BackgroundTransparency = FadeValue(Info[2], self.Intensity)
	end

	if self.Enabled then
		self:_applyPanels(true)
	end
end

function LiquidGlass:_step(Delta)
	local Window = self.Window

	if not Window or not Window:IsDescendantOf(game) then
		if self._seen then
			self:Destroy()
		end
		return
	end

	self._seen = true

	if not Window.Visible then return end

	local Size, Position = Window.AbsoluteSize, Window.AbsolutePosition
	if Size.X < 1 or Size.Y < 1 then return end

	local Time = os.clock() + self._phase
	local Pointer = self.GetPointer and self.GetPointer()
	local RelX, RelY = Size.X / 2, Size.Y / 2

	if Pointer then
		RelX, RelY = Pointer.X - Position.X, Pointer.Y - Position.Y
	end

	local Inside = Pointer ~= nil and RelX >= 0 and RelY >= 0 and RelX <= Size.X and RelY <= Size.Y
	local Smooth = 1 - math.exp(-Delta * 10)

	--// Light direction
	local TargetX = math.clamp(RelX / Size.X - 0.5, -0.5, 0.5)
	local TargetY = math.clamp(RelY / Size.Y - 0.5, -0.5, 0.5)
	self._nx += (TargetX - self._nx) * Smooth
	self._ny += (TargetY - self._ny) * Smooth

	local Angle = 45 + (self._nx - self._ny) * 70
	self.RimGradient.Rotation = Angle
	self.LipGradient.Rotation = Angle
	self.DispA.Rotation = Angle + 8
	self.DispB.Rotation = Angle - 8
	self.BodyGradient.Rotation = 135 + self._nx * 20

	--// Liquid motion
	self.Spec.Position = UDim2.new(0.5 + math.sin(Time * 0.45) * 0.05, 0, 0, 7)
	self.Caustic.Position = UDim2.new(0.62 + math.sin(Time * 0.6) * 0.08, 0, 1, -6)

	--// Pointer light
	self._alpha += ((Inside and 1 or 0) - self._alpha) * (1 - math.exp(-Delta * 8))

	if self._alpha > 0.01 then
		if not self.Glow.Visible then
			self._gx, self._gy = RelX, RelY
			self.Glow.Visible = true
		end

		local Follow = 1 - math.exp(-Delta * 12)
		self._gx += (math.clamp(RelX, 0, Size.X) - self._gx) * Follow
		self._gy += (math.clamp(RelY, 0, Size.Y) - self._gy) * Follow

		local Diameter = math.clamp(math.max(Size.X, Size.Y) * (self.Compact and 1.2 or 0.55), self.Compact and 40 or 150, 340)

		self.Glow.Size = UDim2.fromOffset(Diameter, Diameter)
		self.Glow.Position = UDim2.fromOffset(self._gx, self._gy)
		self.Glow.GroupTransparency = 1 - math.clamp(self.Intensity * self._alpha, 0, 1)
	elseif self.Glow.Visible then
		self.Glow.Visible = false
	end

	if self.Compact then return end

	--// Light sweep (once every 9 seconds)
	local Phase = (Time % 9) / 9
	if Phase < 0.22 then
		local P = Phase / 0.22
		P = P * P * (3 - 2 * P)
		self.Sweep.Position = UDim2.fromScale(-0.25 + 1.5 * P, 0.5)

		if not self.Sweep.Visible then
			self.Sweep.Visible = true
		end
	elseif self.Sweep.Visible then
		self.Sweep.Visible = false
	end
end

function LiquidGlass:_bind()
	if self._bound then return end
	self._bound = true

	Services.Run:BindToRenderStep(self._id, Enum.RenderPriority.Last.Value, function(Delta)
		self:_step(Delta)
	end)
end

function LiquidGlass:_unbind()
	if not self._bound then return end
	self._bound = false

	pcall(function()
		Services.Run:UnbindFromRenderStep(self._id)
	end)
end

function LiquidGlass:SetEnabled(Value)
	if self.Destroyed then return end

	Value = not not Value
	self.Enabled = Value
	self.Back.Visible = Value
	self.Front.Visible = Value

	self:_applyPanels(Value)

	if Value then
		self:_bind()
	else
		self:_unbind()
	end
end

function LiquidGlass:SetIntensity(Value)
	if self.Destroyed or type(Value) ~= "number" then return end

	self.Intensity = math.clamp(Value, 0, 1.5)
	self:_refresh()
end

function LiquidGlass:SetTint(Value)
	if self.Destroyed or typeof(Value) ~= "Color3" then return end

	self.Tint = Value
	self:_applyTint()
end

function LiquidGlass:SetLight(IsLight)
	if self.Destroyed then return end

	self.Depth.BackgroundColor3 = IsLight and Color3.fromRGB(120, 150, 190) or Color3.fromRGB(10, 25, 60)
	self.DepthPoints[3][2] = IsLight and 0.93 or 0.86
	self:_refresh()
end

function LiquidGlass:Destroy()
	if self.Destroyed then return end

	self.Destroyed = true
	self.Enabled = false
	self:_unbind()
	self:_applyPanels(false)

	pcall(function()
		self.Back:Destroy()
		self.Front:Destroy()
	end)
end

--// ============================================================
--// Tables for Data
--// ============================================================
local Animations = {}
local Components = (Screen:FindFirstChild("Components"));
local Library = {};
local StoredInfo = {
	["Sections"] = {};
	["Tabs"] = {}
};

--// Animations [Window]
function Animations:Open(Window: CanvasGroup, Transparency: number, UseCurrentSize: boolean)
	local Original = (UseCurrentSize and Window.Size) or Setup.Size
	local Multiplied = Multiply(Original, 1.1)
	local Shadow = Window:FindFirstChildOfClass("UIStroke")

	if Shadow then SetProperty(Shadow, { Transparency = 1 }) end
	SetProperty(Window, {
		Size = Multiplied,
		GroupTransparency = 1,
		Visible = true,
	})

	if Shadow then Tween(Shadow, .25, { Transparency = 0.5 }) end
	Tween(Window, .25, {
		Size = Original,
		GroupTransparency = Transparency or 0,
	})
end

function Animations:Close(Window: CanvasGroup)
	local Original = Window.Size
	local Multiplied = Multiply(Original, 1.1)
	local Shadow = Window:FindFirstChildOfClass("UIStroke")

	SetProperty(Window, {
		Size = Original,
	})

	if Shadow then Tween(Shadow, .25, { Transparency = 1 }) end
	Tween(Window, .25, {
		Size = Multiplied,
		GroupTransparency = 1,
	})

	task.wait(.25)
	Window.Size = Original
	Window.Visible = false
end

function Animations:Component(Component: any, Custom: boolean)	
	Connect(Component.InputBegan, function() 
		if Custom then
			Tween(Component, .25, { Transparency = .85 });
		else
			Tween(Component, .25, { BackgroundColor3 = Color(Theme.Component, 5, Setup.ThemeMode) });
		end
	end)

	Connect(Component.InputEnded, function() 
		if Custom then
			Tween(Component, .25, { Transparency = 1 });
		else
			Tween(Component, .25, { BackgroundColor3 = Theme.Component });
		end
	end)
end

--// ============================================================
--// "Show UI" prompt (small floating pill, shown while the window is hidden)
--// Tap it to bring the window back. It can be dragged anywhere on screen.
--// ============================================================
local CreatePrompt = function(OnClick, CornerRadius)
	local Prompt = {}
	local Shown = false
	local Version = 0
	local Home = UDim2.new(0.5, 0, 0, 28)
	local Connections = {}

	local PromptBlur, PromptGlass = nil, nil
	local BlurWanted, GlassWanted = false, false
	local BlurIntensity, GlassIntensity = 1, 1

	--// Same translucency rules as the window
	local Rest = function()
		if GlassWanted and PromptGlass then
			return 0.08 + (0.45 - 0.08) * math.clamp(GlassIntensity, 0, 1)
		end

		return 0.08
	end

	local Holder = Instance.new("CanvasGroup")
	SetProperty(Holder, {
		Name = "ShowPrompt",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(92, 30),
		Position = Home,
		BackgroundColor3 = Theme.Primary,
		BackgroundTransparency = Rest(),
		GroupTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 100,
	})

	local Pulse = Instance.new("UIScale")
	Pulse.Scale = 0.85
	Pulse.Parent = Holder

	--// Corner radius follows the window (capped so it never exceeds a full pill)
	local Radius = (CornerRadius and CornerRadius.Offset > 0) and CornerRadius.Offset or 8

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, math.min(Radius, 15))
	Corner.Parent = Holder

	local Stroke = Instance.new("UIStroke")
	SetProperty(Stroke, {
		Name = "PromptStroke",
		Color = Theme.Outline,
		Thickness = 1,
		Transparency = 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	Stroke.Parent = Holder

	--// Same font as the UI titles
	local Face
	pcall(function()
		Face = Components["Button"]["Labels"]["Title"].FontFace
	end)

	local Label = Instance.new("TextLabel")
	SetProperty(Label, {
		Name = "PromptLabel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		Text = "Show UI",
		TextSize = 13,
		TextColor3 = Theme.Title,
		ZIndex = 101,
	})
	if Face then
		Label.FontFace = Face
	end
	Label.Parent = Holder

	local Button = Instance.new("TextButton")
	SetProperty(Button, {
		Name = "PromptButton",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 102,
	})
	Button.Parent = Holder
	Holder.Parent = Screen

	function Prompt:Refresh()
		Holder.BackgroundColor3 = Theme.Primary
		Stroke.Color = Theme.Outline
		Label.TextColor3 = Theme.Title

		if PromptGlass then
			PromptGlass:SetLight((Theme.Primary.R + Theme.Primary.G + Theme.Primary.B) / 3 > 0.6)
		end

		if Shown then
			Holder.GroupTransparency = Setup.Transparency
		end
	end

	function Prompt:GetCenter()
		local View = GetViewport()
		return Vector2.new(View.X * Home.X.Scale + Home.X.Offset, View.Y * Home.Y.Scale + Home.Y.Offset)
	end

	function Prompt:SetBlur(Value, Intensity)
		BlurWanted = not not Value
		BlurIntensity = Intensity or BlurIntensity

		if BlurWanted and not PromptBlur then
			PromptBlur = Blur.new(Holder, BlurIntensity, 4)
		end

		if PromptBlur then
			PromptBlur:SetIntensity(BlurIntensity)
			PromptBlur:SetVisible(BlurWanted and Shown, 0.3)
		end
	end

	function Prompt:SetGlass(Value, Intensity, Tint)
		GlassWanted = not not Value
		GlassIntensity = Intensity or GlassIntensity

		if GlassWanted and not PromptGlass then
			local Created, Result = pcall(LiquidGlass.new, Holder, {
				Intensity = GlassIntensity,
				Tint = Tint,
				GetPointer = GetHoverPointer,
				Compact = true,
			})

			if Created then
				PromptGlass = Result
			end
		end

		if PromptGlass then
			PromptGlass:SetIntensity(GlassIntensity)

			if Tint then
				PromptGlass:SetTint(Tint)
			end

			PromptGlass:SetLight((Theme.Primary.R + Theme.Primary.G + Theme.Primary.B) / 3 > 0.6)
			PromptGlass:SetEnabled(GlassWanted)
		end

		Tween(Holder, .25, { BackgroundTransparency = Rest() })
	end

	--// The window condenses into the pill, so the pill simply fades / pulses in place
	function Prompt:Show()
		Version += 1
		Shown = true

		SetProperty(Holder, { Position = Home, GroupTransparency = 1, Visible = true })
		Pulse.Scale = 0.8

		Tween(Holder, .35, { GroupTransparency = Setup.Transparency }, Ease.SineOut)
		Tween(Pulse, .5, { Scale = 1 }, Ease.Out)

		if PromptBlur then
			PromptBlur:SetVisible(BlurWanted, 0.45)
		end
	end

	function Prompt:Hide()
		if not Shown then return end

		Shown = false
		Version += 1

		local Current = Version

		Tween(Holder, .25, { GroupTransparency = 1 }, Ease.SineIn)
		Tween(Pulse, .25, { Scale = 0.85 }, Ease.In)

		if PromptBlur then
			PromptBlur:SetVisible(false, 0.25)
		end

		task.delay(.27, function()
			if Version == Current then
				Holder.Visible = false
			end
		end)
	end

	function Prompt:Destroy()
		for _, Item in next, Connections do
			Item:Disconnect()
		end

		if PromptGlass then PromptGlass:Destroy() end
		if PromptBlur then PromptBlur:Destroy() end

		Holder:Destroy()
	end

	--// Tap to open, drag to move
	local Active, Origin, Start, Moved

	table.insert(Connections, Button.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Active = Input
			Origin = Vector2.new(Input.Position.X, Input.Position.Y)
			Start = Holder.AbsolutePosition + Holder.AbsoluteSize / 2
			Moved = false
		end
	end))

	table.insert(Connections, Services.Input.InputChanged:Connect(function(Input)
		if not Active then return end
		if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then return end

		local Delta = Vector2.new(Input.Position.X, Input.Position.Y) - Origin

		if not Moved and Delta.Magnitude > 6 then
			Moved = true
		end

		if Moved then
			local Bounds, Half = GetViewport(), Holder.AbsoluteSize / 2
			local X = math.clamp(Start.X + Delta.X, Half.X, math.max(Bounds.X - Half.X, Half.X))
			local Y = math.clamp(Start.Y + Delta.Y, Half.Y, math.max(Bounds.Y - Half.Y, Half.Y))

			Holder.Position = UDim2.fromOffset(X, Y)
		end
	end))

	table.insert(Connections, Services.Input.InputEnded:Connect(function(Input)
		if Active and (Input == Active or Input.UserInputType == Active.UserInputType) then
			local WasMoved = Moved
			Active = nil

			if WasMoved then
				Home = Holder.Position
			elseif Shown then
				OnClick()
			end
		end
	end))

	return Prompt
end

--// ============================================================
--// Library [Window]
--// ============================================================
function Library:CreateWindow(Settings: { Title: string, Size: UDim2, Transparency: number, MinimizeKeybind: Enum.KeyCode?, Blurring: boolean, BlurIntensity: number, LiquidGlass: boolean, LiquidGlassIntensity: number, LiquidGlassTint: Color3, ShowButton: boolean, Theme: string })
	local Window = Clone(Screen:WaitForChild("Main"));
	local Sidebar = Window:FindFirstChild("Sidebar");
	local Holder = Window:FindFirstChild("Main");
	local BG = Window:FindFirstChild("BackgroundShadow");
	local Tab = Sidebar:FindFirstChild("Tab");

	local Options = {};
	local Examples = {};
	local Opened = true;
	local Maximized = false;
	local Busy = false;
	local Pending = false;

	local BlurObject, Glass = nil, nil
	local Prompt, SyncPrompt
	local BlurEnabled, GlassEnabled = false, false

	local Scale = Window:FindFirstChildOfClass("UIScale")
	if not Scale then
		Scale = Instance.new("UIScale")
		Scale.Parent = Window
	end

	local BaseScale = Scale.Scale
	local MinimizeScale = 0.4
	local SavedPosition = nil

	for Index, Example in next, Window:GetDescendants() do
		if Example.Name:find("Example") and not Examples[Example.Name] then
			Examples[Example.Name] = Example
		end
	end

	--// Window setup
	Drag(Window, Holder);
	Resizeable(Window, Vector2.new(411, 271), GetViewport());
	Setup.Transparency = Settings.Transparency or 0
	Setup.Size = FitSize(Settings.Size)
	Setup.ThemeMode = Settings.Theme or "Dark"

	if Settings.MinimizeKeybind then
		Setup.Keybind = Settings.MinimizeKeybind
	end

	--// Blur
	local SetBlur = function(Value)
		Value = not not Value

		if Value and not BlurObject then
			BlurObject = Blur.new(Window, Settings.BlurIntensity or 1)
		end

		BlurEnabled = Value

		if BlurObject then
			BlurObject:SetVisible(Value and Opened, 0.4)
		end

		if SyncPrompt then SyncPrompt() end
	end

	--// Liquid Glass
	local SetLiquidGlass = function(Value)
		Value = not not Value

		if Value and not Glass then
			local Created, Result = pcall(LiquidGlass.new, Window, {
				Intensity = Settings.LiquidGlassIntensity,
				Tint = Settings.LiquidGlassTint,
				GetPointer = GetPointer,
				Panels = { { Window, 0.45 }, { Holder, 0.5 } },
			})

			if not Created then
				warn("[UI LIB]: Failed to create Liquid Glass - " .. tostring(Result))
				return
			end

			Glass = Result
			Glass:SetLight((Theme.Primary.R + Theme.Primary.G + Theme.Primary.B) / 3 > 0.6)
		end

		GlassEnabled = Value

		if Glass then
			Glass:SetEnabled(Value)
		end

		if SyncPrompt then SyncPrompt() end
	end

	if Settings.Blurring then
		SetBlur(true)
	end

	if Settings.LiquidGlass then
		SetLiquidGlass(true)
	end

	--// Minimize / restore
	local ShowPrompt = Settings.ShowButton
	if ShowPrompt == nil then
		ShowPrompt = Services.Input.TouchEnabled
	end

	local Toggle

	local WindowCorner = Window:FindFirstChildOfClass("UICorner")

	Prompt = CreatePrompt(function()
		Toggle()
	end, WindowCorner and WindowCorner.CornerRadius)

	--// Keeps the Show UI pill in sync with the window (blur, glass, tint)
	SyncPrompt = function()
		Prompt:SetBlur(BlurEnabled, Settings.BlurIntensity or 1)
		Prompt:SetGlass(GlassEnabled, Settings.LiquidGlassIntensity or 1, Settings.LiquidGlassTint)
	end

	SyncPrompt()

	local ShrunkPosition = function()
		local Small = ResolveSize(Window.Size) * BaseScale * MinimizeScale
		local Center = Prompt:GetCenter()
		local Anchor = Window.AnchorPoint

		return UDim2.fromOffset(Center.X + (Anchor.X - 0.5) * Small.X, Center.Y + (Anchor.Y - 0.5) * Small.Y)
	end

	local Finish = function()
		Busy = false

		if Pending then
			Pending = false
			Toggle()
		end
	end

	local Hide = function()
		Busy, Opened = true, false
		SavedPosition = Window.Position

		local Shadow = Window:FindFirstChildOfClass("UIStroke")

		if BlurObject then
			BlurObject:SetVisible(false, 0.3)
		end

		Tween(Window, .42, { Position = ShrunkPosition() }, Ease.InOut)
		Tween(Scale, .42, { Scale = BaseScale * MinimizeScale }, Ease.InOut)
		Tween(Window, .3, { GroupTransparency = 1 }, Ease.SineIn)

		if Shadow then
			Tween(Shadow, .25, { Transparency = 1 })
		end

		if ShowPrompt then
			task.delay(.28, function()
				if not Opened then
					Prompt:Show()
				end
			end)
		end

		task.delay(.44, function()
			if not Opened then
				Window.Visible = false
				Scale.Scale = BaseScale
				Window.Position = SavedPosition
			end

			Finish()
		end)
	end

	local Show = function()
		Busy, Opened = true, true
		Prompt:Hide()

		local Shadow = Window:FindFirstChildOfClass("UIStroke")
		local Target = SavedPosition or Window.Position

		SetProperty(Window, {
			Position = ShrunkPosition(),
			GroupTransparency = 1,
			Visible = true,
		})

		Scale.Scale = BaseScale * MinimizeScale

		if Shadow then
			Shadow.Transparency = 1
			Tween(Shadow, .4, { Transparency = 0.5 })
		end

		if BlurObject then
			BlurObject:SetVisible(BlurEnabled, 0.45)
		end

		Tween(Window, .5, { Position = Target }, Ease.Out)
		Tween(Scale, .5, { Scale = BaseScale }, Ease.Out)
		Tween(Window, .35, { GroupTransparency = Setup.Transparency }, Ease.SineOut)

		task.delay(.52, Finish)
	end

	Toggle = function()
		if Busy then
			Pending = not Pending
			return
		end

		if Opened then
			Hide()
		else
			Show()
		end
	end

	for Index, Button in next, Sidebar.Top.Buttons:GetChildren() do
		if Button:IsA("TextButton") then
			local Name = Button.Name
			Animations:Component(Button, true)

			Connect(Button.MouseButton1Click, function() 
				if Name == "Close" or Name == "Minimize" then
					Toggle()
				elseif Name == "Maximize" then
					if Maximized then
						Maximized = false
						Tween(Window, .15, { Size = Setup.Size });
					else
						Maximized = true
						Tween(Window, .15, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5 )});
					end
				end
			end)
		end
	end

	local KeybindConnection = Services.Input.InputBegan:Connect(function(Input, Focused) 
		if (Input == Setup.Keybind or Input.KeyCode == Setup.Keybind) and not Focused then
			Toggle()
		end
	end)

	--// Tab Functions

	function Options:SetTab(Name: string)
		for Index, Button in next, Tab:GetChildren() do
			if Button:IsA("TextButton") then
				local Opened, SameName = Button.Value, (Button.Name == Name);
				local Padding = Button:FindFirstChildOfClass("UIPadding");

				if SameName and not Opened.Value then
					Tween(Padding, .25, { PaddingLeft = UDim.new(0, 25) });
					Tween(Button, .25, { BackgroundTransparency = 0.9, Size = UDim2.new(1, -15, 0, 30) });
					SetProperty(Opened, { Value = true });
				elseif not SameName and Opened.Value then
					Tween(Padding, .25, { PaddingLeft = UDim.new(0, 20) });
					Tween(Button, .25, { BackgroundTransparency = 1, Size = UDim2.new(1, -44, 0, 30) });
					SetProperty(Opened, { Value = false });
				end
			end
		end

		for Index, Main in next, Holder:GetChildren() do
			if Main:IsA("CanvasGroup") then
				local Opened, SameName = Main.Value, (Main.Name == Name);
				local Scroll = Main:FindFirstChild("ScrollingFrame");

				if SameName and not Opened.Value then
					Opened.Value = true
					Main.Visible = true

					Tween(Main, .3, { GroupTransparency = 0 });
					Tween(Scroll["UIPadding"], .3, { PaddingTop = UDim.new(0, 5) });

				elseif not SameName and Opened.Value then
					Opened.Value = false

					Tween(Main, .15, { GroupTransparency = 1 });
					Tween(Scroll["UIPadding"], .15, { PaddingTop = UDim.new(0, 15) });	

					task.delay(.2, function()
						Main.Visible = false
					end)
				end
			end
		end
	end

	function Options:AddTabSection(Settings: { Name: string, Order: number })
		local Example = Examples["SectionExample"];
		local Section = Clone(Example);

		StoredInfo["Sections"][Settings.Name] = (Settings.Order);
		SetProperty(Section, { 
			Parent = Example.Parent,
			Text = Settings.Name,
			Name = Settings.Name,
			LayoutOrder = Settings.Order,
			Visible = true
		});
	end

	function Options:AddTab(Settings: { Title: string, Icon: string, Section: string? })
		if StoredInfo["Tabs"][Settings.Title] then 
			error("[UI LIB]: A tab with the same name has already been created") 
		end 

		local Example, MainExample = Examples["TabButtonExample"], Examples["MainExample"];
		local Section = StoredInfo["Sections"][Settings.Section];
		local Main = Clone(MainExample);
		local Tab = Clone(Example);

		if not Settings.Icon then
			Destroy(Tab["ICO"]);
		else
			SetProperty(Tab["ICO"], { Image = Settings.Icon });
		end

		StoredInfo["Tabs"][Settings.Title] = { Tab }
		SetProperty(Tab["TextLabel"], { Text = Settings.Title });

		SetProperty(Main, { 
			Parent = MainExample.Parent,
			Name = Settings.Title;
		});

		SetProperty(Tab, { 
			Parent = Example.Parent,
			LayoutOrder = Section or #StoredInfo["Sections"] + 1,
			Name = Settings.Title;
			Visible = true;
		});

		Tab.MouseButton1Click:Connect(function()
			Options:SetTab(Tab.Name);
		end)

		return Main.ScrollingFrame
	end

	--// Notifications

	function Options:Notify(Settings: { Title: string, Description: string, Duration: number }) 
		local Notification = Clone(Components["Notification"]);
		local Title, Description = Options:GetLabels(Notification);
		local Timer = Notification["Timer"];

		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Notification, {
			Parent = Screen["Frame"],
		})

		task.spawn(function() 
			local Duration = Settings.Duration or 2
			local Wait = task.wait;

			Animations:Open(Notification, Setup.Transparency, true); Tween(Timer, Duration, { Size = UDim2.new(0, 0, 0, 4) });
			Wait(Duration);
			Animations:Close(Notification);
			Wait(1);
			Notification:Destroy();
		end)
	end

	--// Component Functions

	function Options:GetLabels(Component)
		local Labels = Component:FindFirstChild("Labels")

		return Labels.Title, Labels.Description
	end

	function Options:AddSection(Settings: { Name: string, Tab: Instance }) 
		local Section = Clone(Components["Section"]);
		SetProperty(Section, {
			Text = Settings.Name,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddButton(Settings: { Title: string, Description: string, Tab: Instance, Callback: any }) 
		local Button = Clone(Components["Button"]);
		local Title, Description = Options:GetLabels(Button);

		Connect(Button.MouseButton1Click, Settings.Callback)
		Animations:Component(Button)
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Button, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddInput(Settings: { Title: string, Description: string, Tab: Instance, Callback: any }) 
		local Input = Clone(Components["Input"]);
		local Title, Description = Options:GetLabels(Input);
		local TextBox = Input["Main"]["Input"];

		Connect(Input.MouseButton1Click, function() 
			TextBox:CaptureFocus()
		end)

		Connect(TextBox.FocusLost, function() 
			Settings.Callback(TextBox.Text)
		end)

		Animations:Component(Input)
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Input, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddToggle(Settings: { Title: string, Description: string, Default: boolean, Tab: Instance, Callback: any }) 
		local Toggle = Clone(Components["Toggle"]);
		local Title, Description = Options:GetLabels(Toggle);

		local On = Toggle["Value"];
		local Main = Toggle["Main"];
		local Circle = Main["Circle"];

		local Set = function(Value)
			Value = Value == true

			if Value then
				Tween(Main,   .2, { BackgroundColor3 = Color3.fromRGB(153, 155, 255) });
				Tween(Circle, .2, { BackgroundColor3 = Color3.fromRGB(255, 255, 255), Position = UDim2.new(1, -16, 0.5, 0) });
			else
				Tween(Main,   .2, { BackgroundColor3 = Theme.Interactables });
				Tween(Circle, .2, { BackgroundColor3 = Theme.Primary, Position = UDim2.new(0, 3, 0.5, 0) });
			end

			On.Value = Value
		end 

		Connect(Toggle.MouseButton1Click, function()
			local Value = not On.Value

			Set(Value)
			Settings.Callback(Value)
		end)

		Animations:Component(Toggle);
		Set(Settings.Default);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Toggle, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddKeybind(Settings: { Title: string, Description: string, Tab: Instance, Callback: any }) 
		local Dropdown = Clone(Components["Keybind"]);
		local Title, Description = Options:GetLabels(Dropdown);
		local Bind = Dropdown["Main"].Options;

		local Mouse = { Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3 }; 
		local Types = { 
			["Mouse"] = "Enum.UserInputType.MouseButton", 
			["Key"] = "Enum.KeyCode." 
		}

		Connect(Dropdown.MouseButton1Click, function()
			local Detect, Finished

			SetProperty(Bind, { Text = "..." });
			Detect = Connect(Services.Input.InputBegan, function(Key, Focused) 
				local InputType = (Key.UserInputType)

				if not Finished and not Focused then
					Finished = (true)

					if table.find(Mouse, InputType) then
						Settings.Callback(Key);
						SetProperty(Bind, {
							Text = tostring(InputType):gsub(Types.Mouse, "MB")
						})
					elseif InputType == Enum.UserInputType.Keyboard then
						Settings.Callback(Key);
						SetProperty(Bind, {
							Text = tostring(Key.KeyCode):gsub(Types.Key, "")
						})
					end

					Detect:Disconnect()
				end 
			end)
		end)

		Animations:Component(Dropdown);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Dropdown, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddDropdown(Settings: { Title: string, Description: string, Options: {}, Tab: Instance, Callback: any }) 
		local Dropdown = Clone(Components["Dropdown"]);
		local Title, Description = Options:GetLabels(Dropdown);
		local Text = Dropdown["Main"].Options;

		Connect(Dropdown.MouseButton1Click, function()
			local Example = Clone(Examples["DropdownExample"]);
			local Buttons = Example["Top"]["Buttons"];

			Tween(BG, .25, { BackgroundTransparency = 0.6 });
			SetProperty(Example, { Parent = Window });
			Animations:Open(Example, 0, true)

			local Dismiss = function()
				Tween(BG, .25, { BackgroundTransparency = 1 });
				task.spawn(function()
					Animations:Close(Example);
					task.wait(2)
					Destroy(Example);
				end)
			end

			for Index, Button in next, Buttons:GetChildren() do
				if Button:IsA("TextButton") then
					Animations:Component(Button, true)
					Connect(Button.MouseButton1Click, Dismiss)
				end
			end

			for Index, Option in next, Settings.Options do
				local Button = Clone(Examples["DropdownButtonExample"]);
				local Title, Description = Options:GetLabels(Button);
				local Selected = Button["Value"];

				Animations:Component(Button);
				SetProperty(Title, { Text = Index });
				SetProperty(Button, { Parent = Example.ScrollingFrame, Visible = true });
				Destroy(Description);

				Connect(Button.MouseButton1Click, function() 
					local NewValue = not Selected.Value 

					if NewValue then
						Tween(Button, .25, { BackgroundColor3 = Theme.Interactables });
						Settings.Callback(Option)
						Text.Text = Index

						for _, Others in next, Example:GetChildren() do
							if Others:IsA("TextButton") and Others ~= Button then
								Others.BackgroundColor3 = Theme.Component
							end
						end
					else
						Tween(Button, .25, { BackgroundColor3 = Theme.Component });
					end

					Selected.Value = NewValue
					Dismiss()
				end)
			end
		end)

		Animations:Component(Dropdown);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Dropdown, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddSlider(Settings: { Title: string, Description: string, MaxValue: number, Default: number, AllowDecimals: boolean, DecimalAmount: number, Tab: Instance, Callback: any }) 
		local Slider = Clone(Components["Slider"]);
		local Title, Description = Options:GetLabels(Slider);

		local Main = Slider["Slider"];
		local Amount = Main["Main"].Input;
		local Slide = Main["Slide"];
		local Fire = Slide["Fire"];
		local Fill = Slide["Highlight"];

		local Active = false
		local Value = 0
		local Maximum = Settings.MaxValue

		local SetNumber = function(Number)
			if Settings.AllowDecimals then
				local Power = 10 ^ (Settings.DecimalAmount or 2)
				Number = math.floor(Number * Power + 0.5) / Power
			else
				Number = math.round(Number)
			end

			return Number
		end

		--// Updates the visuals only (no callback)
		local Render = function(Number)
			Value = SetNumber(math.clamp(Number, 0, Maximum))
			Amount.Text = tostring(Value)
			Fill.Size = UDim2.fromScale(Value / Maximum, 1)
		end

		local Update = function(Number)
			if not Number then
				local Fraction = (GetPointer().X - Slide.AbsolutePosition.X) / Slide.AbsoluteSize.X
				Number = math.clamp(Fraction, 0, 1) * Maximum
			end

			Render(Number)
			Settings.Callback(Value)
		end

		local Activate = function()
			Active = true

			repeat task.wait()
				Update()
			until not Active
		end

		Connect(Amount.FocusLost, function() 
			Update(tonumber(Amount.Text) or 0)
		end)

		Connect(Fire.MouseButton1Down, Activate)
		Connect(Services.Input.InputEnded, function(Input) 
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Active = false
			end
		end)

		Render(Settings.Default or 0);
		Animations:Component(Slider);
		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Slider, {
			Name = Settings.Title,
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	function Options:AddParagraph(Settings: { Title: string, Description: string, Tab: Instance }) 
		local Paragraph = Clone(Components["Paragraph"]);
		local Title, Description = Options:GetLabels(Paragraph);

		SetProperty(Title, { Text = Settings.Title });
		SetProperty(Description, { Text = Settings.Description });
		SetProperty(Paragraph, {
			Parent = Settings.Tab,
			Visible = true,
		})
	end

	--// Ready-made appearance controls (Blur, Liquid Glass, Transparency)
	function Options:AddAppearanceSettings(Info: { Tab: Instance })
		Options:AddToggle({
			Title = "UI Blur",
			Description = "Blurs the game behind the window. Requires graphics quality 8 or higher.",
			Default = BlurEnabled,
			Tab = Info.Tab,
			Callback = function(Value)
				Options:SetSetting("Blur", Value)
			end,
		})

		Options:AddToggle({
			Title = "Liquid Glass",
			Description = "Frosted glass surface with water-droplet highlights. Best used together with UI Blur.",
			Default = GlassEnabled,
			Tab = Info.Tab,
			Callback = function(Value)
				Options:SetSetting("LiquidGlass", Value)
			end,
		})

		Options:AddSlider({
			Title = "Glass Intensity",
			Description = "Adjust the strength of the Liquid Glass effect.",
			MaxValue = 100,
			Default = math.floor((Settings.LiquidGlassIntensity or 1) * 100 + 0.5),
			Tab = Info.Tab,
			Callback = function(Value)
				Options:SetSetting("LiquidGlassIntensity", Value / 100)
			end,
		})

		Options:AddSlider({
			Title = "UI Transparency",
			Description = "Adjust the transparency of the window.",
			MaxValue = 1,
			AllowDecimals = true,
			Default = Setup.Transparency,
			Tab = Info.Tab,
			Callback = function(Value)
				Options:SetSetting("Transparency", Value)
			end,
		})
	end

	--// Kept for compatibility: Liquid Glass controls only
	function Options:AddLiquidGlassSettings(Info: { Tab: Instance })
		Options:AddToggle({
			Title = "Liquid Glass",
			Description = "Frosted glass surface with water-droplet highlights. Best used together with UI Blur.",
			Default = GlassEnabled,
			Tab = Info.Tab,
			Callback = function(Value)
				Options:SetSetting("LiquidGlass", Value)
			end,
		})

		Options:AddSlider({
			Title = "Glass Intensity",
			Description = "Adjust the strength of the Liquid Glass effect.",
			MaxValue = 100,
			Default = math.floor((Settings.LiquidGlassIntensity or 1) * 100 + 0.5),
			Tab = Info.Tab,
			Callback = function(Value)
				Options:SetSetting("LiquidGlassIntensity", Value / 100)
			end,
		})
	end

	local Themes = {
		Names = {	
			["Paragraph"] = function(Label)
				if Label:IsA("TextButton") then
					Label.BackgroundColor3 = Color(Theme.Component, 5, "Dark");
				end
			end,

			["Title"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Description"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Description
				end
			end,

			["Section"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Options"] = function(Label)
				if Label:IsA("TextLabel") and Label.Parent.Name == "Main" then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Notification"] = function(Label)
				if Label:IsA("CanvasGroup") then
					Label.BackgroundColor3 = Theme.Primary
					Label.UIStroke.Color = Theme.Outline
				end
			end,

			["TextLabel"] = function(Label)
				if Label:IsA("TextLabel") and Label.Parent:FindFirstChild("List") then
					Label.TextColor3 = Theme.Tab
				end
			end,

			["Main"] = function(Label)
				if Label:IsA("Frame") then

					if Label.Parent == Window then
						Label.BackgroundColor3 = Theme.Secondary
					elseif Label.Parent:FindFirstChild("Value") then
						local Toggle = Label.Parent.Value 
						local Circle = Label:FindFirstChild("Circle")

						if not Toggle.Value then
							Label.BackgroundColor3 = Theme.Interactables
							Label.Circle.BackgroundColor3 = Theme.Primary
						end
					else
						Label.BackgroundColor3 = Theme.Interactables
					end
				elseif Label:FindFirstChild("Padding") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Amount"] = function(Label)
				if Label:IsA("Frame") then
					Label.BackgroundColor3 = Theme.Interactables
				end
			end,

			["Slide"] = function(Label)
				if Label:IsA("Frame") then
					Label.BackgroundColor3 = Theme.Interactables
				end
			end,

			["Input"] = function(Label)
				if Label:IsA("TextLabel") then
					Label.TextColor3 = Theme.Title
				elseif Label:FindFirstChild("Labels") then
					Label.BackgroundColor3 = Theme.Component
				elseif Label:IsA("TextBox") and Label.Parent.Name == "Main" then
					Label.TextColor3 = Theme.Title
				end
			end,

			["Outline"] = function(Stroke)
				if Stroke:IsA("UIStroke") then
					Stroke.Color = Theme.Outline
				end
			end,

			["DropdownExample"] = function(Label)
				Label.BackgroundColor3 = Theme.Secondary
			end,

			["Underline"] = function(Label)
				if Label:IsA("Frame") then
					Label.BackgroundColor3 = Theme.Outline
				end
			end,
		},

		Classes = {
			["ImageLabel"] = function(Label)
				if Label.Image ~= "rbxassetid://6644618143" then
					Label.ImageColor3 = Theme.Icon
				end
			end,

			["TextLabel"] = function(Label)
				if Label:FindFirstChild("Padding") then
					Label.TextColor3 = Theme.Title
				end
			end,

			["TextButton"] = function(Label)
				if Label:FindFirstChild("Labels") then
					Label.BackgroundColor3 = Theme.Component
				end
			end,

			["ScrollingFrame"] = function(Label)
				Label.ScrollBarImageColor3 = Theme.Component
			end,
		},
	}

	function Options:SetTheme(Info)
		Theme = Info or Theme

		local IsLight = (Theme.Primary.R + Theme.Primary.G + Theme.Primary.B) / 3 > 0.6
		Setup.ThemeMode = IsLight and "Light" or "Dark"

		Window.BackgroundColor3 = Theme.Primary
		Holder.BackgroundColor3 = Theme.Secondary
		Window.UIStroke.Color = Theme.Shadow

		for Index, Descendant in next, Screen:GetDescendants() do
			local Name, Class =  Themes.Names[Descendant.Name],  Themes.Classes[Descendant.ClassName]

			if Name then
				Name(Descendant);
			elseif Class then
				Class(Descendant);
			end
		end

		Prompt:Refresh()

		if Glass then
			Glass:SetLight(IsLight)
		end
	end

	--// Changing Settings

	function Options:SetSetting(Setting, Value) --// Available settings - Size, Transparency, Blur, BlurIntensity, LiquidGlass, LiquidGlassIntensity, LiquidGlassTint, ShowButton, Theme, Keybind
		if Setting == "Size" then

			Setup.Size = FitSize(Value)
			Window.Size = Setup.Size

		elseif Setting == "Transparency" then

			Window.GroupTransparency = Value
			Setup.Transparency = Value
			Prompt:Refresh()

			for Index, Notification in next, Screen:GetDescendants() do
				if Notification:IsA("CanvasGroup") and Notification.Name == "Notification" then
					Notification.GroupTransparency = Value
				end
			end

		elseif Setting == "Blur" then

			SetBlur(Value)

		elseif Setting == "BlurIntensity" then

			Settings.BlurIntensity = Value
			if BlurObject then BlurObject:SetIntensity(Value) end
			SyncPrompt()

		elseif Setting == "LiquidGlass" then

			SetLiquidGlass(Value)

		elseif Setting == "LiquidGlassIntensity" then

			Settings.LiquidGlassIntensity = Value
			if Glass then Glass:SetIntensity(Value) end
			SyncPrompt()

		elseif Setting == "LiquidGlassTint" then

			Settings.LiquidGlassTint = Value
			if Glass then Glass:SetTint(Value) end
			SyncPrompt()

		elseif Setting == "ShowButton" then

			ShowPrompt = not not Value

			if not ShowPrompt then
				Prompt:Hide()
			elseif not Opened then
				Prompt:Show()
			end

		elseif Setting == "Theme" and typeof(Value) == "table" then

			Options:SetTheme(Value)

		elseif Setting == "Keybind" then

			Setup.Keybind = Value

		else
			warn("[UI LIB]: Tried to change a setting that doesn't exist or isn't available to change.")
		end
	end

	--// Window control
	function Options:Toggle()
		Toggle()
	end

	function Options:Hide()
		if Opened then Toggle() end
	end

	function Options:Show()
		if not Opened then Toggle() end
	end

	function Options:Destroy()
		KeybindConnection:Disconnect()

		if Glass then
			Glass:Destroy()
			Glass = nil
		end

		if BlurObject then
			BlurObject:Destroy()
			BlurObject = nil
		end

		Prompt:Destroy()
		Window:Destroy()
	end

	SetProperty(Window, { Size = Setup.Size, Visible = true, Parent = Screen });
	Animations:Open(Window, Settings.Transparency or 0)

	return Options
end

return Library
