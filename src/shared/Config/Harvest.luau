--[[
	Récolte (forme minimale avancée à l'étape 1 pour financer les constructions).
	Les matériaux vont directement dans la réserve du groupe du récolteur (cahier §3).
	Module pur.
]]

return {
	PlayerCooldown = 1.0, -- secondes minimales entre deux récoltes d'un même joueur
	MaxDistance = 12, -- vérification serveur, en plus de la portée du ProximityPrompt

	Nodes = {
		Tree = { Material = "Wood", Amount = 3, RespawnSeconds = 25, HoldDuration = 0.8, Label = "Arbre" },
		Rock = { Material = "Stone", Amount = 2, RespawnSeconds = 35, HoldDuration = 1.0, Label = "Rocher" },
	},

	-- Zone de récolte : entre chaque paire de parcelles, à cette distance du centre.
	RingRadius = 115,
	-- Disposition dans chaque « bosquet » : { type, décalage tangent, décalage radial }
	Grove = {
		{ "Tree", -8, -6 },
		{ "Tree", 8, -4 },
		{ "Tree", 0, 8 },
		{ "Rock", -10, 10 },
		{ "Rock", 11, 9 },
	},
}
