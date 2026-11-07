--[[
	LiquidGlass.lua  -  Hiệu ứng "kính lỏng" (liquid glass) cho GuiObject trong Roblox

	Roblox không có khúc xạ thật, nên module này mô phỏng bằng nhiều lớp:
	  1. Tint        : lớp phủ màu kính, trong hơn ở dưới, đậm hơn ở trên
	  2. Depth       : tối nhẹ ở đáy cho cảm giác có độ dày
	  3. Specular    : mảng sáng cong ở góc trên trái (như ánh đèn phản chiếu)
	  4. Sheen       : vệt sáng chéo lướt ngang qua định kỳ
	  5. Rim + Glow  : viền sáng 2 đầu chéo, XOAY THEO CON TRỎ / NGÓN TAY
	                   (không có con trỏ thì tự xoay chậm) -> cảm giác kính phản chiếu ánh sáng

	Dùng chung với Blur.lua để có nền mờ phía sau (frosted).

	API:
	  local Glass = LiquidGlass.new(GuiObject, Config?)
	  Glass:Start() / Glass:Stop()          --// tự chạy theo target.Visible
	  Glass:SetIntensity(0..1.5)            --// độ mạnh của các lớp sáng
	  Glass:SetTint(Color3)
	  Glass:Destroy()

	Config = {
		Corner       = UDim,        --// bo góc (mặc định đọc từ UICorner của target)
		Tint         = Color3,      --// màu kính (mặc định trắng)
		Intensity    = 1,           --// độ mạnh hiệu ứng
		RimThickness = 1.5,         --// độ dày viền sáng
		Animate      = true,        --// vệt sheen chạy định kỳ
		FollowPointer= true,        --// viền xoay theo con trỏ
		ZIndex       = 20,
		Frames       = { {Frame, BackgroundTransparency}, ... }, --// các khung nền muốn làm trong suốt
	}
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LiquidGlass = {}
LiquidGlass.__index = LiquidGlass

--// ─────────────────────────── Helpers ───────────────────────────
local function make(Class: string, Props: { [string]: any }, Parent: Instance?)
	local Object = Instance.new(Class)
	for Key, Value in pairs(Props) do
		Object[Key] = Value
	end
	Object.Parent = Parent
	return Object
end

local function layerFrame(Name: string, Parent: Instance, Corner: UDim, Props: { [string]: any }?)
	local Frame = make("Frame", {
		Name = Name,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		Interactable = false,
		ZIndex = Parent.ZIndex,
	}, Parent)

	if Props then
		for Key, Value in pairs(Props) do
			Frame[Key] = Value
		end
	end

	make("UICorner", { CornerRadius = Corner }, Frame)
	return Frame
end

local function sequence(Intensity: number, Points: { { number } })
	local Keys = table.create(#Points)
	for Index, Point in ipairs(Points) do
		-- 1 = trong suốt hoàn toàn; Intensity kéo giá trị về phía trong suốt
		Keys[Index] = NumberSequenceKeypoint.new(Point[1], math.clamp(1 - (1 - Point[2]) * Intensity, 0, 1))
	end
	return NumberSequence.new(Keys)
end

-- Các điểm gốc của từng lớp (để SetIntensity dựng lại)
local Curves = {
	Tint = { { 0, 0.90 }, { 0.5, 0.945 }, { 1, 0.97 } },
	Depth = { { 0, 1 }, { 0.55, 1 }, { 1, 0.86 } },
	Specular = { { 0, 0.84 }, { 0.5, 0.94 }, { 1, 1 } },
	Blob = { { 0, 0.86 }, { 0.6, 0.96 }, { 1, 1 } },
	Sheen = { { 0, 1 }, { 0.40, 1 }, { 0.5, 0.88 }, { 0.60, 1 }, { 1, 1 } },
	Rim = { { 0, 0.05 }, { 0.30, 0.85 }, { 0.70, 0.85 }, { 1, 0.05 } },
	Glow = { { 0, 0.82 }, { 0.35, 1 }, { 0.65, 1 }, { 1, 0.82 } },
}

--// ─────────────────────────── Constructor ───────────────────────────
function LiquidGlass.new(target: GuiObject, config: { [string]: any }?)
	assert(typeof(target) == "Instance" and target:IsA("GuiObject"), "[LiquidGlass] target phải là GuiObject")
	config = config or {}

	local Existing = target:FindFirstChild("LiquidGlass")
	if Existing then
		Existing:Destroy()
	end

	local TargetCorner = target:FindFirstChildOfClass("UICorner")
	local Corner: UDim = config.Corner or (TargetCorner and TargetCorner.CornerRadius) or UDim.new(0, 12)
	local Rim = config.RimThickness or 1.5

	local self = setmetatable({
		target = target,
		_intensity = config.Intensity or 1,
		_animate = config.Animate ~= false,
		_follow = config.FollowPointer ~= false,
		_corner = Corner,
		_rimThickness = Rim,
		_angle = 45,
		_pointer = nil,
		_running = false,
		_conns = {},
		_restore = {},
		_layers = {},
	}, LiquidGlass)

	--// Container
	local Container = make("Frame", {
		Name = "LiquidGlass",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		Interactable = false,
		ClipsDescendants = true,
		ZIndex = config.ZIndex or 20,
	}, target)
	self.container = Container

	local Layers = self._layers
	local Intensity = self._intensity

	--// 1. Tint
	Layers.Tint = layerFrame("Tint", Container, Corner, {
		BackgroundColor3 = config.Tint or Color3.new(1, 1, 1),
	})
	Layers.TintGradient = make("UIGradient", {
		Rotation = 90,
		Transparency = sequence(Intensity, Curves.Tint),
	}, Layers.Tint)

	--// 2. Depth (đáy tối)
	Layers.Depth = layerFrame("Depth", Container, Corner, { BackgroundColor3 = Color3.new(0, 0, 0) })
	Layers.DepthGradient = make("UIGradient", {
		Rotation = 90,
		Transparency = sequence(Intensity, Curves.Depth),
	}, Layers.Depth)

	--// 3. Specular (nửa trên + mảng sáng cong góc trên trái)
	Layers.Specular = layerFrame("Specular", Container, Corner, { Size = UDim2.fromScale(1, 0.5) })
	Layers.SpecularGradient = make("UIGradient", {
		Rotation = 90,
		Transparency = sequence(Intensity, Curves.Specular),
	}, Layers.Specular)

	Layers.Blob = layerFrame("Blob", Container, UDim.new(1, 0), {
		Position = UDim2.fromScale(-0.18, -0.34),
		Size = UDim2.fromScale(0.78, 0.62),
		Rotation = -14,
	})
	Layers.BlobGradient = make("UIGradient", {
		Rotation = 60,
		Transparency = sequence(Intensity, Curves.Blob),
	}, Layers.Blob)

	--// 4. Sheen (vệt sáng chéo)
	Layers.Sheen = layerFrame("Sheen", Container, Corner)
	Layers.SheenGradient = make("UIGradient", {
		Rotation = 24,
		Offset = Vector2.new(-1, 0),
		Transparency = sequence(Intensity, Curves.Sheen),
	}, Layers.Sheen)

	--// 5. Glow (viền mờ bên trong) + Rim (viền sáng sắc nét)
	local function strokeLayer(Name: string, Thickness: number, Curve, ZOffset: number)
		local Inset = Thickness
		local Frame = make("Frame", {
			Name = Name,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -Inset * 2, 1, -Inset * 2),
			Active = false,
			Interactable = false,
			ZIndex = Container.ZIndex + ZOffset,
		}, Container)

		make("UICorner", {
			CornerRadius = UDim.new(Corner.Scale, math.max(Corner.Offset - Inset, 0)),
		}, Frame)

		local Stroke = make("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = Thickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
		}, Frame)

		local Gradient = make("UIGradient", {
			Rotation = self._angle,
			Transparency = sequence(Intensity, Curve),
		}, Stroke)

		return Frame, Gradient
	end

	Layers.Glow, Layers.GlowGradient = strokeLayer("Glow", Rim * 4, Curves.Glow, 0)
	Layers.Rim, Layers.RimGradient = strokeLayer("Rim", Rim, Curves.Rim, 1)

	--// Làm các khung nền trong suốt để thấy blur phía sau
	if config.Frames then
		for _, Entry in ipairs(config.Frames) do
			local Frame, Transparency = Entry[1], Entry[2]
			if typeof(Frame) == "Instance" and Frame:IsA("GuiObject") then
				table.insert(self._restore, { Frame, Frame.BackgroundTransparency })
				Frame.BackgroundTransparency = Transparency
			end
		end
	end

	--// Theo dõi con trỏ / ngón tay
	if self._follow then
		table.insert(self._conns, UserInputService.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				self._pointer = Vector2.new(Input.Position.X, Input.Position.Y)
			end
		end))
		table.insert(self._conns, UserInputService.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.Touch then
				self._pointer = Vector2.new(Input.Position.X, Input.Position.Y)
			end
		end))
	end

	--// Tự chạy / dừng theo Visible
	table.insert(self._conns, target:GetPropertyChangedSignal("Visible"):Connect(function()
		if target.Visible then
			self:Start()
		else
			self:Stop()
		end
	end))
	table.insert(self._conns, target.Destroying:Connect(function()
		self:Destroy()
	end))

	if target.Visible then
		self:Start()
	end

	return self
