--// Hyko Suite — Ultra Anti-NPC (v6.1 ⇄ v6.2) + Server Hop + NPC Blocker
--// MAX-OPTIMIZED build · event-driven · distance-gated · watchdog re-freeze
--// Logic unchanged for user-facing features — internal freeze is stronger

--============================================================--
-- [0] EXECUTOR COMPATIBILITY LAYER
--============================================================--
local cloneref = cloneref or function(o) return o end
local function safeService(name)
	local ok, s = pcall(function() return cloneref(game:GetService(name)) end)
	if ok and s then return s end
	return game:GetService(name)
end

local Players          = safeService("Players")
local RunService       = safeService("RunService")
local UserInputService = safeService("UserInputService")
local TweenService     = safeService("TweenService")
local HttpService      = safeService("HttpService")
local TeleportService  = safeService("TeleportService")
local PhysicsService   = safeService("PhysicsService")

local LP      = Players.LocalPlayer
local PlaceId = game.PlaceId

local rawgetmt      = rawgetmetatable or (debug and debug.getmetatable) or getrawmetatable
local setreadonlyFn = setreadonly or make_writeable or (debug and debug.setreadonly)
local newcclosureFn = newcclosure or (function(f) return f end)
local getnamecallFn = getnamecallmethod or (function() return "" end)

local function httpGet(url)
	if syn and syn.request then
		local ok, res = pcall(syn.request, {Url = url, Method = "GET"})
		if ok and res and res.Body then return res.Body end
	end
	if request then
		local ok, res = pcall(request, {Url = url, Method = "GET"})
		if ok and res and res.Body then return res.Body end
	end
	if http_request then
		local ok, res = pcall(http_request, {Url = url, Method = "GET"})
		if ok and res and res.Body then return res.Body end
	end
	if http and http.request then
		local ok, res = pcall(http.request, {Url = url, Method = "GET"})
		if ok and res and res.Body then return res.Body end
	end
	if game.HttpGet then
		local ok, res = pcall(function() return game:HttpGet(url) end)
		if ok and type(res) == "string" then return res end
	end
	if game.HttpGetAsync then
		local ok, res = pcall(function() return game:HttpGetAsync(url) end)
		if ok and type(res) == "string" then return res end
	end
	return nil
end

local fireProxPrompt = fireproximityprompt
local function doFireProximityPrompt(prompt)
	if not prompt then return end
	if fireProxPrompt then pcall(fireProxPrompt, prompt); return end
	if prompt.InputHoldBegin and prompt.InputHoldEnd then
		pcall(function()
			prompt:InputHoldBegin(); task.wait(); prompt:InputHoldEnd()
		end)
	end
end

local Icons = {
	Close    = "rbxassetid://10747384394",
	Refresh  = "rbxassetid://10734933222",
	Server   = "rbxassetid://10734949856",
	Players  = "rbxassetid://10747373426",
	Teleport = "rbxassetid://10723434830",
	List     = "rbxassetid://10723433811",
	Hop      = "rbxassetid://10734923549",
	Auto     = "rbxassetid://10734933966",
	Search   = "rbxassetid://10734943674",
	Check    = "rbxassetid://10709790644",
	Settings = "rbxassetid://10734950309",
}

--============================================================--
-- [A] INPUT
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
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then d += Vector3.new(0, 0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then d += Vector3.new(0, 0, 1)  end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then d += Vector3.new(-1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then d += Vector3.new(1, 0, 0)  end
	return d
end

--============================================================--
-- [B] FAST LOOT
--============================================================--
local fastLootOn = true
local function fixPrompt(p)
	if p:IsA("ProximityPrompt") then pcall(function() p.HoldDuration = 0 end) end
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") then fixPrompt(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if fastLootOn and d:IsA("ProximityPrompt") then fixPrompt(d) end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or not fastLootOn then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	local c = LP.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local best, bestDist = nil, math.huge
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled then
			local par = d.Parent
			local pos
			if par and par:IsA("BasePart") then pos = par.Position
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
	if best then doFireProximityPrompt(best) end
end)

--============================================================--
-- [C] NAMECALL HOOK
--============================================================--
local blockRouse = true
local hookInstalled = false
local hookOk, hookErr = pcall(function()
	if not rawgetmt or not setreadonlyFn then error("executor missing metatable APIs") end
	local mt = rawgetmt(game)
	if not mt then error("no metatable") end
	local oldNC = mt.__namecall
	if not oldNC then error("no __namecall") end
	setreadonlyFn(mt, false)
	mt.__namecall = newcclosureFn(function(self, ...)
		local m = getnamecallFn()
		if blockRouse and m == "FireServer" and typeof(self) == "Instance" then
			local n = self.Name
			if n == "Rouse" or n == "ForestStrike" or n == "ForestHandoff"
			or n == "Alert" or n == "Wake" or n == "Chase" or n == "Detect"
			or n == "SpeedTollOffer" or n == "SpeedTollWarning" then
				return
			end
		end
		return oldNC(self, ...)
	end)
	setreadonlyFn(mt, true)
	hookInstalled = true
end)
if not hookOk then warn("[Hyko] Namecall hook skipped: " .. tostring(hookErr)) end

--============================================================--
-- [D] HELPERS
--============================================================--
local function mkCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius); c.Parent = parent; return c
end
local function mkStroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Transparency = transparency or 0
	s.Thickness = thickness or 1; s.Parent = parent; return s
end
local function safeDestroy(x) if x then pcall(function() x:Destroy() end) end end
local function disconnect(x)
	if x and typeof(x) == "RBXScriptConnection" then pcall(function() x:Disconnect() end) end
end

--============================================================--
-- [E] ANTI-NPC  — ULTRA FREEZE
--============================================================--
local antiMode      = "off"
local frozenNPCs    = {}        -- npc → data (đang frozen)
local playerChrs    = {}

local LOCK_RADIUS       = 600   -- chỉ CFrame-lock NPC trong bán kính này
local LOCK_RADIUS_SQ    = LOCK_RADIUS * LOCK_RADIUS
local CFrameLockRate    = 4      -- chạy mỗi N PreSimulation (4 ≈ 15Hz)

local function refreshPlayerChrs()
	playerChrs = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then playerChrs[pl.Character] = true end
	end
end
refreshPlayerChrs()
Players.PlayerAdded:Connect(function(pl) pl.CharacterAdded:Connect(refreshPlayerChrs) end)
Players.PlayerRemoving:Connect(refreshPlayerChrs)

local function isNPC(model)
	if not model or not model:IsA("Model") then return false end
	if playerChrs[model] then return false end
	if LP.Character == model then return false end
	return model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Danh sách state cần tắt (dùng chung 2 mode)
local DISABLED_STATES = {
	Enum.HumanoidStateType.Walking,
	Enum.HumanoidStateType.Running,
	Enum.HumanoidStateType.Jumping,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.GettingUp,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Landed,
	Enum.HumanoidStateType.Freefall,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Flying,
	Enum.HumanoidStateType.PlatformStanding,
	Enum.HumanoidStateType.Dead,
}

