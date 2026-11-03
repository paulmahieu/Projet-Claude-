--[[
	Microachats.

	Les identifiants à 0 sont désactivés : ils s'affichent « Bientôt » dans la boutique.
	Pour les activer : créer le produit sur le Creator Hub (expérience publiée requise),
	puis coller son identifiant ici.

	Module pur : testable avec Lune.
]]

return {
	-- Produits consommables (achetables plusieurs fois).
	DevProducts = {
		{
			Key = "GoldPouch",
			ProductId = 0,
			Name = "Bourse d'or",
			Description = "10 minutes de production instantanée",
			-- Récompense indexée sur la production : reste utile à tous les stades du jeu.
			Reward = { Type = "IncomeMinutes", Minutes = 10, MinGold = 500 },
		},
		{
			Key = "GoldChest",
			ProductId = 0,
			Name = "Coffre d'or",
			Description = "1 heure de production instantanée",
			Reward = { Type = "IncomeMinutes", Minutes = 60, MinGold = 3000 },
		},
	},

	-- Passes permanents.
	GamePasses = {
		DoubleGold = {
			GamePassId = 0,
			Name = "Or x2",
			Description = "Double toute la production d'or",
			Multiplier = 2,
		},
		FastTraining = {
			GamePassId = 0,
			Name = "Entraînement x2",
			Description = "Double l'XP d'entraînement",
			Multiplier = 2,
		},
	},
}