end

--// ─────────────────────────── Animation loop ───────────────────────────
function LiquidGlass:_setAngle(Angle: number)
	self._angle = Angle
	local Layers = self._layers
	Layers.RimGradient.Rotation = Angle
	Layers.GlowGradient.Rotation = Angle
end

function LiquidGlass:Start()
	if self._running or self._destroyed then return end
	self._running = true

	--// Viền xoay theo con trỏ (mượt, đi đường ngắn nhất)
	self._beat = RunService.Heartbeat:Connect(function(dt)
		local Target = self.target
		if not Target.Visible or Target.AbsoluteSize.X < 2 then return end

		local Goal
		local Pointer = self._pointer
		if self._follow and Pointer then
			local Center = Target.AbsolutePosition + Target.AbsoluteSize / 2
			Goal = math.deg(math.atan2(Pointer.Y - Center.Y, Pointer.X - Center.X))
		else
			Goal = self._angle + 14 * dt -- không có con trỏ: tự xoay rất chậm
		end

		local Delta = (Goal - self._angle + 180) % 360 - 180
		self:_setAngle(self._angle + Delta * math.min(dt * 7, 1))
	end)

	--// Vệt sheen quét qua định kỳ
	if self._animate then
		local Token = {}
		self._sheenToken = Token

		task.spawn(function()
			local Gradient = self._layers.SheenGradient
			local Rng = Random.new()

			while self._sheenToken == Token and Gradient.Parent do
				Gradient.Offset = Vector2.new(-1, 0)
				local Tween = TweenService:Create(
					Gradient,
					TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Offset = Vector2.new(1, 0) }
				)
				Tween:Play()
				Tween.Completed:Wait()

				local Wait = 3.5 + Rng:NextNumber() * 3
				local Elapsed = 0
				while Elapsed < Wait and self._sheenToken == Token do
					Elapsed += task.wait(0.25)
				end
			end
		end)
	end
