--[[
	PlotService : génère le monde (sol, hub, parcelles) et gère les bases des joueurs.

	Tout est généré par code à partir de la configuration : le jeu est jouable directement
	après `rojo build`, sans construction manuelle dans Studio. Les blocs colorés sont des
	placeholders ; ils seront remplacés par de vrais modèles (voir docs/ROADMAP.md).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared.Config.Buildings)
local Formulas = require(Shared.Formulas)

local PLOT_COUNT = 6
local PLOT_SIZE = 110
local PLOT_RING_RADIUS = 170
local FLOOR_TOP = 1 -- hauteur (Y) du dessus du sol des parcelles
local PAD_DEBOUNCE = 1.5 -- évite de répéter « or insuffisant » quand on reste sur le pad

local PlotService = {}

type Plot = {
	Index: number,
	Model: Model,
	CFrame: CFrame,
	Owner: Player?,
	Sign: TextLabel,
	Pads: { [string]: BasePart },
	BuildingsFolder: Folder,
	PadsFolder: Folder,
}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local padHandler: ((Player, string) -> ())? = nil
local lastPadTouch: { [Player]: number } = {}

local buildingById = {}
for _, def in Buildings do
	buildingById[def.Id] = def
end

-- Utilitaires de construction ---------------------------------------------------------

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

local function makeBillboard(adornee: BasePart, text: string, offsetY: number, size: Vector2?): TextLabel
	local gui = Instance.new("BillboardGui")
	local s = size or Vector2.new(8, 2)
	gui.Size = UDim2.fromScale(s.X, s.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	return label
end

local function toColor(rgb): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function localCFrame(plot: Plot, x: number, y: number, z: number): CFrame
	return plot.CFrame * CFrame.new(x, y, z)
end

-- Monde ------------------------------------------------------------------------------

local function buildWorld()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	makePart({
		Name = "Ground",
		Size = Vector3.new(1024, 4, 1024),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(86, 140, 70),
		Parent = world,
	})

	-- Hub central : point d'apparition et futur village (quêtes, portail d'exploration).
	makePart({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 60, 60),
		CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(150, 145, 135),
		Parent = world,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 0)
	spawn.Material = Enum.Material.Marble
	spawn.Duration = 0 -- pas de bouclier d'apparition
	spawn.Parent = world

	return world
end

local function buildPlot(index: number, parent: Instance): Plot
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local center = Vector3.new(math.cos(angle) * PLOT_RING_RADIUS, 0, math.sin(angle) * PLOT_RING_RADIUS)
	-- Le côté -Z local de la parcelle (son entrée) fait face au hub.
	local cf = CFrame.lookAt(center, Vector3.zero)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("OwnerId", 0)
	model.Parent = parent

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = cf * CFrame.new(0, FLOOR_TOP - 0.5, 0),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(110, 90, 60),
		Parent = model,
	})
	model.PrimaryPart = floor

	-- Allée entre le hub et la parcelle.
	local pathLength = PLOT_RING_RADIUS - PLOT_SIZE / 2 - 30
	makePart({
		Name = "Path",
		Size = Vector3.new(10, 1, pathLength),
		CFrame = cf * CFrame.new(0, 0.2, -PLOT_SIZE / 2 - pathLength / 2),
		Material = Enum.Material.Pebble,
		Color = Color3.fromRGB(140, 130, 115),
		CanCollide = false,
		Parent = model,
	})

	local signPost = makePart({
		Name = "SignPost",
		Size = Vector3.new(1, 8, 1),
		CFrame = cf * CFrame.new(8, FLOOR_TOP + 4, -PLOT_SIZE / 2 + 2),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(100, 70, 40),
		Parent = model,
	})
	local sign = makeBillboard(signPost, "Base libre", 6, Vector2.new(14, 3))

	local buildingsFolder = Instance.new("Folder")
	buildingsFolder.Name = "Buildings"
	buildingsFolder.Parent = model

	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "Pads"
	padsFolder.Parent = model

	return {
		Index = index,
		Model = model,
		CFrame = cf * CFrame.new(0, FLOOR_TOP, 0), -- origine = centre, au ras du sol
		Owner = nil,
		Sign = sign,
		Pads = {},
		BuildingsFolder = buildingsFolder,
		PadsFolder = padsFolder,
	}
end

-- Bâtiments --------------------------------------------------------------------------

