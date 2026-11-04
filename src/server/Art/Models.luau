--[[
	Models : modèles 3D du jeu, construits par code à partir de pièces Roblox simples.

	Direction visuelle (cahier §13) : style épuré, silhouettes lisibles, bois / pierre /
	verdure / cristaux, magie mesurée. Aucun asset externe ni identifiant inventé : tout est
	reproductible et réinstallable à partir du code.

	Conventions :
	- Chaque fonction reçoit `base` : CFrame posé AU SOL, -Z = face avant (côté entrée/hub).
	- Les pièces sont ancrées. Peu de PointLight (coûteuses sur mobile).
	- Les pièces marquées `Depletable` disparaissent quand une ressource est récoltée.
	- Nombre de pièces surveillé : un bastion complet reste sous ~250 pièces.
]]

local Models = {}

-- Palette ------------------------------------------------------------------------------

local C = {
	Wood = Color3.fromRGB(124, 84, 50),
	WoodDark = Color3.fromRGB(88, 58, 36),
	WoodLight = Color3.fromRGB(170, 125, 80),
	Bark = Color3.fromRGB(96, 66, 42),
	Birch = Color3.fromRGB(225, 222, 210),
	Stone = Color3.fromRGB(150, 148, 142),
	StoneDark = Color3.fromRGB(108, 106, 104),
	StoneLight = Color3.fromRGB(190, 186, 176),
	Roof = Color3.fromRGB(150, 58, 48),
	RoofDark = Color3.fromRGB(112, 44, 38),
	Leaf1 = Color3.fromRGB(78, 150, 72),
	Leaf2 = Color3.fromRGB(58, 125, 60),
	Leaf3 = Color3.fromRGB(110, 175, 85),
	Pine = Color3.fromRGB(40, 105, 70),
	Straw = Color3.fromRGB(214, 178, 108),
	Cloth = Color3.fromRGB(170, 45, 45),
	ClothBlue = Color3.fromRGB(50, 90, 170),
	Metal = Color3.fromRGB(165, 168, 175),
	Rune = Color3.fromRGB(255, 205, 110),
	RuneBlue = Color3.fromRGB(140, 120, 255),
	Ether = Color3.fromRGB(110, 210, 255),
	Earth = Color3.fromRGB(140, 112, 80),
}
Models.Colors = C

-- Utilitaires --------------------------------------------------------------------------

