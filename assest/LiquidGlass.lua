local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

local Counter = 0
local White = Color3.new(1, 1, 1)
local DefaultTint = Color3.fromRGB(190, 225, 255)

--// Helpers

local function New(Class, Properties, Parent)
	local Object = Instance.new(Class)

	for Property, Value in next, Properties do
		Object[Property] = Value
	end

	if Object:IsA("GuiObject") then
		pcall(function()
			Object.Interactable = false --// Không chặn chuột của UI bên dưới
		end)
	end

	Object.Parent = Parent
	return Object
end

local function Inset(Radius, Amount)
	return UDim.new(Radius.Scale, math.max(Radius.Offset - Amount, 0))
end

local function Fade(Base, Intensity)
	return math.clamp(1 - (1 - Base) * Intensity, 0, 1)
end

local function Sequence(Points, Intensity)
	local Keys = table.create(#Points)

	for Index, Point in ipairs(Points) do
		Keys[Index] = NumberSequenceKeypoint.new(Point[1], Fade(Point[2], Intensity))
	end

	return NumberSequence.new(Keys)
end

--// Builders

function LiquidGlass:_frame(Name, Parent, Properties)
	Properties.Name = Name
	Properties.BorderSizePixel = 0
	Properties.BackgroundColor3 = Properties.BackgroundColor3 or White

	if Properties.BackgroundTransparency == nil then
		Properties.BackgroundTransparency = 1
	end

	return New("Frame", Properties, Parent)
end

function LiquidGlass:_gradient(Parent, Rotation, Points)
	local Gradient = New("UIGradient", {
		Rotation = Rotation,
		Transparency = Sequence(Points, self.Intensity),
	}, Parent)

	table.insert(self.Gradients, { Gradient, Points })
	return Gradient
end

function LiquidGlass:_fade(Object, Base)
	Object.BackgroundTransparency = Fade(Base, self.Intensity)
	table.insert(self.Fades, { Object, Base })
end

function LiquidGlass:_ring(Name, Distance, Thickness, Rotation, Points)
	--// UIStroke vẽ ra phía NGOÀI frame, nên thụt vào đúng bằng độ dày để không bị CanvasGroup cắt
	local Ring = self:_frame(Name, self.Front, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -Distance * 2, 1, -Distance * 2),
	})

	New("UICorner", { CornerRadius = Inset(self.Radius, Distance) }, Ring)

	local Stroke = New("UIStroke", {
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
end

function LiquidGlass:_build()
	local Window = self.Window

	local Back = self:_frame("LG_Back", Window, {
		Size = UDim2.fromScale(1, 1), ZIndex = -5, Visible = false,
	})

	local Front = self:_frame("LG_Front", Window, {
		Size = UDim2.fromScale(1, 1), ZIndex = 10, Visible = false,
	})

	self.Back, self.Front = Back, Front

	--// [Back] thân kính: màu xanh nhạt + chiều sâu
	local Body = self:_frame("LG_Body", Back, {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0,
	})
	New("UICorner", { CornerRadius = self.Radius }, Body)
	self.Body = Body
	self.BodyGradient = self:_gradient(Body, 135, { { 0, 0.78 }, { 0.5, 0.92 }, { 1, 0.82 } })

	local Depth = self:_frame("LG_Depth", Back, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 25, 60),
		BackgroundTransparency = 0,
	})
	New("UICorner", { CornerRadius = self.Radius }, Depth)
	self:_gradient(Depth, 90, { { 0, 1 }, { 0.55, 1 }, { 1, 0.86 } })

	--// [Front] viền dày của giọt nước
	self.LipGradient = self:_ring("LG_Lip", 8, 6, 45, {
		{ 0, 0.86 }, { 0.3, 0.97 }, { 0.55, 0.94 }, { 0.8, 0.97 }, { 1, 0.84 },
	})

	--// Viền sáng (sáng nhất ở góc trên-trái và dưới-phải)
	self.RimGradient = self:_ring("LG_Rim", 2, 2, 45, {
		{ 0, 0.08 }, { 0.35, 0.8 }, { 0.5, 0.92 }, { 0.65, 0.8 }, { 1, 0.08 },
	})

	--// Tán sắc ở mép (như nước / thủy tinh)
	self.DispA = self:_ring("LG_DispA", 4, 1, 45, { { 0, 0.45 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0.85 } })
	self.DispA.Color = ColorSequence.new(Color3.fromRGB(110, 220, 255))
	self.DispB = self:_ring("LG_DispB", 5, 1, 45, { { 0, 0.85 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0.45 } })
	self.DispB.Color = ColorSequence.new(Color3.fromRGB(255, 140, 210))

	--// Mảng sáng phía trên (độ cong của giọt)
	local Sheen = self:_frame("LG_Sheen", Front, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -12, 0.32, 0),
		BackgroundTransparency = 0,
	})
	New("UICorner", { CornerRadius = Inset(self.Radius, 6) }, Sheen)
	self:_gradient(Sheen, 90, { { 0, 0.84 }, { 1, 1 } })

	--// Vệt phản chiếu sắc nét
	local Spec = self:_frame("LG_Spec", Front, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.new(0.62, 0, 0, 5),
		BackgroundTransparency = 0,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, Spec)
	self:_gradient(Spec, 0, { { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } })
	self.Spec = Spec

	--// Đốm sáng nhỏ như hạt nước
	local DotA = self:_frame("LG_DotA", Front, {
		Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(7, 7),
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, DotA)
	self:_fade(DotA, 0.35)

	local DotC = self:_frame("LG_DotC", Front, {
		Position = UDim2.fromOffset(31, 11), Size = UDim2.fromOffset(3, 3),
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, DotC)
	self:_fade(DotC, 0.5)

	self.DotB = self:_frame("LG_DotB", Front, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -14),
		Size = UDim2.fromOffset(5, 5),
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, self.DotB)
	self:_fade(self.DotB, 0.55)

	--// Caustic ở đáy (ánh sáng hội tụ)
	self.Caustic = self:_frame("LG_Caustic", Front, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.62, 0, 1, -6),
		Size = UDim2.new(0.5, 0, 0, 6),
		BackgroundTransparency = 0,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, self.Caustic)
	self:_gradient(self.Caustic, 0, { { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } })

	--// Ánh sáng chạy theo chuột
	self.Glow = self:_frame("LG_Glow", Front, { Size = UDim2.fromScale(1, 1), Visible = false })
	self.Orbs = {}

	for _, Info in ipairs({ { 1, 0.97 }, { 0.72, 0.95 }, { 0.46, 0.93 }, { 0.24, 0.9 } }) do
		local Orb = self:_frame("LG_Orb", self.Glow, { AnchorPoint = Vector2.new(0.5, 0.5) })
		New("UICorner", { CornerRadius = UDim.new(1, 0) }, Orb)
		table.insert(self.Orbs, { Orb, Info[1], Info[2] })
	end

	--// Vệt sáng quét ngang
	self.Sweep = self:_frame("LG_Sweep", Front, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.2, 2),
		Rotation = 20,
		BackgroundTransparency = 0,
		Visible = false,
	})
	self:_gradient(self.Sweep, 0, { { 0, 1 }, { 0.5, 0.9 }, { 1, 1 } })

	self:_applyTint()
