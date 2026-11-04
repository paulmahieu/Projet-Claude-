--[[
	Point d'entrée serveur — Bastions d'Éther.
	1. init()  : préparation (monde, magasins de données, connexions entre services)
	2. start() : boucles et événements joueurs. ProfileService démarre en DERNIER : il
	   déclenche les chargements, une fois tous les abonnements en place.
]]

local Services = script.Parent.Services
local ProfileService = require(Services.ProfileService)
local GroupService = require(Services.GroupService)
local PlotService = require(Services.PlotService)
local HarvestService = require(Services.HarvestService)
local BuildService = require(Services.BuildService)
local TrainingService = require(Services.TrainingService)
local TreeService = require(Services.TreeService)
local MonetizationService = require(Services.MonetizationService)
local PetService = require(Services.PetService)
local BossService = require(Services.BossService)
local StreetService = require(Services.StreetService)
local FarmService = require(Services.FarmService)
local LeaderboardService = require(Services.LeaderboardService)
local Net = require(Services.Net)

ProfileService.init()
GroupService.init()
PlotService.init()
HarvestService.init()
BuildService.init()
TrainingService.init()
MonetizationService.init()
PetService.init()
BossService.init()
StreetService.init()
FarmService.init() -- après TrainingService.init (ordre des calculs hors ligne)
LeaderboardService.init()
-- Esquive et Frappe runique partagées entre arènes et Rue des boss.
StreetService.setInvulnerabilityCheck(BossService.isInvulnerable)
BossService.setStrikeFallback(StreetService.strike)
Net.init()

-- La récolte est incompatible avec l'entraînement.
HarvestService.beforeHarvest(function(player)
	TrainingService.stop(player)
end)

GroupService.start()
TrainingService.start()
TreeService.start()
PetService.start()
BossService.start()
StreetService.start()
FarmService.start()
LeaderboardService.start()
ProfileService.start()

print("[Bastions d'Éther] Serveur prêt")
