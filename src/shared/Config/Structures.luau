--[[
	Constructions prédéfinies du bastion, achetées avec les matériaux COMMUNS du groupe
	(cahier §5). Module pur.

	Id          : identifiant stable, sauvegardé (ne jamais renommer un Id publié)
	Cost        : { [MaterialId] = quantité }
	Requires    : Id d'une construction préalable (nil = disponible)
	Effect      : texte affiché AVANT achat (coût, prérequis et effet sont visibles)
	Effects     : effets réellement appliqués par le code
	              Stations     : positions {x, z} des tapis créés
	              StationTier  : palier des tapis créés (multiplie l'XP et l'or)
	              TrainingMult : bonus du bastion sur tous ses tapis (0.10 = +10 %)
	              HarvestBonus : { [MaterialId] = bonus par récolte }
	              RequiredRebirths : renaissances personnelles nécessaires pour UTILISER ces tapis
	Offset/Size : position {x, z} et taille {x, y, z} relatives à la parcelle.
	              z négatif = entrée (côté hub). Parcelle de 90 x 90 (de -45 à 45).
]]

return {
	{
		Id = "TrainingGround",
		Name = "Terrain d'entraînement",
		Cost = { Wood = 10 },
		Requires = nil,
		Effect = "2 tapis d'entraînement : XP et or",
		Effects = { Stations = { { -28, -14 }, { -16, -14 } }, StationTier = 1 },
		Offset = { -22, -14 },
		Size = { 26, 0.4, 14 },
		Color = { 120, 90, 60 },
		Material = "WoodPlanks",
	},
	{
		Id = "Palisade",
		Name = "Palissade",
		Cost = { Wood = 30, Stone = 10 },
		Requires = "TrainingGround",
		Effect = "Protège le fond du bastion",
		Effects = {},
		Offset = { 0, 42 },
		Size = { 86, 8, 2 },
		Color = { 110, 75, 45 },
		Material = "Wood",
	},
	{
		Id = "Sawmill",
		Name = "Scierie",
		Cost = { Wood = 40, Stone = 20 },
		Requires = "Palisade",
		Effect = "+1 bois par récolte",
		Effects = { HarvestBonus = { Wood = 1 } },
		Offset = { -28, 22 },
		Size = { 14, 8, 12 },
		Color = { 140, 95, 55 },
		Material = "WoodPlanks",
	},
	{
		Id = "Quarry",
		Name = "Carrière",
		Cost = { Wood = 60, Stone = 30 },
		Requires = "Sawmill",
		Effect = "+1 pierre par récolte",
		Effects = { HarvestBonus = { Stone = 1 } },
		Offset = { 28, 22 },
		Size = { 14, 8, 12 },
		Color = { 120, 120, 125 },
		Material = "Slate",
	},
	{
		Id = "RuneMats",
		Name = "Tapis runiques",
		Cost = { Wood = 80, Stone = 60 },
		Requires = "Quarry",
		Effect = "2 tapis runiques : XP et or x1,5",
		Effects = { Stations = { { 16, -14 }, { 28, -14 } }, StationTier = 2 },
		Offset = { 22, -14 },
		Size = { 26, 0.4, 14 },
		Color = { 70, 60, 120 },
		Material = "Slate",
	},
	{
		Id = "Watchtower",
		Name = "Tour de guet",
		Cost = { Wood = 120, Stone = 100 },
		Requires = "RuneMats",
		Effect = "+10 % d'XP et d'or sur tous les tapis",
		Effects = { TrainingMult = 0.10 },
		Offset = { 0, 30 },
		Size = { 8, 22, 8 },
		Color = { 150, 150, 140 },
		Material = "Cobblestone",
	},
	{
		Id = "EtherMats",
		Name = "Tapis d'Éther",
		Cost = { Wood = 200, Stone = 150, Crystal = 10 },
		Requires = "Watchtower",
		Effect = "2 tapis x3 (renaissance 1 requise pour s'y entraîner)",
		Effects = { Stations = { { -4, -14 }, { 4, -14 } }, StationTier = 3, RequiredRebirths = 1 },
		Offset = { 0, -14 },
		Size = { 16, 0.4, 12 },
		Color = { 60, 120, 150 },
		Material = "Slate",
	},
	{
		Id = "CelestialMats",
		Name = "Tapis célestes",
		Cost = { Wood = 400, Stone = 300, Ore = 20, Crystal = 40 },
		Requires = "EtherMats",
		Effect = "2 tapis x6 (renaissance 3 requise pour s'y entraîner)",
		Effects = { Stations = { { -29, 4 }, { -19, 4 } }, StationTier = 4, RequiredRebirths = 3 },
		Offset = { -24, 4 },
		Size = { 18, 0.4, 10 },
		Color = { 230, 210, 140 },
		Material = "Marble",
	},
}
