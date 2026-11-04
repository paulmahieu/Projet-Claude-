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
local TREE_ASSETS = { "Tree_Oak", "Tree_Pine", "Tree_Birch" }

function Models.tree(base: CFrame, variant: number, seed: number): Model
	local imported = Models.override(TREE_ASSETS[variant] or "Tree_Oak", base * CFrame.Angles(0, seed * 1.7, 0))
	if imported then
		-- Modèle importé : tout disparaît à la récolte sauf une souche générée.
		for _, inst in imported:GetDescendants() do
			if inst:IsA("BasePart") then
				inst:SetAttribute("Depletable", true)
			end
		end
		local stump = column(imported, "Stump", 1.2, 2.2, base, C.Bark, Enum.Material.Wood)
		imported.PrimaryPart = stump
		return imported
	end
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
	local imported = Models.override("Rock", base * CFrame.Angles(0, seed * 2.3, 0))
	if imported then
		for _, inst in imported:GetDescendants() do
			if inst:IsA("BasePart") then
				inst:SetAttribute("Depletable", true)
			end
		end
		local rubble = part(
			imported,
			"Rubble",
			Vector3.new(1.4, 0.7, 1.2),
			base * CFrame.new(-2, 0.35, 1.4),
			C.StoneDark,
			Enum.Material.Rock
		)
		imported.PrimaryPart = rubble
		return imported
	end
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
	-- Palette par palier : runique (violet), Éther (cyan), céleste (or et marbre).
	local palettes = {
		[2] = { Platform = C.StoneDark, Rune = C.RuneBlue, Material = Enum.Material.Slate },
		[3] = { Platform = Color3.fromRGB(40, 70, 95), Rune = C.Ether, Material = Enum.Material.Slate },
		[4] = { Platform = Color3.fromRGB(235, 230, 215), Rune = C.Rune, Material = Enum.Material.Marble },
	}
	local palette = palettes[math.min(tier, 4)] or palettes[2]
	if tier >= 2 then
		platform = part(
			m,
			"Platform",
			Vector3.new(5, 0.6, 5),
			base * CFrame.new(0, 0.3, 0),
			palette.Platform,
			palette.Material
		)
		rune = part(
			m,
			"Rune",
			Vector3.new(0.12, 4, 4),
			base * CFrame.new(0, 0.64, 0) * VERTICAL,
			palette.Rune,
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
				palette.Rune,
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
	local imported = Models.override("Structure_" .. id, base, size)
	if imported then
		imported.Name = id
		return imported
	end
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
		if i == 1 then
			continue -- 90° : emplacement du portail de la Rue des boss
		end
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

-- Tapis d'Éther : dalle bleu nuit, cristaux cyan flottants.
builders.EtherMats = function(m: Model, base: CFrame, size: Vector3)
	local sx, sz = size.X, size.Z
	part(
		m,
		"Floor",
		Vector3.new(sx, 0.3, sz),
		base * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(35, 55, 80),
		Enum.Material.Slate
	)
	part(
		m,
		"Edge",
		Vector3.new(sx, 0.08, 0.3),
		base * CFrame.new(0, 0.32, -sz / 2 + 0.3),
		C.Ether,
		Enum.Material.Neon,
		{
			CanCollide = false,
			NoShadow = true,
		}
	)
	for _, x in { -sx / 2 + 0.8, sx / 2 - 0.8 } do
		local pillar = base * CFrame.new(x, 0.3, sz / 2 - 0.8)
		part(m, "Pillar", Vector3.new(1, 3, 1), pillar * CFrame.new(0, 1.5, 0), C.StoneDark, Enum.Material.Slate)
		part(
			m,
			"Crystal",
			Vector3.new(0.9, 1.8, 0.9),
			pillar * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, math.rad(45), math.rad(10)),
			C.Ether,
			Enum.Material.Neon,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
	end
end

-- Tapis célestes : marbre blanc, arches dorées.
builders.CelestialMats = function(m: Model, base: CFrame, size: Vector3)
	local sx, sz = size.X, size.Z
	part(
		m,
		"Floor",
		Vector3.new(sx, 0.3, sz),
		base * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(240, 236, 225),
		Enum.Material.Marble
	)
	part(m, "Trim", Vector3.new(sx + 0.4, 0.2, sz + 0.4), base * CFrame.new(0, 0.05, 0), C.Rune, Enum.Material.Metal)
	local back = base * CFrame.new(0, 0.3, sz / 2 - 0.6)
	for _, x in { -sx / 2 + 0.8, sx / 2 - 0.8 } do
		column(m, "ArchPillar", 6, 0.9, back * CFrame.new(x, 0, 0), Color3.fromRGB(240, 236, 225), Enum.Material.Marble)
	end
	part(m, "ArchTop", Vector3.new(sx - 0.6, 0.8, 0.9), back * CFrame.new(0, 6.2, 0), C.Rune, Enum.Material.Metal)
	part(m, "Sun", Vector3.new(0.3, 2.2, 2.2), back * CFrame.new(0, 7.8, 0) * VERTICAL, C.Rune, Enum.Material.Neon, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		NoShadow = true,
	})
