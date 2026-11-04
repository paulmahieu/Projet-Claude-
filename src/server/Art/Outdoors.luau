--[[
	Outdoors : habille l'extérieur (prairies entre le château, les bosquets et les bastions).

	- Nappes d'herbe (matériau LeafyGrass, plusieurs verts) et quelques coins de terre : l'herbe
	  n'est plus un aplat uniforme.
	- Touffes d'herbe (brins en biseau), massifs de fleurs, cailloux, champignons près des
	  bosquets, troncs couchés, arbres isolés dans les grandes prairies.
	- Mares : eau du Terrain Roblox (vagues, reflets ; remplie par PlotService), fond vaseux,
	  margelle de pierres, nénuphars et roseaux.
	Tout est décoratif : non collisionnable, ignoré par les rayons et sans ombre pour les petites
	pièces (performances mobiles). Disposition déterministe (même rendu à chaque génération) et
	jamais sur le château, les allées, les bastions (extensions comprises), les bosquets ni les
	arènes.
]]

local Outdoors = {}

local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- l'axe d'un cylindre Roblox est X

-- Proches du vert du sol (105, 161, 82) : variation douce, pas de taches contrastées.
local GRASS = {
	Color3.fromRGB(98, 152, 74),
	Color3.fromRGB(112, 166, 84),
	Color3.fromRGB(102, 148, 70),
	Color3.fromRGB(118, 162, 80),
}
local BLADES = { Color3.fromRGB(70, 140, 55), Color3.fromRGB(96, 165, 66), Color3.fromRGB(124, 182, 78) }
local PETALS = {
	Color3.fromRGB(250, 248, 240),
	Color3.fromRGB(255, 214, 70),
	Color3.fromRGB(230, 80, 80),
	Color3.fromRGB(170, 120, 230),
	Color3.fromRGB(110, 160, 250),
	Color3.fromRGB(255, 150, 190),
}

local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material, opts)
	local p = Instance.new(if opts and opts.Wedge then "WedgePart" else "Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = opts ~= nil and opts.Shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts and opts.Shape then
		(p :: Part).Shape = opts.Shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if opts and opts.Transparency then
		p.Transparency = opts.Transparency
	end
	p.Parent = parent
	return p
end

-- Disque plat posé au sol (dessus à la hauteur `top`).
local function disc(parent, name, radius: number, x: number, z: number, top: number, color, material)
	return deco(
		parent,
		name,
		Vector3.new(0.08, radius * 2, radius * 2),
		CFrame.new(x, top - 0.04, z) * VERTICAL,
		color,
		material,
		{ Shape = Enum.PartType.Cylinder }
	)
end

-- Zones interdites ------------------------------------------------------------------------------

local function makeBlocked(cfg)
	local Game, Harvest = cfg.Game, cfg.Harvest
	local plots = {}
	for i = 1, Game.PlotCount do
		local angle = (i - 1) / Game.PlotCount * math.pi * 2
		local center = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Game.PlotRingRadius
		table.insert(plots, CFrame.lookAt(center, Vector3.zero):Inverse())
	end
	local groves = {}
	for i = 1, Game.PlotCount do
		local angle = (i - 0.5) / Game.PlotCount * math.pi * 2
		table.insert(groves, Vector3.new(math.cos(angle), 0, math.sin(angle)) * Harvest.RingRadius)
	end
	local half = Game.PlotSize / 2
	local roadOuter = Game.RingRoadRadius + Game.RingRoadWidth / 2
	local pathEnd = -(Game.PlotRingRadius - roadOuter) - 2
	local arenas = cfg.Arenas or {}
	return function(p: Vector3, margin: number): boolean
		local r = Vector3.new(p.X, 0, p.Z).Magnitude
		if r < roadOuter + 8 + margin or r > 465 - margin then
			return true
		end
		for _, inv in plots do
			local l = inv * p
			-- Parcelle et extensions (jusqu'à z = 205 + muret), allée vers la route.
			if math.abs(l.X) < 76 + margin and l.Z > -half - 6 - margin and l.Z < 214 + margin then
				return true
			end
			if math.abs(l.X) < 8 + margin and l.Z < -half and l.Z > pathEnd - margin then
				return true
			end
		end
		for _, g in groves do
			if (Vector3.new(p.X, 0, p.Z) - g).Magnitude < 27 + margin then
				return true
			end
		end
		for _, a in arenas do
			if (Vector3.new(p.X, 0, p.Z) - a).Magnitude < 78 + margin then
				return true
			end
		end
		return false
	end,
		groves
end

-- Éléments ------------------------------------------------------------------------------------

local function tuft(parent, x: number, z: number, rand)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, rand() * math.pi * 2, 0)
	local h = 1.3 + rand() * 0.9
	for k = 0, 2 do
		local bh = h * (0.75 + rand() * 0.35)
		deco(
			parent,
			"GrassBlade",
			Vector3.new(0.14, bh, 0.6),
			base
				* CFrame.Angles(0, k * math.rad(120) + rand() * 0.5, 0)
				* CFrame.new(0, bh / 2, 0.12)
				* CFrame.Angles(math.rad(-8 - rand() * 10), 0, 0),
			BLADES[1 + math.floor(rand() * #BLADES)],
			Enum.Material.SmoothPlastic,
			{ Wedge = true }
		)
	end
end

local function flower(parent, x: number, z: number, color: Color3, rand)
	local h = 0.6 + rand() * 0.5
	local base = CFrame.new(x, 0, z)
	deco(parent, "FlowerStem", Vector3.new(0.1, h, 0.1), base * CFrame.new(0, h / 2, 0), BLADES[1])
	local head = base * CFrame.new(0, h + 0.04, 0)
	deco(
		parent,
		"FlowerPetals",
		Vector3.new(0.1, 0.6, 0.6),
		head * VERTICAL,
		color,
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder }
	)
	deco(
		parent,
		"FlowerHeart",
		Vector3.new(0.24, 0.24, 0.24),
		head * CFrame.new(0, 0.07, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Ball }
	)
end

local function pebble(parent, x: number, z: number, size: number, rand)
	-- Bloc tourné au hasard et à moitié enterré : facettes irrégulières de vrai caillou.
	deco(
		parent,
		"Pebble",
		Vector3.new(size, size * (0.6 + rand() * 0.3), size * (0.7 + rand() * 0.3)),
		CFrame.new(x, size * 0.12, z) * CFrame.Angles(rand() * math.pi, rand() * math.pi, rand() * math.pi),
		Color3.fromRGB(128, 126, 120):Lerp(Color3.fromRGB(165, 160, 150), rand()),
		Enum.Material.Slate
	)
end

local function mushroom(parent, x: number, z: number, rand)
	local h = 0.5 + rand() * 0.4
	local base = CFrame.new(x, 0, z)
	deco(
		parent,
		"MushroomStem",
		Vector3.new(0.22, h, 0.22),
		base * CFrame.new(0, h / 2, 0),
		Color3.fromRGB(240, 232, 215)
	)
	deco(
		parent,
		"MushroomCap",
		Vector3.new(0.3, 0.75, 0.75),
		base * CFrame.new(0, h + 0.05, 0) * VERTICAL,
		if rand() < 0.7 then Color3.fromRGB(210, 50, 45) else Color3.fromRGB(180, 120, 70),
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder }
	)
	deco(
		parent,
		"MushroomDot",
		Vector3.new(0.14, 0.14, 0.14),
		base * CFrame.new(0.12, h + 0.2, -0.1),
		Color3.fromRGB(250, 248, 240),
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Ball }
	)
