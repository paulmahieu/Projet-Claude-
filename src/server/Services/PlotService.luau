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
	Pedestals: { [string]: { Part: BasePart, Prompt: ProximityPrompt, Label: TextLabel } },
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

local function buildWorld()
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy() -- réexécution : on remplace uniquement notre dossier
	end
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	makePart({
		Name = "Ground",
		Size = Vector3.new(1024, 4, 1024),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(96, 150, 78),
		Parent = world,
	})

	-- Point d'accueil (futur marchand, portail d'exploration).
	makePart({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 56, 56),
		CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(160, 155, 145),
		Parent = world,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 0)
	spawn.Material = Enum.Material.Marble
	spawn.Duration = 0
	spawn.Parent = world
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
		Size = Vector3.new(1, 8, 1),
		CFrame = cf * CFrame.new(9, FLOOR_TOP + 4, -HALF + 2),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(100, 70, 40),
		Parent = model,
	})
	local sign = makeBillboard(signPost, "Parcelle libre", 6, Vector2.new(16, 3))

	-- Noyau d'Éther : cœur protégé du bastion (visible seulement quand la parcelle est occupée).
	local core = makePart({
		Name = "EtherCore",
		Size = Vector3.new(4, 9, 4),
		CFrame = cf * CFrame.new(0, FLOOR_TOP + 5, 8) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local coreLabel = makeBillboard(core, "", 7, Vector2.new(12, 2.5))

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
	local sx, sy, sz = def.Size[1], def.Size[2], def.Size[3]
	local model = Instance.new("Model")
	model.Name = def.Id
	local body = makePart({
		Name = "Body",
		Size = Vector3.new(sx, sy, sz),
		CFrame = PlotService.localCFrame(plot, def.Offset[1], sy / 2, def.Offset[2]),
		Material = Enum.Material[def.Material],
		Color = toColor(def.Color),
		Parent = model,
	})
	model.PrimaryPart = body
	if sy >= 8 and sx <= 30 then
		makePart({
			Name = "Roof",
			Size = Vector3.new(sx + 2, 1.5, sz + 2),
			CFrame = PlotService.localCFrame(plot, def.Offset[1], sy + 0.75, def.Offset[2]),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(125, 45, 40),
			Parent = model,
		})
	end
	makeBillboard(body, def.Name, math.max(sy, 2) / 2 + 3, Vector2.new(10, 1.6))
	model.Parent = plot.StructuresFolder
end

local function pedestalCFrame(plot: Plot, def): CFrame
	-- Devant l'emprise de la construction, côté entrée.
	return PlotService.localCFrame(plot, def.Offset[1], 1.5, def.Offset[2] - def.Size[3] / 2 - 4)
end

local function createPedestal(plot: Plot, def)
	local part = makePart({
		Name = "Pedestal_" .. def.Id,
		Size = Vector3.new(3, 3, 3),
		CFrame = pedestalCFrame(plot, def),
		Material = Enum.Material.Neon,
		Color = COLORS.Locked,
		Parent = plot.PedestalsFolder,
	})
	local label = makeBillboard(part, "", 5, Vector2.new(12, 4))

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

	plot.Pedestals[def.Id] = { Part = part, Prompt = prompt, Label = label }
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
				pedestal.Part:Destroy()
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
			pedestal.Part.Color = if locked then COLORS.Locked elseif affordable then COLORS.Ready else COLORS.Missing
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
			local core = plot.Model:FindFirstChild("EtherCore") :: BasePart
			core.Transparency = 0.15
			core.CanCollide = true
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
	local core = plot.Model:FindFirstChild("EtherCore") :: BasePart
	core.Transparency = 1
	core.CanCollide = false
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
	buildWorld()
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	for i = 1, Game.PlotCount do
		table.insert(plots, buildPlot(i, plotsFolder))
	end
end

return PlotService
