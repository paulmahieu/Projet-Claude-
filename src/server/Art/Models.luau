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

-- Fiches du pack de décors importé (Config/Decors), transmises par Models.setDecors.
local decorDefs: { [string]: any } = {}

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

-- Générateur pseudo-aléatoire déterministe (même rendu à chaque génération).
local function rng(seed: number)
	local state = math.floor(math.abs(seed) * 7919 + 12345) % 2147483646 + 1
	return function(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end
Models.rng = rng

-- Ressources ---------------------------------------------------------------------------

-- Arbres (planches du créateur) ----------------------------------------------------------
-- Feuillage en « bouquets de feuilles » à facettes : un cœur arrondi recouvert de cartes de
-- feuilles en losange, inclinées vers l'extérieur, en deux ou trois teintes (style low-poly des
-- planches). Troncs torsadés en segments, racines évasées, branches vers chaque bouquet.

local LEAF_MAT = Enum.Material.SmoothPlastic

-- Bouquet de feuilles centré en `center`, rayon r. colors = { sombre, moyen, clair }.
local function leafClump(m, center: CFrame, r: number, colors, seed: number, accent: Color3?)
	local rand = rng(seed)
	local core =
		part(m, "LeafCore", Vector3.new(r * 2, r * 1.5, r * 2), center, colors[1], LEAF_MAT, { Depletable = true })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = core
	-- Facettes de feuilles posées sur le dôme (tangentes, légèrement soulevées), plus claires
	-- vers le haut : aspect « low-poly » des planches.
	for _, ring in { { -0.15, 9, 1 }, { 0.35, 8, 2 }, { 0.75, 5, 3 }, { 1.2, 1, 3 } } do
		local elev = ring[1]
		for k = 0, ring[2] - 1 do
			local a = (k + rand() * 0.5) / ring[2] * math.pi * 2
			local dir = Vector3.new(math.cos(elev) * math.cos(a), math.sin(elev) * 0.75, math.cos(elev) * math.sin(a))
			local pos = dir * r * 0.95
			local s = r * (0.62 + rand() * 0.2)
			local at = center * CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(12), 0, rand() * 0.6)
			part(
				m,
				"Leaf",
				Vector3.new(s, s, 0.16),
				at * CFrame.Angles(0, 0, math.rad(45)),
				colors[ring[3]]:Lerp(colors[math.min(3, ring[3] + 1)], rand() * 0.6),
				LEAF_MAT,
				{ Depletable = true, NoShadow = ring[3] < 3 }
			)
			if accent and rand() < 0.2 then
				part(
					m,
					"LeafAccent",
					Vector3.new(s * 0.35, s * 0.35, 0.18),
					at * CFrame.new(0, 0, -0.04) * CFrame.Angles(0, 0, math.rad(45)),
					accent,
					LEAF_MAT,
					{ Depletable = true, NoShadow = true }
				)
			end
		end
	end
end

-- Tronc torsadé : segments coniques légèrement tournés. Retourne le repère du sommet.
local function twistedTrunk(
	m,
	base: CFrame,
	height: number,
	d0: number,
	d1: number,
	color: Color3,
	seed: number,
	segments: number?,
	lean: number?
)
	local n = segments or 5
	local cf = base
	for k = 0, n - 1 do
		local t = k / n
		local d = d0 + (d1 - d0) * t
		local h = height / n
		part(
			m,
			"Trunk",
			Vector3.new(d, h * 1.15, d * 0.92),
			cf * CFrame.new(0, h / 2, 0),
			color:Lerp(Color3.new(0, 0, 0), (k % 2) * 0.06),
			Enum.Material.Wood,
			{ Depletable = true }
		)
		cf = cf
			* CFrame.new(0, h, 0)
			* CFrame.Angles(math.sin(seed + k) * 0.06, 0.35, (lean or 0) + math.cos(seed + k * 1.3) * 0.06)
	end
	return cf
end

-- Branche de `from` (repère) vers un point local au modèle ; retourne la longueur.
local function branchTo(m, from: Vector3, to: Vector3, d: number, color: Color3)
	local len = (to - from).Magnitude
	part(
		m,
		"Branch",
		Vector3.new(d, d, len),
		CFrame.lookAt((from + to) / 2, to),
		color,
		Enum.Material.Wood,
		{ Depletable = true }
	)
end

-- Souche et racines évasées (restent visibles après la récolte).
local function stumpAndRoots(m, turn: CFrame, d: number, color: Color3, count: number, reach: number): BasePart
	local stump = column(m, "Stump", 1.2, d, turn, color, Enum.Material.Wood)
	part(
		m,
		"StumpTop",
		Vector3.new(0.2, d * 0.82, d * 0.82),
		turn * CFrame.new(0, 1.25, 0) * VERTICAL,
		C.WoodLight,
		Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder }
	)
	part(
		m,
		"StumpRing",
		Vector3.new(0.22, d * 0.5, d * 0.5),
		turn * CFrame.new(0, 1.27, 0) * VERTICAL,
		C.Bark:Lerp(C.WoodLight, 0.45),
		Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder, NoShadow = true }
	)
	for r = 1, count do
		local a = r / count * math.pi * 2 + 0.4
		local root = turn * CFrame.Angles(0, a, 0)
		part(
			m,
			"Root" .. r,
			Vector3.new(reach, 0.7, 0.8),
			root * CFrame.new(d * 0.3 + reach / 2, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-16)),
			color:Lerp(C.WoodDark, 0.25),
			Enum.Material.Wood
		)
		part(
			m,
			"RootTip" .. r,
			Vector3.new(reach * 0.5, 0.4, 0.5),
			root * CFrame.new(d * 0.3 + reach * 1.15, 0.12, 0.2) * CFrame.Angles(0, 0.4, math.rad(-8)),
			color:Lerp(C.WoodDark, 0.35),
			Enum.Material.Wood
		)
	end
	return stump
end

local OAK = { Color3.fromRGB(46, 110, 52), Color3.fromRGB(70, 140, 60), Color3.fromRGB(150, 200, 70) }
local BIRCH = { Color3.fromRGB(110, 160, 50), Color3.fromRGB(150, 196, 60), Color3.fromRGB(196, 226, 90) }
local MAPLE = { Color3.fromRGB(205, 85, 35), Color3.fromRGB(235, 140, 40), Color3.fromRGB(250, 200, 60) }
local MAPLE_RED = { Color3.fromRGB(150, 35, 35), Color3.fromRGB(190, 55, 45), Color3.fromRGB(220, 90, 60) }
local FIR = { Color3.fromRGB(26, 80, 60), Color3.fromRGB(36, 104, 72), Color3.fromRGB(56, 130, 86) }
local ANCIENT = { Color3.fromRGB(24, 110, 80), Color3.fromRGB(36, 150, 100), Color3.fromRGB(70, 190, 120) }
local WILLOW = { Color3.fromRGB(130, 80, 190), Color3.fromRGB(170, 110, 225), Color3.fromRGB(205, 160, 245) }
local SNOW = Color3.fromRGB(245, 248, 252)

local treeBuilders = {}

-- Chêne des clairières : tronc large torsadé, nœud en spirale, cinq bouquets vert sombre/clair.
treeBuilders.Oak = function(m, turn, s, seed)
	local bark = Color3.fromRGB(130, 82, 48)
	local top = twistedTrunk(m, turn * CFrame.new(0, 1.2, 0), 6.5 * s, 2.3 * s, 1.3 * s, bark, seed)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		part(
			m,
			"Knot",
			Vector3.new(0.25, 0.25, 0.15),
			turn * CFrame.new(math.cos(a) * 0.35, 3 + math.sin(a) * 0.35, -1.12 * s),
			bark:Lerp(C.WoodDark, 0.4),
			Enum.Material.Wood,
			{ Depletable = true, NoShadow = true }
		)
	end
	local p0 = top.Position
	local clumps = {
		{ 0, 2.5, 0, 3.4 },
		{ 3.2, 0.6, 0.6, 2.6 },
		{ -3.0, 0.9, -0.8, 2.7 },
		{ 0.8, 0.4, 2.8, 2.4 },
		{ -0.5, 0.5, -2.9, 2.4 },
	}
	for k, c in clumps do
		local at = top * CFrame.new(c[1] * s, c[2] * s, c[3] * s)
		if k > 1 then
			branchTo(m, p0, at.Position, 0.55 * s, bark)
		end
		leafClump(m, at, c[4] * s, OAK, seed + k * 7)
	end
end

-- Bouleau des lisières : deux troncs blancs fourchus à marques noires, bouquets vert tendre.
treeBuilders.Birch = function(m, turn, s, seed)
	local white = Color3.fromRGB(232, 226, 210)
	for side, lean in { [-1] = -0.22, [1] = 0.22 } do
		local cf = turn * CFrame.new(side * 0.25, 1.2, 0)
		local top = twistedTrunk(m, cf, 9 * s, 0.9 * s, 0.55 * s, white, seed + side, 5, lean)
		local rand = rng(seed + side * 13)
		for k = 1, 9 do
			local y = 1.5 + k * 0.85
			local a = rand() * math.pi * 2
			part(
				m,
				"Mark",
				Vector3.new(0.4, 0.15, 0.12),
				cf
					* CFrame.Angles(0, 0, lean * y / 9)
					* CFrame.new(math.cos(a) * 0.4, y * s, math.sin(a) * 0.4)
					* CFrame.Angles(0, -a + math.pi / 2, 0),
				C.WoodDark:Lerp(Color3.new(0, 0, 0), 0.3),
				Enum.Material.SmoothPlastic,
				{ Depletable = true, NoShadow = true }
			)
		end
		leafClump(m, top * CFrame.new(0, 1.2 * s, 0), 2.1 * s, BIRCH, seed + side * 3)
		local mid = cf * CFrame.new(side * 0.6, 5 * s, 0)
		branchTo(m, mid.Position, (mid * CFrame.new(side * 2.4 * s, 1.2 * s, 0.4)).Position, 0.25 * s, white)
		leafClump(m, mid * CFrame.new(side * 2.8 * s, 1.5 * s, 0.4), 1.6 * s, BIRCH, seed + side * 5)
	end
end

-- Érable d'automne : tronc fourchu, gros bouquets orange et jaunes, un bouquet rouge.
treeBuilders.Maple = function(m, turn, s, seed)
	local bark = Color3.fromRGB(135, 75, 45)
	local top = twistedTrunk(m, turn * CFrame.new(0, 1.2, 0), 5.5 * s, 1.9 * s, 1.0 * s, bark, seed)
	local p0 = top.Position
	local clumps = {
		{ 0, 3.2, 0, 3.0, MAPLE },
		{ -2.8, 1.4, 0.4, 2.6, MAPLE },
		{ 2.9, 0.8, -0.3, 2.2, MAPLE_RED },
		{ 0.6, 1.0, 2.6, 2.3, MAPLE },
		{ -0.6, 1.2, -2.6, 2.2, MAPLE },
	}
	for k, c in clumps do
		local at = top * CFrame.new(c[1] * s, c[2] * s, c[3] * s)
		branchTo(m, p0, at.Position, 0.5 * s, bark)
		leafClump(m, at, c[4] * s, c[5], seed + k * 11)
	end
end

-- Sapin des montagnes : étages d'aiguilles en étoile, neige sur le dessus de chaque étage.
treeBuilders.Fir = function(m, turn, s, seed)
	local bark = Color3.fromRGB(125, 80, 48)
	twistedTrunk(m, turn * CFrame.new(0, 1.2, 0), 4 * s, 1.3 * s, 0.9 * s, bark, seed, 3)
	local tiers = 6
	for k = 0, tiers - 1 do
		local t = k / (tiers - 1)
		local r = (3.6 - t * 2.7) * s
		local y = (4.4 + k * 1.7) * s
		local count = 10 - math.floor(t * 4)
		for j = 0, count - 1 do
			local a = (j + (k % 2) * 0.5) / count * math.pi * 2
			local at = turn
				* CFrame.new(0, y, 0)
				* CFrame.Angles(0, -a, 0)
				* CFrame.new(0, 0.2, -r * 0.5)
				* CFrame.Angles(math.rad(-38), 0, 0) -- branches qui retombent : silhouette en cône
			part(
				m,
				"Needles",
				Vector3.new(r * 0.7, 0.35, r * 1.2),
				at,
				FIR[(j + k) % 3 + 1],
				LEAF_MAT,
				{ Depletable = true }
			)
			if j % 2 == 0 then
				part(
					m,
					"Snow",
					Vector3.new(r * 0.42, 0.24, r * 0.5),
					at * CFrame.new(0, 0.26, r * 0.15),
					SNOW,
					LEAF_MAT,
					{ Depletable = true, NoShadow = true }
				)
			end
		end
		part(
			m,
			"TierCore",
			Vector3.new(r * 0.9, 1.4 * s, r * 0.9),
			turn * CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(45), 0),
			FIR[1],
			LEAF_MAT,
			{ Depletable = true }
		)
	end
	part(
		m,
		"Tip",
		Vector3.new(0.9 * s, 1.6 * s, 0.9 * s),
		turn * CFrame.new(0, (4.4 + (tiers - 0.35) * 1.7) * s, 0) * CFrame.Angles(0, math.rad(45), 0),
		FIR[2],
		LEAF_MAT,
		{ Depletable = true }
	)
	part(
		m,
		"TipSnow",
		Vector3.new(0.6 * s, 0.6 * s, 0.6 * s),
		turn * CFrame.new(0, (5.0 + (tiers - 0.35) * 1.7) * s, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		SNOW,
		LEAF_MAT,
		{ Depletable = true }
	)
end

-- Arbre ancestral : tronc colossal en arche, runes dorées lumineuses, grosses branches
-- tortueuses, bouquets vert émeraude parsemés de feuilles d'or.
treeBuilders.Ancient = function(m, turn, s, seed)
	local bark = Color3.fromRGB(115, 78, 55)
	-- Deux « jambes » formant une arche, puis le fût
	for _, side in { -1, 1 } do
		twistedTrunk(
			m,
			turn * CFrame.new(side * 1.2 * s, 1.0, 0) * CFrame.Angles(0, 0, -side * 0.18),
			3.2 * s,
			1.8 * s,
			1.6 * s,
			bark,
			seed + side,
			3
		)
	end
	local top = twistedTrunk(m, turn * CFrame.new(0, 3.8 * s, 0), 4.5 * s, 3.2 * s, 2.0 * s, bark, seed, 4)
	-- Runes dorées
	for k, off in { -0.35, 0.35 } do
		local at = turn * CFrame.new(off * s, 5.6 * s, -1.6 * s)
		part(
			m,
			"Rune",
			Vector3.new(0.14, 0.9, 0.1),
			at * CFrame.Angles(0, 0, if k == 1 then 0.4 else -0.4),
			Color3.fromRGB(255, 200, 70),
			Enum.Material.Neon,
			{ Depletable = true, NoShadow = true }
		)
		part(
			m,
			"Rune",
			Vector3.new(0.14, 0.6, 0.1),
			at * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, if k == 1 then -0.5 else 0.5),
			Color3.fromRGB(255, 200, 70),
			Enum.Material.Neon,
			{ Depletable = true, NoShadow = true }
		)
	end
	-- Mousse
	for k = 0, 5 do
		local a = k * 1.1
		part(
			m,
			"Moss",
			Vector3.new(1.2, 0.5, 0.3),
			turn * CFrame.Angles(0, a, 0) * CFrame.new(0, 3 + (k % 3) * 1.2, -1.55 * s),
			C.Leaf2,
			Enum.Material.Grass,
			{ Depletable = true, NoShadow = true }
		)
	end
	local p0 = top.Position
	local accent = Color3.fromRGB(240, 200, 60)
	local clumps = {
		{ 0, 2.4, 0, 3.8 },
		{ 4.2, 0.2, 0.8, 2.8 },
		{ -4.4, 0.4, -0.4, 3.0 },
		{ 1.0, -0.2, 3.6, 2.6 },
		{ -1.0, 0.2, -3.6, 2.6 },
		{ 5.6, -1.6, -1.6, 1.8 },
	}
	for k, c in clumps do
		local at = top * CFrame.new(c[1] * s, c[2] * s, c[3] * s)
		if k > 1 then
			branchTo(m, p0, at.Position, 0.8 * s, bark)
		end
		leafClump(m, at, c[4] * s, ANCIENT, seed + k * 5, accent)
	end
end

-- Saule arcanique : tronc violet torsadé parcouru d'une veine lumineuse, cristal à la base,
-- bouquets violets d'où pendent des rideaux de feuilles.
treeBuilders.Willow = function(m, turn, s, seed)
	local bark = Color3.fromRGB(92, 68, 100)
	local base = turn * CFrame.new(0, 1.2, 0)
	local top = twistedTrunk(m, base, 7.5 * s, 2.0 * s, 1.1 * s, bark, seed, 6)
	-- Veine lumineuse qui s'enroule
	for k = 0, 11 do
		local y = 1.6 + k * 0.5
		local a = k * 0.45
		part(
			m,
			"Vein",
			Vector3.new(0.16, 0.6, 0.1),
			turn * CFrame.Angles(0, a, 0) * CFrame.new(0, y * s, -(1.0 - k * 0.03) * s) * CFrame.Angles(0, 0, 0.4),
			Color3.fromRGB(90, 230, 240),
			Enum.Material.Neon,
			{ Depletable = true, NoShadow = true }
		)
	end
	local crystal = part(
		m,
		"Crystal",
		Vector3.new(0.6, 1.3, 0.6),
		turn * CFrame.new(0, 1.0, -1.25 * s) * CFrame.Angles(0, math.rad(45), 0),
		Color3.fromRGB(110, 235, 245),
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 120, 255)
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = crystal
	local p0 = top.Position
	local clumps = {
		{ 0, 1.6, 0, 2.8 },
		{ 3.2, -0.2, 0.6, 2.3 },
		{ -3.2, 0.2, -0.6, 2.4 },
		{ 0.8, -0.4, 3.0, 2.1 },
		{ -0.8, -0.2, -3.0, 2.1 },
	}
	local rand = rng(seed)
	for k, c in clumps do
		local at = top * CFrame.new(c[1] * s, c[2] * s, c[3] * s)
		if k > 1 then
			branchTo(m, p0, at.Position, 0.5 * s, bark)
		end
		leafClump(m, at, c[4] * s, WILLOW, seed + k * 3)
		-- Rideaux tombants
		for j = 0, 7 do
			local a = j / 8 * math.pi * 2 + k
			local strand = at * CFrame.Angles(0, -a, 0) * CFrame.new(0, -c[4] * s * 0.3, -c[4] * s * 0.85)
			local len = (2 + rand() * 2.2) * s
			for q = 0, math.floor(len / 0.7) do
				part(
					m,
					"Drape",
					Vector3.new(0.55, 0.75, 0.12),
					strand * CFrame.new(0, -q * 0.65, 0) * CFrame.Angles(0, 0, math.rad(45)),
					WILLOW[(q + j) % 3 + 1],
					LEAF_MAT,
					{ Depletable = true, NoShadow = true }
				)
			end
		end
	end
end

-- variant : 1 = chêne, 2 = sapin, 3 = bouleau, 4 = érable, "Ancient", "Willow".
local TREE_KINDS = { "Oak", "Fir", "Birch", "Maple" }
local TREE_ASSETS = {
	Oak = "Tree_Oak",
	Fir = "Tree_Pine",
	Birch = "Tree_Birch",
	Maple = "Tree_Maple",
	Ancient = "Tree_Ancient",
	Willow = "Tree_Willow",
}

function Models.tree(base: CFrame, variant: number | string, seed: number): Model
	local kind = if type(variant) == "string" then variant else (TREE_KINDS[variant] or "Oak")
	local imported = Models.override(TREE_ASSETS[kind] or "Tree_Oak", base * CFrame.Angles(0, seed * 1.7, 0))
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
	m:SetAttribute("TreeKind", kind)
	local turn = base * CFrame.Angles(0, seed * 1.7, 0)
	local s = 1 + jitter(seed, 0.1)
	local big = kind == "Ancient" or kind == "Willow"
	local stumpColor = if kind == "Birch"
		then Color3.fromRGB(220, 214, 198)
		elseif kind == "Willow" then Color3.fromRGB(92, 68, 100)
		else C.Bark
	local stump = stumpAndRoots(
		m,
		turn,
		(if big then 3.2 else 2.3) * s,
		stumpColor,
		if big then 7 else 5,
		(if big then 2.6 else 1.6) * s
	)
	treeBuilders[kind](m, turn, s, seed)
	m.PrimaryPart = stump
	return m
end

function Models.rock(base: CFrame, seed: number): Model
	-- Rocher du pack importé : tout disparaît à la récolte sauf des gravats générés.
	local decor = Models.decor("03_Rocher", base * CFrame.Angles(0, seed * 2.3, 0), { Depletable = true })
	if decor then
		local rubble = part(
			decor,
			"Rubble",
			Vector3.new(1.4, 0.7, 1.2),
			base * CFrame.new(-2, 0.35, 1.4),
			C.StoneDark,
			Enum.Material.Rock
		)
		decor.PrimaryPart = rubble
		return decor
	end
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
-- Rangée de modules d'un décor répété (mur, palissade) de `from` à `to` sur l'axe X de `base` :
-- nombre entier de modules, légèrement étirés pour tomber juste (aucun décalage). Retourne
-- false si le décor n'est pas importé.
local function decorRow(id: string, parent: Instance, base: CFrame, from: number, to: number, scale: number?): boolean
	if not Models.hasDecor(id) then
		return false
	end
	local def = decorDefs[id]
	local moduleW = def.Size[1] * (scale or 1)
	local length = to - from
	local count = math.max(1, math.floor(length / moduleW + 0.5))
	local stretch = length / (count * moduleW)
	for i = 0, count - 1 do
		local x = from + (i + 0.5) * moduleW * stretch
		local piece = Models.decor(id, base * CFrame.new(x, 0, 0), { Scale = scale, StretchX = stretch })
		if piece then
			piece.Parent = parent
		end
	end
	return true
end
Models.decorRow = decorRow