--=========== v6.1 (SOFT) ===========--
local function lockNPC_v61(npc)
	if frozenNPCs[npc] or not npc.Parent then return end
	local hrp = npc:FindFirstChild("HumanoidRootPart")
		or npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso")
	local hum = npc:FindFirstChildOfClass("Humanoid")
	local collider = npc:FindFirstChild("Collider")
	local data = { mode = "v61", collides = {}, alerts = {}, vfx = {} }

	if hrp and hrp:IsA("BasePart") then
		data.hrp = hrp; data.origAnchored = hrp.Anchored
		pcall(function() hrp:SetNetworkOwner(LP); hrp.Anchored = true end)
	end
	if hum then
		data.hum = hum; data.origWalk = hum.WalkSpeed; data.origJump = hum.JumpPower
		pcall(function()
			hum.WalkSpeed = 0; hum.JumpPower = 0
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	-- Chỉ lưu các part THỰC SỰ cần restore (CanCollide=true)
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			data.collides[d] = true
			pcall(function() d.CanCollide = false end)
		end
		if d:IsA("BillboardGui") then
			local nm = d.Name:lower()
			if nm:find("alert") or nm:find("warn") or nm:find("detect") then
				data.alerts[d] = d.Enabled; d.Enabled = false
			end
		end
		if d:IsA("Sound") and d.Playing then pcall(function() d:Stop() end) end
		if d:IsA("ParticleEmitter") and d.Enabled then
			local nm = d.Name:lower()
			if nm:find("alert") or nm:find("detect") or nm:find("wake")
				or nm:find("sleep") or nm:find("anger") then
				data.vfx[d] = d.Enabled; d.Enabled = false
			end
		end
	end

	if collider then
		data.collider = collider; data.origCollide = collider.CanCollide
		pcall(function() collider.CanCollide = false end)
	end

	frozenNPCs[npc] = data
end

--=========== v6.2 (HARD / ULTRA) ===========--
local function lockNPC_v62(npc)
	if frozenNPCs[npc] or not npc.Parent then return end
	local hrp = npc:FindFirstChild("HumanoidRootPart")
		or npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso")
	local hum = npc:FindFirstChildOfClass("Humanoid")
	local data = { mode = "v62", parts = {}, alerts = {}, vfx = {} }

	-- HRP: anchor + network owner + zero velocity
	if hrp and hrp:IsA("BasePart") then
		data.hrp = hrp; data.origAnchored = hrp.Anchored
		pcall(function()
			hrp:SetNetworkOwner(LP)
			hrp.Anchored = true
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end)
		data.lockedCF = hrp.CFrame
	end

	-- Humanoid: hard freeze
	if hum then
		data.hum = hum
		data.origWalk = hum.WalkSpeed
		data.origJump = hum.JumpPower
		data.origStateMachine = hum.EvaluateStateMachine
		pcall(function()
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.AutoRotate = false
			hum.PlatformStand = true
			hum.EvaluateStateMachine = false   -- ★ BIG: stops state-machine from driving motion
			hum:ChangeState(Enum.HumanoidStateType.Physics)
			hum:UnequipTools()
			for _, st in ipairs(DISABLED_STATES) do
				hum:SetStateEnabled(st, false)
			end
		end)
		pcall(function() hum.MoveDirection = Vector3.zero end)
	end

	-- Animator kill — animations won't try to move parts
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		data.animator = animator
		pcall(function() animator:Destroy() end)
	end

	-- Parts: disable collision/query/touch, remove TT, set Massless (giảm lực đẩy)
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") then
			local rec = { part = d }
			local needStore = false
			if d.CanCollide then rec.cc = true; needStore = true end
			if d.CanTouch then   rec.ct = true; needStore = true end
			if d.CanQuery then   rec.cq = true; needStore = true end
			if needStore then table.insert(data.parts, rec) end
			pcall(function()
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
			end)
		end
		if d:IsA("TouchTransmitter") then pcall(function() d:Destroy() end) end
		if d:IsA("BillboardGui") then
			data.alerts[d] = d.Enabled; d.Enabled = false
		end
		if d:IsA("Sound") and d.Playing then pcall(function() d:Stop() end) end
		if d:IsA("ParticleEmitter") and d.Enabled then
			local nm = d.Name:lower()
			if nm:find("alert") or nm:find("detect") or nm:find("wake")
				or nm:find("sleep") or nm:find("anger") then
				data.vfx[d] = d.Enabled; d.Enabled = false
			end
		end
	end

	-- Special parts
	for _, nm in ipairs({"Collider", "EggPoint", "CENTER", "HeadProxy", "Hitbox"}) do
		local pt = npc:FindFirstChild(nm)
		if pt and pt:IsA("BasePart") then
			if pt.CanCollide or pt.CanTouch or pt.CanQuery then
				table.insert(data.parts, {
					part = pt,
					cc = pt.CanCollide, ct = pt.CanTouch, cq = pt.CanQuery,
					tr = pt.Transparency,
				})
			end
			pcall(function()
				pt.CanCollide = false; pt.CanTouch = false
				pt.CanQuery = false; pt.Transparency = 1
				pt.Massless = true
			end)
		end
	end

	frozenNPCs[npc] = data
end

local function unlockNPC(npc)
	local data = frozenNPCs[npc]
	if not data then return end
	if data.hrp and data.hrp.Parent then
		pcall(function() data.hrp.Anchored = data.origAnchored or false end)
	end
	if data.hum and data.hum.Parent then
		pcall(function()
			data.hum.WalkSpeed = data.origWalk or 16
			data.hum.JumpPower = data.origJump or 50
			data.hum.PlatformStand = false
			data.hum.AutoRotate = true
			if data.origStateMachine ~= nil then
				data.hum.EvaluateStateMachine = data.origStateMachine
			end
		end)
	end
	for p in pairs(data.collides or {}) do
		if p and p.Parent then pcall(function() p.CanCollide = true end) end
	end
	if data.collider and data.collider.Parent then
		pcall(function() data.collider.CanCollide = data.origCollide ~= false end)
	end
	for _, rec in ipairs(data.parts or {}) do
		local p = rec.part
		if p and p.Parent then
			pcall(function()
				if rec.cc then p.CanCollide = true end
				if rec.ct then p.CanTouch = true end
				if rec.cq then p.CanQuery = true end
				if rec.tr ~= nil then p.Transparency = rec.tr end
			end)
		end
	end
	for d, en in pairs(data.alerts or {}) do
		if d and d.Parent then d.Enabled = en end
	end
	for d, en in pairs(data.vfx or {}) do
		if d and d.Parent then d.Enabled = en end
	end
	frozenNPCs[npc] = nil
end

local function unlockAll()
	for npc in pairs(frozenNPCs) do unlockNPC(npc) end
end

--=========== ASYNC LOCK QUEUE ===========--
local pendingLocks = setmetatable({}, {__mode = "k"})
local function tryLockNPC(npc, mode)
	if frozenNPCs[npc] or pendingLocks[npc] then return end
	if not npc.Parent then return end
	pendingLocks[npc] = true
	task.defer(function()
		pcall(function()
			if mode == "v61" then lockNPC_v61(npc) else lockNPC_v62(npc) end
		end)
		pendingLocks[npc] = nil
	end)
end

--=========== CFrame LOCK (PreSimulation, distance-gated) ===========--
local psCounter = 0
local cachedMyRoot = nil

local function updateMyRoot()
	local c = LP.Character
	cachedMyRoot = c and c:FindFirstChild("HumanoidRootPart")
end
updateMyRoot()

RunService.PreSimulation:Connect(function()
	if next(frozenNPCs) == nil then return end
	psCounter = (psCounter + 1) % CFrameLockRate
	if psCounter ~= 0 then return end

	local myRoot = cachedMyRoot
	if not myRoot or not myRoot.Parent then
		updateMyRoot()
		myRoot = cachedMyRoot
	end
	local mx, my, mz = 0, 0, 0
	if myRoot then
		local mp = myRoot.Position
		mx, my, mz = mp.X, mp.Y, mp.Z
	end

	for npc, data in pairs(frozenNPCs) do
		local hrp = data.hrp
		if not npc.Parent or not hrp or not hrp.Parent then
			frozenNPCs[npc] = nil
		else
			-- distance gate: chỉ lock NPC gần player
			local lockIt = true
			if myRoot then
				local p = hrp.Position
				local dx, dy, dz = p.X - mx, p.Y - my, p.Z - mz
				if dx*dx + dy*dy + dz*dz > LOCK_RADIUS_SQ then
					lockIt = false
				end
			end
			if lockIt then
				hrp.CFrame = data.lockedCF
				hrp.AssemblyLinearVelocity  = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end)

--=========== NPC DETECTION (event-driven) ===========--
workspace.DescendantAdded:Connect(function(inst)
	if antiMode == "off" then return end
	if not inst:IsA("Model") then return end
	task.defer(function()
		if antiMode == "off" then return end
		if isNPC(inst) then tryLockNPC(inst, antiMode) end
	end)
end)

-- Backstop scan: 3s/lần (thay vì 0.1s) — bắt NPC spawn trước khi bật mode
local function scanAndLockAll()
	refreshPlayerChrs()
	local mode = antiMode
	if mode == "off" then return end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and not frozenNPCs[obj] and isNPC(obj) then
			tryLockNPC(obj, mode)
		end
	end
end

--=========== WATCHDOG — re-freeze nếu bị script khác phá ===========--
task.spawn(function()
	while task.wait(1.2) do
		if antiMode == "off" then continue end
		for npc, data in pairs(frozenNPCs) do
			if not npc.Parent then
				frozenNPCs[npc] = nil
			else
				local hum = data.hum
				if hum and hum.Parent then
					if hum.WalkSpeed > 0 then hum.WalkSpeed = 0 end
					if hum.JumpPower > 0 then hum.JumpPower = 0 end
					if hum.EvaluateStateMachine then
						pcall(function() hum.EvaluateStateMachine = false end)
					end
				end
				local hrp = data.hrp
				if hrp and hrp.Parent and not hrp.Anchored then
					pcall(function()
						hrp.Anchored = true
						hrp.AssemblyLinearVelocity = Vector3.zero
						hrp.AssemblyAngularVelocity = Vector3.zero
					end)
				end
			end
		end
	end
end)

--============================================================--
-- [E2] NPC BLOCKER
--============================================================--
local BLOCKER_GROUP = "HykoNPCBlocker"
local PLAYER_GROUP  = "HykoPlayerParts"
pcall(function() PhysicsService:RegisterCollisionGroup(BLOCKER_GROUP) end)
pcall(function() PhysicsService:RegisterCollisionGroup(PLAYER_GROUP) end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(BLOCKER_GROUP, PLAYER_GROUP, false)
end)

local blockerSize = 18
local blockerPart = nil

local function tagAllPlayerParts()
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		if c then
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") and d.CollisionGroup ~= PLAYER_GROUP then
					pcall(function() d.CollisionGroup = PLAYER_GROUP end)
				end
			end
		end
	end
end

local function ensureBlocker()
	if blockerPart and blockerPart.Parent then return blockerPart end
	local p = Instance.new("Part")
	p.Name = "HykoNPCBlocker"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(blockerSize, blockerSize, blockerSize)
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = true
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Massless = true
	p.CollisionGroup = BLOCKER_GROUP
	p.Parent = workspace
	blockerPart = p
	return p
end

local function removeBlocker()
	if blockerPart then pcall(function() blockerPart:Destroy() end) end
	blockerPart = nil
end

local function updateBlocker()
	if antiMode ~= "v62" then removeBlocker(); return end
	local c = LP.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then removeBlocker(); return end
	local p = ensureBlocker()
	if p.Size.X ~= blockerSize then
		p.Size = Vector3.new(blockerSize, blockerSize, blockerSize)
	end
	p.CFrame = CFrame.new(hrp.Position)
end

local function applyPlayerNoTouch()
	if antiMode ~= "v62" then return end
	local c = LP.Character
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			pcall(function() p.CanTouch = false end)
		end
	end
end

--============================================================--
-- [F] INVISIBLE
--============================================================--
local invisOn = false
local function setInvis(on)
	local c = LP.Character
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = on and 1 or 0
		elseif p:IsA("Decal") then
			p.Transparency = on and 1 or 0
		end
	end
end

--============================================================--
-- [G] ESP
--============================================================--
local espOn = false
local ESP_MAX_DISTANCE = 5000
local ESP_UPDATE_INTERVAL = 0.25
local espEntries = {}
local espConnections = {}
local espFolder = Instance.new("Folder")
espFolder.Name = "HykoESP"
espFolder.Parent = workspace

local TC = {
	accent = Color3.fromRGB(10, 132, 255),
	text   = Color3.fromRGB(23, 26, 33),
	sub    = Color3.fromRGB(138, 144, 158),
	green  = Color3.fromRGB(48, 209, 88),
	amber  = Color3.fromRGB(255, 159, 10),
	red    = Color3.fromRGB(255, 69, 58),
	cardBg = Color3.fromRGB(255, 255, 255),
	cardStroke = Color3.fromRGB(230, 233, 240),
}

local function getRootHum(char)
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum  = char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return root, hum end
end

local makeESP, removeESP, updateESPEntry, bindPlayerESP

makeESP = function(plr)
	if not espOn or plr == LP then return end
	local char = plr.Character
	local root, hum = getRootHum(char)
	if not root then return end
	local old = espEntries[plr]
	if old and old.character == char then return end
	if old then safeDestroy(old.highlight); safeDestroy(old.billboard) end

	local highlight = Instance.new("Highlight")
	highlight.Adornee = char
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 0.92
	highlight.OutlineTransparency = 0.15
	highlight.FillColor = TC.accent
	highlight.OutlineColor = TC.accent
	highlight.Parent = espFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = ESP_MAX_DISTANCE
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffset = Vector3.new(0, 3.1, 0)
	billboard.Parent = espFolder

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = TC.cardBg
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.Parent = billboard
	mkCorner(card, 8)
	mkStroke(card, TC.cardStroke, 0.35, 1)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, 6)
	nameLabel.Size = UDim2.new(1, -20, 0, 16)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = TC.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = plr.DisplayName
	nameLabel.Parent = card

	local distLabel = Instance.new("TextLabel")
	distLabel.BackgroundTransparency = 1
	distLabel.Position = UDim2.fromOffset(12, 25)
	distLabel.Size = UDim2.fromOffset(42, 12)
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextSize = 9
	distLabel.TextColor3 = TC.sub
	distLabel.TextXAlignment = Enum.TextXAlignment.Left
	distLabel.Text = "-- m"
	distLabel.Parent = card

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(1, -78, 0, 28)
	barBg.Size = UDim2.fromOffset(58, 4)
	barBg.BackgroundColor3 = Color3.fromRGB(232, 235, 240)
	barBg.BorderSizePixel = 0
	barBg.Parent = card
	mkCorner(barBg, 2)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = TC.green
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	mkCorner(barFill, 2)

	local hpLabel = Instance.new("TextLabel")
	hpLabel.BackgroundTransparency = 1
	hpLabel.Position = UDim2.new(1, -78, 0, 12)
	hpLabel.Size = UDim2.fromOffset(58, 12)
	hpLabel.Font = Enum.Font.Gotham
	hpLabel.TextSize = 8
	hpLabel.TextColor3 = TC.sub
	hpLabel.TextXAlignment = Enum.TextXAlignment.Right
	hpLabel.Text = "100%"
	hpLabel.Parent = card

	espEntries[plr] = {
		player = plr, character = char, root = root, hum = hum,
		highlight = highlight, billboard = billboard,
		nameLabel = nameLabel, distLabel = distLabel,
		barFill = barFill, hpLabel = hpLabel,
	}
