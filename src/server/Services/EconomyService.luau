--[[
	EconomyService : or, production passive, achats de bâtiments, gains hors ligne,
	et synchronisation de l'état vers le client (attributs du joueur + leaderstats).

	Le serveur fait autorité : le client n'envoie jamais de montant, il ne fait qu'afficher.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Buildings = require(Shared.Config.Buildings)
local Economy = require(Shared.Config.Economy)
local Training = require(Shared.Config.Training)
local Formulas = require(Shared.Formulas)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local MonetizationService = require(script.Parent.MonetizationService)
local Notifier = require(script.Parent.Notifier)

local EconomyService = {}

local buildingById = {}
for _, def in Buildings do
	buildingById[def.Id] = def
end

local active: { [Player]: boolean } = {} -- joueurs prêts (données + parcelle)

function EconomyService.incomePerSecond(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	return Formulas.incomePerSecond(
		Buildings,
		data.Buildings,
		data.Level,
		Economy.IncomeBonusPerLevel,
		MonetizationService.passMultiplier(player, "DoubleGold")
	)
end

-- Pousse l'état vers le client. Les attributs sont répliqués automatiquement.
function EconomyService.sync(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("Gold", data.Gold)
	player:SetAttribute("IncomePerSec", EconomyService.incomePerSecond(player))
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("Xp", data.Xp)
	player:SetAttribute("XpNext", Formulas.xpToNext(data.Level, Training))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Or.Value = math.floor(data.Gold);
		(leaderstats :: any).Niveau.Value = data.Level
	end
end

function EconomyService.addGold(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.Gold = Formulas.clampGold(data.Gold + amount, Economy.GoldCap)
	data.Stats.TotalEarned += amount
	EconomyService.sync(player)
	PlotService.updatePads(player, data.Buildings, data.Gold)
end

function EconomyService.tryBuy(player: Player, buildingId: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local def = buildingById[buildingId]
	local ok, reason = Formulas.canBuy(def, data.Buildings, data.Gold)
	if not ok then
		if reason == "Or insuffisant" then
			Notifier.send(
				player,
				string.format("Il vous manque %s or.", Formulas.formatNumber(def.Cost - data.Gold)),
				"error"
			)
		end
		return
	end
	data.Gold -= def.Cost
	data.Buildings[def.Id] = true
	PlotService.addBuilding(player, def.Id)
	PlotService.updatePads(player, data.Buildings, data.Gold)
	EconomyService.sync(player)
	Notifier.send(player, def.Name .. " construit !", "success")
end

local function createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local gold = Instance.new("NumberValue")
	gold.Name = "Or"
	gold.Parent = folder
	local level = Instance.new("IntValue")
	level.Name = "Niveau"
	level.Parent = folder
	folder.Parent = player
end

local function grantOfflineEarnings(player: Player, data)
	if data.LastOnline <= 0 then
		Notifier.send(player, "Bienvenue ! Marchez sur le cercle vert pour construire votre feu de camp.", "info")
		return
	end
	-- Les gains hors ligne utilisent la production calculée avec les données sauvegardées.
	local elapsed = os.time() - data.LastOnline
	local gold, seconds = Formulas.offlineEarnings(EconomyService.incomePerSecond(player), elapsed, Economy.Offline)
	if gold > 0 then
		EconomyService.addGold(player, gold)
		Notifier.send(
			player,
			string.format(
				"Pendant votre absence (%s), votre base a produit %s or.",
				Formulas.formatDuration(seconds),
				Formulas.formatNumber(gold)
			),
			"reward"
		)
	end
end

-- Appelé par Main une fois les données chargées et la parcelle attribuée.
function EconomyService.onPlayerReady(player: Player, data)
	createLeaderstats(player)
	grantOfflineEarnings(player, data)
	EconomyService.sync(player)
	PlotService.updatePads(player, data.Buildings, data.Gold)
	active[player] = true
end

function EconomyService.init()
	PlotService.setPadHandler(EconomyService.tryBuy)
end

function EconomyService.start()
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
	end)

	-- Boucle de production : une fois par seconde, crédite chaque joueur actif.
	-- Avec 6 joueurs max par serveur, le coût est négligeable.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last -- tient compte des ralentissements du serveur
			last = now
			for player in active do
				local data = DataService.get(player)
				if data then
					data.Stats.PlaySeconds += dt
					EconomyService.addGold(player, EconomyService.incomePerSecond(player) * dt)
				end
			end
		end
	end)
end

return EconomyService