end

function LiquidGlass:Stop()
	if not self._running then return end
	self._running = false
	self._sheenToken = nil

	if self._beat then
		self._beat:Disconnect()
		self._beat = nil
	end
end

--// ─────────────────────────── Public setters ───────────────────────────
function LiquidGlass:SetIntensity(Value: number)
	self._intensity = math.clamp(Value, 0, 1.5)
	local Layers = self._layers

	Layers.TintGradient.Transparency = sequence(self._intensity, Curves.Tint)
	Layers.DepthGradient.Transparency = sequence(self._intensity, Curves.Depth)
	Layers.SpecularGradient.Transparency = sequence(self._intensity, Curves.Specular)
	Layers.BlobGradient.Transparency = sequence(self._intensity, Curves.Blob)
	Layers.SheenGradient.Transparency = sequence(self._intensity, Curves.Sheen)
	Layers.RimGradient.Transparency = sequence(self._intensity, Curves.Rim)
	Layers.GlowGradient.Transparency = sequence(self._intensity, Curves.Glow)
end

function LiquidGlass:SetTint(Color: Color3)
	self._layers.Tint.BackgroundColor3 = Color
end

function LiquidGlass:SetVisible(Value: boolean)
	self.container.Visible = Value
	if Value then self:Start() else self:Stop() end
end

function LiquidGlass:Destroy()
	if self._destroyed then return end
	self:Stop()
	self._destroyed = true

	for _, Conn in ipairs(self._conns) do
		Conn:Disconnect()
	end
	table.clear(self._conns)

	for _, Entry in ipairs(self._restore) do
		if Entry[1] and Entry[1].Parent then
			Entry[1].BackgroundTransparency = Entry[2]
		end
	end
	table.clear(self._restore)

	if self.container then
		self.container:Destroy()
	end
end

return LiquidGlass