end

removeESP = function(plr)
	local e = espEntries[plr]
	if not e then return end
	safeDestroy(e.highlight)
	safeDestroy(e.billboard)
	espEntries[plr] = nil
end

updateESPEntry = function(e, myRoot)
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
	e.nameLabel.Text = plr.DisplayName
	local distance = myRoot and (myRoot.Position - root.Position).Magnitude or 0
	local visible  = distance <= ESP_MAX_DISTANCE
	e.highlight.Enabled = visible
	e.billboard.Enabled = visible
	local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	e.distLabel.Text = string.format("%dm", math.floor(distance + 0.5))
	e.hpLabel.Text   = string.format("%d%%", math.floor(hp * 100 + 0.5))
	local col
	if hp > 0.6 then col = TC.green
	elseif hp > 0.3 then col = TC.amber
	else col = TC.red end
	e.barFill.BackgroundColor3 = col
	e.barFill.Size = UDim2.fromScale(hp, 1)
end

bindPlayerESP = function(plr)
	if plr == LP then return end
	disconnect(espConnections[plr])
	espConnections[plr] = plr.CharacterAdded:Connect(function()
		task.wait(0.15)
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
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then makeESP(plr) end
	end
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
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LP then
					local e = espEntries[plr]
					if e then updateESPEntry(e, myRoot) else makeESP(plr) end
				end
			end
		end
	end
end)

--============================================================--
-- [H] UI
--============================================================--
local PlayerGui = LP:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:FindFirstChild("HykoGui")
if not ScreenGui then
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "HykoGui"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui
end
local oldUI = ScreenGui:FindFirstChild("HykoWindow")
if oldUI then oldUI:Destroy() end
local oldShadow = ScreenGui:FindFirstChild("HykoShadow")
if oldShadow then oldShadow:Destroy() end

