-- Кот против мальчика-гусеницы: сервер. Ты — Леон, за тобой ползёт гусеница-Ник.
-- Задание даёт 2 заряда: ЛЁД (E) морозит гусеницу на 5 с — подбеги и толкни, ЩИТ (Q) на 4 с; РЫВОК (R) раз в 7 с.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local DSS = game:GetService("DataStoreService")
local MPS = game:GetService("MarketplaceService")
local Config = require(RS:WaitForChild("ShopConfig"))
local store = nil
pcall(function() store = DSS:GetDataStore("CatGame_v1") end)
local shopFn = RS:FindFirstChild("ShopAction") or Instance.new("RemoteFunction")
shopFn.Name = "ShopAction"; shopFn.Parent = RS
local remote = RS:FindFirstChild("CatAction") or Instance.new("RemoteEvent")
remote.Name = "CatAction"; remote.Parent = RS

local FLOOR, HX, HZ = 1, 78, 52
local SPAWN = Vector3.new(-62, FLOOR + 3, 0)
local LevelFolder = workspace:WaitForChild("Level")
local Border = workspace:WaitForChild("Arena"):WaitForChild("Border")
local WORLDS = { "Двор", "Пляж", "Кухня", "Москва", "Красноярск", "Лес", "Пустыня", "Горы", "Космос", "Замок" }

local G = nil

local function P(t)
	local p = Instance.new(t.Class or "Part"); p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if t.Shape then p.Shape = t.Shape end
	p.Size = t.Size; p.CFrame = t.CFrame or CFrame.new(t.Pos)
	p.Color = t.Color or Color3.new(1, 1, 1); p.Material = t.Material or Enum.Material.SmoothPlastic
	p.CanCollide = t.CanCollide ~= false; p.CanTouch = false
	if t.Transparency then p.Transparency = t.Transparency end
	p.Name = t.Name or "Part"; p.Parent = t.Parent or LevelFolder
	return p
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function dxz(a, b) return (flat(a) - flat(b)).Magnitude end

-- ───────── сообщения и состояние для интерфейса ─────────
local msgId = 0
local function say(plr, text) msgId += 1; plr:SetAttribute("Msg", text); plr:SetAttribute("MsgId", msgId) end
local function sync()
	if not G or not G.player then return end
	local pl, m = G.player, G.cat
	pl:SetAttribute("Energy", math.floor(G.energy)); pl:SetAttribute("Lives", G.lives); pl:SetAttribute("Charges", G.charges)
	pl:SetAttribute("Level", G.level); pl:SetAttribute("World", G.themeName or "Двор")
	pl:SetAttribute("DashCd", math.ceil(G.dashCd * 10) / 10)
	if m then pl:SetAttribute("MonsterHP", math.max(0, math.floor(m.hp))); pl:SetAttribute("MonsterMax", m.maxHp); pl:SetAttribute("Frozen", math.ceil(m.frozen)); pl:SetAttribute("Boss", m.boss) end
	local t = G.task
	if t then pl:SetAttribute("TaskText", t.text); pl:SetAttribute("TaskDone", t.done); pl:SetAttribute("TaskNeed", t.need) else pl:SetAttribute("TaskText", G.charges > 0 and ("Зарядов: " .. G.charges .. " — E лёд, Q щит") or ""); pl:SetAttribute("TaskDone", 0); pl:SetAttribute("TaskNeed", 0) end
	local ls = pl:FindFirstChild("leaderstats"); if ls then ls.Level.Value = G.level; ls.Coins.Value = G.coins end
	pl:SetAttribute("MaxLives", (G.passes and G.passes.ExtraHeart) and 4 or 3); pl:SetAttribute("CanRevive", G.result == "lose" and G.canRevive == true)
	pl:SetAttribute("Kit", G.kit or "barca"); pl:SetAttribute("OwnedKits", table.concat(G.owned or {}, ","))
	local ps = {}; for k, v in pairs(G.passes or {}) do if v then table.insert(ps, k) end end; pl:SetAttribute("Passes", table.concat(ps, ","))
end

-- ───────── сохранение, пропуски, монеты ─────────
local function saveData()
	if not G or not G.player or not store or not G.loaded then return end
	local d = { level = G.level, best = G.best, coins = G.coins, owned = G.owned, kit = G.kit }
	local ok, err = pcall(function() store:SetAsync("p_" .. G.player.UserId, d) end)
	if not ok then warn("Сохранение не удалось: " .. tostring(err)) end
end
local function loadData(plr)
	if not store then return {} end
	local ok, res = pcall(function() return store:GetAsync("p_" .. plr.UserId) end)
	if not ok then warn("Загрузка не удалась (опубликуй игру и включи API Services): " .. tostring(res)); return {} end
	return res or {}
end
local function addCoins(n) G.coins += n * ((G.passes and G.passes.DoubleCoins) and 2 or 1) end
local function kitByKey(k) for _, K in ipairs(Config.Kits) do if K.key == k then return K end end; return Config.Kits[1] end
local function ownsKit(k) local K = kitByKey(k); if K.coins == 0 then return true end; if K.pass then return G.passes[K.pass] == true end; return table.find(G.owned, k) ~= nil end

-- ───────── ловушки ─────────
local function kindsFor(level)
	local k = { "pool", "rock", "bush" }
	if level >= 2 then table.insert(k, "cactus") end
	if level >= 3 then table.insert(k, "spikes") end
	if level >= 4 then table.insert(k, "lava") end
	if level >= 5 then table.insert(k, "mud") end
	if level >= 8 then table.insert(k, "laser") end
	if level >= 10 then table.insert(k, "fence") end
	return k
end
local function inZone(pos, z, pad) pad = pad or 0; return math.abs(pos.X - z.cx) < z.sx / 2 + pad and math.abs(pos.Z - z.cz) < z.sz / 2 + pad end
local function zoneAt(pos, kind, pad) for _, z in ipairs(G.zones) do if z.kind == kind and inZone(pos, z, pad) then return z end end end