end

-- Remplacement par des modèles importés ---------------------------------------------------

--[[
	Si ServerStorage/Assets contient un modèle portant le nom attendu (ex. "Tree_Oak",
	"Rock", "Structure_Sawmill", "Boss_ForestGuardian"), il remplace le modèle généré.
	Sécurité (cahier §11) : tous les scripts du modèle importé sont supprimés avant usage.
	Le modèle est ancré, mis à l'échelle de l'emprise prévue et posé au sol.
	Guide : docs/ASSETS.md
]]
local ServerStorage = game:GetService("ServerStorage")

local function assetFolder(): Instance?
	return ServerStorage:FindFirstChild("Assets")
end

function Models.override(assetName: string, base: CFrame, footprint: Vector3?): Model?
	local folder = assetFolder()
	local source = folder and folder:FindFirstChild(assetName)
	if not source or not source:IsA("Model") then
		return nil
	end
	local m = source:Clone()
	for _, inst in m:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			inst:Destroy() -- jamais de script provenant d'un modèle externe
		elseif inst:IsA("BasePart") then
			inst.Anchored = true
		end
	end
	if footprint then
		local _, size = m:GetBoundingBox()
		local scale = math.min(footprint.X / math.max(size.X, 0.1), footprint.Z / math.max(size.Z, 0.1))
		if scale > 0 and math.abs(scale - 1) > 0.01 then
			m:ScaleTo(m:GetScale() * scale)
		end
	end
	m:PivotTo(base)
	local cf, size = m:GetBoundingBox()
	local offset = base.Position - cf.Position
	m:PivotTo(m:GetPivot() + Vector3.new(offset.X, offset.Y + size.Y / 2, offset.Z))
	return m
end

-- Œufs, portails, arènes, boss ----------------------------------------------------------------