local P = {
	bgTop      = Color3.fromRGB(252, 253, 255),
	card       = Color3.fromRGB(255, 255, 255),
	cardSoft   = Color3.fromRGB(246, 248, 252),
	border     = Color3.fromRGB(228, 231, 238),
	borderSoft = Color3.fromRGB(237, 240, 245),
	text       = Color3.fromRGB(23, 26, 33),
	sub        = Color3.fromRGB(138, 144, 158),
	dim        = Color3.fromRGB(180, 186, 198),
	accent     = Color3.fromRGB(10, 132, 255),
	accentSoft = Color3.fromRGB(230, 241, 255),
	green      = Color3.fromRGB(48, 209, 88),
	greenSoft  = Color3.fromRGB(228, 249, 233),
	amber      = Color3.fromRGB(255, 159, 10),
	amberSoft  = Color3.fromRGB(255, 245, 224),
	red        = Color3.fromRGB(255, 69, 58),
	redSoft    = Color3.fromRGB(255, 235, 232),
	purple     = Color3.fromRGB(140, 90, 255),
	purpleSoft = Color3.fromRGB(240, 233, 255),
	off        = Color3.fromRGB(210, 214, 220),
}

local WINDOW_W      = 340
local WINDOW_H      = 600
local WINDOW_H_MINI = 64
local SHADOW_PAD    = 8

local Shadow = Instance.new("Frame", ScreenGui)
Shadow.Name = "HykoShadow"
Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Shadow.BackgroundTransparency = 0.85
Shadow.BorderSizePixel = 0
Shadow.ZIndex = 1
mkCorner(Shadow, 20)

local Window = Instance.new("Frame", ScreenGui)
Window.Name = "HykoWindow"
Window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
Window.Position = UDim2.new(0, 20, 0.5, -WINDOW_H/2)
Window.BackgroundColor3 = P.bgTop
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
Window.ZIndex = 2
mkCorner(Window, 14)
mkStroke(Window, P.border, 0.2, 1)

local function syncShadow()
	Shadow.Position = UDim2.new(
		Window.Position.X.Scale, Window.Position.X.Offset - SHADOW_PAD,
		Window.Position.Y.Scale, Window.Position.Y.Offset - SHADOW_PAD
	)
	Shadow.Size = UDim2.new(
		Window.Size.X.Scale, Window.Size.X.Offset + SHADOW_PAD * 2,
		Window.Size.Y.Scale, Window.Size.Y.Offset + SHADOW_PAD * 2
	)
end
Window:GetPropertyChangedSignal("Position"):Connect(syncShadow)
Window:GetPropertyChangedSignal("Size"):Connect(syncShadow)
Window:GetPropertyChangedSignal("Visible"):Connect(function()
	Shadow.Visible = Window.Visible
end)
syncShadow()

--================= HEADER =================
local header = Instance.new("Frame", Window)
header.Size = UDim2.new(1, 0, 0, 60)
header.BackgroundTransparency = 1
header.ZIndex = 3

local avatarWrap = Instance.new("Frame", header)
avatarWrap.Size = UDim2.fromOffset(36, 36)
avatarWrap.Position = UDim2.fromOffset(16, 12)
avatarWrap.BackgroundColor3 = P.accentSoft
avatarWrap.BorderSizePixel = 0
avatarWrap.ZIndex = 4
mkCorner(avatarWrap, 18)
mkStroke(avatarWrap, P.border, 0.4, 1)

local avatar = Instance.new("ImageLabel", avatarWrap)
avatar.Size = UDim2.fromScale(1, 1)
avatar.BackgroundTransparency = 1
avatar.Image = "rbxassetid://14780540796"
avatar.ZIndex = 5
mkCorner(avatar, 18)

task.spawn(function()
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(LP.UserId,
			Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and url then avatar.Image = url end
end)

local statusDot = Instance.new("Frame", header)
statusDot.Size = UDim2.fromOffset(10, 10)
statusDot.Position = UDim2.fromOffset(44, 38)
statusDot.BackgroundColor3 = P.green
statusDot.BorderSizePixel = 0
statusDot.ZIndex = 6
mkCorner(statusDot, 5)
mkStroke(statusDot, Color3.fromRGB(255,255,255), 0, 2)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -150, 0, 18)
title.Position = UDim2.fromOffset(62, 12)
title.BackgroundTransparency = 1
title.Text = "Hello, " .. (LP.DisplayName or LP.Name)
title.TextColor3 = P.text
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTruncate = Enum.TextTruncate.AtEnd
title.ZIndex = 4

local subtitle = Instance.new("TextLabel", header)
subtitle.Size = UDim2.new(1, -150, 0, 12)
subtitle.Position = UDim2.fromOffset(62, 31)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Hyko Suite"
subtitle.TextColor3 = P.sub
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 4

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.fromOffset(28, 28)
minBtn.Position = UDim2.new(1, -68, 0, 16)
minBtn.BackgroundColor3 = P.cardSoft
minBtn.Text = ""
minBtn.AutoButtonColor = false
minBtn.ZIndex = 4
mkCorner(minBtn, 8)
mkStroke(minBtn, P.borderSoft, 0.3, 1)

local minBarH = Instance.new("Frame", minBtn)
minBarH.Size = UDim2.fromOffset(11, 1.6)
minBarH.Position = UDim2.new(0.5, -5.5, 0.5, -0.8)
minBarH.BackgroundColor3 = P.sub
minBarH.BorderSizePixel = 0
minBarH.ZIndex = 5
mkCorner(minBarH, 1)

local minBarV = Instance.new("Frame", minBtn)
minBarV.Size = UDim2.fromOffset(1.6, 11)
minBarV.Position = UDim2.new(0.5, -0.8, 0.5, -5.5)
minBarV.BackgroundColor3 = P.sub
minBarV.BorderSizePixel = 0
minBarV.Visible = false
minBarV.ZIndex = 5
mkCorner(minBarV, 1)

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 16)
closeBtn.BackgroundColor3 = P.redSoft
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 4
mkCorner(closeBtn, 8)

local closeIcon = Instance.new("ImageLabel", closeBtn)
closeIcon.Size = UDim2.fromOffset(13, 13)
closeIcon.Position = UDim2.new(0.5, -6.5, 0.5, -6.5)
closeIcon.BackgroundTransparency = 1
closeIcon.Image = Icons.Close
closeIcon.ImageColor3 = P.red
closeIcon.ScaleType = Enum.ScaleType.Fit
closeIcon.ZIndex = 5

closeBtn.MouseButton1Click:Connect(function() Window.Visible = false end)

local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Window.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		local d = input.Position - dragStart
		Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local divider = Instance.new("Frame", Window)
divider.Size = UDim2.new(1, -32, 0, 1)
divider.Position = UDim2.fromOffset(16, 60)
divider.BackgroundColor3 = P.border
divider.BackgroundTransparency = 0.4
divider.BorderSizePixel = 0
divider.ZIndex = 3

--================= TABS =================
local TabBar = Instance.new("Frame", Window)
TabBar.Size = UDim2.new(1, -24, 0, 36)
TabBar.Position = UDim2.fromOffset(12, 74)
TabBar.BackgroundColor3 = P.cardSoft
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 3
mkCorner(TabBar, 10)
mkStroke(TabBar, P.borderSoft, 0.5, 1)

local tabIndicator = Instance.new("Frame", TabBar)
tabIndicator.Size = UDim2.new(0.5, -4, 1, -4)
tabIndicator.Position = UDim2.fromOffset(2, 2)
tabIndicator.BackgroundColor3 = P.card
tabIndicator.BorderSizePixel = 0
tabIndicator.ZIndex = 4
mkCorner(tabIndicator, 8)
mkStroke(tabIndicator, P.borderSoft, 0.2, 1)