end

--// Constructor

function LiquidGlass.new(Window, Config)
	Config = Config or {}
	Counter += 1

	local Corner = Window:FindFirstChildOfClass("UICorner")

	local self = setmetatable({
		Window = Window,
		Intensity = math.clamp(Config.Intensity or 1, 0, 1.5),
		Tint = Config.Tint or DefaultTint,
		Animate = Config.Animate ~= false,
		Radius = Config.CornerRadius or (Corner and Corner.CornerRadius) or UDim.new(0, 12),

		Enabled = false,
		Destroyed = false,

		Gradients = {},
		Fades = {},
		Panels = {},

		Mouse = Players.LocalPlayer and Players.LocalPlayer:GetMouse(),

		_id = "LiquidGlass_" .. Counter .. "_" .. math.floor(os.clock() * 1000),
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

--// Panels (làm Window / Holder trong hơn để thấy lớp kính)

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

--// Render

function LiquidGlass:_step(Delta)
	local Window = self.Window

	if not Window or not Window:IsDescendantOf(game) then
		if self._seen then
			self:Destroy()
		end
		return
	end

	self._seen = true

	if not Window.Visible then
		return
	end

	local Size, Position = Window.AbsoluteSize, Window.AbsolutePosition
	if Size.X < 1 or Size.Y < 1 then
		return
	end

	if not self.Animate then
		return
	end

	local Time = os.clock() + self._phase
	local Mouse = self.Mouse
	local RelX, RelY = Size.X / 2, Size.Y / 2

	if Mouse then
		RelX, RelY = Mouse.X - Position.X, Mouse.Y - Position.Y
	end

	local Inside = Mouse ~= nil and RelX >= 0 and RelY >= 0 and RelX <= Size.X and RelY <= Size.Y
	local Smooth = 1 - math.exp(-Delta * 10)

	--// Hướng ánh sáng
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

	--// Chuyển động như nước
	self.Spec.Position = UDim2.new(0.5 + math.sin(Time * 0.45) * 0.05, 0, 0, 7)
	self.Caustic.Position = UDim2.new(0.62 + math.sin(Time * 0.6) * 0.08, 0, 1, -6)

	--// Ánh sáng theo chuột
	self._alpha += ((Inside and 1 or 0) - self._alpha) * (1 - math.exp(-Delta * 8))

	if self._alpha > 0.01 then
		if not self.Glow.Visible then
			self._gx, self._gy = RelX, RelY
			self.Glow.Visible = true
		end

		local Follow = 1 - math.exp(-Delta * 12)
		self._gx += (math.clamp(RelX, 0, Size.X) - self._gx) * Follow
		self._gy += (math.clamp(RelY, 0, Size.Y) - self._gy) * Follow

		local Diameter = math.clamp(math.max(Size.X, Size.Y) * 0.5, 140, 320)
		local Strength = self.Intensity * self._alpha

		for _, Orb in ipairs(self.Orbs) do
			local Side = Diameter * Orb[2]
			Orb[1].Size = UDim2.fromOffset(Side, Side)
			Orb[1].Position = UDim2.fromOffset(self._gx, self._gy)
			Orb[1].BackgroundTransparency = Fade(Orb[3], Strength)
		end
	elseif self.Glow.Visible then
		self.Glow.Visible = false
	end

	--// Vệt sáng quét (9 giây một lần)
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
	if self._bound then
		return
	end

	self._bound = true
	RunService:BindToRenderStep(self._id, Enum.RenderPriority.Last.Value, function(Delta)
		self:_step(Delta)
	end)
end

function LiquidGlass:_unbind()
	if not self._bound then
		return
	end

	self._bound = false
	pcall(function()
		RunService:UnbindFromRenderStep(self._id)
	end)
end

--// Public

function LiquidGlass:SetEnabled(Value)
	if self.Destroyed then
		return
	end

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
	if self.Destroyed or type(Value) ~= "number" then
		return
	end

	self.Intensity = math.clamp(Value, 0, 1.5)

	for _, Info in ipairs(self.Gradients) do
		Info[1].Transparency = Sequence(Info[2], self.Intensity)
	end

	for _, Info in ipairs(self.Fades) do
		Info[1].BackgroundTransparency = Fade(Info[2], self.Intensity)
	end

	if self.Enabled then
		self:_applyPanels(true)
	end
end

function LiquidGlass:SetTint(Value)
	if self.Destroyed or typeof(Value) ~= "Color3" then
		return
	end

	self.Tint = Value
	self:_applyTint()
end

function LiquidGlass:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Enabled = false
	self:_unbind()
	self:_applyPanels(false)

	pcall(function()
		self.Back:Destroy()
		self.Front:Destroy()
	end)
end

return LiquidGlass
