--[[
	Point d'entrée serveur. Ordre :
	1. init()  : préparation sans dépendance au joueur (monde, callbacks)
	2. start() : boucles et connexions aux événements joueurs
	Quand les données d'un joueur sont chargées : parcelle -> mannequin -> économie.
]]

local Players = game:GetService("Players")

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local MonetizationService = require(Services.MonetizationService)
local EconomyService = require(Services.EconomyService)
local TrainingService = require(Services.TrainingService)
local Notifier = require(Services.Notifier)

DataService.init()
PlotService.init()
MonetizationService.init()
EconomyService.init()

DataService.onLoaded(function(player: Player, data)
	local plot = PlotService.claim(player, data.Buildings)
	if not plot then
		-- Le nombre max de joueurs du serveur doit égaler PLOT_COUNT (Game Settings > Places).
		Notifier.send(player, "Toutes les bases sont occupées sur ce serveur.", "error")
		return
	end
	TrainingService.setup(player, plot)
	EconomyService.onPlayerReady(player, data)
	if DataService.isMemoryMode() then
		Notifier.send(player, "Mode test : la progression ne sera pas sauvegardée.", "error")
	end
end)

PlotService.start()
EconomyService.start()
TrainingService.start()
DataService.start() -- en dernier : déclenche le chargement des joueurs

print(string.format("[FantasyTycoon] Serveur prêt (%d joueur(s))", #Players:GetPlayers()))