local function buildObstacle(kind, cx, cz, solids)
	local z = { kind = kind, cx = cx, cz = cz, sx = 10, sz = 8 }
	if kind == "pool" then
		z.sx, z.sz = math.random(12, 18), math.random(9, 13)
		P({ Name = "Pool", Size = Vector3.new(z.sx, 0.3, z.sz), Pos = Vector3.new(cx, FLOOR + 0.1, cz), Color = Color3.fromRGB(64, 160, 225), Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false })
		P({ Name = "PoolEdge", Size = Vector3.new(z.sx + 1.5, 0.2, z.sz + 1.5), Pos = Vector3.new(cx, FLOOR + 0.02, cz), Color = Color3.fromRGB(40, 120, 180), CanCollide = false })
	elseif kind == "rock" then
		z.sx, z.sz = 6, 6
		P({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 6, 7), Pos = Vector3.new(cx, FLOOR + 2, cz), Color = Color3.fromRGB(141, 144, 150), Material = Enum.Material.Slate, Parent = solids })
	elseif kind == "bush" then
		z.sx, z.sz = math.random(10, 16), 4
		P({ Name = "Bush", Size = Vector3.new(z.sx, 4, 4), Pos = Vector3.new(cx, FLOOR + 2, cz), Color = Color3.fromRGB(63, 143, 58), Material = Enum.Material.LeafyGrass, Parent = solids })
	elseif kind == "cactus" then
		z.sx, z.sz = 5, 5
		P({ Name = "Cactus", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 2.6, 2.6), CFrame = CFrame.new(cx, FLOOR + 3.5, cz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(63, 143, 58), Material = Enum.Material.Grass, CanCollide = false })
		P({ Name = "CactusArm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.6, 1.6), CFrame = CFrame.new(cx + 1.8, FLOOR + 4.5, cz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(63, 143, 58), Material = Enum.Material.Grass, CanCollide = false })
		P({ Name = "CactusArm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.5, 1.6, 1.6), CFrame = CFrame.new(cx - 1.8, FLOOR + 3.6, cz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(63, 143, 58), Material = Enum.Material.Grass, CanCollide = false })
	elseif kind == "spikes" then
		z.sx, z.sz = 8, 8
		P({ Name = "SpikePlate", Size = Vector3.new(8, 0.4, 8), Pos = Vector3.new(cx, FLOOR + 0.2, cz), Color = Color3.fromRGB(90, 94, 102), Material = Enum.Material.Metal, CanCollide = false })
		for ix = -1, 1 do for iz = -1, 1 do
			P({ Class = "WedgePart", Name = "Spike", Size = Vector3.new(0.9, 1.6, 0.9), CFrame = CFrame.new(cx + ix * 2.4, FLOOR + 1.2, cz + iz * 2.4), Color = Color3.fromRGB(215, 219, 227), Material = Enum.Material.Metal, CanCollide = false })
		end end
	elseif kind == "lava" then
		z.sx, z.sz = math.random(12, 17), math.random(9, 13)
		local l = P({ Name = "Lava", Size = Vector3.new(z.sx, 0.35, z.sz), Pos = Vector3.new(cx, FLOOR + 0.12, cz), Color = Color3.fromRGB(255, 90, 31), Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 120, 40); light.Range = 14; light.Brightness = 2; light.Parent = l
	elseif kind == "mud" then
		z.sx, z.sz = math.random(12, 17), math.random(9, 13)
		P({ Name = "Mud", Size = Vector3.new(z.sx, 0.3, z.sz), Pos = Vector3.new(cx, FLOOR + 0.1, cz), Color = Color3.fromRGB(90, 60, 32), Material = Enum.Material.Mud, CanCollide = false })
	elseif kind == "laser" then
		local horiz = math.random() < 0.5; z.sx, z.sz = horiz and 16 or 1.5, horiz and 1.5 or 16
		for s = -1, 1, 2 do P({ Name = "LaserPost", Size = Vector3.new(1.6, 4, 1.6), Pos = Vector3.new(cx + (horiz and s * 8 or 0), FLOOR + 2, cz + (horiz and 0 or s * 8)), Color = Color3.fromRGB(58, 61, 68), Material = Enum.Material.Metal, Parent = solids }) end
		z.beam = P({ Name = "LaserBeam", Size = Vector3.new(horiz and 16 or 0.3, 0.3, horiz and 0.3 or 16), Pos = Vector3.new(cx, FLOOR + 2.5, cz), Color = Color3.fromRGB(255, 59, 92), Material = Enum.Material.Neon, CanCollide = false })
		z.phase = math.random() * 3
	elseif kind == "fence" then
		z.sx, z.sz = 14, 1.2
		for i = 0, 4 do P({ Name = "FencePost", Size = Vector3.new(0.9, 4, 0.9), Pos = Vector3.new(cx - 7 + i * 3.5, FLOOR + 2, cz), Color = Color3.fromRGB(169, 113, 66), Material = Enum.Material.Wood, Parent = solids }) end
		for _, h in ipairs({ 1.2, 3.0 }) do P({ Name = "FenceWire", Size = Vector3.new(14, 0.2, 0.2), Pos = Vector3.new(cx, FLOOR + h, cz), Color = Color3.fromRGB(127, 216, 255), Material = Enum.Material.Neon, Parent = solids }) end
	end
	table.insert(G.zones, z)
end

local function freeSpot(minPlayer)
	for _ = 1, 80 do
		local p = Vector3.new(math.random(-HX + 8, HX - 8), FLOOR, math.random(-HZ + 8, HZ - 8))
		local ok = true
		for _, z in ipairs(G.zones) do if inZone(p, z, 5) then ok = false break end end
		local hrp = G.player and G.player.Character and G.player.Character:FindFirstChild("HumanoidRootPart")
		if ok and hrp and dxz(p, hrp.Position) < (minPlayer or 14) then ok = false end
		if ok then return p end
	end
	return Vector3.new(0, FLOOR, -HZ + 10)
end

-- ───────── гусеница-Ник ─────────
local BROWN, BROWN2, WHITE = Color3.fromRGB(90, 58, 34), Color3.fromRGB(112, 74, 44), Color3.fromRGB(246, 239, 227)
local function buildCat(level)
	local boss = level % 5 == 0
	local m = { segs = {}, r = boss and 4 or 3, boss = boss, frozen = 0, stun = 1.5, snake = 0, snakeCd = 6, dashT = 6, dashOn = 0, trapCd = 0, shootT = 3 }
	m.speed = math.min(19, 10 + level * 0.35) * (boss and 0.85 or 1)
	m.maxHp = 100 * level * (boss and 1.5 or 1); m.hp = m.maxHp
	m.hits = 3 + math.floor(level / 5); m.dmg = math.ceil(m.maxHp / m.hits)
	local model = Instance.new("Model"); model.Name = boss and "BossCaterpillar" or "Caterpillar"; model.Parent = LevelFolder
	local n = math.min(22, 10 + level)
	for i = 1, n do
		local r = (i == 1) and m.r or m.r * (1 - (i - 1) / (n + 4) * 0.5)
		local pos = Vector3.new(60 + (i - 1) * r * 1.3, FLOOR + r, 0)
		local s = P({ Shape = Enum.PartType.Ball, Name = (i == 1) and "Head" or ("Seg" .. i), Size = Vector3.new(r * 2, r * 2, r * 2), CFrame = CFrame.lookAt(pos, pos - Vector3.new(1, 0, 0)), Color = (i % 2 == 0) and BROWN or BROWN2, CanCollide = false, Parent = model })
		s.CanQuery = false
		table.insert(m.segs, { part = s, r = r, pos = pos, col = s.Color })
		if i > 1 and i % 2 == 1 then -- белое пузико снизу
			local b = P({ Shape = Enum.PartType.Ball, Name = "Belly", Size = Vector3.new(r * 1.4, r * 1.2, r * 1.4), CFrame = s.CFrame * CFrame.new(0, -r * 0.45, 0), Color = WHITE, CanCollide = false, Parent = s })
			b.Anchored = false; b.Massless = true; b.CanQuery = false; local w = Instance.new("WeldConstraint"); w.Part0 = s; w.Part1 = b; w.Parent = b
		end
	end
	local head = m.segs[1].part
	local function deco(t) t.Parent = head; t.CanCollide = false; t.CFrame = head.CFrame * t.Rel; local p = P(t); p.Anchored = false; p.Massless = true; p.CanQuery = false; local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = p; w.Parent = p; return p end
	local r = m.r
	deco({ Shape = Enum.PartType.Ball, Name = "Muzzle", Size = Vector3.new(r * 0.9, r * 0.7, r * 0.7), Rel = CFrame.new(0, -r * 0.25, -r * 0.75), Color = WHITE })
	for s = -1, 1, 2 do
		deco({ Shape = Enum.PartType.Ball, Name = "Eye", Size = Vector3.new(r * 0.32, r * 0.32, r * 0.32), Rel = CFrame.new(s * r * 0.38, r * 0.18, -r * 0.86), Color = Color3.fromRGB(110, 170, 230) })
		deco({ Shape = Enum.PartType.Ball, Name = "Pupil", Size = Vector3.new(r * 0.15, r * 0.15, r * 0.15), Rel = CFrame.new(s * r * 0.38, r * 0.18, -r * 1.0), Color = Color3.new(0, 0, 0) })
		deco({ Class = "WedgePart", Name = "Ear", Size = Vector3.new(r * 0.18, r * 0.95, r * 0.75), Rel = CFrame.new(s * r * 0.6, r * 0.95, -r * 0.1) * CFrame.Angles(0, 0, -s * 0.35), Color = BROWN })
	end
	deco({ Shape = Enum.PartType.Ball, Name = "Nose", Size = Vector3.new(r * 0.2, r * 0.15, r * 0.15), Rel = CFrame.new(0, -r * 0.08, -r * 1.08), Color = Color3.fromRGB(233, 167, 181) })
	m.tongue = deco({ Name = "Tongue", Size = Vector3.new(r * 0.12, r * 0.06, r * 1.4), Rel = CFrame.new(0, -r * 0.4, -r * 1.6), Color = Color3.fromRGB(230, 57, 70), Material = Enum.Material.Neon })
	m.tongue.Transparency = 1
	if boss then
		m.shield = deco({ Name = "BossShield", Size = Vector3.new(r * 2.6, r * 1.8, 0.4), Rel = CFrame.new(0, 0, -r * 1.5), Color = Color3.fromRGB(127, 216, 255), Material = Enum.Material.ForceField })
		local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0, 160, 0, 40); bb.StudsOffset = Vector3.new(0, r + 3, 0); bb.AlwaysOnTop = true; bb.Parent = head
		local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = "БОСС"; tl.TextColor3 = Color3.fromRGB(255, 77, 109); tl.TextScaled = true; tl.Font = Enum.Font.GothamBlack; tl.Parent = bb
	end
	return m
end

local function setFrozenLook(m, on)
	for _, s in ipairs(m.segs) do
		s.part.Material = on and Enum.Material.Ice or Enum.Material.SmoothPlastic
		s.part.Color = on and Color3.fromRGB(170, 220, 255) or s.col
		s.part.Transparency = on and 0.1 or 0
	end
end

-- ───────── задания ─────────
local TASKS = { "collect", "rings", "buttons", "mouse" }
local function clearTask() if G.taskFolder then G.taskFolder:Destroy() end; G.taskFolder = Instance.new("Folder"); G.taskFolder.Name = "Task"; G.taskFolder.Parent = LevelFolder end
local function label(part, txt)
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0, 60, 0, 60); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Parent = part
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = txt; tl.TextColor3 = Color3.fromRGB(255, 230, 0); tl.TextStrokeTransparency = 0; tl.TextScaled = true; tl.Font = Enum.Font.GothamBlack; tl.Parent = bb
	return tl
end
local function newTask()
	clearTask(); G.taskN += 1
	local typ = TASKS[(G.level + G.taskN - 2) % #TASKS + 1]
	local t = { type = typ, items = {}, done = 0, need = 3 }
	if typ == "collect" then
		t.text = "Собери 3 золотые монетки"
		for _ = 1, 3 do local p = freeSpot(); table.insert(t.items, { pos = p, part = P({ Shape = Enum.PartType.Cylinder, Name = "GoldCoin", Size = Vector3.new(0.5, 3, 3), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)), Color = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Metal, CanCollide = false, Parent = G.taskFolder }) }) end
	elseif typ == "rings" then
		t.text = "Пробеги 3 кольца по порядку"
		for i = 1, 3 do local p = freeSpot(); local ring = P({ Shape = Enum.PartType.Cylinder, Name = "Ring" .. i, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(p + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 230, 0), Material = Enum.Material.Neon, Transparency = i == 1 and 0.2 or 0.7, CanCollide = false, Parent = G.taskFolder }); table.insert(t.items, { pos = p, part = ring, lbl = label(ring, tostring(i)) }) end
	elseif typ == "buttons" then
		t.text = "Наступи на 3 красные кнопки"
		for _ = 1, 3 do local p = freeSpot(); local b = P({ Shape = Enum.PartType.Cylinder, Name = "RedButton", Size = Vector3.new(0.8, 5, 5), CFrame = CFrame.new(p + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(230, 57, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = G.taskFolder }); table.insert(t.items, { pos = p, part = b }) end
	else
		t.text = "Поймай мышку"; t.need = 1
		local p = freeSpot(20); local mouse = P({ Shape = Enum.PartType.Ball, Name = "Mouse", Size = Vector3.new(2.2, 1.6, 3), Pos = p + Vector3.new(0, 0.8, 0), Color = Color3.fromRGB(154, 154, 154), CanCollide = false, Parent = G.taskFolder })
		for s = -1, 1, 2 do local e = P({ Shape = Enum.PartType.Ball, Name = "MouseEar", Size = Vector3.new(1, 1, 0.3), CFrame = mouse.CFrame * CFrame.new(s * 0.7, 0.9, -0.8), Color = Color3.fromRGB(240, 160, 176), CanCollide = false, Parent = G.taskFolder }); e.Anchored = false; e.Massless = true; local w = Instance.new("WeldConstraint"); w.Part0 = mouse; w.Part1 = e; w.Parent = e end
		table.insert(t.items, { pos = p, part = mouse, vel = Vector3.zero })
	end
	G.task = t; say(G.player, "Задание: " .. t.text)
end

-- ───────── уровень ─────────
local function hrpOf() local c = G and G.player and G.player.Character; return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid") end
-- ───────── арены: каждый уровень своя ─────────
local THEMES = {
	{ name = "Двор", floor = { 122, 190, 96 }, fm = "Grass", stripe = { 140, 206, 112 }, hedge = { 58, 130, 54 }, hm = "LeafyGrass", leaves = { 70, 150, 62 }, lm = "LeafyGrass", trunk = { 110, 74, 44 }, clock = 14, fog = { 200, 225, 255 } },
	{ name = "Пляж", floor = { 240, 220, 156 }, fm = "Sand", stripe = { 228, 205, 140 }, hedge = { 214, 168, 110 }, hm = "Wood", leaves = { 64, 168, 82 }, lm = "Grass", trunk = { 160, 120, 70 }, clock = 12, fog = { 180, 225, 255 } },
	{ name = "Зима", floor = { 238, 244, 251 }, fm = "Snow", stripe = { 222, 233, 246 }, hedge = { 190, 215, 240 }, hm = "Ice", leaves = { 245, 250, 255 }, lm = "Snow", trunk = { 100, 80, 60 }, clock = 10, fog = { 225, 235, 250 } },
	{ name = "Пустыня", floor = { 232, 195, 110 }, fm = "Sand", stripe = { 220, 180, 94 }, hedge = { 184, 121, 58 }, hm = "Sandstone", leaves = { 70, 140, 60 }, lm = "Grass", trunk = { 70, 140, 60 }, clock = 16, fog = { 255, 225, 180 } },
	{ name = "Космос", floor = { 32, 34, 70 }, fm = "SmoothPlastic", stripe = { 44, 48, 96 }, hedge = { 107, 111, 168 }, hm = "Metal", leaves = { 150, 90, 230 }, lm = "Neon", trunk = { 70, 70, 100 }, clock = 0, fog = { 30, 30, 60 } },
	{ name = "Вулкан", floor = { 74, 48, 48 }, fm = "Basalt", stripe = { 62, 38, 38 }, hedge = { 42, 26, 26 }, hm = "Rock", leaves = { 255, 90, 31 }, lm = "Neon", trunk = { 40, 24, 24 }, clock = 18.5, fog = { 255, 140, 90 } },
	{ name = "Лес", floor = { 79, 143, 62 }, fm = "Grass", stripe = { 70, 130, 55 }, hedge = { 90, 58, 34 }, hm = "Wood", leaves = { 47, 107, 42 }, lm = "LeafyGrass", trunk = { 90, 58, 34 }, clock = 15, fog = { 170, 210, 170 } },
	{ name = "Город", floor = { 143, 143, 152 }, fm = "Concrete", stripe = { 128, 128, 138 }, hedge = { 160, 82, 60 }, hm = "Brick", leaves = { 80, 140, 70 }, lm = "Grass", trunk = { 90, 70, 50 }, clock = 13, fog = { 210, 210, 220 } },
}
local function applyTheme(level)
	local T = THEMES[(level - 1) % #THEMES + 1]; G.themeName = T.name
	local c = function(t) return Color3.fromRGB(t[1], t[2], t[3]) end
	local A = workspace:FindFirstChild("Arena"); if not A then return end
	for _, o in ipairs(A:GetDescendants()) do
		if o:IsA("BasePart") then
			if o.Name == "Floor" then o.Color = c(T.floor); o.Material = Enum.Material[T.fm]
			elseif o.Name == "Stripe" then o.Color = c(T.stripe); o.Material = Enum.Material[T.fm]
			elseif o.Name:sub(1, 5) == "Hedge" then o.Color = c(T.hedge); o.Material = Enum.Material[T.hm]
			elseif o.Name == "Leaves" or o.Name == "Leaves2" then o.Color = c(T.leaves); o.Material = Enum.Material[T.lm]
			elseif o.Name == "Trunk" then o.Color = c(T.trunk) end
		end
	end
	local L = game:GetService("Lighting"); L.ClockTime = T.clock; L.Brightness = T.clock < 6 and 1 or 2.5
	local at = L:FindFirstChildOfClass("Atmosphere"); if at then at.Color = c(T.fog); at.Density = T.clock < 6 and 0.4 or 0.25 end
end
local function buildLevel(level)
	LevelFolder:ClearAllChildren()
	applyTheme(level)
	G.level = level; G.zones = {}; G.taskN = 0; G.task = nil; G.charges = (G.passes and G.passes.VIP) and 1 or 0; G.result = nil; G.bitten = false; G.energy = 100; G.lives = (G.passes and G.passes.ExtraHeart) and 4 or 3; G.canRevive = false; G.inv = 2; G.poison = 0; G.dirty = false; G.trapCd = 0
	local solids = Instance.new("Folder"); solids.Name = "Solids"; solids.Parent = LevelFolder
	local kinds = kindsFor(level)
	local count = level == 1 and 0 or math.min(10, 2 + math.floor(level / 3) + math.random(0, 2))
	local placed = {}
	for _ = 1, count do
		for _ = 1, 40 do
			local cx, cz = math.random(-HX + 14, HX - 22), math.random(-HZ + 10, HZ - 10)
			if cx < -44 or cx > 48 then continue end
			local ok = true; for _, q in ipairs(placed) do if (Vector2.new(cx, cz) - q).Magnitude < 24 then ok = false break end end
			if ok then table.insert(placed, Vector2.new(cx, cz)); buildObstacle(kinds[math.random(1, #kinds)], cx, cz, solids) break end
		end
	end
	G.rayParams = RaycastParams.new(); G.rayParams.FilterType = Enum.RaycastFilterType.Include; G.rayParams.FilterDescendantsInstances = { solids, Border }
	G.cat = buildCat(level)
	-- монетки на поле
	G.coinsOnField = {}
	for _ = 1, 5 do local p = freeSpot(); local c = P({ Shape = Enum.PartType.Cylinder, Name = "Coin", Size = Vector3.new(0.6, 3.6, 3.6), CFrame = CFrame.new(p + Vector3.new(0, 2.2, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, CanCollide = false }); table.insert(G.coinsOnField, { pos = p, part = c }) end
	local hrp, hum = hrpOf(); if hrp then hrp.CFrame = CFrame.new(SPAWN) end; if hum then hum.Health = hum.MaxHealth end
	newTask()
	say(G.player, (G.cat.boss and "БОСС! Щит спереди — бей лёдом сбоку или сзади" or ("Уровень " .. level .. " — убегай и выполняй задания")))
	sync()
end

local function shard(pos, col)
	for _ = 1, 8 do local s = Instance.new("Part"); s.Size = Vector3.new(0.6, 0.6, 0.6); s.Color = col; s.Material = Enum.Material.Ice; s.CanCollide = false; s.CFrame = CFrame.new(pos); s.Parent = LevelFolder; s.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(10, 30), math.random(-20, 20)); Debris:AddItem(s, 1.2) end
end

local function loseLife(reason)
	G.lives -= 1; G.energy = 100; G.inv = 2
	if G.lives <= 0 then
		G.result = "lose"; G.canRevive = Config.Products.Revive.id > 0
		say(G.player, G.canRevive and "Съели! Можно воскреснуть на месте — или уровень заново через 8 с" or "Съели! Начинаем уровень заново…"); sync()
		local myLevel = G.level
		task.delay(G.canRevive and 8 or 3, function() if G and G.result == "lose" and G.level == myLevel then buildLevel(G.level) end end)
	else
		say(G.player, (reason or "Энергия кончилась!") .. " Осталось жизней: " .. G.lives)
		local hrp = hrpOf(); if hrp then hrp.CFrame = CFrame.new(SPAWN) end
	end
end
local function hurtPlayer(n, text)
	if G.result or G.inv > 0 then return end
	if G.shieldT and G.shieldT > 0 then return end
	G.energy -= n; G.inv = 0.8; if text then say(G.player, text) end
	if G.energy <= 0 then loseLife() end
end

local function win()
	G.result = "win"
	local clean = not G.bitten
	local bonus = 5 + G.level + (G.cat.boss and 20 or 0) + (clean and 100 or 0)
	addCoins(bonus)
	say(G.player, "ПОБЕДА! +" .. bonus .. " монет" .. (clean and " (100 ₽ — ни одного укуса!)" or ""))
	for _, s in ipairs(G.cat.segs) do shard(s.pos, Color3.fromRGB(255, 215, 0)) end
	sync()
	G.best = math.max(G.best or 1, G.level + 1); task.delay(3.5, function() if G and G.result == "win" then buildLevel(G.level + 1); saveData() end end)
end

-- ───────── действия игрока ─────────
remote.OnServerEvent:Connect(function(plr, action)
	if not G or plr ~= G.player or G.result then return end
	local hrp = hrpOf(); if not hrp then return end
	if action == "ice" and G.charges > 0 then
		G.charges -= 1
		local head = G.cat.segs[1]
		local from = hrp.Position + Vector3.new(0, 1, 0)
		local dir = (flat(head.pos) - flat(from)); dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
		local ball = P({ Shape = Enum.PartType.Ball, Name = "IceBall", Size = Vector3.new(2, 2, 2), Pos = from, Color = Color3.fromRGB(154, 214, 255), Material = Enum.Material.Neon, CanCollide = false })
		table.insert(G.balls, { part = ball, pos = from, dir = dir, life = 2.5 })
		if G.charges <= 0 and not G.task then task.delay(0.6, function() if G and not G.task and not G.result then newTask() end end) end
	elseif action == "shield" and G.charges > 0 then
		G.charges -= 1; G.shieldT = 4
		local ff = Instance.new("ForceField"); ff.Visible = true; ff.Parent = hrp.Parent; Debris:AddItem(ff, 4)
		say(plr, "ЩИТ на 4 секунды!")
		if G.charges <= 0 and not G.task then task.delay(0.6, function() if G and not G.task and not G.result then newTask() end end) end
	elseif action == "dash" and G.dashCd <= 0 then
		G.dashCd = 7; G.dashT = 0.7
	end
	sync()
end)

-- ───────── главный цикл ─────────
local syncT = 0
RunService.Heartbeat:Connect(function(dt)
	if not G or not G.player or not G.cat then return end
	local hrp, hum = hrpOf(); if not hrp or not hum then return end
	local m, head = G.cat, G.cat.segs[1]
	G.inv = math.max(0, G.inv - dt); G.dashCd = math.max(0, G.dashCd - dt); G.dashT = math.max(0, (G.dashT or 0) - dt); G.poison = math.max(0, G.poison - dt); G.shieldT = math.max(0, (G.shieldT or 0) - dt); G.trapCd = math.max(0, G.trapCd - dt)
	local ppos = hrp.Position
	-- скорость Леона: рывок, яд, вода
	local inPool = zoneAt(ppos, "pool")
	hum.WalkSpeed = (18 + (G.dashT > 0 and 26 or 0)) * (G.poison > 0 and 0.65 or 1) * (inPool and 0.6 or 1)
	if inPool and G.dirty then G.dirty = false; say(G.player, "Помылся!") end
	if zoneAt(ppos, "mud") and not G.dirty then G.dirty = true; say(G.player, "Испачкался в грязи!") end
	-- ловушки для Леона
	if not G.result and G.trapCd <= 0 then
		local function trap(kind, n, txt) local z = zoneAt(ppos, kind); if z and (kind ~= "laser" or z.on) then G.trapCd = (kind == "lava") and 1 or 0.8; hurtPlayer(n, txt); if kind == "lava" then G.dirty = true end; return true end end
		local _ = trap("cactus", 5, "-5 кактус!") or trap("spikes", 10, "-10 шипы!") or trap("lava", 20, "-20 ЛАВА!") or trap("laser", 10, "-10 ЛАЗЕР!")
		local f = zoneAt(ppos, "fence", 2.5); if f then G.trapCd = 0.8; hurtPlayer(10, "-10 ТОК!"); hrp.CFrame = hrp.CFrame + Vector3.new(0, 0, (ppos.Z > f.cz) and 4 or -4) end
	end
	-- лазеры мигают
	local now = os.clock()
	for _, z in ipairs(G.zones) do if z.kind == "laser" then z.on = ((now + z.phase) % 3) < 1.6; z.beam.Transparency = z.on and 0 or 0.85 end end
	-- монетки на поле
	for i = #G.coinsOnField, 1, -1 do local c = G.coinsOnField[i]; c.part.CFrame = CFrame.new(c.pos + Vector3.new(0, 2.2 + math.sin(now * 3 + c.pos.X) * 0.4, 0)) * CFrame.Angles(0, now * 3, 0); if dxz(c.pos, ppos) < 4 then c.part:Destroy(); table.remove(G.coinsOnField, i); addCoins(1); say(G.player, (G.passes.DoubleCoins and "+2 монеты" or "+1 монета")) end end
	-- задание
	local t = G.task
	if t and not G.result then
		if t.type == "collect" then for _, it in ipairs(t.items) do if not it.got then it.part.CFrame = CFrame.new(it.pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, now * 3, 0); if dxz(it.pos, ppos) < 4 then it.got = true; it.part:Destroy(); t.done += 1; addCoins(1) end end end
		elseif t.type == "rings" then local it = t.items[t.done + 1]; if it and dxz(it.pos, ppos) < 3.8 then it.got = true; it.part:Destroy(); t.done += 1; local nx = t.items[t.done + 1]; if nx then nx.part.Transparency = 0.2 end end
		elseif t.type == "buttons" then for _, it in ipairs(t.items) do if not it.got and dxz(it.pos, ppos) < 3.5 then it.got = true; it.part.Color = Color3.fromRGB(46, 204, 113); it.part.CFrame = it.part.CFrame - Vector3.new(0, 0.3, 0); t.done += 1 end end
		elseif t.type == "mouse" then local it = t.items[1]; local d = dxz(it.pos, ppos); if d < 22 then local away = flat(it.pos) - flat(ppos); away = away.Magnitude > 0 and away.Unit or Vector3.new(1, 0, 0); it.pos = it.pos + away * 12.5 * dt; it.pos = Vector3.new(math.clamp(it.pos.X, -HX + 3, HX - 3), FLOOR, math.clamp(it.pos.Z, -HZ + 3, HZ - 3)); it.part.CFrame = CFrame.lookAt(it.pos + Vector3.new(0, 0.8, 0), it.pos + Vector3.new(0, 0.8, 0) - away) end; if d < 3.2 then it.part:Destroy(); t.done = 1 end end
		if t.done >= t.need then G.task = nil; clearTask(); G.charges = 2; say(G.player, "2 заряда! E — ЛЁД, Q — ЩИТ") end
	end
	-- гусеница
	m.stun = math.max(0, m.stun - dt); m.snake = math.max(0, m.snake - dt); m.snakeCd = math.max(0, m.snakeCd - dt); m.dashOn = math.max(0, m.dashOn - dt); m.dashT -= dt; m.trapCd = math.max(0, m.trapCd - dt)
	if m.frozen > 0 then m.frozen = math.max(0, m.frozen - dt); if m.frozen <= 0 then setFrozenLook(m, false) end end
	m.tongue.Transparency = (m.snake > 0 or (m.snakeCd < 0.5 and m.frozen <= 0)) and 0 or 1
	if not G.result and m.frozen <= 0 and m.stun <= 0 then
		local dist = dxz(head.pos, ppos)
		if m.dashT <= 0 then m.dashT = 6 + math.random() * 2; m.dashOn = 0.8 end
		if m.snakeCd <= 0 and dist < 26 and not m.boss then m.snake = 1.3; m.snakeCd = 6 + math.random() * 2; say(G.player, "ШШШ! Гусеница бросается!") end
		local dir = flat(ppos) - flat(head.pos); dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(-1, 0, 0)
		if m.boss and dist < 18 then dir = -dir end -- босс держит дистанцию и стреляет
		local spd = m.speed * (m.snake > 0 and 2.6 or (m.dashOn > 0 and 1.9 or 1)) * (zoneAt(head.pos, "mud") and 0.55 or 1)
		local ray = workspace:Raycast(head.pos, dir * (m.r + 4), G.rayParams)
		if ray then local side = Vector3.new(-dir.Z, 0, dir.X); if side:Dot(flat(ray.Normal)) < 0 then side = -side end; dir = (side + flat(ray.Normal) * 0.4).Unit end
		local np = head.pos + dir * spd * dt
		np = Vector3.new(math.clamp(np.X, -HX + m.r, HX - m.r), FLOOR + m.r, math.clamp(np.Z, -HZ + m.r, HZ - m.r))
		head.pos = np
		local look = flat(ppos) - flat(np); look = look.Magnitude > 0.1 and look.Unit or dir
		head.part.CFrame = CFrame.lookAt(np, np + look)
		-- босс стреляет огнём
		if m.boss then m.shootT -= dt; if m.shootT <= 0 then m.shootT = 2.4; local fb = P({ Shape = Enum.PartType.Ball, Name = "FireBall", Size = Vector3.new(1.8, 1.8, 1.8), Pos = np, Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, CanCollide = false }); table.insert(G.fire, { part = fb, pos = np, dir = look, life = 3 }) end end
	end
	for i = 2, #m.segs do local a, b = m.segs[i - 1], m.segs[i]; local d = b.pos - a.pos; local gap = (a.r + b.r) * 0.62; if d.Magnitude > gap then b.pos = a.pos + d.Unit * gap end; b.pos = Vector3.new(b.pos.X, FLOOR + b.r, b.pos.Z); b.part.CFrame = CFrame.lookAt(b.pos, a.pos) end
	-- ловушки бьют гусеницу
	if m.trapCd <= 0 and not G.result then
		for _, kind in ipairs({ "lava", "spikes", "cactus", "laser" }) do local z = zoneAt(head.pos, kind); if z and (kind ~= "laser" or z.on) then local pct = ({ lava = 0.08, spikes = 0.03, cactus = 0.02, laser = 0.04 })[kind]; m.hp -= math.max(5, m.maxHp * pct); m.trapCd = 0.8; say(G.player, "Гусеница наступила: " .. ({ lava = "лава!", spikes = "шипы!", cactus = "кактус!", laser = "лазер!" })[kind]); break end end
		if m.hp <= 0 then win() end
	end
	-- укус
	local dist = dxz(head.pos, ppos)
	if not G.result and m.frozen <= 0 and m.stun <= 0 and dist < m.r + 2 then
		if G.shieldT > 0 then m.stun = 0.6; say(G.player, "Щит!")
		elseif G.inv <= 0 then
			G.bitten = true; local wasSnake = m.snake > 0; local n = wasSnake and 11 or 20; if wasSnake then G.poison = 2 end
			m.snake = 0; m.stun = 0.7; hurtPlayer(n, wasSnake and "Ядовитый укус! -11" or ("Укус! -" .. n)); G.inv = 1
			head.pos = head.pos + (flat(head.pos) - flat(ppos)).Unit * 6
		end
	end
	-- замороженную толкаем
	if not G.result and m.frozen > 0 and dist < m.r + 3 then
		m.hp -= m.dmg; m.frozen = 0; setFrozenLook(m, false); m.stun = 0.6; shard(head.pos, Color3.fromRGB(190, 233, 255)); say(G.player, "ХРЯСЬ! -" .. m.dmg)
		head.pos = head.pos + (flat(head.pos) - flat(ppos)).Unit * 9
		if m.hp <= 0 then win() end
	end
	-- ледяные шары
	for i = #G.balls, 1, -1 do
		local b = G.balls[i]; b.life -= dt; local step = b.dir * 70 * dt
		local hitWall = workspace:Raycast(b.pos, step, G.rayParams)
		b.pos += step; b.part.CFrame = CFrame.new(b.pos)
		local hit = false
		for _, s in ipairs(m.segs) do if (s.pos - b.pos).Magnitude < s.r + 1.2 then hit = true break end end
		if hit then
			local blocked = false
			if m.boss and m.stun <= 0 then local face = head.part.CFrame.LookVector; local from = flat(b.pos - b.dir * 5) - flat(head.pos); if from.Magnitude > 0 and face:Dot(from.Unit) > 0.35 then blocked = true end end
			if blocked then say(G.player, "Щит босса! Зайди сбоку или сзади") else m.frozen = 5; m.stun = 5; setFrozenLook(m, true); say(G.player, "ЗАМЁРЗ на 5 секунд! Толкни его!") end
			b.part:Destroy(); table.remove(G.balls, i)
		elseif hitWall or b.life <= 0 then b.part:Destroy(); table.remove(G.balls, i) end
	end
	-- огонь босса
	for i = #G.fire, 1, -1 do
		local f = G.fire[i]; f.life -= dt; f.pos += f.dir * 40 * dt; f.part.CFrame = CFrame.new(f.pos)
		if dxz(f.pos, ppos) < 2.5 then hurtPlayer(15, "Огонь! -15"); f.part:Destroy(); table.remove(G.fire, i)
		elseif f.life <= 0 or workspace:Raycast(f.pos, f.dir * 2, G.rayParams) then f.part:Destroy(); table.remove(G.fire, i) end
	end
	syncT -= dt; if syncT <= 0 then syncT = 0.1; sync() end
end)

-- ───────── игроки ─────────
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function dressLeon(char)
	local K = kitByKey(G and G.kit or "barca")
	for _, o in ipairs(char:GetDescendants()) do if o:IsA("SurfaceGui") and o.Name == "Kit" then o:Destroy() end end
	local oldVip = char:FindFirstChild("Head") and char.Head:FindFirstChild("VIP"); if oldVip then oldVip:Destroy() end
	local bc = char:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors", char)
	bc.TorsoColor3 = rgb(K.torso); bc.LeftLegColor3 = rgb(K.legs); bc.RightLegColor3 = rgb(K.legs)
	bc.HeadColor3 = Color3.fromRGB(243, 214, 188); bc.LeftArmColor3 = Color3.fromRGB(243, 214, 188); bc.RightArmColor3 = Color3.fromRGB(243, 214, 188)
	for _, n in ipairs({ "Shirt", "Pants" }) do local o = char:FindFirstChildOfClass(n); if o then o:Destroy() end end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if torso then
		local sg = Instance.new("SurfaceGui"); sg.Name = "Kit"; sg.Face = Enum.NormalId.Back; sg.CanvasSize = Vector2.new(200, 200); sg.Parent = torso
		local f = Instance.new("Frame"); f.Size = UDim2.fromScale(1, 1); f.BackgroundTransparency = 1; f.Parent = sg
		for i = 0, 2 do local st = Instance.new("Frame"); st.Size = UDim2.new(0.16, 0, 1, 0); st.Position = UDim2.new(0.08 + i * 0.3, 0, 0, 0); st.BackgroundColor3 = rgb(K.stripe); st.BorderSizePixel = 0; st.Parent = f end
		local tl = Instance.new("TextLabel"); tl.Size = UDim2.new(1, 0, 0.3, 0); tl.BackgroundTransparency = 1; tl.Text = "LEON"; tl.TextColor3 = rgb(K.text); tl.TextScaled = true; tl.Font = Enum.Font.GothamBlack; tl.Parent = f
		local nl = tl:Clone(); nl.Text = "17"; nl.Position = UDim2.new(0, 0, 0.3, 0); nl.Size = UDim2.new(1, 0, 0.6, 0); nl.Parent = f
		local front = sg:Clone(); front.Face = Enum.NormalId.Front; front.Parent = torso; front.Frame.TextLabel:Destroy(); local fl = front.Frame:FindFirstChildOfClass("TextLabel"); if fl then fl.Size = UDim2.new(0.3, 0, 0.3, 0); fl.Position = UDim2.new(0.62, 0, 0.1, 0) end
	end
	if G and G.passes and G.passes.VIP and char:FindFirstChild("Head") then
		local bb = Instance.new("BillboardGui"); bb.Name = "VIP"; bb.Size = UDim2.new(0, 70, 0, 26); bb.StudsOffset = Vector3.new(0, 2.6, 0); bb.AlwaysOnTop = true; bb.Parent = char.Head
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundColor3 = Color3.fromRGB(255, 215, 0); t.Text = "VIP"; t.Font = Enum.Font.GothamBlack; t.TextScaled = true; t.TextColor3 = Color3.fromRGB(29, 63, 143); t.Parent = bb
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = t
	end
end

Players.PlayerAdded:Connect(function(plr)
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr
	local lv = Instance.new("IntValue"); lv.Name = "Level"; lv.Value = 1; lv.Parent = ls
	local co = Instance.new("IntValue"); co.Name = "Coins"; co.Value = 0; co.Parent = ls
	G = { player = plr, coins = 0, dashCd = 0, balls = {}, fire = {}, level = 1, best = 1, zones = {}, owned = {}, kit = "barca", passes = {}, loaded = false }
	local data = loadData(plr)
	G.level = data.level or 1; G.best = data.best or G.level; G.coins = data.coins or 0; G.owned = data.owned or {}; G.kit = data.kit or "barca"
	for key, ps in pairs(Config.Passes) do if ps.id > 0 then local ok, has = pcall(function() return MPS:UserOwnsGamePassAsync(plr.UserId, ps.id) end); G.passes[key] = ok and has or false end end
	if not ownsKit(G.kit) then G.kit = "barca" end
	G.loaded = true
	local function onChar(char)
		task.wait(0.2); dressLeon(char)
		local hum = char:WaitForChild("Humanoid"); hum.MaxHealth = math.huge; hum.Health = math.huge
		if not G.cat then buildLevel(G.level) else local hrp = char:WaitForChild("HumanoidRootPart"); hrp.CFrame = CFrame.new(SPAWN) end
	end
	plr.CharacterAdded:Connect(onChar)
	if plr.Character then task.spawn(onChar, plr.Character) end
end)
Players.PlayerRemoving:Connect(function(plr) if G and G.player == plr then saveData(); LevelFolder:ClearAllChildren(); G = nil end end)
game:BindToClose(function() saveData() end)
task.spawn(function() while true do task.wait(45); saveData() end end)

-- ───────── магазин: формы за монеты, пропуски и покупки за Robux ─────────
shopFn.OnServerInvoke = function(plr, action, arg)
	if not G or plr ~= G.player then return false, "Подожди" end
	if action == "buyKit" then
		local K = kitByKey(arg); if not K or K.pass then return false, "Эту форму открывает пропуск" end
		if ownsKit(arg) then return false, "Уже есть" end
		if G.coins < K.coins then return false, "Не хватает монет" end
		G.coins -= K.coins; table.insert(G.owned, K.key); G.kit = K.key; saveData(); sync()
		if plr.Character then dressLeon(plr.Character) end
		return true, "Куплена форма «" .. K.name .. "»"
	elseif action == "equipKit" then
		if not ownsKit(arg) then return false, "Сначала купи" end
		G.kit = arg; saveData(); sync(); if plr.Character then dressLeon(plr.Character) end
		return true, "Надета форма «" .. kitByKey(arg).name .. "»"
	end
	return false, "?"
end
MPS.PromptGamePassPurchaseFinished:Connect(function(plr, passId, bought)
	if not bought or not G or plr ~= G.player then return end
	for key, ps in pairs(Config.Passes) do if ps.id == passId then G.passes[key] = true; say(plr, "Спасибо! Пропуск «" .. ps.name .. "» открыт") end end
	if plr.Character then dressLeon(plr.Character) end; sync()
end)
MPS.ProcessReceipt = function(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	if not plr or not G or G.player ~= plr or not G.loaded then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key; for k, pr in pairs(Config.Products) do if pr.id == info.ProductId then key = k end end
	if not key then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local pr = Config.Products[key]
	if pr.coins then G.coins += pr.coins; say(plr, "+" .. pr.coins .. " монет — спасибо!")
	elseif key == "Revive" then
		if G.result == "lose" then G.result = nil; G.canRevive = false; G.lives = G.passes.ExtraHeart and 4 or 3; G.energy = 100; G.inv = 2; say(plr, "Воскрес! Играем дальше")
		else G.coins += 15; say(plr, "Воскрешение не понадобилось — +15 монет") end
	elseif key == "Energy" then G.energy = 100; say(plr, "Энергия полная!") end
	saveData(); sync()
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
