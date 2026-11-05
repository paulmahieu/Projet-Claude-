--[[
	PlotService : génère le monde et attribue une parcelle à chaque GROUPE actif sur le serveur.

	- Génération reproductible : tout est créé dans Workspace.World ; une seconde exécution
	  détruit et recrée uniquement ce dossier (aucune duplication, rien d'autre n'est touché).
	- Les constructions sont positionnées relativement à l'origine de la parcelle : la même
	  base peut être reconstruite sur n'importe quelle parcelle à la session suivante.
	- Chaque construction non possédée a un socle avec ProximityPrompt « Construire »
	  (clavier, manette et tactile) affichant coût, prérequis et effet.
	- Le Noyau d'Éther est le cœur protégé du bastion (non supprimable).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Structures = require(Shared.Config.Structures)
local Decors = require(Shared.Config.Decors)
local Formulas = require(Shared.Formulas)

local Models = require(script.Parent.Parent.Art.Models)
local Outdoors = require(script.Parent.Parent.Art.Outdoors)
local Harvest = require(Shared.Config.Harvest)
local Bosses = require(Shared.Config.Bosses)
local VisualStyle = require(Shared.Config.VisualStyle)
local EnvironmentStyle = require(Shared.EnvironmentStyle)
local CostPanel = require(script.Parent.Parent.Art.CostPanel)

local Lighting = game:GetService("Lighting")

local PlotService = {}

local FLOOR_TOP = 1
local HALF = Game.PlotSize / 2

local COLORS = {
	Ready = Color3.fromRGB(80, 190, 95),
	Missing = Color3.fromRGB(200, 80, 60),
	Locked = Color3.fromRGB(110, 110, 110),
}

export type Plot = {
	Index: number,
	Model: Model,
	CFrame: CFrame,
	GroupId: string?,
	Sign: TextLabel,
	CoreLabel: TextLabel,
	StructuresFolder: Folder,
	PedestalsFolder: Folder,
	StationsFolder: Folder,
	Core: Model,
	Pedestals: { [string]: { Part: BasePart, Gem: BasePart, Prompt: ProximityPrompt, Label: any } },
	Doors: { any },
	DoorsOpen: boolean,
	DoorPrompt: ProximityPrompt?,
}

local plots: { Plot } = {}
local plotByGroup: { [string]: Plot } = {}
local buildHandler: ((Player, string) -> ())? = nil
local gateHandler: ((Player, any) -> ())? = nil
local refreshHooks = {} -- fn(plot, groupData) après chaque mise à jour (terrain, machines)
local releaseHooks = {} -- fn(plot) quand une parcelle est libérée
local world: Folder

local structureById = {}
for _, def in Structures do
	structureById[def.Id] = def
end

-- Utilitaires --------------------------------------------------------------------------

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end
PlotService.makePart = makePart

-- Étiquette 3D lisible : toujours au premier plan (jamais cachée par un bâtiment), taille fixe
-- à l'écran (ne devient pas géante de près) et visible seulement à proximité (pas de fouillis).
local function makeBillboard(
	adornee: BasePart,
	text: string,
	offsetY: number,
	size: Vector2?,
	maxDistance: number?
): TextLabel
	local gui = Instance.new("BillboardGui")
	local s = size or Vector2.new(10, 3)
	gui.Size = UDim2.fromOffset(s.X * 17, s.Y * 17)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 70
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	return label
end
PlotService.makeBillboard = makeBillboard

local function toColor(rgb): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function PlotService.localCFrame(plot: Plot, x: number, y: number, z: number): CFrame
	return plot.CFrame * CFrame.new(x, y, z)
end

-- Monde --------------------------------------------------------------------------------

-- Terrain Roblox : collines à l'horizon. FillBall remplace
-- seulement les zones concernées (le reste du terrain éventuel n'est pas effacé).
local function buildTerrain()
	local terrain = workspace.Terrain
	-- NB : Terrain.Decoration (herbe animée) ne peut pas être modifié par un script : c'était la
	-- cause de l'arrêt du serveur au démarrage. À activer à la main si souhaité :
	-- Explorer > Workspace > Terrain > propriété « Decoration ».
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(125, 173, 107)) -- vert doux du sol (VisualStyle)
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 98, 70))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 126, 122))
	-- Eau des mares (Terrain) : claire, légèrement verte, petites vagues et reflets.
	terrain.WaterColor = Color3.fromRGB(46, 120, 130)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.06
	terrain.WaterWaveSpeed = 6
	-- Nuages animés intégrés de Roblox, poussés par un vent léger (qui anime aussi l'herbe
	-- décorative du Terrain si elle est activée dans Studio).
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.5
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
	workspace.GlobalWind = Vector3.new(6, 0, 3)
	-- Le sol plat est une pièce exacte (Workspace.Ground, dessus à y = 0) : un remplissage de
	-- terrain remontait au-dessus de 0 et recouvrait le dallage du hub et le pied des objets.

	-- Collines en anneau au-delà des parcelles, en évitant les directions des arènes (0° et 270°).
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2
		local deg = math.deg(angle) % 360
		local nearArena = deg < 25 or deg > 335 or math.abs(deg - 270) < 25
		if not nearArena then
			-- Au-delà des extensions de terrain (jusqu'à 405 studs du centre, Config/Land).
			local dist = 470 + (i % 3) * 30
			local radius = 40 + (i % 4) * 10
			local center = Vector3.new(math.cos(angle) * dist, -radius * 0.45, math.sin(angle) * dist)
			terrain:FillBall(center, radius, if i % 5 == 0 then Enum.Material.Rock else Enum.Material.Grass)
		end
	end
end

local function buildWorld()
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy() -- réexécution : on remplace uniquement notre dossier
	end
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	-- Style visuel central : tout ce qui sera ajouté au monde (génération, clones, imports,
	-- régénérations) est lissé par lots via l'événement DescendantAdded (Config/VisualStyle).
	EnvironmentStyle.watch(world)
	local ground = workspace:FindFirstChild("Ground")
	if ground then
		EnvironmentStyle.apply(ground)
	end

	local terrainOk, terrainErr = pcall(buildTerrain)
	if not terrainOk then
		warn("[PlotService] Terrain : " .. tostring(terrainErr))
	end

	-- Cour royale : point d'apparition au centre d'un château fermé par des remparts ; on en
	-- sort par les portes fortifiées (est, ouest, sud) pour rejoindre bastions et bosquets.
	local castle = Instance.new("Folder")
	castle.Name = "Castle"
	castle.Parent = world
	Models.castle(castle, Game)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 0.2, 8)
	-- Posé sur l'estrade, tourné vers les portails (+Z) ; les œufs sont dans le dos (-Z).
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 1.95, 0), Vector3.new(0, 1.95, 10))
	spawn.Transparency = 1 -- l'estrade décorée tient lieu de point d'apparition
	spawn.Duration = 0
	spawn.Parent = world

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = world
	Models.hubPlaza(decor, 28)
	Models.hubDecor(decor, 28)
	-- Torches sur pied le long des allées de la cour (hors œufs et portails).
	for _, spot in { { 0, 20 }, { 0, 40 }, { 180, 20 }, { 180, 40 }, { 90, 20 }, { 270, 40 } } do
		local a = math.rad(spot[1])
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local perp = Vector3.new(-dir.Z, 0, dir.X)
		for _, side in { -1, 1 } do
			local pos = dir * spot[2] + perp * side * 5.2 + Vector3.new(0, 1, 0)
			Models.torch(CFrame.lookAt(pos, Vector3.new(0, 1, 0)), decor)
		end
	end
	-- Extérieur : nappes d'herbe, touffes, fleurs, cailloux, arbres de prairie, mares.
	local outdoorsOk, outdoorsErr = pcall(function()
		local outside = Instance.new("Folder")
		outside.Name = "Outdoors"
		outside.Parent = world
		local arenas = {}
		for _, def in Bosses do
			if def.Arena then
				table.insert(arenas, Vector3.new(def.Arena[1], 0, def.Arena[2]))
			end
		end
		local ponds = Outdoors.build(outside, { Game = Game, Harvest = Harvest, Arenas = arenas }, Models)
		-- Eau du Terrain : surface à ~0,8 stud au-dessus du sol (le dessous est caché par le sol).
		for _, p in ponds do
			workspace.Terrain:FillCylinder(CFrame.new(p.Position), 1.6, p.Radius, Enum.Material.Water)
		end
	end)
	if not outdoorsOk then
		warn("[PlotService] Extérieur : " .. tostring(outdoorsErr))
	end

	-- Quelques buissons entre le hub et les parcelles (positions fixes, rendu reproductible).
	for i = 1, Game.PlotCount * 2 do
		local angle = (i / (Game.PlotCount * 2)) * math.pi * 2 + 0.2
		local radius = 132 + (i % 3) * 6 -- entre les bosquets et les parcelles
		Models.bush(CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), decor, i)
	end
