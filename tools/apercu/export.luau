local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local root = process.args[1]
local src = fs.readFile(root .. "/src/server/Art/Models.luau")
-- Simulacre minimal de `game` : aucun asset importé dans l'aperçu.
local fakeGame = {
	GetService = function()
		return {
			FindFirstChild = function()
				return nil
			end,
		}
	end,
}
local env = setmetatable({
	Instance = roblox.Instance,
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	game = fakeGame,
}, { __index = _G })
local Models = luau.load(src, { environment = env, debugName = "Models" })()
local function loadModule(path, name)
	return luau.load(fs.readFile(root .. path), { environment = env, debugName = name })()
end
local function loadData(path, name)
	return luau.load(fs.readFile(root .. path), { debugName = name })()
end
local PetModels = loadModule("/src/shared/PetModels.luau", "PetModels")
local PetsCfg = loadData("/src/shared/Config/Pets.luau", "Pets")
local BossesCfg = loadData("/src/shared/Config/Bosses.luau", "Bosses")

local out = {}
local function dump(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			local rx, ry, rz = cf:ToEulerAnglesXYZ()
			local shape = "Block"
			if p:FindFirstChildOfClass("SpecialMesh") then
				shape = "Ball" -- ellipsoïde
			elseif p.ClassName == "WedgePart" then
				shape = "Wedge"
			elseif p.ClassName == "Part" then
				shape = p.Shape.Name
			end
			if not (p:GetAttribute("Depletable") and false) then
				table.insert(out, {
					s = { p.Size.X, p.Size.Y, p.Size.Z },
					p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
					r = { rx, ry, rz },
					c = { p.Color.R, p.Color.G, p.Color.B },
					shape = shape,
					name = p.Name,
					neon = p.Material.Name == "Neon",
					mat = p.Material.Name,
					t = p.Transparency,
				})
			end
		end
	end
end

-- Scène : choisie par l'argument 2 ("base" ou "v2")
local scene = process.args[2] or "base"
local function at(x, z)
	return roblox.CFrame.new(x, 0, z)
end
local V = roblox.Vector3.new
if scene == "machines" then
	-- Les 5 machines (niveau 3, puis 5 pour la dernière) et un socle de construction.
	local lvl = tonumber(process.args[3]) or 3
	for i, kind in { "LumberMill", "StoneCrusher", "OreDrill", "EtherCondenser", "RoyalForge" } do
		dump((Models.machine(kind, at((i - 3) * 16, 0), lvl)))
	end
	dump((Models.pedestal(at(48, -6))))
elseif scene == "etalon" then
	-- Étalon de luxe : face, trois quarts, profil.
	local holder = roblox.Instance.new("Model")
	local def
	for _, d in PetsCfg.List do
		if d.Id == "LuxuryStallion" then
			def = d
		end
	end
	for i, angle in { 0, -35, -90 } do
		local model = PetModels.build(def, roblox.Color3.new(1, 1, 1))
		local base = roblox.CFrame.new((i - 2) * 3.2, 1.6, 0) * roblox.CFrame.Angles(0, math.rad(angle), 0)
		local pivot = model.PrimaryPart.CFrame
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame = base * pivot:Inverse() * p.CFrame
			end
		end
		model.Parent = holder
	end
	dump(holder)
elseif scene == "pantin" then
	-- Pantin chevalier : face, profil, dos (et une version de zone royale).
	local holder = roblox.Instance.new("Model")
	local blue = roblox.Color3.fromRGB(46, 84, 170)
	Models.dummy(roblox.CFrame.new(-6, 0, 0) * roblox.CFrame.Angles(0, math.pi, 0), holder, blue)
	Models.dummy(roblox.CFrame.new(0, 0, 0) * roblox.CFrame.Angles(0, math.pi / 2, 0), holder, blue)
	Models.dummy(roblox.CFrame.new(6, 0, 0), holder, blue)
	Models.dummy(
		roblox.CFrame.new(12, 0, 0) * roblox.CFrame.Angles(0, math.pi, 0),
		holder,
		roblox.Color3.fromRGB(212, 160, 50)
	)
	dump(holder)
elseif scene == "decors" then
	-- Nouveautés liées au pack : torche, minerai de cristal, portail du bastion à battants.
	local GameCfg = loadData("/src/shared/Config/Game.luau", "Game")
	local holder = roblox.Instance.new("Model")
	local floor = roblox.Instance.new("Part")
	floor.Size = V(GameCfg.PlotSize, 1, GameCfg.PlotSize)
	floor.CFrame = roblox.CFrame.new(0, 0.5, 0)
	floor.Color = roblox.Color3.fromRGB(150, 142, 128)
	floor.Parent = holder
	local base = roblox.CFrame.new(0, 1, 0)
	Models.plotDecor(base, GameCfg.PlotSize, holder)
	local gateBase = base * roblox.CFrame.new(0, 0, -GameCfg.PlotSize / 2 + 0.7)
	local doors = Models.gateDoors(gateBase, 12, 7, holder)
	Models.setDoors(doors, tonumber(process.args[3] or "1") or 1)
	dump(holder)
	local t = roblox.Instance.new("Model")
	Models.torch(base * roblox.CFrame.new(-8, 0, -36), t)
	Models.torch(base * roblox.CFrame.new(8, 0, -36), t)
	dump(t)
	dump(Models.crystalOre(base * roblox.CFrame.new(-14, 0, -30), 3))
elseif scene == "enemies" then
	-- Un groupe d'ennemis par image (argument 3) : petits, frontieres, elites, regionaux, majeurs.
	local StreetCfg = loadData("/src/shared/Config/Street.luau", "Street")
	local groups = {
		petits = { "ThornJelly", "RuinSpider", "ScrapGoblin" },
		frontieres = { "SkeletonSentinel", "BrambleWolf", "AshCultist" },
		elites = { "ShieldbreakerOrc", "QuarryGolem", "ThornKnight" },
		regionaux = { "GoblinKing", "RootGuardian", "MarshHydra" },
		majeurs = { "FrostTitan", "FurnaceDragon", "VoidColossus" },
	}
	local byId = {}
	for _, d in StreetCfg.Kinds do
		byId[d.Id] = d
	end
	for _, d in StreetCfg.Bosses do
		byId[d.Id] = d
	end
	local list = groups[process.args[3] or "petits"]
	local spacing = ({ petits = 7, frontieres = 9, elites = 13, regionaux = 20, majeurs = 26 })[process.args[3] or "petits"]
	for i, id in list do
		local model = Models.enemy(
			byId[id],
			roblox.CFrame.new((i - 2) * spacing, 0, 0) * roblox.CFrame.Angles(0, math.rad(-25), 0),
			1,
			false
		)
		dump(model)
	end
elseif scene == "pets" then
	-- Une rareté par image (argument 3) : 5 compagnons alignés, vus de trois quarts.
	local rarity = process.args[3] or "Common"
	local floor = roblox.Instance.new("Part")
	floor.Size = V(40, 1, 16)
	floor.CFrame = roblox.CFrame.new(0, -0.5, 0)
	floor.Color = roblox.Color3.fromRGB(226, 220, 210)
	floor.Material = roblox.Enum.Material.SmoothPlastic
	dump(floor)
	local i = 0
	for _, def in PetsCfg.List do
		if def.Rarity == rarity then
			i += 1
			local r = PetsCfg.Rarities[def.Rarity].Color
			local model = PetModels.build(def, roblox.Color3.fromRGB(r[1], r[2], r[3]))
			local base = roblox.CFrame.new(-8 + (i - 1) * 4, 1.35, 0) * roblox.CFrame.Angles(0, math.rad(-35), 0)
			local pivot = model.PrimaryPart.CFrame
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					p.CFrame = base * pivot:Inverse() * p.CFrame
				end
			end
			dump(model)
		end
	end
elseif scene == "eggs" then
	local floor = roblox.Instance.new("Part")
	floor.Size = V(60, 1, 20)
	floor.CFrame = roblox.CFrame.new(0, -0.5, 0)
	floor.Color = roblox.Color3.fromRGB(150, 142, 128)
	floor.Material = roblox.Enum.Material.Slate
	dump(floor)
	for i, egg in PetsCfg.Eggs do
		local c = egg.Color
		local base = roblox.CFrame.new(-21 + (i - 1) * 8.4, 0, 0) * roblox.CFrame.Angles(0, math.pi, 0)
		dump((Models.eggStand(base, roblox.Color3.fromRGB(c[1], c[2], c[3]), egg.Product ~= nil, egg.Design)))
	end
elseif scene == "trees" then
	local floor = roblox.Instance.new("Part")
	floor.Size = V(110, 1, 40)
	floor.CFrame = roblox.CFrame.new(0, -0.5, 0)
	floor.Color = roblox.Color3.fromRGB(110, 170, 80)
	dump(floor)
	-- Les six arbres des planches, du commun au plus rare.
	local kinds = { "Oak", "Birch", "Fir", "Maple", "Ancient", "Willow" }
	for i, kind in kinds do
		dump(Models.tree(at(-35 + (i - 1) * 14, 0), kind, i))
	end
elseif scene == "plot" then
	local GameCfg = loadData("/src/shared/Config/Game.luau", "Game")
	local StructuresCfg = loadData("/src/shared/Config/Structures.luau", "Structures")
	local holder = roblox.Instance.new("Model")
	local floor = roblox.Instance.new("Part")
	floor.Size = V(GameCfg.PlotSize, 1, GameCfg.PlotSize)
	floor.CFrame = roblox.CFrame.new(0, 0.5, 0)
	floor.Color = roblox.Color3.fromRGB(150, 142, 128)
	floor.Parent = holder
	local base = roblox.CFrame.new(0, 1, 0)
	Models.plotDecor(base, GameCfg.PlotSize, holder)
	dump(holder)
	dump((Models.etherCore(base * roblox.CFrame.new(0, 0, 8))))
	for _, def in StructuresCfg do
		local size = V(def.Size[1], def.Size[2], def.Size[3])
		local c = def.Color
		dump(
			Models.structure(
				def.Id,
				base * roblox.CFrame.new(def.Offset[1], 0, def.Offset[2]),
				size,
				roblox.Color3.fromRGB(c[1], c[2], c[3]),
				roblox.Enum.Material.Slate
			)
		)
		for _, pos in def.Effects.Stations or {} do
			dump((Models.trainingMat(base * roblox.CFrame.new(pos[1], 0.3, pos[2]), def.Effects.StationTier)))
		end
	end
elseif scene == "land" then
	-- Parcelle agrandie : 3 extensions achetées (pavées, machines), 3 en friche (barrières).
	local GameCfg = loadData("/src/shared/Config/Game.luau", "Game")
	local StructuresCfg = loadData("/src/shared/Config/Structures.luau", "Structures")
	local LandCfg = loadData("/src/shared/Config/Land.luau", "Land")
	local Formulas = loadData("/src/shared/Formulas.luau", "Formulas")
	local holder = roblox.Instance.new("Model")
	local floor = roblox.Instance.new("Part")
	floor.Size = V(GameCfg.PlotSize, 1, GameCfg.PlotSize)
	floor.CFrame = roblox.CFrame.new(0, 0.5, 0)
	floor.Color = roblox.Color3.fromRGB(150, 142, 128)
	floor.Parent = holder
	local base = roblox.CFrame.new(0, 1, 0)
	Models.plotDecor(base, GameCfg.PlotSize, holder)
	dump(holder)
	dump((Models.etherCore(base * roblox.CFrame.new(0, 0, 8))))
	for _, def in StructuresCfg do
		local size = V(def.Size[1], def.Size[2], def.Size[3])
		local c = def.Color
		dump(
			Models.structure(
				def.Id,
				base * roblox.CFrame.new(def.Offset[1], 0, def.Offset[2]),
				size,
				roblox.Color3.fromRGB(c[1], c[2], c[3]),
				roblox.Enum.Material.Slate
			)
		)
	end
	local level = 3
	local owned = Formulas.landOwned(LandCfg, level)
	local land = roblox.Instance.new("Model")
	for _, area in LandCfg.Areas do
		local f = roblox.Instance.new("Folder")
		f.Parent = land
		local fl, fallow = Models.landFloor(base, area.Rect, f)
		if owned[area.Id] then
			fl.Color = roblox.Color3.fromRGB(150, 142, 128)
			fallow:Destroy()
		end
	end
	for _, seg in Formulas.landWalls(LandCfg) do
		Models.landWall(base, seg.X1, seg.Z1, seg.X2, seg.Z2, land)
	end
	for _, o in LandCfg.Openings do
		if not (owned[o.A] and owned[o.B]) then
			Models.landBarrier(base, o.X, o.Z, o.Along, LandCfg.OpeningWidth).Parent = land
		end
	end
	dump(land)
	local n = 0
	for _, area in LandCfg.Areas do
		if owned[area.Id] then
			for _, slot in area.Slots do
				n += 1
				local cf = base * roblox.CFrame.new(slot.X, 0, slot.Z)
				if n < 4 then
					dump((Models.machine(slot.Machine, cf, n + 1)))
				else
					dump((Models.pedestal(cf)))
				end
			end
		end
	end
	-- Aperçu des machines restantes au fond (une de chaque).
	for i, kind in { "EtherCondenser", "RoyalForge" } do
		dump((Models.machine(kind, base * roblox.CFrame.new(-25 + i * 40 - 40 + 20, 0, 146), 5)))
	end
elseif scene == "castle" then
	local GameCfg = loadData("/src/shared/Config/Game.luau", "Game")
	local BossesCfg2 = loadData("/src/shared/Config/Bosses.luau", "Bosses")
	local StreetCfg = loadData("/src/shared/Config/Street.luau", "Street")
	local FarmCfg = loadData("/src/shared/Config/Farm.luau", "Farm")
	local holder = roblox.Instance.new("Model")
	Models.castle(holder, GameCfg)
	Models.hubPlaza(holder, 28)
	Models.hubDecor(holder, 28)
	dump(holder)
	local function lookCenter(pos)
		return roblox.CFrame.lookAt(V(pos[1], 1, pos[2]), V(0, 1, 0))
	end
	local colors = { roblox.Color3.fromRGB(90, 170, 70), roblox.Color3.fromRGB(120, 210, 255) }
	for i, boss in BossesCfg2 do
		dump((Models.portal(lookCenter(boss.Portal), colors[i])))
	end
	dump((Models.portal(lookCenter(StreetCfg.Portal), roblox.Color3.fromRGB(220, 70, 70))))
	dump((Models.portal(lookCenter(FarmCfg.Portal), roblox.Color3.fromRGB(110, 210, 255))))
	for _, egg in PetsCfg.Eggs do
		local c = egg.Color
		dump(
			(
				Models.eggStand(
					lookCenter(egg.Position),
					roblox.Color3.fromRGB(c[1], c[2], c[3]),
					egg.Product ~= nil,
					egg.Design
				)
			)
		)
	end
elseif scene == "hub" then
	local holder = roblox.Instance.new("Model")
	-- disque du hub (joints)
	local hub = roblox.Instance.new("Part")
	hub.Shape = roblox.Enum.PartType.Cylinder
	hub.Size = V(1, 56, 56)
	hub.CFrame = roblox.CFrame.new(0, 0.5, 0) * roblox.CFrame.Angles(0, 0, math.rad(90))
	hub.Color = roblox.Color3.fromRGB(88, 90, 102)
	hub.Parent = holder
	Models.hubPlaza(holder, 28)
	dump(holder)
	local function lookCenter(x, z)
		return roblox.CFrame.lookAt(V(x, 1, z), V(0, 1, 0))
	end
	dump((Models.portal(lookCenter(-12, 22), roblox.Color3.fromRGB(90, 170, 70))))
	dump((Models.portal(lookCenter(0, 24), roblox.Color3.fromRGB(220, 70, 70))))
	dump((Models.portal(lookCenter(12, 22), roblox.Color3.fromRGB(120, 210, 255))))
	for i, egg in PetsCfg.Eggs do
		local c = egg.Color
		dump((Models.eggStand(lookCenter(egg.Position[1], egg.Position[2]), roblox.Color3.fromRGB(c[1], c[2], c[3]))))
	end
	dump((Models.rebirthShrine(roblox.CFrame.new(40, 0, -10) * roblox.CFrame.Angles(0, math.rad(-90), 0))))
elseif scene == "farm" then
	local FarmCfg = loadData("/src/shared/Config/Farm.luau", "Farm")
	local Formulas = loadData("/src/shared/Formulas.luau", "Formulas")
	local holder = roblox.Instance.new("Model")
	Models.farmIsland(roblox.CFrame.new(0, 0, 0), FarmCfg, Formulas.zoneCenter, holder)
	Models.mysticHall(roblox.CFrame.new(0, 0, 0), FarmCfg.Hall, roblox.Color3.fromRGB(110, 210, 255), holder, 13)
	-- Couleurs telles qu'un joueur à 3 renaissances les voit (vert / rouge / or).
	for _, p in holder:GetDescendants() do
		local i = p:GetAttribute("ZoneIndex")
		if i then
			local zone = FarmCfg.Zones[i]
			p.Color = if zone.PassKey
				then roblox.Color3.fromRGB(255, 205, 80)
				elseif zone.Rebirths <= 3 then roblox.Color3.fromRGB(90, 230, 120)
				else roblox.Color3.fromRGB(230, 70, 60)
		end
	end
	dump(holder)
elseif scene == "street" then
	local StreetCfg = loadData("/src/shared/Config/Street.luau", "Street")
	local cfg = table.clone(StreetCfg)
	cfg.Sections = 3
	local origin = roblox.CFrame.lookAt(V(0, 0, 0), V(0, 0, -1)) -- la rue part vers -Z
	local holder = roblox.Instance.new("Model")
	Models.street(origin, cfg, holder)
	local hallCfg = table.clone(StreetCfg.Hall)
	hallCfg.Back = -(cfg.Sections * cfg.SectionLength) - 4
	Models.mysticHall(origin, hallCfg, roblox.Color3.fromRGB(255, 110, 90), holder, 7)
	dump(holder)
	for i, kind in StreetCfg.Kinds do
		dump(
			(
				Models.enemy(
					kind,
					origin * roblox.CFrame.new(-9 + i * 4, 0, -24) * roblox.CFrame.Angles(0, math.pi, 0),
					kind.Scale,
					false
				)
			)
		)
	end
	dump(
		(
			Models.enemy(
				StreetCfg.Kinds[2],
				origin * roblox.CFrame.new(0, 0, -40) * roblox.CFrame.Angles(0, math.pi, 0),
				1,
				true
			)
		)
	)
	-- Porte locale (rendue côté client dans le jeu)
	local gate = roblox.Instance.new("Part")
	gate.Size = V(cfg.Width - 2, 12, 1)
	gate.CFrame = origin * roblox.CFrame.new(0, 6, -cfg.SectionLength * 2)
	gate.Color = roblox.Color3.fromRGB(255, 70, 70)
	gate.Transparency = 0.5
	local g = roblox.Instance.new("Model")
	gate.Parent = g
	dump(g)
elseif scene == "base" then
	dump(Models.tree(at(-30, -40), 1, 1))
	dump(Models.tree(at(-20, -40), 2, 2))
	dump(Models.tree(at(-10, -40), 3, 3))
	dump((Models.rock(at(0, -40), 4)))
	dump((Models.trainingMat(at(12, -40), 1)))
	dump((Models.trainingMat(at(22, -40), 2)))
	dump((Models.pedestal(at(32, -40))))
	dump((Models.etherCore(at(0, -20))))
	dump(Models.structure("TrainingGround", at(-22, 0), V(26, 0.4, 14)))
	dump(Models.structure("RuneMats", at(22, 0), V(26, 0.4, 14)))
	dump(Models.structure("Sawmill", at(-28, 25), V(14, 8, 12)))
	dump(Models.structure("Quarry", at(28, 25), V(14, 8, 12)))
	dump(Models.structure("Watchtower", at(0, 30), V(8, 22, 8)))
	dump(Models.structure("Palisade", at(0, 48), V(86, 8, 2)))
else
	dump((Models.boss(BossesCfg[1], at(-14, 10))))
	dump((Models.boss(BossesCfg[2], at(14, 10))))
	dump((Models.portal(at(0, -6), roblox.Color3.fromRGB(90, 170, 70))))
	dump(Models.structure("EtherMats", at(-26, -14), V(16, 0.4, 12)))
	dump(Models.structure("CelestialMats", at(26, -14), V(18, 0.4, 10)))
	dump((Models.trainingMat(at(-30, -14), 3)))
	dump((Models.trainingMat(at(22, -14), 4)))
	for i, egg in PetsCfg.Eggs do
		local c = egg.Color
		dump((Models.eggStand(at(-12 + i * 6, -26), roblox.Color3.fromRGB(c[1], c[2], c[3]))))
	end
	for i, def in PetsCfg.List do
		local r = PetsCfg.Rarities[def.Rarity].Color
		local m = PetModels.build(def, roblox.Color3.fromRGB(r[1], r[2], r[3]))
		local offset = roblox.CFrame.new(-16 + i * 3.6, 2, -34) -- PivotTo n'existe pas dans Lune
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame = offset * p.CFrame
			end
		end
		dump(m)
	end
end
fs.writeFile("parts.json", serde.encode("json", out))
print(#out .. " pièces")