local function renderBuilding(plot: Plot, def)
	if plot.BuildingsFolder:FindFirstChild(def.Id) then
		return
	end
	local sx, sy, sz = def.Size[1], def.Size[2], def.Size[3]
	local model = Instance.new("Model")
	model.Name = def.Id

	local body = makePart({
		Name = "Body",
		Size = Vector3.new(sx, sy, sz),
		CFrame = localCFrame(plot, def.Offset[1], sy / 2, def.Offset[2]),
		Material = Enum.Material[def.Material],
		Color = toColor(def.Color),
		Parent = model,
	})
	model.PrimaryPart = body

	-- Toit simple pour les bâtiments hauts (placeholder).
	if sy >= 8 and sx <= 30 then
		makePart({
			Name = "Roof",
			Size = Vector3.new(sx + 2, 1.5, sz + 2),
			CFrame = localCFrame(plot, def.Offset[1], sy + 0.75, def.Offset[2]),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(120, 40, 35),
			Parent = model,
		})
	end

	if def.Id == "Campfire" then
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Parent = body
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Parent = body
	end

	makeBillboard(body, string.format("%s\n+%s or/s", def.Name, Formulas.formatNumber(def.Income)), sy / 2 + 4)
	model.Parent = plot.BuildingsFolder
end

-- Pads d'achat -----------------------------------------------------------------------

local function onPadTouched(plot: Plot, buildingId: string, hit: BasePart)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or player ~= plot.Owner then
		return
	end
	local now = os.clock()
	if (lastPadTouch[player] or 0) + PAD_DEBOUNCE > now then
		return
	end
	lastPadTouch[player] = now
	if padHandler then
		padHandler(player, buildingId)
	end
end

local function createPad(plot: Plot, def): BasePart
	local padZ = def.Offset[2] - def.Size[3] / 2 - 4
	local pad = makePart({
		Name = "Pad_" .. def.Id,
		Size = Vector3.new(6, 0.6, 6),
		CFrame = localCFrame(plot, def.Offset[1], 0.3, padZ),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(80, 200, 90),
		CanCollide = false,
		Parent = plot.PadsFolder,
	})
	makeBillboard(pad, string.format("%s\n%s or", def.Name, Formulas.formatNumber(def.Cost)), 4)
	pad.Touched:Connect(function(hit)
		onPadTouched(plot, def.Id, hit)
	end)
	return pad
end

-- API publique -----------------------------------------------------------------------

function PlotService.setPadHandler(fn: (Player, string) -> ())
	padHandler = fn
end

function PlotService.get(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.spawnCFrame(plot: Plot): CFrame
	-- Entrée de la base, regard tourné vers l'intérieur.
	return plot.CFrame * CFrame.new(0, 3, -PLOT_SIZE / 2 + 6) * CFrame.Angles(0, math.pi, 0)
end

-- Attribue une parcelle libre et reconstruit les bâtiments déjà possédés.
function PlotService.claim(player: Player, ownedSet): Plot?
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.Model:SetAttribute("OwnerId", player.UserId)
			plot.Sign.Text = "Base de " .. player.DisplayName
			plotByPlayer[player] = plot
			for _, def in Buildings do
				if ownedSet[def.Id] then
					renderBuilding(plot, def)
				end
			end
			-- Le personnage est souvent apparu au hub avant la fin du chargement des données.
			local character = player.Character
			if character then
				character:PivotTo(PlotService.spawnCFrame(plot))
			end
			return plot
		end
	end
	return nil
end

function PlotService.release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	lastPadTouch[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerId", 0)
	plot.Sign.Text = "Base libre"
	plot.BuildingsFolder:ClearAllChildren()
	plot.PadsFolder:ClearAllChildren()
	table.clear(plot.Pads)
	-- Le mannequin est géré par TrainingService.
	local dummy = plot.Model:FindFirstChild("TrainingDummy")
	if dummy then
		dummy:Destroy()
	end
end

function PlotService.addBuilding(player: Player, buildingId: string)
	local plot = plotByPlayer[player]
	local def = buildingById[buildingId]
	if plot and def then
		renderBuilding(plot, def)
	end
end

-- Affiche les pads disponibles ; rouge = pas assez d'or, vert = achetable.
function PlotService.updatePads(player: Player, ownedSet, gold: number)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local available = {}
	for _, def in Formulas.availableBuildings(Buildings, ownedSet) do
		available[def.Id] = def
	end
	for id, pad in plot.Pads do
		if not available[id] then
			pad:Destroy()
			plot.Pads[id] = nil
		end
	end
	for id, def in available do
		local pad = plot.Pads[id]
		if not pad then
			pad = createPad(plot, def)
			plot.Pads[id] = pad
		end
		pad.Color = if gold >= def.Cost then Color3.fromRGB(80, 200, 90) else Color3.fromRGB(200, 70, 60)
	end
end

function PlotService.init()
	local world = buildWorld()
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	for i = 1, PLOT_COUNT do
		table.insert(plots, buildPlot(i, plotsFolder))
	end
end

function PlotService.start()
	-- À chaque apparition, le joueur est placé à l'entrée de sa base.
	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			local plot = plotByPlayer[player]
			if plot then
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if root then
					task.defer(function()
						character:PivotTo(PlotService.spawnCFrame(plot))
					end)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end
	Players.PlayerRemoving:Connect(PlotService.release)
end

return PlotService