end

-- Éclairage doux de fin d'après-midi (réutilise les objets existants : pas de doublon).
local function setupLighting()
	-- Valeurs centrales : Config/VisualStyle.Lighting (lumière douce, peu de bloom, pas de brume).
	local L = VisualStyle.Lighting
	local function rgb(c)
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	pcall(function()
		(Lighting :: any).LightingStyle = (Enum :: any).LightingStyle[L.Style]
	end)
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = rgb(L.OutdoorAmbient)
	-- Lumière des lieux fermés (salles mystiques sous la carte) : jamais noir complet.
	Lighting.Ambient = rgb(L.IndoorAmbient)
	Lighting.ColorShift_Top = rgb(L.ColorShiftTop)
	pcall(function()
		Lighting.ShadowSoftness = L.ShadowSoftness
	end)
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	local function ensure(className: string, name: string)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end
	local atmosphere = ensure("Atmosphere", "BastionAtmosphere") :: Atmosphere
	atmosphere.Density = L.Atmosphere.Density
	atmosphere.Haze = L.Atmosphere.Haze
	atmosphere.Glare = L.Atmosphere.Glare
	atmosphere.Color = rgb(L.Atmosphere.Color)
	atmosphere.Decay = rgb(L.Atmosphere.Decay)
	local grading = ensure("ColorCorrectionEffect", "BastionGrading") :: ColorCorrectionEffect
	grading.Saturation = L.Grading.Saturation
	grading.Contrast = L.Grading.Contrast
	grading.Brightness = L.Grading.Brightness
	grading.TintColor = rgb(L.Grading.Tint)
	local bloom = ensure("BloomEffect", "BastionBloom") :: BloomEffect
	bloom.Intensity = L.Bloom.Intensity
	bloom.Threshold = L.Bloom.Threshold
	bloom.Size = L.Bloom.Size
	local rays = ensure("SunRaysEffect", "BastionSunRays") :: SunRaysEffect
	rays.Intensity = L.SunRays.Intensity
	rays.Spread = L.SunRays.Spread
