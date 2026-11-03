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
local UpgradeService = require(Services.UpgradeService)
local MonetizationService = require(Services.MonetizationService)
local Net = require(Services.Net)

ProfileService.init()
GroupService.init()
PlotService.init()
HarvestService.init()
BuildService.init()
TrainingService.init()
MonetizationService.init()
Net.init()

-- La récolte est incompatible avec l'entraînement.
HarvestService.beforeHarvest(function(player)
	TrainingService.stop(player)
end)

GroupService.start()
TrainingService.start()
UpgradeService.start()
ProfileService.start()

print("[Bastions d'Éther] Serveur prêt")