local function makeTabButton(parent, text, iconId, xScale)
	local btn = Instance.new("TextButton", parent)
	btn.Size = UDim2.new(0.5, 0, 1, 0)
	btn.Position = UDim2.new(xScale, 0, 0, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 5

	local inner = Instance.new("Frame", btn)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromOffset(110, 16)
	inner.BackgroundTransparency = 1
	inner.ZIndex = 6

	local icon = Instance.new("ImageLabel", inner)
	icon.Size = UDim2.fromOffset(13, 13)
	icon.Position = UDim2.fromOffset(0, 1.5)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = P.sub
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 7

	local lbl = Instance.new("TextLabel", inner)
	lbl.Position = UDim2.fromOffset(19, 0)
	lbl.Size = UDim2.fromOffset(91, 16)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = P.sub
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 7

	return btn, icon, lbl
end

local MainTabBtn, mainTabIcon, mainTabLabel = makeTabButton(TabBar, "Dashboard", Icons.List, 0)
local HopTabBtn,  hopTabIcon,  hopTabLabel  = makeTabButton(TabBar, "Server Hop", Icons.Server, 0.5)

mainTabIcon.ImageColor3 = P.accent
mainTabLabel.TextColor3 = P.text

--================= CONTENT =================
local content = Instance.new("Frame", Window)
content.Size = UDim2.new(1, -24, 1, -132)
content.Position = UDim2.fromOffset(12, 118)
content.BackgroundTransparency = 1
content.ZIndex = 3

local MainContent = Instance.new("Frame", content)
MainContent.Size = UDim2.fromScale(1, 1)
MainContent.BackgroundTransparency = 1
MainContent.ZIndex = 4

local HopContent = Instance.new("Frame", content)
HopContent.Size = UDim2.fromScale(1, 1)
HopContent.BackgroundTransparency = 1
HopContent.ZIndex = 4
HopContent.Visible = false

local function switchTab(tab)
	if tab == "main" then
		MainContent.Visible = true; HopContent.Visible = false
		mainTabIcon.ImageColor3 = P.accent; mainTabLabel.TextColor3 = P.text
		hopTabIcon.ImageColor3 = P.sub; hopTabLabel.TextColor3 = P.sub
		TweenService:Create(tabIndicator, TweenInfo.new(0.22,
			Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(2, 2)
		}):Play()
	else
		MainContent.Visible = false; HopContent.Visible = true
		mainTabIcon.ImageColor3 = P.sub; mainTabLabel.TextColor3 = P.sub
		hopTabIcon.ImageColor3 = P.accent; hopTabLabel.TextColor3 = P.text
		TweenService:Create(tabIndicator, TweenInfo.new(0.22,
			Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 2, 0, 2)
		}):Play()
	end
end
MainTabBtn.MouseButton1Click:Connect(function() switchTab("main") end)
HopTabBtn.MouseButton1Click:Connect(function() switchTab("hop") end)

--================= MINIMIZE =================
local isMinimized = false
minBtn.MouseButton1Click:Connect(function()
	if isMinimized then
		isMinimized = false; minBarV.Visible = false
		local tw = TweenService:Create(Window, TweenInfo.new(0.24,
			Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
		})
		tw:Play()
		tw.Completed:Connect(function()
			if not isMinimized then
				TabBar.Visible = true; content.Visible = true; divider.Visible = true
			end
		end)
	else
		isMinimized = true; minBarV.Visible = true
		TabBar.Visible = false; content.Visible = false; divider.Visible = false
		TweenService:Create(Window, TweenInfo.new(0.24,
			Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(WINDOW_W, WINDOW_H_MINI)
		}):Play()
	end
end)

--============================================================--
-- [I] UI BUILDERS
--============================================================--
local ROW_H = 34
local BADGE = 22
local LABEL_X = 48

local function makeCard(parent, yPos, height)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(1, 0, 0, height)
	card.Position = UDim2.fromOffset(0, yPos)
	card.BackgroundColor3 = P.card
	card.BorderSizePixel = 0
	card.ZIndex = 4
	mkCorner(card, 10)
	mkStroke(card, P.borderSoft, 0.25, 1)
	return card
end

local function makeIconBadge(parent, iconId, bgColor, iconColor, x, y, size)
	size = size or BADGE
	local badge = Instance.new("Frame", parent)
	badge.Size = UDim2.fromOffset(size, size)
	badge.Position = UDim2.fromOffset(x, y)
	badge.BackgroundColor3 = bgColor
	badge.BorderSizePixel = 0
	badge.ZIndex = 5
	mkCorner(badge, math.floor(size * 0.32))
	local is = size - 8
	local icon = Instance.new("ImageLabel", badge)
	icon.Size = UDim2.fromOffset(is, is)
	icon.Position = UDim2.new(0.5, -is/2, 0.5, -is/2)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = iconColor
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 6
	return badge, icon
end

local function makeToggle(card, name, defaultState, yOffset, iconId, badgeBg, iconColor, callback)
	local badgeY = yOffset + (ROW_H - BADGE) / 2
	makeIconBadge(card, iconId, badgeBg, iconColor, 14, badgeY, BADGE)

	local lbl = Instance.new("TextLabel", card)
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(LABEL_X, yOffset)
	lbl.Size = UDim2.new(1, -LABEL_X - 66, 0, ROW_H)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextColor3 = P.text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Text = name
	lbl.ZIndex = 5

	local sw = Instance.new("Frame", card)
	sw.Size = UDim2.fromOffset(38, 21)
	sw.Position = UDim2.new(1, -52, 0, yOffset + (ROW_H - 21) / 2)
	sw.BackgroundColor3 = defaultState and P.green or P.off
	sw.BorderSizePixel = 0
	sw.ZIndex = 5
	mkCorner(sw, 11)

	local thumb = Instance.new("Frame", sw)
	thumb.Size = UDim2.fromOffset(17, 17)
	thumb.Position = defaultState and UDim2.fromOffset(19, 2) or UDim2.fromOffset(2, 2)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.ZIndex = 6
	mkCorner(thumb, 9)

	local btn = Instance.new("TextButton", card)
	btn.Size = UDim2.new(1, 0, 0, ROW_H)
	btn.Position = UDim2.fromOffset(0, yOffset)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 7

	local state = defaultState
	local function applyState(s, fire)
		state = s
		TweenService:Create(sw, TweenInfo.new(0.2, Enum.EasingStyle.Quart),
			{BackgroundColor3 = state and P.green or P.off}):Play()
		TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Quart),
			{Position = state and UDim2.fromOffset(19, 2) or UDim2.fromOffset(2, 2)}):Play()
		if fire and callback then callback(state) end
	end
	btn.MouseButton1Click:Connect(function() applyState(not state, true) end)
	return {
		setState = function(s) applyState(s, false) end,
		getState = function() return state end,
	}
end

local function makeSlider(card, name, minVal, maxVal, defaultVal, yOffset,
	iconId, badgeBg, iconColor, callback)
	makeIconBadge(card, iconId, badgeBg, iconColor, 14, yOffset, BADGE)

	local lbl = Instance.new("TextLabel", card)
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(LABEL_X, yOffset)
	lbl.Size = UDim2.new(1, -LABEL_X - 60, 0, BADGE)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextColor3 = P.text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = name
	lbl.ZIndex = 5

	local valChip = Instance.new("Frame", card)
	valChip.Size = UDim2.fromOffset(46, 20)
	valChip.Position = UDim2.new(1, -60, 0, yOffset + 1)
	valChip.BackgroundColor3 = badgeBg
	valChip.BorderSizePixel = 0
	valChip.ZIndex = 5
	mkCorner(valChip, 6)

	local valLbl = Instance.new("TextLabel", valChip)
	valLbl.Size = UDim2.fromScale(1, 1)
	valLbl.BackgroundTransparency = 1
	valLbl.Font = Enum.Font.GothamBold
	valLbl.Text = tostring(defaultVal)
	valLbl.TextColor3 = iconColor
	valLbl.TextSize = 11
	valLbl.ZIndex = 6

	local track = Instance.new("TextButton", card)
	track.Size = UDim2.new(1, -28, 0, 4)
	track.Position = UDim2.fromOffset(14, yOffset + 34)
	track.BackgroundColor3 = P.borderSoft
	track.Text = ""
	track.AutoButtonColor = false
	track.ZIndex = 5
	mkCorner(track, 2)

	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
	fill.BackgroundColor3 = iconColor
	fill.BorderSizePixel = 0
	fill.ZIndex = 6
	mkCorner(fill, 2)

	local thumb = Instance.new("Frame", track)
	thumb.Size = UDim2.fromOffset(12, 12)
	thumb.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), -6, 0.5, -6)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.ZIndex = 7
	mkCorner(thumb, 6)
	mkStroke(thumb, P.border, 0.2, 1)

	local draggingSlider = false
	local function updateSlider(input)
		local tw = track.AbsoluteSize.X
		local tx = track.AbsolutePosition.X
		local pct = math.clamp((input.Position.X - tx) / tw, 0, 1)
		local val = math.floor(minVal + pct * (maxVal - minVal))
		fill.Size = UDim2.new(pct, 0, 1, 0)
		thumb.Position = UDim2.new(pct, -6, 0.5, -6)
		valLbl.Text = tostring(val)
		if callback then callback(val) end
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			updateSlider(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not draggingSlider then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			updateSlider(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
		end
	end)
end

--============================================================--
-- [J] DASHBOARD CARDS
--============================================================--
local curSpeed = 60
local speedOn  = false
local savedHum, savedCollide, mainConn = nil, {}, nil
local yLockOn  = true
_G.curSpeed = curSpeed

local speedCard = makeCard(MainContent, 0, 68)
makeSlider(speedCard, "Movement Speed", 10, 800, 60, 10,
	Icons.Auto, P.accentSoft, P.accent, function(val)
		curSpeed = val; _G.curSpeed = val
	end)

local boostCard = makeCard(MainContent, 76, 80)

local function enableSpeed()
	local c = LP.Character
	if not c then return false end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hrp then return false end
	if hum then savedHum = hum; hum.Parent = nil end
	pcall(function() workspace.CurrentCamera.CameraSubject = hrp end)
	savedCollide = {}
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p ~= hrp then
			savedCollide[p] = p.CanCollide; p.CanCollide = false
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {c}
	rayParams.IgnoreWater = true
	mainConn = RunService.Heartbeat:Connect(function()
		local ch = LP.Character
		if not ch then return end
		local root = ch:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.new(root.Position, root.Position + flat.Unit)
		end
		root.AssemblyAngularVelocity = Vector3.zero
		local v = readMove()
		if v.Magnitude < 0.05 then
			root.AssemblyLinearVelocity = Vector3.zero
		else
			local camCF = cam.CFrame
			local worldDir = camCF.LookVector * (-v.Z) + camCF.RightVector * v.X
			worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)
			if worldDir.Magnitude > 0.01 then
				root.AssemblyLinearVelocity = worldDir.Unit * curSpeed
			end
		end
		if yLockOn then
			local origin = root.Position + Vector3.new(0, 4, 0)
			local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
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
	end)
	return true