end

local function buildPlot(index: number, parent: Instance): Plot
	local angle = (index - 1) / Game.PlotCount * math.pi * 2
	local center = Vector3.new(math.cos(angle) * Game.PlotRingRadius, 0, math.sin(angle) * Game.PlotRingRadius)
	local cf = CFrame.lookAt(center, Vector3.zero) -- -Z local = entrée, face au hub

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("GroupId", "")
	model.Parent = parent

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(Game.PlotSize, 1, Game.PlotSize),
		CFrame = cf * CFrame.new(0, FLOOR_TOP - 0.5, 0),
		Material = Enum.Material.Cobblestone, -- sol pavé, assorti à la cour royale
		Color = Color3.fromRGB(150, 142, 128),
		Parent = model,
	})
	model.PrimaryPart = floor

	-- L'allée part de la route pavée qui fait le tour du château.
	local roadOuter = Game.RingRoadRadius + Game.RingRoadWidth / 2
	local pathLength = Game.PlotRingRadius - HALF - roadOuter
	makePart({
		Name = "Path",
		Size = Vector3.new(10, 1, pathLength),
		CFrame = cf * CFrame.new(0, 0.2, -HALF - pathLength / 2),
		Material = Enum.Material.Pebble,
		Color = Color3.fromRGB(150, 140, 120),
		CanCollide = false,
		Parent = model,
	})

	local signPost = makePart({
		Name = "SignPost",
		Size = Vector3.new(0.8, 7, 0.8),
		CFrame = cf * CFrame.new(10, FLOOR_TOP + 3.5, -HALF + 4.5), -- derrière le muret d'entrée
		Material = Enum.Material.Wood,
		Color = Models.Colors.WoodDark,
		Parent = model,
	})
	makePart({
		Name = "SignBoard",
		Size = Vector3.new(5, 2, 0.4),
		CFrame = cf * CFrame.new(10, FLOOR_TOP + 6, -HALF + 4),
		Material = Enum.Material.WoodPlanks,
		Color = Models.Colors.WoodLight,
		Parent = model,
	})
	local sign = makeBillboard(signPost, "Parcelle libre", 6, Vector2.new(16, 3))

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	Models.plotDecor(cf * CFrame.new(0, FLOOR_TOP, 0), Game.PlotSize, decor)
	-- Portail d'entrée à deux battants : décor importé « 05_Portail » (agrandi à la largeur de
	-- l'entrée) ou battants générés dans le portail existant. Ouverts par défaut.
	local gateBase = cf * CFrame.new(0, FLOOR_TOP, -HALF + 0.7)
	local gateModel, doors = Models.decor("05_Portail", gateBase, { Scale = 1.2 })
	if gateModel then
		gateModel.Parent = decor
	else
		doors = Models.gateDoors(gateBase, 12, 7, decor)
	end
	doors = doors or {}
	Models.setDoors(doors, 1)
	local doorAnchor = makePart({
		Name = "GatePromptAnchor",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = gateBase * CFrame.new(0, 3.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local doorPrompt = Instance.new("ProximityPrompt")
	doorPrompt.ActionText = "Fermer la porte"
	doorPrompt.ObjectText = "Portail du bastion"
	doorPrompt.HoldDuration = 0.3
	doorPrompt.MaxActivationDistance = 9
	doorPrompt.RequiresLineOfSight = false
	doorPrompt.Enabled = false -- activée quand un groupe occupe la parcelle
	doorPrompt.Parent = doorAnchor

	-- Noyau d'Éther : cœur protégé du bastion, affiché seulement quand la parcelle est occupée.
	local core, crystal = Models.etherCore(cf * CFrame.new(0, FLOOR_TOP, 8))
	local coreLabel = makeBillboard(crystal, "", 4, Vector2.new(12, 2.5))

	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		return f
	end

	return {
		Index = index,
		Model = model,
		CFrame = cf * CFrame.new(0, FLOOR_TOP, 0),
		GroupId = nil,
		Sign = sign,
		CoreLabel = coreLabel,
		Core = core,
		StructuresFolder = folder("Structures"),
		PedestalsFolder = folder("Pedestals"),
		StationsFolder = folder("Stations"),
		Pedestals = {},
		Doors = doors,
		DoorsOpen = true,
		DoorPrompt = doorPrompt,
	}
end

-- Constructions ------------------------------------------------------------------------

local function renderStructure(plot: Plot, def)
	if plot.StructuresFolder:FindFirstChild(def.Id) then
		return
	end
	local size = Vector3.new(def.Size[1], def.Size[2], def.Size[3])
	local base = PlotService.localCFrame(plot, def.Offset[1], 0, def.Offset[2])
	local model = Models.structure(def.Id, base, size, toColor(def.Color), Enum.Material[def.Material])
	-- Étiquette au-dessus du centre de la construction.
	local anchor = makePart({
		Name = "LabelAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = base * CFrame.new(0, math.max(size.Y, 3) + 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	makeBillboard(anchor, def.Name, 1, Vector2.new(10, 1.6))
	model.Parent = plot.StructuresFolder
end

local function pedestalCFrame(plot: Plot, def): CFrame
	-- Devant l'emprise de la construction, côté entrée.
	return PlotService.localCFrame(plot, def.Offset[1], 0, def.Offset[2] - def.Size[3] / 2 - 4)
end

local function createPedestal(plot: Plot, def)
	local model, part, gem = Models.pedestal(pedestalCFrame(plot, def))
	model.Name = "Pedestal_" .. def.Id
	model.Parent = plot.PedestalsFolder
	gem.Color = COLORS.Locked
	local label = CostPanel.new(gem, 1.2, 60)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Construire"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0.5 -- évite les achats accidentels
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		if buildHandler then
			buildHandler(player, def.Id)
		end
	end)

	plot.Pedestals[def.Id] = { Part = part, Gem = gem, Prompt = prompt, Label = label }
end

-- Met à jour socles et noyau selon l'état du groupe.
function PlotService.refresh(groupId: string, groupData)
	local plot = plotByGroup[groupId]
	if not plot then
		return
	end
	local owned = groupData.Structures
	plot.CoreLabel.Text = string.format("Noyau d'Éther · Bastion niv. %d", Formulas.bastionLevel(Structures, owned))
	for _, def in Structures do
		local pedestal = plot.Pedestals[def.Id]
		if owned[def.Id] then
			renderStructure(plot, def)
			if pedestal then
				(pedestal.Part.Parent :: Instance):Destroy()
				plot.Pedestals[def.Id] = nil
			end
		else
			if not pedestal then
				createPedestal(plot, def)
				pedestal = plot.Pedestals[def.Id]
			end
			local locked = def.Requires ~= nil and not owned[def.Requires]
			local affordable = Formulas.canAfford(groupData.Materials, def.Cost)
			CostPanel.set(pedestal.Label, {
				Title = def.Name,
				Cost = def.Cost,
				Have = groupData.Materials,
				Lines = { def.Effect },
				Status = if locked
					then "Requiert : " .. structureById[def.Requires].Name
					elseif affordable then "Maintenir E pour construire"
					else "Il manque des ressources",
				Kind = if locked then "locked" elseif affordable then "ok" else "missing",
			})
			pedestal.Gem.Color = if locked then COLORS.Locked elseif affordable then COLORS.Ready else COLORS.Missing
			pedestal.Prompt.Enabled = not locked
		end
	end
	for _, fn in refreshHooks do
		local ok, err = pcall(fn, plot, groupData)
		if not ok then
			warn("[PlotService] refresh : " .. tostring(err))
		end
	end
end

function PlotService.onRefresh(fn)
	table.insert(refreshHooks, fn)
end

function PlotService.onRelease(fn)
	table.insert(releaseHooks, fn)
end

-- API ----------------------------------------------------------------------------------

function PlotService.setBuildHandler(fn: (Player, string) -> ())
	buildHandler = fn
end

-- fn(player, plot) : demande d'ouvrir / fermer le portail (permissions vérifiées par l'appelant).
function PlotService.setGateHandler(fn: (Player, any) -> ())
	gateHandler = fn
end

-- Ouvre ou ferme le portail d'un bastion (rotation des battants autour de leurs charnières).
function PlotService.setGate(plot: Plot, open: boolean)
	if plot.DoorsOpen == open then
		return
	end
	plot.DoorsOpen = open
	if plot.DoorPrompt then
		plot.DoorPrompt.ActionText = if open then "Fermer la porte" else "Ouvrir la porte"
	end
	local from = if open then 0 else 1
	local to = if open then 1 else 0
	task.spawn(function()
		local start = os.clock()
		local duration = 0.7
		while true do
			local t = math.clamp((os.clock() - start) / duration, 0, 1)
			if plot.DoorsOpen ~= open then
				return -- inversé entre-temps
			end
			local eased = 1 - (1 - t) ^ 2
			Models.setDoors(plot.Doors, from + (to - from) * eased)
			if t >= 1 then
				return
			end
			task.wait()
		end
	end)
end

function PlotService.all(): { Plot }
	return plots
end

function PlotService.get(groupId: string): Plot?
	return plotByGroup[groupId]
end

function PlotService.spawnCFrame(plot: Plot): CFrame
	return plot.CFrame * CFrame.new(0, 3, -HALF + 6) * CFrame.Angles(0, math.pi, 0)
end

function PlotService.teleportToPlot(player: Player, groupId: string)
	local plot = plotByGroup[groupId]
	local character = player.Character
	if plot and character then
		character:PivotTo(PlotService.spawnCFrame(plot))
	end
end

function PlotService.claim(groupId: string, groupData): Plot?
	if plotByGroup[groupId] then
		return plotByGroup[groupId]
	end
	for _, plot in plots do
		if plot.GroupId == nil then
			plot.GroupId = groupId
			plot.Model:SetAttribute("GroupId", groupId)
			plot.Sign.Text = groupData.Name
			plot.Core.Parent = plot.Model
			plotByGroup[groupId] = plot
			if plot.DoorPrompt then
				plot.DoorPrompt.Enabled = true
			end
			PlotService.refresh(groupId, groupData)
			return plot
		end
	end
	return nil
end

function PlotService.release(groupId: string)
	local plot = plotByGroup[groupId]
	if not plot then
		return
	end
	plotByGroup[groupId] = nil
	plot.GroupId = nil
	plot.Model:SetAttribute("GroupId", "")
	plot.Sign.Text = "Parcelle libre"
	plot.CoreLabel.Text = ""
	plot.Core.Parent = nil -- conservé pour la prochaine attribution
	PlotService.setGate(plot, true)
	if plot.DoorPrompt then
		plot.DoorPrompt.Enabled = false
	end
	plot.StructuresFolder:ClearAllChildren()
	plot.PedestalsFolder:ClearAllChildren()
	plot.StationsFolder:ClearAllChildren()
	table.clear(plot.Pedestals)
	for _, fn in releaseHooks do
		pcall(fn, plot)
	end
end

function PlotService.rename(groupId: string, name: string)
	local plot = plotByGroup[groupId]
	if plot then
		plot.Sign.Text = name
	end
end

function PlotService.world(): Folder
	return world
end

function PlotService.init()
	-- L'éclairage est cosmétique : une erreur ne doit jamais empêcher de construire le monde.
	local ok, err = pcall(setupLighting)
	if not ok then
		warn("[PlotService] Éclairage : " .. tostring(err))
	end
	Models.setDecors(Decors) -- décors importés (ServerStorage > Assets), sinon décors générés
	buildWorld()
	-- Le point d'apparition du hub existe : celui de secours ne sert plus. Le sol
	-- (Workspace.Ground, fichier du projet) existe toujours, même si un script échoue.
	local safetySpawn = workspace:FindFirstChild("SafetySpawn")
	if safetySpawn then
		safetySpawn:Destroy()
	end
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	for i = 1, Game.PlotCount do
		local plot = buildPlot(i, plotsFolder)
		table.insert(plots, plot)
		if plot.DoorPrompt then
			plot.DoorPrompt.Triggered:Connect(function(player)
				if gateHandler and plot.GroupId then
					gateHandler(player, plot)
				end
			end)
		end
	end
end

return PlotService