end

local function fallenLog(parent, x: number, z: number, rand)
	local len = 5 + rand() * 3
	local d = 1 + rand() * 0.4
	local cf = CFrame.new(x, d / 2 - 0.1, z) * CFrame.Angles(0, rand() * math.pi, 0)
	deco(
		parent,
		"Log",
		Vector3.new(len, d, d),
		cf,
		Color3.fromRGB(96, 66, 42),
		Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder, Shadow = true }
	)
	deco(
		parent,
		"LogMoss",
		Vector3.new(len * 0.6, 0.2, d * 0.7),
		cf * CFrame.new(-len * 0.1, d / 2 - 0.02, 0),
		Color3.fromRGB(92, 130, 60),
		Enum.Material.Grass
	)
	deco(
		parent,
		"LogEnd",
		Vector3.new(0.06, d * 0.85, d * 0.85),
		cf * CFrame.new(len / 2 + 0.01, 0, 0),
		Color3.fromRGB(176, 136, 90),
		Enum.Material.Wood,
		{ Shape = Enum.PartType.Cylinder }
	)
end

-- Mare : fond vaseux, margelle de pierres, nénuphars, roseaux (l'eau est du Terrain).
local function pond(parent, x: number, z: number, radius: number, rand)
	disc(parent, "PondBed", radius + 0.5, x, z, 0.06, Color3.fromRGB(62, 70, 48), Enum.Material.Mud)
	local count = math.floor(radius * 1.6)
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2 + rand() * 0.1
		local r = radius + 0.7 + rand() * 0.5
		local s = 1.6 + rand() * 1.4
		local h = 0.6 + rand() * 0.5
		deco(
			parent,
			"PondStone",
			Vector3.new(s, h * 1.6, s * (0.6 + rand() * 0.3)),
			CFrame.new(x + math.cos(a) * r, h * 0.2, z + math.sin(a) * r)
				* CFrame.Angles(0, -a + (rand() - 0.5) * 0.8, 0)
				* CFrame.Angles(math.rad(35 + rand() * 20), 0, (rand() - 0.5) * 0.5),
			Color3.fromRGB(120, 118, 112):Lerp(Color3.fromRGB(160, 156, 146), rand()),
			Enum.Material.Slate,
			{ Shadow = true }
		)
	end
	-- Galets autour de la margelle
	for _ = 1, math.floor(radius * 1.2) do
		local a = rand() * math.pi * 2
		local r = radius + 2.2 + rand()
		pebble(parent, x + math.cos(a) * r, z + math.sin(a) * r, 0.4 + rand() * 0.5, rand)
	end
	for _ = 1, 6 do
		local a, r = rand() * math.pi * 2, rand() * (radius - 2.5)
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		deco(
			parent,
			"LilyPad",
			Vector3.new(0.06, 1.6, 1.6),
			CFrame.new(px, 0.86, pz) * VERTICAL,
			Color3.fromRGB(70, 140, 60),
			Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Cylinder }
		)
		if rand() < 0.4 then
			deco(
				parent,
				"LilyFlower",
				Vector3.new(0.4, 0.4, 0.4),
				CFrame.new(px + 0.3, 1.02, pz),
				Color3.fromRGB(255, 190, 215),
				Enum.Material.SmoothPlastic,
				{ Shape = Enum.PartType.Ball }
			)
		end
	end
	for _ = 1, 4 do
		local a = rand() * math.pi * 2
		local cx, cz = x + math.cos(a) * (radius - 0.6), z + math.sin(a) * (radius - 0.6)
		for _ = 1, 5 do
			local h = 2 + rand() * 1.2
			local rx, rz = cx + (rand() - 0.5) * 1.6, cz + (rand() - 0.5) * 1.6
			local tilt = CFrame.Angles((rand() - 0.5) * 0.25, 0, (rand() - 0.5) * 0.25)
			local base = CFrame.new(rx, 0, rz) * tilt
			deco(
				parent,
				"Reed",
				Vector3.new(0.12, h, 0.12),
				base * CFrame.new(0, h / 2, 0),
				Color3.fromRGB(110, 150, 70)
			)
			deco(
				parent,
				"Cattail",
				Vector3.new(0.26, 0.6, 0.26),
				base * CFrame.new(0, h - 0.5, 0),
				Color3.fromRGB(110, 72, 42),
				Enum.Material.Fabric
			)
		end
	end