builders.Palisade = function(m: Model, base: CFrame, size: Vector3)
	local sx, h = size.X, size.Y
	-- Palissade du pack importé : modules de 8 studs, passage central conservé.
	if Models.hasDecor("04_Palissade") then
		decorRow("04_Palissade", m, base, -sx / 2, -6, size.Y / 6)
		decorRow("04_Palissade", m, base, 6, sx / 2, size.Y / 6)
		return
	end
	local d = 2.4
	local count = math.floor(sx / d)
	local gap = 6 -- passage central vers les extensions de terrain (Config/Land)
	for i = 0, count - 1 do
		local x = -sx / 2 + d / 2 + i * d
		if math.abs(x) < gap then
			continue
		end
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
	local wing = sx / 2 - gap + d / 2 -- longueur de chaque moitié de palissade
	for i, y in { h * 0.28, h * 0.72 } do
		for _, side in { -1, 1 } do
			part(
				m,
				"Beam" .. i,
				Vector3.new(wing, 0.5, 0.45),
				base * CFrame.new(side * (sx / 2 - wing / 2), y, d / 2 + 0.1),
				C.WoodDark,
				Enum.Material.Wood
			)
		end
		for k = 0, math.floor(sx / 8) do
			if math.abs(-sx / 2 + 2 + k * 8) < gap then
				continue
			end
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
	for _, side in { -1, 1 } do
		part(
			m,
			"Walkway",
			Vector3.new(wing, 0.4, 2.2),
			base * CFrame.new(side * (sx / 2 - wing / 2), h * 0.62, -(d / 2 + 1.4)),
			C.WoodLight,
			Enum.Material.WoodPlanks
		)
	end
	-- Porte du passage : deux poteaux et un linteau
	for _, side in { -1, 1 } do
		column(m, "GatePost", h + 1.5, 1.1, base * CFrame.new(side * (gap - 0.4), 0, 0), C.WoodDark, Enum.Material.Wood)
	end
	part(
		m,
		"GateLintel",
		Vector3.new(gap * 2 + 0.6, 0.8, 1),
		base * CFrame.new(0, h + 1.1, 0),
		C.WoodDark,
		Enum.Material.Wood
	)
	for k = 0, math.floor(sx / 12) do
		if math.abs(-sx / 2 + 3 + k * 12) < gap + 1 then
			continue
		end
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
	-- Socle de construction : chantier balisé (piquets et rubans), stèle de pierre cerclée d'or,
	-- gemme d'état tenue par quatre griffes dorées au-dessus d'un anneau runique, plan roulé
	-- et maillet au pied. La couleur de la gemme indique l'état (prêt, manquant, verrouillé).
	local m = newModel("Pedestal")
	part(m, "Footing", Vector3.new(3.8, 0.4, 3.8), base * CFrame.new(0, 0.2, 0), C.StoneDark, Enum.Material.Cobblestone)
	local plinth =
		part(m, "Plinth", Vector3.new(2.4, 1.8, 2.4), base * CFrame.new(0, 1.3, 0), C.Stone, Enum.Material.Cobblestone)
	part(m, "Band", Vector3.new(2.6, 0.22, 2.6), base * CFrame.new(0, 0.75, 0), GOLD, Enum.Material.Metal, {
		NoShadow = true,
	})
	part(m, "Cap", Vector3.new(2.9, 0.36, 2.9), base * CFrame.new(0, 2.36, 0), C.StoneLight, Enum.Material.Slate)
	part(
		m,
		"RunePlate",
		Vector3.new(1.2, 0.8, 0.1),
		base * CFrame.new(0, 1.45, -1.24),
		C.Ether,
		Enum.Material.Neon,
		{ NoShadow = true, CanCollide = false, Transparency = 0.2 }
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p1 = (base * CFrame.new(sx * 0.75, 2.5, sz * 0.75)).Position
			local p2 = (base * CFrame.new(sx * 0.42, 3.35, sz * 0.42)).Position
			part(
				m,
				"Claw",
				Vector3.new(0.14, 0.14, (p2 - p1).Magnitude),
				CFrame.lookAt((p1 + p2) / 2, p2),
				GOLD,
				Enum.Material.Metal,
				{ NoShadow = true, CanCollide = false }
			)
		end
	end
	local ringAt = base * CFrame.new(0, 2.85, 0)
	for i = 0, 11 do
		part(
			m,
			"RuneRing",
			Vector3.new(0.5, 0.08, 0.12),
			ringAt * CFrame.Angles(0, i * math.pi / 6, 0) * CFrame.new(0, 0, 0.95),
			C.Ether,
			Enum.Material.Neon,
			{ NoShadow = true, CanCollide = false }
		)
	end
	local gem = part(
		m,
		"Gem",
		Vector3.new(1.1, 1.1, 1.1),
		base * CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Ether,
		Enum.Material.Neon,
		{ CanCollide = false, NoShadow = true }
	)
	-- Chantier balisé : piquets d'angle et rubans rouges et blancs
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for i, c in corners do
		local at = base * CFrame.new(c[1] * 2.3, 0, c[2] * 2.3)
		part(m, "Stake", Vector3.new(0.22, 1.4, 0.22), at * CFrame.new(0, 0.7, 0), C.WoodLight, Enum.Material.Wood)
		part(
			m,
			"StakeTip",
			Vector3.new(0.26, 0.2, 0.26),
			at * CFrame.new(0, 1.5, 0),
			C.Cloth,
			Enum.Material.SmoothPlastic,
			{ NoShadow = true }
		)
		local n = corners[i % 4 + 1]
		local to = base * CFrame.new(n[1] * 2.3, 0, n[2] * 2.3)
		for k, y in { 1.15, 0.85 } do
			local p1 = (at * CFrame.new(0, y, 0)).Position
			local p2 = (to * CFrame.new(0, y, 0)).Position
			part(
				m,
				"Tape",
				Vector3.new(0.04, 0.14, (p2 - p1).Magnitude - 0.24),
				CFrame.lookAt((p1 + p2) / 2, p2),
				if k == 1 then C.Cloth else Color3.fromRGB(240, 236, 228),
				Enum.Material.Fabric,
				{ NoShadow = true, CanCollide = false }
			)
		end
	end
	-- Plan roulé et maillet au pied de la stèle
	part(
		m,
		"Blueprint",
		Vector3.new(1.4, 0.32, 0.32),
		base * CFrame.new(-0.6, 0.56, -1.6) * CFrame.Angles(0, math.rad(15), 0),
		Color3.fromRGB(80, 130, 200),
		Enum.Material.Fabric,
		{ Shape = Enum.PartType.Cylinder, NoShadow = true, CanCollide = false }
	)
	part(
		m,
		"MalletHandle",
		Vector3.new(0.12, 0.12, 1),
		base * CFrame.new(0.9, 0.48, -1.55) * CFrame.Angles(0, math.rad(-30), 0),
		C.WoodLight,
		Enum.Material.Wood,
		{ NoShadow = true, CanCollide = false }
	)
	part(
		m,
		"MalletHead",
		Vector3.new(0.55, 0.36, 0.36),
		base * CFrame.new(1.15, 0.6, -1.95) * CFrame.Angles(0, math.rad(-30), 0),
		C.WoodDark,
		Enum.Material.Wood,
		{ NoShadow = true, CanCollide = false }
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
	local decor = Models.decor("09_Buisson", base * CFrame.Angles(0, seed * 1.9, 0), { Scale = s })
	if decor then
		decor.Parent = parent
		return
	end
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
	-- Bannières : les deux du sud sont écartées pour ne pas masquer les œufs royaux.
	for i, deg in { 135, 200, 340, 45 } do
		local angle = math.rad(deg)
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

-- Pack de décors importé (Blender) ---------------------------------------------------------------
-- Les fiches (Config/Decors) sont transmises par le serveur (Models.setDecors). Un décor n'est
-- utilisé que s'il a été importé dans ServerStorage > Assets ; sinon chaque fonction garde son
-- modèle généré. Aucun identifiant d'asset n'est écrit dans le code.

function Models.setDecors(cfg)
	decorDefs = { __tolerance = cfg.Tolerance }
	for _, def in cfg.List do
		decorDefs[def.Id] = def
	end
end

local function decorSource(id: string): Model?
	local folder = assetFolder()
	local source = folder and folder:FindFirstChild(id)
	if source and source:IsA("Model") and decorDefs[id] then
		return source
	end
	return nil
end

function Models.hasDecor(id: string): boolean
	return decorSource(id) ~= nil
end

-- Nombre de pièces d'un décor importé (pour limiter les répétitions coûteuses).
function Models.decorPartCount(id: string): number
	local source = decorSource(id)
	local n = 0
	if source then
		for _, inst in source:GetDescendants() do
			if inst:IsA("BasePart") then
				n += 1
			end
		end
	end
	return n
end

local function matchesAny(name: string, prefixes: { string }?): boolean
	for _, prefix in prefixes or {} do
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

--[[
	Place un décor importé, le dessous centré sur `base` (-Z de `base` = face avant).
	opts : { Scale = nombre (taille relative), StretchX = nombre (étirement d'un module répété),
	         Depletable = true (pièces marquées pour la récolte) }
	Retourne le modèle et, pour le portail, la liste des battants { Hinge, Parts, OpenAngle }.
	Contrôles : scripts supprimés ; taille comparée au manifeste et corrigée ; maillages ancrés et
	non collisionnables ; collisions par boîtes invisibles ; lumière de la torche.
]]
function Models.decor(id: string, base: CFrame, opts): (Model?, { any }?)
	local source = decorSource(id)
	if not source then
		return nil, nil
	end
	opts = opts or {}
	local def = decorDefs[id]
	local m = source:Clone()
	for _, inst in m:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanTouch = false
			if opts.Depletable and (def.Depletable == nil or matchesAny(inst.Name, def.Depletable)) then
				inst:SetAttribute("Depletable", true)
			end
		end
	end
	-- Échelle : la largeur attendue fait foi (unités FBX parfois mal interprétées à l'import).
	local _, size = m:GetBoundingBox()
	local expected = Vector3.new(def.Size[1], def.Size[2], def.Size[3])
	local fix = expected.X / math.max(size.X, 0.01)
	local scale = (opts.Scale or 1) * (if math.abs(fix - 1) > (decorDefs.__tolerance or 0.12) then fix else 1)
	if math.abs(scale - 1) > 0.001 then
		m:ScaleTo(m:GetScale() * scale)
	end
	local unit = (opts.Scale or 1) -- échelle des données du manifeste (charnières, boîtes)
	-- Étirement horizontal d'un module répété (murs, palissades, pavés) : aligne les modules.
	local stretch = opts.StretchX or 1
	local boxCf, boxSize = m:GetBoundingBox()
	if math.abs(stretch - 1) > 0.001 then
		for _, inst in m:GetDescendants() do
			if inst:IsA("BasePart") then
				local rel = boxCf:ToObjectSpace(inst.CFrame)
				inst.Size = Vector3.new(inst.Size.X * stretch, inst.Size.Y, inst.Size.Z)
				inst.CFrame = boxCf * (CFrame.new(rel.X * stretch, rel.Y, rel.Z) * (rel - rel.Position))
			end
		end
		boxCf, boxSize = m:GetBoundingBox()
	end
	-- Pose : le dessous du décor sur `base`.
	local bottom = boxCf * CFrame.new(0, -boxSize.Y / 2, 0)
	local delta = base * bottom:Inverse()
	for _, inst in m:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.CFrame = delta * inst.CFrame
		end
	end
	local scaleV = Vector3.new(unit * stretch, unit, unit)
	-- Collisions simples (boîtes invisibles)
	for i, box in (def.Collision and def.Collision.Boxes) or {} do
		local collider = part(
			m,
			"Collision" .. i,
			Vector3.new(box.Size[1], box.Size[2], box.Size[3]) * scaleV,
			base * CFrame.new(Vector3.new(box.Offset[1], box.Offset[2], box.Offset[3]) * scaleV),
			C.Stone,
			nil,
			{ Transparency = 1 }
		)
		collider.CastShadow = false
	end
	-- Lumière (torche)
	if def.Light then
		local holder = part(
			m,
			"LightAnchor",
			Vector3.new(0.2, 0.2, 0.2),
			base * CFrame.new(0, def.Light.Height * unit, 0),
			C.Stone,
			nil,
			{
				Transparency = 1,
				CanCollide = false,
			}
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(def.Light.Color[1], def.Light.Color[2], def.Light.Color[3])
		light.Range = def.Light.Range
		light.Brightness = 1.6
		light.Parent = holder
	end
	-- Battants du portail : chaque battant tourne autour de sa charnière avec sa boîte.
	local doors = nil
	if def.Doors then
		doors = {}
		for _, d in def.Doors do
			local leaf = m:FindFirstChild(d.Part, true)
			if leaf and leaf:IsA("BasePart") then
				local hinge = base * CFrame.new(Vector3.new(d.Hinge[1], d.Hinge[2], d.Hinge[3]) * scaleV)
				local w = d.Size[1] * unit * stretch
				local towards = if d.Hinge[1] < 0 then 1 else -1
				local collider = part(
					m,
					"DoorCollision",
					Vector3.new(w, d.Size[2] * unit, d.Size[3] * unit),
					hinge * CFrame.new(towards * w / 2, d.Size[2] * unit / 2, 0),
					C.Wood,
					nil,
					{ Transparency = 1 }
				)
				table.insert(doors, {
					Hinge = hinge,
					OpenAngle = d.OpenAngle,
					Parts = {
						{ Part = leaf, Offset = hinge:ToObjectSpace(leaf.CFrame) },
						{ Part = collider, Offset = hinge:ToObjectSpace(collider.CFrame) },
					},
				})
			end
		end
	end
	m.Name = def.Name
	return m, doors
end

-- Ouvre (t = 1) ou ferme (t = 0) des battants rendus par Models.decor ou Models.gateDoors.
function Models.setDoors(doors, t: number)
	for _, door in doors do
		local rot = door.Hinge * CFrame.Angles(0, math.rad(door.OpenAngle * t), 0)
		for _, entry in door.Parts do
			entry.Part.CFrame = rot * entry.Offset
		end
	end
end

-- Battants générés (sans pack importé) pour une ouverture de largeur `width` centrée sur `base`.
function Models.gateDoors(base: CFrame, width: number, height: number, parent: Instance)
	local doors = {}
	for _, side in { -1, 1 } do
		local hinge = base * CFrame.new(side * width / 2, 0, 0)
		local w = width / 2 - 0.1
		local towards = -side
		local leaf = part(
			parent,
			"GateLeaf",
			Vector3.new(w, height, 0.45),
			hinge * CFrame.new(towards * w / 2, height / 2, 0),
			C.Wood,
			Enum.Material.WoodPlanks
		)
		local entries = { { Part = leaf, Offset = hinge:ToObjectSpace(leaf.CFrame) } }
		for _, y in { height * 0.25, height * 0.75 } do
			local band = part(
				parent,
				"GateLeafBand",
				Vector3.new(w - 0.2, 0.35, 0.6),
				hinge * CFrame.new(towards * w / 2, y, 0),
				C.Metal,
				Enum.Material.Metal,
				{ NoShadow = true }
			)
			table.insert(entries, { Part = band, Offset = hinge:ToObjectSpace(band.CFrame) })
		end
		table.insert(doors, { Hinge = hinge, OpenAngle = side * 70, Parts = entries })
	end
	return doors
end

-- Torche sur pied : décor importé « 08_Torche » ou version générée (socle, manche, brasero,
-- flammes, lumière).
function Models.torch(base: CFrame, parent: Instance): Model
	local imported = Models.decor("08_Torche", base)
	if imported then
		imported.Parent = parent
		return imported
	end
	local m = newModel("Torche")
	part(m, "Socle", Vector3.new(1.8, 0.7, 1.8), base * CFrame.new(0, 0.35, 0), C.StoneDark, Enum.Material.Slate)
	column(m, "Manche", 4.2, 0.45, base * CFrame.new(0, 0.7, 0), C.WoodDark, Enum.Material.Wood)
	part(m, "Brasero", Vector3.new(1.2, 0.45, 1.2), base * CFrame.new(0, 5.1, 0), C.StoneDark, Enum.Material.Metal)
	for i, f in
		{
			{ 0.15, 0, -0.1, Color3.fromRGB(230, 60, 40), 1.1 },
			{ -0.15, 0, 0.05, Color3.fromRGB(255, 140, 40), 0.9 },
			{ 0, 0, 0.2, Color3.fromRGB(255, 210, 70), 0.6 },
		}
	do
		local flame = part(
			m,
			"Flamme" .. i,
			Vector3.new(0.35, f[5], 0.35),
			base * CFrame.new(f[1], 5.35 + f[5] / 2, f[3]) * CFrame.Angles(0, math.rad(45), 0),
			f[4],
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true }
		)
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 170, 90)
			light.Range = 18
			light.Brightness = 1.6
			light.Parent = flame
		end
	end
	m.Parent = parent
	return m
end

-- Minerai de cristal (ressource) : décor importé « 10_Minerai_cristal » ou version générée.
-- Les cristaux disparaissent à la récolte ; le socle de roche reste.
function Models.crystalOre(base: CFrame, seed: number): Model
	local turn = base * CFrame.Angles(0, seed * 1.3, 0)
	local imported = Models.decor("10_Minerai_cristal", turn, { Depletable = true })
	if imported then
		local anchorPart =
			part(imported, "OreAnchor", Vector3.new(0.4, 0.4, 0.4), turn * CFrame.new(0, 1, 0), C.Stone, nil, {
				Transparency = 1,
				CanCollide = false,
			})
		imported.PrimaryPart = anchorPart
		return imported
	end
	local m = newModel("Minerai de cristal")
	local rock = part(
		m,
		"Roche",
		Vector3.new(3.6, 1.2, 2.8),
		turn * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0.3, 0),
		C.StoneDark,
		Enum.Material.Slate
	)
	part(
		m,
		"RocheHaut",
		Vector3.new(2.6, 0.6, 2),
		turn * CFrame.new(0.2, 1.3, 0) * CFrame.Angles(0, -0.4, 0.06),
		C.StoneDark:Lerp(C.Stone, 0.3),
		Enum.Material.Slate
	)
	for i, c in { { 0.1, -0.15, 2.7, 0 }, { -0.95, 0.12, 1.8, -0.32 }, { 1.16, 0.08, 1.6, 0.35 } } do
		local crystal = turn * CFrame.new(c[1], 1.2, c[2]) * CFrame.Angles(0, 0, c[4])
		part(
			m,
			"Cristal" .. i,
			Vector3.new(0.55, c[3], 0.55),
			crystal * CFrame.new(0, c[3] / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color3.fromRGB(70, 190, 210),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true, Depletable = true }
		)
		part(
			m,
			"CristalPointe" .. i,
			Vector3.new(0.4, 0.4, 0.4),
			crystal * CFrame.new(0, c[3], 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color3.fromRGB(150, 235, 245),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true, Depletable = true }
		)
	end
	m.PrimaryPart = rock
	return m
end

-- Œufs, portails, arènes, boss ----------------------------------------------------------------

-- Présentoir d'œuf : socle, œuf (ellipsoïde), anneau lumineux. Retourne model, socle.
-- Œufs détaillés (designs du créateur) ---------------------------------------------------
-- Un œuf = ellipsoïde (SpecialMesh) + éléments posés sur sa surface : plaques, bandes,
-- écailles, cristaux, feuilles, filigranes. Face avant = -Z du présentoir (vers le hub).

local EGG_FRONT = -math.pi / 2 -- angle phi de la face avant

-- Repère posé sur la surface d'un ellipsoïde (demi-axes a, b, a), -Z vers l'extérieur,
-- Y le long du méridien (vers la pointe). theta : 0 = pointe, pi = base.
local function eggPoint(center: CFrame, a: number, b: number, theta: number, phi: number, lift: number?): CFrame
	local s, c = math.sin(theta), math.cos(theta)
	local x, y, z = a * s * math.cos(phi), b * c, a * s * math.sin(phi)
	local n = Vector3.new(x / (a * a), y / (b * b), z / (a * a)).Unit
	local p = Vector3.new(x, y, z) + n * (lift or 0)
	local up = if math.abs(n.Y) > 0.97 then Vector3.new(-math.cos(phi), 0, -math.sin(phi)) else Vector3.new(0, 1, 0)
	return center * CFrame.lookAt(p, p + n, up)
end

local function eggBody(m, center: CFrame, a: number, b: number, color: Color3, material, name: string?)
	local body =
		part(m, name or "Egg", Vector3.new(2 * a, 2 * b, 2 * a), center, color, material or Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	return body
end

-- Bas d'une autre teinte sans bourrelet : même ellipsoïde, à peine plus large, abaissé de
-- `shift` (la limite des couleurs se place vers y = -shift / 2).
local function eggLowerShift(m, center: CFrame, a: number, b: number, shift: number, color: Color3, material)
	eggBody(m, center * CFrame.new(0, -shift, 0), a * 1.01, b * 1.01, color, material, "EggLower")
end

-- Bas de l'œuf d'une autre teinte : second ellipsoïde légèrement plus large, posé au fond.
local function eggLower(m, center: CFrame, a: number, b: number, frac: number, color: Color3, material)
	local h = b * frac
	eggBody(m, center * CFrame.new(0, -b + h, 0), a * 1.008, h, color, material, "EggLower")
end

local function thetaAt(b: number, y: number): number
	return math.acos(math.clamp(y / b, -0.999, 0.999))
end

-- Bande autour de l'œuf à la hauteur y (ondulée si wave > 0).
local function eggRing(m, center, a, b, y, width, thick, color, material, count, wave, waveK, phase)
	for k = 0, count - 1 do
		local phi = (k + 0.5) / count * math.pi * 2
		local yy = y + (wave or 0) * math.sin(phi * (waveK or 3) + (phase or 0))
		local theta = thetaAt(b, yy)
		local radius = a * math.sin(theta)
		local seg = 2 * math.pi * radius / count * 1.12
		-- Pente de l'ondulation : chaque segment suit la vague (pas d'effet d'escalier).
		local slope = (wave or 0) * (waveK or 3) * math.cos(phi * (waveK or 3) + (phase or 0)) / math.max(0.2, radius)
		part(
			m,
			"EggBand",
			Vector3.new(seg, width, thick),
			eggPoint(center, a, b, theta, phi, thick / 2 - 0.03) * CFrame.Angles(0, 0, math.atan(slope)),
			color,
			material,
			{ CanCollide = false, NoShadow = true }
		)
	end
end

-- Bande le long d'un méridien (phi peut varier avec theta : filigrane courbe).
local function eggMeridian(m, center, a, b, phiOf, t0, t1, width, thick, color, material, steps)
	for k = 0, steps - 1 do
		local th = t0 + (t1 - t0) * (k + 0.5) / steps
		local d = (t1 - t0) / steps
		local phi = phiOf(th)
		local along = math.sqrt((a * math.cos(th)) ^ 2 + (b * math.sin(th)) ^ 2) -- sens du méridien
		local across = (phiOf(th + 0.01) - phi) / 0.01 * a * math.sin(th) -- sens du parallèle
		local len = math.sqrt(along * along + across * across) * d * 1.18
		local cf = eggPoint(center, a, b, th, phi, thick / 2 - 0.03)
		part(
			m,
			"EggStrip",
			Vector3.new(width + (k % 2) * 0.08, len, thick + (k % 2) * 0.1),
			cf * CFrame.Angles(0, 0, math.atan(across / math.max(0.05, along))),
			color,
			material,
			{ CanCollide = false, NoShadow = true }
		)
	end
end

-- Gemme en losange (avec cadre) posée sur la surface.
local function eggGem(m, cf: CFrame, size: number, gem: Color3, frame: Color3?, gemMaterial)
	if frame then
		part(
			m,
			"GemFrame",
			Vector3.new(size * 1.35, size * 1.35, 0.14),
			cf * CFrame.new(0, 0, -0.02) * CFrame.Angles(0, 0, math.rad(45)),
			frame,
			Enum.Material.Metal,
			{ CanCollide = false, NoShadow = true }
		)
	end
	part(
		m,
		"Gem",
		Vector3.new(size, size, 0.22),
		cf * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, 0, math.rad(45)),
		gem,
		gemMaterial or Enum.Material.Neon,
		{ CanCollide = false, NoShadow = true }
	)
end

-- Prisme de cristal dressé selon la normale (pointe vers l'extérieur).
local function eggCrystal(m, cf: CFrame, w: number, h: number, color: Color3, material, tilt: number?)
	part(
		m,
		"Crystal",
		Vector3.new(w, h, w),
		cf
			* CFrame.Angles(math.rad(-90 + (tilt or 0)), 0, 0)
			* CFrame.new(0, h * 0.3, 0)
			* CFrame.Angles(0, math.rad(45), 0),
		color,
		material,
		{ CanCollide = false, NoShadow = true }
	)
	part(
		m,
		"CrystalTip",
		Vector3.new(w * 0.62, w * 0.62, w * 0.62),
		cf
			* CFrame.Angles(math.rad(-90 + (tilt or 0)), 0, 0)
			* CFrame.new(0, h * 0.8, 0)
			* CFrame.Angles(math.rad(45), math.rad(45), 0),
		color:Lerp(Color3.new(1, 1, 1), 0.25),
		material,
		{ CanCollide = false, NoShadow = true }
	)
end

local eggDesigns = {}

-- Œuf des clairières (Commun) : coquille crème mouchetée, sillons gravés, plaques de grès à
-- la base, ambre en façade.
eggDesigns.Meadow = function(m, center, a, b)
	local rand = rng(101)
	eggBody(m, center, a, b, Color3.fromRGB(236, 222, 196))
	for _ = 1, 46 do
		local d = 0.1 + rand() * 0.14
		part(
			m,
			"Speckle",
			Vector3.new(0.04, d, d),
			eggPoint(center, a, b, 0.25 + rand() * 1.55, rand() * math.pi * 2, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(196, 112, 70),
			Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Cylinder, CanCollide = false, NoShadow = true }
		)
	end
	local groove = Color3.fromRGB(206, 186, 152)
	eggMeridian(m, center, a, b, function(th)
		return EGG_FRONT - 1.4 + th * 1.5
	end, 0.45, 1.75, 0.13, 0.05, groove, Enum.Material.SmoothPlastic, 12)
	eggMeridian(m, center, a, b, function(th)
		return EGG_FRONT + 0.9 + th * 1.1
	end, 0.6, 1.6, 0.12, 0.05, groove, Enum.Material.SmoothPlastic, 10)
	local stone = Color3.fromRGB(206, 178, 136)
	for row, spec in { { 2.15, 9, 0.95 }, { 2.55, 8, 0.85 }, { 2.9, 5, 0.75 } } do
		for k = 0, spec[2] - 1 do
			local phi = (k + (row % 2) * 0.5) / spec[2] * math.pi * 2
			local s = spec[3] * (0.85 + rand() * 0.3)
			part(
				m,
				"Plate",
				Vector3.new(s, s * 0.8, 0.28),
				eggPoint(center, a, b, spec[1], phi, 0.08) * CFrame.Angles(0, 0, (rand() - 0.5) * 0.6),
				stone:Lerp(Color3.fromRGB(180, 150, 110), rand() * 0.6),
				Enum.Material.Sandstone,
				{ CanCollide = false }
			)
		end
	end
	local amber = eggPoint(center, a, b, 2.05, EGG_FRONT, 0.2)
	part(
		m,
		"AmberSeat",
		Vector3.new(0.75, 0.75, 0.3),
		amber * CFrame.Angles(0, 0, math.rad(45)),
		stone,
		Enum.Material.Sandstone,
		{ CanCollide = false }
	)
	ball(
		m,
		"Amber",
		0.42,
		amber * CFrame.new(0, 0, -0.18),
		Color3.fromRGB(240, 150, 30),
		Enum.Material.Glass,
		{ CanCollide = false, NoShadow = true }
	)
end

-- Œuf sylvestre (Peu commun) : haut vert couvert de feuilles de chêne, bas en écorce, bande de
-- bois, émeraude, glands en façade, racines au dos.
eggDesigns.Sylvan = function(m, center, a, b)
	local rand = rng(202)
	eggBody(m, center, a, b, Color3.fromRGB(78, 120, 56))
	eggLower(m, center, a, b, 0.55, Color3.fromRGB(104, 70, 44), Enum.Material.Wood)
	for row, spec in { { 2.0, 10 }, { 2.4, 9 }, { 2.75, 6 } } do
		for k = 0, spec[2] - 1 do
			local phi = (k + (row % 2) * 0.5) / spec[2] * math.pi * 2
			part(
				m,
				"Bark",
				Vector3.new(0.66, 0.7, 0.1),
				eggPoint(center, a * 1.02, b, spec[1], phi, 0.02) * CFrame.Angles(0, 0, (rand() - 0.5) * 0.3),
				Color3.fromRGB(92, 62, 40):Lerp(Color3.fromRGB(130, 90, 58), rand()),
				Enum.Material.Wood,
				{ CanCollide = false }
			)
		end
	end
	for _ = 1, 10 do
		ball(
			m,
			"Moss",
			0.25 + rand() * 0.2,
			eggPoint(center, a * 1.02, b, 1.9 + rand() * 0.8, rand() * math.pi * 2, 0.05),
			Color3.fromRGB(110, 150, 60),
			Enum.Material.Grass,
			{ CanCollide = false, NoShadow = true }
		)
	end
	eggRing(m, center, a * 1.03, b, -0.15, 0.32, 0.2, Color3.fromRGB(150, 100, 58), Enum.Material.Wood, 22, 0.08, 4)
	-- Feuilles de chêne (ellipses aplaties) et nervure
	for k = 0, 6 do
		local phi = EGG_FRONT + (k - 3) * 0.75
		local cf = eggPoint(center, a, b, 0.75 + (k % 2) * 0.3, phi, 0.06) * CFrame.Angles(0, 0, (k - 3) * 0.25)
		local leaf = part(
			m,
			"OakLeaf",
			Vector3.new(0.6, 1.4, 0.1),
			cf,
			Color3.fromRGB(128, 178, 70):Lerp(Color3.fromRGB(150, 196, 84), rand()),
			Enum.Material.Grass,
			{ CanCollide = false }
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = leaf
		part(
			m,
			"LeafVein",
			Vector3.new(0.06, 1.1, 0.04),
			cf * CFrame.new(0, 0, -0.07),
			Color3.fromRGB(96, 140, 50),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false, NoShadow = true }
		)
	end
	eggGem(
		m,
		eggPoint(center, a * 1.03, b, thetaAt(b, -0.15), EGG_FRONT, 0.15),
		0.45,
		Color3.fromRGB(40, 200, 90),
		Color3.fromRGB(150, 100, 58)
	)
	-- Glands
	for k, off in { -0.25, 0.1 } do
		local cf = eggPoint(center, a * 1.02, b, 2.2 + k * 0.08, EGG_FRONT + 0.55 + off, 0.2)
		local nut = part(
			m,
			"Acorn",
			Vector3.new(0.34, 0.44, 0.34),
			cf * CFrame.new(0, -0.08, 0),
			Color3.fromRGB(176, 120, 50),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false, NoShadow = true }
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = nut
		ball(
			m,
			"AcornCap",
			0.32,
			cf * CFrame.new(0, 0.14, 0),
			Color3.fromRGB(110, 76, 44),
			Enum.Material.Wood,
			{ CanCollide = false, NoShadow = true }
		)
	end
	-- Racines au dos
	eggMeridian(m, center, a * 1.03, b, function(th)
		return -EGG_FRONT + math.sin(th * 5) * 0.25
	end, 1.2, 2.85, 0.22, 0.16, Color3.fromRGB(80, 52, 34), Enum.Material.Wood, 12)
end

-- Œuf du givre (Rare) : dégradé bleu, cristaux de glace en couronne, bandes d'argent ondulées,
-- saphir en façade, fermoirs au dos.
eggDesigns.Frost = function(m, center, a, b)
	local rand = rng(303)
	eggBody(m, center, a, b, Color3.fromRGB(150, 200, 248), Enum.Material.Ice)
	eggLower(m, center, a, b, 0.62, Color3.fromRGB(56, 86, 150), Enum.Material.Ice)
	local silver = Color3.fromRGB(205, 210, 222)
	eggRing(m, center, a, b, 0.25, 0.2, 0.13, silver, Enum.Material.Metal, 26, 0.14, 3)
	eggRing(m, center, a, b, -0.45, 0.2, 0.13, silver, Enum.Material.Metal, 26, 0.14, 3, 1.5)
	eggRing(m, center, a, b, -1.1, 0.2, 0.13, silver, Enum.Material.Metal, 22, 0.1, 3, 0.7)
	local ice = Color3.fromRGB(150, 215, 255)
	eggCrystal(m, eggPoint(center, a, b, 0.02, 0, 0), 0.42, 1.2, ice, Enum.Material.Glass)
	for k = 0, 8 do
		local phi = k / 9 * math.pi * 2
		eggCrystal(
			m,
			eggPoint(center, a, b, 0.45 + (k % 2) * 0.2, phi, 0),
			0.3 + rand() * 0.12,
			0.7 + rand() * 0.5,
			ice:Lerp(Color3.fromRGB(150, 200, 250), rand()),
			Enum.Material.Glass,
			10
		)
	end
	eggGem(
		m,
		eggPoint(center, a, b, 1.2, EGG_FRONT, 0.1),
		0.55,
		Color3.fromRGB(40, 80, 230),
		silver,
		Enum.Material.Glass
	)
	for _, y in { 0.25, -0.45, -1.1 } do
		part(
			m,
			"Clasp",
			Vector3.new(0.35, 0.35, 0.18),
			eggPoint(center, a, b, thetaAt(b, y), -EGG_FRONT, 0.12),
			silver,
			Enum.Material.Metal,
			{ CanCollide = false }
		)
	end
end

-- Œuf arcanique (Épique) : violet cerclé d'argent (méridiens + ceinture à méandres),
-- améthyste hexagonale, trois cristaux au sommet, runes au dos.
eggDesigns.Arcane = function(m, center, a, b)
	eggBody(m, center, a, b, Color3.fromRGB(116, 62, 176))
	local silver = Color3.fromRGB(172, 172, 184)
	for k = 0, 3 do
		local phi = EGG_FRONT + k * math.pi / 2
		eggMeridian(m, center, a, b, function()
			return phi
		end, 0.25, 2.9, 0.26, 0.14, silver, Enum.Material.Metal, 12)
	end
	eggRing(m, center, a, b, -0.15, 0.6, 0.18, silver, Enum.Material.Metal, 26)
	for k = 0, 17 do
		local phi = k / 18 * math.pi * 2
		part(
			m,
			"Meander",
			Vector3.new(0.18, 0.3, 0.1),
			eggPoint(center, a, b, thetaAt(b, -0.15), phi, 0.2) * CFrame.Angles(0, 0, math.rad(45)),
			Color3.fromRGB(120, 120, 132),
			Enum.Material.Metal,
			{ CanCollide = false, NoShadow = true }
		)
	end
	local gemCf = eggPoint(center, a, b, thetaAt(b, -0.15), EGG_FRONT, 0.28)
	part(
		m,
		"HexFrame",
		Vector3.new(0.18, 1.05, 1.05),
		gemCf * CFrame.Angles(0, math.rad(90), 0),
		silver,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false }
	)
	part(
		m,
		"Amethyst",
		Vector3.new(0.24, 0.75, 0.75),
		gemCf * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(176, 110, 255),
		Enum.Material.Neon,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false, NoShadow = true }
	)
	for k, phi in { EGG_FRONT, EGG_FRONT + 2.1, EGG_FRONT - 2.1 } do
		eggCrystal(
			m,
			eggPoint(center, a, b, if k == 1 then 0.02 else 0.35, phi, 0),
			0.3,
			if k == 1 then 0.9 else 0.65,
			Color3.fromRGB(190, 140, 255),
			Enum.Material.Neon,
			if k == 1 then 0 else 15
		)
	end
	for k = 0, 4 do
		part(
			m,
			"Rune",
			Vector3.new(0.3, 0.08, 0.05),
			eggPoint(center, a, b, 0.7 + k * 0.42, -EGG_FRONT, 0.02) * CFrame.Angles(0, 0, k * 0.9),
			Color3.fromRGB(220, 160, 255),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true }
		)
	end
end

-- Œuf draconique (Légendaire) : écailles rouges et noires sur un cœur incandescent, cornes,
-- ceinture d'or à tête de dragon et gemme de feu.
eggDesigns.Dragon = function(m, center, a, b)
	local rand = rng(404)
	eggBody(m, center, a * 0.97, b * 0.97, Color3.fromRGB(255, 110, 30), Enum.Material.Neon, "EggCore")
	local reds = { Color3.fromRGB(150, 40, 34), Color3.fromRGB(120, 32, 30), Color3.fromRGB(170, 56, 40) }
	local theta = 0.3
	local row = 0
	while theta < 2.95 do
		local count = math.max(4, math.floor(2 * math.pi * a * math.sin(theta) / 0.55 + 0.5))
		for k = 0, count - 1 do
			local phi = (k + (row % 2) * 0.5) / count * math.pi * 2
			local back = math.abs(((phi - -EGG_FRONT) + math.pi) % (2 * math.pi) - math.pi) < 0.35
			local color = if back and row % 2 == 0 then Color3.fromRGB(46, 38, 42) else reds[math.floor(rand() * 3) + 1]
			part(
				m,
				"Scale",
				Vector3.new(0.56, 0.56, 0.14),
				eggPoint(center, a, b, theta, phi, 0.02) * CFrame.Angles(0, 0, math.rad(45)),
				color,
				Enum.Material.Slate,
				{ CanCollide = false, NoShadow = true }
			)
		end
		theta += 0.27
		row += 1
	end
	-- Cornes recourbées
	for _, side in { -1, 1 } do
		local base = eggPoint(center, a, b, 0.6, EGG_FRONT + side * 1.1, 0)
		column(m, "HornRing", 0.25, 0.6, base * CFrame.Angles(math.rad(-90), 0, 0), GOLD, Enum.Material.Metal)
		local seg = base * CFrame.Angles(math.rad(-90), 0, 0)
		for k, w in { 0.42, 0.34, 0.26, 0.18 } do
			seg = seg * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, side * math.rad(18))
			part(
				m,
				"Horn" .. k,
				Vector3.new(w, 0.45, w),
				seg * CFrame.new(0, 0.1, 0),
				Color3.fromRGB(42, 34, 36),
				Enum.Material.SmoothPlastic,
				{ CanCollide = false }
			)
		end
	end
	eggRing(m, center, a * 1.02, b, -0.15, 0.32, 0.18, GOLD, Enum.Material.Metal, 24)
	-- Tête de dragon dorée et gemme de feu
	local head = eggPoint(center, a * 1.02, b, thetaAt(b, 0.25), EGG_FRONT, 0.25)
	part(m, "DragonHead", Vector3.new(0.6, 0.5, 0.35), head, GOLD, Enum.Material.Metal, { CanCollide = false })
	part(
		m,
		"DragonSnout",
		Vector3.new(0.34, 0.3, 0.3),
		head * CFrame.new(0, -0.22, -0.2),
		GOLD,
		Enum.Material.Metal,
		{ CanCollide = false }
	)
	for _, side in { -1, 1 } do
		part(
			m,
			"DragonHornlet",
			Vector3.new(0.1, 0.35, 0.1),
			head * CFrame.new(side * 0.25, 0.32, 0) * CFrame.Angles(0, 0, -side * 0.5),
			GOLD,
			Enum.Material.Metal,
			{ CanCollide = false, NoShadow = true }
		)
		ball(
			m,
			"DragonEye",
			0.1,
			head * CFrame.new(side * 0.15, 0.05, -0.18),
			Color3.fromRGB(255, 200, 60),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true }
		)
	end
	eggGem(m, eggPoint(center, a * 1.02, b, thetaAt(b, -0.5), EGG_FRONT, 0.2), 0.5, Color3.fromRGB(255, 130, 20), GOLD)
end

-- Œuf de l'éther (Mythique) : nacre violette et turquoise, filigranes d'or, étoile cyan,
-- constellations, croissant de lune au sommet.
eggDesigns.Ether = function(m, center, a, b)
	local rand = rng(505)
	eggBody(m, center, a, b, Color3.fromRGB(78, 54, 150))
	eggLowerShift(m, center, a, b, 0.9, Color3.fromRGB(36, 128, 126))
	for _ = 1, 14 do
		local patch = part(
			m,
			"Nacre",
			Vector3.new(0.9, 0.7, 0.08),
			eggPoint(center, a, b, 0.5 + rand() * 1.9, rand() * math.pi * 2, -0.01),
			Color3.fromRGB(130, 70, 200):Lerp(Color3.fromRGB(70, 110, 200), rand()),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false, NoShadow = true }
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = patch
	end
	-- Filigranes d'or : arcs en ogive de part et d'autre de la façade et du dos
	for _, center0 in { EGG_FRONT, -EGG_FRONT } do
		for _, side in { -1, 1 } do
			eggMeridian(m, center, a, b, function(th)
				return center0 + side * (0.25 + math.sin((th - 0.3) / 2.5 * math.pi) * 0.75)
			end, 0.3, 2.8, 0.15, 0.08, GOLD, Enum.Material.Metal, 24)
		end
	end
	eggRing(m, center, a, b, -1.15, 0.24, 0.14, GOLD, Enum.Material.Metal, 22, 0.12, 4)
	-- Étoile à quatre branches
	local star = eggPoint(center, a, b, thetaAt(b, -0.05), EGG_FRONT, 0.15)
	part(
		m,
		"StarBack",
		Vector3.new(0.8, 0.8, 0.1),
		star * CFrame.Angles(0, 0, math.rad(45)),
		GOLD,
		Enum.Material.Metal,
		{ CanCollide = false }
	)
	for _, sz in { Vector3.new(0.22, 1.5, 0.12), Vector3.new(1.5, 0.22, 0.12) } do
		part(
			m,
			"StarRay",
			sz,
			star * CFrame.new(0, 0, -0.08),
			Color3.fromRGB(90, 230, 255),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true }
		)
	end
	part(
		m,
		"StarHeart",
		Vector3.new(0.45, 0.45, 0.16),
		star * CFrame.new(0, 0, -0.12) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(200, 250, 255),
		Enum.Material.Neon,
		{ CanCollide = false, NoShadow = true }
	)
	-- Constellations (points lumineux reliés)
	for _, side in { -1, 1 } do
		local points = {}
		for k = 0, 3 do
			local cf =
				eggPoint(center, a, b, 0.9 + k * 0.28 + rand() * 0.1, EGG_FRONT + side * (1.1 + rand() * 0.5), 0.02)
			ball(
				m,
				"StarDot",
				0.12,
				cf,
				Color3.fromRGB(120, 230, 255),
				Enum.Material.Neon,
				{ CanCollide = false, NoShadow = true }
			)
			table.insert(points, cf.Position)
		end
		for k = 1, #points - 1 do
			local p0, p1 = points[k], points[k + 1]
			part(
				m,
				"StarLine",
				Vector3.new(0.03, 0.03, (p1 - p0).Magnitude),
				CFrame.lookAt((p0 + p1) / 2, p1),
				Color3.fromRGB(120, 230, 255),
				Enum.Material.Neon,
				{ CanCollide = false, NoShadow = true }
			)
		end
	end
	-- Croissant de lune au sommet
	local top = center * CFrame.new(0, b + 0.55, 0)
	column(m, "MoonStem", 0.4, 0.22, center * CFrame.new(0, b - 0.1, 0), GOLD, Enum.Material.Metal)
	for k = 0, 13 do
		local t = k / 13
		local ang = math.rad(110 + t * 270)
		local w = 0.1 + math.sin(t * math.pi) * 0.16 -- plus épais au milieu
		part(
			m,
			"Moon",
			Vector3.new(0.2 + (k % 2) * 0.08, w, 0.16 + (k % 2) * 0.1),
			top * CFrame.new(math.cos(ang) * 0.42, math.sin(ang) * 0.42, 0) * CFrame.Angles(0, 0, ang),
			GOLD,
			Enum.Material.Metal,
			{ CanCollide = false, NoShadow = true }
		)
	end
end

