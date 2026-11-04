--[[
	Compagnons et œufs. Module pur.

	- Les œufs s'achètent avec de l'OR gagné en jeu. Les probabilités sont affichées.
	  (Œufs payants en Robux : décision en attente, voir docs/CONCEPTION.md — le cahier §9.1
	  interdit les caisses aléatoires payantes dans cette version.)
	- Bonus d'un compagnon : multiplicateur additif sur l'XP et l'or des tapis et sur les dégâts.
	  Total plafonné (MaxTotalBonus) : pas de multiplicateur infini (cahier §9).
	- Visuel : forme simple générée par code (Kind), couleur de rareté.
]]

return {
	InventorySize = 40,
	MaxTotalBonus = 6, -- +600 % au maximum, tous compagnons équipés confondus

	Rarities = {
		Common = { Name = "Commun", Color = { 190, 190, 190 }, Order = 1 },
		Rare = { Name = "Rare", Color = { 80, 160, 255 }, Order = 2 },
		Epic = { Name = "Épique", Color = { 180, 90, 255 }, Order = 3 },
		Legendary = { Name = "Légendaire", Color = { 255, 190, 40 }, Order = 4 },
		Mythic = { Name = "Mythique", Color = { 255, 70, 120 }, Order = 5 },
	},

	-- Bonus = +x (0.10 = +10 %)
	List = {
		{
			Id = "Sprout",
			Name = "Pousse sylvestre",
			Rarity = "Common",
			Bonus = 0.10,
			Kind = "Sprout",
			Color = { 120, 200, 90 },
		},
		{
			Id = "Hare",
			Name = "Lièvre des prés",
			Rarity = "Common",
			Bonus = 0.12,
			Kind = "Beast",
			Color = { 200, 170, 130 },
		},
		{
			Id = "RuneWolf",
			Name = "Loup runique",
			Rarity = "Rare",
			Bonus = 0.25,
			Kind = "Beast",
			Color = { 120, 140, 170 },
		},
		{
			Id = "Owl",
			Name = "Hibou des ruines",
			Rarity = "Rare",
			Bonus = 0.30,
			Kind = "Bird",
			Color = { 150, 115, 80 },
		},
		{
			Id = "LittleGolem",
			Name = "Petit golem",
			Rarity = "Epic",
			Bonus = 0.55,
			Kind = "Golem",
			Color = { 140, 140, 150 },
		},
		{
			Id = "LightWisp",
			Name = "Esprit de lumière",
			Rarity = "Epic",
			Bonus = 0.65,
			Kind = "Wisp",
			Color = { 255, 240, 170 },
		},
		{
			Id = "CrystalFox",
			Name = "Renard de cristal",
			Rarity = "Legendary",
			Bonus = 1.2,
			Kind = "Beast",
			Color = { 120, 220, 255 },
		},
		{
			Id = "EmberDrake",
			Name = "Dragonnet de braise",
			Rarity = "Legendary",
			Bonus = 1.5,
			Kind = "Bird",
			Color = { 255, 110, 50 },
		},
		{
			Id = "EtherPhoenix",
			Name = "Phénix d'Éther",
			Rarity = "Mythic",
			Bonus = 3.0,
			Kind = "Bird",
			Color = { 140, 230, 255 },
		},
	},

	-- Position {x, z} des présentoirs, autour du hub. Weights : poids relatifs (probabilités affichées).
	Eggs = {
		{
			Id = "ForestEgg",
			Name = "Œuf de la forêt",
			Cost = 150,
			Color = { 140, 200, 110 },
			Position = { -9, -16 },
			Weights = { Sprout = 45, Hare = 35, RuneWolf = 15, Owl = 5 },
		},
		{
			Id = "RuinEgg",
			Name = "Œuf des ruines",
			Cost = 1500,
			Color = { 170, 140, 220 },
			Position = { 9, -16 },
			Weights = { Hare = 30, RuneWolf = 30, Owl = 22, LittleGolem = 12, LightWisp = 6 },
		},
		{
			Id = "EtherEgg",
			Name = "Œuf d'Éther",
			Cost = 15000,
			Color = { 110, 210, 255 },
			Position = { 0, -18 },
			Weights = { LittleGolem = 40, LightWisp = 33, CrystalFox = 17, EmberDrake = 9, EtherPhoenix = 1 },
		},
	},
}