-- Présentoir d'œuf : socle, œuf (ellipsoïde), anneau lumineux. Retourne model, socle.
function Models.eggStand(base: CFrame, color: Color3): (Model, BasePart)
	local m = newModel("EggStand")
	local plinth = column(m, "Plinth", 1.2, 5, base, C.StoneDark, Enum.Material.Cobblestone)
	column(m, "Cushion", 0.4, 3.6, base * CFrame.new(0, 1.2, 0), C.Cloth, Enum.Material.Fabric)
	-- Une boule Roblox reste toujours sphérique : l'ellipsoïde passe par un SpecialMesh.
	local egg =
		part(m, "Egg", Vector3.new(2.6, 3.4, 2.6), base * CFrame.new(0, 3.3, 0), color, Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	column(
		m,
		"Band",
		0.35,
		2.75,
		base * CFrame.new(0, 3.1, 0),
		color:Lerp(Color3.new(1, 1, 1), 0.45),
		Enum.Material.SmoothPlastic,
		{
			CanCollide = false,
			NoShadow = true,
		}
	)
	column(
		m,
		"Glow",
		0.1,
		4.6,
		base * CFrame.new(0, 1.22, 0),
		color,
		Enum.Material.Neon,
		{ CanCollide = false, NoShadow = true }
	)
	m.PrimaryPart = plinth
	return m, plinth
end

-- Portail : arche de pierre et voile lumineux. Retourne model, voile (porte l'invite).
function Models.portal(base: CFrame, color: Color3): (Model, BasePart)
	local m = newModel("Portal")
	part(m, "Step", Vector3.new(10, 0.6, 4), base * CFrame.new(0, 0.3, 0), C.StoneDark, Enum.Material.Cobblestone)
	for _, x in { -4, 4 } do
		part(m, "Pillar", Vector3.new(1.6, 9, 1.6), base * CFrame.new(x, 4.8, 0), C.Stone, Enum.Material.Cobblestone)
		part(m, "Cap", Vector3.new(2.2, 0.8, 2.2), base * CFrame.new(x, 9.6, 0), C.StoneLight, Enum.Material.Slate)
	end
	part(m, "Lintel", Vector3.new(10, 1.4, 1.8), base * CFrame.new(0, 10.4, 0), C.StoneLight, Enum.Material.Slate)
	part(
		m,
		"Keystone",
		Vector3.new(1.4, 1.4, 1.9),
		base * CFrame.new(0, 10.4, 0) * CFrame.Angles(0, 0, math.rad(45)),
		color,
		Enum.Material.Neon,
		{
			NoShadow = true,
		}
	)
	local veil = part(m, "Veil", Vector3.new(6.4, 8.6, 0.3), base * CFrame.new(0, 5, 0), color, Enum.Material.Neon, {
		CanCollide = false,
		Transparency = 0.45,
		NoShadow = true,
	})
	m.PrimaryPart = veil
	return m, veil
end

-- Arène circulaire : sol, bordure de pierres levées, torches. `center` au sol.
function Models.arena(center: CFrame, radius: number, accent: Color3, parent: Instance)
	part(
		parent,
		"ArenaFloor",
		Vector3.new(1.2, radius * 2, radius * 2),
		center * CFrame.new(0, 0.6, 0) * VERTICAL,
		C.StoneDark,
		Enum.Material.Slate,
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
	part(
		parent,
		"ArenaRing",
		Vector3.new(0.15, radius * 1.3, radius * 1.3),
		center * CFrame.new(0, 1.25, 0) * VERTICAL,
		accent,
		Enum.Material.Neon,
		{
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Transparency = 0.7,
			NoShadow = true,
		}
	)
	local count = 16
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local pos = center * CFrame.new(math.cos(angle) * (radius - 1.5), 1.2, math.sin(angle) * (radius - 1.5))
		if i % 4 ~= 0 then
			part(
				parent,
				"Standing",
				Vector3.new(2.5, 7 + (i % 3), 2),
				pos * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 3.5, 0),
				C.Stone,
				Enum.Material.Rock
			)
		else
			column(parent, "Torch", 4, 0.6, pos, C.WoodDark, Enum.Material.Wood)
			local flame = part(
				parent,
				"Flame",
				Vector3.new(1, 1.4, 1),
				pos * CFrame.new(0, 4.7, 0),
				Color3.fromRGB(255, 150, 60),
				Enum.Material.Neon,
				{
					CanCollide = false,
					NoShadow = true,
				}
			)
			local fire = Instance.new("Fire")
			fire.Size = 3
			fire.Heat = 4
			fire.Parent = flame
		end
	end
end

-- Boss. Retourne model, Root (pièce de référence, invisible).
function Models.boss(def, base: CFrame): (Model, BasePart)
	local override = Models.override("Boss_" .. def.Id, base, Vector3.new(16, 0, 16))
	local body = Color3.fromRGB(def.Colors.Body[1], def.Colors.Body[2], def.Colors.Body[3])
	local accent = Color3.fromRGB(def.Colors.Accent[1], def.Colors.Accent[2], def.Colors.Accent[3])
	local eyes = Color3.fromRGB(def.Colors.Eyes[1], def.Colors.Eyes[2], def.Colors.Eyes[3])
	local m = override or newModel(def.Id)
	local root = part(m, "Root", Vector3.new(8, 14, 8), base * CFrame.new(0, 7, 0), body, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
	})
	root.CanQuery = false
	if not override then
		if def.Kind == "Treant" then
			column(m, "Trunk", 12, 6, base, body, Enum.Material.Wood)
			for i, a in { 0, 2.1, 4.2 } do
				part(
					m,
					"Root" .. i,
					Vector3.new(6, 1.6, 1.6),
					base * CFrame.Angles(0, a, 0) * CFrame.new(3.5, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-20)),
					body:Lerp(Color3.new(0, 0, 0), 0.15),
					Enum.Material.Wood
				)
			end
			for _, side in { -1, 1 } do
				part(
					m,
					"Arm",
					Vector3.new(1.6, 8, 1.6),
					base * CFrame.new(side * 4.4, 8, 0) * CFrame.Angles(0, 0, math.rad(side * 35)),
					body,
					Enum.Material.Wood
				)
				ball(m, "Hand", 2.6, base * CFrame.new(side * 6.6, 4.8, 0), accent, Enum.Material.Grass)
			end
			ball(m, "Crown", 11, base * CFrame.new(0, 15, 0), accent, Enum.Material.Grass)
			ball(
				m,
				"Crown2",
				7,
				base * CFrame.new(3.5, 13.5, 2),
				accent:Lerp(Color3.new(1, 1, 0.6), 0.2),
				Enum.Material.Grass
			)
			for _, x in { -1.2, 1.2 } do
				part(
					m,
					"Eye",
					Vector3.new(0.9, 0.9, 0.3),
					base * CFrame.new(x, 9.5, -3.05),
					eyes,
					Enum.Material.Neon,
					{ NoShadow = true }
				)
			end
		else -- Golem
			part(
				m,
				"Legs",
				Vector3.new(6, 4, 3.5),
				base * CFrame.new(0, 2, 0),
				body:Lerp(Color3.new(0, 0, 0), 0.2),
				Enum.Material.Slate
			)
			part(m, "Torso", Vector3.new(9, 7, 5.5), base * CFrame.new(0, 7.5, 0), body, Enum.Material.Rock)
			part(
				m,
				"Head",
				Vector3.new(4, 3.2, 3.6),
				base * CFrame.new(0, 12.6, -0.5),
				body:Lerp(Color3.new(1, 1, 1), 0.1),
				Enum.Material.Rock
			)
			for _, side in { -1, 1 } do
				part(
					m,
					"Arm",
					Vector3.new(3, 8, 3),
					base * CFrame.new(side * 6.2, 6.5, 0) * CFrame.Angles(0, 0, math.rad(side * 10)),
					body,
					Enum.Material.Rock
				)
				part(
					m,
					"Fist",
					Vector3.new(3.6, 3, 3.6),
					base * CFrame.new(side * 6.8, 2.2, 0),
					body:Lerp(Color3.new(0, 0, 0), 0.25),
					Enum.Material.Slate
				)
			end
			for i = 1, 4 do
				part(
					m,
					"Crystal" .. i,
					Vector3.new(1, 2.6, 1),
					base
						* CFrame.new(-3 + i * 1.3, 11.5 + (i % 2) * 0.6, 2.2)
						* CFrame.Angles(math.rad(-25), 0, math.rad((i - 2.5) * 12)),
					accent,
					Enum.Material.Neon,
					{
						NoShadow = true,
					}
				)
			end
			for _, x in { -0.9, 0.9 } do
				part(
					m,
					"Eye",
					Vector3.new(0.8, 0.5, 0.3),
					base * CFrame.new(x, 12.8, -2.35),
					eyes,
					Enum.Material.Neon,
					{ NoShadow = true }
				)
			end
		end
	end
	m.PrimaryPart = root
	return m, root
