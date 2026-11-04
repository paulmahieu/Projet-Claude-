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
local Materials = require(Shared.Config.Materials)
local Formulas = require(Shared.Formulas)

local Models = require(script.Parent.Parent.Art.Models)

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
	Pedestals: { [string]: { Part: BasePart, Gem: BasePart, Prompt: ProximityPrompt, Label: TextLabel } },
}

local plots: { Plot } = {}
local plotByGroup: { [string]: Plot } = {}
local buildHandler: ((Player, string) -> ())? = nil
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

local function makeBillboard(adornee: BasePart, text: string, offsetY: number, size: Vector2?): TextLabel
	local gui = Instance.new("BillboardGui")
	local s = size or Vector2.new(10, 3)
	gui.Size = UDim2.fromScale(s.X, s.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 90
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
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

-- Terrain Roblox : herbe animée, collines à l'horizon, mare. FillBlock/FillBall remplacent
-- seulement les zones concernées (le reste du terrain éventuel n'est pas effacé).
local function buildTerrain()
	local terrain = workspace.Terrain
	terrain.Decoration = true -- brins d'herbe animés (optimisés par Roblox, réglables par le joueur)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 160, 82))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 98, 70))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 126, 122))
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(1100, 8, 1100), Enum.Material.Grass)

	-- Collines en anneau au-delà des parcelles, en évitant les directions des arènes (0° et 270°).
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2
		local deg = math.deg(angle) % 360
		local nearArena = deg < 25 or deg > 335 or math.abs(deg - 270) < 25
		if not nearArena then
			local dist = 330 + (i % 3) * 45
			local radius = 45 + (i % 4) * 12
			local center = Vector3.new(math.cos(angle) * dist, -radius * 0.45, math.sin(angle) * dist)
			terrain:FillBall(center, radius, if i % 5 == 0 then Enum.Material.Rock else Enum.Material.Grass)
		end
	end
	-- Mare décorative entre deux parcelles.
	local pond = Vector3.new(math.cos(math.rad(112.5)) * 72, -1.5, math.sin(math.rad(112.5)) * 72)
	terrain:FillCylinder(CFrame.new(pond), 3, 9, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -2, 0)), 2, 10, Enum.Material.Sand)
end

local function buildWorld()
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy() -- réexécution : on remplace uniquement notre dossier
	end
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	buildTerrain()

	-- Point d'accueil (futur marchand, portail d'exploration).
	makePart({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 56, 56),
		CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(88, 90, 102), -- teinte des joints entre les dalles
		Parent = world,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.Position = Vector3.new(0, 1.95, 0) -- posé sur l'estrade
	spawn.Transparency = 1 -- l'estrade décorée tient lieu de point d'apparition
	spawn.Duration = 0
	spawn.Parent = world

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = world
	Models.hubPlaza(decor, 28)
	Models.hubDecor(decor, 28)
	-- Quelques buissons entre le hub et les parcelles (positions fixes, rendu reproductible).
	for i = 1, Game.PlotCount * 2 do
		local angle = (i / (Game.PlotCount * 2)) * math.pi * 2 + 0.2
		local radius = 60 + (i % 3) * 14
		Models.bush(CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), decor, i)
	end
end

-- Éclairage doux de fin d'après-midi (réutilise les objets existants : pas de doublon).
local function setupLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 128, 120)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
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
	-- Brume légère : profondeur sans flou (une densité/brume élevée rendait les lointains flous).
	atmosphere.Density = 0.1
	atmosphere.Haze = 0
	atmosphere.Glare = 0
	atmosphere.Color = Color3.fromRGB(205, 215, 230)
	atmosphere.Decay = Color3.fromRGB(110, 120, 140)
	local grading = ensure("ColorCorrectionEffect", "BastionGrading") :: ColorCorrectionEffect
	grading.Saturation = 0.1
	grading.Contrast = 0.1 -- un peu plus de contraste : formes plus nettes
	local bloom = ensure("BloomEffect", "BastionBloom") :: BloomEffect
	-- Halo discret autour des éléments lumineux (un halo large donnait un effet baveux).
	bloom.Intensity = 0.12
	bloom.Threshold = 2.2
	bloom.Size = 10
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
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(125, 105, 75),
		Parent = model,
	})
	model.PrimaryPart = floor

	local pathLength = Game.PlotRingRadius - HALF - 28
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
		CFrame = cf * CFrame.new(10, FLOOR_TOP + 3.5, -HALF + 2),
		Material = Enum.Material.Wood,
		Color = Models.Colors.WoodDark,
		Parent = model,
	})
	makePart({
		Name = "SignBoard",
		Size = Vector3.new(5, 2, 0.4),
		CFrame = cf * CFrame.new(10, FLOOR_TOP + 6, -HALF + 1.5),
		Material = Enum.Material.WoodPlanks,
		Color = Models.Colors.WoodLight,
		Parent = model,
	})
	local sign = makeBillboard(signPost, "Parcelle libre", 6, Vector2.new(16, 3))

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	Models.plotDecor(cf * CFrame.new(0, FLOOR_TOP, 0), Game.PlotSize, decor)

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
	local label = makeBillboard(gem, "", 4, Vector2.new(12, 4))

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
			local lines = { def.Name, Formulas.formatCost(Materials, def.Cost), def.Effect }
			if locked then
				table.insert(lines, "Requiert : " .. structureById[def.Requires].Name)
			end
			pedestal.Label.Text = table.concat(lines, "\n")
			pedestal.Gem.Color = if locked then COLORS.Locked elseif affordable then COLORS.Ready else COLORS.Missing
			pedestal.Prompt.Enabled = not locked
		end
	end
end

-- API ----------------------------------------------------------------------------------

function PlotService.setBuildHandler(fn: (Player, string) -> ())
	buildHandler = fn
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
	plot.StructuresFolder:ClearAllChildren()
	plot.PedestalsFolder:ClearAllChildren()
	plot.StationsFolder:ClearAllChildren()
	table.clear(plot.Pedestals)
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
	setupLighting()
	buildWorld()
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	for i = 1, Game.PlotCount do
		table.insert(plots, buildPlot(i, plotsFolder))
	end
end

return PlotService
