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
		-- Arbres rares (planches du créateur) : plus précieux mais moins nombreux et plus longs à
		-- repousser ; placés dans les bosquets ENTRE les bastions (équitable pour tous).
		AncientTree = {
			Material = "Wood",
			Amount = 8,
			RespawnSeconds = 60,
			HoldDuration = 1.5,
			Label = "Arbre ancestral",
			Model = "Ancient",
		},
		ArcaneWillow = {
			Material = "Wood",
			Amount = 6,
			Bonus = { Crystal = 1 },
			RespawnSeconds = 120,
			HoldDuration = 2.0,
			Label = "Saule arcanique",
			Model = "Willow",
		},
		Rock = { Material = "Stone", Amount = 2, RespawnSeconds = 35, HoldDuration = 1.0, Label = "Rocher" },
		-- Minerai de cristal (pack de décors) : source régulière de cristal, rare et lente.
		CrystalOre = {
			Material = "Crystal",
			Amount = 2,
			Bonus = { Stone = 1 },
			RespawnSeconds = 90,
			HoldDuration = 1.6,
			Label = "Minerai de cristal",
			Model = "CrystalOre",
		},
	},

	-- Zone de récolte : entre chaque paire de parcelles, à cette distance du centre.
	RingRadius = 128, -- au-delà de la route qui fait le tour du château
	-- Disposition dans chaque « bosquet » : { type, décalage tangent, décalage radial }
	Grove = {
		{ "Tree", -8, -6 },
		{ "Tree", 8, -4 },
		{ "Tree", 0, 8 },
		{ "Rock", -10, 10 },
		{ "Rock", 11, 9 },
	},

	-- Arbre rare supplémentaire dans certains bosquets : { type, bosquets, décalage tangent, radial }.
	Specials = {
		{ "AncientTree", { 1, 3, 5, 7 }, 0, -17 },
		{ "ArcaneWillow", { 2, 6 }, 0, -18 },
		{ "CrystalOre", { 4, 8 }, 0, -16 },
		{ "CrystalOre", { 1, 5 }, 15, 1 },
	},
}
