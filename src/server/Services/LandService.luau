--[[
	LandService : agrandissement du terrain du bastion et machines de production.

	Terrain (Config/Land) :
	- Les 6 extensions existent physiquement autour de chaque parcelle (friche clôturée).
	- Achat dans l'ordre, avec les matériaux COMMUNS du groupe et la permission Construire,
	  sur le panneau « Agrandir » placé devant le prochain passage. Vérification et débit sans
	  attente entre les deux (même règle que BuildService) : jamais facturé deux fois.
	- À l'achat : sol pavé, friche retirée, barrières ouvertes, emplacements de machines.

	Machines (Config/Machines) :
	- Achat et amélioration (niveaux 1 à 5) sur leur emplacement, matériaux du groupe.
	- Production chaque seconde : matériaux pour le groupe (fractions reportées) et une faible
	  part d'or personnel pour chaque membre du groupe en ligne sur ce serveur.
	- Hors ligne : crédit des matériaux au chargement du bastion (GroupService, 25 %, 8 h).
	- Le tapis roulant et ses blocs sont animés par le client (MachineFx) : aucun coût serveur.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Land = require(Shared.Config.Land)
local Machines = require(Shared.Config.Machines)
local Materials = require(Shared.Config.Materials)
local Economy = require(Shared.Config.Economy)
local Texts = require(Shared.Config.Texts)

local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local ProfileService = require(script.Parent.ProfileService)
local Notifier = require(script.Parent.Notifier)
local Models = require(script.Parent.Parent.Art.Models)
local CostPanel = require(script.Parent.Parent.Art.CostPanel)

local LandService = {}

local PAVED = Color3.fromRGB(150, 142, 128)
local FALLOW = Color3.fromRGB(128, 140, 84)
local READY = Color3.fromRGB(80, 190, 95)
local MISSING = Color3.fromRGB(200, 80, 60)
local SYNC_EVERY = 5 -- secondes entre deux publications de la production

local machineById = {}
for _, def in Machines.List do
	machineById[def.Id] = def
end
local slotById, areaOfSlot = {}, {}
for _, area in Land.Areas do
	for _, slot in area.Slots do
		slotById[slot.Id] = slot
		areaOfSlot[slot.Id] = area.Id
	end
end
local materialName = {}
for _, mat in Materials do
	materialName[mat.Id] = mat.Name
end

type LandState = {
	Folder: Folder,
	Floors: { [string]: { Floor: BasePart, Fallow: Folder, Paving: Folder? } },
	Barriers: { [number]: Model },
	SlotsFolder: Folder,
	Slots: { [string]: { Model: Model, Level: number, Label: any, Prompt: ProximityPrompt, Gem: BasePart? } },
	Sign: { Model: Model, Gem: BasePart, Label: any, AreaId: string }?,
}

local states: { [any]: LandState } = {} -- par parcelle
local paveArea -- défini plus bas
local lastAction: { [Player]: number } = {}

local function slotCFrame(plot, slot): CFrame
	return plot.CFrame * CFrame.new(slot.X, 0, slot.Z) * CFrame.Angles(0, math.rad(slot.Rot or 0), 0)
end

-- Panneau d'achat : devant le passage, côté terrain déjà possédé.
local function signCFrame(plot, areaId: string): CFrame
	local opening = Land.Openings[Land.SignOpening[areaId]]
	local x, z = opening.X, opening.Z
	if opening.Along == "X" then
		z -= 5
	else
		x -= 5 * math.sign(x)
	end
	return plot.CFrame * CFrame.new(x + (if opening.Along == "X" then 7 else 0), 0, z)
end

local function rateLine(def, level: number): string
	return string.format(
		"+%s %s/min · +%s or/min par membre en ligne",
		Formulas.formatNumber(math.floor(Formulas.machineRate(Machines, def, level) * 60 * 10 + 0.5) / 10),
		materialName[def.Material] or def.Material,
		Formulas.formatNumber(
			math.floor(Formulas.machineGold(Machines, def, level) * Machines.PersonalGoldShare * 60 + 0.5)
		)
	)
end

-- Géométrie fixe des extensions d'une parcelle (construite une fois au démarrage).
local function buildLand(plot)
	local folder = Instance.new("Folder")
	folder.Name = "Land"
	folder.Parent = plot.Model
	local state: LandState = {
		Folder = folder,
		Floors = {},
		Barriers = {},
		SlotsFolder = Instance.new("Folder"),
		Slots = {},
		Sign = nil,
	}
	state.SlotsFolder.Name = "Machines"
	state.SlotsFolder.Parent = folder
	for _, area in Land.Areas do
		local areaFolder = Instance.new("Folder")
		areaFolder.Name = area.Id
		areaFolder.Parent = folder
		local floor, fallow = Models.landFloor(plot.CFrame, area.Rect, areaFolder)
		state.Floors[area.Id] = { Floor = floor, Fallow = fallow }
	end
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder
	for _, seg in Formulas.landWalls(Land) do
		Models.landWall(plot.CFrame, seg.X1, seg.Z1, seg.X2, seg.Z2, walls)
	end
	for i, opening in Land.Openings do
		local barrier = Models.landBarrier(plot.CFrame, opening.X, opening.Z, opening.Along, Land.OpeningWidth)
		barrier.Parent = folder
		state.Barriers[i] = barrier
	end
	states[plot] = state
end

-- Dalles de pavés du pack importé (« 02_Sol_pave ») sur une extension achetée : modules de 8
-- studs alignés sur l'extension. Ignoré si le décor n'est pas importé ou s'il coûterait trop de
-- pièces (pack non fusionné : voir docs/IMPORT_DECORS.md).
local PAVING_BUDGET = 700

function paveArea(plot, rect, parent: Instance): Folder?
	if not Models.hasDecor("02_Sol_pave") then
		return nil
	end
	local sx, sz = rect[2] - rect[1], rect[4] - rect[3]
	local nx, nz = math.max(1, math.floor(sx / 8 + 0.5)), math.max(1, math.floor(sz / 8 + 0.5))
	local perTile = Models.decorPartCount("02_Sol_pave") + 1
	if nx * nz * perTile > PAVING_BUDGET then
		warn(
			string.format(
				"[LandService] Pavés : %d pièces pour une extension, trop coûteux (fusionner le modèle).",
				nx * nz * perTile
			)
		)
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Paving"
	folder.Parent = parent
	local stepX, stepZ = sx / nx, sz / nz
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local cf = plot.CFrame * CFrame.new(rect[1] + (i + 0.5) * stepX, 0, rect[3] + (j + 0.5) * stepZ)
			local tile = Models.decor("02_Sol_pave", cf, { Scale = stepZ / 8, StretchX = stepX / stepZ })
			if tile then
				tile.Parent = folder
			end
		end
	end
	return folder
end

local function clearSlots(state: LandState)
	state.SlotsFolder:ClearAllChildren()
	table.clear(state.Slots)
	if state.Sign then
		state.Sign.Model:Destroy()
		state.Sign = nil
	end
end

local function makePrompt(parent: Instance, action: string, object: string, onTrigger)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.5 -- évite les achats accidentels
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	prompt.Triggered:Connect(onTrigger)
	return prompt
end

-- Emplacement : socle (à construire) ou machine à son niveau (à améliorer).
local function renderSlot(plot, state: LandState, slot, level: number, materials)
	local def = machineById[slot.Machine]
	local current = state.Slots[slot.Id]
	if current and current.Level ~= level then
		current.Model:Destroy()
		state.Slots[slot.Id] = nil
		current = nil
	end
	if not current then
		local model, anchor, gem
		if level > 0 then
			model, anchor = Models.machine(def.Id, slotCFrame(plot, slot), level)
			CollectionService:AddTag(model, "MachineBelt")
			local c = Models.Colors
			local blockColor = if def.Material == "Wood"
				then c.WoodLight
				elseif def.Material == "Stone" then c.Stone
				elseif def.Material == "Crystal" then c.Ether
				else Color3.fromRGB(190, 120, 80)
			model:SetAttribute("BlockColor", blockColor)
			model:SetAttribute("Interval", math.max(0.6, 3 / level))
		else
			model, _, gem = Models.pedestal(slotCFrame(plot, slot))
			anchor = gem
		end
		model.Name = slot.Id
		model.Parent = state.SlotsFolder
		local label = CostPanel.new(anchor, if level > 0 then 0.5 else 1.2, 70)
		local prompt = makePrompt(
			if level > 0 then anchor else gem :: BasePart,
			if level > 0 then "Améliorer" else "Construire",
			def.Name,
			function(player)
				LandService.machineAction(player, slot.Id)
			end
		)
		current = { Model = model, Level = level, Label = label, Prompt = prompt, Gem = gem }
		state.Slots[slot.Id] = current
	end
	local entry = current :: any
	if level <= 0 then
		local affordable = Formulas.canAfford(materials, def.Cost)
		CostPanel.set(entry.Label, {
			Title = def.Name,
			Cost = def.Cost,
			Have = materials,
			Lines = { rateLine(def, 1) },
			Status = if affordable then "Maintenir E pour construire" else "Il manque des ressources",
			Kind = if affordable then "ok" else "missing",
		})
		entry.Gem.Color = if affordable then READY else MISSING
	elseif level >= Machines.MaxLevel then
		CostPanel.set(entry.Label, {
			Title = string.format("%s · niv. %d", def.Name, level),
			Lines = { rateLine(def, level) },
			Status = "Niveau maximum atteint",
			Kind = "info",
		})
		entry.Prompt.Enabled = false
	else
		local cost = Formulas.machineUpgradeCost(Machines, def, level)
		local affordable = Formulas.canAfford(materials, cost)
		CostPanel.set(entry.Label, {
			Title = string.format("%s · niv. %d → %d", def.Name, level, level + 1),
			Cost = cost,
			Have = materials,
			Lines = { rateLine(def, level) },
			Status = if affordable then "Maintenir E pour améliorer" else "Il manque des ressources",
			Kind = if affordable then "ok" else "missing",
		})
		entry.Prompt.Enabled = true
	end
end

local function render(plot, data)
	local state = states[plot]
	if not state then
		return
	end
	local level = data.Land or 0
	local owned = Formulas.landOwned(Land, level)
	for _, area in Land.Areas do
		local entry = state.Floors[area.Id]
		local isOwned = owned[area.Id] == true
		entry.Floor.Color = if isOwned then PAVED else FALLOW
		entry.Floor.Material = Enum.Material.SmoothPlastic -- style lisse (Config/VisualStyle)
		entry.Fallow.Parent = if isOwned then nil else entry.Floor.Parent
		if isOwned and not entry.Paving then
			entry.Paving = paveArea(plot, area.Rect, entry.Floor.Parent :: Instance)
		elseif not isOwned and entry.Paving then
			entry.Paving:Destroy()
			entry.Paving = nil
		end
	end
	for i, opening in Land.Openings do
		local open = owned[opening.A] and owned[opening.B]
		state.Barriers[i].Parent = if open then nil else state.Folder
	end
	-- Machines des extensions possédées
	for _, area in Land.Areas do
		for _, slot in area.Slots do
			if owned[area.Id] then
				renderSlot(plot, state, slot, data.Machines[slot.Id] or 0, data.Materials)
			elseif state.Slots[slot.Id] then
				state.Slots[slot.Id].Model:Destroy()
				state.Slots[slot.Id] = nil
			end
		end
	end
	-- Panneau d'achat de la prochaine extension
	local nextArea = Formulas.landNext(Land, level)
	if state.Sign and (not nextArea or state.Sign.AreaId ~= nextArea.Id) then
		state.Sign.Model:Destroy()
		state.Sign = nil
	end
	if nextArea and not state.Sign then
		local model, part, gem = Models.pedestal(signCFrame(plot, nextArea.Id))
		model.Name = "LandSign"
		model.Parent = state.Folder
		local label = CostPanel.new(gem, 1.2, 80)
		makePrompt(part, "Agrandir", nextArea.Name, function(player)
			LandService.buyArea(player)
		end)
		state.Sign = { Model = model, Gem = gem, Label = label, AreaId = nextArea.Id }
	end
	if nextArea and state.Sign then
		local slots = #nextArea.Slots
		local affordable = Formulas.canAfford(data.Materials, nextArea.Cost)
		CostPanel.set(state.Sign.Label, {
			Title = string.format("Agrandir : %s (%d/%d)", nextArea.Name, level + 1, #Land.Areas),
			Cost = nextArea.Cost,
			Have = data.Materials,
			Lines = { string.format("+%d emplacement(s) de machine", slots) },
			Status = if affordable then "Maintenir E pour agrandir" else "Il manque des ressources",
			Kind = if affordable then "ok" else "missing",
		})
		state.Sign.Gem.Color = if affordable then READY else MISSING
	end
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if (lastAction[player] or 0) + 0.5 > now then
		return true
	end
	lastAction[player] = now
	return false
end

local function near(player: Player, position: Vector3, range: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - position).Magnitude <= range
end

local function notEnough(player: Player, materials, cost)
	local parts = {}
	for _, m in Formulas.missingMaterials(Materials, materials, cost) do
		table.insert(parts, string.format("%d %s", m.Missing, m.Name))
	end
	Notifier.send(player, string.format(Texts.NotEnough, table.concat(parts, ", ")), "error")
end

function LandService.buyArea(player: Player)
	if throttled(player) then
		return
	end
	local group, err = GroupService.authorize(player, "Build")
	if not group then
		Notifier.send(player, err or Texts.NoPermission, "error")
		return
	end
	local plot = PlotService.get(group.Id)
	if not plot then
		Notifier.send(player, Texts.NoPlot, "error")
		return
	end
	local data = group.Data
	local area = Formulas.landNext(Land, data.Land)
	if not area then
		return
	end
	if not near(player, signCFrame(plot, area.Id).Position, 16) then
		Notifier.send(player, Texts.TooFar, "error")
		return
	end
	if not Formulas.canAfford(data.Materials, area.Cost) then
		notEnough(player, data.Materials, area.Cost)
		return
	end
	-- Débit + agrandissement, sans attente entre la vérification et l'écriture.
	for id, amount in area.Cost do
		data.Materials[id] -= amount
	end
	data.Land += 1
	GroupService.markChanged(group, true)
	for member in group.Online do
		Notifier.send(member, string.format("🏗 Le bastion s'agrandit : %s !", area.Name), "success")
	end
end

function LandService.machineAction(player: Player, slotId: string)
	if throttled(player) then
		return
	end
	local slot = slotById[slotId]
	if not slot then
		return
	end
	local group, err = GroupService.authorize(player, "Build")
	if not group then
		Notifier.send(player, err or Texts.NoPermission, "error")
		return
	end
	local plot = PlotService.get(group.Id)
	if not plot then
		Notifier.send(player, Texts.NoPlot, "error")
		return
	end
	local data = group.Data
	if not Formulas.landOwned(Land, data.Land)[areaOfSlot[slotId]] then
		return
	end
	if not near(player, slotCFrame(plot, slot).Position, 18) then
		Notifier.send(player, Texts.TooFar, "error")
		return
	end
	local def = machineById[slot.Machine]
	local level = data.Machines[slotId] or 0
	if level >= Machines.MaxLevel then
		return
	end
	local cost = if level == 0 then def.Cost else Formulas.machineUpgradeCost(Machines, def, level)
	if not Formulas.canAfford(data.Materials, cost) then
		notEnough(player, data.Materials, cost)
		return
	end
	for id, amount in cost do
		data.Materials[id] -= amount
	end
	data.Machines[slotId] = level + 1
	GroupService.markChanged(group, true)
	for member in group.Online do
		Notifier.send(
			member,
			if level == 0
				then string.format("⚙ %s construite !", def.Name)
				else string.format("⚙ %s : niveau %d !", def.Name, level + 1),
			"success"
		)
	end
end

-- Production en ligne : une seconde de machines pour un groupe chargé avec une parcelle.
local function produce(group, dt: number, publish: boolean)
	local data = group.Data
	if not GroupService.canMutate(group) then
		return
	end
	local rates = Formulas.machineRates(Machines, Land, data.Land, data.Machines)
	local changed = false
	for matId, perSecond in rates.Materials do
		local total = (data.MachineCarry[matId] or 0) + perSecond * dt
		local whole = math.floor(total)
		data.MachineCarry[matId] = total - whole
		if whole > 0 then
			data.Materials[matId] = Formulas.clamp((data.Materials[matId] or 0) + whole, Economy.MaterialCap)
			changed = true
		end
	end
	data.MachineAt = os.time()
	if rates.PersonalGold > 0 then
		for member in group.Online do
			local profile = ProfileService.get(member)
			if profile and ProfileService.canMutate(member) then
				profile.Gold = Formulas.clamp(profile.Gold + rates.PersonalGold * dt, Economy.GoldCap)
				if publish then
					ProfileService.sync(member)
				end
			end
		end
	end
	if changed and publish then
		GroupService.markChanged(group)
	end
end

function LandService.init()
	for _, plot in PlotService.all() do
		buildLand(plot)
	end
	PlotService.onRefresh(render)
	PlotService.onRelease(function(plot)
		local state = states[plot]
		if state then
			clearSlots(state)
			render(plot, { Land = 0, Machines = {}, Materials = {} })
			clearSlots(state)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

function LandService.start()
	task.spawn(function()
		local last = os.clock()
		local tick = 0
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = math.min(now - last, 5)
			last = now
			tick += 1
			for _, plot in PlotService.all() do
				local group = plot.GroupId and GroupService.get(plot.GroupId)
				if group then
					local ok, err = pcall(produce, group, dt, tick % SYNC_EVERY == 0)
					if not ok then
						warn("[LandService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return LandService
