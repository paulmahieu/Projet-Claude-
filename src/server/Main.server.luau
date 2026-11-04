--[[
	Point d'entrée serveur — Bastions d'Éther.
	1. init()  : préparation (monde, magasins de données, connexions entre services)
	2. start() : boucles et événements joueurs. ProfileService démarre en DERNIER : il
	   déclenche les chargements, une fois tous les abonnements en place.

	Robustesse : chaque étape est isolée (pcall). Une erreur dans un service n'empêche plus
	les autres de démarrer ; elle est journalisée et, dans Studio, affichée à l'écran
	(Diagnostics) pour pouvoir la signaler facilement.
]]

local Services = script.Parent.Services
local Diagnostics = require(Services.Diagnostics)
Diagnostics.init()

local function load(name: string)
	local ok, result = pcall(require, Services[name])
	if not ok then
		Diagnostics.report("Chargement de " .. name, result)
		return nil
	end
	return result
end

local ProfileService = load("ProfileService")
local GroupService = load("GroupService")
local PlotService = load("PlotService")
local HarvestService = load("HarvestService")
local BuildService = load("BuildService")
local TrainingService = load("TrainingService")
local TreeService = load("TreeService")
local MonetizationService = load("MonetizationService")
local PetService = load("PetService")
local BossService = load("BossService")
local StreetService = load("StreetService")
local FarmService = load("FarmService")
local LeaderboardService = load("LeaderboardService")
local RewardService = load("RewardService")
local TitleService = load("TitleService")
local Net = load("Net")

-- Exécute une étape ; en cas d'erreur, la signale et continue.
local function step(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		Diagnostics.report(label, err)
	end
end

local function call(service, method: string, name: string)
	if service and service[method] then
		step(name .. "." .. method, service[method])
	end
end

-- Le monde en premier : sol, point d'accueil et parcelles doivent exister au plus tôt.
call(PlotService, "init", "PlotService")
call(ProfileService, "init", "ProfileService")
call(GroupService, "init", "GroupService")
call(HarvestService, "init", "HarvestService")
call(BuildService, "init", "BuildService")
call(TrainingService, "init", "TrainingService")
call(MonetizationService, "init", "MonetizationService")
call(PetService, "init", "PetService")
call(BossService, "init", "BossService")
call(StreetService, "init", "StreetService")
call(FarmService, "init", "FarmService") -- après TrainingService.init (ordre des calculs hors ligne)
call(LeaderboardService, "init", "LeaderboardService")

step("Liaisons combat", function()
	-- Esquive et Frappe runique partagées entre arènes et Rue des boss.
	StreetService.setInvulnerabilityCheck(BossService.isInvulnerable)
	BossService.setStrikeFallback(StreetService.strike)
end)
call(Net, "init", "Net")

step("Liaison récolte", function()
	-- La récolte est incompatible avec l'entraînement.
	HarvestService.beforeHarvest(function(player)
		TrainingService.stop(player)
	end)
end)

call(GroupService, "start", "GroupService")
call(TrainingService, "start", "TrainingService")
call(TreeService, "start", "TreeService")
call(PetService, "start", "PetService")
call(BossService, "start", "BossService")
call(StreetService, "start", "StreetService")
call(FarmService, "start", "FarmService")
call(LeaderboardService, "start", "LeaderboardService")
call(RewardService, "start", "RewardService")
call(TitleService, "start", "TitleService")
call(ProfileService, "start", "ProfileService")
Diagnostics.startVoidRescue()

print(string.format("[Bastions d'Éther] Serveur prêt (%d erreur(s) au démarrage)", Diagnostics.count()))
