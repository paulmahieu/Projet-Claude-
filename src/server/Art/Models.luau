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

-- Marbre et or des éléments « célestes » (portails, point d'accueil).
local MARBLE = Color3.fromRGB(236, 232, 222)
local MARBLE_SHADE = Color3.fromRGB(205, 200, 190)
local GOLD = Color3.fromRGB(222, 176, 64)

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

-- Feuillage « en touffes » (style des captures) : surfaces lisses, sans texture bruitée ;
-- le relief vient des boules qui se chevauchent et de trois teintes (dessous sombre,
-- cœur, dessus éclairé).
local LEAF_MAT = Enum.Material.SmoothPlastic
local LEAF_LIGHT = Color3.fromRGB(196, 232, 120)
local OAK_LEAVES = {
	Dark = Color3.fromRGB(48, 122, 58),
	Mid = Color3.fromRGB(72, 158, 66),
	Light = Color3.fromRGB(118, 196, 84),
}
local BIRCH_LEAVES = {
	Dark = Color3.fromRGB(104, 160, 66),
	Mid = Color3.fromRGB(140, 192, 78),
	Light = Color3.fromRGB(190, 218, 104),
}
local PINE_SHADES = {
	Color3.fromRGB(46, 112, 78),
	Color3.fromRGB(56, 128, 84),
	Color3.fromRGB(42, 104, 74),
	Color3.fromRGB(60, 136, 88),
}

-- Une touffe : boule centrale, couronne de boules autour (dessous sombre), petites
-- touffes au-dessus (éclairées). `center` = centre de la touffe, `r` = rayon.
local function crown(m: Model, center: CFrame, r: number, palette, seed: number)
	ball(m, "Leaves", r * 2, center, palette.Mid, LEAF_MAT, { Depletable = true })
	-- Dessous : anneau aplati, plus sombre (ombre de la couronne).
	local n = 6
	for j = 1, n do
		local a = (j / n) * math.pi * 2 + seed * 0.7
		local size = r * (1.05 + 0.15 * math.sin(seed + j * 1.9))
		ball(
			m,
			"LeavesLow" .. j,
			size,
			center * CFrame.new(math.cos(a) * r * 0.8, -r * 0.35, math.sin(a) * r * 0.8),
			palette.Dark,
			LEAF_MAT,
			{ Depletable = true, NoShadow = true }
		)
	end
	-- Milieu : touffes qui débordent, teinte du cœur.
	for j = 1, 5 do
		local a = (j / 5) * math.pi * 2 + seed * 1.3 + 0.6
		ball(
			m,
			"LeavesMid" .. j,
			r * 1.15,
			center * CFrame.new(math.cos(a) * r * 0.75, r * 0.2, math.sin(a) * r * 0.75),
			palette.Mid,
			LEAF_MAT,
			{ Depletable = true, NoShadow = true }
		)
	end
	-- Dessus : petites touffes éclairées.
	for j = 1, 3 do
		local a = (j / 3) * math.pi * 2 + seed * 2.1
		ball(
			m,
			"LeavesTop" .. j,
			r * 0.85,
			center * CFrame.new(math.cos(a) * r * 0.38, r * 0.72, math.sin(a) * r * 0.38),
			palette.Light,
			LEAF_MAT,
			{ Depletable = true, NoShadow = true }
		)
	end
end

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

	-- Anneaux de croissance sur la souche
	part(
		m,
		"StumpRing",
		Vector3.new(0.22, 1.1 * scale, 1.1 * scale),
		turn * CFrame.new(0, 1.27, 0) * VERTICAL,
		C.Bark:Lerp(C.WoodLight, 0.45),
		Enum.Material.Wood,
		{
			Shape = Enum.PartType.Cylinder,
			NoShadow = true,
		}
	)
	-- Racines évasées (toujours visibles, ancrent la souche au sol)
	for r = 1, 4 do
		local a = r * math.pi / 2 + seed
		part(
			m,
			"Root" .. r,
			Vector3.new(1.6, 0.6, 0.7) * scale,
			turn * CFrame.Angles(0, a, 0) * CFrame.new(1.2 * scale, 0.25, 0) * CFrame.Angles(0, 0, math.rad(-18)),
			C.Bark:Lerp(C.WoodDark, 0.3),
			Enum.Material.Wood
		)
	end

	if variant == 2 then
		-- Sapin stylisé : cône de touffes (5 étages de boules qui rétrécissent vers la pointe).
		column(m, "Trunk", 5 * scale, 1.2 * scale, turn * CFrame.new(0, 1.2, 0), C.Bark, Enum.Material.Wood, {
			Depletable = true,
		})
		local tiers = 5
		for k = 1, tiers do
			local t = (k - 1) / (tiers - 1) -- 0 en bas, 1 en haut
			local d = (6.4 - t * 4.2) * scale
			local y = (4.6 + t * 8.4) * scale
			local shade = PINE_SHADES[((k - 1) % #PINE_SHADES) + 1]
			ball(m, "Needles" .. k, d, turn * CFrame.new(0, y, 0), shade, LEAF_MAT, { Depletable = true })
			-- Couronne de touffes plus sombres sous chaque étage (silhouette de sapin).
			local n = 7 - math.floor(t * 3)
			for j = 1, n do
				local a = (j / n) * math.pi * 2 + k * 0.6 + seed
				ball(
					m,
					"Tuft" .. k .. "_" .. j,
					d * 0.55,
					turn * CFrame.new(math.cos(a) * d * 0.42, y - d * 0.22, math.sin(a) * d * 0.42),
					shade:Lerp(Color3.new(0, 0, 0), 0.15),
					LEAF_MAT,
					{ Depletable = true, NoShadow = true }
				)
			end
			-- Reflet clair sur le dessus.
			ball(
				m,
				"Cap" .. k,
				d * 0.55,
				turn * CFrame.new(d * 0.12, y + d * 0.28, -d * 0.1),
				shade:Lerp(LEAF_LIGHT, 0.22),
				LEAF_MAT,
				{ Depletable = true, NoShadow = true }
			)
		end
		ball(
			m,
			"Tip",
			1.4 * scale,
			turn * CFrame.new(0, 14.6 * scale, 0),
			PINE_SHADES[1]:Lerp(LEAF_LIGHT, 0.3),
			LEAF_MAT,
			{ Depletable = true }
		)
	elseif variant == 3 then
		-- Bouleau : tronc fin blanc à marques sombres, feuillage clair en 3 touffes étagées.
		column(m, "Trunk", 9 * scale, 1 * scale, turn * CFrame.new(0, 1.2, 0), C.Birch, Enum.Material.SmoothPlastic, {
			Depletable = true,
		})
		for k = 1, 7 do
			local y = 2 + k * 1.05
			local a = k * 2.4
			part(
				m,
				"Mark" .. k,
				Vector3.new(0.45, 0.18, 0.1) * scale,
				turn
					* CFrame.new(math.cos(a) * 0.5 * scale, y * scale, math.sin(a) * 0.5 * scale)
					* CFrame.Angles(0, -a + math.pi / 2, 0),
				C.WoodDark,
				Enum.Material.SmoothPlastic,
				{ Depletable = true, NoShadow = true }
			)
		end
		crown(m, turn * CFrame.new(0, 11 * scale, 0), 3.4 * scale, BIRCH_LEAVES, seed)
		crown(m, turn * CFrame.new(1.4 * scale, 8.8 * scale, 0.4 * scale), 2.6 * scale, BIRCH_LEAVES, seed + 3)
		crown(m, turn * CFrame.new(-1.3 * scale, 9.4 * scale, -0.6 * scale), 2.4 * scale, BIRCH_LEAVES, seed + 7)
	else
		-- Chêne : tronc en deux sections et branches, couronne en touffes (une grosse, deux lobes).
		column(m, "Trunk", 4 * scale, 1.9 * scale, turn * CFrame.new(0, 1.2, 0), C.Bark, Enum.Material.Wood, {
			Depletable = true,
		})
		column(
			m,
			"TrunkUpper",
			2.6 * scale,
			1.4 * scale,
			turn * CFrame.new(0.15, 5, 0) * CFrame.Angles(0, 0, math.rad(-6)),
			C.Bark,
			Enum.Material.Wood,
			{ Depletable = true }
		)
		for k, b in { { 1.6, 5.4, 0, 35 }, { -1.5, 5.8, 0.4, -40 }, { 0.2, 6.2, -1.5, 0 } } do
			part(
				m,
				"Branch" .. k,
				Vector3.new(0.6, 2.8, 0.6) * scale,
				turn
					* CFrame.new(b[1] * scale, b[2] * scale, b[3] * scale)
					* CFrame.Angles(math.rad(if b[4] == 0 then 30 else 0), 0, math.rad(-b[4])),
				C.Bark,
				Enum.Material.Wood,
				{ Depletable = true }
			)
		end
		crown(m, turn * CFrame.new(0, 9.4 * scale, 0), 4.6 * scale, OAK_LEAVES, seed)
		crown(m, turn * CFrame.new(3 * scale, 8.2 * scale, 0.8 * scale), 3 * scale, OAK_LEAVES, seed + 5)
		crown(m, turn * CFrame.new(-2.8 * scale, 8.4 * scale, -1 * scale), 3.2 * scale, OAK_LEAVES, seed + 9)
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
	-- Bloc principal facetté (3 volumes imbriqués) + éclats + mousse + gravats
	local main = part(
		m,
		"Main",
		Vector3.new(4.4, 3.2, 3.8),
		turn * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(8), math.rad(20), math.rad(6)),
		C.Stone,
		Enum.Material.Rock,
		{
			Depletable = true,
		}
	)
	part(
		m,
		"Facet1",
		Vector3.new(3.6, 2.6, 3.2),
		turn * CFrame.new(0.4, 2.1, 0.2) * CFrame.Angles(math.rad(-14), math.rad(55), math.rad(10)),
		C.Stone:Lerp(C.StoneLight, 0.3),
		Enum.Material.Rock,
		{
			Depletable = true,
		}
	)
	part(
		m,
		"Facet2",
		Vector3.new(2.8, 2.2, 2.6),
		turn * CFrame.new(2.2, 1, 0.9) * CFrame.Angles(math.rad(-10), math.rad(48), math.rad(14)),
		C.StoneDark,
		Enum.Material.Rock,
		{
			Depletable = true,
		}
	)
	part(
		m,
		"Facet3",
		Vector3.new(2.2, 1.8, 2),
		turn * CFrame.new(-1.9, 0.9, -1) * CFrame.Angles(math.rad(12), math.rad(-30), math.rad(-8)),
		C.Stone:Lerp(C.StoneDark, 0.5),
		Enum.Material.Rock,
		{
			Depletable = true,
		}
	)
	part(
		m,
		"Top",
		Vector3.new(2, 1.4, 1.8),
		turn * CFrame.new(-0.5, 3.4, -0.2) * CFrame.Angles(math.rad(15), math.rad(-25), 0),
		C.StoneLight,
		Enum.Material.Rock,
		{
			Depletable = true,
		}
	)
	part(
		m,
		"Moss",
		Vector3.new(2.4, 0.25, 2),
		turn * CFrame.new(0.2, 3.25, 0.3) * CFrame.Angles(math.rad(8), math.rad(20), math.rad(6)),
		C.Leaf2,
		Enum.Material.Grass,
		{
			Depletable = true,
			NoShadow = true,
		}
	)
	part(
		m,
		"Vein",
		Vector3.new(0.25, 0.25, 2.6),
		turn * CFrame.new(1.2, 1.7, -1.85) * CFrame.Angles(math.rad(8), math.rad(20), math.rad(30)),
		C.StoneLight:Lerp(Color3.new(1, 1, 1), 0.4),
		Enum.Material.Slate,
		{
			Depletable = true,
			NoShadow = true,
		}
	)
	-- Gravats : toujours visibles (emplacement de repousse)
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
	part(
		m,
		"Rubble3",
		Vector3.new(0.7, 0.4, 0.8),
		turn * CFrame.new(2.6, 0.2, 1.8) * CFrame.Angles(0.3, 0.4, 0),
		C.StoneLight,
		Enum.Material.Rock
	)
	local _ = main
	m.PrimaryPart = rubble
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

-- Palissade : rondins aux pointes taillées, hauteurs alternées, traverses cloutées à
-- l'extérieur et chemin de ronde à l'intérieur (-Z = vers le centre de la parcelle).
builders.Palisade = function(m: Model, base: CFrame, size: Vector3)
	local sx, h = size.X, size.Y
	local d = 2.4
	local count = math.floor(sx / d)
	for i = 0, count - 1 do
		local x = -sx / 2 + d / 2 + i * d
		local logH = h + (if i % 2 == 0 then 0.8 else -0.2)
		local color = if i % 3 == 0 then C.WoodDark elseif i % 3 == 1 then C.Wood else C.Bark
		column(m, "Log" .. i, logH, d, base * CFrame.new(x, 0, 0), color, Enum.Material.Wood)
		part(
			m,
			"Tip" .. i,
			Vector3.new(d * 0.72, d * 0.72, d * 0.72),
			base * CFrame.new(x, logH + 0.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			color:Lerp(C.WoodLight, 0.25),
			Enum.Material.Wood
		)
	end
	for i, y in { h * 0.28, h * 0.72 } do
		part(
			m,
			"Beam" .. i,
			Vector3.new(sx, 0.5, 0.45),
			base * CFrame.new(0, y, d / 2 + 0.1),
			C.WoodDark,
			Enum.Material.Wood
		)
		for k = 0, math.floor(sx / 8) do
			part(
				m,
				"Rivet",
				Vector3.new(0.25, 0.25, 0.1),
				base * CFrame.new(-sx / 2 + 2 + k * 8, y, d / 2 + 0.38),
				C.Metal,
				Enum.Material.Metal,
				{
					NoShadow = true,
				}
			)
		end
	end
	part(
		m,
		"Walkway",
		Vector3.new(sx, 0.4, 2.2),
		base * CFrame.new(0, h * 0.62, -(d / 2 + 1.4)),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)
	for k = 0, math.floor(sx / 12) do
		column(
			m,
			"WalkPost",
			h * 0.62,
			0.5,
			base * CFrame.new(-sx / 2 + 3 + k * 12, 0, -(d / 2 + 2.2)),
			C.WoodDark,
			Enum.Material.Wood
		)
	end
end

-- Scierie : colombages, fenêtres à volets, porte encadrée, toit débordant, cheminée,
-- grande lame dentée, établi et pile de rondins.
builders.Sawmill = function(m: Model, base: CFrame, size: Vector3)
	local sx, sy, sz = size.X, size.Y, size.Z
	local wallH = sy * 0.62
	local frame = C.WoodDark
	-- Fondation en pierre et murs en planches
	part(
		m,
		"Foundation",
		Vector3.new(sx + 0.8, 0.9, sz + 0.8),
		base * CFrame.new(0, 0.45, 0),
		C.StoneDark,
		Enum.Material.Cobblestone
	)
	part(
		m,
		"Walls",
		Vector3.new(sx, wallH, sz),
		base * CFrame.new(0, 0.9 + wallH / 2, 0),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)
	local top = 0.9 + wallH
	-- Colombages : poteaux d'angle, sablière, traverse médiane, croix de Saint-André en façade
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			part(
				m,
				"CornerPost",
				Vector3.new(0.7, wallH, 0.7),
				base * CFrame.new(cx * (sx / 2), 0.9 + wallH / 2, cz * (sz / 2)),
				frame,
				Enum.Material.Wood
			)
		end
	end
	for _, cz in { -1, 1 } do
		part(
			m,
			"Plate",
			Vector3.new(sx + 0.7, 0.5, 0.5),
			base * CFrame.new(0, top - 0.25, cz * (sz / 2 + 0.05)),
			frame,
			Enum.Material.Wood
		)
		part(
			m,
			"MidRail",
			Vector3.new(sx, 0.35, 0.35),
			base * CFrame.new(0, 0.9 + wallH * 0.48, cz * (sz / 2 + 0.12)),
			frame,
			Enum.Material.Wood
		)
	end
	for _, cx in { -1, 1 } do
		part(
			m,
			"SidePlate",
			Vector3.new(0.5, 0.5, sz + 0.7),
			base * CFrame.new(cx * (sx / 2 + 0.05), top - 0.25, 0),
			frame,
			Enum.Material.Wood
		)
	end
	for _, side in { -1, 1 } do
		local cx = side * sx * 0.3
		local len = math.sqrt((sx * 0.3) ^ 2 + (wallH * 0.48) ^ 2)
		part(
			m,
			"Brace",
			Vector3.new(0.3, len, 0.3),
			base * CFrame.new(cx, 0.9 + wallH * 0.74, -sz / 2 - 0.15) * CFrame.Angles(0, 0, math.rad(side * 50)),
			frame,
			Enum.Material.Wood
		)
	end
	-- Porte encadrée avec planches et ferrures
	local door = base * CFrame.new(0, 0.9, -sz / 2 - 0.12)
	part(m, "DoorFrame", Vector3.new(3.2, 4.2, 0.3), door * CFrame.new(0, 2.1, 0), frame, Enum.Material.Wood)
	part(m, "Door", Vector3.new(2.5, 3.7, 0.3), door * CFrame.new(0, 1.85, -0.08), C.Wood, Enum.Material.WoodPlanks)
	for _, y in { 0.9, 2.8 } do
		part(
			m,
			"Hinge",
			Vector3.new(1.6, 0.18, 0.1),
			door * CFrame.new(-0.4, y, -0.26),
			C.Metal,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	-- Fenêtres latérales : cadre, vitre, volets ouverts
	for _, side in { -1, 1 } do
		for _, wz in { -sz * 0.22, sz * 0.22 } do
			local win = base
				* CFrame.new(side * (sx / 2 + 0.1), 0.9 + wallH * 0.62, wz)
				* CFrame.Angles(0, math.rad(90 * side), 0)
			part(m, "WindowFrame", Vector3.new(2, 1.8, 0.25), win, frame, Enum.Material.Wood)
			part(
				m,
				"Glass",
				Vector3.new(1.5, 1.3, 0.28),
				win,
				Color3.fromRGB(70, 90, 110),
				Enum.Material.Glass,
				{ NoShadow = true }
			)
			part(m, "Mullion", Vector3.new(0.15, 1.3, 0.32), win, frame, Enum.Material.Wood, { NoShadow = true })
			for _, sh in { -1, 1 } do
				part(
					m,
					"Shutter",
					Vector3.new(0.9, 1.7, 0.15),
					win * CFrame.new(sh * 1.5, 0, -0.1),
					C.RoofDark:Lerp(C.Wood, 0.4),
					Enum.Material.WoodPlanks
				)
			end
		end
	end
	-- Toit à deux pans débordant, faîtage et bordures
	local roofH = sy - wallH + 1
	gableRoof(m, sx + 2.4, sz + 2.4, roofH, base * CFrame.new(0, top, 0), C.Roof)
	part(
		m,
		"Ridge",
		Vector3.new(sx + 2.6, 0.5, 0.6),
		base * CFrame.new(0, top + roofH, 0),
		C.RoofDark,
		Enum.Material.Wood
	)
	-- Pignons : triangles en planches qui ferment les deux bouts du toit
	for _, side in { -1, 1 } do
		local gable = base * CFrame.new(side * sx / 2, top + roofH / 2, 0)
		part(
			m,
			"GableA",
			Vector3.new(0.5, roofH, sz / 2),
			gable * CFrame.new(0, 0, -sz / 4),
			C.WoodLight,
			Enum.Material.WoodPlanks,
			{
				Class = "WedgePart",
			}
		)
		part(
			m,
			"GableB",
			Vector3.new(0.5, roofH, sz / 2),
			gable * CFrame.new(0, 0, sz / 4) * CFrame.Angles(0, math.pi, 0),
			C.WoodLight,
			Enum.Material.WoodPlanks,
			{
				Class = "WedgePart",
			}
		)
	end
	-- Cheminée en pierre
	local chim = base * CFrame.new(sx * 0.28, top, sz * 0.18)
	part(
		m,
		"Chimney",
		Vector3.new(1.6, roofH + 1.6, 1.6),
		chim * CFrame.new(0, (roofH + 1.6) / 2, 0),
		C.Stone,
		Enum.Material.Cobblestone
	)
	part(
		m,
		"ChimneyCap",
		Vector3.new(2, 0.4, 2),
		chim * CFrame.new(0, roofH + 1.8, 0),
		C.StoneDark,
		Enum.Material.Slate
	)
	-- Grande lame dentée sur le côté
	local saw = base * CFrame.new(sx / 2 + 0.5, 3, 0)
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
	for t = 1, 12 do
		local a = t * math.pi / 6
		part(
			m,
			"Tooth",
			Vector3.new(0.18, 0.5, 0.5),
			saw
				* CFrame.new(0, math.cos(a) * 2.25, math.sin(a) * 2.25)
				* CFrame.Angles(a, 0, 0)
				* CFrame.Angles(math.rad(45), 0, 0),
			C.Metal:Lerp(Color3.new(1, 1, 1), 0.3),
			Enum.Material.Metal,
			{
				NoShadow = true,
			}
		)
	end
	-- Établi avec rondin en cours de coupe, et pile de rondins
	local bench = base * CFrame.new(sx / 2 + 2.6, 0, -sz * 0.25)
	for _, bz in { -1.2, 1.2 } do
		part(m, "BenchLeg", Vector3.new(0.4, 1.4, 0.4), bench * CFrame.new(0, 0.7, bz), frame, Enum.Material.Wood)
	end
	part(m, "BenchTop", Vector3.new(1.4, 0.3, 3.2), bench * CFrame.new(0, 1.45, 0), C.Wood, Enum.Material.WoodPlanks)
	part(
		m,
		"BenchLog",
		Vector3.new(3, 0.9, 0.9),
		bench * CFrame.new(0, 2.05, 0) * CFrame.Angles(0, math.rad(90), 0),
		C.Bark,
		Enum.Material.Wood,
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
	for i = 0, 4 do
		local layer = if i >= 3 then 1 else 0
		local offset = if i >= 3 then (i - 3.5) * 1 else (i - 1) * 1
		part(
			m,
			"Pile" .. i,
			Vector3.new(4, 1, 1),
			base * CFrame.new(-sx / 2 + 2.5, 0.5 + layer * 0.86, -sz / 2 - 1.8 + offset),
			if i % 2 == 0 then C.Bark else C.Wood,
			Enum.Material.Wood,
			{
				Shape = Enum.PartType.Cylinder,
			}
		)
	end
end

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

-- Tour de guet : fût de pierre à chaînages d'angle, bandeaux, meurtrières, porte cintrée,
-- hourd en bois avec garde-corps, toit pyramidal à épi et drapeau.
builders.Watchtower = function(m: Model, base: CFrame, size: Vector3)
	local w, h = size.X, size.Y
	local shaftH = h * 0.7
	part(
		m,
		"Plinth",
		Vector3.new(w + 1.4, 1.2, w + 1.4),
		base * CFrame.new(0, 0.6, 0),
		C.StoneDark,
		Enum.Material.Cobblestone
	)
	part(m, "Shaft", Vector3.new(w, shaftH, w), base * CFrame.new(0, shaftH / 2, 0), C.Stone, Enum.Material.Cobblestone)
	-- Chaînages d'angle : blocs alternés plus clairs
	local blocks = math.floor(shaftH / 1.6)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			for k = 0, blocks - 1 do
				local long = k % 2 == 0
				part(
					m,
					"Quoin",
					Vector3.new(if long then 1.6 else 1, 1.4, if long then 1 else 1.6),
					base * CFrame.new(cx * (w / 2 - 0.35), 0.8 + k * 1.6, cz * (w / 2 - 0.35)),
					C.StoneLight,
					Enum.Material.Slate
				)
			end
		end
	end
	-- Bandeaux de pierre
	for _, y in { shaftH * 0.35, shaftH * 0.7 } do
		part(
			m,
			"Band",
			Vector3.new(w + 0.4, 0.5, w + 0.4),
			base * CFrame.new(0, y, 0),
			C.StoneLight,
			Enum.Material.Slate
		)
	end
	-- Meurtrières sur chaque face
	for f = 0, 3 do
		local face = base * CFrame.Angles(0, f * math.pi / 2, 0)
		for _, y in { shaftH * 0.52, shaftH * 0.85 } do
			part(
				m,
				"Slit",
				Vector3.new(0.4, 1.6, 0.2),
				face * CFrame.new(0, y, -w / 2 - 0.02),
				Color3.fromRGB(25, 22, 20),
				Enum.Material.SmoothPlastic,
				{
					NoShadow = true,
				}
			)
		end
	end
	-- Porte cintrée
	part(
		m,
		"DoorArch",
		Vector3.new(2.6, 2.6, 0.3),
		base * CFrame.new(0, 3.6, -w / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(45)),
		C.StoneLight,
		Enum.Material.Slate
	)
	part(
		m,
		"DoorFrame",
		Vector3.new(2.8, 3.6, 0.3),
		base * CFrame.new(0, 1.8, -w / 2 - 0.05),
		C.StoneLight,
		Enum.Material.Slate
	)
	part(
		m,
		"Door",
		Vector3.new(2.1, 3.3, 0.3),
		base * CFrame.new(0, 1.65, -w / 2 - 0.15),
		C.Wood,
		Enum.Material.WoodPlanks
	)
	-- Hourd : plancher débordant, consoles, garde-corps
	local deckY = shaftH
	part(
		m,
		"Deck",
		Vector3.new(w + 3.4, 0.7, w + 3.4),
		base * CFrame.new(0, deckY + 0.35, 0),
		C.Wood,
		Enum.Material.WoodPlanks
	)
	for f = 0, 3 do
		local face = base * CFrame.Angles(0, f * math.pi / 2, 0)
		for _, x in { -w / 4, w / 4 } do
			part(
				m,
				"Corbel",
				Vector3.new(0.6, 1.2, 1.6),
				face * CFrame.new(x, deckY - 0.5, -w / 2 - 0.6),
				C.WoodDark,
				Enum.Material.Wood
			)
		end
		part(
			m,
			"Rail",
			Vector3.new(w + 3.4, 0.3, 0.3),
			face * CFrame.new(0, deckY + 1.8, -(w + 3.4) / 2 + 0.15),
			C.WoodDark,
			Enum.Material.Wood
		)
		for k = -2, 2 do
			part(
				m,
				"Baluster",
				Vector3.new(0.25, 1.1, 0.25),
				face * CFrame.new(k * (w + 3) / 5, deckY + 1.25, -(w + 3.4) / 2 + 0.15),
				C.WoodDark,
				Enum.Material.Wood
			)
		end
	end
	local half = (w + 3.4) / 2 - 0.4
	for _, c in { { -half, -half }, { half, -half }, { -half, half }, { half, half } } do
		column(m, "Pillar", 3.4, 0.5, base * CFrame.new(c[1], deckY + 0.7, c[2]), C.WoodDark, Enum.Material.Wood)
	end
	-- Toit pyramidal à gradins et épi
	local roofY = deckY + 4
	for i, sz in { w + 5, w + 3, w + 1, w - 1, w - 3, 1.4 } do
		part(
			m,
			"Roof" .. i,
			Vector3.new(sz, 0.9, sz),
			base * CFrame.new(0, roofY + (i - 1) * 0.8, 0),
			if i % 2 == 0 then C.RoofDark else C.Roof,
			Enum.Material.Slate
		)
	end
	local flag = base * CFrame.new(0, roofY + 4.6, 0)
	ball(m, "Finial", 0.7, flag, C.Rune, Enum.Material.Metal)
	column(m, "FlagPole", 3, 0.2, flag, C.WoodDark, Enum.Material.Wood)
	part(
		m,
		"Flag",
		Vector3.new(0.1, 1.2, 2),
		flag * CFrame.new(0, 2.3, 1),
		C.ClothBlue,
		Enum.Material.Fabric,
		{ CanCollide = false }
	)
	part(
		m,
		"FlagEmblem",
		Vector3.new(0.12, 0.6, 0.6),
		flag * CFrame.new(0, 2.3, 1) * CFrame.Angles(math.rad(45), 0, 0),
		C.Rune,
		Enum.Material.SmoothPlastic,
		{
			CanCollide = false,
			NoShadow = true,
		}
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

-- Décor du hub : puits central décoratif autour du point d'apparition, lanternes, bannières.
function Models.hubDecor(parent: Instance, radius: number)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + math.pi / 6
		if i == 1 or i == 4 then
			continue -- 90° et 270° : portails de la Rue des boss et du Champ des champions
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
	column(m, "Cushion", 0.4, 3.6, base * CFrame.new(0, 1.2, 0), GOLD, Enum.Material.Metal)
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
-- Arc en plein cintre fait de claveaux (blocs disposés sur un demi-cercle).
-- `center` : CFrame au centre de l'arc (hauteur des naissances). Retourne la liste des blocs.
local function arch(
	parent,
	center: CFrame,
	radius: number,
	thickness: number,
	depth: number,
	count: number,
	color,
	material,
	props
)
	local blocks = {}
	-- Recouvrement léger entre claveaux : pas de dents visibles sur l'extrados.
	local length = math.pi * (radius + thickness / 2) / count * 1.06
	for k = 1, count do
		local theta = math.pi * (k - 0.5) / count
		local cf = center
			* CFrame.new(radius * math.cos(theta), radius * math.sin(theta), 0)
			* CFrame.Angles(0, 0, theta + math.pi / 2)
		table.insert(
			blocks,
			part(parent, "Voussoir" .. k, Vector3.new(length, thickness, depth), cf, color, material, props)
		)
	end
	return blocks
end
Models.arch = arch

-- Portail céleste : emmarchement de marbre, colonnes à base et chapiteau cerclés d'or,
-- arc en plein cintre à claveaux, filet d'or, clé de voûte à gemme, voile lumineux en deux
-- couches (rectangle + disque) épousant l'arc. Retourne model, voile (porte l'invite).
function Models.portal(base: CFrame, color: Color3): (Model, BasePart)
	local m = newModel("Portal")
	local half = 4.2 -- demi-écartement des colonnes
	local spring = 8.6 -- hauteur des naissances de l'arc
	-- Emmarchement
	part(m, "Step1", Vector3.new(12.5, 0.5, 5.6), base * CFrame.new(0, 0.25, 0), MARBLE_SHADE, Enum.Material.Marble)
	part(m, "Step2", Vector3.new(11, 0.5, 4.4), base * CFrame.new(0, 0.75, 0), MARBLE, Enum.Material.Marble)
	part(
		m,
		"StepTrim",
		Vector3.new(11.1, 0.12, 4.5),
		base * CFrame.new(0, 1.04, 0),
		GOLD,
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	for _, side in { -1, 1 } do
		local col = base * CFrame.new(side * half, 1, 0)
		part(m, "Plinth", Vector3.new(2.4, 0.9, 2.4), col * CFrame.new(0, 0.45, 0), MARBLE, Enum.Material.Marble)
		part(
			m,
			"PlinthTrim",
			Vector3.new(2.5, 0.15, 2.5),
			col * CFrame.new(0, 0.95, 0),
			GOLD,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
		column(m, "Shaft", spring - 2.6, 1.6, col * CFrame.new(0, 1, 0), MARBLE, Enum.Material.Marble)
		for _, y in { 1.4, spring - 2.2 } do
			column(m, "Ring", 0.25, 1.75, col * CFrame.new(0, y, 0), GOLD, Enum.Material.Metal, { NoShadow = true })
		end
		part(
			m,
			"Capital",
			Vector3.new(2.4, 0.7, 2.4),
			col * CFrame.new(0, spring - 1.25, 0),
			MARBLE,
			Enum.Material.Marble
		)
		part(
			m,
			"Abacus",
			Vector3.new(2.7, 0.35, 2.7),
			col * CFrame.new(0, spring - 0.75, 0),
			GOLD,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
		-- Applique à cristal sur la face avant de la colonne
		part(m, "Sconce", Vector3.new(0.5, 0.9, 0.4), col * CFrame.new(0, 4.2, -0.95), GOLD, Enum.Material.Metal)
		part(
			m,
			"SconceGem",
			Vector3.new(0.45, 0.45, 0.45),
			col * CFrame.new(0, 4.85, -1) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			color,
			Enum.Material.Neon,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
	end
	-- Arc à claveaux de marbre + filet d'or à l'intrados
	local archCenter = base * CFrame.new(0, spring, 0)
	arch(m, archCenter, half, 1.6, 2, 15, MARBLE, Enum.Material.Marble)
	-- Bandeau d'extrados : filet de marbre plus sombre qui adoucit le contour de l'arc
	arch(m, archCenter, half + 0.95, 0.3, 2.1, 21, MARBLE_SHADE, Enum.Material.Marble)
	arch(
		m,
		archCenter * CFrame.new(0, 0, -1.02),
		half - 0.72,
		0.18,
		0.12,
		15,
		GOLD,
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	arch(
		m,
		archCenter * CFrame.new(0, 0, 1.02),
		half - 0.72,
		0.18,
		0.12,
		15,
		GOLD,
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	-- Clé de voûte : cartouche doré et gemme
	local key = archCenter * CFrame.new(0, half + 0.9, -0.2)
	part(m, "KeyFrame", Vector3.new(1.5, 1.5, 2.3), key * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
	part(
		m,
		"KeyGem",
		Vector3.new(0.95, 0.95, 2.4),
		key * CFrame.Angles(0, 0, math.rad(45)),
		color,
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	-- Voile : rectangle sous les naissances + disque pour la partie cintrée, en deux couches
	local inner = (half - 0.8) * 2
	local veil = part(
		m,
		"Veil",
		Vector3.new(inner, spring - 1.1, 0.2),
		base * CFrame.new(0, 1 + (spring - 1) / 2, 0),
		color,
		Enum.Material.Neon,
		{
			CanCollide = false,
			Transparency = 0.35,
			NoShadow = true,
		}
	)
	part(
		m,
		"VeilArch",
		Vector3.new(0.2, inner, inner),
		archCenter * CFrame.Angles(0, math.rad(90), 0),
		color,
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
		"VeilGlow",
		Vector3.new(inner * 0.6, spring - 2.2, 0.22),
		base * CFrame.new(0, 1 + (spring - 1) / 2, 0),
		color:Lerp(Color3.new(1, 1, 1), 0.6),
		Enum.Material.Neon,
		{
			CanCollide = false,
			Transparency = 0.55,
			NoShadow = true,
		}
	)
	m.PrimaryPart = veil
	return m, veil
end

-- Estrade d'apparition au centre de la cour : trois degrés, anneau d'or, cercle runique.
function Models.hubPlaza(parent: Instance, _radius: number)
	-- Le sol pavé et l'enceinte sont construits par Models.castle ; ici, l'estrade centrale.
	-- Estrade d'apparition à trois degrés
	column(parent, "Dais1", 0.35, 15, CFrame.new(0, 1, 0), MARBLE_SHADE, Enum.Material.Marble)
	column(parent, "Dais2", 0.35, 12, CFrame.new(0, 1.35, 0), MARBLE, Enum.Material.Marble)
	column(parent, "DaisRing", 0.08, 12.3, CFrame.new(0, 1.66, 0), GOLD, Enum.Material.Metal, { NoShadow = true })
	column(parent, "DaisTop", 0.12, 9, CFrame.new(0, 1.7, 0), Color3.fromRGB(60, 70, 100), Enum.Material.Slate)
	column(
		parent,
		"RuneCircle",
		0.05,
		7,
		CFrame.new(0, 1.82, 0),
		C.Ether,
		Enum.Material.Neon,
		{ NoShadow = true, CanCollide = false }
	)
	column(
		parent,
		"RuneInner",
		0.06,
		6.2,
		CFrame.new(0, 1.83, 0),
		Color3.fromRGB(60, 70, 100),
		Enum.Material.Slate,
		{ NoShadow = true, CanCollide = false }
	)
	for k = 1, 8 do
		local a = k * math.pi / 4
		part(
			parent,
			"Rune" .. k,
			Vector3.new(0.5, 0.06, 0.5),
			CFrame.new(math.cos(a) * 2.4, 1.86, math.sin(a) * 2.4)
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(0, math.rad(45), 0),
			C.Ether,
			Enum.Material.Neon,
			{
				NoShadow = true,
				CanCollide = false,
			}
		)
	end
end

-- Autel de renaissance (sanctuaire) : mur de pierre sombre à trois baies gothiques garnies de
-- vitraux de cristal bleu, colonnettes, autel central à cristal flottant, degrés.
-- Retourne model, cristal (porte l'invite).
function Models.rebirthShrine(base: CFrame): (Model, BasePart)
	local m = newModel("RebirthShrine")
	local stone = Color3.fromRGB(92, 104, 120)
	local stoneLight = Color3.fromRGB(128, 140, 156)
	local glow = Color3.fromRGB(70, 190, 255)
	part(m, "Step1", Vector3.new(18, 0.5, 10), base * CFrame.new(0, 0.25, 0), stoneLight, Enum.Material.Slate)
	part(m, "Step2", Vector3.new(16, 0.5, 8), base * CFrame.new(0, 0.75, 0.6), stone, Enum.Material.Slate)
	local wallZ = 3.6
	part(m, "Wall", Vector3.new(16, 10, 1.4), base * CFrame.new(0, 6, wallZ), stone, Enum.Material.Slate)
	part(m, "Cornice", Vector3.new(16.8, 0.8, 2), base * CFrame.new(0, 11.4, wallZ), stoneLight, Enum.Material.Slate)
	for k = -3, 3 do
		part(
			m,
			"Merlon",
			Vector3.new(1.4, 1.2, 1.6),
			base * CFrame.new(k * 2.4, 12.4, wallZ),
			stoneLight,
			Enum.Material.Slate
		)
	end
	-- Trois baies : vitrail lumineux, arc à claveaux, colonnettes
	for b = -1, 1 do
		local x = b * 5
		local h = if b == 0 then 6 else 5
		local w = if b == 0 then 3.2 else 2.6
		local sill = 1.6
		local bay = base * CFrame.new(x, 0, wallZ - 0.75)
		part(
			m,
			"Glass",
			Vector3.new(w, h, 0.2),
			bay * CFrame.new(0, sill + h / 2, 0),
			glow,
			Enum.Material.Neon,
			{ NoShadow = true }
		)
		part(
			m,
			"GlassArch",
			Vector3.new(0.2, w, w),
			bay * CFrame.new(0, sill + h, 0) * CFrame.Angles(0, math.rad(90), 0),
			glow,
			Enum.Material.Neon,
			{
				Shape = Enum.PartType.Cylinder,
				NoShadow = true,
			}
		)
		part(
			m,
			"Mullion",
			Vector3.new(0.18, h + w / 2, 0.3),
			bay * CFrame.new(0, sill + (h + w / 2) / 2, -0.05),
			stone,
			Enum.Material.Slate,
			{ NoShadow = true }
		)
		part(
			m,
			"Transom",
			Vector3.new(w, 0.18, 0.3),
			bay * CFrame.new(0, sill + h * 0.55, -0.05),
			stone,
			Enum.Material.Slate,
			{ NoShadow = true }
		)
		arch(m, bay * CFrame.new(0, sill + h, -0.15), w / 2 + 0.35, 0.7, 0.6, 9, stoneLight, Enum.Material.Slate)
		for _, sx in { -1, 1 } do
			part(
				m,
				"Colonnette",
				Vector3.new(0.6, h, 0.6),
				bay * CFrame.new(sx * (w / 2 + 0.35), sill + h / 2, -0.15),
				stoneLight,
				Enum.Material.Slate
			)
		end
		part(
			m,
			"Sill",
			Vector3.new(w + 1.6, 0.4, 0.9),
			bay * CFrame.new(0, sill - 0.2, -0.3),
			stoneLight,
			Enum.Material.Slate
		)
	end
	-- Autel central et cristal flottant
	local altar = base * CFrame.new(0, 1, -0.8)
	part(m, "Altar", Vector3.new(4, 2.2, 2.2), altar * CFrame.new(0, 1.1, 0), stoneLight, Enum.Material.Slate)
	part(m, "AltarTop", Vector3.new(4.5, 0.35, 2.7), altar * CFrame.new(0, 2.35, 0), stone, Enum.Material.Slate)
	part(
		m,
		"AltarRune",
		Vector3.new(2.6, 0.5, 0.1),
		altar * CFrame.new(0, 1.2, -1.12),
		glow,
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	local crystal = part(
		m,
		"Crystal",
		Vector3.new(1.4, 2.6, 1.4),
		altar * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, math.rad(45), 0),
		glow,
		Enum.Material.Neon,
		{
			NoShadow = true,
		}
	)
	for k = 1, 4 do
		local a = k * math.pi / 2
		part(
			m,
			"Shard" .. k,
			Vector3.new(0.4, 0.9, 0.4),
			altar * CFrame.new(math.cos(a) * 1.5, 4.1, math.sin(a) * 1.5) * CFrame.Angles(0, a, math.rad(25)),
			glow:Lerp(Color3.new(1, 1, 1), 0.4),
			Enum.Material.Neon,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 18
	light.Brightness = 1.6
	light.Parent = crystal
	m.PrimaryPart = crystal
	return m, crystal
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

-- Champ des champions ---------------------------------------------------------------------

-- Mannequin d'entraînement autonome (poteau, bras, corps, tête). Retourne le corps.
function Models.dummy(base: CFrame, parent: Instance, color: Color3): BasePart
	column(parent, "DummyPole", 4.6, 0.45, base, C.WoodDark, Enum.Material.Wood)
	part(
		parent,
		"DummyArms",
		Vector3.new(2.8, 0.35, 0.35),
		base * CFrame.new(0, 3.4, 0),
		C.WoodDark,
		Enum.Material.Wood
	)
	local body =
		part(parent, "DummyBody", Vector3.new(1.5, 1.8, 0.9), base * CFrame.new(0, 3, 0), color, Enum.Material.Fabric)
	ball(parent, "DummyHead", 1.1, base * CFrame.new(0, 4.5, 0), C.Straw, Enum.Material.Fabric)
	return body
end

--[[
	Île suspendue et ses zones. `origin` : CFrame au sol, -Z = vers le fond de l'île.
	Retourne { { Border = {BasePart}, Dummies = {BasePart}, Center = CFrame } } par zone.
	La couleur des bordures est ajustée côté client (vert = accessible, rouge = verrouillé).
]]
function Models.farmIsland(origin: CFrame, cfg, zoneCenter, parent: Instance)
	local step = cfg.ZoneSize + cfg.Gap
	local rows = math.ceil(#cfg.Zones / cfg.Columns)
	local width = cfg.Columns * step + 16
	local depth = rows * step + 34
	-- Plateau principal + bordure basse + parvis d'arrivée
	part(
		parent,
		"Island",
		Vector3.new(width, 4, depth),
		origin * CFrame.new(0, -2, -(depth / 2) + 22),
		C.Stone,
		Enum.Material.Slate
	)
	part(
		parent,
		"IslandRock",
		Vector3.new(width - 10, 18, depth - 10),
		origin * CFrame.new(0, -13, -(depth / 2) + 22),
		C.StoneDark,
		Enum.Material.Rock
	)
	for _, side in { -1, 1 } do
		part(
			parent,
			"Rail",
			Vector3.new(1.2, 3, depth),
			origin * CFrame.new(side * (width / 2 - 0.6), 1.5, -(depth / 2) + 22),
			C.StoneLight,
			Enum.Material.Slate
		)
	end
	part(
		parent,
		"RailBack",
		Vector3.new(width, 3, 1.2),
		origin * CFrame.new(0, 1.5, -depth + 22.6),
		C.StoneLight,
		Enum.Material.Slate
	)

	local zones = {}
	for i, zone in cfg.Zones do
		local x, z = zoneCenter(cfg, i)
		local center = origin * CFrame.new(x, 0, -z)
		local floorColor = if zone.Royal then Color3.fromRGB(120, 90, 30) else C.StoneDark:Lerp(C.RuneBlue, 0.15)
		part(
			parent,
			"ZoneFloor" .. i,
			Vector3.new(cfg.ZoneSize, 0.2, cfg.ZoneSize),
			center * CFrame.new(0, 0.1, 0),
			floorColor,
			Enum.Material.Slate
		)
		local border = {}
		local h = cfg.ZoneSize / 2
		for _, e in
			{
				{ 0, -h, cfg.ZoneSize, 0.6 },
				{ 0, h, cfg.ZoneSize, 0.6 },
				{ -h, 0, 0.6, cfg.ZoneSize },
				{ h, 0, 0.6, cfg.ZoneSize },
			}
		do
			local b = part(
				parent,
				"ZoneBorder" .. i,
				Vector3.new(e[3], 0.3, e[4]),
				center * CFrame.new(e[1], 0.3, e[2]),
				if zone.Royal then C.Rune else C.Ether,
				Enum.Material.Neon,
				{
					CanCollide = false,
					NoShadow = true,
				}
			)
			b:SetAttribute("ZoneIndex", i)
			table.insert(border, b)
		end
		local dummies = {}
		for d = -1, 1 do
			local body = Models.dummy(
				center * CFrame.new(d * 6, 0.2, -5),
				parent,
				if zone.Royal then C.Rune else C.Straw:Lerp(C.Cloth, (i % 3) * 0.3)
			)
			table.insert(dummies, body)
		end
		table.insert(zones, { Border = border, Dummies = dummies, Center = center })
	end
	return zones
end

-- Panneau de classement : cadre en bois + SurfaceGui. Retourne titre et lignes (10).
function Models.leaderboard(base: CFrame, title: string, accent: Color3, parent: Instance): (TextLabel, { TextLabel })
	local w, h = 14, 16
	for _, x in { -w / 2 - 0.6, w / 2 + 0.6 } do
		column(parent, "BoardPost", h + 2, 1, base * CFrame.new(x, 0, 0), C.WoodDark, Enum.Material.Wood)
	end
	local board = part(
		parent,
		"Board",
		Vector3.new(w, h, 0.6),
		base * CFrame.new(0, h / 2 + 1.5, 0),
		Color3.fromRGB(245, 240, 225),
		Enum.Material.SmoothPlastic
	)
	part(
		parent,
		"BoardTop",
		Vector3.new(w + 2.4, 1.2, 1.2),
		base * CFrame.new(0, h + 2.3, 0),
		accent,
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = gui
	local function line(order: number, height: number, font, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -20, 0, height)
		label.BackgroundTransparency = 1
		label.Font = font
		label.TextScaled = true
		label.TextColor3 = color
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = ""
		label.Parent = gui
		return label
	end
	local titleLabel = line(0, 60, Enum.Font.FredokaOne, accent:Lerp(Color3.new(0, 0, 0), 0.25))
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Text = title
	local rows = {}
	for i = 1, 10 do
		rows[i] = line(
			i,
			36,
			Enum.Font.GothamBold,
			if i <= 3 then Color3.fromRGB(150, 100, 20) else Color3.fromRGB(50, 45, 40)
		)
	end
	return titleLabel, rows
end

-- Cour royale ------------------------------------------------------------------------------

local WALL_STONE = Color3.fromRGB(150, 146, 136)
local WALL_DARK = Color3.fromRGB(118, 114, 106)
local WALL_LIGHT = Color3.fromRGB(184, 178, 166)
local PAVING = Color3.fromRGB(158, 150, 138)
local ROYAL_BLUE = Color3.fromRGB(40, 70, 150)

-- Tour ronde crénelée à toit conique (étages) et drapeau facultatif. `base` au sol.
local function roundTower(parent, base: CFrame, d: number, h: number, flag: boolean)
	column(parent, "TowerBase", 1.5, d + 1.4, base, WALL_DARK, Enum.Material.Cobblestone)
	column(parent, "Tower", h, d, base, WALL_STONE, Enum.Material.Cobblestone)
	column(parent, "TowerBand", 0.8, d + 0.6, base * CFrame.new(0, h * 0.55, 0), WALL_LIGHT, Enum.Material.Slate)
	column(parent, "TowerTop", 1.2, d + 1.6, base * CFrame.new(0, h, 0), WALL_LIGHT, Enum.Material.Slate)
	local merlons = 10
	for k = 1, merlons do
		local a = (k / merlons) * math.pi * 2
		part(
			parent,
			"TowerMerlon",
			Vector3.new(1.6, 1.6, 1.2),
			base
				* CFrame.new(math.cos(a) * (d / 2 + 0.4), h + 2, math.sin(a) * (d / 2 + 0.4))
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			WALL_STONE,
			Enum.Material.Cobblestone
		)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		part(
			parent,
			"Slit",
			Vector3.new(0.5, 2, 0.4),
			base
				* CFrame.new(math.cos(a) * d / 2, h * 0.75, math.sin(a) * d / 2)
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			Color3.fromRGB(28, 24, 22),
			Enum.Material.SmoothPlastic,
			{
				NoShadow = true,
			}
		)
	end
	local roofY = h + 1.2
	for k, scale in { 1, 0.8, 0.6, 0.4, 0.22 } do
		column(
			parent,
			"TowerRoof",
			1.6,
			(d + 1) * scale,
			base * CFrame.new(0, roofY + (k - 1) * 1.5, 0),
			if k % 2 == 0 then C.RoofDark else C.Roof,
			Enum.Material.Slate
		)
	end
	if flag then
		local top = base * CFrame.new(0, roofY + 7.5, 0)
		column(parent, "FlagPole", 4, 0.25, top, C.WoodDark, Enum.Material.Wood)
		part(
			parent,
			"Flag",
			Vector3.new(0.1, 1.6, 2.8),
			top * CFrame.new(0, 3.2, 1.4),
			ROYAL_BLUE,
			Enum.Material.Fabric,
			{ CanCollide = false }
		)
		part(
			parent,
			"FlagStripe",
			Vector3.new(0.12, 0.3, 2.8),
			top * CFrame.new(0, 3.2, 1.4),
			GOLD,
			Enum.Material.Fabric,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
	end
end

-- Pan de rempart droit entre deux points (au sol), avec créneaux côté extérieur, chemin de
-- ronde côté intérieur, torche et bannière facultatives. `frame` : -Z vers la cour.
local function wallSegment(parent, frame: CFrame, length: number, cfg, decorate: boolean)
	local h, t = cfg.WallHeight, cfg.WallThickness
	part(
		parent,
		"WallFooting",
		Vector3.new(length, 1.2, t + 1.2),
		frame * CFrame.new(0, 0.6, 0),
		WALL_DARK,
		Enum.Material.Cobblestone
	)
	part(
		parent,
		"Wall",
		Vector3.new(length, h, t),
		frame * CFrame.new(0, h / 2, 0),
		WALL_STONE,
		Enum.Material.Cobblestone
	)
	part(
		parent,
		"WallCap",
		Vector3.new(length, 0.6, t + 0.6),
		frame * CFrame.new(0, h + 0.3, 0),
		WALL_LIGHT,
		Enum.Material.Slate
	)
	part(
		parent,
		"StringCourse",
		Vector3.new(length, 0.5, t + 0.4),
		frame * CFrame.new(0, h * 0.6, 0),
		WALL_LIGHT,
		Enum.Material.Slate
	)
	local count = math.max(1, math.floor(length / 3.2))
	for k = 0, count - 1 do
		local x = -length / 2 + (k + 0.5) * (length / count)
		if k % 2 == 0 then
			part(
				parent,
				"Merlon",
				Vector3.new(length / count * 0.95, 1.8, 1.2),
				frame * CFrame.new(x, h + 1.5, t / 2 - 0.6),
				WALL_STONE,
				Enum.Material.Cobblestone
			)
		end
	end
	if decorate then
		-- Torche murale et grande bannière royale côté cour
		local torch = frame * CFrame.new(-length * 0.25, h * 0.45, -t / 2 - 0.4)
		part(parent, "Sconce", Vector3.new(0.5, 1.2, 0.6), torch, C.WoodDark, Enum.Material.Wood)
		local flame = part(
			parent,
			"Flame",
			Vector3.new(0.7, 0.9, 0.7),
			torch * CFrame.new(0, 1, 0),
			Color3.fromRGB(255, 160, 70),
			Enum.Material.Neon,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Range = 14
		light.Parent = flame
		local banner = frame * CFrame.new(length * 0.2, h * 0.58, -t / 2 - 0.15)
		part(
			parent,
			"BannerRod",
			Vector3.new(4.4, 0.3, 0.3),
			banner * CFrame.new(0, 3.2, 0),
			C.WoodDark,
			Enum.Material.Wood
		)
		part(
			parent,
			"Banner",
			Vector3.new(3.6, 6, 0.1),
			banner,
			ROYAL_BLUE,
			Enum.Material.Fabric,
			{ CanCollide = false }
		)
		part(
			parent,
			"BannerTrim",
			Vector3.new(3.6, 0.35, 0.12),
			banner * CFrame.new(0, -2.9, 0),
			GOLD,
			Enum.Material.Fabric,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
		part(
			parent,
			"BannerCrest",
			Vector3.new(1.4, 1.4, 0.14),
			banner * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(45)),
			GOLD,
			Enum.Material.Metal,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
	end
end

-- Porte fortifiée : ouverture, arc de claveaux, herse relevée, vantaux ouverts, étage de garde
-- crénelé. `frame` au centre de l'ouverture, -Z vers la cour.
local function gatehouse(parent, frame: CFrame, cfg)
	local h, t, w = cfg.WallHeight, cfg.WallThickness, cfg.GateWidth
	local depth = t + 3
	for _, side in { -1, 1 } do
		-- Piédroits massifs de part et d'autre
		part(
			parent,
			"GatePier",
			Vector3.new(3, h + 5, depth),
			frame * CFrame.new(side * (w / 2 + 1.5), (h + 5) / 2, 0),
			WALL_DARK,
			Enum.Material.Cobblestone
		)
		part(
			parent,
			"GatePierCap",
			Vector3.new(3.6, 0.8, depth + 0.6),
			frame * CFrame.new(side * (w / 2 + 1.5), h + 5.4, 0),
			WALL_LIGHT,
			Enum.Material.Slate
		)
		-- Vantail en bois ouvert vers la cour
		local hinge = frame * CFrame.new(side * w / 2, 0, -depth / 2)
		part(
			parent,
			"GateDoor",
			Vector3.new(w / 2 - 0.2, 10, 0.5),
			hinge * CFrame.Angles(0, math.rad(side * -75), 0) * CFrame.new(-side * (w / 4), 5, 0),
			C.Wood,
			Enum.Material.WoodPlanks
		)
		for _, y in { 2, 8 } do
			part(
				parent,
				"DoorBand",
				Vector3.new(w / 2 - 0.4, 0.4, 0.6),
				hinge * CFrame.Angles(0, math.rad(side * -75), 0) * CFrame.new(-side * (w / 4), y, 0),
				C.Metal,
				Enum.Material.Metal,
				{
					NoShadow = true,
				}
			)
		end
	end
	-- Linteau, arc et étage de garde au-dessus du passage
	part(
		parent,
		"GateLintel",
		Vector3.new(w, 4, depth),
		frame * CFrame.new(0, h - 1, 0),
		WALL_STONE,
		Enum.Material.Cobblestone
	)
	part(
		parent,
		"GateUpper",
		Vector3.new(w + 6, 5, depth),
		frame * CFrame.new(0, h + 2.5, 0),
		WALL_STONE,
		Enum.Material.Cobblestone
	)
	for k = -3, 3 do
		if k % 2 ~= 0 then
			part(
				parent,
				"GateMerlon",
				Vector3.new(2, 1.8, depth),
				frame * CFrame.new(k * 2.5, h + 5.9, 0),
				WALL_STONE,
				Enum.Material.Cobblestone
			)
		end
	end
	for _, z in { -depth / 2 - 0.05, depth / 2 + 0.05 } do
		arch(
			parent,
			frame * CFrame.new(0, h - 3 - w / 2 + 0.6, z),
			w / 2 - 0.3,
			1.2,
			0.5,
			11,
			WALL_LIGHT,
			Enum.Material.Slate
		)
	end
	-- Herse relevée (dents de fer visibles sous le linteau)
	for k = -5, 5 do
		part(
			parent,
			"Portcullis",
			Vector3.new(0.3, 2.4, 0.3),
			frame * CFrame.new(k * (w / 11), h - 4, 0),
			Color3.fromRGB(60, 60, 66),
			Enum.Material.Metal,
			{
				NoShadow = true,
			}
		)
	end
	part(
		parent,
		"PortcullisBar",
		Vector3.new(w, 0.3, 0.3),
		frame * CFrame.new(0, h - 3.2, 0),
		Color3.fromRGB(60, 60, 66),
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	-- Blason au-dessus de la porte, côté extérieur
	local crest = frame * CFrame.new(0, h + 2.6, depth / 2 + 0.1)
	part(parent, "Crest", Vector3.new(2.6, 3, 0.3), crest, ROYAL_BLUE, Enum.Material.SmoothPlastic)
	part(
		parent,
		"CrestGem",
		Vector3.new(1.2, 1.2, 0.35),
		crest * CFrame.Angles(0, 0, math.rad(45)),
		GOLD,
		Enum.Material.Metal,
		{ NoShadow = true }
	)
end

-- Donjon royal : corps de pierre, tourelles d'angle, fenêtres, grande porte, tour centrale.
-- `base` au sol, -Z = façade (vers la cour).
local function royalKeep(parent, base: CFrame)
	local w, d, h = 30, 14, 22
	part(
		parent,
		"KeepPlinth",
		Vector3.new(w + 2, 1.4, d + 2),
		base * CFrame.new(0, 0.7, 0),
		WALL_DARK,
		Enum.Material.Cobblestone
	)
	part(parent, "Keep", Vector3.new(w, h, d), base * CFrame.new(0, h / 2, 0), WALL_STONE, Enum.Material.Cobblestone)
	part(
		parent,
		"KeepBand",
		Vector3.new(w + 0.6, 0.6, d + 0.6),
		base * CFrame.new(0, h * 0.5, 0),
		WALL_LIGHT,
		Enum.Material.Slate
	)
	part(
		parent,
		"KeepCap",
		Vector3.new(w + 1, 0.8, d + 1),
		base * CFrame.new(0, h + 0.4, 0),
		WALL_LIGHT,
		Enum.Material.Slate
	)
	for k = -6, 6 do
		if k % 2 == 0 then
			part(
				parent,
				"KeepMerlon",
				Vector3.new(2, 1.8, 1.2),
				base * CFrame.new(k * 2.2, h + 1.7, -d / 2),
				WALL_STONE,
				Enum.Material.Cobblestone
			)
		end
	end
	-- Tourelles d'angle
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			roundTower(parent, base * CFrame.new(cx * w / 2, 0, cz * d / 2), 5, h + 4, false)
		end
	end
	-- Grande porte en arc, dorée, et escalier
	local door = base * CFrame.new(0, 1.4, -d / 2 - 0.1)
	part(parent, "KeepDoor", Vector3.new(6, 8, 0.4), door * CFrame.new(0, 4, 0), C.Wood, Enum.Material.WoodPlanks)
	part(parent, "KeepDoorFrame", Vector3.new(7.4, 9, 0.3), door * CFrame.new(0, 4.4, 0.15), GOLD, Enum.Material.Metal)
	arch(parent, door * CFrame.new(0, 8, -0.1), 3.6, 0.9, 0.6, 9, WALL_LIGHT, Enum.Material.Slate)
	for k = 1, 3 do
		part(
			parent,
			"KeepStep",
			Vector3.new(10, 0.45, 1.4),
			base * CFrame.new(0, 1.4 - k * 0.45 + 0.22, -d / 2 - 0.7 - (k - 1) * 1.3),
			WALL_LIGHT,
			Enum.Material.Slate
		)
	end
	-- Fenêtres sur deux niveaux
	for _, y in { 8, 15 } do
		for _, x in { -10, -5, 5, 10 } do
			local win = base * CFrame.new(x, y, -d / 2 - 0.05)
			part(
				parent,
				"KeepWindow",
				Vector3.new(1.8, 3, 0.2),
				win,
				Color3.fromRGB(60, 85, 120),
				Enum.Material.Glass,
				{ NoShadow = true }
			)
			part(
				parent,
				"KeepWindowFrame",
				Vector3.new(2.4, 3.6, 0.15),
				win * CFrame.new(0, 0, 0.1),
				WALL_LIGHT,
				Enum.Material.Slate
			)
		end
	end
	-- Bannières royales encadrant la porte
	for _, x in { -6.5, 6.5 } do
		local b = base * CFrame.new(x, 12, -d / 2 - 0.15)
		part(parent, "KeepBanner", Vector3.new(3, 9, 0.1), b, ROYAL_BLUE, Enum.Material.Fabric, { CanCollide = false })
		part(
			parent,
			"KeepBannerCrest",
			Vector3.new(1.4, 1.4, 0.14),
			b * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(45)),
			GOLD,
			Enum.Material.Metal,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
	end
	-- Tour centrale
	local tower = base * CFrame.new(0, h + 0.8, 2)
	part(
		parent,
		"CentralTower",
		Vector3.new(10, 10, 8),
		tower * CFrame.new(0, 5, 0),
		WALL_STONE,
		Enum.Material.Cobblestone
	)
	for k, size in { 12, 9.5, 7, 4.5, 2 } do
		part(
			parent,
			"CentralRoof",
			Vector3.new(size, 1.5, size * 0.8),
			tower * CFrame.new(0, 10.7 + (k - 1) * 1.4, 0),
			if k % 2 == 0 then C.RoofDark else C.Roof,
			Enum.Material.Slate
		)
	end
	local top = tower * CFrame.new(0, 17.5, 0)
	column(parent, "KeepFlagPole", 6, 0.3, top, C.WoodDark, Enum.Material.Wood)
	part(
		parent,
		"KeepFlag",
		Vector3.new(0.1, 2.4, 4),
		top * CFrame.new(0, 4.6, 2),
		ROYAL_BLUE,
		Enum.Material.Fabric,
		{ CanCollide = false }
	)
	part(
		parent,
		"KeepFlagCrest",
		Vector3.new(0.12, 1, 1),
		top * CFrame.new(0, 4.6, 2) * CFrame.Angles(math.rad(45), 0, 0),
		GOLD,
		Enum.Material.Fabric,
		{
			CanCollide = false,
			NoShadow = true,
		}
	)
end

--[[
	Cour royale complète : sol pavé, allées dallées, enceinte octogonale (remparts, tours,
	portes fortifiées), donjon au nord, route pavée extérieure et routes des portes.
	Côtés de l'octogone centrés sur 0°, 45°, 90°... (x = cos, z = sin).
]]
function Models.castle(parent: Instance, cfg)
	local A = cfg.CourtyardApothem
	local t = cfg.WallThickness
	local side = 2 * A * math.tan(math.rad(22.5))
	local vertexR = (A + t / 2) / math.cos(math.rad(22.5))

	-- Sol pavé (dessus à y = 1) et allées dallées vers les portes et le donjon
	part(
		parent,
		"CourtyardPaving",
		Vector3.new(1, vertexR * 2, vertexR * 2),
		CFrame.new(0, 0.5, 0) * VERTICAL,
		PAVING,
		Enum.Material.Cobblestone,
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
	for _, a in { 0, 180, 270, 90 } do
		local r = math.rad(a)
		local len = if a == 90 then 30 else A
		local mid = len / 2 + 4
		part(
			parent,
			"Alley",
			Vector3.new(len, 0.12, 7),
			CFrame.new(math.cos(r) * mid, 1.04, math.sin(r) * mid) * CFrame.Angles(0, -r, 0),
			WALL_LIGHT,
			Enum.Material.Slate,
			{
				NoShadow = true,
			}
		)
		for _, s in { -1, 1 } do
			part(
				parent,
				"AlleyEdge",
				Vector3.new(len, 0.16, 0.5),
				CFrame.new(math.cos(r) * mid, 1.06, math.sin(r) * mid)
					* CFrame.Angles(0, -r, 0)
					* CFrame.new(0, 0, s * 3.75),
				WALL_DARK,
				Enum.Material.Slate,
				{
					NoShadow = true,
				}
			)
		end
	end
	column(parent, "PavingRing", 0.1, 20, CFrame.new(0, 1, 0), WALL_LIGHT, Enum.Material.Slate, { NoShadow = true })

	-- Enceinte
	local gates = {}
	for _, g in cfg.GateAngles do
		gates[g] = true
	end
	for k = 0, 7 do
		local deg = k * 45
		local a = math.rad(deg)
		local center = Vector3.new(math.cos(a) * (A + t / 2), 0, math.sin(a) * (A + t / 2))
		local frame = CFrame.lookAt(center, Vector3.new(0, 0, 0)) -- -Z vers la cour
		if gates[deg] then
			local seg = (side - cfg.GateWidth - 6) / 2
			for _, s in { -1, 1 } do
				wallSegment(parent, frame * CFrame.new(s * (cfg.GateWidth / 2 + 3 + seg / 2), 0, 0), seg, cfg, false)
			end
			gatehouse(parent, frame, cfg)
		else
			wallSegment(parent, frame, side, cfg, deg ~= 90)
		end
		local va = a + math.rad(22.5)
		roundTower(
			parent,
			CFrame.new(math.cos(va) * vertexR, 0, math.sin(va) * vertexR),
			9,
			cfg.WallHeight + 5,
			k % 2 == 0
		)
	end

	-- Donjon royal au nord, adossé au rempart
	royalKeep(parent, CFrame.lookAt(Vector3.new(0, 0, A - 7), Vector3.new(0, 0, -100)))

	-- Route pavée extérieure (anneau) et routes des portes
	local R, W = cfg.RingRoadRadius, cfg.RingRoadWidth
	local segments = 40
	for k = 1, segments do
		local a = (k / segments) * math.pi * 2
		local len = 2 * math.pi * R / segments * 1.04
		part(
			parent,
			"RingRoad",
			Vector3.new(len, 0.6, W),
			CFrame.new(math.cos(a) * R, 0.3, math.sin(a) * R) * CFrame.Angles(0, -a + math.pi / 2, 0),
			PAVING,
			Enum.Material.Cobblestone
		)
	end
	for _, g in cfg.GateAngles do
		local a = math.rad(g)
		local from, to = A + t, R - W / 2
		local mid = (from + to) / 2
		part(
			parent,
			"GateRoad",
			Vector3.new(to - from + 1, 0.6, cfg.GateWidth),
			CFrame.new(math.cos(a) * mid, 0.3, math.sin(a) * mid) * CFrame.Angles(0, -a, 0),
			PAVING,
			Enum.Material.Cobblestone
		)
	end
end

-- Bastion (parcelle) : enceinte basse crénelée, tours d'angle, portail d'entrée à arc avec
-- torches, allée dallée jusqu'au Noyau. `base` au sol de la parcelle, -Z = entrée (vers le hub).
function Models.plotDecor(base: CFrame, plotSize: number, parent: Instance)
	local half = plotSize / 2
	local h, t = 3.6, 1.4
	local gate = 12
	local function lowWall(cf: CFrame, length: number)
		part(
			parent,
			"LowWall",
			Vector3.new(length, h, t),
			cf * CFrame.new(0, h / 2, 0),
			WALL_STONE,
			Enum.Material.Cobblestone
		)
		part(
			parent,
			"LowWallCap",
			Vector3.new(length, 0.35, t + 0.3),
			cf * CFrame.new(0, h + 0.17, 0),
			WALL_LIGHT,
			Enum.Material.Slate
		)
		local count = math.max(1, math.floor(length / 4))
		for k = 0, count - 1 do
			if k % 2 == 0 then
				part(
					parent,
					"LowMerlon",
					Vector3.new(length / count * 0.9, 0.9, t),
					cf * CFrame.new(-length / 2 + (k + 0.5) * (length / count), h + 0.8, 0),
					WALL_STONE,
					Enum.Material.Cobblestone
				)
			end
		end
	end
	-- Trois côtés pleins, façade d'entrée ouverte au centre
	lowWall(base * CFrame.new(0, 0, half - t / 2), plotSize - 4)
	for _, sx in { -1, 1 } do
		lowWall(base * CFrame.new(sx * (half - t / 2), 0, 0) * CFrame.Angles(0, math.rad(90), 0), plotSize - 4)
		local seg = (plotSize - gate) / 2 - 2
		lowWall(base * CFrame.new(sx * (gate / 2 + seg / 2), 0, -half + t / 2), seg)
	end
	-- Tours d'angle (cylindres à créneaux et toit en gradins)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			local tower = base * CFrame.new(cx * (half - 1.5), 0, cz * (half - 1.5))
			column(parent, "CornerTower", 7, 4.2, tower, WALL_STONE, Enum.Material.Cobblestone)
			column(parent, "CornerTowerTop", 0.6, 5, tower * CFrame.new(0, 7, 0), WALL_LIGHT, Enum.Material.Slate)
			for k, sc in { 1, 0.7, 0.4 } do
				column(
					parent,
					"CornerRoof",
					1.1,
					5 * sc,
					tower * CFrame.new(0, 7.6 + (k - 1) * 1, 0),
					if k % 2 == 0 then C.RoofDark else C.Roof,
					Enum.Material.Slate
				)
			end
		end
	end
	-- Portail : piliers à chapiteau doré, arc de claveaux, torches
	for _, sx in { -1, 1 } do
		local pillar = base * CFrame.new(sx * (gate / 2 + 1), 0, -half + t / 2)
		part(
			parent,
			"GatePillar",
			Vector3.new(2, 7.5, 2),
			pillar * CFrame.new(0, 3.75, 0),
			WALL_DARK,
			Enum.Material.Cobblestone
		)
		part(
			parent,
			"GatePillarCap",
			Vector3.new(2.6, 0.5, 2.6),
			pillar * CFrame.new(0, 7.75, 0),
			GOLD,
			Enum.Material.Metal
		)
		local torch = pillar * CFrame.new(0, 5, -1.2)
		part(parent, "Sconce", Vector3.new(0.5, 1, 0.5), torch, C.WoodDark, Enum.Material.Wood)
		part(
			parent,
			"Flame",
			Vector3.new(0.6, 0.8, 0.6),
			torch * CFrame.new(0, 0.9, 0),
			Color3.fromRGB(255, 160, 70),
			Enum.Material.Neon,
			{
				CanCollide = false,
				NoShadow = true,
			}
		)
	end
	arch(parent, base * CFrame.new(0, 7.2, -half + t / 2), gate / 2 + 1, 1.4, 2, 11, WALL_LIGHT, Enum.Material.Slate)
	part(
		parent,
		"GateKeystone",
		Vector3.new(1.4, 1.4, 2.2),
		base * CFrame.new(0, 7.2 + gate / 2 + 1.9, -half + t / 2) * CFrame.Angles(0, 0, math.rad(45)),
		GOLD,
		Enum.Material.Metal,
		{
			NoShadow = true,
		}
	)
	-- Allée dallée de l'entrée au Noyau d'Éther, bordée de pierre
	local alleyLength = half + 2
	local alley = base * CFrame.new(0, 0.06, -half + alleyLength / 2)
	part(
		parent,
		"PlotAlley",
		Vector3.new(6, 0.12, alleyLength),
		alley,
		WALL_LIGHT,
		Enum.Material.Slate,
		{ NoShadow = true }
	)
	for _, sx in { -1, 1 } do
		part(
			parent,
			"PlotAlleyEdge",
			Vector3.new(0.5, 0.16, alleyLength),
			alley * CFrame.new(sx * 3.25, 0.02, 0),
			WALL_DARK,
			Enum.Material.Slate,
			{
				NoShadow = true,
			}
		)
	end
end

return Models