end

-- Construction -------------------------------------------------------------------------------

-- cfg : { Game, Harvest, Arenas = { Vector3 } }. Models : module Art/Models (arbres).
-- Retourne la liste des mares { Position: Vector3, Radius: number } pour l'eau du Terrain.
function Outdoors.build(parent: Instance, cfg, Models)
	local rand = Models.rng(4242)
	local blocked, groves = makeBlocked(cfg)
	local function spot(rMin: number, rMax: number, margin: number): Vector3?
		for _ = 1, 30 do
			local a = rand() * math.pi * 2
			-- Répartition uniforme en surface (racine) entre rMin et rMax.
			local r = math.sqrt(rMin * rMin + rand() * (rMax * rMax - rMin * rMin))
			local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			if not blocked(p, margin) then
				return p
			end
		end
		return nil
	end
	local function folder(name: string)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end

	-- Mares (trois, dans les grandes prairies entre les bastions)
	local ponds = {}
	local pondFolder = folder("Ponds")
	for _ = 1, 3 do
		local radius = 11 + rand() * 5
		local p = spot(250, 430, radius + 8)
		if p then
			local clash = false
			for _, other in ponds do
				if (other.Position - p).Magnitude < 70 then
					clash = true
				end
			end
			if not clash then
				pond(pondFolder, p.X, p.Z, radius, rand)
				table.insert(ponds, { Position = p, Radius = radius })
			end
		end
	end
	local function nearPond(p: Vector3, margin: number): boolean
		for _, other in ponds do
			if (other.Position - p).Magnitude < other.Radius + 3 + margin then
				return true
			end
		end
		return false
	end

	-- Nappes d'herbe : trois hauteurs (0,05 / 0,09 / 0,13) ; deux nappes de même hauteur ne se
	-- chevauchent jamais (pas de scintillement).
	local patches = folder("GrassPatches")
	-- Chaque nappe est une forme irrégulière faite de 3 ou 4 disques qui se chevauchent ; chaque
	-- disque a sa propre hauteur parmi 6 (0,04 à 0,19) et deux disques de même hauteur ne se
	-- touchent jamais : bords festonnés, aucun scintillement.
	local layers = { {}, {}, {}, {}, {}, {} }
	local nextLayer = 0
	for _ = 1, 70 do
		local size = 8 + rand() * 12
		local p = spot(90, 455, size * 0.6)
		if p and not nearPond(p, size) then
			local color = GRASS[1 + math.floor(rand() * #GRASS)]
			for _ = 1, 3 + math.floor(rand() * 2) do
				local r = size * (0.45 + rand() * 0.4)
				local a, d = rand() * math.pi * 2, rand() * size * 0.55
				local c = p + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				nextLayer = nextLayer % 6 + 1
				local free = true
				for _, q in layers[nextLayer] do
					if (q.P - c).Magnitude < q.R + r + 0.5 then
						free = false
						break
					end
				end
				if free and not blocked(c, r * 0.3) then
					table.insert(layers[nextLayer], { P = c, R = r })
					disc(patches, "GrassPatch", r, c.X, c.Z, 0.01 + nextLayer * 0.03, color, Enum.Material.Grass)
				end
			end
		end
	end
	-- Coins de terre battue (au-dessus des nappes)
	for _ = 1, 14 do
		local radius = 3 + rand() * 3
		local p = spot(95, 450, radius)
		if p and not nearPond(p, radius) then
			disc(patches, "DirtPatch", radius, p.X, p.Z, 0.23, Color3.fromRGB(128, 104, 74), Enum.Material.Ground)
		end
	end

	-- Touffes d'herbe en petits groupes
	-- Plus denses là où l'on marche (entre le château, les bosquets et les bastions).
	local tufts = folder("GrassTufts")
	for i = 1, 230 do
		local p = if i % 4 == 0 then spot(250, 455, 2) else spot(84, 250, 2)
		if p and not nearPond(p, 0) then
			for _ = 1, 2 + math.floor(rand() * 3) do
				tuft(tufts, p.X + (rand() - 0.5) * 3.5, p.Z + (rand() - 0.5) * 3.5, rand)
			end
		end
	end

	-- Massifs de fleurs (une ou deux couleurs par massif)
	local flowers = folder("Flowers")
	for _ = 1, 55 do
		local p = spot(90, 450, 3)
		if p and not nearPond(p, 1) then
			local c1 = PETALS[1 + math.floor(rand() * #PETALS)]
			local c2 = PETALS[1 + math.floor(rand() * #PETALS)]
			for k = 1, 4 + math.floor(rand() * 3) do
				local a, r = rand() * math.pi * 2, rand() * 2.2
				flower(flowers, p.X + math.cos(a) * r, p.Z + math.sin(a) * r, if k % 2 == 0 then c1 else c2, rand)
			end
		end
	end

	-- Cailloux et troncs couchés
	local rocks = folder("Stones")
	for _ = 1, 40 do
		local p = spot(88, 455, 2)
		if p and not nearPond(p, 1) then
			for _ = 1, 2 + math.floor(rand() * 2) do
				pebble(rocks, p.X + (rand() - 0.5) * 2.4, p.Z + (rand() - 0.5) * 2.4, 0.5 + rand() * 0.8, rand)
			end
		end
	end
	for _ = 1, 8 do
		local p = spot(150, 450, 6)
		if p and not nearPond(p, 4) then
			fallenLog(rocks, p.X, p.Z, rand)
		end
	end

	-- Champignons à la lisière des bosquets
	local shrooms = folder("Mushrooms")
	for _, g in groves do
		for _ = 1, 2 do
			local a = rand() * math.pi * 2
			local p = g + Vector3.new(math.cos(a), 0, math.sin(a)) * (29 + rand() * 4)
			if not blocked(p, 0) then
				for _ = 1, 3 do
					mushroom(shrooms, p.X + (rand() - 0.5) * 1.8, p.Z + (rand() - 0.5) * 1.8, rand)
				end
			end
		end
	end

	-- Bosquets d'agrément dans les grandes prairies (au-delà des bastions) : 2 ou 3 arbres et
	-- des buissons, pas de sapin enneigé.
	local trees = folder("MeadowTrees")
	local copses = {}
	local kinds = { "Oak", "Birch", "Maple", "Oak", "Maple" }
	local n = 0
	for _ = 1, 12 do
		local c = spot(255, 400, 14)
		if c and not nearPond(c, 12) then
			local clash = false
			for _, q in copses do
				if (q - c).Magnitude < 45 then
					clash = true
				end
			end
			if not clash then
				table.insert(copses, c)
				for k = 1, 2 + math.floor(rand() * 2) do
					n += 1
					local a = k * 2.3 + rand()
					local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * (if k == 1 then 0 else 7 + rand() * 3)
					Models.tree(CFrame.new(p), kinds[1 + n % #kinds], n * 3.7).Parent = trees
				end
				for k = 1, 2 do
					local a = rand() * math.pi * 2
					Models.bush(CFrame.new(c + Vector3.new(math.cos(a), 0, math.sin(a)) * 11), trees, n * 10 + k)
				end
			end
		end
	end

	return ponds
end

return Outdoors
