-- Арена «Двор»: пол с полосами, живая изгородь по краю, деревья вокруг, точка появления, свет
local ws = workspace
for _, n in ipairs({ "Baseplate", "SpawnLocation", "Arena", "Level" }) do local o = ws:FindFirstChild(n); if o then o:Destroy() end end
local arena = Instance.new("Folder"); arena.Name = "Arena"; arena.Parent = ws
local border = Instance.new("Folder"); border.Name = "Border"; border.Parent = arena
local function P(t)
	local p = Instance.new("Part"); p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if t.Shape then p.Shape = t.Shape end
	p.Size = t.Size; p.CFrame = t.CFrame or CFrame.new(t.Pos); p.Color = t.Color; p.Material = t.Material or Enum.Material.SmoothPlastic
	p.CanCollide = t.CanCollide ~= false; if t.Transparency then p.Transparency = t.Transparency end
	p.Name = t.Name or "Part"; p.Parent = t.Parent or arena; return p
end
local HX, HZ = 80, 54
P({ Name = "Floor", Size = Vector3.new(HX * 2 + 40, 2, HZ * 2 + 40), Pos = Vector3.new(0, 0, 0), Color = Color3.fromRGB(122, 190, 96), Material = Enum.Material.Grass })
for x = -HX, HX - 1, 16 do P({ Name = "Stripe", Size = Vector3.new(8, 0.05, HZ * 2), Pos = Vector3.new(x + 4, 1.03, 0), Color = Color3.fromRGB(140, 206, 112), Material = Enum.Material.Grass, CanCollide = false }) end
local hedge = Color3.fromRGB(58, 130, 54)
P({ Name = "HedgeN", Size = Vector3.new(HX * 2 + 6, 5, 3), Pos = Vector3.new(0, 3.5, -HZ - 1.5), Color = hedge, Material = Enum.Material.LeafyGrass, Parent = border })
P({ Name = "HedgeS", Size = Vector3.new(HX * 2 + 6, 5, 3), Pos = Vector3.new(0, 3.5, HZ + 1.5), Color = hedge, Material = Enum.Material.LeafyGrass, Parent = border })
P({ Name = "HedgeW", Size = Vector3.new(3, 5, HZ * 2), Pos = Vector3.new(-HX - 1.5, 3.5, 0), Color = hedge, Material = Enum.Material.LeafyGrass, Parent = border })
P({ Name = "HedgeE", Size = Vector3.new(3, 5, HZ * 2), Pos = Vector3.new(HX + 1.5, 3.5, 0), Color = hedge, Material = Enum.Material.LeafyGrass, Parent = border })
-- деревья вокруг арены
local trees = Instance.new("Folder"); trees.Name = "Trees"; trees.Parent = arena
for i = 0, 15 do
	local a = i / 16 * math.pi * 2; local x, z = math.cos(a) * (HX + 12), math.sin(a) * (HZ + 12)
	P({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 2, 2), CFrame = CFrame.new(x, 5, z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 74, 44), Material = Enum.Material.Wood, Parent = trees })
	P({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9), Pos = Vector3.new(x, 11, z), Color = Color3.fromRGB(70, 150, 62), Material = Enum.Material.LeafyGrass, Parent = trees })
	P({ Name = "Leaves2", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), Pos = Vector3.new(x + 2, 14, z - 1), Color = Color3.fromRGB(90, 170, 74), Material = Enum.Material.LeafyGrass, Parent = trees })
end
local sp = Instance.new("SpawnLocation"); sp.Name = "SpawnLocation"; sp.Anchored = true; sp.Size = Vector3.new(6, 0.4, 6); sp.CFrame = CFrame.new(-62, 1.2, 0); sp.Color = Color3.fromRGB(255, 224, 138); sp.Material = Enum.Material.SmoothPlastic; sp.Transparency = 0.3; sp.Neutral = true; sp.Duration = 0; sp.Parent = ws
local L = game:GetService("Lighting"); L.ClockTime = 14; L.Brightness = 2.5; L.Ambient = Color3.fromRGB(120, 120, 120); L.OutdoorAmbient = Color3.fromRGB(150, 150, 150); L.GlobalShadows = true
if not L:FindFirstChildOfClass("Atmosphere") then local at = Instance.new("Atmosphere"); at.Density = 0.25; at.Parent = L end
local lvl = Instance.new("Folder"); lvl.Name = "Level"; lvl.Parent = ws
game:GetService("StarterPlayer").CharacterWalkSpeed = 18
return "arena ok"