end

local function disableSpeed()
	if mainConn then mainConn:Disconnect() mainConn = nil end
	local c = LP.Character
	if not c then savedHum = nil; savedCollide = {}; return end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity  = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	for part, can in pairs(savedCollide) do
		if part and part.Parent then part.CanCollide = can end
	end
	savedCollide = {}
	if savedHum and savedHum.Parent == nil then
		pcall(function()
			savedHum.Parent = c
			savedHum.WalkSpeed = 16
			savedHum.JumpPower = 50
		end)
	end
	savedHum = nil
	task.wait(0.1)
	pcall(function() LP:LoadCharacter() end)
end

makeToggle(boostCard, "Speed Boost", false, 6,
	Icons.Hop, P.accentSoft, P.accent, function(state)
		if state then
			if enableSpeed() then speedOn = true end
		else
			speedOn = false; disableSpeed()
		end
	end)

makeToggle(boostCard, "Invisible", false, 6 + ROW_H,
	Icons.Settings, P.purpleSoft, P.purple, function(state)
		invisOn = state; setInvis(invisOn)
	end)

local protCard = makeCard(MainContent, 164, 160)
local anti61Handle, anti62Handle

local function switchAntiMode(newMode)
	if antiMode == newMode then newMode = "off" end
	if antiMode == newMode then return end
	unlockAll()
	antiMode = newMode
	anti61Handle.setState(newMode == "v61")
	anti62Handle.setState(newMode == "v62")
	if newMode ~= "off" then
		task.spawn(scanAndLockAll)
		if newMode == "v62" then
			applyPlayerNoTouch()
			tagAllPlayerParts()
		end
	else
		removeBlocker()
	end
end

anti61Handle = makeToggle(protCard, "Anti-NPC · Soft (v6.1)", false, 6,
	Icons.List, P.greenSoft, P.green, function(state)
		if state then switchAntiMode("v61") else switchAntiMode("off") end
	end)

anti62Handle = makeToggle(protCard, "Anti-NPC · Hard (v6.2)", false, 6 + ROW_H,
	Icons.Check, P.greenSoft, P.green, function(state)
		if state then switchAntiMode("v62") else switchAntiMode("off") end
	end)

makeToggle(protCard, "Block Rouse", true, 6 + ROW_H * 2,
	Icons.Close, P.redSoft, P.red, function(state)
		blockRouse = state
	end)

makeSlider(protCard, "Blocker Size", 6, 80, 18, 6 + ROW_H * 3,
	Icons.Check, P.purpleSoft, P.purple, function(val)
		blockerSize = val
		if blockerPart and blockerPart.Parent then
			blockerPart.Size = Vector3.new(val, val, val)
		end
	end)

local espCard = makeCard(MainContent, 332, 80)
makeToggle(espCard, "Player ESP", false, 6,
	Icons.Players, P.accentSoft, P.accent, function(state)
		if state then enableESP() else disableESP() end
	end)
makeToggle(espCard, "Fast Loot", true, 6 + ROW_H,
	Icons.Search, P.amberSoft, P.amber, function(state)
		fastLootOn = state
	end)

--============================================================--
-- [K] SERVER HOP TAB
--============================================================--
local InfoCard = Instance.new("Frame", HopContent)
InfoCard.Size = UDim2.new(1, 0, 0, 48)
InfoCard.BackgroundColor3 = P.card
InfoCard.BorderSizePixel = 0
InfoCard.ZIndex = 5
mkCorner(InfoCard, 10)
mkStroke(InfoCard, P.borderSoft, 0.25, 1)

makeIconBadge(InfoCard, Icons.Players, P.accentSoft, P.accent, 14, 13, BADGE)

local InfoLabel = Instance.new("TextLabel", InfoCard)
InfoLabel.Position = UDim2.fromOffset(LABEL_X, 0)
InfoLabel.Size = UDim2.new(1, -LABEL_X - 70, 1, 0)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Font = Enum.Font.GothamMedium
InfoLabel.Text = "Players in this server"
InfoLabel.TextColor3 = P.text
InfoLabel.TextSize = 11
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.ZIndex = 6

local NowCount = Instance.new("TextLabel", InfoCard)
NowCount.Size = UDim2.fromOffset(60, 48)
NowCount.Position = UDim2.new(1, -70, 0, 0)
NowCount.BackgroundTransparency = 1
NowCount.Font = Enum.Font.GothamBold
NowCount.Text = "0"
NowCount.TextColor3 = P.green
NowCount.TextSize = 15
NowCount.TextXAlignment = Enum.TextXAlignment.Right
NowCount.ZIndex = 6

local StatusLabel = Instance.new("TextLabel", HopContent)
StatusLabel.Position = UDim2.fromOffset(4, 54)
StatusLabel.Size = UDim2.new(1, -8, 0, 16)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Ready"
StatusLabel.TextColor3 = P.sub
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 5

local InputCard = Instance.new("Frame", HopContent)
InputCard.Position = UDim2.fromOffset(0, 76)
InputCard.Size = UDim2.new(1, 0, 0, 48)
InputCard.BackgroundColor3 = P.card
InputCard.BorderSizePixel = 0
InputCard.ZIndex = 5
mkCorner(InputCard, 10)
mkStroke(InputCard, P.borderSoft, 0.25, 1)

makeIconBadge(InputCard, Icons.Settings, P.amberSoft, P.amber, 14, 13, BADGE)

local MaxLabel = Instance.new("TextLabel", InputCard)
MaxLabel.Position = UDim2.fromOffset(LABEL_X, 0)
MaxLabel.Size = UDim2.new(1, -LABEL_X - 70, 1, 0)
MaxLabel.BackgroundTransparency = 1
MaxLabel.Font = Enum.Font.GothamMedium
MaxLabel.Text = "Hop when players exceed"
MaxLabel.TextColor3 = P.text
MaxLabel.TextSize = 11
MaxLabel.TextXAlignment = Enum.TextXAlignment.Left
MaxLabel.ZIndex = 6

local MaxBox = Instance.new("TextBox", InputCard)
MaxBox.Position = UDim2.new(1, -50, 0.5, -12)
MaxBox.Size = UDim2.fromOffset(36, 24)
MaxBox.BackgroundColor3 = P.amberSoft
MaxBox.Font = Enum.Font.GothamBold
MaxBox.Text = "1"
MaxBox.TextColor3 = P.amber
MaxBox.TextSize = 12
MaxBox.ClearTextOnFocus = false
MaxBox.TextXAlignment = Enum.TextXAlignment.Center
MaxBox.ZIndex = 6
mkCorner(MaxBox, 6)

local HopBtn = Instance.new("TextButton", HopContent)
HopBtn.Position = UDim2.fromOffset(0, 132)
HopBtn.Size = UDim2.new(0.48, 0, 0, 40)
HopBtn.BackgroundColor3 = P.accent
HopBtn.Text = ""
HopBtn.AutoButtonColor = false
HopBtn.ZIndex = 5
mkCorner(HopBtn, 10)