end

-- Zone d'impact annoncée : disque rouge au sol. Retourne la pièce (à détruire après l'impact).
function Models.telegraph(parent: Instance, position: Vector3, radius: number): BasePart
	return part(
		parent,
		"Telegraph",
		Vector3.new(0.2, radius * 2, radius * 2),
		CFrame.new(position) * VERTICAL,
		Color3.fromRGB(255, 60, 40),
		Enum.Material.Neon,
		{
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Transparency = 0.55,
			NoShadow = true,
		}
	)
end

-- Rue des boss ---------------------------------------------------------------------------

--[[
	Construit la rue suspendue. `origin` : CFrame au sol du début de la rue, -Z local = sens
	de la marche. Retourne la liste des CFrames de porte (fin de chaque section, au sol).
]]
function Models.street(origin: CFrame, cfg, parent: Instance)
	local length = cfg.Sections * cfg.SectionLength
	local w = cfg.Width
	local gates = {}
	-- Parvis de départ (avant la section 1)
	part(
		parent,
		"StartPlaza",
		Vector3.new(w + 10, 2, 24),
		origin * CFrame.new(0, -1, 12),
		C.StoneLight,
		Enum.Material.Slate
	)
	for i = 1, cfg.Sections do
		local z0 = -(i - 1) * cfg.SectionLength
		local center = origin * CFrame.new(0, 0, z0 - cfg.SectionLength / 2)
		-- Pavage en damier doux (deux teintes de pierre par section)
		part(
			parent,
			"Road" .. i,
			Vector3.new(w, 2, cfg.SectionLength),
			center * CFrame.new(0, -1, 0),
			if i % 2 == 0 then C.Stone else C.StoneDark:Lerp(C.Stone, 0.4),
			Enum.Material.Cobblestone
		)
		part(
			parent,
			"Carpet" .. i,
			Vector3.new(6, 0.1, cfg.SectionLength - 2),
			center * CFrame.new(0, 0.05, 0),
			C.Cloth:Lerp(C.RoofDark, 0.4),
			Enum.Material.Fabric,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
		for _, side in { -1, 1 } do
			-- Murs latéraux avec créneaux (empêchent de tomber)
			part(
				parent,
				"Wall",
				Vector3.new(2, 6, cfg.SectionLength),
				center * CFrame.new(side * (w / 2 + 1), 3, 0),
				C.StoneDark,
				Enum.Material.Cobblestone
			)
			for k = 0, 3 do
				part(
					parent,
					"Merlon",
					Vector3.new(2.2, 1.6, 3),
					center * CFrame.new(side * (w / 2 + 1), 6.8, -cfg.SectionLength / 2 + 5 + k * 10),
					C.Stone,
					Enum.Material.Cobblestone
				)
			end
			-- Torche au milieu de la section
			local torch = center * CFrame.new(side * (w / 2 - 0.4), 3.5, 0)
			part(parent, "Sconce", Vector3.new(0.6, 1.4, 0.6), torch, C.WoodDark, Enum.Material.Wood)
			local flame = part(
				parent,
				"Flame",
				Vector3.new(0.8, 1, 0.8),
				torch * CFrame.new(0, 1.1, 0),
				Color3.fromRGB(255, 150, 60),
				Enum.Material.Neon,
				{
					CanCollide = false,
					NoShadow = true,
				}
			)
			if i % 2 == 1 then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 170, 90)
				light.Range = 14
				light.Parent = flame
			end
			-- Bannière
			part(
				parent,
				"Banner",
				Vector3.new(0.1, 3.2, 2),
				center
					* CFrame.new(side * (w / 2 - 0.05), 3.6, -cfg.SectionLength / 4)
					* CFrame.Angles(0, math.rad(90), 0),
				if i % 2 == 0 then C.ClothBlue else C.Cloth,
				Enum.Material.Fabric,
				{
					CanCollide = false,
				}
			)
		end
		-- Arche de fin de section
		local gate = origin * CFrame.new(0, 0, z0 - cfg.SectionLength)
		for _, side in { -1, 1 } do
			part(
				parent,
				"ArchPillar",
				Vector3.new(2.4, 12, 2.4),
				gate * CFrame.new(side * (w / 2 - 0.2), 6, 0),
				C.StoneLight,
				Enum.Material.Slate
			)
		end
		part(
			parent,
			"ArchTop",
			Vector3.new(w + 2, 2, 2.8),
			gate * CFrame.new(0, 12.5, 0),
			C.StoneLight,
			Enum.Material.Slate
		)
		part(
			parent,
			"ArchGem",
			Vector3.new(1.6, 1.6, 1.6),
			gate * CFrame.new(0, 12.5, -1.3) * CFrame.Angles(0, 0, math.rad(45)),
			C.Ether,
			Enum.Material.Neon,
			{
				NoShadow = true,
			}
		)
		table.insert(gates, gate)
	end
	-- Mur de fin
	part(
		parent,
		"EndWall",
		Vector3.new(w + 4, 12, 2),
		origin * CFrame.new(0, 6, -length - 2),
		C.StoneDark,
		Enum.Material.Cobblestone
	)
	return gates
