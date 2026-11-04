--[[
	TrainingService : tapis d'entraînement du bastion (cahier §8).

	- Les tapis sont créés par les constructions (Terrain d'entraînement, Tapis runiques).
	- Le joueur entre explicitement en entraînement (ProximityPrompt). Un tapis = un joueur,
	  un joueur = un tapis. Seuls les membres actifs du groupe peuvent l'utiliser.
	- Gains : XP d'entraînement (-> niveau -> Puissance) et or individuel, chaque seconde.
	- Arrêt : sortie du tapis, mort, départ, changement de groupe, récolte (action incompatible).
	- Instantané du rendement AFK DURABLE avant chaque sauvegarde du profil : base du calcul
	  hors ligne (aucun bonus temporaire, aucune amélioration future n'y entre).
	- Aucune entrée n'est simulée pour éviter la déconnexion d'inactivité de Roblox (§8) :
	  au-delà, ce sont les gains hors ligne qui prennent le relais.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Training = require(Shared.Config.Training)
local Structures = require(Shared.Config.Structures)
local Economy = require(Shared.Config.Economy)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)
local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local Notifier = require(script.Parent.Notifier)
local Models = require(script.Parent.Parent.Art.Models)

local TrainingService = {}

type Station = {
	Id: string,
	GroupId: string,
	Tier: number,
	RequiredRebirths: number,
	Part: BasePart, -- plateforme (porte le ProximityPrompt)
	Rune: BasePart, -- cercle lumineux qui pulse à chaque gain
	Prompt: ProximityPrompt,
	Occupant: Player?,
}

local stationsByGroup: { [string]: { [string]: Station } } = {}
local training: { [Player]: Station } = {}

-- Rendement durable (sans bonus temporaire) d'un joueur sur un palier de tapis.
local function durableRates(player: Player, tier: number)
	local profile = ProfileService.get(player)
	local group = GroupService.groupOf(player)
	if not profile or not group then
		return { Xp = 0, Gold = 0 }
	end
	return Formulas.trainingRates(
		tier,
		Formulas.groupTrainingMult(Structures, group.Data.Structures),
		ProfileService.treeStat(player, "TrainingMult"), -- nœuds « Concentration »
		1,
		Training,
		ProfileService.personalMultiplier(player) -- renaissances x compagnons
	)
end

function TrainingService.isTraining(player: Player): boolean
	return training[player] ~= nil
end

function TrainingService.stop(player: Player, message: string?)
	local station = training[player]
	if not station then
		return
	end
	training[player] = nil
	station.Occupant = nil
	station.Prompt.ActionText = "S'entraîner"
	if player.Parent then
		player:SetAttribute("Training", false)
		player:SetAttribute("TrainingRate", "")
		if message then
			Notifier.send(player, message, "info")
		end
	end
end

local function start(player: Player, station: Station)
	local group = GroupService.groupOf(player)
	if not group or group.Id ~= station.GroupId then
		Notifier.send(player, Texts.NotYourBase, "error")
		return
	end
	if not ProfileService.canMutate(player) then
		Notifier.send(player, Texts.ReadOnly, "error")
		return
	end
	local profile = ProfileService.get(player)
	if profile and profile.Rebirths < station.RequiredRebirths then
		Notifier.send(
			player,
			string.format("Renaissance %d requise pour ce tapis (menu > Renaissance).", station.RequiredRebirths),
			"error"
		)
		return
	end
	if training[player] == station then
		TrainingService.stop(player, Texts.TrainingStop)
		return
	end
	if station.Occupant and station.Occupant ~= player then
		Notifier.send(player, Texts.TrainingBusy, "error")
		return
	end
	TrainingService.stop(player) -- un seul tapis à la fois
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	character:PivotTo(station.Part.CFrame * CFrame.new(0, 3, 0))
	station.Occupant = player
	training[player] = station
	station.Prompt.ActionText = "Arrêter"
	player:SetAttribute("Training", true)
	local rates = durableRates(player, station.Tier)
	player:SetAttribute(
		"TrainingRate",
		string.format("+%s XP/s · +%s or/s", Formulas.formatNumber(rates.Xp), Formulas.formatNumber(rates.Gold))
	)
	Notifier.send(player, Texts.TrainingStart, "info")
end

local MAT_NAMES = { "Tapis d'entraînement", "Tapis runique", "Tapis d'Éther", "Tapis céleste" }

local function createStation(group, plot, id: string, pos, tier: number, requiredRebirths: number)
	-- Posé sur le sol de la construction (0,3 stud d'épaisseur).
	local model, part, rune = Models.trainingMat(PlotService.localCFrame(plot, pos[1], 0.3, pos[2]), tier)
	model.Name = id
	model.Parent = plot.StationsFolder
	rune:SetAttribute("RestTransparency", rune.Transparency)
	PlotService.makeBillboard(
		part,
		(MAT_NAMES[tier] or MAT_NAMES[1])
			.. string.format(" · x%s", tostring(Training.TierMultiplier[tier] or 1))
			.. (if requiredRebirths > 0 then string.format("\nRenaissance %d", requiredRebirths) else ""),
		6,
		Vector2.new(8, 1.4)
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "S'entraîner"
	prompt.ObjectText = "Tapis d'entraînement"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local station: Station = {
		Id = id,
		GroupId = group.Id,
		Tier = tier,
		RequiredRebirths = requiredRebirths,
		Part = part,
		Rune = rune,
		Prompt = prompt,
		Occupant = nil,
	}
	prompt.Triggered:Connect(function(player)
		start(player, station)
	end)
	return station
end

-- Crée les tapis manquants selon les constructions possédées (idempotent).
local function ensureStations(group)
	local plot = PlotService.get(group.Id)
	if not plot then
		return
	end
	local stations = stationsByGroup[group.Id]
	if not stations then
		stations = {}
		stationsByGroup[group.Id] = stations
	end
	for _, def in Structures do
		local positions = def.Effects.Stations
		if group.Data.Structures[def.Id] and positions then
			for index, pos in positions do
				local id = def.Id .. "_" .. index
				if not stations[id] or not stations[id].Part.Parent then
					stations[id] = createStation(
						group,
						plot,
						id,
						pos,
						def.Effects.StationTier or 1,
						def.Effects.RequiredRebirths or 0
					)
				end
			end
		end
	end
end

local function pulse(rune: BasePart)
	if rune.Parent then
		rune.Transparency = 0
		TweenService:Create(rune, TweenInfo.new(0.8), { Transparency = rune:GetAttribute("RestTransparency") or 0.4 })
			:Play()
	end
end

local function tick(player: Player, station: Station, dt: number)
	local profile = ProfileService.get(player)
	local group = GroupService.groupOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not profile
		or not group
		or group.Id ~= station.GroupId
		or not station.Part.Parent
		or not root
		or not humanoid
		or humanoid.Health <= 0
	then
		TrainingService.stop(player, Texts.TrainingStop)
		return
	end
	if (root.Position - station.Part.Position).Magnitude > Training.MaxRange then
		TrainingService.stop(player, Texts.TrainingStop)
		return
	end
	if not ProfileService.canMutate(player) then
		TrainingService.stop(player, Texts.ReadOnly)
		return
	end

	local rates = durableRates(player, station.Tier)
	local level, xp, gained = Formulas.addXp(profile.Level, profile.TrainXp, rates.Xp * dt, Training)
	profile.Level, profile.TrainXp = level, xp
	profile.Stats.TrainSeconds += dt
	profile.Gold = Formulas.clamp(profile.Gold + rates.Gold * dt, Economy.GoldCap)
	pulse(station.Rune)
	if gained > 0 then
		Notifier.send(player, string.format(Texts.LevelUp, level, ProfileService.power(player)), "success")
	end
	ProfileService.sync(player)
end

function TrainingService.init()
	GroupService.onAttached(function(_, group)
		ensureStations(group)
	end)
	GroupService.onStructuresChanged(ensureStations)
	GroupService.onDetached(function(player)
		TrainingService.stop(player)
	end)
	GroupService.onReleased(function(group)
		local stations = stationsByGroup[group.Id]
		if stations then
			for _, station in stations do
				if station.Occupant then
					TrainingService.stop(station.Occupant)
				end
			end
		end
		stationsByGroup[group.Id] = nil
	end)

	-- Instantané du rendement AFK durable : meilleur tapis disponible dans le bastion.
	ProfileService.beforeSave(function(player, profile)
		local group = GroupService.groupOf(player)
		if group then
			profile.AfkRate =
				durableRates(player, Formulas.bestStationTier(Structures, group.Data.Structures, profile.Rebirths))
		end
	end)
end

function TrainingService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			TrainingService.stop(player)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					TrainingService.stop(player, Texts.TrainingStop)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = math.min(now - last, 5) -- borne en cas de gros ralentissement
			last = now
			for player, station in training do
				tick(player, station, dt)
			end
		end
	end)
end

return TrainingService