local hopInner = Instance.new("Frame", HopBtn)
hopInner.AnchorPoint = Vector2.new(0.5, 0.5)
hopInner.Position = UDim2.fromScale(0.5, 0.5)
hopInner.Size = UDim2.fromOffset(90, 16)
hopInner.BackgroundTransparency = 1
hopInner.ZIndex = 6

local hopIcon = Instance.new("ImageLabel", hopInner)
hopIcon.Size = UDim2.fromOffset(13, 13)
hopIcon.Position = UDim2.fromOffset(0, 1.5)
hopIcon.BackgroundTransparency = 1
hopIcon.Image = Icons.Hop
hopIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
hopIcon.ScaleType = Enum.ScaleType.Fit
hopIcon.ZIndex = 7

local hopText = Instance.new("TextLabel", hopInner)
hopText.Position = UDim2.fromOffset(19, 0)
hopText.Size = UDim2.fromOffset(71, 16)
hopText.BackgroundTransparency = 1
hopText.Font = Enum.Font.GothamBold
hopText.Text = "Hop Now"
hopText.TextColor3 = Color3.fromRGB(255, 255, 255)
hopText.TextSize = 11
hopText.TextXAlignment = Enum.TextXAlignment.Left
hopText.ZIndex = 7

local AutoBtn = Instance.new("TextButton", HopContent)
AutoBtn.Position = UDim2.new(0.52, 0, 0, 132)
AutoBtn.Size = UDim2.new(0.48, 0, 0, 40)
AutoBtn.BackgroundColor3 = P.card
AutoBtn.Text = ""
AutoBtn.AutoButtonColor = false
AutoBtn.ZIndex = 5
mkCorner(AutoBtn, 10)
mkStroke(AutoBtn, P.borderSoft, 0.25, 1)

local autoInner = Instance.new("Frame", AutoBtn)
autoInner.AnchorPoint = Vector2.new(0.5, 0.5)
autoInner.Position = UDim2.fromScale(0.5, 0.5)
autoInner.Size = UDim2.fromOffset(90, 16)
autoInner.BackgroundTransparency = 1
autoInner.ZIndex = 6

local autoIcon = Instance.new("ImageLabel", autoInner)
autoIcon.Size = UDim2.fromOffset(13, 13)
autoIcon.Position = UDim2.fromOffset(0, 1.5)
autoIcon.BackgroundTransparency = 1
autoIcon.Image = Icons.Auto
autoIcon.ImageColor3 = P.sub
autoIcon.ScaleType = Enum.ScaleType.Fit
autoIcon.ZIndex = 7

local autoText = Instance.new("TextLabel", autoInner)
autoText.Position = UDim2.fromOffset(19, 0)
autoText.Size = UDim2.fromOffset(71, 16)
autoText.BackgroundTransparency = 1
autoText.Font = Enum.Font.GothamBold
autoText.Text = "Auto: OFF"
autoText.TextColor3 = P.sub
autoText.TextSize = 11
autoText.TextXAlignment = Enum.TextXAlignment.Left
autoText.ZIndex = 7

local SearchBar = Instance.new("Frame", HopContent)
SearchBar.Position = UDim2.fromOffset(0, 180)
SearchBar.Size = UDim2.new(1, 0, 0, 36)
SearchBar.BackgroundColor3 = P.card
SearchBar.BorderSizePixel = 0
SearchBar.ZIndex = 5
mkCorner(SearchBar, 10)
mkStroke(SearchBar, P.borderSoft, 0.25, 1)

local searchIcon = Instance.new("ImageLabel", SearchBar)
searchIcon.Size = UDim2.fromOffset(13, 13)
searchIcon.Position = UDim2.fromOffset(12, 11)
searchIcon.BackgroundTransparency = 1
searchIcon.Image = Icons.Search
searchIcon.ImageColor3 = P.sub
searchIcon.ScaleType = Enum.ScaleType.Fit
searchIcon.ZIndex = 6

local SearchBox = Instance.new("TextBox", SearchBar)
SearchBox.Size = UDim2.new(1, -60, 1, 0)
SearchBox.Position = UDim2.fromOffset(34, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.Font = Enum.Font.Gotham
SearchBox.Text = ""
SearchBox.PlaceholderText = "Search by Job ID..."
SearchBox.PlaceholderColor3 = P.dim
SearchBox.TextColor3 = P.text
SearchBox.TextSize = 11
SearchBox.ClearTextOnFocus = false
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ZIndex = 6

local RefreshBtn = Instance.new("TextButton", SearchBar)
RefreshBtn.Position = UDim2.new(1, -32, 0.5, -11)
RefreshBtn.Size = UDim2.fromOffset(22, 22)
RefreshBtn.BackgroundColor3 = P.accentSoft
RefreshBtn.Text = ""
RefreshBtn.AutoButtonColor = false
RefreshBtn.ZIndex = 6
mkCorner(RefreshBtn, 6)

local refreshIcon = Instance.new("ImageLabel", RefreshBtn)
refreshIcon.Size = UDim2.fromOffset(12, 12)
refreshIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
refreshIcon.BackgroundTransparency = 1
refreshIcon.Image = Icons.Refresh
refreshIcon.ImageColor3 = P.accent
refreshIcon.ScaleType = Enum.ScaleType.Fit
refreshIcon.ZIndex = 7

local ServerListFrame = Instance.new("Frame", HopContent)
ServerListFrame.Position = UDim2.fromOffset(0, 224)
ServerListFrame.Size = UDim2.new(1, 0, 1, -224)
ServerListFrame.BackgroundTransparency = 1
ServerListFrame.ClipsDescendants = true
ServerListFrame.ZIndex = 5

local ServerScrolling = Instance.new("ScrollingFrame", ServerListFrame)
ServerScrolling.Size = UDim2.new(1, 0, 1, 0)
ServerScrolling.BackgroundTransparency = 1
ServerScrolling.BorderSizePixel = 0
ServerScrolling.ScrollBarThickness = 3
ServerScrolling.ScrollBarImageColor3 = P.dim
ServerScrolling.ScrollBarImageTransparency = 0.4
ServerScrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
ServerScrolling.ZIndex = 5

local ServerListLayout = Instance.new("UIListLayout", ServerScrolling)
ServerListLayout.Padding = UDim.new(0, 6)
ServerListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local serverCards = {}

local function clearServerCards()
	for _, card in ipairs(serverCards) do card:Destroy() end
	serverCards = {}
end

local function teleportToServer(serverId)
	if not serverId then return false, "no server id" end
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(PlaceId, serverId, LP)
	end)
	return ok, err
end

local function formatJobId(id)
	if not id then return "N/A" end
	local str = tostring(id)
	if #str > 10 then return str:sub(1, 8) .. "..." end
	return str
end