end

-- Ennemi de la rue. Retourne model, Root (invisible, référence de position et de portée).
function Models.enemy(kind, base: CFrame, scale: number, patron: boolean): (Model, BasePart)
	local m = newModel(kind.Id)
	local c = Color3.fromRGB(kind.Color[1], kind.Color[2], kind.Color[3])
	local k = scale * (if patron then 1.8 else 1)
	local eye = if patron then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(255, 220, 90)
	local root = part(m, "Root", Vector3.new(2, 4, 2) * k, base * CFrame.new(0, 2 * k, 0), c, nil, {
		Transparency = 1,
		CanCollide = false,
	})
	root.CanQuery = false
	if kind.Id == "ShadowWolf" then
		part(m, "Body", Vector3.new(1.6, 1.4, 3) * k, base * CFrame.new(0, 1.6 * k, 0), c, Enum.Material.Fabric)
		part(
			m,
			"Head",
			Vector3.new(1.3, 1.2, 1.4) * k,
			base * CFrame.new(0, 2.2 * k, -1.9 * k),
			c,
			Enum.Material.Fabric
		)
		for _, x in { -0.35, 0.35 } do
			part(
				m,
				"Ear",
				Vector3.new(0.3, 0.6, 0.25) * k,
				base * CFrame.new(x * k, 3 * k, -1.8 * k),
				c,
				Enum.Material.Fabric
			)
			part(
				m,
				"Eye",
				Vector3.new(0.2, 0.2, 0.1) * k,
				base * CFrame.new(x * k, 2.35 * k, -2.62 * k),
				eye,
				Enum.Material.Neon,
				{ NoShadow = true }
			)
		end
		for _, p in { { -0.55, -1 }, { 0.55, -1 }, { -0.55, 1 }, { 0.55, 1 } } do
			part(
				m,
				"Leg",
				Vector3.new(0.4, 1, 0.4) * k,
				base * CFrame.new(p[1] * k, 0.5 * k, p[2] * k),
				c:Lerp(Color3.new(0, 0, 0), 0.2),
				Enum.Material.Fabric
			)
		end
	else
		local hunch = if kind.Id == "Ghoul" then CFrame.Angles(math.rad(-15), 0, 0) else CFrame.new()
		for _, x in { -0.45, 0.45 } do
			part(
				m,
				"Leg",
				Vector3.new(0.6, 1.8, 0.6) * k,
				base * CFrame.new(x * k, 0.9 * k, 0),
				c:Lerp(Color3.new(0, 0, 0), 0.25),
				Enum.Material.SmoothPlastic
			)
		end
		local torso = part(
			m,
			"Torso",
			Vector3.new(1.8, 1.8, 1) * k,
			base * CFrame.new(0, 2.7 * k, 0) * hunch,
			c,
			Enum.Material.SmoothPlastic
		)
		for _, x in { -1.25, 1.25 } do
			part(
				m,
				"Arm",
				Vector3.new(0.5, 1.7, 0.5) * k,
				torso.CFrame * CFrame.new(x * k, -0.2 * k, -0.2 * k) * CFrame.Angles(math.rad(-40), 0, 0),
				c,
				Enum.Material.SmoothPlastic
			)
		end
		local head = part(
			m,
			"Head",
			Vector3.new(1.2, 1.2, 1.2) * k,
			torso.CFrame * CFrame.new(0, 1.55 * k, -0.1 * k),
			c:Lerp(Color3.new(1, 1, 1), 0.1),
			Enum.Material.SmoothPlastic
		)
		for _, x in { -0.25, 0.25 } do
			part(
				m,
				"Eye",
				Vector3.new(0.22, 0.22, 0.1) * k,
				head.CFrame * CFrame.new(x * k, 0.1 * k, -0.62 * k),
				eye,
				Enum.Material.Neon,
				{ NoShadow = true }
			)
		end
		if kind.Id == "Goblin" then
			for _, x in { -1, 1 } do
				part(
					m,
					"Ear",
					Vector3.new(0.8, 0.25, 0.2) * k,
					head.CFrame * CFrame.new(x * 0.75 * k, 0.15 * k, 0) * CFrame.Angles(0, 0, math.rad(x * 20)),
					c,
					Enum.Material.SmoothPlastic
				)
			end
			part(
				m,
				"Club",
				Vector3.new(0.4, 2.2, 0.4) * k,
				torso.CFrame * CFrame.new(1.4 * k, -0.6 * k, -1 * k) * CFrame.Angles(math.rad(-60), 0, 0),
				C.WoodDark,
				Enum.Material.Wood
			)
		elseif kind.Id == "Skeleton" then
			for r = 1, 3 do
				part(
					m,
					"Rib",
					Vector3.new(1.9, 0.15, 1.05) * k,
					torso.CFrame * CFrame.new(0, (0.6 - r * 0.4) * k, 0),
					Color3.fromRGB(60, 55, 50),
					Enum.Material.SmoothPlastic,
					{
						NoShadow = true,
					}
				)
			end
			part(
				m,
				"Sword",
				Vector3.new(0.2, 2.6, 0.12) * k,
				torso.CFrame * CFrame.new(1.4 * k, -0.4 * k, -1.1 * k) * CFrame.Angles(math.rad(-60), 0, 0),
				C.Metal,
				Enum.Material.Metal
			)
		elseif kind.Id == "Ghoul" then
			part(
				m,
				"Hood",
				Vector3.new(1.4, 0.8, 1.4) * k,
				head.CFrame * CFrame.new(0, 0.55 * k, 0.1 * k),
				Color3.fromRGB(70, 60, 80),
				Enum.Material.Fabric
			)
		end
	end
	if patron then
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			part(
				m,
				"Crown" .. i,
				Vector3.new(0.35, 0.8, 0.35) * k,
				base
					* CFrame.new(
						math.cos(a) * 0.5 * k,
						(if kind.Id == "ShadowWolf" then 3.1 else 4.6) * k,
						math.sin(a) * 0.5 * k
					),
				C.Rune,
				Enum.Material.Neon,
				{
					NoShadow = true,
				}
			)
		end
	end
	m.PrimaryPart = root
	return m, root
end

return Models