-- Œuf complet posé au-dessus de `base` (bas de l'œuf à baseY). Repli : œuf uni.
function Models.eggModel(design: string?, base: CFrame, baseY: number, parent: Instance, color: Color3)
	local a, b = 1.45, 1.9
	local center = base * CFrame.new(0, baseY + b, 0)
	local builder = design and eggDesigns[design]
	if builder then
		builder(parent, center, a, b)
	else
		eggBody(parent, center, a, b, color)
	end
end

function Models.eggStand(base: CFrame, color: Color3, royal: boolean?, design: string?): (Model, BasePart)
	local m = newModel("EggStand")
	local plinth
	if royal then
		-- Présentoir royal : socle de marbre à degrés, colonnettes dorées, couronne flottante.
		plinth = column(m, "Plinth", 0.6, 6.4, base, MARBLE_SHADE, Enum.Material.Marble)
		column(m, "Plinth2", 0.6, 5.2, base * CFrame.new(0, 0.6, 0), MARBLE, Enum.Material.Marble)
		column(
			m,
			"PlinthTrim",
			0.12,
			5.3,
			base * CFrame.new(0, 1.15, 0),
			GOLD,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
		for k = 0, 3 do
			local a = math.rad(k * 90 + 45)
			local post = base * CFrame.new(math.cos(a) * 2.7, 0.6, math.sin(a) * 2.7)
			column(m, "RoyalPost", 3.2, 0.35, post, GOLD, Enum.Material.Metal)
			ball(m, "RoyalOrb", 0.6, post * CFrame.new(0, 3.4, 0), color, Enum.Material.Neon, { NoShadow = true })
		end
	else
		plinth = column(m, "Plinth", 1.2, 5, base, C.StoneDark, Enum.Material.Cobblestone)
		column(
			m,
			"PlinthTrim",
			0.15,
			5.2,
			base * CFrame.new(0, 0.9, 0),
			Color3.fromRGB(184, 178, 166),
			Enum.Material.Slate,
			{ NoShadow = true }
		)
		for k = 0, 7 do
			local a = math.rad(k * 45)
			part(
				m,
				"PlinthStone",
				Vector3.new(1.1, 0.6, 0.25),
				base * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0.45, 2.5),
				C.StoneDark:Lerp(C.Stone, (k % 3) * 0.25),
				Enum.Material.Cobblestone,
				{ CanCollide = false, NoShadow = true }
			)
		end
	end
	column(m, "Cushion", 0.4, 3.6, base * CFrame.new(0, 1.2, 0), GOLD, Enum.Material.Metal)
	Models.eggModel(design, base, 1.55, m, color)
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
			-- Profondeur alternée : les recouvrements entre claveaux ne scintillent pas.
			part(
				parent,
				"Voussoir" .. k,
				Vector3.new(length, thickness, depth + (k % 2) * 0.14),
				cf,
				color,
				material,
				props
			)
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
		Vector3.new(11.16, 0.12, 4.56),
		base * CFrame.new(0, 1.05, 0),
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
	arch(m, archCenter, half + 0.95, 0.3, 2.45, 21, MARBLE_SHADE, Enum.Material.Marble)
	arch(
		m,
		archCenter * CFrame.new(0, 0, -1.13),
		half - 0.9,
		0.18,
		0.12,
		15,
		GOLD,
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	arch(
		m,
		archCenter * CFrame.new(0, 0, 1.13),
		half - 0.9,
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

-- Arène des Cristaux (design du créateur, maquette 3D « Arène des Cristaux ») ------------------
-- Reconstruite à l'échelle ARENA_SCALE (1 unité de la maquette = 6 studs) : sol en damier sable et
-- ardoise, murs crénelés coiffés de sable et couverts de mousse, tours d'angle, deux portes à
-- bannières et boucliers dorés, six braseros allumés, quatre amas de cristaux, quatre piliers à
-- cristal flottant, cercle runique central, épée plantée dans le rocher, tonneaux et caisses.
-- `center` : centre au sol ; le sol de combat est à y = ARENA_FLOOR. Les portes sont à ±Z.

local ARENA_SCALE = 6
local ARENA_FLOOR = 1.2
Models.CrystalArenaHalf = Vector2.new(6.5 * ARENA_SCALE, 9.5 * ARENA_SCALE) -- murs (demi-largeurs)

local function hex(v: number): Color3
	return Color3.fromRGB(bit32.rshift(v, 16) % 256, bit32.rshift(v, 8) % 256, v % 256)
end

function Models.crystalArena(center: CFrame, parent: Instance)
	local S, FY = ARENA_SCALE, ARENA_FLOOR
	local rand = rng(20261105)
	local function R(a: number, b: number): number
		return a + (b - a) * rand()
	end
	-- Position (unités de la maquette, y depuis le sol de combat) -> repère du monde
	local function at(x: number, y: number, z: number): CFrame
		return center * CFrame.new(x * S, FY + y * S, z * S)
	end
	local function blk(name, w, h, d, cf, color, material, props)
		return part(parent, name, Vector3.new(w * S, h * S, d * S), cf, color, material, props)
	end

	local slate = { hex(0x66728c), hex(0x5d6882), hex(0x717e98) }
	local sand, sandDeep = hex(0xe2c68b), hex(0xd2b273)
	local moss, mossLight = hex(0x5f9a34), hex(0x82bb45)
	local gateStone, gateStoneDark = hex(0xa1a8b8), hex(0x878ea1)
	local gold, banner, iron = hex(0xf0b52e), hex(0xa02a42), hex(0x2e3039)
	local wood, woodDark = hex(0x94602f), hex(0x5f3b1e)
	local rock, rockDark = hex(0x8e94a3), hex(0x737a8a)
	local crystal, crystalPale = hex(0x67f2e2), hex(0xb8fff6)
	local rune = hex(0x3fe8d4)

	-- Sol : socle d'ardoise, damier de dalles de sable (une case sur deux)
	local FW, FL = 16, 22
	part(
		parent,
		"ArenaBase",
		Vector3.new(FW * S + 2.4, FY, FL * S + 2.4),
		center * CFrame.new(0, FY / 2, 0),
		hex(0xa0a8b6),
		Enum.Material.Slate
	)
	part(
		parent,
		"ArenaSkirt",
		Vector3.new(FW * S + 5.4, 0.6, FL * S + 5.4),
		center * CFrame.new(0, 0.3, 0),
		hex(0x3e4658),
		Enum.Material.Slate
	)
	for i = 0, FW - 1 do
		for j = 0, FL - 1 do
			if (i + j) % 2 == 0 then
				local v = math.floor((rand() - 0.5) * 8)
				part(
					parent,
					"ArenaTile",
					Vector3.new(S, 0.1, S),
					center * CFrame.new((i - FW / 2 + 0.5) * S, FY + 0.05, (j - FL / 2 + 0.5) * S),
					Color3.fromRGB(216 + v, 192 + v, 143 + v),
					Enum.Material.Sandstone,
					{ CanCollide = false, NoShadow = true }
				)
			end
		end
	end

	-- Murs : segments alternés haut/bas, chaperons de sable, mousse sur les faces
	local H, T = 2.7, 1.0
	local function wallRun(ax: number, az: number, bx: number, bz: number)
		local alongX = az == bz
		local len = if alongX then math.abs(bx - ax) else math.abs(bz - az)
		local n = math.max(1, math.floor(len / 0.9 + 0.5))
		local seg = len / n
		local fixed = if alongX then az else ax
		local inner = -math.sign(fixed)
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			local cx = if alongX then ax + (bx - ax) * t else ax
			local cz = if alongX then az else az + (bz - az) * t
			local tall = i % 2 == 0
			local h = H + (if tall then 0.38 else 0) + R(-0.12, 0.12)
			local jit = R(-0.05, 0.05)
			local px = if alongX then cx else cx + jit
			local pz = if alongX then cz + jit else cz
			local w = seg * 0.985
			blk(
				"Wall",
				if alongX then w else T,
				h,
				if alongX then T else w,
				at(px, h / 2, pz),
				slate[1 + math.floor(rand() * 3)],
				Enum.Material.Slate
			)
			local capH = if tall then 0.44 else 0.3
			local cw = if tall then seg * 1.04 else seg * 0.92
			local cd = T + (if tall then 0.24 else 0.1)
			blk(
				"WallCap",
				if alongX then cw else cd,
				capH,
				if alongX then cd else cw,
				at(px, h + capH / 2 - 0.04, pz),
				if tall then sand else sandDeep,
				Enum.Material.Sandstone
			)
			for _, side in { inner, -inner } do
				if rand() < 0.45 then
					local mw, mh, off = seg * R(0.35, 0.95), R(0.25, 1.15), T / 2 + 0.035
					local mx = if alongX then px + R(-0.15, 0.15) else px + side * off
					local mz = if alongX then pz + side * off else pz + R(-0.15, 0.15)
					blk(
						"Moss",
						if alongX then mw else 0.07,
						mh,
						if alongX then 0.07 else mw,
						at(mx, h - mh / 2 + 0.02, mz),
						if rand() < 0.5 then moss else mossLight,
						Enum.Material.Grass,
						{ NoShadow = true }
					)
				end
			end
		end
	end
	wallRun(-6.5, -9, -6.5, 9)
	wallRun(6.5, -9, 6.5, 9)
	wallRun(-6, -9.5, -2.2, -9.5)
	wallRun(2.2, -9.5, 6, -9.5)
	wallRun(-6, 9.5, -2.2, 9.5)
	wallRun(2.2, 9.5, 6, 9.5)

	-- Tours d'angle
	for _, p in { { -6.5, -9.5 }, { 6.5, -9.5 }, { -6.5, 9.5 }, { 6.5, 9.5 } } do
		local h = H + 0.75
		local sx, sz = math.sign(p[1]), math.sign(p[2])
		blk("Tower", 1.4, h, 1.4, at(p[1], h / 2, p[2]), slate[3], Enum.Material.Slate)
		blk("TowerCap", 1.65, 0.5, 1.65, at(p[1], h + 0.21, p[2]), sand, Enum.Material.Sandstone)
		blk("TowerTop", 0.9, 0.35, 0.9, at(p[1] + 0.15, h + 0.6, p[2] - 0.1), sandDeep, Enum.Material.Sandstone)
		blk("Moss", 1.0, 0.8, 0.07, at(p[1], h - 0.35, p[2] + sz * 0.74), moss, Enum.Material.Grass)
		blk("Moss", 0.07, 0.6, 0.8, at(p[1] + sx * 0.74, h - 0.28, p[2]), mossLight, Enum.Material.Grass)
	end

	-- Bannière rouge à barres et losange dorés (face vers -Z du repère `cf`)
	local function makeBanner(cf: CFrame, w: number, h: number)
		blk("Banner", w, h, 0.06, cf, banner, Enum.Material.Fabric, { CanCollide = false })
		blk("BannerRod", w + 0.14, 0.11, 0.11, cf * CFrame.new(0, h / 2 * S, 0.02 * S), gold, Enum.Material.Metal)
		blk("BannerHem", w + 0.04, 0.07, 0.08, cf * CFrame.new(0, -h / 2 * S, 0), gold, Enum.Material.Metal)
		blk(
			"BannerEmblem",
			0.2,
			0.28,
			0.02,
			cf * CFrame.new(0, 0.05 * S, -0.04 * S) * CFrame.Angles(0, 0, math.rad(45)),
			gold,
			Enum.Material.Metal,
			{ CanCollide = false, NoShadow = true }
		)
	end

	-- Portes : piliers, linteau à corniches, bannières et boucliers dorés
	local function gate(z: number)
		for _, x in { -1.65, 1.65 } do
			blk("GatePillar", 1.1, 3.9, 1.3, at(x, 1.95, z), gateStone, Enum.Material.Slate)
			blk("GatePlinth", 1.3, 0.24, 1.5, at(x, 0.12, z), gateStoneDark, Enum.Material.Slate)
			blk("GateBand", 1.2, 0.12, 1.4, at(x, 3.35, z), gold, Enum.Material.Metal)
			for _, f in { 1, -1 } do
				makeBanner(at(x, 1.95, z + f * 0.68) * CFrame.Angles(0, if f > 0 then math.pi else 0, 0), 0.72, 1.75)
			end
		end
		blk("GateLintel", 4.5, 0.7, 1.36, at(0, 4.2, z), gateStone, Enum.Material.Slate)
		blk("GateCornice", 4.6, 0.14, 1.46, at(0, 3.82, z), gateStoneDark, Enum.Material.Slate)
		blk("GateCornice", 4.7, 0.14, 1.5, at(0, 4.6, z), gateStoneDark, Enum.Material.Slate)
		for _, f in { 1, -1 } do
			local face = at(0, 4.2, z + f * 0.7)
			blk("Shield", 0.72, 0.36, 0.1, face * CFrame.new(0, 0.12 * S, 0), gold, Enum.Material.Metal)
			blk(
				"ShieldPoint",
				0.48,
				0.48,
				0.1,
				face * CFrame.new(0, -0.08 * S, 0) * CFrame.Angles(0, 0, math.rad(45)),
				gold,
				Enum.Material.Metal
			)
		end
	end
	gate(-9.5)
	gate(9.5)
	for _, z in { -2.6, 2.6 } do
		for _, s in { -1, 1 } do
			makeBanner(at(s * 5.97, 1.75, z) * CFrame.Angles(0, s * math.pi / 2, 0), 0.8, 1.9)
		end
	end

	-- Braseros allumés (feu et lumière intégrés de Roblox)
	for _, z in { -5.4, 0, 4.6 } do
		for _, x in { -5.2, 5.2 } do
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					blk(
						"BrazierLeg",
						0.09,
						0.78,
						0.09,
						at(x + sx * 0.26, 0.38, z + sz * 0.26) * CFrame.Angles(-sz * 0.12, 0, sx * 0.12),
						iron,
						Enum.Material.Metal
					)
				end
			end
			blk("BrazierBase", 0.66, 0.1, 0.66, at(x, 0.72, z), iron, Enum.Material.Metal)
			blk("BrazierSide", 0.8, 0.26, 0.09, at(x, 0.88, z + 0.36), iron, Enum.Material.Metal)
			blk("BrazierSide", 0.8, 0.26, 0.09, at(x, 0.88, z - 0.36), iron, Enum.Material.Metal)
			blk("BrazierSide", 0.09, 0.26, 0.64, at(x + 0.36, 0.88, z), iron, Enum.Material.Metal)
			blk("BrazierSide", 0.09, 0.26, 0.64, at(x - 0.36, 0.88, z), iron, Enum.Material.Metal)
			local ember =
				blk("Embers", 0.6, 0.1, 0.6, at(x, 0.86, z), hex(0xff6a1a), Enum.Material.Neon, { NoShadow = true })
			local flame = blk(
				"Flame",
				0.32,
				0.55,
				0.32,
				at(x, 1.2, z) * CFrame.Angles(0, math.rad(45), 0),
				hex(0xffb02e),
				Enum.Material.Neon,
				{ CanCollide = false, NoShadow = true, Transparency = 0.15 }
			)
			local fire = Instance.new("Fire")
			fire.Size = 7
			fire.Heat = 9
			fire.Color = hex(0xff8a1e)
			fire.SecondaryColor = hex(0xffe066)
			fire.Parent = ember
			local light = Instance.new("PointLight")
			light.Color = hex(0xffa040)
			light.Range = 24
			light.Brightness = 1.6
			light.Shadows = false
			light.Parent = flame
		end
	end

	-- Cristal : fût hexagonal approché (bloc tourné) et pointe en losange
	local function shard(base: CFrame, h: number, r: number, color: Color3)
		blk(
			"Crystal",
			r * 1.8,
			h,
			r * 1.8,
			base * CFrame.new(0, h / 2 * S, 0) * CFrame.Angles(0, math.rad(30), 0),
			color,
			Enum.Material.Neon,
			{
				NoShadow = true,
				Transparency = 0.1,
			}
		)
		blk(
			"CrystalTip",
			r * 1.3,
			r * 1.3,
			r * 1.3,
			base * CFrame.new(0, h * S, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			color,
			Enum.Material.Neon,
			{ NoShadow = true, Transparency = 0.1, CanCollide = false }
		)
	end
	local function crystalCluster(x: number, z: number, s: number)
		local base = at(x, 0, z)
		local function k(v: number): number
			return v * s
		end
		blk(
			"Rock",
			k(1.9),
			k(0.6),
			k(1.6),
			base * CFrame.new(0, k(0.25) * S, 0) * CFrame.Angles(0.2, 0.5, 0.1),
			rock,
			Enum.Material.Rock
		)
		blk(
			"Rock",
			k(0.8),
			k(0.7),
			k(0.8),
			base * CFrame.new(k(0.7) * S, k(0.15) * S, k(0.35) * S) * CFrame.Angles(0.6, 0.3, 0.5),
			rockDark,
			Enum.Material.Rock
		)
		blk(
			"Rock",
			k(0.7),
			k(0.6),
			k(0.7),
			base * CFrame.new(k(-0.75) * S, k(0.12) * S, k(-0.2) * S) * CFrame.Angles(0.4, 1.1, 0.7),
			rock,
			Enum.Material.Rock
		)
		for _, sp in
			{
				{ 0, 0, 1.3, 0.26, 0, 0, crystal },
				{ 0.35, 0.1, 0.95, 0.2, -0.45, 0.2, crystal },
				{ -0.38, 0.05, 0.9, 0.2, 0.5, -0.1, crystalPale },
				{ 0.1, -0.35, 0.75, 0.17, 0.15, 0.5, crystal },
				{ -0.1, 0.4, 0.65, 0.15, -0.1, -0.5, crystalPale },
			}
		do
			shard(
				base * CFrame.new(k(sp[1]) * S, k(0.35) * S, k(sp[2]) * S) * CFrame.Angles(sp[6], 0, sp[5]),
				k(sp[3]),
				k(sp[4]),
				sp[7]
			)
		end
		local glow = Instance.new("PointLight")
		glow.Color = crystal
		glow.Range = 18
		glow.Brightness = 1.2
		glow.Shadows = false
		glow.Parent =
			part(parent, "CrystalGlow", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 1.2 * S, 0), crystal, nil, {
				Transparency = 1,
				CanCollide = false,
			})
	end
	crystalCluster(-4.3, -8.35, 1.0)
	crystalCluster(4.75, -8.3, 1.0)
	crystalCluster(-5.0, 8.25, 1.25)
	crystalCluster(5.0, 8.25, 1.25)

	-- Piliers à cristal flottant
	for _, p in { { -2.8, -4 }, { 2.8, -4 }, { -2.8, 4 }, { 2.8, 4 } } do
		blk("PedestalFoot", 0.8, 0.2, 0.8, at(p[1], 0.1, p[2]), gateStoneDark, Enum.Material.Slate)
		blk("PedestalBody", 0.56, 0.48, 0.56, at(p[1], 0.44, p[2]), gateStone, Enum.Material.Slate)
		blk("PedestalCap", 0.7, 0.1, 0.7, at(p[1], 0.73, p[2]), gateStoneDark, Enum.Material.Slate)
		blk(
			"FloatingCrystal",
			0.26,
			0.5,
			0.26,
			at(p[1], 1.15, p[2]) * CFrame.Angles(0, math.rad(45), 0),
			crystalPale,
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true }
		)
	end

	-- Cercle runique central : deux anneaux, quatre losanges, carré central
	local function ring(r1: number, r2: number, n: number)
		local r = (r1 + r2) / 2
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			blk(
				"Rune",
				(r2 - r1),
				0.012,
				2 * math.pi * r / n * 1.06,
				at(math.cos(a) * r, 0.03, math.sin(a) * r) * CFrame.Angles(0, -a, 0),
				rune,
				Enum.Material.Neon,
				{ CanCollide = false, NoShadow = true, Transparency = 0.15 }
			)
		end
	end
	ring(3.05, 3.24, 48)
	ring(1.95, 2.1, 36)
	for _, p in { { 3.15, 0 }, { -3.15, 0 }, { 0, 3.15 }, { 0, -3.15 } } do
		blk(
			"RuneDiamond",
			0.62,
			0.012,
			0.62,
			at(p[1], 0.035, p[2]) * CFrame.Angles(0, math.rad(45), 0),
			rune,
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true, Transparency = 0.1 }
		)
	end
	for k = 0, 3 do
		blk(
			"RuneSquare",
			0.7,
			0.012,
			0.16,
			at(0, 0.03, 0) * CFrame.Angles(0, k * math.pi / 2 + math.rad(45), 0) * CFrame.new(0, 0, 0.43 * S),
			rune,
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true, Transparency = 0.15 }
		)
	end
	local runeLight = part(parent, "RuneLight", Vector3.new(0.2, 0.2, 0.2), at(0, 1.2, 0), rune, nil, {
		Transparency = 1,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = hex(0x50f0dc)
	light.Range = 40
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = runeLight

	-- Épée plantée dans le rocher (près de la porte -Z)
	local sb = at(2.85, 0, -8.15)
	blk(
		"SwordRock",
		1.8,
		1.0,
		1.5,
		sb * CFrame.new(0, 0.3 * S, 0) * CFrame.Angles(0.15, 0.4, 0.1),
		rock,
		Enum.Material.Rock
	)
	blk(
		"SwordRock",
		0.85,
		0.8,
		0.85,
		sb * CFrame.new(0.8 * S, 0.2 * S, 0.3 * S) * CFrame.Angles(0.5, 0.2, 0.6),
		rockDark,
		Enum.Material.Rock
	)
	blk(
		"SwordRock",
		0.75,
		0.7,
		0.75,
		sb * CFrame.new(-0.7 * S, 0.18 * S, 0.35 * S) * CFrame.Angles(0.3, 1.0, 0.4),
		rock,
		Enum.Material.Rock
	)
	local sw = sb * CFrame.new(0, 0.6 * S, 0) * CFrame.Angles(0.08, 0, -0.32)
	local steel = hex(0xdfe3ec)
	blk("Blade", 0.44, 3.4, 0.1, sw * CFrame.new(0, 1.7 * S, 0), steel, Enum.Material.Metal)
	blk("BladeEdge", 0.1, 3.0, 0.14, sw * CFrame.new(0, 1.75 * S, 0), hex(0xb9bfcc), Enum.Material.Metal)
	blk("Crossguard", 1.55, 0.24, 0.3, sw * CFrame.new(0, 3.5 * S, 0), gold, Enum.Material.Metal)
	blk("GuardEnd", 0.24, 0.36, 0.34, sw * CFrame.new(-0.78 * S, 3.56 * S, 0), gold, Enum.Material.Metal)
	blk("GuardEnd", 0.24, 0.36, 0.34, sw * CFrame.new(0.78 * S, 3.56 * S, 0), gold, Enum.Material.Metal)
	blk(
		"GuardGem",
		0.2,
		0.2,
		0.2,
		sw * CFrame.new(0, 3.5 * S, -0.17 * S) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		crystal,
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	part(
		parent,
		"Grip",
		Vector3.new(0.8 * S, 0.21 * S, 0.21 * S),
		sw * CFrame.new(0, 4.02 * S, 0) * VERTICAL,
		woodDark,
		Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder }
	)
	blk(
		"Pommel",
		0.28,
		0.28,
		0.28,
		sw * CFrame.new(0, 4.55 * S, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		gold,
		Enum.Material.Metal
	)

	-- Tonneaux et caisses dans les angles
	local function barrel(x: number, z: number)
		local b = at(x, 0, z)
		column(parent, "Barrel", 0.76 * S, 0.62 * S, b, wood, Enum.Material.WoodPlanks)
		column(parent, "BarrelBelly", 0.4 * S, 0.7 * S, b * CFrame.new(0, 0.18 * S, 0), wood, Enum.Material.WoodPlanks)
		for _, y in { 0.15, 0.57 } do
			column(parent, "BarrelBand", 0.06 * S, 0.72 * S, b * CFrame.new(0, y * S, 0), iron, Enum.Material.Metal, {
				NoShadow = true,
			})
		end
		column(parent, "BarrelLid", 0.02 * S, 0.56 * S, b * CFrame.new(0, 0.76 * S, 0), woodDark, Enum.Material.Wood, {
			NoShadow = true,
		})
	end
	local function crate(x: number, z: number, s: number, ry: number)
		local c = at(x, 0, z) * CFrame.Angles(0, ry, 0)
		blk("ArenaCrate", s, s, s, c * CFrame.new(0, s / 2 * S, 0), hex(0xa06a38), Enum.Material.WoodPlanks)
		for _, y in { 0.06, s - 0.06 } do
			blk(
				"ArenaCrateBand",
				s + 0.03,
				0.1,
				s + 0.03,
				c * CFrame.new(0, y * S, 0),
				hex(0x5e3719),
				Enum.Material.Wood,
				{
					NoShadow = true,
				}
			)
		end
	end
	barrel(-5.45, -7.05)
	barrel(-4.75, -7.3)
	crate(-5.35, -6.35, 0.7, 0.1)
	crate(5.35, -7.0, 0.72, -0.08)
	barrel(5.4, -6.25)
	barrel(-5.4, 6.35)
	barrel(-5.4, 5.65)
	crate(-4.65, 6.3, 0.75, 0.12)
	crate(5.3, 6.4, 0.75, -0.1)
	barrel(4.55, 6.45)
	barrel(5.4, 5.6)
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
-- Ennemis de la Rue des boss (planches du créateur) -----------------------------------------
-- Constructeurs : bipède paramétrique (gobelin, squelette, cultiste, orque, golem, chevalier,
-- roi, gardien, titan, colosse), quadrupède (loup, hydre, dragon), gelée, araignée. `base` au
-- sol, -Z = face. Toutes les pièces sont soudées à la pièce « Root » (un seul bloc déplacé).

local function ep(parent, name: string, size: Vector3, cf: CFrame, color: Color3, material, props)
	local p = table.clone(props or {})
	p.CanCollide = false
	return part(parent, name, size, cf, color, material, p)
end

local function blob(parent, name: string, size: Vector3, cf: CFrame, color: Color3, material, props)
	local p = ep(parent, name, size, cf, color, material, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function glow(parent, name: string, size: Vector3, cf: CFrame, color: Color3, shape)
	return ep(parent, name, size, cf, color, Enum.Material.Neon, { NoShadow = true, Shape = shape })
end

local IRON = Color3.fromRGB(110, 106, 104)
local RUST = Color3.fromRGB(150, 95, 60)
local LEATHER = Color3.fromRGB(105, 70, 45)
local ROPE = Color3.fromRGB(200, 165, 105)

-- Armes -------------------------------------------------------------------------------------

local function weaponSword(m, hand: CFrame, len: number, blade: Color3, guard: Color3, glowColor: Color3?)
	local w = len * 0.13
	ep(m, "Grip", Vector3.new(w * 0.5, len * 0.2, w * 0.5), hand, LEATHER, Enum.Material.Fabric)
	ep(
		m,
		"Guard",
		Vector3.new(w * 2.2, w * 0.4, w * 0.6),
		hand * CFrame.new(0, -len * 0.11, 0),
		guard,
		Enum.Material.Metal
	)
	local b = hand * CFrame.new(0, -len * 0.11 - len * 0.4, 0)
	ep(m, "Blade", Vector3.new(w, len * 0.8, w * 0.25), b, blade, Enum.Material.Metal)
	ep(
		m,
		"BladeTip",
		Vector3.new(w * 0.71, w * 0.71, w * 0.25),
		b * CFrame.new(0, -len * 0.4, 0) * CFrame.Angles(0, 0, math.rad(45)),
		blade,
		Enum.Material.Metal
	)
	if glowColor then
		glow(m, "BladeRune", Vector3.new(w * 0.2, len * 0.6, w * 0.3), b, glowColor)
	end
end

local function weaponCleaver(m, hand: CFrame, size: number)
	ep(m, "Grip", Vector3.new(size * 0.12, size * 0.35, size * 0.12), hand, LEATHER, Enum.Material.Wood)
	local b = hand * CFrame.new(size * 0.15, -size * 0.55, 0)
	ep(
		m,
		"Cleaver",
		Vector3.new(size * 0.5, size * 0.75, size * 0.06),
		b,
		IRON:Lerp(RUST, 0.45),
		Enum.Material.CorrodedMetal
	)
	for k = 0, 2 do
		ep(
			m,
			"Notch",
			Vector3.new(size * 0.08, size * 0.08, size * 0.07),
			b * CFrame.new(size * 0.25, size * (0.25 - k * 0.25), 0),
			Color3.fromRGB(70, 60, 55),
			Enum.Material.Metal
		)
	end
end

local function weaponHammer(m, hand: CFrame, size: number, head: Color3, rune: Color3?)
	ep(
		m,
		"Haft",
		Vector3.new(size * 0.12, size * 1.0, size * 0.12),
		hand * CFrame.new(0, -size * 0.3, 0),
		Color3.fromRGB(130, 55, 45),
		Enum.Material.Wood
	)
	local h = hand * CFrame.new(0, -size * 0.85, 0)
	ep(m, "HammerHead", Vector3.new(size * 0.55, size * 0.4, size * 0.4), h, head, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		ep(
			m,
			"HammerBand",
			Vector3.new(size * 0.06, size * 0.44, size * 0.44),
			h * CFrame.new(side * size * 0.2, 0, 0),
			RUST,
			Enum.Material.Metal
		)
	end
	if rune then
		glow(
			m,
			"HammerRune",
			Vector3.new(size * 0.2, size * 0.2, 0.05),
			h * CFrame.new(0, 0, -size * 0.21) * CFrame.Angles(0, 0, math.rad(45)),
			rune
		)
	end
end

local function weaponMace(m, hand: CFrame, size: number)
	ep(
		m,
		"Haft",
		Vector3.new(size * 0.12, size * 0.9, size * 0.12),
		hand * CFrame.new(0, -size * 0.25, 0),
		LEATHER,
		Enum.Material.Wood
	)
	local h = hand * CFrame.new(0, -size * 0.85, 0)
	ep(
		m,
		"MaceHead",
		Vector3.new(size * 0.5, size * 0.5, size * 0.5),
		h,
		Color3.fromRGB(70, 60, 55),
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Ball }
	)
	for k = 0, 9 do
		local a = k * 2.4
		ep(
			m,
			"Spike",
			Vector3.new(size * 0.1, size * 0.22, size * 0.1),
			h * CFrame.Angles(a, k * 1.3, 0) * CFrame.new(0, size * 0.28, 0),
			Color3.fromRGB(190, 160, 90),
			Enum.Material.Metal
		)
	end
end

local function weaponStaff(m, hand: CFrame, len: number, crystal: Color3)
	ep(
		m,
		"Staff",
		Vector3.new(len * 0.05, len, len * 0.05),
		hand * CFrame.new(0, len * 0.25, 0),
		C.WoodDark,
		Enum.Material.Wood
	)
	local top = hand * CFrame.new(0, len * 0.78, 0)
	for k = 0, 3 do
		ep(
			m,
			"Claw",
			Vector3.new(len * 0.03, len * 0.12, len * 0.03),
			top * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -len * 0.05) * CFrame.Angles(-0.4, 0, 0),
			C.WoodDark,
			Enum.Material.Wood
		)
	end
	local gem = glow(
		m,
		"Ember",
		Vector3.new(len * 0.08, len * 0.13, len * 0.08),
		top * CFrame.new(0, len * 0.04, 0) * CFrame.Angles(0, math.rad(45), 0),
		crystal
	)
	local light = Instance.new("PointLight")
	light.Color = crystal
	light.Range = 10
	light.Parent = gem
end

local function plankShield(m, arm: CFrame, w: number, h: number, wood: Color3, emblem: Color3?)
	local s = arm * CFrame.new(0, 0, -w * 0.15)
	for k = -1, 1 do
		ep(
			m,
			"ShieldPlank",
			Vector3.new(w / 3 * 0.95, h, w * 0.08),
			s * CFrame.new(k * w / 3, 0, 0),
			wood:Lerp(Color3.new(0, 0, 0), (k + 1) * 0.06),
			Enum.Material.WoodPlanks
		)
	end
	for _, y in { -0.33, 0.33 } do
		ep(
			m,
			"ShieldBand",
			Vector3.new(w * 1.04, h * 0.08, w * 0.1),
			s * CFrame.new(0, y * h, -0.02),
			IRON,
			Enum.Material.Metal
		)
	end
	if emblem then
		ep(
			m,
			"ShieldEmblem",
			Vector3.new(w * 0.32, w * 0.32, w * 0.1),
			s * CFrame.new(0, 0, -w * 0.05) * CFrame.Angles(0, 0, math.rad(45)),
			emblem,
			Enum.Material.SmoothPlastic
		)
	end
end

-- Bipède -------------------------------------------------------------------------------------
-- spec : H (hauteur), Bulk, Head (proportion), Skin, Torso, Pants, Boots, Hands. Retourne les
-- repères utiles : mains, tête, poitrine, dos, épaules.
local function biped(m, base: CFrame, s)
	local H, b = s.H, s.Bulk or 1
	local headS = H * (s.Head or 0.2)
	local legH = (H - headS) * 0.48
	local torsoH = (H - headS) * 0.48
	local torsoW, torsoD = H * 0.3 * b, H * 0.18 * b
	local hipW = torsoW * 0.62
	local legW = H * 0.11 * b
	for _, side in { -1, 1 } do
		ep(
			m,
			"Leg",
			Vector3.new(legW, legH, legW * 1.1),
			base * CFrame.new(side * hipW / 2, legH / 2, 0),
			s.Pants,
			s.PantsMat or Enum.Material.Fabric
		)
		ep(
			m,
			"Boot",
			Vector3.new(legW * 1.3, legH * 0.32, legW * 1.6),
			base * CFrame.new(side * hipW / 2, legH * 0.16, -legW * 0.2),
			s.Boots,
			s.BootsMat or Enum.Material.Fabric
		)
		if s.Knee then
			ep(
				m,
				"Knee",
				Vector3.new(legW * 1.2, legW * 0.9, legW * 0.4),
				base * CFrame.new(side * hipW / 2, legH * 0.55, -legW * 0.6),
				s.Knee,
				Enum.Material.Metal
			)
		end
	end
	local chestY = legH + torsoH / 2
	ep(
		m,
		"Torso",
		Vector3.new(torsoW, torsoH, torsoD),
		base * CFrame.new(0, chestY, 0),
		s.Torso,
		s.TorsoMat or Enum.Material.Fabric
	)
	ep(
		m,
		"Belt",
		Vector3.new(torsoW * 1.04, torsoH * 0.12, torsoD * 1.06),
		base * CFrame.new(0, legH + torsoH * 0.12, 0),
		s.Belt or LEATHER,
		Enum.Material.Fabric
	)
	local armW = H * 0.11 * b
	local armL = torsoH * 1.05
	local hands = {}
	for _, side in { -1, 1 } do
		local shoulder = base * CFrame.new(side * (torsoW / 2 + armW * 0.45), legH + torsoH - armW * 0.4, 0)
		local arm = shoulder * CFrame.Angles(0, 0, side * 0.12)
		ep(
			m,
			"Arm",
			Vector3.new(armW, armL, armW),
			arm * CFrame.new(0, -armL / 2, 0),
			s.Arms or s.Skin,
			s.ArmsMat or Enum.Material.SmoothPlastic
		)
		local hand = arm * CFrame.new(0, -armL - armW * 0.1, 0)
		ep(
			m,
			"Hand",
			Vector3.new(armW * 1.35, armW * 1.2, armW * 1.35),
			hand,
			s.Hands or s.Skin,
			s.HandsMat or Enum.Material.SmoothPlastic
		)
		if s.Bracer then
			ep(
				m,
				"Bracer",
				Vector3.new(armW * 1.2, armL * 0.3, armW * 1.2),
				arm * CFrame.new(0, -armL * 0.75, 0),
				s.Bracer,
				Enum.Material.Metal
			)
		end
		hands[side] = hand
	end
	local headCf = base * CFrame.new(0, legH + torsoH + headS * 0.5, 0)
	return {
		H = H,
		Head = headCf,
		HeadS = headS,
		Chest = base * CFrame.new(0, chestY, -torsoD / 2),
		Back = base * CFrame.new(0, chestY, torsoD / 2),
		ShoulderL = base * CFrame.new(-(torsoW / 2 + armW * 0.45), legH + torsoH, 0),
		ShoulderR = base * CFrame.new(torsoW / 2 + armW * 0.45, legH + torsoH, 0),
		HandL = hands[-1],
		HandR = hands[1],
		TorsoW = torsoW,
		TorsoD = torsoD,
		LegH = legH,
		TorsoH = torsoH,
	}
end

local function eyesPair(m, head: CFrame, spread: number, y: number, z: number, size: number, color: Color3)
	for _, side in { -1, 1 } do
		glow(m, "Eye", Vector3.new(size, size * 0.8, 0.08), head * CFrame.new(side * spread, y, -z), color)
	end
end

local function spikedPauldron(m, at: CFrame, size: number, plate: Color3, spikes: Color3, side: number)
	blob(
		m,
		"Pauldron",
		Vector3.new(size * 1.3, size * 0.8, size * 1.2),
		at * CFrame.new(side * size * 0.15, size * 0.1, 0),
		plate,
		Enum.Material.Metal
	)
	for k = -1, 1 do
		ep(
			m,
			"PauldronSpike",
			Vector3.new(size * 0.18, size * 0.5, size * 0.18),
			at * CFrame.new(side * size * 0.3, size * 0.45, k * size * 0.32) * CFrame.Angles(0, 0, -side * 0.4),
			spikes,
			Enum.Material.Metal
		)
	end
end

local function leafyPauldron(m, at: CFrame, size: number, color: Color3, side: number)
	for k = 0, 5 do
		local a = (k - 2.5) * 0.45
		ep(
			m,
			"ThornLeaf",
			Vector3.new(size * 0.35, size * 0.9, size * 0.08),
			at
				* CFrame.new(side * size * 0.3, size * 0.25, 0)
				* CFrame.Angles(0, a, -side * 0.9)
				* CFrame.new(0, size * 0.35, 0)
				* CFrame.Angles(0, 0, math.rad(45)),
			color:Lerp(Color3.new(0, 0, 0), (k % 2) * 0.12),
			Enum.Material.Grass
		)
	end
end

local function cape(m, back: CFrame, w: number, h: number, color: Color3, tatters: number)
	ep(
		m,
		"Cape",
		Vector3.new(w, h, 0.12),
		back * CFrame.new(0, -h * 0.35, 0.12) * CFrame.Angles(0.08, 0, 0),
		color,
		Enum.Material.Fabric
	)
	for k = 0, tatters - 1 do
		local x = -w / 2 + (k + 0.5) * w / tatters
		ep(
			m,
			"CapeTatter",
			Vector3.new(w / tatters * 0.8, h * 0.18, 0.1),
			back * CFrame.new(x, -h * 0.86 - (k % 2) * h * 0.05, 0.2) * CFrame.Angles(0.1, 0, math.rad(45)),
			color:Lerp(Color3.new(0, 0, 0), 0.1),
			Enum.Material.Fabric
		)
	end
end

-- Quadrupède (loup, hydre, dragon) -----------------------------------------------------------
local function quad(m, base: CFrame, s)
	local L, Hb, W = s.L, s.Hb, s.W
	local legH = s.LegH
	local body = base * CFrame.new(0, legH + Hb / 2, 0)
	blob(m, "Body", Vector3.new(W, Hb, L), body, s.Skin, s.SkinMat or Enum.Material.SmoothPlastic)
	if s.Belly then
		blob(
			m,
			"Belly",
			Vector3.new(W * 0.75, Hb * 0.7, L * 0.8),
			body * CFrame.new(0, -Hb * 0.15, -L * 0.05),
			s.Belly,
			Enum.Material.SmoothPlastic
		)
	end
	for _, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local leg = base * CFrame.new(p[1] * W * 0.32, legH / 2 + Hb * 0.1, p[2] * L * 0.3)
		ep(
			m,
			"Leg",
			Vector3.new(W * 0.24, legH + Hb * 0.2, W * 0.26),
			leg,
			s.Legs or s.Skin,
			s.SkinMat or Enum.Material.SmoothPlastic
		)
		local paw = base * CFrame.new(p[1] * W * 0.32, W * 0.06, p[2] * L * 0.3 - W * 0.05)
		ep(
			m,
			"Paw",
			Vector3.new(W * 0.3, W * 0.12, W * 0.36),
			paw,
			s.Paws or s.Legs or s.Skin,
			Enum.Material.SmoothPlastic
		)
		for k = -1, 1 do
			ep(
				m,
				"Claw",
				Vector3.new(W * 0.05, W * 0.06, W * 0.12),
				paw * CFrame.new(k * W * 0.09, 0, -W * 0.2),
				s.Claws or Color3.fromRGB(230, 220, 190),
				Enum.Material.SmoothPlastic
			)
		end
	end
	return body
end

local function beastHead(m, at: CFrame, size: number, s)
	blob(m, "Head", Vector3.new(size, size * 0.8, size), at, s.Skin, s.SkinMat or Enum.Material.SmoothPlastic)
	ep(
		m,
		"Snout",
		Vector3.new(size * 0.55, size * 0.4, size * 0.75),
		at * CFrame.new(0, -size * 0.12, -size * 0.55),
		s.Skin:Lerp(Color3.new(0, 0, 0), 0.1),
		s.SkinMat or Enum.Material.SmoothPlastic
	)
	ep(
		m,
		"Jaw",
		Vector3.new(size * 0.5, size * 0.14, size * 0.6),
		at * CFrame.new(0, -size * 0.36, -size * 0.45) * CFrame.Angles(math.rad(s.Open or 10), 0, 0),
		s.Belly or s.Skin,
		Enum.Material.SmoothPlastic
	)
	ep(
		m,
		"Nose",
		Vector3.new(size * 0.18, size * 0.12, size * 0.1),
		at * CFrame.new(0, -size * 0.02, -size * 0.92),
		Color3.fromRGB(30, 26, 28),
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		glow(
			m,
			"Eye",
			Vector3.new(size * 0.16, size * 0.1, 0.08),
			at * CFrame.new(side * size * 0.24, size * 0.12, -size * 0.48),
			s.Eye
		)
		if s.Teeth then
			ep(
				m,
				"Fang",
				Vector3.new(size * 0.06, size * 0.16, size * 0.06),
				at * CFrame.new(side * size * 0.16, -size * 0.32, -size * 0.8),
				Color3.fromRGB(240, 235, 220),
				Enum.Material.SmoothPlastic
			)
		end
		if s.Ears then
			ep(
				m,
				"Ear",
				Vector3.new(size * 0.3, size * 0.3, size * 0.1),
				at * CFrame.new(side * size * 0.3, size * 0.42, size * 0.1) * CFrame.Angles(0, 0, math.rad(45)),
				s.Skin,
				s.SkinMat or Enum.Material.SmoothPlastic
			)
		end
		if s.Horns then
			local cf = at
				* CFrame.new(side * size * 0.28, size * 0.35, size * 0.25)
				* CFrame.Angles(0.7, 0, -side * 0.3)
			for _, w in { 0.2, 0.16, 0.12, 0.08 } do
				ep(
					m,
					"Horn",
					Vector3.new(size * w, size * 0.28, size * w),
					cf * CFrame.new(0, size * 0.13, 0),
					s.Horns,
					Enum.Material.SmoothPlastic
				)
				cf = cf * CFrame.new(0, size * 0.25, 0) * CFrame.Angles(0.35, 0, 0)
			end
		end
	end
end

local function batWingsBig(m, at: CFrame, span: number, skin: Color3, bone: Color3)
	for _, side in { -1, 1 } do
		-- Ailes dressées en V, membranes inclinées vers l'avant (visibles de face et de profil)
		local root = at * CFrame.Angles(0, 0, side * 0.75)
		ep(
			m,
			"WingArm",
			Vector3.new(span, span * 0.06, span * 0.06),
			root * CFrame.new(side * span / 2, 0, 0),
			bone,
			Enum.Material.SmoothPlastic
		)
		ep(
			m,
			"WingClaw",
			Vector3.new(span * 0.08, span * 0.12, span * 0.08),
			root * CFrame.new(side * span, span * 0.05, 0),
			Color3.fromRGB(220, 200, 160),
			Enum.Material.SmoothPlastic
		)
		for k = 0, 3 do
			local len = span * (1 - k * 0.14)
			local fan = root * CFrame.Angles(0, -side * (0.25 + k * 0.32), 0)
			blob(
				m,
				"WingSkin",
				Vector3.new(len, span * 0.03, span * 0.34),
				fan * CFrame.new(side * len * 0.48, -span * 0.05, span * 0.1) * CFrame.Angles(math.rad(55), 0, 0),
				skin:Lerp(Color3.new(0, 0, 0), k * 0.07),
				Enum.Material.SmoothPlastic
			)
			ep(
				m,
				"WingBone",
				Vector3.new(len, span * 0.04, span * 0.04),
				fan * CFrame.new(side * len * 0.5, 0, 0),
				bone,
				Enum.Material.SmoothPlastic
			)
		end
	end
end

-- Fiches --------------------------------------------------------------------------------------

local enemyBuilders = {}

-- Gelée épineuse : gelée verte translucide, graine-cœur et racines, épines de bois moussues.
enemyBuilders.ThornJelly = function(m, base, k)
	local green = Color3.fromRGB(150, 210, 50)
	blob(
		m,
		"Seed",
		Vector3.new(1.1, 1.0, 1.1) * k,
		base * CFrame.new(0, 0.8 * k, 0.1 * k),
		Color3.fromRGB(100, 70, 45),
		Enum.Material.Wood
	)
	blob(
		m,
		"Jelly",
		Vector3.new(3.0, 2.2, 2.8) * k,
		base * CFrame.new(0, 1.0 * k, 0),
		green,
		Enum.Material.Glass,
		{ Transparency = 0.35 }
	)
	ep(
		m,
		"JellyBase",
		Vector3.new(3.2, 0.25, 3.0) * k,
		base * CFrame.new(0, 0.12 * k, 0),
		green:Lerp(Color3.new(1, 1, 0.5), 0.2),
		Enum.Material.Glass,
		{ Transparency = 0.3 }
	)
	for _, side in { -1, 1 } do
		glow(
			m,
			"Eye",
			Vector3.new(0.38, 0.38, 0.1) * k,
			base * CFrame.new(side * 0.5 * k, 1.2 * k, -1.33 * k) * CFrame.Angles(0, 0, math.rad(45)),
			Color3.fromRGB(255, 160, 30)
		)
	end
	for i, sp in { { 0, 2.4, 0, 1.2 }, { -0.9, 2.0, 0.3, 0.8 }, { 0.9, 2.0, 0.2, 0.8 }, { 0.2, 1.8, 0.9, 0.7 } } do
		local at = base * CFrame.new(sp[1] * k, sp[2] * k, sp[3] * k) * CFrame.Angles(0, i, sp[1] * -0.3)
		ep(m, "Thorn", Vector3.new(0.45, sp[4], 0.45) * k, at, Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
		ep(
			m,
			"ThornTip",
			Vector3.new(0.32, 0.32, 0.32) * k,
			at * CFrame.new(0, sp[4] * 0.5 * k, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color3.fromRGB(120, 80, 50),
			Enum.Material.Wood
		)
		ep(
			m,
			"Moss",
			Vector3.new(0.5, 0.15, 0.5) * k,
			at * CFrame.new(0, -sp[4] * 0.3 * k, 0),
			C.Leaf2,
			Enum.Material.Grass
		)
	end
	return 2.8 * k
end

-- Araignée des ruines : abdomen violet sous des plaques de pierre gravées, huit pattes de pierre
-- articulées, yeux turquoise, crocs.
enemyBuilders.RuinSpider = function(m, base, k)
	local stone = Color3.fromRGB(140, 130, 125)
	local body = base * CFrame.new(0, 1.3 * k, 0.5 * k)
	blob(m, "Abdomen", Vector3.new(2.4, 1.6, 2.4) * k, body, Color3.fromRGB(95, 60, 100), Enum.Material.Slate)
	for i, p in { { 0, 0.75, 0, 1.4 }, { -0.75, 0.45, 0.2, 0.9 }, { 0.75, 0.45, 0.2, 0.9 }, { 0, 0.5, 0.95, 1.0 } } do
		local plate = body * CFrame.new(p[1] * k, p[2] * k, p[3] * k) * CFrame.Angles(0, i * 0.4, p[1] * -0.4)
		ep(m, "Plate", Vector3.new(p[4], 0.25, p[4]) * k, plate, stone, Enum.Material.Slate)
		ep(
			m,
			"Spiral",
			Vector3.new(p[4] * 0.5, 0.06, p[4] * 0.5) * k,
			plate * CFrame.new(0, 0.14 * k, 0) * CFrame.Angles(0, math.rad(45), 0),
			stone:Lerp(Color3.new(1, 1, 1), 0.25),
			Enum.Material.Slate
		)
	end
	glow(
		m,
		"BackGem",
		Vector3.new(0.4, 0.4, 0.1) * k,
		body * CFrame.new(0, -0.2 * k, 1.2 * k) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(255, 160, 40)
	)
	local head = base * CFrame.new(0, 1.1 * k, -1.0 * k)
	ep(m, "Head", Vector3.new(1.3, 0.9, 1.0) * k, head, stone, Enum.Material.Slate)
	for _, e in { { -0.3, 0.1 }, { 0.3, 0.1 }, { -0.15, -0.12 }, { 0.15, -0.12 } } do
		glow(
			m,
			"Eye",
			Vector3.new(0.18, 0.18, 0.08) * k,
			head * CFrame.new(e[1] * k, e[2] * k, -0.52 * k),
			Color3.fromRGB(60, 230, 220),
			Enum.PartType.Ball
		)
	end
	for _, side in { -1, 1 } do
		ep(
			m,
			"Fang",
			Vector3.new(0.12, 0.4, 0.12) * k,
			head * CFrame.new(side * 0.25 * k, -0.5 * k, -0.4 * k),
			Color3.fromRGB(235, 225, 200),
			Enum.Material.SmoothPlastic
		)
		for j = 0, 3 do
			local a = (j - 1.5) * 0.45
			local hip = base * CFrame.new(side * 0.8 * k, 1.2 * k, (j - 1.5) * 0.45 * k) * CFrame.Angles(0, side * a, 0)
			local up = hip * CFrame.Angles(0, 0, side * -0.55)
			ep(
				m,
				"LegUpper",
				Vector3.new(1.4, 0.35, 0.35) * k,
				up * CFrame.new(side * 0.7 * k, 0, 0),
				stone:Lerp(Color3.new(0, 0, 0), j % 2 * 0.08),
				Enum.Material.Slate
			)
			local knee = up * CFrame.new(side * 1.4 * k, 0, 0)
			ep(
				m,
				"Joint",
				Vector3.new(0.3, 0.3, 0.3) * k,
				knee,
				IRON,
				Enum.Material.Metal,
				{ Shape = Enum.PartType.Ball }
			)
			local low = knee * CFrame.Angles(0, 0, side * 1.3)
			ep(
				m,
				"LegLower",
				Vector3.new(1.5, 0.3, 0.3) * k,
				low * CFrame.new(side * 0.75 * k, 0, 0),
				stone,
				Enum.Material.Slate
			)
			ep(
				m,
				"LegTip",
				Vector3.new(0.22, 0.22, 0.22) * k,
				low * CFrame.new(side * 1.5 * k, 0, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				Color3.fromRGB(80, 60, 50),
				Enum.Material.Slate
			)
		end
	end
	return 2.6 * k
end

-- Gobelin ferrailleur : gobelin à capuche, tunique rapiécée, épaulières rouillées, couperet,
-- bouclier de planches à rouage, sac à dos (pioche, tuyaux).
enemyBuilders.ScrapGoblin = function(m, base, k)
	local skin = Color3.fromRGB(130, 165, 70)
	local b = biped(m, base, {
		H = 4.2 * k,
		Bulk = 1.15,
		Head = 0.3,
		Skin = skin,
		Torso = LEATHER,
		Pants = Color3.fromRGB(90, 60, 40),
		Boots = Color3.fromRGB(80, 55, 38),
		Bracer = RUST,
	})
	local hs = b.HeadS
	blob(m, "Head", Vector3.new(hs * 0.95, hs * 0.85, hs * 0.9), b.Head, skin)
	blob(
		m,
		"Hood",
		Vector3.new(hs * 1.05, hs * 0.75, hs * 0.95),
		b.Head * CFrame.new(0, hs * 0.18, hs * 0.08),
		LEATHER:Lerp(RUST, 0.2),
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		ep(
			m,
			"Ear",
			Vector3.new(hs * 0.65, hs * 0.18, hs * 0.08),
			b.Head * CFrame.new(side * hs * 0.65, hs * 0.05, 0) * CFrame.Angles(0, 0, side * 0.25),
			skin
		)
		ep(
			m,
			"Pauldron",
			Vector3.new(b.TorsoW * 0.45, hs * 0.2, b.TorsoD * 1.1),
			(if side < 0 then b.ShoulderL else b.ShoulderR) * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, side * 0.3),
			RUST,
			Enum.Material.CorrodedMetal
		)
	end
	eyesPair(m, b.Head, hs * 0.2, hs * 0.02, hs * 0.44, hs * 0.16, Color3.fromRGB(255, 220, 60))
	ep(
		m,
		"Tusk",
		Vector3.new(hs * 0.08, hs * 0.12, hs * 0.06),
		b.Head * CFrame.new(hs * 0.15, -hs * 0.3, -hs * 0.4),
		Color3.fromRGB(240, 235, 210)
	)
	ep(
		m,
		"Rope",
		Vector3.new(b.TorsoW * 1.06, b.TorsoH * 0.08, b.TorsoD * 1.08),
		b.Chest * CFrame.new(0, -b.TorsoH * 0.32, b.TorsoD / 2),
		ROPE,
		Enum.Material.Fabric
	)
	ep(
		m,
		"Strap",
		Vector3.new(b.TorsoW * 0.15, b.TorsoH * 1.1, 0.1),
		b.Chest * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, 0, 0.6),
		LEATHER:Lerp(Color3.new(0, 0, 0), 0.2),
		Enum.Material.Fabric
	)
	-- Sac à dos, pioche et tuyaux
	local pack = b.Back * CFrame.new(0, 0, b.TorsoD * 0.35)
	ep(m, "Backpack", Vector3.new(b.TorsoW * 0.8, b.TorsoH * 0.75, b.TorsoD * 0.7), pack, LEATHER, Enum.Material.Fabric)
	for _, x in { -0.15, 0.12 } do
		ep(
			m,
			"Pipe",
			Vector3.new(b.TorsoW * 0.12, b.TorsoH * 0.45, b.TorsoW * 0.12),
			pack * CFrame.new(x * b.TorsoW, b.TorsoH * 0.5, 0),
			IRON,
			Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	ep(
		m,
		"PickHandle",
		Vector3.new(0.12, b.TorsoH * 1.3, 0.12) * k,
		pack * CFrame.new(b.TorsoW * 0.25, b.TorsoH * 0.55, 0.1) * CFrame.Angles(0, 0, -0.3),
		C.WoodDark,
		Enum.Material.Wood
	)
	ep(
		m,
		"PickHead",
		Vector3.new(b.TorsoW * 0.9, 0.14 * k, 0.14 * k),
		pack * CFrame.new(b.TorsoW * 0.45, b.TorsoH * 1.15, 0.1) * CFrame.Angles(0, 0, -0.3),
		IRON,
		Enum.Material.Metal
	)
	weaponCleaver(m, b.HandR, b.H * 0.4)
	plankShield(
		m,
		b.HandL * CFrame.new(-0.2 * k, b.H * 0.05, -0.2 * k),
		b.H * 0.3,
		b.H * 0.4,
		Color3.fromRGB(150, 105, 65),
		Color3.fromRGB(225, 215, 195)
	)
	return b.H
end

-- Squelette sentinelle : os, cage thoracique et gemme d'âme, tabard rouge, chapeau de fer,
-- épée et bouclier.
enemyBuilders.SkeletonSentinel = function(m, base, k)
	local bone = Color3.fromRGB(225, 210, 175)
	local red = Color3.fromRGB(130, 40, 45)
	local b = biped(m, base, {
		H = 5.6 * k,
		Bulk = 0.7,
		Head = 0.2,
		Skin = bone,
		Torso = bone:Lerp(Color3.new(0, 0, 0), 0.25),
		Pants = bone,
		Boots = LEATHER,
		Bracer = LEATHER,
	})
	local hs = b.HeadS
	ep(m, "Skull", Vector3.new(hs * 0.85, hs * 0.85, hs * 0.85), b.Head, bone)
	ep(
		m,
		"Jaw",
		Vector3.new(hs * 0.6, hs * 0.22, hs * 0.6),
		b.Head * CFrame.new(0, -hs * 0.5, -hs * 0.08),
		bone:Lerp(Color3.new(0, 0, 0), 0.08)
	)
	eyesPair(m, b.Head, hs * 0.2, hs * 0.05, hs * 0.43, hs * 0.2, Color3.fromRGB(255, 200, 60))
	ep(
		m,
		"HatBrim",
		Vector3.new(hs * 0.08, hs * 1.6, hs * 1.6),
		b.Head * CFrame.new(0, hs * 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)),
		IRON:Lerp(RUST, 0.3),
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
	blob(
		m,
		"HatDome",
		Vector3.new(hs * 1.0, hs * 0.6, hs * 1.0),
		b.Head * CFrame.new(0, hs * 0.5, 0),
		IRON:Lerp(RUST, 0.3),
		Enum.Material.Metal
	)
	for r = 0, 3 do
		ep(
			m,
			"Rib",
			Vector3.new(b.TorsoW * 1.05, b.TorsoH * 0.07, b.TorsoD * 1.1),
			b.Chest * CFrame.new(0, b.TorsoH * (0.3 - r * 0.15), b.TorsoD / 2),
			bone
		)
	end
	glow(
		m,
		"SoulGem",
		Vector3.new(b.TorsoW * 0.2, b.TorsoW * 0.32, 0.12),
		b.Chest * CFrame.new(0, b.TorsoH * 0.1, -0.05) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(255, 190, 50)
	)
	ep(
		m,
		"Tabard",
		Vector3.new(b.TorsoW * 0.6, b.TorsoH * 0.9, 0.08),
		b.Chest * CFrame.new(0, -b.TorsoH * 0.55, -0.06),
		red,
		Enum.Material.Fabric
	)
	ep(
		m,
		"Mantle",
		Vector3.new(b.TorsoW * 1.3, b.TorsoH * 0.25, b.TorsoD * 1.2),
		b.Chest * CFrame.new(0, b.TorsoH * 0.42, b.TorsoD / 2),
		red,
		Enum.Material.Fabric
	)
	weaponSword(
		m,
		b.HandR * CFrame.Angles(math.rad(-20), 0, 0),
		b.H * 0.4,
		IRON:Lerp(Color3.new(1, 1, 1), 0.2),
		LEATHER
	)
	plankShield(
		m,
		b.HandL * CFrame.new(-0.2 * k, b.H * 0.08, -0.25 * k),
		b.H * 0.26,
		b.H * 0.38,
		Color3.fromRGB(110, 70, 45),
		Color3.fromRGB(200, 170, 120)
	)
	return b.H
end

-- Loup des ronces : fourrure sombre, plaques de bois moussues serties de ronces, yeux verts.
enemyBuilders.BrambleWolf = function(m, base, k)
	local fur = Color3.fromRGB(60, 58, 62)
	local s = {
		L = 4.2 * k,
		Hb = 1.8 * k,
		W = 1.7 * k,
		LegH = 1.4 * k,
		Skin = fur,
		Belly = fur:Lerp(Color3.new(1, 1, 1), 0.12),
		Eye = Color3.fromRGB(170, 255, 60),
		Teeth = true,
		Ears = true,
	}
	local body = quad(m, base, s)
	beastHead(m, body * CFrame.new(0, 0.5 * k, -2.3 * k), 1.5 * k, s)
	local wood = Color3.fromRGB(120, 80, 50)
	for i, p in
		{
			{ 0, 0.85, -0.9 },
			{ 0, 0.9, 0.3 },
			{ 0, 0.8, 1.4 },
			{ -0.75, 0.4, -0.4 },
			{ 0.75, 0.4, -0.4 },
			{ -0.75, 0.4, 0.9 },
			{ 0.75, 0.4, 0.9 },
		}
	do
		local plate = body * CFrame.new(p[1] * k, p[2] * k, p[3] * k) * CFrame.Angles(0.15, 0, p[1] * -0.8)
		ep(
			m,
			"BarkPlate",
			Vector3.new(1.1, 0.25, 1.0) * k,
			plate,
			wood:Lerp(Color3.new(0, 0, 0), i % 2 * 0.1),
			Enum.Material.Wood
		)
		ep(
			m,
			"PlateMoss",
			Vector3.new(0.6, 0.1, 0.4) * k,
			plate * CFrame.new(0, 0.15 * k, -0.2 * k),
			C.Leaf2,
			Enum.Material.Grass
		)
		glow(
			m,
			"BrambleVein",
			Vector3.new(0.06, 0.06, 0.8) * k,
			plate * CFrame.new(0.2 * k, 0.14 * k, 0),
			Color3.fromRGB(150, 230, 60)
		)
		ep(
			m,
			"Thorn",
			Vector3.new(0.12, 0.45, 0.12) * k,
			plate * CFrame.new(0, 0.3 * k, 0.3 * k) * CFrame.Angles(0.5, 0, 0),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.Wood
		)
	end
	for k2 = 0, 2 do
		blob(
			m,
			"Tail",
			Vector3.new(0.7, 0.7, 1.1) * k * (1 - k2 * 0.15),
			body * CFrame.new(0, (0.2 + k2 * 0.25) * k, (2.2 + k2 * 0.7) * k) * CFrame.Angles(-0.5, 0, 0),
			fur,
			Enum.Material.SmoothPlastic
		)
	end
	return 3.6 * k
end

-- Cultiste des cendres : robe sombre à liserés rouges, capuche et demi-masque de cuivre, bâton
-- à cristal de braise, fioles à la ceinture.
enemyBuilders.AshCultist = function(m, base, k)
	local robe = Color3.fromRGB(55, 45, 50)
	local red = Color3.fromRGB(130, 35, 40)
	local b = biped(m, base, {
		H = 5.9 * k,
		Bulk = 1.0,
		Head = 0.2,
		Skin = robe,
		Torso = robe,
		Pants = robe,
		Boots = Color3.fromRGB(40, 32, 35),
		Hands = Color3.fromRGB(70, 55, 50),
	})
	local hs = b.HeadS
	-- Robe longue jusqu'au sol
	ep(
		m,
		"RobeSkirt",
		Vector3.new(b.TorsoW * 1.2, b.LegH * 0.95, b.TorsoD * 1.4),
		base * CFrame.new(0, b.LegH * 0.5, 0),
		robe,
		Enum.Material.Fabric
	)
	ep(
		m,
		"RobeTrim",
		Vector3.new(b.TorsoW * 1.22, b.LegH * 0.08, b.TorsoD * 1.42),
		base * CFrame.new(0, b.LegH * 0.06, 0),
		red,
		Enum.Material.Fabric
	)
	ep(
		m,
		"Sash",
		Vector3.new(b.TorsoW * 0.32, b.TorsoH * 1.4, 0.08),
		b.Chest * CFrame.new(0, -b.TorsoH * 0.35, -0.06),
		red,
		Enum.Material.Fabric
	)
	glow(
		m,
		"SashSigil",
		Vector3.new(b.TorsoW * 0.16, b.TorsoW * 0.16, 0.05),
		b.Chest * CFrame.new(0, -b.TorsoH * 0.4, -0.11) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(255, 120, 60)
	)
	blob(
		m,
		"Hood",
		Vector3.new(hs * 1.25, hs * 1.3, hs * 1.25),
		b.Head * CFrame.new(0, hs * 0.08, hs * 0.05),
		robe:Lerp(Color3.new(0, 0, 0), 0.15),
		Enum.Material.Fabric
	)
	ep(
		m,
		"HoodTrim",
		Vector3.new(hs * 1.0, hs * 0.08, hs * 0.1),
		b.Head * CFrame.new(0, hs * 0.48, -hs * 0.55),
		red,
		Enum.Material.Fabric
	)
	ep(
		m,
		"Mask",
		Vector3.new(hs * 0.75, hs * 0.75, hs * 0.1),
		b.Head * CFrame.new(0, 0, -hs * 0.56),
		Color3.fromRGB(185, 115, 70),
		Enum.Material.Metal
	)
	eyesPair(m, b.Head, hs * 0.17, hs * 0.08, hs * 0.62, hs * 0.13, Color3.fromRGB(255, 140, 60))
	for _, side in { -1, 1 } do
		ep(
			m,
			"Mantle",
			Vector3.new(b.TorsoW * 0.5, b.TorsoH * 0.3, b.TorsoD * 1.25),
			(if side < 0 then b.ShoulderL else b.ShoulderR) * CFrame.new(-side * b.TorsoW * 0.1, -b.TorsoH * 0.05, 0),
			red,
			Enum.Material.Fabric
		)
		glow(
			m,
			"Potion",
			Vector3.new(0.35, 0.45, 0.35) * k,
			b.Chest * CFrame.new(side * b.TorsoW * 0.35, -b.TorsoH * 0.42, -0.1),
			Color3.fromRGB(230, 60, 50),
			Enum.PartType.Ball
		)
	end
	weaponStaff(m, b.HandR, b.H * 0.95, Color3.fromRGB(255, 150, 40))
	return b.H
end

-- Orque brise-bouclier (élite) : massif, épaulières à pointes, pagne rouge, gemme de ceinture,
-- marteau de pierre runique.
enemyBuilders.ShieldbreakerOrc = function(m, base, k)
	local skin = Color3.fromRGB(110, 140, 70)
	local b = biped(m, base, {
		H = 7.5 * k,
		Bulk = 1.45,
		Head = 0.19,
		Skin = skin,
		Torso = skin,
		Pants = Color3.fromRGB(70, 60, 55),
		Boots = Color3.fromRGB(65, 55, 50),
		Bracer = IRON,
		Knee = IRON,
	})
	local hs = b.HeadS
	ep(m, "Head", Vector3.new(hs * 0.95, hs * 0.9, hs * 0.9), b.Head, skin)
	ep(
		m,
		"Brow",
		Vector3.new(hs * 0.95, hs * 0.18, hs * 0.2),
		b.Head * CFrame.new(0, hs * 0.15, -hs * 0.42),
		skin:Lerp(Color3.new(0, 0, 0), 0.2)
	)
	eyesPair(m, b.Head, hs * 0.2, hs * 0.02, hs * 0.46, hs * 0.13, Color3.fromRGB(255, 200, 60))
	for _, side in { -1, 1 } do
		ep(
			m,
			"Tusk",
			Vector3.new(hs * 0.1, hs * 0.25, hs * 0.1),
			b.Head * CFrame.new(side * hs * 0.22, -hs * 0.32, -hs * 0.42),
			Color3.fromRGB(240, 235, 210)
		)
		ep(
			m,
			"Ear",
			Vector3.new(hs * 0.35, hs * 0.2, hs * 0.08),
			b.Head * CFrame.new(side * hs * 0.55, hs * 0.05, 0) * CFrame.Angles(0, 0, side * 0.3),
			skin
		)
		spikedPauldron(
			m,
			if side < 0 then b.ShoulderL else b.ShoulderR,
			b.TorsoW * 0.5,
			IRON,
			Color3.fromRGB(200, 195, 180),
			side
		)
	end
	ep(
		m,
		"Mohawk",
		Vector3.new(hs * 0.15, hs * 0.5, hs * 0.8),
		b.Head * CFrame.new(0, hs * 0.6, 0.1),
		Color3.fromRGB(35, 30, 30)
	)
	ep(
		m,
		"Strap",
		Vector3.new(b.TorsoW * 0.15, b.TorsoH * 1.15, 0.12),
		b.Chest * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, 0, 0.55),
		LEATHER,
		Enum.Material.Fabric
	)
	glow(
		m,
		"BeltGem",
		Vector3.new(b.TorsoW * 0.18, b.TorsoW * 0.18, 0.12),
		b.Chest * CFrame.new(0, -b.TorsoH * 0.38, -0.1) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(255, 160, 40)
	)
	ep(
		m,
		"Loincloth",
		Vector3.new(b.TorsoW * 0.4, b.LegH * 0.6, 0.1),
		base * CFrame.new(0, b.LegH * 0.7, -b.TorsoD / 2 - 0.05),
		Color3.fromRGB(140, 40, 40),
		Enum.Material.Fabric
	)
	weaponHammer(m, b.HandR, b.H * 0.5, Color3.fromRGB(120, 115, 110), Color3.fromRGB(230, 190, 120))
	return b.H
end

-- Golem des carrières (élite) : blocs de grès, mousse sur les épaules, cœur de cristal turquoise
-- et runes gravées.
enemyBuilders.QuarryGolem = function(m, base, k)
	local sand = Color3.fromRGB(190, 160, 115)
	local b = biped(m, base, {
		H = 8.5 * k,
		Bulk = 1.7,
		Head = 0.15,
		Skin = sand,
		Torso = sand,
		Pants = sand:Lerp(Color3.new(0, 0, 0), 0.1),
		Boots = sand:Lerp(Color3.new(0, 0, 0), 0.15),
		TorsoMat = Enum.Material.Sandstone,
		PantsMat = Enum.Material.Sandstone,
		BootsMat = Enum.Material.Sandstone,
		ArmsMat = Enum.Material.Sandstone,
		HandsMat = Enum.Material.Sandstone,
	})
	local hs = b.HeadS
	ep(m, "Head", Vector3.new(hs * 1.1, hs * 0.9, hs), b.Head, sand, Enum.Material.Sandstone)
	eyesPair(m, b.Head, hs * 0.22, 0, hs * 0.52, hs * 0.16, Color3.fromRGB(80, 230, 200))
	glow(
		m,
		"Core",
		Vector3.new(b.TorsoW * 0.28, b.TorsoW * 0.36, 0.2),
		b.Chest * CFrame.new(0, b.TorsoH * 0.1, -0.1) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(60, 230, 190)
	)
	local rand = rng(17)
	for i = 1, 10 do
		local at = b.Chest
			* CFrame.new(
				(rand() - 0.5) * b.TorsoW * 0.9,
				(rand() - 0.5) * b.TorsoH * 0.9,
				b.TorsoD * (rand() < 0.5 and 0 or 1)
			)
		ep(
			m,
			"Block",
			Vector3.new(b.TorsoW * 0.3, b.TorsoH * 0.22, 0.3 * k),
			at * CFrame.Angles(0, 0, rand() * 0.3),
			sand:Lerp(Color3.new(0, 0, 0), rand() * 0.15),
			Enum.Material.Sandstone
		)
		if i % 3 == 0 then
			glow(
				m,
				"Rune",
				Vector3.new(b.TorsoW * 0.12, b.TorsoW * 0.12, 0.05),
				at * CFrame.new(0, 0, -0.17 * k) * CFrame.Angles(0, 0, math.rad(45)),
				Color3.fromRGB(80, 220, 190)
			)
		end
	end
	for _, side in { -1, 1 } do
		local sh = if side < 0 then b.ShoulderL else b.ShoulderR
		ep(
			m,
			"ShoulderRock",
			Vector3.new(b.TorsoW * 0.55, b.TorsoW * 0.45, b.TorsoD * 1.2),
			sh * CFrame.new(side * b.TorsoW * 0.05, b.TorsoW * 0.05, 0),
			sand,
			Enum.Material.Sandstone
		)
		blob(
			m,
			"Moss",
			Vector3.new(b.TorsoW * 0.5, b.TorsoW * 0.18, b.TorsoD * 1.1),
			sh * CFrame.new(side * b.TorsoW * 0.05, b.TorsoW * 0.28, 0),
			C.Leaf2,
			Enum.Material.Grass
		)
		ep(
			m,
			"Fist",
			Vector3.new(b.TorsoW * 0.45, b.TorsoW * 0.45, b.TorsoW * 0.45),
			(if side < 0 then b.HandL else b.HandR) * CFrame.new(0, -b.TorsoW * 0.1, 0),
			sand,
			Enum.Material.Sandstone
		)
	end
	return b.H
end

-- Chevalier des épines (élite) : armure verte à feuilles épineuses, cape pourpre en lambeaux,
-- heaume à bois de cerf et visière lumineuse, épée à runes.
enemyBuilders.ThornKnight = function(m, base, k)
	local armor = Color3.fromRGB(75, 95, 60)
	local b = biped(m, base, {
		H = 8.0 * k,
		Bulk = 1.2,
		Head = 0.17,
		Skin = armor,
		Torso = armor,
		Pants = armor:Lerp(Color3.new(0, 0, 0), 0.15),
		Boots = armor:Lerp(Color3.new(0, 0, 0), 0.25),
		TorsoMat = Enum.Material.Metal,
		PantsMat = Enum.Material.Metal,
		BootsMat = Enum.Material.Metal,
		ArmsMat = Enum.Material.Metal,
		Knee = Color3.fromRGB(150, 130, 70),
		Bracer = Color3.fromRGB(150, 130, 70),
	})
	local hs = b.HeadS
	ep(
		m,
		"Helm",
		Vector3.new(hs * 0.95, hs, hs * 0.95),
		b.Head,
		armor:Lerp(Color3.new(0, 0, 0), 0.1),
		Enum.Material.Metal
	)
	ep(
		m,
		"HelmCrest",
		Vector3.new(hs * 0.12, hs * 0.5, hs * 0.9),
		b.Head * CFrame.new(0, hs * 0.5, 0),
		Color3.fromRGB(150, 130, 70),
		Enum.Material.Metal
	)
	glow(
		m,
		"Visor",
		Vector3.new(hs * 0.6, hs * 0.1, 0.08),
		b.Head * CFrame.new(0, hs * 0.05, -hs * 0.48),
		Color3.fromRGB(220, 255, 90)
	)
	glow(
		m,
		"VisorV",
		Vector3.new(hs * 0.1, hs * 0.35, 0.08),
		b.Head * CFrame.new(0, -hs * 0.1, -hs * 0.48),
		Color3.fromRGB(220, 255, 90)
	)
	for _, side in { -1, 1 } do
		local cf = b.Head * CFrame.new(side * hs * 0.3, hs * 0.5, 0) * CFrame.Angles(0, 0, -side * 0.4)
		ep(
			m,
			"Antler",
			Vector3.new(0.18 * k, hs * 0.8, 0.18 * k),
			cf * CFrame.new(0, hs * 0.4, 0),
			Color3.fromRGB(110, 75, 50),
			Enum.Material.Wood
		)
		ep(
			m,
			"AntlerTine",
			Vector3.new(0.14 * k, hs * 0.45, 0.14 * k),
			cf * CFrame.new(0, hs * 0.55, 0) * CFrame.Angles(0, 0, side * 0.8) * CFrame.new(0, hs * 0.2, 0),
			Color3.fromRGB(110, 75, 50),
			Enum.Material.Wood
		)
		leafyPauldron(
			m,
			if side < 0 then b.ShoulderL else b.ShoulderR,
			b.TorsoW * 0.55,
			Color3.fromRGB(85, 120, 55),
			side
		)
	end
	cape(m, b.Back * CFrame.new(0, b.TorsoH * 0.45, 0), b.TorsoW * 1.3, b.H * 0.6, Color3.fromRGB(110, 40, 70), 6)
	ep(
		m,
		"Tasset",
		Vector3.new(b.TorsoW * 0.9, b.LegH * 0.45, b.TorsoD * 1.15),
		base * CFrame.new(0, b.LegH * 0.85, 0),
		armor,
		Enum.Material.Metal
	)
	weaponSword(
		m,
		b.HandR * CFrame.Angles(math.rad(-15), 0, 0),
		b.H * 0.6,
		Color3.fromRGB(170, 175, 160),
		Color3.fromRGB(150, 130, 70),
		Color3.fromRGB(180, 230, 90)
	)
	return b.H
end

-- Roi gobelin (boss régional) : énorme gobelin couronné, cape rouge, armure cloutée, fermoir
-- rubis, écus pendus à la ceinture, tonneaux dans le dos, masse à pointes.
enemyBuilders.GoblinKing = function(m, base, k)
	local skin = Color3.fromRGB(120, 155, 65)
	local b = biped(m, base, {
		H = 11 * k,
		Bulk = 1.65,
		Head = 0.2,
		Skin = skin,
		Torso = Color3.fromRGB(95, 85, 80),
		TorsoMat = Enum.Material.Metal,
		Pants = Color3.fromRGB(80, 60, 45),
		Boots = Color3.fromRGB(70, 60, 55),
		BootsMat = Enum.Material.Metal,
		Bracer = IRON,
		Knee = IRON,
	})
	local hs = b.HeadS
	blob(m, "Head", Vector3.new(hs * 1.1, hs * 0.95, hs), b.Head, skin)
	eyesPair(m, b.Head, hs * 0.22, hs * 0.05, hs * 0.46, hs * 0.13, Color3.fromRGB(255, 210, 60))
	for _, side in { -1, 1 } do
		ep(
			m,
			"Ear",
			Vector3.new(hs * 0.7, hs * 0.2, hs * 0.08),
			b.Head * CFrame.new(side * hs * 0.75, hs * 0.08, 0) * CFrame.Angles(0, 0, side * 0.2),
			skin
		)
		ep(
			m,
			"Tusk",
			Vector3.new(hs * 0.1, hs * 0.2, hs * 0.08),
			b.Head * CFrame.new(side * hs * 0.2, -hs * 0.32, -hs * 0.42),
			Color3.fromRGB(240, 235, 210)
		)
		spikedPauldron(
			m,
			if side < 0 then b.ShoulderL else b.ShoulderR,
			b.TorsoW * 0.45,
			Color3.fromRGB(100, 90, 85),
			Color3.fromRGB(210, 180, 100),
			side
		)
	end
	-- Couronne
	local crownCf = b.Head * CFrame.new(0, hs * 0.55, 0)
	ep(
		m,
		"CrownBand",
		Vector3.new(hs * 0.25, hs * 0.85, hs * 0.85),
		crownCf * CFrame.Angles(0, 0, math.rad(90)),
		GOLD,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		ep(
			m,
			"CrownSpike",
			Vector3.new(hs * 0.12, hs * 0.35, hs * 0.12),
			crownCf * CFrame.Angles(0, a, 0) * CFrame.new(0, hs * 0.2, -hs * 0.38),
			GOLD,
			Enum.Material.Metal
		)
	end
	glow(
		m,
		"CrownRuby",
		Vector3.new(hs * 0.15, hs * 0.15, 0.06),
		crownCf * CFrame.new(0, 0, -hs * 0.43) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(230, 30, 40)
	)
	cape(m, b.Back * CFrame.new(0, b.TorsoH * 0.45, 0), b.TorsoW * 1.4, b.H * 0.55, Color3.fromRGB(150, 35, 40), 7)
	ep(
		m,
		"Clasp",
		Vector3.new(b.TorsoW * 0.22, b.TorsoW * 0.22, 0.2),
		b.Chest * CFrame.new(0, b.TorsoH * 0.3, -0.1) * CFrame.Angles(0, 0, math.rad(45)),
		GOLD,
		Enum.Material.Metal
	)
	glow(
		m,
		"ClaspRuby",
		Vector3.new(b.TorsoW * 0.12, b.TorsoW * 0.12, 0.22),
		b.Chest * CFrame.new(0, b.TorsoH * 0.3, -0.12) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(230, 30, 40)
	)
	for i, col in { Color3.fromRGB(60, 90, 160), Color3.fromRGB(170, 40, 40), Color3.fromRGB(60, 120, 70) } do
		ep(
			m,
			"Crest",
			Vector3.new(b.TorsoW * 0.22, b.TorsoW * 0.26, 0.12),
			b.Chest * CFrame.new((i - 2) * b.TorsoW * 0.3, -b.TorsoH * 0.42, -0.12),
			col,
			Enum.Material.Wood
		)
	end
	for _, side in { -1, 1 } do
		ep(
			m,
			"Barrel",
			Vector3.new(b.TorsoH * 0.55, b.TorsoW * 0.35, b.TorsoW * 0.35),
			b.Back * CFrame.new(side * b.TorsoW * 0.22, 0, b.TorsoD * 0.2) * CFrame.Angles(0, 0, math.rad(90)),
			C.Wood,
			Enum.Material.WoodPlanks,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	weaponMace(m, b.HandR, b.H * 0.4)
	return b.H
end

-- Gardien des racines (boss régional) : colosse de bois tressé, feuillage sur les épaules, cœur
-- d'ambre, runes dorées, bois de branches, champignons dans le dos.
enemyBuilders.RootGuardian = function(m, base, k)
	local wood = Color3.fromRGB(125, 90, 60)
	local b = biped(m, base, {
		H = 14 * k,
		Bulk = 1.45,
		Head = 0.14,
		Skin = wood,
		Torso = wood,
		Pants = wood:Lerp(Color3.new(0, 0, 0), 0.1),
		Boots = wood:Lerp(Color3.new(0, 0, 0), 0.2),
		TorsoMat = Enum.Material.Wood,
		PantsMat = Enum.Material.Wood,
		BootsMat = Enum.Material.Wood,
		ArmsMat = Enum.Material.Wood,
		HandsMat = Enum.Material.Wood,
	})
	local hs = b.HeadS
	ep(m, "Head", Vector3.new(hs * 0.9, hs * 1.1, hs * 0.9), b.Head, wood, Enum.Material.Wood)
	eyesPair(m, b.Head, hs * 0.2, hs * 0.1, hs * 0.46, hs * 0.13, Color3.fromRGB(255, 200, 60))
	glow(
		m,
		"AmberHeart",
		Vector3.new(b.TorsoW * 0.25, b.TorsoW * 0.3, 0.25),
		b.Chest * CFrame.new(0, b.TorsoH * 0.12, -0.15) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(255, 170, 40)
	)
	for _, side in { -1, 1 } do
		ep(
			m,
			"BarkDoor",
			Vector3.new(b.TorsoW * 0.3, b.TorsoH * 0.5, 0.25 * k),
			b.Chest * CFrame.new(side * b.TorsoW * 0.28, b.TorsoH * 0.12, -0.2) * CFrame.Angles(0, side * 0.4, 0),
			wood:Lerp(Color3.new(0, 0, 0), 0.15),
			Enum.Material.Wood
		)
		leafClump(
			m,
			(if side < 0 then b.ShoulderL else b.ShoulderR) * CFrame.new(side * b.TorsoW * 0.15, b.TorsoW * 0.3, 0),
			b.TorsoW * 0.45,
			{ Color3.fromRGB(46, 110, 52), Color3.fromRGB(70, 140, 60), Color3.fromRGB(150, 200, 70) },
			40 + side
		)
		glow(
			m,
			"ArmRune",
			Vector3.new(b.TorsoW * 0.15, b.TorsoW * 0.15, 0.05),
			(if side < 0 then b.HandL else b.HandR)
				* CFrame.new(0, b.TorsoH * 0.45, -b.TorsoW * 0.2)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color3.fromRGB(255, 200, 70)
		)
		local tine = b.Head * CFrame.new(side * hs * 0.25, hs * 0.5, 0) * CFrame.Angles(0, 0, -side * 0.5)
		ep(
			m,
			"Branch",
			Vector3.new(0.4 * k, hs * 1.2, 0.4 * k),
			tine * CFrame.new(0, hs * 0.6, 0),
			wood,
			Enum.Material.Wood
		)
		ep(
			m,
			"Twig",
			Vector3.new(0.3 * k, hs * 0.6, 0.3 * k),
			tine * CFrame.new(0, hs * 0.9, 0) * CFrame.Angles(0, 0, side * 0.9) * CFrame.new(0, hs * 0.3, 0),
			wood,
			Enum.Material.Wood
		)
		-- Doigts en racines
		for f = -1, 1 do
			ep(
				m,
				"RootFinger",
				Vector3.new(0.35 * k, b.TorsoW * 0.35, 0.35 * k),
				(if side < 0 then b.HandL else b.HandR)
					* CFrame.new(f * b.TorsoW * 0.1, -b.TorsoW * 0.25, -b.TorsoW * 0.05)
					* CFrame.Angles(0.2, 0, f * 0.2),
				wood:Lerp(Color3.new(0, 0, 0), 0.2),
				Enum.Material.Wood
			)
		end
	end
	for i = 0, 3 do
		local at = b.Back * CFrame.new((i - 1.5) * b.TorsoW * 0.22, (i % 2 - 0.5) * b.TorsoH * 0.4, 0.15)
		ep(
			m,
			"MushStem",
			Vector3.new(0.3 * k, 0.6 * k, 0.3 * k),
			at,
			Color3.fromRGB(235, 225, 205),
			Enum.Material.SmoothPlastic
		)
		blob(
			m,
			"MushCap",
			Vector3.new(1.0 * k, 0.5 * k, 1.0 * k),
			at * CFrame.new(0, 0.35 * k, 0.1 * k),
			Color3.fromRGB(200, 60, 55),
			Enum.Material.SmoothPlastic
		)
	end
	return b.H
end

-- Hydre des marais (boss régional) : corps écailleux sarcelle, ventre beige, trois têtes de
-- dragon cornues aux sacs de gorge lumineux, crêtes orange.
enemyBuilders.MarshHydra = function(m, base, k)
	local teal = Color3.fromRGB(35, 90, 100)
	local s = {
		L = 9 * k,
		Hb = 4.2 * k,
		W = 5 * k,
		LegH = 2.6 * k,
		Skin = teal,
		Belly = Color3.fromRGB(210, 190, 150),
		Eye = Color3.fromRGB(230, 255, 80),
		Teeth = true,
		Horns = Color3.fromRGB(200, 180, 140),
		Open = 25,
	}
	local body = quad(m, base, s)
	local fin = Color3.fromRGB(220, 150, 60)
	for i = 0, 5 do
		ep(
			m,
			"BackFin",
			Vector3.new(0.25 * k, (1.6 - math.abs(i - 2) * 0.2) * k, 1.2 * k),
			body * CFrame.new(0, 2.2 * k, (-2 + i * 0.9) * k),
			fin,
			Enum.Material.SmoothPlastic
		)
	end
	local rand = rng(9)
	for _ = 1, 26 do
		local a = rand() * math.pi - math.pi / 2
		local z = (rand() - 0.5) * 7 * k
		ep(
			m,
			"Scale",
			Vector3.new(0.9, 0.9, 0.12) * k,
			body
				* CFrame.new(math.sin(a) * 2.45 * k, math.cos(a) * 2.0 * k, z)
				* CFrame.Angles(0, math.pi / 2 * math.sign(a), 0)
				* CFrame.Angles(0, 0, math.rad(45)),
			teal:Lerp(Color3.new(0, 0, 0), rand() * 0.25),
			Enum.Material.Slate
		)
	end
	for i, angle in { -0.55, 0, 0.55 } do
		local neckBase = body * CFrame.new(angle * 2.6 * k, 1.2 * k, -3.6 * k)
		local neck = neckBase * CFrame.Angles(-0.6, -angle * 0.6, -angle * 0.5)
		blob(
			m,
			"Neck",
			Vector3.new(1.4 * k, 4.2 * k, 1.5 * k),
			neck * CFrame.new(0, 1.9 * k, 0),
			teal,
			Enum.Material.SmoothPlastic
		)
		local head = neck * CFrame.new(0, 4.0 * k, -0.4 * k) * CFrame.Angles(0.6, 0, 0)
		beastHead(m, head, (if i == 2 then 2.0 else 1.7) * k, s)
		glow(
			m,
			"ThroatSac",
			Vector3.new(1.0, 0.9, 1.0) * k,
			head * CFrame.new(0, -0.9 * k, -0.4 * k),
			Color3.fromRGB(180, 240, 60),
			Enum.PartType.Ball
		)
		ep(
			m,
			"HeadFin",
			Vector3.new(0.18 * k, 0.9 * k, 1.1 * k),
			head * CFrame.new(0, 0.6 * k, 0.3 * k),
			fin,
			Enum.Material.SmoothPlastic
		)
	end
	for t = 0, 4 do
		blob(
			m,
			"Tail",
			Vector3.new(2.2 - t * 0.4, 1.8 - t * 0.3, 2.2) * k,
			body * CFrame.new(0, (-0.6 - t * 0.2) * k, (4.5 + t * 1.6) * k),
			teal,
			Enum.Material.SmoothPlastic
		)
	end
	return 11 * k
end

-- Titan du givre (boss majeur) : géant de roche sombre couvert de cristaux de glace, barbe de
-- glace, noyau cobalt, gourdin de glace.
enemyBuilders.FrostTitan = function(m, base, k)
	local rock = Color3.fromRGB(60, 62, 72)
	local ice = Color3.fromRGB(160, 215, 245)
	local b = biped(m, base, {
		H = 17 * k,
		Bulk = 1.6,
		Head = 0.14,
		Skin = rock,
		Torso = rock,
		Pants = rock,
		Boots = rock:Lerp(Color3.new(0, 0, 0), 0.15),
		TorsoMat = Enum.Material.Slate,
		PantsMat = Enum.Material.Slate,
		BootsMat = Enum.Material.Slate,
		ArmsMat = Enum.Material.Slate,
		HandsMat = Enum.Material.Slate,
		Bracer = Color3.fromRGB(110, 80, 60),
	})
	local hs = b.HeadS
	ep(m, "Head", Vector3.new(hs * 0.9, hs, hs * 0.9), b.Head, rock, Enum.Material.Slate)
	eyesPair(m, b.Head, hs * 0.2, hs * 0.12, hs * 0.46, hs * 0.13, Color3.fromRGB(80, 160, 255))
	local function shard(cf: CFrame, w: number, h: number)
		ep(m, "Ice", Vector3.new(w, h, w), cf * CFrame.Angles(0, math.rad(45), 0), ice, Enum.Material.Ice)
	end
	-- Barbe et couronne de glace
	for i = -2, 2 do
		shard(
			b.Head * CFrame.new(i * hs * 0.17, -hs * 0.55, -hs * 0.35) * CFrame.Angles(0.3, 0, i * 0.15),
			hs * 0.18,
			hs * (0.9 - math.abs(i) * 0.15)
		)
		shard(
			b.Head * CFrame.new(i * hs * 0.17, hs * 0.55, 0) * CFrame.Angles(0, 0, i * 0.25),
			hs * 0.15,
			hs * (0.7 - math.abs(i) * 0.1)
		)
	end
	local core = glow(
		m,
		"Core",
		Vector3.new(b.TorsoW * 0.26, b.TorsoW * 0.26, 0.3),
		b.Chest * CFrame.new(0, b.TorsoH * 0.15, -0.15) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(40, 90, 255)
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(80, 140, 255)
	light.Range = 20
	light.Parent = core
	local rand = rng(23)
	for _, side in { -1, 1 } do
		local sh = if side < 0 then b.ShoulderL else b.ShoulderR
		for i = 0, 4 do
			shard(
				sh
					* CFrame.new(side * (rand() * b.TorsoW * 0.3), rand() * b.TorsoW * 0.3, (rand() - 0.5) * b.TorsoD)
					* CFrame.Angles(0, 0, -side * (0.3 + i * 0.15)),
				b.TorsoW * 0.18,
				b.TorsoW * (0.4 + rand() * 0.3)
			)
		end
		glow(
			m,
			"ElbowGem",
			Vector3.new(b.TorsoW * 0.15, b.TorsoW * 0.15, 0.1),
			sh
				* CFrame.new(side * b.TorsoW * 0.05, -b.TorsoH * 0.5, -b.TorsoW * 0.2)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color3.fromRGB(60, 120, 255)
		)
	end
	for i = 0, 5 do
		shard(
			b.Chest * CFrame.new((i - 2.5) * b.TorsoW * 0.18, -b.TorsoH * 0.55, -0.1) * CFrame.Angles(math.pi, 0, 0),
			b.TorsoW * 0.14,
			b.TorsoH * 0.35
		)
	end
	-- Gourdin de glace
	local club = b.HandR * CFrame.new(0, -b.H * 0.12, 0)
	ep(
		m,
		"ClubHandle",
		Vector3.new(b.TorsoW * 0.15, b.H * 0.25, b.TorsoW * 0.15),
		club,
		Color3.fromRGB(110, 80, 60),
		Enum.Material.Wood
	)
	shard(club * CFrame.new(0, -b.H * 0.2, 0), b.TorsoW * 0.5, b.H * 0.25)
	return b.H
end

-- Dragon de la fournaise (boss majeur) : écailles d'obsidienne veinées de lave, ailes orange,
-- cornes, queue à masse de pierre.
enemyBuilders.FurnaceDragon = function(m, base, k)
	k *= 1.35 -- boss majeur : plus massif que l'hydre
	local obsidian = Color3.fromRGB(55, 48, 60)
	local s = {
		L = 9 * k,
		Hb = 4.6 * k,
		W = 5 * k,
		LegH = 3 * k,
		Skin = obsidian,
		SkinMat = Enum.Material.Slate,
		Belly = Color3.fromRGB(185, 150, 100),
		Eye = Color3.fromRGB(255, 160, 40),
		Teeth = true,
		Horns = Color3.fromRGB(200, 170, 120),
		Open = 20,
	}
	local body = quad(m, base, s)
	local lava = Color3.fromRGB(255, 120, 30)
	local rand = rng(51)
	for _ = 1, 16 do
		local a = rand() * math.pi * 1.4 - math.pi * 0.7
		glow(
			m,
			"LavaVein",
			Vector3.new(0.12 * k, 0.12 * k, (0.8 + rand() * 1.4) * k),
			body
				* CFrame.new(math.sin(a) * 2.5 * k, math.cos(a) * 2.25 * k, (rand() - 0.5) * 7 * k)
				* CFrame.Angles(rand(), 0, rand()),
			lava
		)
	end
	for i = 0, 6 do
		ep(
			m,
			"Spike",
			Vector3.new(0.5 * k, (1.3 - math.abs(i - 3) * 0.15) * k, 0.5 * k),
			body * CFrame.new(0, 2.4 * k, (-3 + i) * k) * CFrame.Angles(0.4, math.rad(45), 0),
			obsidian:Lerp(Color3.new(0, 0, 0), 0.3),
			Enum.Material.Slate
		)
	end
	local neck = body * CFrame.new(0, 1.8 * k, -4.0 * k) * CFrame.Angles(-0.7, 0, 0)
	blob(
		m,
		"Neck",
		Vector3.new(2.2 * k, 4.0 * k, 2.4 * k),
		neck * CFrame.new(0, 1.6 * k, 0),
		obsidian,
		Enum.Material.Slate
	)
	beastHead(m, neck * CFrame.new(0, 3.6 * k, -0.6 * k) * CFrame.Angles(0.7, 0, 0), 2.6 * k, s)
	batWingsBig(m, body * CFrame.new(0, 2.2 * k, -0.8 * k), 8 * k, Color3.fromRGB(230, 110, 40), obsidian)
	for t = 0, 5 do
		blob(
			m,
			"Tail",
			Vector3.new(2.0 - t * 0.28, 1.7 - t * 0.22, 2.0) * k,
			body * CFrame.new(0, (-0.4 - t * 0.25) * k, (4.5 + t * 1.5) * k),
			obsidian,
			Enum.Material.Slate
		)
	end
	local club = body * CFrame.new(0, -1.9 * k, 13.8 * k)
	ep(m, "TailClub", Vector3.new(2.0, 1.8, 2.2) * k, club, Color3.fromRGB(120, 105, 100), Enum.Material.Slate)
	glow(
		m,
		"TailRune",
		Vector3.new(0.8, 0.8, 0.1) * k,
		club * CFrame.new(0, 0, -1.12 * k) * CFrame.Angles(0, 0, math.rad(45)),
		lava
	)
	return 14 * k
end

-- Colosse du néant (boss final) : armure violet sombre bordée d'or, épaulières en croissant,
-- noyau stellaire, pierres en lévitation, étoffe pourpre.
enemyBuilders.VoidColossus = function(m, base, k)
	local dark = Color3.fromRGB(55, 45, 70)
	local gold = Color3.fromRGB(190, 150, 80)
	local violet = Color3.fromRGB(190, 100, 255)
	local b = biped(m, base, {
		H = 20 * k,
		Bulk = 1.75,
		Head = 0.13,
		Skin = dark,
		Torso = dark,
		Pants = dark,
		Boots = dark:Lerp(Color3.new(0, 0, 0), 0.2),
		TorsoMat = Enum.Material.Metal,
		PantsMat = Enum.Material.Metal,
		BootsMat = Enum.Material.Metal,
		ArmsMat = Enum.Material.Metal,
		HandsMat = Enum.Material.Metal,
		Knee = gold,
		Bracer = gold,
	})
	local hs = b.HeadS
	ep(m, "Helm", Vector3.new(hs * 0.9, hs * 1.1, hs * 0.9), b.Head, dark, Enum.Material.Metal)
	ep(
		m,
		"HelmSpike",
		Vector3.new(hs * 0.3, hs * 0.6, hs * 0.3),
		b.Head * CFrame.new(0, hs * 0.7, 0) * CFrame.Angles(0, math.rad(45), 0),
		dark,
		Enum.Material.Metal
	)
	eyesPair(m, b.Head, hs * 0.18, hs * 0.1, hs * 0.46, hs * 0.14, violet)
	local core = glow(
		m,
		"StarCore",
		Vector3.new(b.TorsoW * 0.3, b.TorsoW * 0.3, 0.3),
		b.Chest * CFrame.new(0, b.TorsoH * 0.15, -0.15) * CFrame.Angles(0, 0, math.rad(45)),
		violet
	)
	glow(
		m,
		"StarRayV",
		Vector3.new(b.TorsoW * 0.06, b.TorsoW * 0.55, 0.32),
		b.Chest * CFrame.new(0, b.TorsoH * 0.15, -0.16),
		violet
	)
	glow(
		m,
		"StarRayH",
		Vector3.new(b.TorsoW * 0.55, b.TorsoW * 0.06, 0.32),
		b.Chest * CFrame.new(0, b.TorsoH * 0.15, -0.16),
		violet
	)
	local light = Instance.new("PointLight")
	light.Color = violet
	light.Range = 24
	light.Parent = core
	ep(
		m,
		"ChestTrim",
		Vector3.new(b.TorsoW * 1.04, b.TorsoH * 0.08, b.TorsoD * 1.05),
		b.Chest * CFrame.new(0, b.TorsoH * 0.45, b.TorsoD / 2),
		gold,
		Enum.Material.Metal
	)
	for _, side in { -1, 1 } do
		local sh = if side < 0 then b.ShoulderL else b.ShoulderR
		blob(
			m,
			"Pauldron",
			Vector3.new(b.TorsoW * 0.6, b.TorsoW * 0.45, b.TorsoD * 1.4),
			sh * CFrame.new(side * b.TorsoW * 0.1, b.TorsoW * 0.1, 0),
			dark,
			Enum.Material.Metal
		)
		-- Croissant : arc de blocs dorés au-dessus de l'épaule
		for i = 0, 6 do
			local a = math.rad(-20 + i * 25)
			ep(
				m,
				"Crescent",
				Vector3.new(b.TorsoW * 0.12, b.TorsoW * 0.22, b.TorsoW * 0.12),
				sh
					* CFrame.new(
						side * (b.TorsoW * 0.2 + math.cos(a) * b.TorsoW * 0.35),
						b.TorsoW * 0.2 + math.sin(a) * b.TorsoW * 0.45,
						0
					)
					* CFrame.Angles(0, 0, side * a),
				if i % 3 == 0 then gold else dark,
				Enum.Material.Metal
			)
		end
		glow(
			m,
			"ShoulderRune",
			Vector3.new(b.TorsoW * 0.14, b.TorsoW * 0.14, 0.06),
			sh
				* CFrame.new(side * b.TorsoW * 0.15, b.TorsoW * 0.1, -b.TorsoD * 0.72)
				* CFrame.Angles(0, 0, math.rad(45)),
			violet
		)
	end
	ep(
		m,
		"Tabard",
		Vector3.new(b.TorsoW * 0.45, b.LegH * 0.9, 0.12),
		base * CFrame.new(0, b.LegH * 0.55, -b.TorsoD / 2 - 0.1),
		Color3.fromRGB(110, 40, 140),
		Enum.Material.Fabric
	)
	local rand = rng(77)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		ep(
			m,
			"FloatingRock",
			Vector3.new(hs * 0.35, hs * 0.25, hs * 0.3),
			b.Head
				* CFrame.new(math.cos(a) * hs * 1.3, hs * (0.6 + rand() * 0.5), math.sin(a) * hs * 1.0)
				* CFrame.Angles(rand(), rand(), rand()),
			dark:Lerp(Color3.new(0, 0, 0), 0.2),
			Enum.Material.Slate
		)
	end
	return b.H
end

-- Ennemi complet. `kind` : entrée de Config/Street (Kinds ou Bosses). `patron` grossit un
-- ennemi ordinaire (chef de vague de la défense). Retourne le modèle et la pièce « Root » (au
-- centre, hauteur = taille de l'ennemi).
function Models.enemy(kind, base: CFrame, scale: number, patron: boolean): (Model, BasePart)
	local m = newModel(kind.Id)
	local k = (scale or 1) * (if patron and not kind.Boss then 1.4 else 1)
	local builder = enemyBuilders[kind.Id] or enemyBuilders.ScrapGoblin
	local height = builder(m, base, k)
	local width = math.max(2, height * 0.45)
	local root = part(m, "Root", Vector3.new(width, height, width), base * CFrame.new(0, height / 2, 0), C.Stone, nil, {
		Transparency = 1,
		CanCollide = false,
	})
	root.CanQuery = false
	if patron and not kind.Boss then
		glow(
			m,
			"ChiefAura",
			Vector3.new(0.2, height * 0.9, height * 0.9),
			base * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 70, 70),
			Enum.PartType.Cylinder
		).Transparency =
			0.6
	end
	-- Une seule pièce ancrée (Root) ; le reste y est soudé : déplacement en un bloc.
	m.PrimaryPart = root
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			p.CanCollide = false
			p.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
			p.Anchored = false
			p.Massless = true
		end
	end
	return m, root
end

-- Champ des champions ---------------------------------------------------------------------

-- Mannequin d'entraînement autonome (poteau, bras, corps, tête). Retourne le corps.
-- Pantin chevalier (planche du créateur) : mannequin de bois articulé (tête, torse, bassin,
-- bras et jambes en segments, rotules brun foncé) portant casque, plastron à gemme dorée,
-- épaulières, coudières, genouillères, ceinture à boucle, tabard bleu bordé d'argent, bottes,
-- épée et bouclier. Toutes les pièces sont soudées à une racine ancrée au pied : secouer la
-- racine fait osciller tout le pantin depuis son socle. `color` : couleur du tabard et du
-- bouclier (zone). Retourne la racine.
-- Pantins du créateur (Art/PuppetDesigns, transmis par Models.setPuppetDesigns) ------------------
local puppetDesigns: { [string]: any } = {}
function Models.setPuppetDesigns(designs)
	puppetDesigns = designs or {}
end

local PUPPET_SHAPES = { C = Enum.PartType.Cylinder }

-- Pantin d'après un design : pièces reproduites telles quelles (formes, tailles, positions,
-- rotations, couleurs, matériaux), soudées à une racine ancrée au pied (le pantin oscille d'un
-- bloc quand on le frappe). `base` au sol, -Z = face. Retourne la racine (nil si design inconnu).
function Models.puppet(kind: string, base: CFrame, parent: Instance): BasePart?
	local design = puppetDesigns[kind]
	if not design then
		return nil
	end
	local m = newModel("Pantin_" .. kind)
	m:SetAttribute("PuppetName", design.Name)
	for i, d in design.Parts do
		local size = Vector3.new(d[2], d[3], d[4])
		local cf = base * CFrame.new(d[5], d[6], d[7]) * CFrame.Angles(math.rad(d[8]), math.rad(d[9]), math.rad(d[10]))
		local color = Color3.fromRGB(bit32.rshift(d[11], 16) % 256, bit32.rshift(d[11], 8) % 256, d[11] % 256)
		local material = (Enum.Material :: any)[d[12]] or Enum.Material.SmoothPlastic
		local props = { CanCollide = false, NoShadow = math.max(d[2], d[3], d[4]) < 0.3 }
		if d[13] and d[13] > 0 then
			props.Transparency = d[13]
		end
		local shape = PUPPET_SHAPES[d[1]]
		local uniformBall = d[1] == "S" and d[2] == d[3] and d[3] == d[4]
		if shape then
			props.Shape = shape
		elseif uniformBall then
			props.Shape = Enum.PartType.Ball
		end
		local p = part(m, "Piece" .. i, size, cf, color, material, props)
		if d[1] == "S" and not uniformBall then
			-- Ellipsoïde : maillage sphère étiré à la taille de la pièce.
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
	end
	-- Socle discret (seule pièce solide) et racine invisible soudée à tout le reste.
	column(m, "Socle", 0.2, 2.6, base, C.StoneDark, Enum.Material.Slate)
	local root = part(m, "PantinRacine", Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(0, 0.2, 0), C.StoneDark, nil, {
		Transparency = 1,
		CanCollide = false,
	})
	root.CanQuery = false
	m.PrimaryPart = root
	for _, inst in m:GetDescendants() do
		if inst:IsA("BasePart") and inst ~= root then
			inst.CanCollide = inst.Name == "Socle"
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = inst
			weld.Parent = inst
			inst.Anchored = false
			inst.Massless = true
		end
	end
	m.Parent = parent
	return root
end

function Models.dummy(base: CFrame, parent: Instance, color: Color3): BasePart
	local m = newModel("PantinChevalier")
	m.Parent = parent
	local wood = Color3.fromRGB(214, 150, 78)
	local woodDark = Color3.fromRGB(192, 128, 62)
	local joint = Color3.fromRGB(110, 68, 42)
	local steel = Color3.fromRGB(176, 180, 190)
	local steelDark = Color3.fromRGB(132, 136, 148)
	local leather = Color3.fromRGB(110, 70, 44)
	local boot = Color3.fromRGB(116, 74, 48)
	local W, M = Enum.Material.Wood, Enum.Material.Metal
	local function p(name, size, cf, col, mat, props)
		return part(m, name, size, base * cf, col, mat or Enum.Material.SmoothPlastic, props)
	end
	local function b(name, d, cf, col, mat)
		return ball(m, name, d, base * cf, col, mat or Enum.Material.SmoothPlastic)
	end
	local function cyl(name, h, d, cf, col, mat)
		return column(m, name, h, d, base * cf, col, mat or Enum.Material.SmoothPlastic)
	end

	-- Socle rond
	cyl("Socle", 0.3, 2.8, CFrame.new(0, 0, 0), C.WoodDark, W)
	cyl("SocleBord", 0.12, 3.0, CFrame.new(0, 0.05, 0), joint, W)

	-- Jambes : botte, cheville, tibia, genou (genouillère), cuisse, hanche
	for _, side in { -1, 1 } do
		local x = side * 0.42
		p("Botte", Vector3.new(0.72, 0.55, 1.0), CFrame.new(x, 0.58, -0.12), boot, Enum.Material.Fabric)
		p(
			"BotteTige",
			Vector3.new(0.7, 0.35, 0.7),
			CFrame.new(x, 0.98, 0.02),
			boot:Lerp(Color3.new(0, 0, 0), 0.1),
			Enum.Material.Fabric
		)
		cyl("Cheville", 0.16, 0.42, CFrame.new(x, 1.15, 0.02), joint, W)
		p("Tibia", Vector3.new(0.52, 0.95, 0.56), CFrame.new(x, 1.78, 0.02), wood, W)
		p(
			"TibiaBiseau",
			Vector3.new(0.4, 0.95, 0.6),
			CFrame.new(x, 1.78, 0.02) * CFrame.Angles(0, math.rad(45), 0),
			woodDark,
			W
		)
		b("Genou", 0.46, CFrame.new(x, 2.36, 0.02), joint, W)
		p(
			"Genouillere",
			Vector3.new(0.56, 0.48, 0.3),
			CFrame.new(x, 2.38, -0.26) * CFrame.Angles(math.rad(-8), 0, 0),
			steel,
			M
		)
		p("Cuisse", Vector3.new(0.6, 1.05, 0.64), CFrame.new(x, 3.0, 0.02), wood, W)
		b("Hanche", 0.42, CFrame.new(x, 3.58, 0.02), joint, W)
	end

	-- Bassin, ceinture, tabard et faltes
	p("Bassin", Vector3.new(1.45, 0.55, 0.82), CFrame.new(0, 3.82, 0.02), wood, W)
	p("Ceinture", Vector3.new(1.56, 0.24, 0.94), CFrame.new(0, 4.05, 0.02), leather, Enum.Material.Fabric)
	p("Boucle", Vector3.new(0.34, 0.26, 0.08), CFrame.new(0, 4.05, -0.5), GOLD, M)
	p("BoucleCentre", Vector3.new(0.16, 0.12, 0.1), CFrame.new(0, 4.05, -0.52), leather, Enum.Material.Fabric)
	p("Tabard", Vector3.new(0.78, 1.15, 0.08), CFrame.new(0, 3.38, -0.48), color, Enum.Material.Fabric)
	p(
		"TabardPointe",
		Vector3.new(0.55, 0.55, 0.08),
		CFrame.new(0, 2.8, -0.48) * CFrame.Angles(0, 0, math.rad(45)),
		color,
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		p("TabardBord", Vector3.new(0.07, 1.2, 0.1), CFrame.new(side * 0.41, 3.36, -0.49), steel, M)
		p(
			"Falte",
			Vector3.new(0.5, 0.55, 0.86),
			CFrame.new(side * 0.62, 3.72, 0.02) * CFrame.Angles(0, 0, side * math.rad(12)),
			steelDark,
			M
		)
	end

	-- Torse et plastron
	p("Torse", Vector3.new(1.5, 1.45, 0.86), CFrame.new(0, 4.92, 0.02), wood, W)
	p("TorseHaut", Vector3.new(1.75, 0.55, 0.9), CFrame.new(0, 5.42, 0.02), wood, W)
	p("Plastron", Vector3.new(1.62, 1.25, 0.14), CFrame.new(0, 5.0, -0.46), steel, M)
	p("PlastronHaut", Vector3.new(1.8, 0.4, 0.16), CFrame.new(0, 5.5, -0.46), steel, M)
	p("Dossiere", Vector3.new(1.62, 1.4, 0.14), CFrame.new(0, 5.05, 0.5), steelDark, M)
	p(
		"GemmePlastron",
		Vector3.new(0.26, 0.26, 0.1),
		CFrame.new(0, 5.12, -0.55) * CFrame.Angles(0, 0, math.rad(45)),
		GOLD,
		Enum.Material.Neon,
		{ NoShadow = true }
	)

	-- Cou, tête et casque
	cyl("Cou", 0.28, 0.38, CFrame.new(0, 5.7, 0.02), joint, W)
	p("Tete", Vector3.new(0.78, 0.8, 0.78), CFrame.new(0, 6.32, 0.02), wood, W)
	p("Casque", Vector3.new(0.92, 0.84, 0.92), CFrame.new(0, 6.34, 0.02), steel, M)
	for _, side in { -1, 1 } do
		p(
			"CasqueJoue",
			Vector3.new(0.12, 0.6, 0.7),
			CFrame.new(side * 0.5, 6.25, -0.05) * CFrame.Angles(0, side * math.rad(-12), 0),
			steelDark,
			M
		)
	end
	p(
		"CasqueSommet",
		Vector3.new(0.62, 0.32, 0.62),
		CFrame.new(0, 6.86, 0.02) * CFrame.Angles(0, math.rad(45), 0),
		steelDark,
		M
	)
	p("CasqueCrete", Vector3.new(0.12, 0.2, 0.8), CFrame.new(0, 7.05, 0.02), steel, M)
	p(
		"Visiere",
		Vector3.new(0.66, 0.14, 0.06),
		CFrame.new(0, 6.42, -0.48),
		Color3.fromRGB(28, 26, 30),
		Enum.Material.SmoothPlastic
	)
	p("Ventail", Vector3.new(0.78, 0.3, 0.1), CFrame.new(0, 6.12, -0.49), steelDark, M)

	-- Bras : épaule, épaulière, bras, coude (coudière), avant-bras, main
	local hands = {}
	for _, side in { -1, 1 } do
		local shoulder = CFrame.new(side * 1.02, 5.38, 0.02) * CFrame.Angles(0, 0, side * math.rad(10))
		b("Epaule", 0.42, shoulder, joint, W)
		local pauldron = p(
			"Epauliere",
			Vector3.new(0.85, 0.5, 0.95),
			shoulder * CFrame.new(side * 0.05, 0.18, 0),
			steel,
			M,
			{ Class = "Part" }
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = pauldron
		p("Bras", Vector3.new(0.42, 0.8, 0.44), shoulder * CFrame.new(0, -0.55, 0), wood, W)
		local elbow = shoulder * CFrame.new(0, -1.05, 0)
		b("Coude", 0.36, elbow, joint, W)
		p("Coudiere", Vector3.new(0.4, 0.34, 0.24), elbow * CFrame.new(0, 0, 0.18), steelDark, M)
		p("AvantBras", Vector3.new(0.4, 0.75, 0.42), elbow * CFrame.new(0, -0.48, 0), wood, W)
		local hand = elbow * CFrame.new(0, -1.0, 0)
		p("Main", Vector3.new(0.42, 0.42, 0.46), hand, wood, W)
		hands[side] = hand
	end

	-- Épée (main droite), lame vers le bas en avant
	local grip = hands[1] * CFrame.Angles(math.rad(-35), 0, 0)
	p("Poignee", Vector3.new(0.14, 0.5, 0.14), grip, leather, Enum.Material.Fabric)
	p("Pommeau", Vector3.new(0.2, 0.2, 0.2), grip * CFrame.new(0, 0.32, 0) * CFrame.Angles(0, math.rad(45), 0), GOLD, M)
	p("Garde", Vector3.new(0.75, 0.14, 0.16), grip * CFrame.new(0, -0.28, 0), GOLD, M)
	p("Lame", Vector3.new(0.2, 1.9, 0.06), grip * CFrame.new(0, -1.3, 0), Color3.fromRGB(205, 208, 215), M)
	p(
		"LamePointe",
		Vector3.new(0.14, 0.14, 0.06),
		grip * CFrame.new(0, -2.25, 0) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(205, 208, 215),
		M
	)

	-- Bouclier en écu (bras gauche) : bord d'argent, champ coloré, pointe
	-- Tenu de face, légèrement tourné vers l'extérieur (comme sur la planche).
	local shieldCf = hands[-1] * CFrame.new(-0.05, 0.55, -0.42) * CFrame.Angles(0, math.rad(25), 0)
	p("BouclierBord", Vector3.new(1.2, 1.25, 0.12), shieldCf, steel, M)
	p(
		"BouclierPointeBord",
		Vector3.new(0.86, 0.86, 0.12),
		shieldCf * CFrame.new(0, -0.62, 0) * CFrame.Angles(0, 0, math.rad(45)),
		steel,
		M
	)
	p(
		"BouclierChamp",
		Vector3.new(0.98, 1.08, 0.16),
		shieldCf * CFrame.new(0, 0.02, 0),
		color,
		Enum.Material.SmoothPlastic
	)
	p(
		"BouclierPointe",
		Vector3.new(0.68, 0.68, 0.16),
		shieldCf * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(45)),
		color,
		Enum.Material.SmoothPlastic
	)

	-- Racine ancrée au pied ; tout le reste y est soudé (le pantin oscille d'un bloc).
	local root = part(m, "PantinRacine", Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(0, 0.2, 0), joint, nil, {
		Transparency = 1,
		CanCollide = false,
	})
	root.CanQuery = false
	m.PrimaryPart = root
	for _, inst in m:GetDescendants() do
		if inst:IsA("BasePart") and inst ~= root then
			inst.CanCollide = inst.Name == "Socle"
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = inst
			weld.Parent = inst
			inst.Anchored = false
			inst.Massless = true
		end
	end
	return root
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
			local spot = center * CFrame.new(d * 6, 0.2, -5) * CFrame.Angles(0, math.pi, 0) -- face aux joueurs
			local body = zone.Puppet and Models.puppet(zone.Puppet, spot, parent)
				or Models.dummy(
					spot,
					parent,
					if zone.Royal
						then Color3.fromRGB(212, 160, 50)
						else Color3.fromRGB(46, 84, 170):Lerp(C.Cloth, (i % 3) * 0.35)
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

-- Kit de détails ------------------------------------------------------------------------
-- Ajoute du relief aux grandes surfaces (pierres saillantes, corbeaux, lierre, mousse) et
-- des accessoires (tonneaux, caisses, étals). Tout est déterministe (même rendu à chaque
-- génération) grâce à un générateur pseudo-aléatoire initialisé par une graine.

local LEAF_IVY = { Color3.fromRGB(58, 112, 52), Color3.fromRGB(74, 132, 60), Color3.fromRGB(46, 96, 48) }
local MOSS = Color3.fromRGB(92, 120, 64)

-- Pierres saillantes sur une face de mur. `frame` : repère du mur (X le long du mur, Y vers le
-- haut, Z épaisseur) ; `faceZ` : position de la face ; `dir` : -1 ou 1 (côté de la face).
local function stoneFace(
	parent,
	frame: CFrame,
	length: number,
	y0: number,
	y1: number,
	faceZ: number,
	dir: number,
	seed: number,
	density: number?,
	bands: { number }?
)
	-- Pierres disposées en rangées SANS chevauchement (sinon leurs faces scintillent), avec une
	-- profondeur légèrement différente d'une pierre à l'autre ; les rangées qui croisent un
	-- bandeau (cordon, bague de tour) sont sautées.
	local rand = rng(seed)
	local rowH, gap = 0.95, 0.14
	local y = y0 + 0.25
	local index = 0
	while y + rowH <= y1 - 0.2 do
		local blocked = false
		for _, band in bands or {} do
			if math.abs(y + rowH / 2 - band) < rowH / 2 + 0.45 then
				blocked = true
			end
		end
		if not blocked then
			local x = -length / 2 + 0.3 + rand() * 0.8
			while x < length / 2 - 0.5 do
				local w = 1.1 + rand() * 1.3
				if x + w > length / 2 - 0.3 then
					break
				end
				if rand() < 0.42 * (density or 1) then
					index += 1
					local h = rowH * (0.75 + rand() * 0.2)
					local tint = rand()
					local color = if tint < 0.3
						then WALL_STONE:Lerp(WALL_DARK, 0.15 + rand() * 0.25)
						elseif tint < 0.85 then WALL_STONE:Lerp(WALL_LIGHT, 0.3 + rand() * 0.6)
						else WALL_STONE:Lerp(Color3.fromRGB(176, 160, 132), 0.5)
					local depth = 0.2 + (index % 3) * 0.04
					part(
						parent,
						"Stone",
						Vector3.new(w, h, depth),
						frame * CFrame.new(x + w / 2, y + rowH / 2, faceZ + dir * (depth / 2 - 0.04)),
						color,
						if rand() < 0.5 then Enum.Material.Cobblestone else Enum.Material.Slate,
						{ CanCollide = false, NoShadow = true }
					)
				end
				x += w + gap
			end
		end
		y += rowH + gap
	end
end
Models.stoneFace = stoneFace

-- Rangée de corbeaux (consoles) sous un chemin de ronde ou un parapet.
local function corbels(parent, frame: CFrame, length: number, y: number, faceZ: number, dir: number)
	local count = math.floor(length / 2.4)
	for k = 0, count - 1 do
		local x = -length / 2 + (k + 0.5) * (length / count)
		part(
			parent,
			"Corbel",
			Vector3.new(0.8, 1.1, 0.9),
			frame * CFrame.new(x, y - 0.55, faceZ + dir * 0.4),
			WALL_DARK,
			Enum.Material.Slate,
			{ NoShadow = true }
		)
		part(
			parent,
			"CorbelTip",
			Vector3.new(0.6, 0.5, 0.5),
			frame * CFrame.new(x, y - 1.3, faceZ + dir * 0.3),
			WALL_DARK,
			Enum.Material.Slate,
			{ NoShadow = true }
		)
	end
end

-- Lierre grimpant : tige qui monte en zigzag, touffes de feuilles de trois teintes.
local function ivy(parent, frame: CFrame, x: number, faceZ: number, dir: number, height: number, seed: number)
	local rand = rng(seed)
	local px, py = x, 0.5
	while py < height do
		local nx = px + (rand() - 0.5) * 2.4
		local ny = py + 1 + rand() * 0.8
		for k = 1, 2 do
			local spread = 0.6 + rand() * 1.2
			ball(
				parent,
				"Ivy",
				0.7 + rand() * 0.7,
				frame
					* CFrame.new(
						px + (rand() - 0.5) * spread * 2,
						py + rand() * 0.8,
						faceZ + dir * (0.25 + rand() * 0.2)
					),
				LEAF_IVY[(k + math.floor(rand() * 3)) % 3 + 1],
				Enum.Material.Grass,
				{ CanCollide = false, NoShadow = true }
			)
		end
		px, py = nx, ny
	end
end
Models.ivy = ivy

-- Bande de mousse et touffes d'herbe au pied d'un mur.
local function wallFoot(parent, frame: CFrame, length: number, faceZ: number, dir: number, seed: number, baseY: number?)
	local y0 = baseY or 0
	local rand = rng(seed)
	-- Plaques de mousse côte à côte sans chevauchement (sinon scintillement).
	local cursor = -length / 2 + 0.3
	local n = 0
	while cursor < length / 2 - 1.8 do
		n += 1
		local w = math.min(1.5 + rand() * 2.5, length / 2 - 0.3 - cursor)
		local x = cursor + w / 2
		cursor += w + 1 + rand() * 4
		part(
			parent,
			"Moss",
			Vector3.new(w, 0.5 + rand() * 0.6, 0.25),
			frame * CFrame.new(x, y0 + 0.4, faceZ + dir * (0.12 + (n % 4) * 0.07)),
			MOSS:Lerp(LEAF_IVY[1], rand() * 0.5),
			Enum.Material.Grass,
			{ CanCollide = false, NoShadow = true }
		)
		if rand() < 0.6 then
			for j = 0, 2 do
				part(
					parent,
					"Tuft",
					Vector3.new(0.18, 0.7 + rand() * 0.5, 0.18),
					frame
						* CFrame.new(x + (rand() - 0.5) * 1.5, y0 + 0.35, faceZ + dir * (0.6 + rand() * 0.5))
						* CFrame.Angles(math.rad((rand() - 0.5) * 30), j * 2, math.rad((rand() - 0.5) * 30)),
					LEAF_IVY[j % 3 + 1]:Lerp(C.Leaf3, 0.3),
					Enum.Material.Grass,
					{ CanCollide = false, NoShadow = true }
				)
			end
		end
	end
end

-- Accessoires ------------------------------------------------------------------------------

function Models.barrel(parent, base: CFrame, color: Color3?)
	local decor = Models.decor("07_Tonneau", base, { Scale = 0.65 })
	if decor then
		decor.Parent = parent
		return
	end
	local wood = color or C.Wood
	column(parent, "Barrel", 2.4, 1.9, base, wood, Enum.Material.WoodPlanks)
	column(
		parent,
		"BarrelBelly",
		1.2,
		2.1,
		base * CFrame.new(0, 0.6, 0),
		wood:Lerp(C.WoodDark, 0.15),
		Enum.Material.WoodPlanks
	)
	for _, y in { 0.35, 1.95 } do
		column(
			parent,
			"Hoop",
			0.18,
			2.02,
			base * CFrame.new(0, y, 0),
			C.Metal:Lerp(C.StoneDark, 0.4),
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	column(
		parent,
		"Lid",
		0.08,
		1.7,
		base * CFrame.new(0, 2.4, 0),
		wood:Lerp(C.WoodLight, 0.3),
		Enum.Material.Wood,
		{ NoShadow = true }
	)
end

function Models.crate(parent, base: CFrame, size: number)
	local decor = Models.decor("06_Caisse", base, { Scale = size / 3 })
	if decor then
		decor.Parent = parent
		return
	end
	-- Arêtes et cerclages légèrement en saillie (aucune face au même niveau que la caisse).
	part(
		parent,
		"Crate",
		Vector3.new(size, size, size),
		base * CFrame.new(0, size / 2, 0),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				parent,
				"CrateEdge",
				Vector3.new(0.3, size + 0.08, 0.3),
				base * CFrame.new(sx * (size / 2 - 0.08), size / 2, sz * (size / 2 - 0.08)),
				C.WoodDark,
				Enum.Material.Wood,
				{ NoShadow = true }
			)
		end
	end
	for _, y in { 0.25, size - 0.25 } do
		part(
			parent,
			"CrateBand",
			Vector3.new(size + 0.26, 0.2, size + 0.26),
			base * CFrame.new(0, y, 0),
			C.WoodDark,
			Enum.Material.Wood,
			{ NoShadow = true }
		)
	end
	part(
		parent,
		"CrateBrace",
		Vector3.new(0.22, size * 1.3, 0.1),
		base * CFrame.new(0, size / 2, -size / 2 - 0.2) * CFrame.Angles(0, 0, math.rad(45)),
		C.WoodDark,
		Enum.Material.Wood,
		{ NoShadow = true }
	)
end

function Models.sack(parent, base: CFrame, rand)
	local tint = Color3.fromRGB(196, 172, 128):Lerp(Color3.fromRGB(170, 145, 105), rand())
	ball(parent, "Sack", 1.5, base * CFrame.new(0, 0.6, 0), tint, Enum.Material.Fabric)
	part(
		parent,
		"SackTop",
		Vector3.new(0.6, 0.6, 0.6),
		base * CFrame.new(0, 1.4, 0),
		tint:Lerp(C.WoodDark, 0.2),
		Enum.Material.Fabric
	)
end

-- Étal de marché : comptoir, poteaux, auvent rayé, marchandises.
function Models.marketStall(parent, base: CFrame, stripe: Color3, seed: number)
	local rand = rng(seed)
	part(parent, "Counter", Vector3.new(6, 1.6, 2.2), base * CFrame.new(0, 0.8, 0), C.Wood, Enum.Material.WoodPlanks)
	part(
		parent,
		"CounterTop",
		Vector3.new(6.4, 0.25, 2.6),
		base * CFrame.new(0, 1.7, 0),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			column(
				parent,
				"StallPost",
				4.6,
				0.35,
				base * CFrame.new(sx * 3, 0, sz * 1.3 + 0.6),
				C.WoodDark,
				Enum.Material.Wood
			)
		end
	end
	for k = 0, 5 do
		part(
			parent,
			"Awning",
			Vector3.new(1.08, 0.15, 3.6),
			base * CFrame.new(-2.7 + k * 1.08, 4.75, 0.6) * CFrame.Angles(math.rad(-14), 0, 0),
			if k % 2 == 0 then stripe else Color3.fromRGB(238, 230, 210),
			Enum.Material.Fabric,
			{ NoShadow = false }
		)
	end
	-- Marchandises : pommes, pains, fioles
	for k = 0, 6 do
		local good = rand()
		local at = base * CFrame.new(-2.6 + k * 0.85, 2.05, -0.4 + rand() * 0.6)
		if good < 0.4 then
			ball(
				parent,
				"Apple",
				0.5,
				at,
				Color3.fromRGB(200, 50, 40),
				Enum.Material.SmoothPlastic,
				{ NoShadow = true }
			)
		elseif good < 0.7 then
			part(
				parent,
				"Bread",
				Vector3.new(0.7, 0.35, 0.4),
				at,
				Color3.fromRGB(200, 150, 80),
				Enum.Material.SmoothPlastic,
				{ NoShadow = true }
			)
		else
			column(
				parent,
				"Vial",
				0.6,
				0.3,
				at * CFrame.new(0, -0.15, 0),
				C.RuneBlue:Lerp(C.Ether, rand()),
				Enum.Material.Neon,
				{ NoShadow = true, CanCollide = false }
			)
		end
	end
	Models.crate(parent, base * CFrame.new(3.8, 0, -0.6), 1.4)
	Models.barrel(parent, base * CFrame.new(-4, 0, 0.2))
end

-- Râtelier d'armes : lances, boucliers ronds.
function Models.weaponRack(parent, base: CFrame)
	for _, sx in { -1, 1 } do
		part(
			parent,
			"RackPost",
			Vector3.new(0.35, 2.8, 0.35),
			base * CFrame.new(sx * 1.8, 1.4, 0),
			C.WoodDark,
			Enum.Material.Wood
		)
	end
	part(parent, "RackBar", Vector3.new(4, 0.3, 0.3), base * CFrame.new(0, 2.4, 0), C.WoodDark, Enum.Material.Wood)
	for k = 0, 3 do
		local x = -1.3 + k * 0.85
		part(
			parent,
			"Spear",
			Vector3.new(0.15, 4, 0.15),
			base * CFrame.new(x, 2, 0.2) * CFrame.Angles(math.rad(-8), 0, 0),
			C.Wood,
			Enum.Material.Wood,
			{ NoShadow = true }
		)
		part(
			parent,
			"SpearTip",
			Vector3.new(0.3, 0.6, 0.12),
			base * CFrame.new(x, 4.1, -0.1),
			C.Metal,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	for _, sx in { -1, 1 } do
		part(
			parent,
			"Shield",
			Vector3.new(0.2, 1.6, 1.6),
			base * CFrame.new(sx * 2.4, 1, 0.3) * CFrame.Angles(0, math.rad(90), 0),
			if sx < 0 then Color3.fromRGB(40, 70, 150) else C.Cloth,
			Enum.Material.Wood,
			{ Shape = Enum.PartType.Cylinder }
		)
		part(
			parent,
			"ShieldBoss",
			Vector3.new(0.3, 0.5, 0.5),
			base * CFrame.new(sx * 2.4, 1, 0.2) * CFrame.Angles(0, math.rad(90), 0),
			GOLD,
			Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder, NoShadow = true }
		)
	end
end

-- Botte de foin.
function Models.hayBale(parent, base: CFrame)
	part(parent, "Hay", Vector3.new(2.6, 1.4, 1.6), base * CFrame.new(0, 0.7, 0), C.Straw, Enum.Material.Grass)
	for _, x in { -0.7, 0.7 } do
		part(
			parent,
			"HayTie",
			Vector3.new(0.15, 1.45, 1.65),
			base * CFrame.new(x, 0.7, 0),
			C.Straw:Lerp(C.WoodDark, 0.4),
			Enum.Material.Fabric,
			{ NoShadow = true }
		)
	end
end

-- Jardinière fleurie.
function Models.planter(parent, base: CFrame, seed: number)
	local rand = rng(seed)
	part(parent, "Planter", Vector3.new(3, 1, 1.4), base * CFrame.new(0, 0.5, 0), WALL_DARK, Enum.Material.Cobblestone)
	part(
		parent,
		"Soil",
		Vector3.new(2.7, 0.1, 1.1),
		base * CFrame.new(0, 1.02, 0),
		Color3.fromRGB(90, 66, 44),
		Enum.Material.Ground,
		{ NoShadow = true }
	)
	local flowers = {
		Color3.fromRGB(230, 80, 90),
		Color3.fromRGB(250, 210, 80),
		Color3.fromRGB(150, 110, 230),
		Color3.fromRGB(245, 245, 245),
	}
	for k = 0, 5 do
		local at = base * CFrame.new(-1.1 + k * 0.45, 1.2, (rand() - 0.5) * 0.6)
		ball(
			parent,
			"Leaves",
			0.6,
			at,
			LEAF_IVY[k % 3 + 1],
			Enum.Material.Grass,
			{ NoShadow = true, CanCollide = false }
		)
		ball(
			parent,
			"Flower",
			0.32,
			at * CFrame.new(0, 0.35, 0),
			flowers[k % 4 + 1],
			Enum.Material.SmoothPlastic,
			{ NoShadow = true, CanCollide = false }
		)
	end
end

-- Dalles de couleurs variées posées sur un sol (casse l'aspect uniforme).
local function pavingPatches(parent, center: CFrame, radius: number, count: number, avoid, seed: number)
	-- Dalles sans chevauchement (sinon scintillement), hors des allées et du cercle central,
	-- à trois hauteurs légèrement différentes.
	local rand = rng(seed)
	local placed = {}
	local index = 0
	for _ = 1, count do
		local r = 12 + math.sqrt(rand()) * (radius - 12)
		local a = rand() * math.pi * 2
		local x, z = math.cos(a) * r, math.sin(a) * r
		local w, d = 1.4 + rand() * 1.4, 1.2 + rand() * 1.0
		local blocked = math.abs(x) < 5.2 or math.abs(z) < 5.2 -- allées en croix
		for _, zone in avoid do
			if (x - zone[1]) ^ 2 + (z - zone[2]) ^ 2 < zone[3] ^ 2 then
				blocked = true
				break
			end
		end
		if not blocked then
			for _, q in placed do
				if (x - q[1]) ^ 2 + (z - q[2]) ^ 2 < (q[3] + math.max(w, d) / 2 + 0.3) ^ 2 then
					blocked = true
					break
				end
			end
		end
		if not blocked then
			index += 1
			table.insert(placed, { x, z, math.max(w, d) / 2 })
			part(
				parent,
				"Slab",
				Vector3.new(w, 0.06 + (index % 3) * 0.02, d),
				center
					* CFrame.new(x, 0.03 + (index % 3) * 0.01, z)
					* CFrame.Angles(0, math.floor(rand() * 4) * math.pi / 2 + (rand() - 0.5) * 0.2, 0),
				PAVING:Lerp(if rand() < 0.3 then WALL_DARK else WALL_LIGHT, 0.15 + rand() * 0.35),
				Enum.Material.Slate,
				{ CanCollide = false, NoShadow = true }
			)
		end
	end
end
local ROYAL_BLUE = Color3.fromRGB(40, 70, 150)

-- Tour ronde crénelée à toit conique (étages) et drapeau facultatif. `base` au sol.
local function roundTower(parent, base: CFrame, d: number, h: number, flag: boolean)
	column(parent, "TowerBase", 1.5, d + 1.4, base, WALL_DARK, Enum.Material.Cobblestone)
	column(parent, "Tower", h, d, base, WALL_STONE, Enum.Material.Cobblestone)
	column(parent, "TowerBand", 0.8, d + 0.6, base * CFrame.new(0, h * 0.55, 0), WALL_LIGHT, Enum.Material.Slate)
	column(parent, "TowerTop", 1.2, d + 1.6, base * CFrame.new(0, h, 0), WALL_LIGHT, Enum.Material.Slate)
	-- Relief : pierres saillantes réparties sur le fût, couronne de corbeaux sous le chemin
	-- de ronde, mousse au pied.
	local rand = rng(math.floor(base.Position.X * 5.7 + base.Position.Z * 3.3))
	-- Pierres en rangées autour du fût, sans chevauchement, hors de la bague centrale.
	local perimeter = math.pi * d
	local rowY = 1.9
	local stoneIndex = 0
	while rowY + 0.9 < h - 1.4 do
		if math.abs(rowY + 0.45 - h * 0.55) > 1.0 then
			local around = rand() * 1.5
			while around < perimeter - 1.6 do
				local w = 1.0 + rand() * 0.9
				if rand() < 0.38 then
					stoneIndex += 1
					local a = (around + w / 2) / perimeter * math.pi * 2
					local depth = 0.22 + (stoneIndex % 3) * 0.04
					part(
						parent,
						"TowerStone",
						Vector3.new(w, 0.75 + rand() * 0.15, depth),
						base * CFrame.Angles(0, -a, 0) * CFrame.new(0, rowY + 0.45, d / 2 + depth / 2 - 0.08),
						WALL_STONE:Lerp(if rand() < 0.3 then WALL_DARK else WALL_LIGHT, 0.2 + rand() * 0.4),
						Enum.Material.Cobblestone,
						{ CanCollide = false, NoShadow = true }
					)
				end
				around += w + 0.25
			end
		end
		rowY += 1.05
	end
	for n = 1, 6 do
		local a = rand() * math.pi * 2
		part(
			parent,
			"TowerMoss",
			Vector3.new(1.5 + rand() * 2, 0.6 + rand() * 0.6, 0.3),
			base * CFrame.Angles(0, -a, 0) * CFrame.new(0, 1.6 + n * 0.02, d / 2 + 0.7 + (n % 3) * 0.05),
			MOSS,
			Enum.Material.Grass,
			{ CanCollide = false, NoShadow = true }
		)
	end
	for k = 1, 14 do
		local a = (k / 14) * math.pi * 2
		part(
			parent,
			"TowerCorbel",
			Vector3.new(0.9, 1.2, 0.9),
			base * CFrame.Angles(0, -a, 0) * CFrame.new(0, h - 0.6, d / 2 + 0.35),
			WALL_DARK,
			Enum.Material.Slate,
			{ NoShadow = true }
		)
	end
	local merlons = 10
	for k = 1, merlons do
		local a = (k / merlons) * math.pi * 2
		part(
			parent,
			"TowerMerlon",
			Vector3.new(math.min(1.6, math.pi * (d + 0.8) / merlons * 0.55), 1.6 + (k % 2) * 0.12, 1.2),
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
		Vector3.new(length + 0.4, 1.2, t + 1.2),
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
		Vector3.new(length + 0.2, 0.6, t + 0.6),
		frame * CFrame.new(0, h + 0.3, 0),
		WALL_LIGHT,
		Enum.Material.Slate
	)
	part(
		parent,
		"StringCourse",
		Vector3.new(length - 0.3, 0.5, t + 0.4),
		frame * CFrame.new(0, h * 0.6, 0),
		WALL_LIGHT,
		Enum.Material.Slate
	)
	-- Relief : pierres saillantes sur les deux faces, corbeaux sous le parapet extérieur,
	-- mousse et herbes au pied, lierre sur certains pans côté cour.
	local seed = math.floor(frame.Position.X * 3.1 + frame.Position.Z * 7.3 + length)
	stoneFace(parent, frame, length, 1.2, h - 0.2, -t / 2, -1, seed, 1, { h * 0.6 })
	-- Côté extérieur : pas de pierres sous les corbeaux.
	stoneFace(parent, frame, length, 1.2, h - 1.4, t / 2, 1, seed + 17, 0.8, { h * 0.6 })
	corbels(parent, frame, length, h + 0.05, t / 2, 1)
	-- Mousse posée sur le débord du soubassement (sinon cachée dedans).
	wallFoot(parent, frame, length, -t / 2 - 0.6, -1, seed + 3, 1.2)
	wallFoot(parent, frame, length, t / 2 + 0.6, 1, seed + 5, 1.2)
	if seed % 3 == 0 then
		ivy(parent, frame, length * 0.35, -t / 2, -1, h * 0.8, seed + 9)
	end
	ivy(parent, frame, -length * 0.3, t / 2, 1, h * 0.6, seed + 11)
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
		local banner = frame * CFrame.new(length * 0.2, h * 0.58, -t / 2 - 0.45)
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
		local hinge = frame * CFrame.new(side * (w / 2 - 0.4), 0, -depth / 2 - 0.35) -- hors du pilier
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
		frame * CFrame.new(0, h - 3.2, 0.25),
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
				Vector3.new(2.4, 3.6, 0.34),
				win * CFrame.new(0, 0, 0.12),
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

	-- Vie de la cour : dalles variées, étals de marché, tonneaux, caisses, râteliers, foin et
	-- jardinières, le long des remparts entre les allées (hors portails, œufs et portes).
	local dressing = Instance.new("Folder")
	dressing.Name = "CourtyardDressing"
	dressing.Parent = parent
	local floorTop = CFrame.new(0, 1, 0)
	pavingPatches(dressing, floorTop, A - 4, 170, {
		{ 0, 0, 8 }, -- estrade du point d'apparition
		{ -18.5, 28.5, 7 },
		{ -6.5, 33.4, 7 },
		{ 6.5, 33.4, 7 },
		{ 18.5, 28.5, 7 },
	}, 42)
	local function at(deg: number, r: number): CFrame
		local a = math.rad(deg)
		return CFrame.lookAt(Vector3.new(math.cos(a) * r, 1, math.sin(a) * r), Vector3.new(0, 1, 0))
	end
	local rand = rng(77)
	-- Étals de marché (côtés est et ouest, entre les portes)
	Models.marketStall(dressing, at(140, 42), C.Cloth, 1)
	Models.marketStall(dressing, at(40, 42), ROYAL_BLUE, 2)
	Models.marketStall(dressing, at(218, 43), Color3.fromRGB(60, 140, 80), 3)
	-- Coin de la garde : râteliers, foin, tonneaux
	Models.weaponRack(dressing, at(322, 45))
	Models.weaponRack(dressing, at(308, 45))
	for k, deg in { 333, 336, 296 } do
		Models.barrel(dressing, at(deg, 46 + k % 2))
	end
	Models.hayBale(dressing, at(160, 46))
	Models.hayBale(dressing, at(163, 44) * CFrame.Angles(0, 0.4, 0))
	-- Caisses et sacs empilés
	for _, deg in { 120, 60, 200, 345 } do
		local base = at(deg, 46)
		Models.crate(dressing, base, 1.8)
		Models.crate(dressing, base * CFrame.new(2, 0, 0.3) * CFrame.Angles(0, 0.3, 0), 1.5)
		Models.crate(dressing, base * CFrame.new(0.9, 1.8, 0.1) * CFrame.Angles(0, -0.2, 0), 1.2)
		for j = 0, 1 do
			Models.sack(dressing, base * CFrame.new(-1.8 - j * 1.1, 0, 0.4), rand)
		end
	end
	-- Jardinières au pied du donjon et près des portes
	for k, deg in { 75, 105, 20, 160, 250, 290 } do
		Models.planter(dressing, at(deg, 49), k)
	end

	-- Route pavée extérieure (anneau) et routes des portes
	local R, W = cfg.RingRoadRadius, cfg.RingRoadWidth
	local segments = 40
	for k = 1, segments do
		local a = (k / segments) * math.pi * 2
		local len = 2 * math.pi * R / segments * 1.04
		part(
			parent,
			"RingRoad",
			-- Hauteurs alternées : les recouvrements entre segments ne scintillent pas.
			Vector3.new(len, 0.6 + (k % 2) * 0.1, W - (k % 2) * 0.16),
			CFrame.new(math.cos(a) * R, 0.3 + (k % 2) * 0.05, math.sin(a) * R) * CFrame.Angles(0, -a + math.pi / 2, 0),
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
			Vector3.new(to - from + 1, 0.76, cfg.GateWidth),
			CFrame.new(math.cos(a) * mid, 0.38, math.sin(a) * mid) * CFrame.Angles(0, -a, 0),
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
		local seed = math.floor(cf.Position.X * 2.3 + cf.Position.Z * 4.1 + length)
		stoneFace(parent, cf, length, 1.0, h - 0.2, -t / 2, -1, seed, 0.9)
		stoneFace(parent, cf, length, 1.0, h - 0.2, t / 2, 1, seed + 7, 0.9)
		wallFoot(parent, cf, length, -t / 2, -1, seed + 1)
		wallFoot(parent, cf, length, t / 2, 1, seed + 2)
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
	-- Façade d'entrée ouverte au centre ; passages de 10 studs vers les extensions de terrain
	-- (fond : x = 0 ; côtés : z = 17,5 — voir Config/Land.Openings), fermés par des barrières
	-- tant que l'extension n'est pas achetée.
	local pass = 10
	local function wallBetween(cf: CFrame, from: number, to: number)
		if to - from > 0.5 then
			lowWall(cf * CFrame.new((from + to) / 2, 0, 0), to - from)
		end
	end
	wallBetween(base * CFrame.new(0, 0, half - t / 2), -half + 2, -pass / 2)
	wallBetween(base * CFrame.new(0, 0, half - t / 2), pass / 2, half - 2)
	for _, sx in { -1, 1 } do
		-- Mur latéral : axe local X du mur tourné le long de Z (x' = -z pour une rotation de 90°).
		local side = base * CFrame.new(sx * (half - t / 2), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		wallBetween(side, -(half - 2), -(17.5 + pass / 2))
		wallBetween(side, -(17.5 - pass / 2), half - 2)
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
	-- Portail : piliers à chapiteau doré, arc de claveaux, torches (remplacé par le portail du
	-- pack importé « 05_Portail » quand il existe : voir PlotService).
	if not Models.hasDecor("05_Portail") then
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
		arch(
			parent,
			base * CFrame.new(0, 7.2, -half + t / 2),
			gate / 2 + 1,
			1.4,
			2,
			11,
			WALL_LIGHT,
			Enum.Material.Slate
		)
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
	end
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

-- Extensions de terrain et machines -----------------------------------------------------

local FALLOW = Color3.fromRGB(128, 140, 84) -- friche (extension non achetée)
local FALLOW_DIRT = Color3.fromRGB(132, 108, 76)

-- Sol d'une extension. `base` = origine de la parcelle au niveau du sol ; rect local.
-- Retourne le sol (sa couleur/matière change à l'achat) et un dossier de décor de friche.
function Models.landFloor(base: CFrame, rect, parent: Instance): (BasePart, Folder)
	local sx, sz = rect[2] - rect[1], rect[4] - rect[3]
	local cx, cz = (rect[1] + rect[2]) / 2, (rect[3] + rect[4]) / 2
	local floor =
		part(parent, "LandFloor", Vector3.new(sx, 1, sz), base * CFrame.new(cx, -0.5, cz), FALLOW, Enum.Material.Grass)
	local weeds = Instance.new("Folder")
	weeds.Name = "Fallow"
	weeds.Parent = parent
	-- Touffes d'herbes, cailloux et souches : terrain en friche (disparaît à l'achat).
	local n = math.floor(sx * sz / 220)
	for k = 1, n do
		local fx = (math.noise(k * 0.71, cx * 0.13, 1.7) + 0.5) % 1
		local fz = (math.noise(k * 0.53, cz * 0.11, 4.1) + 0.5) % 1
		local x = rect[1] + 3 + fx * (sx - 6)
		local z = rect[3] + 3 + fz * (sz - 6)
		local at = base * CFrame.new(x, 0, z)
		if k % 3 == 0 then
			part(
				weeds,
				"Pebble",
				Vector3.new(1.2, 0.6, 1),
				at * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, k, 0.2),
				C.Stone,
				Enum.Material.Rock,
				{ CanCollide = false }
			)
		elseif k % 7 == 0 then
			column(weeds, "OldStump", 0.7, 1.4, at, C.Bark, Enum.Material.Wood, { CanCollide = false })
		else
			for j = 0, 2 do
				part(
					weeds,
					"Weed",
					Vector3.new(0.25, 1.1 + j * 0.25, 0.25),
					at * CFrame.Angles(0, j * 2.1, math.rad(14 - j * 12)) * CFrame.new(0, 0.5, 0),
					FALLOW:Lerp(C.Leaf2, 0.5),
					Enum.Material.Grass,
					{ CanCollide = false, NoShadow = true }
				)
			end
		end
	end
	part(
		weeds,
		"DirtPatch",
		Vector3.new(sx * 0.5, 0.06, sz * 0.4),
		base * CFrame.new(cx + sx * 0.12, 0.03, cz - sz * 0.1) * CFrame.Angles(0, 0.3, 0),
		FALLOW_DIRT,
		Enum.Material.Ground,
		{ CanCollide = false, NoShadow = true }
	)
	return floor, weeds
end

-- Muret d'une extension entre deux points locaux (même style que l'enceinte du bastion).
function Models.landWall(base: CFrame, x1: number, z1: number, x2: number, z2: number, parent: Instance)
	-- Mur du pack importé : modules de 12 studs alignés sur le segment.
	if Models.hasDecor("01_Mur_pierre") then
		local length = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
		local mid = base * CFrame.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
		local cf = if math.abs(x2 - x1) >= math.abs(z2 - z1) then mid else mid * CFrame.Angles(0, math.rad(90), 0)
		local folder = Instance.new("Folder")
		folder.Name = "MurPierre"
		folder.Parent = parent
		decorRow("01_Mur_pierre", folder, cf, -length / 2, length / 2, 0.55)
		return
	end
	-- Hauteur et épaisseur légèrement différentes selon le pan : aux angles, les murs qui se
	-- croisent n'ont aucune face au même niveau (pas de scintillement).
	local variant = math.floor(math.abs(x1 * 3 + z1 * 7 + x2 + z2 * 5)) % 3
	local h, t = 3.6 + variant * 0.08, 1.4 + variant * 0.08
	local length = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	local mid = base * CFrame.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
	local cf = if math.abs(x2 - x1) >= math.abs(z2 - z1) then mid else mid * CFrame.Angles(0, math.rad(90), 0)
	part(
		parent,
		"LandWall",
		Vector3.new(length + t, h, t),
		cf * CFrame.new(0, h / 2, 0),
		WALL_STONE,
		Enum.Material.Cobblestone
	)
	part(
		parent,
		"LandWallCap",
		Vector3.new(length + t, 0.35, t + 0.3),
		cf * CFrame.new(0, h + 0.17, 0),
		WALL_LIGHT,
		Enum.Material.Slate
	)
	local count = math.max(1, math.floor(length / 4))
	for k = 0, count - 1, 2 do
		part(
			parent,
			"LandMerlon",
			Vector3.new(length / count * 0.9, 0.9, t),
			cf * CFrame.new(-length / 2 + (k + 0.5) * (length / count), h + 0.8, 0),
			WALL_STONE,
			Enum.Material.Cobblestone
		)
	end
end

-- Barrière qui ferme un passage tant que l'extension n'est pas achetée : poteaux, planches
-- croisées et pancarte « À vendre ». `along` = direction du mur ("X" ou "Z").
function Models.landBarrier(base: CFrame, x: number, z: number, along: string, width: number): Model
	local m = newModel("Barrier")
	local cf = base
		* CFrame.new(x, 0, z)
		* (if along == "X" then CFrame.identity else CFrame.Angles(0, math.rad(90), 0))
	for _, side in { -1, 1 } do
		column(m, "Post", 4.4, 0.9, cf * CFrame.new(side * (width / 2 - 0.5), 0, 0), C.WoodDark, Enum.Material.Wood)
	end
	for k, y in { 1.2, 2.6 } do
		part(m, "Plank" .. k, Vector3.new(width, 0.6, 0.35), cf * CFrame.new(0, y, 0), C.Wood, Enum.Material.WoodPlanks)
	end
	for _, dir in { -1, 1 } do
		part(
			m,
			"Cross",
			Vector3.new(width * 1.05, 0.45, 0.3),
			cf * CFrame.new(0, 1.9, -0.3) * CFrame.Angles(0, 0, math.rad(dir * 16)),
			C.WoodDark,
			Enum.Material.Wood
		)
	end
	-- Invisible et haut : on ne peut pas sauter par-dessus.
	part(m, "Block", Vector3.new(width, 12, 1), cf * CFrame.new(0, 6, 0), C.Wood, nil, { Transparency = 1 })
	return m
end

-- Outils des machines ---------------------------------------------------------------------------

-- Poutre droite entre deux points (monde).
local function beam(m, name: string, p1: Vector3, p2: Vector3, t: number, color: Color3, material, props)
	local dir = p2 - p1
	-- Axe de référence de secours pour une poutre verticale (lookAt dégénéré sinon).
	local up = if math.abs(dir.Unit.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	return part(m, name, Vector3.new(t, t, dir.Magnitude), CFrame.lookAt((p1 + p2) / 2, p2, up), color, material, props)
end

-- Anneau segmenté autour de l'axe X du repère `cf` (rayon r, épaisseur radiale, largeur axiale).
local function ringX(m, name: string, cf: CFrame, r: number, thick: number, width: number, color, material, n: number)
	local len = 2 * math.pi * r / n * 1.08
	for i = 0, n - 1 do
		part(
			m,
			name,
			Vector3.new(width, thick, len),
			cf * CFrame.Angles(i * 2 * math.pi / n, 0, 0) * CFrame.new(0, r, 0),
			color,
			material,
			{ NoShadow = true, CanCollide = false }
		)
	end
end

-- Engrenage d'axe X : disque, dents, moyeu doré.
local function gear(m, name: string, cf: CFrame, d: number, thick: number, teeth: number, color: Color3)
	part(m, name, Vector3.new(thick, d, d), cf, color, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	for i = 0, teeth - 1 do
		part(
			m,
			name .. "Tooth",
			Vector3.new(thick * 0.9, d * 0.16, d * 0.13),
			cf * CFrame.Angles(i * 2 * math.pi / teeth, 0, 0) * CFrame.new(0, d / 2 + d * 0.04, 0),
			color,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	part(
		m,
		name .. "Hub",
		Vector3.new(thick + 0.24, d * 0.3, d * 0.3),
		cf,
		GOLD,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder, NoShadow = true }
	)
end

-- Roue à rayons d'axe X (volant, roue de charrette).
local function spokedWheel(
	m,
	name: string,
	cf: CFrame,
	d: number,
	width: number,
	spokes: number,
	color: Color3,
	material
)
	ringX(m, name .. "Rim", cf, d / 2 - 0.12, 0.26, width, color, material, 10)
	for i = 0, spokes - 1 do
		part(
			m,
			name .. "Spoke",
			Vector3.new(width * 0.6 + (i % 2) * 0.05, d - 0.3, 0.16),
			cf * CFrame.Angles(i * math.pi / spokes, 0, 0),
			color,
			material,
			{ NoShadow = true, CanCollide = false }
		)
	end
	part(
		m,
		name .. "Hub",
		Vector3.new(width + 0.2, d * 0.2, d * 0.2),
		cf,
		C.StoneDark,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder, NoShadow = true }
	)
end

-- Lanterne suspendue (sans lumière : économie de calcul).
local function hangingLantern(m, cf: CFrame, glowColor: Color3)
	part(m, "LanternCage", Vector3.new(0.6, 0.7, 0.6), cf, C.StoneDark, Enum.Material.Metal, { CanCollide = false })
	part(
		m,
		"LanternGlow",
		Vector3.new(0.44, 0.5, 0.7),
		cf,
		glowColor,
		Enum.Material.Neon,
		{ CanCollide = false, NoShadow = true }
	)
	part(
		m,
		"LanternTop",
		Vector3.new(0.3, 0.3, 0.3),
		cf * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(45), 0),
		C.StoneDark,
		Enum.Material.Metal,
		{ CanCollide = false, NoShadow = true }
	)
end

local MACHINE_TOP = 1.2 -- dessus du socle des machines

-- Base commune des machines : fondation en pierre à deux degrés, bornes d'angle dorées,
-- plaque avant aux voyants de niveau, tapis roulant sur rouleaux vers un bac de collecte.
-- Retourne le modèle et l'ancre d'étiquette.
local function machineBase(base: CFrame, level: number, accent: Color3): (Model, BasePart)
	local m = newModel("Machine")
	part(m, "Footing", Vector3.new(12, 0.5, 12), base * CFrame.new(0, 0.25, 0), C.StoneDark, Enum.Material.Cobblestone)
	part(m, "Plinth", Vector3.new(11, 0.7, 11), base * CFrame.new(0, 0.85, 0), C.Stone, Enum.Material.Slate)
	part(
		m,
		"PlinthTrim",
		Vector3.new(11.3, 0.2, 11.3),
		base * CFrame.new(0, 0.9, 0),
		C.StoneLight,
		Enum.Material.Slate,
		{ NoShadow = true }
	)
	-- Bornes d'angle à chapeau doré
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local at = base * CFrame.new(sx * 5.7, 0.5, sz * 5.7)
			column(m, "Bollard", 1.5, 0.8, at, C.StoneDark, Enum.Material.Cobblestone)
			ball(m, "BollardCap", 0.7, at * CFrame.new(0, 1.6, 0), GOLD, Enum.Material.Metal, { NoShadow = true })
		end
	end
	-- Plaque avant : bandeau de la couleur de la machine et voyants de niveau (dorés au max)
	part(
		m,
		"Plate",
		Vector3.new(6.4, 0.8, 0.2),
		base * CFrame.new(-1.4, 0.75, -5.62),
		C.StoneDark:Lerp(accent, 0.25),
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	part(
		m,
		"PlateBand",
		Vector3.new(6.6, 0.14, 0.32),
		base * CFrame.new(-1.4, 1.2, -5.62),
		GOLD,
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	for k = 1, level do
		part(
			m,
			"LevelLight",
			Vector3.new(0.7, 0.4, 0.14),
			base * CFrame.new(-4 + (k - 1) * 1.3, 0.75, -5.76),
			if level >= 5 then GOLD else accent,
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true }
		)
	end
	-- Tapis roulant sur rouleaux, montants métalliques et bac de collecte
	local belt = part(
		m,
		"Belt",
		Vector3.new(2.2, 0.3, 8),
		base * CFrame.new(3.5, 1.05, -9.6),
		Color3.fromRGB(48, 46, 50),
		Enum.Material.Rubber
	)
	for k = 0, 3 do
		part(
			m,
			"BeltSlat",
			Vector3.new(2.1, 0.06, 0.18),
			belt.CFrame * CFrame.new(0, 0.17, -3 + k * 2),
			Color3.fromRGB(70, 68, 72),
			Enum.Material.Metal,
			{ NoShadow = true, CanCollide = false }
		)
	end
	for _, side in { -1, 1 } do
		part(
			m,
			"BeltRail",
			Vector3.new(0.3, 0.6, 8.4),
			base * CFrame.new(3.5 + side * 1.3, 1.1, -9.6),
			C.Metal,
			Enum.Material.Metal
		)
		for k = 0, 2 do
			part(
				m,
				"BeltLeg",
				Vector3.new(0.2, 0.9, 0.2),
				base * CFrame.new(3.5 + side * 1.3, 0.4, -6.4 - k * 3.2),
				C.StoneDark,
				Enum.Material.Metal
			)
		end
	end
	for _, z in { -5.7, -13.5 } do
		part(
			m,
			"BeltRoller",
			Vector3.new(2.5, 0.5, 0.5),
			base * CFrame.new(3.5, 1.05, z),
			C.StoneDark,
			Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder, NoShadow = true }
		)
	end
	local bin = base * CFrame.new(3.5, 0, -15.6)
	Models.crate(m, bin, 3.2)
	for k = 0, 2 do
		part(
			m,
			"Heap",
			Vector3.new(1, 0.7, 1),
			bin * CFrame.new(-0.7 + k * 0.7, 3.45 + (k % 2) * 0.2, (k - 1) * 0.4) * CFrame.Angles(0, k * 0.7, 0.2),
			accent,
			Enum.Material.SmoothPlastic,
			{ NoShadow = true }
		)
	end
	-- Points de départ et d'arrivée des blocs animés côté client (MachineFx).
	local beltStart =
		part(m, "BeltStart", Vector3.new(0.2, 0.2, 0.2), belt.CFrame * CFrame.new(0, 0.6, 3.6), accent, nil, {
			Transparency = 1,
			CanCollide = false,
		})
	beltStart.CanQuery = false
	local beltEnd =
		part(m, "BeltEnd", Vector3.new(0.2, 0.2, 0.2), belt.CFrame * CFrame.new(0, 0.6, -3.8), accent, nil, {
			Transparency = 1,
			CanCollide = false,
		})
	beltEnd.CanQuery = false
	local anchor = part(m, "LabelAnchor", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 13, 0), accent, nil, {
		Transparency = 1,
		CanCollide = false,
	})
	anchor.CanQuery = false
	m.PrimaryPart = anchor
	return m, anchor
end

local machineBuilders = {}

-- Scierie : moulin à colombages, roue à aubes dans un bief, scie circulaire dentée, rondin,
-- piles de planches et de grumes, billot avec sa hache.
machineBuilders.LumberMill = function(m: Model, base: CFrame, level: number)
	local top = base * CFrame.new(0, MACHINE_TOP, 0)
	-- Charpente : sablières, poteaux, liens en diagonale
	for _, sz in { -1, 1 } do
		part(
			m,
			"Sill",
			Vector3.new(8.9, 0.5, 0.56),
			top * CFrame.new(0, 0.25, sz * 3.6),
			C.WoodDark,
			Enum.Material.Wood
		)
		part(
			m,
			"TopBeam",
			Vector3.new(9.2, 0.6, 0.84),
			top * CFrame.new(0, 6.2, sz * 3.6),
			C.WoodDark,
			Enum.Material.Wood
		)
		for _, sx in { -1, 1 } do
			part(
				m,
				"Post",
				Vector3.new(0.7, 6, 0.7),
				top * CFrame.new(sx * 4.1, 3.2, sz * 3.6),
				C.Wood,
				Enum.Material.Wood
			)
			beam(
				m,
				"Brace",
				(top * CFrame.new(sx * 4.1, 4.6, sz * 3.6)).Position,
				(top * CFrame.new(sx * 2.7, 6, sz * 3.6)).Position,
				0.35,
				C.WoodDark,
				Enum.Material.Wood
			)
		end
	end
	-- Mur arrière en planches verticales
	part(
		m,
		"BackWall",
		Vector3.new(7.5, 5.5, 0.3),
		top * CFrame.new(0, 3.2, 3.85),
		C.WoodLight,
		Enum.Material.WoodPlanks
	)
	for k = -3, 3 do
		part(
			m,
			"Batten",
			Vector3.new(0.2, 5.5, 0.12),
			top * CFrame.new(k * 1.1, 3.2, 3.64),
			C.WoodDark,
			Enum.Material.Wood,
			{ NoShadow = true }
		)
	end
	-- Toit en bardeaux, faîtage et épis
	gableRoof(m, 10.8, 9.2, 2.8, top * CFrame.new(0, 6.5, 0), C.Roof)
	part(m, "Ridge", Vector3.new(11.2, 0.4, 0.5), top * CFrame.new(0, 9.35, 0), C.RoofDark, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		ball(m, "Finial", 0.6, top * CFrame.new(sx * 5.5, 9.6, 0), GOLD, Enum.Material.Metal, { NoShadow = true })
	end
	hangingLantern(m, top * CFrame.new(-4.1, 5.2, -4.1), C.Rune)
	-- Établi et scie circulaire
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				m,
				"TableLeg",
				Vector3.new(0.35, 2, 0.35),
				top * CFrame.new(sx * 2.8, 1.1, -1.2 + sz * 0.8),
				C.WoodDark,
				Enum.Material.Wood
			)
		end
	end
	part(m, "Table", Vector3.new(6.6, 0.4, 2.2), top * CFrame.new(0, 2.2, -1.2), C.WoodLight, Enum.Material.WoodPlanks)
	part(m, "Log", Vector3.new(4.6, 1.3, 1.3), top * CFrame.new(-0.9, 3.05, -1.2), C.Bark, Enum.Material.Wood, {
		Shape = Enum.PartType.Cylinder,
	})
	part(
		m,
		"LogEnd",
		Vector3.new(0.1, 1.1, 1.1),
		top * CFrame.new(-3.24, 3.05, -1.2),
		C.WoodLight,
		Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder, NoShadow = true }
	)
	local blade = top * CFrame.new(2.2, 2.9, -1.2)
	part(
		m,
		"Blade",
		Vector3.new(0.12, 2.8, 2.8),
		blade * CFrame.Angles(0, math.rad(90), 0),
		C.Metal,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
	for i = 0, 9 do
		part(
			m,
			"BladeTooth",
			Vector3.new(0.26, 0.26, 0.1),
			blade * CFrame.Angles(0, 0, i * math.pi / 5) * CFrame.new(0, 1.42, 0) * CFrame.Angles(0, 0, math.rad(45)),
			C.Metal:Lerp(C.StoneLight, 0.4),
			Enum.Material.Metal,
			{ NoShadow = true, CanCollide = false }
		)
	end
	part(
		m,
		"BladeHub",
		Vector3.new(0.4, 0.7, 0.7),
		blade * CFrame.Angles(0, math.rad(90), 0),
		GOLD,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder, NoShadow = true }
	)
	part(m, "BladeGuard", Vector3.new(0.5, 0.3, 1.8), blade * CFrame.new(0, 1.65, 0), C.StoneDark, Enum.Material.Metal)
	-- Roue à aubes dans son bief (côté droit), axe vers la charpente
	local trough = top * CFrame.new(6.4, -0.65, 0.4)
	part(m, "Trough", Vector3.new(2.2, 1.1, 7), trough, C.WoodDark, Enum.Material.WoodPlanks)
	part(
		m,
		"Water",
		Vector3.new(1.6, 0.2, 6.6),
		trough * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(70, 140, 200),
		Enum.Material.Glass,
		{ Transparency = 0.25, NoShadow = true, CanCollide = false }
	)
	local wheel = top * CFrame.new(6.4, 2.1, 0.4)
	ringX(m, "WheelRim", wheel, 2.5, 0.3, 1.1, C.WoodDark, Enum.Material.Wood, 12)
	for i = 0, 3 do
		part(
			m,
			"WheelSpoke",
			Vector3.new(0.6, 5, 0.25),
			wheel * CFrame.Angles(i * math.pi / 4, 0, 0),
			C.Wood,
			Enum.Material.Wood,
			{ CanCollide = false }
		)
	end
	for i = 0, 7 do
		part(
			m,
			"Paddle",
			Vector3.new(1.3, 0.9, 0.14),
			wheel * CFrame.Angles(i * math.pi / 4 + 0.13, 0, 0) * CFrame.new(0, 2.85, 0),
			C.WoodLight,
			Enum.Material.WoodPlanks,
			{ NoShadow = true, CanCollide = false }
		)
	end
	part(
		m,
		"Axle",
		Vector3.new(2.8, 0.45, 0.45),
		top * CFrame.new(5.2, 2.1, 0.4),
		C.StoneDark,
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
	-- Pile de planches (plus haute à chaque niveau) et grumes
	for _, x in { -3.8, -1.4 } do
		part(m, "Bearer", Vector3.new(0.4, 0.3, 2), top * CFrame.new(x, 0.15, 2.3), C.WoodDark, Enum.Material.Wood)
	end
	for k = 0, 1 + level do
		part(
			m,
			"Plank",
			Vector3.new(3.4, 0.3, 1.6),
			top * CFrame.new(-2.6 + (k % 2) * 0.1, 0.45 + k * 0.32, 2.3),
			C.WoodLight:Lerp(C.Wood, (k % 2) * 0.35),
			Enum.Material.WoodPlanks
		)
	end
	for k, p in { { 1.6, 0.55, 2.4 }, { 2.8, 0.55, 2.4 }, { 2.2, 1.4, 2.4 } } do
		part(
			m,
			"Lumber" .. k,
			Vector3.new(3, 1.1, 1.1),
			top * CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, math.rad(90), 0),
			C.Bark,
			Enum.Material.Wood,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	-- Billot et hache
	local stump = top * CFrame.new(-3.4, 0, -4)
	column(m, "Stump", 1.2, 1.5, stump, C.Bark, Enum.Material.Wood)
	column(
		m,
		"StumpTop",
		0.06,
		1.3,
		stump * CFrame.new(0, 1.2, 0),
		C.WoodLight,
		Enum.Material.Wood,
		{ NoShadow = true }
	)
	part(
		m,
		"AxeHandle",
		Vector3.new(0.18, 1.8, 0.18),
		stump * CFrame.new(0.2, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		C.WoodLight,
		Enum.Material.Wood,
		{ CanCollide = false }
	)
	part(
		m,
		"AxeHead",
		Vector3.new(0.7, 0.5, 0.12),
		stump * CFrame.new(-0.05, 1.35, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		C.Metal,
		Enum.Material.Metal,
		{ CanCollide = false, NoShadow = true }
	)
end

-- Concasseur : socle de pierre cerclé de fer, carter riveté, trémie dorée, engrenages en prise,
-- volant d'inertie, cheminée à vapeur, manomètre, tas de pierres.
machineBuilders.StoneCrusher = function(m: Model, base: CFrame, level: number)
	local top = base * CFrame.new(0, MACHINE_TOP, 0)
	part(m, "Body", Vector3.new(7, 3, 6), top * CFrame.new(0, 1.5, 0.4), C.StoneDark, Enum.Material.Cobblestone)
	for _, y in { 0.5, 2.5 } do
		part(
			m,
			"IronBand",
			Vector3.new(7.24, 0.32, 6.24),
			top * CFrame.new(0, y, 0.4),
			C.Metal:Lerp(C.StoneDark, 0.5),
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	local housing = top * CFrame.new(0, 4.1, 0.4)
	part(m, "Housing", Vector3.new(6.2, 2.2, 5.2), housing, C.Metal:Lerp(C.StoneDark, 0.3), Enum.Material.DiamondPlate)
	-- Rivets sur la face avant du carter
	for i = 0, 3 do
		for _, y in { -0.75, 0.75 } do
			ball(
				m,
				"Rivet",
				0.22,
				housing * CFrame.new(-2.4 + i * 1.6, y, -2.62),
				C.StoneDark,
				Enum.Material.Metal,
				{ NoShadow = true }
			)
		end
	end
	-- Trémie en entonnoir : quatre plaques inclinées, cadre doré
	local hop = top * CFrame.new(0, 6.3, 0.4)
	for k = 0, 3 do
		local width = if k % 2 == 0 then 6.6 else 5.6
		part(
			m,
			"Hopper",
			Vector3.new(width, 2.4, 0.3),
			hop
				* CFrame.Angles(0, math.rad(k * 90), 0)
				* CFrame.new(0, 0, (if k % 2 == 0 then 2.6 else 3.1) - 0.45)
				* CFrame.Angles(math.rad(-25), 0, 0),
			C.StoneDark:Lerp(C.Metal, 0.35),
			Enum.Material.DiamondPlate
		)
	end
	for k = 0, 3 do
		local width = if k % 2 == 0 then 7.4 else 6.6
		part(
			m,
			"HopperRim",
			Vector3.new(width, 0.35, 0.45),
			hop * CFrame.Angles(0, math.rad(k * 90), 0) * CFrame.new(0, 1.15, if k % 2 == 0 then 3.15 else 3.6),
			GOLD,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	for k = 1, level + 1 do
		part(
			m,
			"Rock",
			Vector3.new(0.9, 0.7, 0.8),
			hop * CFrame.new(-2.2 + k * 0.75, 0.4 + (k % 2) * 0.2, (k % 3 - 1) * 0.7) * CFrame.Angles(k, k * 0.6, 0),
			C.Stone,
			Enum.Material.Rock
		)
	end
	-- Rouleaux broyeurs visibles par la gueule avant
	part(
		m,
		"Mouth",
		Vector3.new(4, 0.9, 0.2),
		top * CFrame.new(0, 1.85, -2.66),
		Color3.fromRGB(30, 28, 30),
		Enum.Material.SmoothPlastic,
		{ NoShadow = true }
	)
	for _, y in { 1.6, 2.1 } do
		part(
			m,
			"Roller",
			Vector3.new(3.8, 0.6, 0.6),
			top * CFrame.new(0, y, -2.62),
			C.Metal,
			Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder, NoShadow = true }
		)
	end
	-- Goulotte vers le tapis
	part(
		m,
		"Chute",
		Vector3.new(2.2, 0.25, 2.6),
		top * CFrame.new(3.5, 0.75, -3.6) * CFrame.Angles(math.rad(-20), 0, 0),
		C.Metal,
		Enum.Material.Metal
	)
	-- Engrenages en prise (côté droit) et volant (côté gauche)
	local big = top * CFrame.new(3.75, 3.3, 0.4)
	gear(m, "GearBig", big, 3.6, 0.4, 10, C.Metal:Lerp(C.StoneDark, 0.2))
	gear(m, "GearSmall", big * CFrame.new(0.05, 2.05, 2.05), 2.2, 0.4, 7, C.Metal)
	spokedWheel(m, "Flywheel", top * CFrame.new(-3.9, 3.2, 0.4), 4, 0.5, 3, C.StoneDark, Enum.Material.Metal)
	-- Cheminée à vapeur cerclée et manomètre
	local stack = top * CFrame.new(-2.2, 5.2, 2.4)
	column(m, "Stack", 4 + level * 0.4, 1, stack, C.StoneDark, Enum.Material.Metal)
	for k = 0, 2 do
		column(m, "StackBand", 0.2, 1.16, stack * CFrame.new(0, 0.8 + k * 1.3, 0), GOLD, Enum.Material.Metal, {
			NoShadow = true,
		})
	end
	column(m, "StackCap", 0.4, 1.5, stack * CFrame.new(0, 4 + level * 0.4, 0), C.StoneDark, Enum.Material.Metal)
	local gauge = housing * CFrame.new(1.9, 0.2, -2.72)
	part(m, "Gauge", Vector3.new(0.14, 1, 1), gauge * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
		NoShadow = true,
	})
	part(
		m,
		"GaugeFace",
		Vector3.new(0.06, 0.8, 0.8),
		gauge * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(240, 235, 220),
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder, NoShadow = true }
	)
	part(
		m,
		"GaugeNeedle",
		Vector3.new(0.05, 0.34, 0.04),
		gauge * CFrame.new(0, 0.1, -0.1) * CFrame.Angles(0, 0, math.rad(-35)),
		Color3.fromRGB(180, 40, 40),
		Enum.Material.SmoothPlastic,
		{ NoShadow = true, CanCollide = false }
	)
	-- Tas de pierres à concasser
	local pile = top * CFrame.new(-3.6, 0, -4)
	for k, p in { { 0, 0.4, 0, 1.2 }, { 0.7, 0.35, 0.4, 1 }, { -0.5, 0.3, 0.6, 0.9 }, { 0.2, 1, 0.2, 0.9 } } do
		part(
			m,
			"PileRock",
			Vector3.new(p[4], p[4] * 0.75, p[4] * 0.9),
			pile * CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(k * 0.5, k * 1.1, k * 0.3),
			C.Stone:Lerp(C.StoneDark, (k % 2) * 0.4),
			Enum.Material.Rock
		)
	end
end

-- Foreuse : derrick en treillis à poulie, vis sans fin dans un puits, chaudière à volant,
-- wagonnet de minerai sur rails, lanterne.
machineBuilders.OreDrill = function(m: Model, base: CFrame, level: number)
	local top = base * CFrame.new(0, MACHINE_TOP, 0)
	local h = 9 + level
	local function leg(sx, sz, y)
		local f = y / h
		local r = 3.2 * (1 - f) + 0.9 * f
		return (top * CFrame.new(sx * r, y, sz * r)).Position
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			beam(m, "Leg", leg(sx, sz, 0), leg(sx, sz, h), 0.55, C.WoodDark, Enum.Material.Wood)
			column(
				m,
				"Footing",
				0.5,
				1,
				top * CFrame.new(sx * 3.2, 0, sz * 3.2),
				C.StoneDark,
				Enum.Material.Cobblestone
			)
		end
	end
	-- Entretoises en croix sur les 4 faces, à deux étages
	for _, y in { { 0.6, h * 0.45 }, { h * 0.45, h * 0.85 } } do
		for face = 0, 3 do
			local a = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
			local p, q = a[face + 1], a[(face + 1) % 4 + 1]
			beam(m, "Brace", leg(p[1], p[2], y[1]), leg(q[1], q[2], y[2]), 0.25, C.Wood, Enum.Material.Wood, {
				NoShadow = true,
				CanCollide = false,
			})
			beam(m, "Brace", leg(q[1], q[2], y[1]), leg(p[1], p[2], y[2]), 0.25, C.Wood, Enum.Material.Wood, {
				NoShadow = true,
				CanCollide = false,
			})
			beam(m, "Girt", leg(p[1], p[2], y[2]), leg(q[1], q[2], y[2]), 0.3, C.WoodDark, Enum.Material.Wood)
		end
	end
	-- Plate-forme et poulie au sommet, câble
	part(m, "Crown", Vector3.new(2.6, 0.4, 2.6), top * CFrame.new(0, h + 0.2, 0), C.WoodDark, Enum.Material.Wood)
	spokedWheel(m, "Pulley", top * CFrame.new(0, h + 1.2, 0), 1.8, 0.3, 2, C.Metal, Enum.Material.Metal)
	part(
		m,
		"Cable",
		Vector3.new(0.08, h - 2.6, 0.08),
		top * CFrame.new(0, (h + 3.8) / 2, -0.85),
		Color3.fromRGB(40, 38, 40),
		Enum.Material.Metal,
		{ NoShadow = true, CanCollide = false }
	)
	-- Puits et vis sans fin
	column(m, "WellRim", 0.4, 3.2, top, C.StoneDark, Enum.Material.Cobblestone)
	column(
		m,
		"WellHole",
		0.06,
		2.4,
		top * CFrame.new(0, 0.4, 0),
		Color3.fromRGB(25, 20, 18),
		Enum.Material.SmoothPlastic,
		{ NoShadow = true }
	)
	column(m, "Shaft", 4, 0.5, top * CFrame.new(0, 0.4, 0), C.Metal, Enum.Material.Metal)
	for k = 0, 7 do
		part(
			m,
			"Flight",
			Vector3.new(1.7, 0.16, 0.5),
			top * CFrame.new(0, 0.6 + k * 0.4, 0) * CFrame.Angles(0, k * math.rad(45), math.rad(12)),
			GOLD,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	part(m, "DrillHead", Vector3.new(1.4, 1.3, 1.4), top * CFrame.new(0, 4.9, 0), C.StoneDark, Enum.Material.Metal)
	-- Chaudière (cylindre couché), cheminée, volant, courroie vers la tête
	local boiler = top * CFrame.new(-2.6, 1.4, 4.2)
	part(m, "Boiler", Vector3.new(3.4, 2, 2), boiler, Color3.fromRGB(150, 70, 50), Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
	})
	for _, x in { -1.2, 0, 1.2 } do
		part(
			m,
			"BoilerBand",
			Vector3.new(0.2, 2.14, 2.14),
			boiler * CFrame.new(x, 0, 0),
			GOLD,
			Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder, NoShadow = true }
		)
	end
	for _, x in { -1.2, 1.2 } do
		part(m, "Cradle", Vector3.new(0.5, 0.6, 2.2), boiler * CFrame.new(x, -1, 0), C.StoneDark, Enum.Material.Metal)
	end
	column(m, "Smokestack", 3.4, 0.6, boiler * CFrame.new(-0.9, 0.9, 0), C.StoneDark, Enum.Material.Metal)
	spokedWheel(m, "Flywheel", boiler * CFrame.new(1.95, 0.2, 0), 2.4, 0.3, 3, C.StoneDark, Enum.Material.Metal)
	beam(
		m,
		"DriveBelt",
		(boiler * CFrame.new(2.1, 1.3, 0)).Position,
		(top * CFrame.new(0, 4.9, 0.6)).Position,
		0.12,
		Color3.fromRGB(70, 50, 35),
		Enum.Material.Fabric,
		{ NoShadow = true, CanCollide = false }
	)
	-- Rails et wagonnet de minerai
	local rails = top * CFrame.new(4.2, 0, -1)
	for k = -2, 2 do
		part(
			m,
			"Sleeper",
			Vector3.new(1.8, 0.16, 0.4),
			rails * CFrame.new(0, 0.08, k * 1.3),
			C.WoodDark,
			Enum.Material.Wood
		)
	end
	for _, x in { -0.55, 0.55 } do
		part(m, "Rail", Vector3.new(0.14, 0.14, 6.6), rails * CFrame.new(x, 0.23, 0), C.Metal, Enum.Material.Metal)
	end
	local cart = rails * CFrame.new(0, 0, 0.4)
	part(m, "Cart", Vector3.new(1.7, 1, 2.2), cart * CFrame.new(0, 1.05, 0), C.Wood, Enum.Material.WoodPlanks)
	part(
		m,
		"CartRim",
		Vector3.new(1.86, 0.18, 2.36),
		cart * CFrame.new(0, 1.52, 0),
		C.StoneDark,
		Enum.Material.Metal,
		{ NoShadow = true }
	)
	for _, x in { -0.8, 0.8 } do
		for _, z in { -0.7, 0.7 } do
			part(
				m,
				"CartWheel",
				Vector3.new(0.18, 0.5, 0.5),
				cart * CFrame.new(x, 0.55, z),
				C.StoneDark,
				Enum.Material.Metal,
				{
					Shape = Enum.PartType.Cylinder,
					NoShadow = true,
				}
			)
		end
	end
	for k = 0, 2 + math.min(level, 3) do
		local ore = k % 3 == 0
		part(
			m,
			"OreLump",
			Vector3.new(0.6, 0.5, 0.6),
			cart
				* CFrame.new(-0.45 + (k % 3) * 0.45, 1.65 + math.floor(k / 3) * 0.2, -0.6 + (k % 2) * 0.9)
				* CFrame.Angles(k, k * 0.7, 0),
			if ore then Color3.fromRGB(230, 150, 90) else Color3.fromRGB(190, 120, 80),
			if ore then Enum.Material.Neon else Enum.Material.Rock,
			{ NoShadow = true }
		)
	end
	local lr = 3.2 * 0.45 + 0.9 * 0.55
	hangingLantern(m, top * CFrame.new(-lr - 0.1, h * 0.55 - 0.7, -lr - 0.5), C.Rune)
end

-- Condenseur d'Éther : dais de marbre à degrés, obélisques runiques, grappe de cristaux
-- flottante dans des anneaux armillaires, réservoir de verre relié par des tuyaux de cuivre.
machineBuilders.EtherCondenser = function(m: Model, base: CFrame, level: number)
	local top = base * CFrame.new(0, MACHINE_TOP, 0)
	local rune = C.RuneBlue:Lerp(C.Ether, 0.5)
	column(m, "Dais", 0.6, 9, top, MARBLE, Enum.Material.Marble)
	column(m, "DaisTrim", 0.2, 9.3, top * CFrame.new(0, 0.2, 0), GOLD, Enum.Material.Metal, { NoShadow = true })
	column(m, "DaisStep", 0.6, 6.6, top * CFrame.new(0, 0.6, 0), MARBLE_SHADE, Enum.Material.Marble)
	column(
		m,
		"DaisRune",
		0.04,
		5.6,
		top * CFrame.new(0, 1.2, 0),
		rune,
		Enum.Material.Neon,
		{ NoShadow = true, Transparency = 0.3 }
	)
	column(
		m,
		"DaisInlay",
		0.06,
		5,
		top * CFrame.new(0, 1.2, 0),
		MARBLE_SHADE,
		Enum.Material.Marble,
		{ NoShadow = true }
	)
	-- Six obélisques à rune et pointe de cristal
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		local at = top * CFrame.new(math.cos(a) * 3.9, 0.6, math.sin(a) * 3.9) * CFrame.Angles(0, -a - math.pi / 2, 0)
		part(m, "ObeliskBase", Vector3.new(1, 0.6, 1), at * CFrame.new(0, 0.3, 0), MARBLE_SHADE, Enum.Material.Marble)
		part(
			m,
			"Obelisk",
			Vector3.new(0.65, 3.6 + level * 0.3, 0.65),
			at * CFrame.new(0, 2.4 + level * 0.15, 0),
			MARBLE,
			Enum.Material.Marble
		)
		part(
			m,
			"ObeliskRune",
			Vector3.new(0.16, 2.6, 0.06),
			at * CFrame.new(0, 2.4, 0.34),
			rune,
			Enum.Material.Neon,
			{ NoShadow = true, CanCollide = false }
		)
		part(
			m,
			"ObeliskTip",
			Vector3.new(0.5, 0.5, 0.5),
			at * CFrame.new(0, 4.6 + level * 0.3, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			rune,
			Enum.Material.Neon,
			{ NoShadow = true, CanCollide = false }
		)
	end
	-- Coupe dorée sur colonnette, grappe de cristaux flottante
	column(m, "Stem", 1.6, 1.1, top * CFrame.new(0, 1.2, 0), MARBLE_SHADE, Enum.Material.Marble)
	column(m, "Bowl", 0.5, 2.6, top * CFrame.new(0, 2.8, 0), GOLD, Enum.Material.Metal)
	local core = top * CFrame.new(0, 5.2, 0)
	part(
		m,
		"Crystal",
		Vector3.new(1.3, 3.4, 1.3),
		core * CFrame.Angles(0, math.rad(45), 0),
		rune,
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	for i = 0, 3 do
		part(
			m,
			"Shard",
			Vector3.new(0.6, 1.6, 0.6),
			core
				* CFrame.Angles(0, i * math.pi / 2, 0)
				* CFrame.new(0, -0.7, -0.75)
				* CFrame.Angles(math.rad(-25), math.rad(45), 0),
			C.Ether,
			Enum.Material.Neon,
			{ NoShadow = true, CanCollide = false }
		)
	end
	-- Anneaux armillaires (un de plus par niveau, jusqu'à 3)
	for k = 1, math.min(level, 3) do
		ringX(
			m,
			"Ring" .. k,
			core * CFrame.Angles(0, k * math.rad(60), math.rad(90)) * CFrame.Angles(math.rad(k * 30), 0, 0),
			1.9 + k * 0.45,
			0.14,
			0.2,
			GOLD,
			Enum.Material.Metal,
			12
		)
	end
	ball(m, "Orb", 0.9, top * CFrame.new(0, 8.6, 0), C.Ether, Enum.Material.Neon, { NoShadow = true })
	-- Réservoir de verre et tuyaux de cuivre
	local tank = top * CFrame.new(-4.4, 0, 3.4)
	column(m, "TankBase", 0.5, 2, tank, GOLD, Enum.Material.Metal)
	column(m, "Tank", 2.8, 1.7, tank * CFrame.new(0, 0.5, 0), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, {
		Transparency = 0.55,
	})
	column(m, "TankFluid", 2 + level * 0.15, 1.3, tank * CFrame.new(0, 0.55, 0), rune, Enum.Material.Neon, {
		NoShadow = true,
		CanCollide = false,
	})
	column(m, "TankLid", 0.4, 2, tank * CFrame.new(0, 3.3, 0), GOLD, Enum.Material.Metal)
	local copper = Color3.fromRGB(190, 110, 70)
	local p1 = (tank * CFrame.new(0, 3.9, 0)).Position
	local p2 = (tank * CFrame.new(0, 4.6, 0)).Position
	local p3 = (top * CFrame.new(-1.2, 4.6, 1)).Position
	beam(m, "Pipe", p1, p2, 0.3, copper, Enum.Material.Metal)
	beam(m, "Pipe", p2, p3, 0.3, copper, Enum.Material.Metal)
	ball(m, "PipeJoint", 0.42, CFrame.new(p2), copper, Enum.Material.Metal, { NoShadow = true })
end

-- Forge royale : forge en brique sur soubassement de pierre, gueule voûtée incandescente,
-- cheminée cerclée crachant des étincelles, soufflet, enclume et marteau, bac de trempe,
-- lingots, bannière royale à couronne.
machineBuilders.RoyalForge = function(m: Model, base: CFrame, level: number)
	local top = base * CFrame.new(0, MACHINE_TOP, 0)
	part(m, "Socle", Vector3.new(8.4, 1, 7), top * CFrame.new(0, 0.5, 1.4), C.StoneDark, Enum.Material.Cobblestone)
	local body = top * CFrame.new(0, 3.5, 1.4)
	part(m, "Furnace", Vector3.new(7.6, 5, 6.4), body, Color3.fromRGB(150, 70, 55), Enum.Material.Brick)
	-- Chaînage d'angle en pierre (harpes alternées)
	for _, sx in { -1, 1 } do
		for k = 0, 4 do
			local long = k % 2 == 0
			part(
				m,
				"Quoin",
				Vector3.new(if long then 1.3 else 0.8, 0.9, 0.3),
				body * CFrame.new(sx * (3.8 - (if long then 0.6 else 0.35)), -2 + k, -3.25),
				C.StoneLight,
				Enum.Material.Slate,
				{ NoShadow = true }
			)
		end
	end
	-- Gueule voûtée : foyer, claveaux, clé dorée
	local mouth = body * CFrame.new(0, -1.2, -3.22)
	part(m, "Mouth", Vector3.new(3, 2.2, 0.2), mouth, Color3.fromRGB(255, 140, 50), Enum.Material.Neon, {
		NoShadow = true,
	})
	part(
		m,
		"Embers",
		Vector3.new(2.6, 0.5, 0.3),
		mouth * CFrame.new(0, -0.8, -0.03),
		Color3.fromRGB(255, 80, 30),
		Enum.Material.Neon,
		{ NoShadow = true }
	)
	for i = 0, 6 do
		local a = math.rad(180 - i * 30)
		part(
			m,
			"Voussoir",
			Vector3.new(0.7, 0.55, 0.4),
			mouth
				* CFrame.new(math.cos(a) * 1.75, 1.1 + math.sin(a) * 1.2, -0.08 - (i % 2) * 0.03)
				* CFrame.Angles(0, 0, a - math.pi / 2),
			if i == 3 then GOLD else C.StoneLight,
			if i == 3 then Enum.Material.Metal else Enum.Material.Slate,
			{ NoShadow = true }
		)
	end
	-- Toit d'ardoise, faîtage, cheminée cerclée et étincelles
	gableRoof(m, 8.4, 7.2, 2.4, top * CFrame.new(0, 6, 1.4), C.RoofDark)
	part(m, "Ridge", Vector3.new(8.8, 0.35, 0.45), top * CFrame.new(0, 8.45, 1.4), C.StoneDark, Enum.Material.Slate)
	local chimneyH = 5 + level
	local chimney = top * CFrame.new(2.4, 6 + chimneyH / 2, 2.8)
	part(m, "Chimney", Vector3.new(1.8, chimneyH, 1.8), chimney, C.StoneDark, Enum.Material.Brick)
	for k = 0, 1 do
		part(
			m,
			"ChimneyBand",
			Vector3.new(1.96, 0.25, 1.96),
			chimney * CFrame.new(0, -chimneyH / 2 + 2 + k * 2.2, 0),
			GOLD,
			Enum.Material.Metal,
			{ NoShadow = true }
		)
	end
	part(
		m,
		"ChimneyCap",
		Vector3.new(2.3, 0.4, 2.3),
		chimney * CFrame.new(0, chimneyH / 2 + 0.2, 0),
		C.StoneDark,
		Enum.Material.Slate
	)
	for k = 0, 3 do
		part(
			m,
			"Spark",
			Vector3.new(0.2, 0.2, 0.2),
			chimney * CFrame.new(-0.4 + k * 0.3, chimneyH / 2 + 0.8 + (k % 2) * 0.7, (k % 3 - 1) * 0.3),
			Color3.fromRGB(255, 170, 60),
			Enum.Material.Neon,
			{ NoShadow = true, CanCollide = false }
		)
	end
	-- Soufflet en cuir (côté gauche)
	local bellows = top * CFrame.new(-4.9, 1.5, 1.4)
	part(
		m,
		"BellowsBoard",
		Vector3.new(1.4, 0.15, 2.6),
		bellows * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-8), 0, 0),
		C.Wood,
		Enum.Material.Wood
	)
	part(m, "BellowsBoard", Vector3.new(1.4, 0.15, 2.6), bellows * CFrame.new(0, -0.5, 0), C.Wood, Enum.Material.Wood)
	part(m, "BellowsLeather", Vector3.new(1.2, 0.8, 2.2), bellows, Color3.fromRGB(105, 70, 45), Enum.Material.Leather)
	part(
		m,
		"BellowsHandle",
		Vector3.new(0.2, 0.2, 1.4),
		bellows * CFrame.new(0, 0.6, 1.8),
		C.WoodDark,
		Enum.Material.Wood
	)
	part(
		m,
		"BellowsSupport",
		Vector3.new(0.6, 0.9, 0.6),
		top * CFrame.new(-4.9, 0.5, 1.4),
		C.StoneDark,
		Enum.Material.Cobblestone
	)
	-- Enclume sur billot et marteau
	local anvil = top * CFrame.new(-2.4, 0, -3.6)
	column(m, "AnvilBlock", 1, 1.5, anvil, C.Bark, Enum.Material.Wood)
	part(m, "AnvilFoot", Vector3.new(1.4, 0.35, 0.9), anvil * CFrame.new(0, 1.18, 0), C.StoneDark, Enum.Material.Metal)
	part(m, "AnvilWaist", Vector3.new(0.8, 0.5, 0.6), anvil * CFrame.new(0, 1.6, 0), C.StoneDark, Enum.Material.Metal)
	part(
		m,
		"AnvilFace",
		Vector3.new(1.8, 0.45, 0.85),
		anvil * CFrame.new(-0.1, 2.07, 0),
		C.Metal:Lerp(C.StoneDark, 0.4),
		Enum.Material.Metal
	)
	part(
		m,
		"AnvilHorn",
		Vector3.new(0.85, 0.45, 0.8),
		anvil * CFrame.new(1.22, 2.07, 0) * CFrame.Angles(0, math.rad(-90), 0),
		C.Metal:Lerp(C.StoneDark, 0.4),
		Enum.Material.Metal,
		{ Class = "WedgePart" }
	)
	part(
		m,
		"HammerHandle",
		Vector3.new(0.14, 0.14, 1.3),
		anvil * CFrame.new(-0.4, 2.4, -0.3) * CFrame.Angles(0, math.rad(30), 0),
		C.WoodLight,
		Enum.Material.Wood,
		{ CanCollide = false }
	)
	part(
		m,
		"HammerHead",
		Vector3.new(0.6, 0.32, 0.32),
		anvil * CFrame.new(-0.05, 2.45, 0.28) * CFrame.Angles(0, math.rad(30), 0),
		C.StoneDark,
		Enum.Material.Metal,
		{ CanCollide = false }
	)
	-- Bac de trempe
	local quench = top * CFrame.new(-4.4, 0, -3.4)
	Models.barrel(m, quench)
	column(
		m,
		"QuenchWater",
		0.06,
		1.6,
		quench * CFrame.new(0, 2.2, 0),
		Color3.fromRGB(70, 120, 170),
		Enum.Material.Glass,
		{
			Transparency = 0.2,
			NoShadow = true,
		}
	)
	-- Lingots d'or en pyramide (plus nombreux avec le niveau)
	local ingots = top * CFrame.new(0.4, 0, -3.8)
	local n = 0
	for row = 0, 2 do
		for k = 0, 2 - row do
			n += 1
			if n > 1 + level then
				break
			end
			part(
				m,
				"Ingot",
				Vector3.new(1.1, 0.4, 0.55),
				ingots * CFrame.new((k - (2 - row) / 2) * 1.15, 0.2 + row * 0.42, 0),
				GOLD,
				Enum.Material.Metal,
				{ NoShadow = true }
			)
		end
	end
	-- Bannière royale à couronne
	local pole = top * CFrame.new(4.6, 0, -2.6)
	column(m, "BannerPole", 7, 0.3, pole, C.WoodDark, Enum.Material.Wood)
	ball(m, "BannerFinial", 0.5, pole * CFrame.new(0, 7.1, 0), GOLD, Enum.Material.Metal, { NoShadow = true })
	part(m, "BannerBar", Vector3.new(0.18, 0.18, 2.2), pole * CFrame.new(0, 6.6, -1), C.WoodDark, Enum.Material.Wood)
	local cloth = pole * CFrame.new(0, 5, -1.1)
	part(m, "Banner", Vector3.new(0.1, 3, 1.8), cloth, C.Cloth, Enum.Material.Fabric, { CanCollide = false })
	part(
		m,
		"BannerTrim",
		Vector3.new(0.16, 0.2, 1.8),
		cloth * CFrame.new(0, -1.3, 0),
		GOLD,
		Enum.Material.Fabric,
		{ NoShadow = true, CanCollide = false }
	)
	part(
		m,
		"Crown",
		Vector3.new(0.2, 0.35, 0.9),
		cloth * CFrame.new(0, 0.3, 0),
		GOLD,
		Enum.Material.Metal,
		{ NoShadow = true, CanCollide = false }
	)
	for k = -1, 1 do
		part(
			m,
			"CrownPoint",
			Vector3.new(0.18, 0.3, 0.2),
			cloth * CFrame.new(0, 0.6, k * 0.33),
			GOLD,
			Enum.Material.Metal,
			{ NoShadow = true, CanCollide = false }
		)
	end
end

local MACHINE_ACCENT = {
	LumberMill = Color3.fromRGB(150, 100, 55),
	StoneCrusher = Color3.fromRGB(170, 170, 175),
	OreDrill = Color3.fromRGB(200, 125, 80),
	EtherCondenser = Color3.fromRGB(140, 120, 255),
	RoyalForge = Color3.fromRGB(255, 190, 70),
}

-- Machine de production complète. `base` = emplacement au sol, -Z = face avant (tapis).
-- Retourne le modèle et l'ancre d'étiquette.
function Models.machine(kind: string, base: CFrame, level: number): (Model, BasePart)
	local accent = MACHINE_ACCENT[kind] or C.Metal
	local m, anchor = machineBase(base, level, accent)
	m.Name = kind
	local builder = machineBuilders[kind]
	if builder then
		builder(m, base, level)
	end
	return m, anchor
end

-- Salle mystique -------------------------------------------------------------------------------
-- Enveloppe fermée autour de la Rue des boss et du Champ des champions (sous la carte) :
-- sol d'abîme à cercles runiques, murs de pierre sombre à colonnes, niches lumineuses et
-- cristaux, plafond en FAUX CIEL (voûte nocturne étoilée, nébuleuses, lune).
-- `frame` : repère de l'origine (sol de la plateforme à y = 0), -Z = sens de progression.
-- cfg : { HalfWidth, Front, Back, Height, Floor } ; accent : couleur des runes et cristaux.
function Models.mysticHall(frame: CFrame, cfg, accent: Color3, parent: Instance, seed: number)
	local rand = rng(seed)
	local hw, front, back, height, floorY = cfg.HalfWidth, cfg.Front, cfg.Back, cfg.Height, cfg.Floor
	local length = front - back
	local midZ = (front + back) / 2
	local t = 3
	local stone = Color3.fromRGB(58, 52, 74)
	local stoneLight = Color3.fromRGB(86, 78, 108)
	local trim = Color3.fromRGB(150, 120, 70)
	local skyColor = Color3.fromRGB(22, 20, 54)

	-- Sol d'abîme et cercles runiques
	part(
		parent,
		"HallFloor",
		Vector3.new(hw * 2 + t * 2, 2, length + t * 2),
		frame * CFrame.new(0, floorY - 1, midZ),
		Color3.fromRGB(26, 22, 40),
		Enum.Material.Slate
	)
	for z = front - 30, back + 20, -60 do
		for _, x in (if hw > 40 then { -hw * 0.5, 0, hw * 0.5 } else { 0 }) do
			local c = frame * CFrame.new(x, floorY + 0.06, z)
			part(
				parent,
				"RuneCircle",
				Vector3.new(0.12, 14, 14),
				c * VERTICAL,
				accent,
				Enum.Material.Neon,
				{ Shape = Enum.PartType.Cylinder, CanCollide = false, NoShadow = true, Transparency = 0.55 }
			)
			part(
				parent,
				"RuneCircleCore",
				Vector3.new(0.14, 12.6, 12.6),
				c * CFrame.new(0, 0.07, 0) * VERTICAL,
				Color3.fromRGB(26, 22, 40),
				Enum.Material.Slate,
				{ Shape = Enum.PartType.Cylinder, CanCollide = false, NoShadow = true }
			)
			for k = 0, 5 do
				part(
					parent,
					"RuneMark",
					Vector3.new(0.8, 0.16, 2.2),
					c * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0.05, -4.2),
					accent,
					Enum.Material.Neon,
					{ CanCollide = false, NoShadow = true }
				)
			end
		end
	end

	-- Murs (gauche, droite, avant, arrière)
	local wallH = height - floorY
	local wallY = floorY + wallH / 2
	for _, side in { -1, 1 } do
		part(
			parent,
			"HallWall",
			Vector3.new(t, wallH, length + t * 2),
			frame * CFrame.new(side * (hw + t / 2), wallY, midZ),
			stone,
			Enum.Material.Slate
		)
	end
	for _, z in { front + t / 2, back - t / 2 } do
		part(
			parent,
			"HallWall",
			Vector3.new(hw * 2 + t * 2 - 0.2, wallH - 0.1, t),
			frame * CFrame.new(0, wallY, z),
			stone,
			Enum.Material.Slate
		)
	end

	-- Colonnes, arcs de niche, runes et cristaux le long des murs latéraux
	local spacing = 24
	local lightEvery = 2
	local index = 0
	for z = front - 8, back + 8, -spacing do
		index += 1
		for _, side in { -1, 1 } do
			local face = frame * CFrame.new(side * hw, 0, z)
			-- Colonne engagée à chapiteau doré
			part(
				parent,
				"HallColumn",
				Vector3.new(2.6, wallH - 0.4, 2.2),
				face * CFrame.new(-side * 1.0, wallY, 0),
				stoneLight,
				Enum.Material.Slate
			)
			part(
				parent,
				"HallColumnCap",
				Vector3.new(3.2, 1.0, 2.8),
				face * CFrame.new(-side * 1.15, height - 2.5, 0),
				trim,
				Enum.Material.Metal
			)
			part(
				parent,
				"HallColumnBase",
				Vector3.new(3.2, 1.2, 2.8),
				face * CFrame.new(-side * 1.15, 0.6 + (if floorY < -2 then floorY else 0), 0),
				trim,
				Enum.Material.Metal
			)
			-- Rune verticale lumineuse entre deux colonnes
			local mid = face * CFrame.new(-side * 0.08, height * 0.45, -spacing / 2)
			part(
				parent,
				"WallRune",
				Vector3.new(0.12, height * 0.5, 0.5),
				mid,
				accent,
				Enum.Material.Neon,
				{ CanCollide = false, NoShadow = true }
			)
			for k = -1, 1 do
				part(
					parent,
					"WallRuneMark",
					Vector3.new(0.14, 0.4, 1.6),
					mid * CFrame.new(0, k * height * 0.14, 0) * CFrame.Angles(math.rad(45), 0, 0),
					accent,
					Enum.Material.Neon,
					{ CanCollide = false, NoShadow = true }
				)
			end
			-- Cristal lumineux sur console (une colonne sur deux)
			if index % lightEvery == 0 then
				local console = face * CFrame.new(-side * 2.6, height * 0.62, 0)
				part(parent, "Console", Vector3.new(2.2, 0.6, 2.2), console, trim, Enum.Material.Metal)
				local crystal = part(
					parent,
					"WallCrystal",
					Vector3.new(0.9, 2.2, 0.9),
					console * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.rad(45), 0),
					accent,
					Enum.Material.Neon,
					{ CanCollide = false, NoShadow = true }
				)
				local light = Instance.new("PointLight")
				light.Color = accent:Lerp(Color3.new(1, 1, 1), 0.35)
				light.Range = 30
				light.Brightness = 1.6
				light.Shadows = false
				light.Parent = crystal
			end
		end
	end
	-- Grands vitraux lumineux aux deux extrémités
	for _, z in { front, back } do
		local dir = if z == front then -1 else 1
		local win = frame * CFrame.new(0, height * 0.5, z + dir * 0.1)
		part(
			parent,
			"EndWindow",
			Vector3.new(math.min(hw, 14), height * 0.55, 0.2),
			win,
			accent:Lerp(Color3.fromRGB(255, 255, 255), 0.2),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true, Transparency = 0.35 }
		)
		part(
			parent,
			"EndWindowFrame",
			Vector3.new(math.min(hw, 14) + 1.6, height * 0.55 + 1.6, 0.4),
			win * CFrame.new(0, 0, -dir * 0.15),
			trim,
			Enum.Material.Metal
		)
	end

	-- Plafond : faux ciel nocturne, bordé d'une corniche dorée (4 bandes, sans superposition)
	part(
		parent,
		"FalseSky",
		Vector3.new(hw * 2 + t * 2, 2, length + t * 2),
		frame * CFrame.new(0, height + 1, midZ),
		skyColor,
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		part(
			parent,
			"SkyCornice",
			Vector3.new(1.4, 1, length),
			frame * CFrame.new(side * (hw - 0.7), height - 0.5, midZ),
			trim,
			Enum.Material.Metal,
			{ CanCollide = false }
		)
		part(
			parent,
			"SkyCornice",
			Vector3.new(hw * 2 - 2.8, 1.1, 1.4),
			frame * CFrame.new(0, height - 0.55, if side < 0 then back + 0.7 else front - 0.7),
			trim,
			Enum.Material.Metal,
			{ CanCollide = false }
		)
	end
	local starCount = math.floor(hw * 2 * length / 18)
	for _ = 1, starCount do
		local x = (rand() - 0.5) * (hw * 2 - 4)
		local z = back + 2 + rand() * (length - 4)
		local d = 0.2 + rand() * 0.45
		part(
			parent,
			"Star",
			Vector3.new(d, d, d),
			frame * CFrame.new(x, height - 0.05 - rand() * 0.4, z),
			if rand() < 0.75 then Color3.fromRGB(255, 250, 235) else accent:Lerp(Color3.new(1, 1, 1), 0.5),
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball, CanCollide = false, NoShadow = true }
		)
	end
	-- Nébuleuses (voiles colorés translucides) et lune
	for n = 1, math.max(3, math.floor(length / 60)) do
		local x = (rand() - 0.5) * hw * 1.2
		local z = back + rand() * length
		local nebula = part(
			parent,
			"Nebula",
			Vector3.new(14 + rand() * 18, 0.2, 10 + rand() * 14),
			frame * CFrame.new(x, height - 1.2 - n % 3 * 0.15, z) * CFrame.Angles(0, rand() * math.pi, 0),
			if n % 2 == 0 then Color3.fromRGB(150, 80, 220) else Color3.fromRGB(60, 170, 200),
			Enum.Material.Neon,
			{ CanCollide = false, NoShadow = true, Transparency = 0.82 }
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = nebula
	end
	local moon = frame * CFrame.new(hw * 0.35, height - 0.6, front - length * 0.3)
	part(
		parent,
		"Moon",
		Vector3.new(0.3, 9, 9),
		moon * VERTICAL,
		Color3.fromRGB(235, 232, 210),
		Enum.Material.Neon,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false, NoShadow = true }
	)
	part(
		parent,
		"MoonShade",
		Vector3.new(0.32, 7.6, 7.6),
		moon * CFrame.new(1.4, -0.14, 1.2) * VERTICAL,
		skyColor,
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false, NoShadow = true }
	)
end

return Models