local function createServerCard(serverData, index)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 52)
	card.BackgroundColor3 = P.card
	card.BorderSizePixel = 0
	card.LayoutOrder = index
	card.ZIndex = 5
	mkCorner(card, 10)
	mkStroke(card, P.borderSoft, 0.25, 1)

	makeIconBadge(card, Icons.Server, P.accentSoft, P.accent, 14, 15, BADGE)

	local jobIdLabel = Instance.new("TextLabel", card)
	jobIdLabel.Size = UDim2.new(1, -LABEL_X - 90, 0, 16)
	jobIdLabel.Position = UDim2.fromOffset(LABEL_X, 7)
	jobIdLabel.BackgroundTransparency = 1
	jobIdLabel.Font = Enum.Font.GothamBold
	jobIdLabel.Text = formatJobId(serverData.id)
	jobIdLabel.TextColor3 = P.text
	jobIdLabel.TextSize = 11
	jobIdLabel.TextXAlignment = Enum.TextXAlignment.Left
	jobIdLabel.TextTruncate = Enum.TextTruncate.AtEnd
	jobIdLabel.ZIndex = 6

	local playerCount = Instance.new("TextLabel", card)
	playerCount.Size = UDim2.new(1, -LABEL_X - 90, 0, 12)
	playerCount.Position = UDim2.fromOffset(LABEL_X, 28)
	playerCount.BackgroundTransparency = 1
	playerCount.Font = Enum.Font.Gotham
	playerCount.Text = (serverData.playing or 0) .. " / " ..
		(serverData.maxPlayers or "?") .. " players"
	playerCount.TextColor3 = P.sub
	playerCount.TextSize = 10
	playerCount.TextXAlignment = Enum.TextXAlignment.Left
	playerCount.ZIndex = 6

	local tpBtn = Instance.new("TextButton", card)
	tpBtn.Size = UDim2.fromOffset(70, 30)
	tpBtn.Position = UDim2.new(1, -82, 0.5, -15)
	tpBtn.BackgroundColor3 = P.accent
	tpBtn.Text = ""
	tpBtn.AutoButtonColor = false
	tpBtn.ZIndex = 6
	mkCorner(tpBtn, 8)

	local tpIcon = Instance.new("ImageLabel", tpBtn)
	tpIcon.Size = UDim2.fromOffset(12, 12)
	tpIcon.Position = UDim2.fromOffset(10, 9)
	tpIcon.BackgroundTransparency = 1
	tpIcon.Image = Icons.Teleport
	tpIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	tpIcon.ScaleType = Enum.ScaleType.Fit
	tpIcon.ZIndex = 7

	local tpText = Instance.new("TextLabel", tpBtn)
	tpText.Position = UDim2.fromOffset(26, 0)
	tpText.Size = UDim2.new(1, -28, 1, 0)
	tpText.BackgroundTransparency = 1
	tpText.Font = Enum.Font.GothamBold
	tpText.Text = "Join"
	tpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	tpText.TextSize = 11
	tpText.TextXAlignment = Enum.TextXAlignment.Left
	tpText.ZIndex = 7

	tpBtn.MouseButton1Click:Connect(function()
		tpText.Text = "..."
		local ok = teleportToServer(serverData.id)
		if not ok then
			tpText.Text = "Fail"; task.wait(1); tpText.Text = "Join"
		end
	end)

	card.Parent = ServerScrolling
	table.insert(serverCards, card)
end

local function fetchServers()
	local url = "https://games.roblox.com/v1/games/" .. PlaceId
		.. "/servers/Public?sortOrder=Asc&limit=100"
	local raw = httpGet(url)
	if not raw or raw == "" then return nil end
	local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok2 or not data or not data.data then return nil end
	return data.data
end

local function updateServerList()
	clearServerCards()
	task.spawn(function()
		local servers = fetchServers()
		if not servers or #servers == 0 then
			StatusLabel.Text = "No servers found (executor HTTP?)"
			StatusLabel.TextColor3 = P.red
			return
		end
		local currentId = tostring(game.JobId)
		local filtered = {}
		for _, s in ipairs(servers) do
			if tostring(s.id) ~= currentId then table.insert(filtered, s) end
		end
		table.sort(filtered, function(a, b)
			return (a.playing or 0) < (b.playing or 0)
		end)
		local query = SearchBox.Text
		if query and query ~= "" then
			query = query:lower()
			local q = {}
			for _, s in ipairs(filtered) do
				if tostring(s.id):lower():find(query, 1, true) then table.insert(q, s) end
			end
			filtered = q
		end
		for i, server in ipairs(filtered) do
			createServerCard(server, i)
			if i % 8 == 0 then task.wait() end
		end
		task.wait(0.05)
		ServerScrolling.CanvasSize = UDim2.new(0, 0, 0,
			ServerListLayout.AbsoluteContentSize.Y + 10)
		StatusLabel.Text = #filtered .. " servers available"
		StatusLabel.TextColor3 = P.sub
	end)
end

local function getRandomServer()
	local servers = fetchServers()
	if not servers or #servers == 0 then return nil end
	local currentId = tostring(game.JobId)
	local candidates = {}
	for _, s in ipairs(servers) do
		if s.id and tostring(s.id) ~= currentId then
			table.insert(candidates, tostring(s.id))
		end
	end
	if #candidates == 0 then return nil end
	return candidates[math.random(1, #candidates)]
end

local function hopOnce()
	local threshold = math.max(1, math.floor(tonumber(MaxBox.Text) or 1))
	local currentCount = #Players:GetPlayers()
	if currentCount <= threshold then
		StatusLabel.Text = "Server meets condition (" .. currentCount .. ")"
		StatusLabel.TextColor3 = P.green
		return false
	end
	StatusLabel.Text = "Searching..."
	StatusLabel.TextColor3 = P.amber
	task.wait(0.4)
	local serverId = getRandomServer()
	if not serverId then
		StatusLabel.Text = "Failed to fetch servers"
		StatusLabel.TextColor3 = P.red
		return false
	end
	StatusLabel.Text = "Teleporting..."
	StatusLabel.TextColor3 = P.accent
	task.wait(0.4)
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(PlaceId, serverId, LP)
	end)
	if not ok then
		StatusLabel.Text = "Error: " .. tostring(err):sub(1, 42)
		StatusLabel.TextColor3 = P.red
		return false
	end
	return true
end

HopBtn.MouseButton1Click:Connect(function()
	HopBtn.Active = false
	hopOnce()
	task.wait(2)
	HopBtn.Active = true
end)

local autoEnabled = false
local autoThread = nil
AutoBtn.MouseButton1Click:Connect(function()
	autoEnabled = not autoEnabled
	if autoEnabled then
		autoText.Text = "Auto: ON"
		autoText.TextColor3 = Color3.fromRGB(255, 255, 255)
		autoIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		AutoBtn.BackgroundColor3 = P.green
		autoThread = task.spawn(function()
			while autoEnabled do
				local threshold = math.max(1, math.floor(tonumber(MaxBox.Text) or 1))
				local count = #Players:GetPlayers()
				if count <= threshold then
					StatusLabel.Text = count .. " players · monitoring"
					StatusLabel.TextColor3 = P.green
					task.wait(3)
				else
					hopOnce()
					task.wait(5)
				end
			end
		end)
	else
		autoText.Text = "Auto: OFF"
		autoText.TextColor3 = P.sub
		autoIcon.ImageColor3 = P.sub
		AutoBtn.BackgroundColor3 = P.card
		if autoThread then task.cancel(autoThread); autoThread = nil end
		StatusLabel.Text = "Auto Hop disabled"
		StatusLabel.TextColor3 = P.sub
	end
end)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	updateServerList()
end)
RefreshBtn.MouseButton1Click:Connect(function() updateServerList() end)

task.spawn(function()
	while ScreenGui.Parent do
		NowCount.Text = tostring(#Players:GetPlayers())
		task.wait(1)
	end
end)

--============================================================--
-- [L] LOOPS
--============================================================--
-- Invis loop (0.5s)
task.spawn(function()
	while task.wait(0.5) do
		if invisOn then setInvis(true) end
	end
end)

-- Backstop scan 3s — chỉ chạy khi anti bật, bù cho event-driven
task.spawn(function()
	while task.wait(3) do
		if antiMode ~= "off" then scanAndLockAll() end
	end
end)

-- Blocker update 0.1s (rẻ, chỉ 1 part)
task.spawn(function()
	while task.wait(0.1) do
		updateBlocker()
	end
end)

-- tag/applyNoTouch backstop 3s
task.spawn(function()
	while task.wait(3) do
		if antiMode == "v62" then
			applyPlayerNoTouch()
			tagAllPlayerParts()
		end
	end
end)

LP.CharacterAdded:Connect(function()
	task.wait(0.5)
	updateMyRoot()
	refreshPlayerChrs()
	if invisOn then setInvis(true) end
	if antiMode == "v62" then applyPlayerNoTouch() end
	tagAllPlayerParts()
	if speedOn then
		pcall(function()
			if mainConn then mainConn:Disconnect() mainConn = nil end
			enableSpeed()
		end)
	end
end)

local function onAnyCharSpawn()
	task.wait(0.4)
	if antiMode == "v62" then
		applyPlayerNoTouch()
		tagAllPlayerParts()
	end
end
for _, plr in ipairs(Players:GetPlayers()) do
	if plr ~= LP then plr.CharacterAdded:Connect(onAnyCharSpawn) end
end
Players.PlayerAdded:Connect(function(plr)
	if plr ~= LP then plr.CharacterAdded:Connect(onAnyCharSpawn) end
end)

tagAllPlayerParts()

print("[Hyko Suite] ULTRA loaded · Namecall:",
	hookInstalled and "ON" or "OFF",
	"· HTTP:", httpGet and "OK" or "NONE",
	"· fireprox:", fireProxPrompt and "OK" or "MISSING")