local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- l'axe d'un cylindre Roblox est X

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material, props): BasePart
	local p = Instance.new(if props and props.Class then props.Class else "Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props and props.Shape then
		(p :: Part).Shape = props.Shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if props then
		if props.CanCollide ~= nil then
			p.CanCollide = props.CanCollide
		end
		if props.Transparency then
			p.Transparency = props.Transparency
		end
		if props.Depletable then
			p:SetAttribute("Depletable", true)
		end
	end
	p.CastShadow = not (props and props.NoShadow)
	p.Parent = parent
	return p
end
Models.part = part

-- Cylindre vertical (hauteur h, diamètre d) dont la BASE est en `cf`.
local function column(parent, name, h: number, d: number, cf: CFrame, color, material, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(h, d, d), cf * CFrame.new(0, h / 2, 0) * VERTICAL, color, material, props)
end

local function ball(parent, name, d: number, cf: CFrame, color, material, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	return part(parent, name, Vector3.new(d, d, d), cf, color, material, props)
end

-- Toit à deux pans (faîtage selon X). `cf` = centre de la base du toit.
local function gableRoof(parent, sx: number, sz: number, h: number, cf: CFrame, color)
	local half = sz / 2
	part(parent, "RoofA", Vector3.new(sx, h, half), cf * CFrame.new(0, h / 2, -half / 2), color, Enum.Material.Slate, {
		Class = "WedgePart",
	})
	part(
		parent,
		"RoofB",
		Vector3.new(sx, h, half),
		cf * CFrame.new(0, h / 2, half / 2) * CFrame.Angles(0, math.pi, 0),
		color,
		Enum.Material.Slate,
		{ Class = "WedgePart" }
	)
end

local function newModel(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

-- Petite variation déterministe (même rendu à chaque génération).
local function jitter(seed: number, amount: number): number
	return (math.noise(seed * 0.37, 1.3, 2.7)) * amount * 2
end

-- Ressources ---------------------------------------------------------------------------

-- variant : 1 = chêne, 2 = sapin, 3 = bouleau
function Models.tree(base: CFrame, variant: number, seed: number): Model
	local m = newModel("Tree")
	local turn = base * CFrame.Angles(0, seed * 1.7, 0)
	local scale = 1 + jitter(seed, 0.12)

	-- Souche : toujours visible (indique où la ressource repoussera).
	local stump = column(m, "Stump", 1.2, 2.2 * scale, turn, C.Bark, Enum.Material.Wood)
	part(
		m,
		"StumpTop",
		Vector3.new(0.2, 1.8 * scale, 1.8 * scale),
		turn * CFrame.new(0, 1.25, 0) * VERTICAL,
		C.WoodLight,
		Enum.Material.Wood,
		{
			Shape = Enum.PartType.Cylinder,
		}
	)

	if variant == 2 then
		column(
			m,
			"Trunk",
			4 * scale,
			1.4 * scale,
			turn * CFrame.new(0, 1.2, 0),
			C.Bark,
			Enum.Material.Wood,
			{ Depletable = true }
		)
		local tiers = { { 8, 3.2 }, { 6.2, 6 }, { 4.2, 8.6 }, { 2.2, 10.8 } }
		for i, t in tiers do
			part(
				m,
				"Needles" .. i,
				Vector3.new(t[1], 2.6, t[1]) * scale,
				turn * CFrame.new(0, t[2] * scale, 0) * CFrame.Angles(0, math.rad(45 * i), 0),
				if i % 2 == 0 then C.Pine else C.Pine:Lerp(C.Leaf2, 0.4),
				Enum.Material.Grass,
				{ Depletable = true }
			)
		end
	elseif variant == 3 then
		local trunk = column(
			m,
			"Trunk",
			7 * scale,
			1.1 * scale,
			turn * CFrame.new(0, 1.2, 0),
			C.Birch,
			Enum.Material.SmoothPlastic,
			{
				Depletable = true,
			}
		)
		for i = 1, 3 do -- marques sombres du bouleau
			part(
				m,
				"Mark" .. i,
				Vector3.new(0.3, 0.25, 1.15 * scale),
				trunk.CFrame * CFrame.new(-2 + i * 1.3, 0, 0) * CFrame.Angles(i, 0, 0),
				C.WoodDark,
				Enum.Material.SmoothPlastic,
				{
					Depletable = true,
					NoShadow = true,
				}
			)
		end
		ball(
			m,
			"Leaves1",
			5.5 * scale,
			turn * CFrame.new(0, 8.6 * scale, 0),
			C.Leaf3,
			Enum.Material.Grass,
			{ Depletable = true }
		)
		ball(
			m,
			"Leaves2",
			3.8 * scale,
			turn * CFrame.new(1.6, 7.4 * scale, 0.8),
			C.Leaf3:Lerp(C.Leaf1, 0.5),
			Enum.Material.Grass,
			{
				Depletable = true,
			}
		)
	else
		column(
			m,
			"Trunk",
			5 * scale,
			1.8 * scale,
			turn * CFrame.new(0, 1.2, 0),
			C.Bark,
			Enum.Material.Wood,
			{ Depletable = true }
		)
		part(
			m,
			"Branch",
			Vector3.new(2.6, 0.7, 0.7),
			turn * CFrame.new(1.4, 5, 0) * CFrame.Angles(0, 0, math.rad(35)),
			C.Bark,
			Enum.Material.Wood,
			{
				Depletable = true,
			}
		)
		ball(
			m,
			"Leaves1",
			6.5 * scale,
			turn * CFrame.new(0, 8 * scale, 0),
			C.Leaf1,
			Enum.Material.Grass,
			{ Depletable = true }
		)
		ball(
			m,
			"Leaves2",
			4.6 * scale,
			turn * CFrame.new(2.4, 7 * scale, 1),
			C.Leaf2,
			Enum.Material.Grass,
			{ Depletable = true }
		)
		ball(m, "Leaves3", 4.2 * scale, turn * CFrame.new(-2.2, 7.2 * scale, -1), C.Leaf3, Enum.Material.Grass, {
			Depletable = true,
		})
	end
	m.PrimaryPart = stump
	return m
end

function Models.rock(base: CFrame, seed: number): Model
	local m = newModel("Rock")
	local turn = base * CFrame.Angles(0, seed * 2.3, 0)
	local main = part(
		m,
		"Main",
		Vector3.new(4.6, 3.4, 4),
		turn * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(8), math.rad(20), math.rad(6)),
		C.Stone,
		Enum.Material.Rock,
		{ Depletable = true }
	)
	part(
		m,
		"Side",
		Vector3.new(2.8, 2.4, 2.6),
		turn * CFrame.new(2.4, 1.1, 0.8) * CFrame.Angles(math.rad(-10), math.rad(50), math.rad(12)),
		C.StoneDark,
		Enum.Material.Rock,
		{
			Depletable = true,
		}
	)
	part(
		m,
		"Top",
		Vector3.new(2.2, 1.6, 2),
		turn * CFrame.new(-0.6, 3.4, -0.3) * CFrame.Angles(math.rad(15), math.rad(-25), 0),
		C.StoneLight,
		Enum.Material.Rock,
		{
			Depletable = true,
		}
	)
	-- Gravats : toujours visibles.
	local rubble = part(
		m,
		"Rubble",
		Vector3.new(1.4, 0.7, 1.2),
		turn * CFrame.new(-2, 0.35, 1.4) * CFrame.Angles(0, 0.6, 0),
		C.StoneDark,
		Enum.Material.Rock
	)
	part(
		m,
		"Rubble2",
		Vector3.new(1, 0.5, 1),
		turn * CFrame.new(1.2, 0.25, -2) * CFrame.Angles(0, 1.2, 0),
		C.Stone,
		Enum.Material.Rock
	)
	m.PrimaryPart = main
	return m, rubble
end

-- Tapis d'entraînement ----------------------------------------------------------------

-- Retourne model, plateforme (porte le ProximityPrompt), rune (pulsation).
function Models.trainingMat(base: CFrame, tier: number): (Model, BasePart, BasePart)
	local m = newModel("Mat")
	local platform, rune
	if tier >= 2 then
		platform =
			part(m, "Platform", Vector3.new(5, 0.6, 5), base * CFrame.new(0, 0.3, 0), C.StoneDark, Enum.Material.Slate)
		rune = part(
			m,
			"Rune",
			Vector3.new(0.12, 4, 4),
			base * CFrame.new(0, 0.64, 0) * VERTICAL,
			C.RuneBlue,
			Enum.Material.Neon,
			{
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
				Transparency = 0.35,
				NoShadow = true,
			}
		)
		part(
			m,
			"RuneInner",
			Vector3.new(0.14, 2.4, 2.4),
			base * CFrame.new(0, 0.66, 0) * VERTICAL,
			C.StoneDark,
			Enum.Material.Slate,
			{
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
				NoShadow = true,
			}
		)
		for i, corner in { { -2.2, -2.2 }, { 2.2, -2.2 }, { -2.2, 2.2 }, { 2.2, 2.2 } } do
			local pylon = base * CFrame.new(corner[1], 0.6, corner[2])
			part(
				m,
				"Pylon" .. i,
				Vector3.new(0.6, 1.6, 0.6),
				pylon * CFrame.new(0, 0.8, 0),
				C.Stone,
				Enum.Material.Slate
			)
			part(
				m,
				"Shard" .. i,
				Vector3.new(0.45, 0.9, 0.45),
				pylon * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, math.rad(45), 0),
				C.RuneBlue,
				Enum.Material.Neon,
				{
					CanCollide = false,
					NoShadow = true,
				}
			)
		end
	else
		platform = part(
			m,
			"Platform",
			Vector3.new(5, 0.4, 5),
			base * CFrame.new(0, 0.2, 0),
			C.WoodDark,
			Enum.Material.WoodPlanks
		)
		part(m, "Straw", Vector3.new(3.8, 0.12, 3.8), base * CFrame.new(0, 0.46, 0), C.Straw, Enum.Material.Fabric, {
			CanCollide = false,
		})
		rune = part(
			m,
			"Rune",
			Vector3.new(0.1, 2, 2),
			base * CFrame.new(0, 0.53, 0) * VERTICAL,
			C.Rune,
			Enum.Material.Neon,
			{
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
				Transparency = 0.45,
				NoShadow = true,
			}
		)
		-- Cadre en rondins
		for i, side in { { 0, -2.4, 5, 0.5 }, { 0, 2.4, 5, 0.5 }, { -2.4, 0, 0.5, 4.3 }, { 2.4, 0, 0.5, 4.3 } } do
			part(
				m,
				"Frame" .. i,
				Vector3.new(side[3], 0.5, side[4]),
				base * CFrame.new(side[1], 0.45, side[2]),
				C.Wood,
				Enum.Material.Wood
			)
		end
	end

	-- Mannequin d'entraînement à l'arrière du tapis.
	local back = base * CFrame.new(0, 0, 3.4)
	column(m, "DummyPole", 4.6, 0.45, back, C.WoodDark, Enum.Material.Wood)
	part(m, "DummyArms", Vector3.new(2.8, 0.35, 0.35), back * CFrame.new(0, 3.4, 0), C.WoodDark, Enum.Material.Wood)
	part(
		m,
		"DummyBody",
		Vector3.new(1.5, 1.8, 0.9),
		back * CFrame.new(0, 3, 0),
		if tier >= 2 then C.ClothBlue else C.Straw,
		Enum.Material.Fabric
	)
	ball(m, "DummyHead", 1.1, back * CFrame.new(0, 4.5, 0), C.Straw, Enum.Material.Fabric)

	m.PrimaryPart = platform
	return m, platform, rune
end

-- Constructions -----------------------------------------------------------------------

local builders = {}

-- Terrain d'entraînement : sol de terre battue, clôture sur 3 côtés, râtelier, bannière.
builders.TrainingGround = function(m: Model, base: CFrame, size: Vector3)
	local sx, sz = size.X, size.Z
	part(m, "Floor", Vector3.new(sx, 0.3, sz), base * CFrame.new(0, 0.15, 0), C.Earth, Enum.Material.Ground)
	local postsX = math.floor(sx / 4)
	for i = 0, postsX do
		local x = -sx / 2 + i * (sx / postsX)
		column(m, "PostBack" .. i, 2.4, 0.5, base * CFrame.new(x, 0, sz / 2), C.Wood, Enum.Material.Wood)
	end
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			local z = -sz / 2 + 2 + i * ((sz - 2) / 2)
			column(
				m,
				"PostSide" .. side .. i,
				2.4,
				0.5,
				base * CFrame.new(side * sx / 2, 0, z),
				C.Wood,
				Enum.Material.Wood
			)
		end
		part(
			m,
			"RailSide" .. side,
			Vector3.new(0.25, 0.3, sz - 2),
			base * CFrame.new(side * sx / 2, 1.8, 1),
			C.WoodLight,
			Enum.Material.Wood
		)
	end
	part(m, "RailBack", Vector3.new(sx, 0.3, 0.25), base * CFrame.new(0, 1.8, sz / 2), C.WoodLight, Enum.Material.Wood)
	part(m, "RailBack2", Vector3.new(sx, 0.3, 0.25), base * CFrame.new(0, 0.9, sz / 2), C.WoodLight, Enum.Material.Wood)
	-- Râtelier d'armes
	local rack = base * CFrame.new(0, 0, sz / 2 - 1.2)
	part(m, "Rack", Vector3.new(3, 0.3, 0.6), rack * CFrame.new(0, 2.2, 0), C.WoodDark, Enum.Material.Wood)
	for i = -1, 1 do
		part(
			m,
			"Sword" .. i,
			Vector3.new(0.2, 3, 0.1),
			rack * CFrame.new(i * 0.9, 1.6, -0.2) * CFrame.Angles(0, 0, math.rad(8 * i)),
			C.Metal,
			Enum.Material.Metal
		)
	end
	-- Bannière
	local pole = base * CFrame.new(sx / 2 - 1, 0, -sz / 2 + 1)
	column(m, "BannerPole", 7, 0.35, pole, C.WoodDark, Enum.Material.Wood)
	part(
		m,
		"Banner",
		Vector3.new(0.1, 2.6, 1.6),
		pole * CFrame.new(0, 5.4, 0.85),
		C.Cloth,
		Enum.Material.Fabric,
		{ CanCollide = false }
	)
end

-- Palissade : rondins verticaux de hauteurs alternées + deux traverses.
builders.Palisade = function(m: Model, base: CFrame, size: Vector3)
	local sx, h = size.X, size.Y
	local d = 2.4
	local count = math.floor(sx / d)
	for i = 0, count - 1 do
		local x = -sx / 2 + d / 2 + i * d
		local logH = h + (if i % 2 == 0 then 0.8 else -0.4)
		column(
			m,
			"Log" .. i,
			logH,
			d,
			base * CFrame.new(x, 0, 0),
			if i % 3 == 0 then C.WoodDark else C.Wood,
			Enum.Material.Wood
		)
	end
	for i, y in { h * 0.3, h * 0.75 } do
		part(
			m,
			"Beam" .. i,
			Vector3.new(sx, 0.5, 0.4),
			base * CFrame.new(0, y, -d / 2 - 0.1),
			C.WoodDark,
			Enum.Material.Wood
		)
	end
end

-- Scierie : maison en bois, toit à deux pans, lame de scie, pile de rondins.
builders.Sawmill = function(m: Model, base: CFrame, size: Vector3)
	local sx, sy, sz = size.X, size.Y, size.Z
	local wallH = sy * 0.65
	part(
		m,
		"Walls",
		Vector3.new(sx, wallH, sz),
		base * CFrame.new(0, wallH / 2, 0),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)
	part(
		m,
		"Base",
		Vector3.new(sx + 0.6, 0.8, sz + 0.6),
		base * CFrame.new(0, 0.4, 0),
		C.StoneDark,
		Enum.Material.Cobblestone
	)
	gableRoof(m, sx + 1.2, sz + 1.2, sy - wallH + 1, base * CFrame.new(0, wallH, 0), C.Roof)
	part(
		m,
		"Door",
		Vector3.new(2.4, 3.6, 0.2),
		base * CFrame.new(0, 2.2, -sz / 2 - 0.05),
		C.WoodDark,
		Enum.Material.Wood
	)
	-- Lame de scie sur le côté
	local saw = base * CFrame.new(sx / 2 + 0.4, 3, 0)
	part(
		m,
		"SawBlade",
		Vector3.new(0.2, 4.4, 4.4),
		saw,
		C.Metal,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
	part(m, "SawHub", Vector3.new(0.5, 1, 1), saw, C.WoodDark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	-- Pile de rondins devant
	for i = 0, 2 do
		part(
			m,
			"Pile" .. i,
			Vector3.new(4, 1, 1),
			base
				* CFrame.new(
					-sx / 2 + 2.5,
					0.5 + (if i == 2 then 0.85 else 0),
					-sz / 2 - 1.6 + (if i == 2 then 0.5 else i)
				),
			C.Bark,
			Enum.Material.Wood,
			{
				Shape = Enum.PartType.Cylinder,
			}
		)
	end
end

-- Carrière : muret de pierre, blocs taillés, grue en bois.
builders.Quarry = function(m: Model, base: CFrame, size: Vector3)
	local sx, sz = size.X, size.Z
	part(m, "Pit", Vector3.new(sx - 1, 0.3, sz - 1), base * CFrame.new(0, 0.15, 0), C.StoneDark, Enum.Material.Slate)
	for i, w in { { 0, sz / 2, sx, 1 }, { -sx / 2, 0, 1, sz }, { sx / 2, 0, 1, sz } } do
		part(
			m,
			"Wall" .. i,
			Vector3.new(w[3], 1.6, w[4]),
			base * CFrame.new(w[1], 0.8, w[2]),
			C.Stone,
			Enum.Material.Cobblestone
		)
	end
	local blocks = { { -3, 1, 2.4 }, { -0.4, 1, 2.4 }, { -1.7, 1, 2.4, true }, { 3, 1, -2 } }
	for i, b in blocks do
		local y = if b[4] then 2.2 else 0.9
		part(
			m,
			"Block" .. i,
			Vector3.new(2.4, 1.6, 1.8),
			base * CFrame.new(b[1], y, b[3]),
			C.StoneLight,
			Enum.Material.Slate
		)
	end
	-- Grue
	local crane = base * CFrame.new(sx / 2 - 2, 0, sz / 2 - 2)
	column(m, "CraneMast", 8, 0.7, crane, C.Wood, Enum.Material.Wood)
	part(m, "CraneArm", Vector3.new(0.5, 0.5, 7), crane * CFrame.new(0, 7.6, -3), C.Wood, Enum.Material.Wood)
	part(m, "Rope", Vector3.new(0.12, 3.6, 0.12), crane * CFrame.new(0, 5.6, -6.2), C.Straw, Enum.Material.Fabric, {
		CanCollide = false,
	})
	part(m, "Load", Vector3.new(1.6, 1.2, 1.4), crane * CFrame.new(0, 3.3, -6.2), C.StoneLight, Enum.Material.Slate)
end

-- Tapis runiques : dallage sombre, lignes de runes, obélisques aux coins.
builders.RuneMats = function(m: Model, base: CFrame, size: Vector3)
	local sx, sz = size.X, size.Z
	part(m, "Floor", Vector3.new(sx, 0.3, sz), base * CFrame.new(0, 0.15, 0), C.StoneDark, Enum.Material.Slate)
	part(
		m,
		"Line",
		Vector3.new(sx - 2, 0.05, 0.25),
		base * CFrame.new(0, 0.32, -sz / 2 + 1),
		C.RuneBlue,
		Enum.Material.Neon,
		{
			CanCollide = false,
			NoShadow = true,
		}
	)
	for _, sxSign in { -1, 1 } do
		for _, szSign in { -1, 1 } do
			local corner = base * CFrame.new(sxSign * (sx / 2 - 1), 0.3, szSign * (sz / 2 - 1))
			part(m, "Obelisk", Vector3.new(1, 4, 1), corner * CFrame.new(0, 2, 0), C.Stone, Enum.Material.Slate)
			part(
				m,
				"ObeliskTip",
				Vector3.new(0.7, 1.2, 0.7),
				corner * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, math.rad(45), 0),
				C.RuneBlue,
				Enum.Material.Neon,
				{
					NoShadow = true,
				}
			)
		end
	end
end

-- Tour de guet : fût de pierre, plateforme en bois, créneaux, toit pointu, drapeau.
builders.Watchtower = function(m: Model, base: CFrame, size: Vector3)
	local w, h = size.X, size.Y
	local shaftH = h * 0.7
	part(
		m,
		"Plinth",
		Vector3.new(w + 1, 1, w + 1),
		base * CFrame.new(0, 0.5, 0),
		C.StoneDark,
		Enum.Material.Cobblestone
	)
	part(m, "Shaft", Vector3.new(w, shaftH, w), base * CFrame.new(0, shaftH / 2, 0), C.Stone, Enum.Material.Cobblestone)
	part(
		m,
		"Window",
		Vector3.new(1, 2, 0.2),
		base * CFrame.new(0, shaftH * 0.6, -w / 2 - 0.05),
		C.WoodDark,
		Enum.Material.Wood
	)
	local deckY = shaftH
	part(
		m,
		"Deck",
		Vector3.new(w + 3, 0.8, w + 3),
		base * CFrame.new(0, deckY + 0.4, 0),
		C.Wood,
		Enum.Material.WoodPlanks
	)
	local half = (w + 3) / 2 - 0.4
	for _, c in { { -half, -half }, { half, -half }, { -half, half }, { half, half } } do
		part(
			m,
			"Merlon",
			Vector3.new(0.8, 1.6, 0.8),
			base * CFrame.new(c[1], deckY + 1.6, c[2]),
			C.StoneLight,
			Enum.Material.Cobblestone
		)
		column(m, "Pillar", 3.2, 0.4, base * CFrame.new(c[1], deckY + 0.8, c[2]), C.WoodDark, Enum.Material.Wood)
	end
	-- Toit pointu en étages (pyramide à gradins)
	local roofY = deckY + 4
	for i, sz in { w + 4, w + 2, w, w - 2.5, 1.5 } do
		part(
			m,
			"Roof" .. i,
			Vector3.new(sz, 1, sz),
			base * CFrame.new(0, roofY + (i - 1) * 0.9, 0),
			if i % 2 == 0 then C.RoofDark else C.Roof,
			Enum.Material.Slate
		)
	end
	local flag = base * CFrame.new(0, roofY + 4, 0)
	column(m, "FlagPole", 3, 0.25, flag, C.WoodDark, Enum.Material.Wood)
	part(
		m,
		"Flag",
		Vector3.new(0.1, 1.2, 2),
		flag * CFrame.new(0, 2.3, 1),
		C.ClothBlue,
		Enum.Material.Fabric,
		{ CanCollide = false }
	)
end

-- Construit le modèle d'une construction. `base` au sol, centre de l'emprise.
function Models.structure(id: string, base: CFrame, size: Vector3, fallbackColor: Color3, fallbackMaterial): Model
	local m = newModel(id)
	local builder = builders[id]
	if builder then
		builder(m, base, size)
	else
		-- Construction sans modèle dédié : bloc simple (aucune erreur si la config évolue).
		part(m, "Body", size, base * CFrame.new(0, size.Y / 2, 0), fallbackColor, fallbackMaterial)
	end
	-- PrimaryPart : la pièce la plus haute sert d'ancre aux étiquettes.
	local top, topY = nil, -math.huge
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.CFrame.Position.Y > topY then
			top, topY = p, p.CFrame.Position.Y
		end
	end
	m.PrimaryPart = top
	return m
end

-- Noyau d'Éther, socle d'achat, décor ---------------------------------------------------

-- Retourne model, cristal (porte l'étiquette).
function Models.etherCore(base: CFrame): (Model, BasePart)
	local m = newModel("EtherCore")
	column(m, "Base", 1, 7, base, C.StoneDark, Enum.Material.Cobblestone)
	column(m, "Step", 0.8, 5, base * CFrame.new(0, 1, 0), C.Stone, Enum.Material.Cobblestone)
	column(m, "Ring", 0.15, 4.2, base * CFrame.new(0, 1.8, 0), C.Ether, Enum.Material.Neon, { NoShadow = true })
	local crystal = part(
		m,
		"Crystal",
		Vector3.new(2.6, 2.6, 2.6),
		base * CFrame.new(0, 5.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Ether,
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2
		part(
			m,
			"Shard" .. i,
			Vector3.new(0.7, 1.4, 0.7),
			base
				* CFrame.new(math.cos(angle) * 2.6, 4.4 + (i % 2) * 0.8, math.sin(angle) * 2.6)
				* CFrame.Angles(0, angle, math.rad(20)),
			C.Ether:Lerp(Color3.new(1, 1, 1), 0.3),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true }
		)
	end
	local light = Instance.new("PointLight")
	light.Color = C.Ether
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = crystal
	m.PrimaryPart = crystal
	return m, crystal
end

-- Socle de construction : colonne de pierre + gemme flottante (couleur = état).
function Models.pedestal(base: CFrame): (Model, BasePart, BasePart)
	local m = newModel("Pedestal")
	local plinth =
		part(m, "Plinth", Vector3.new(2.4, 2, 2.4), base * CFrame.new(0, 1, 0), C.Stone, Enum.Material.Cobblestone)
	part(m, "Cap", Vector3.new(2.8, 0.4, 2.8), base * CFrame.new(0, 2.2, 0), C.StoneLight, Enum.Material.Slate)
	local gem = part(
		m,
		"Gem",
		Vector3.new(1.1, 1.1, 1.1),
		base * CFrame.new(0, 3.3, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Ether,
		Enum.Material.Neon,
		{
			CanCollide = false,
			NoShadow = true,
		}
	)
	m.PrimaryPart = plinth
	return m, plinth, gem
end

function Models.lantern(base: CFrame, parent: Instance, withLight: boolean?)
	column(parent, "LanternPost", 5, 0.4, base, C.WoodDark, Enum.Material.Wood)
	part(
		parent,
		"LanternArm",
		Vector3.new(1.2, 0.25, 0.25),
		base * CFrame.new(0.5, 4.8, 0),
		C.WoodDark,
		Enum.Material.Wood
	)
	local glow =
		part(parent, "Lantern", Vector3.new(0.7, 0.9, 0.7), base * CFrame.new(1, 4.2, 0), C.Rune, Enum.Material.Neon, {
			CanCollide = false,
			NoShadow = true,
		})
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = C.Rune
		light.Range = 12
		light.Parent = glow
	end
end

function Models.bush(base: CFrame, parent: Instance, seed: number)
	local s = 1 + jitter(seed, 0.25)
	ball(parent, "Bush", 3 * s, base * CFrame.new(0, 1 * s, 0), C.Leaf2, Enum.Material.Grass)
	ball(parent, "Bush", 2.2 * s, base * CFrame.new(1.2, 0.8 * s, 0.6), C.Leaf1, Enum.Material.Grass)
end

-- Bordure basse et lanternes d'entrée d'une parcelle.
function Models.plotDecor(base: CFrame, plotSize: number, parent: Instance)
	local half = plotSize / 2
	for i, edge in { { 0, half, plotSize, 1 }, { -half, 0, 1, plotSize }, { half, 0, 1, plotSize } } do
		part(
			parent,
			"Curb" .. i,
			Vector3.new(edge[3], 0.8, edge[4]),
			base * CFrame.new(edge[1], 0.4, edge[2]),
			C.StoneDark,
			Enum.Material.Cobblestone
		)
	end
	-- Entrée : bordure ouverte au centre
	local seg = (plotSize - 12) / 2
	for _, sign in { -1, 1 } do
		part(
			parent,
			"CurbFront",
			Vector3.new(seg, 0.8, 1),
			base * CFrame.new(sign * (6 + seg / 2), 0.4, -half),
			C.StoneDark,
			Enum.Material.Cobblestone
		)
		Models.lantern(base * CFrame.new(sign * 6.5, 0, -half), parent, false)
	end
end

-- Décor du hub : puits central décoratif autour du point d'apparition, lanternes, bannières.
function Models.hubDecor(parent: Instance, radius: number)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + math.pi / 6
		local pos = CFrame.new(math.cos(angle) * (radius - 3), 1, math.sin(angle) * (radius - 3))
		Models.lantern(CFrame.lookAt(pos.Position, Vector3.new(0, 1, 0)), parent, i % 2 == 0)
	end
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
		local pos = Vector3.new(math.cos(angle) * 10, 1, math.sin(angle) * 10)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 1, 0))
		column(parent, "BannerPole", 8, 0.4, cf, C.WoodDark, Enum.Material.Wood)
		part(
			parent,
			"Banner",
			Vector3.new(2, 3.4, 0.1),
			cf * CFrame.new(0, 6, -0.3),
			if i % 2 == 0 then C.ClothBlue else C.Cloth,
			Enum.Material.Fabric,
			{
				CanCollide = false,
			}
		)
	end
end

return Models
