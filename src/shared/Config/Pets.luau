--[[
	Compagnons et œufs. Module pur.

	- Œufs GRATUITS (or gagné en jeu) : uniquement Commun à Légendaire.
	- Œufs ROYAUX (Robux, champ Product -> Config/Products) : Légendaire à Céleste. Décision du
	  porteur du projet (remplace l'interdiction initiale du cahier §9.1). Garde-fous :
	  probabilités affichées AVANT l'achat ; achat masqué là où les objets aléatoires payants
	  sont interdits (PolicyService) ; l'œuf royal s'obtient aussi gratuitement (1 h de jeu
	  par jour, parcours du champion) ; un œuf payé est toujours livré, même inventaire plein.
	- Bonus d'un compagnon : multiplicateur additif sur l'XP et l'or des tapis et sur les dégâts.
	  Total plafonné (MaxTotalBonus) : pas de multiplicateur infini (cahier §9).
	- Visuel : forme simple générée par code (Kind), couleur de rareté.
]]

return {
	InventorySize = 40,
	MaxTotalBonus = 15, -- +1 500 % au maximum, tous compagnons équipés confondus
	FreeMaxOrder = 4, -- les œufs à l'or s'arrêtent à Légendaire (vérifié par les tests)

	Rarities = {
		Common = { Name = "Commun", Color = { 190, 190, 190 }, Order = 1 },
		Rare = { Name = "Rare", Color = { 80, 160, 255 }, Order = 2 },
		Epic = { Name = "Épique", Color = { 180, 90, 255 }, Order = 3 },
		Legendary = { Name = "Légendaire", Color = { 255, 190, 40 }, Order = 4 },
		Mythic = { Name = "Mythique", Color = { 255, 70, 120 }, Order = 5 },
		Celestial = { Name = "Céleste", Color = { 120, 255, 230 }, Order = 6 },
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
		{
			Id = "AstralUnicorn",
			Name = "Licorne astrale",
			Rarity = "Mythic",
			Bonus = 3.6,
			Kind = "Beast",
			Color = { 235, 200, 255 },
		},
		{
			Id = "SunGuardian",
			Name = "Gardien solaire",
			Rarity = "Celestial",
			Bonus = 5.0,
			Kind = "Golem",
			Color = { 255, 215, 90 },
		},
		{
			Id = "CelestialDragon",
			Name = "Dragon céleste",
			Rarity = "Celestial",
			Bonus = 6.5,
			Kind = "Bird",
			Color = { 120, 255, 230 },
		},
	},

	-- Position {x, z} des présentoirs, autour du hub. Weights : poids relatifs (probabilités affichées).
	Eggs = {
		{
			Id = "ForestEgg",
			Name = "Œuf de la forêt",
			Cost = 150,
			Color = { 140, 200, 110 },
			Position = { -7.5, -20.7 },
			Weights = { Sprout = 45, Hare = 35, RuneWolf = 15, Owl = 5 },
		},
		{
			Id = "RuinEgg",
			Name = "Œuf des ruines",
			Cost = 1500,
			Color = { 170, 140, 220 },
			Position = { 7.5, -20.7 },
			Weights = { Hare = 30, RuneWolf = 30, Owl = 22, LittleGolem = 12, LightWisp = 6 },
		},
		{
			Id = "EtherEgg",
			Name = "Œuf d'Éther",
			Cost = 15000,
			Color = { 110, 210, 255 },
			Position = { 0, -22 },
			Weights = { LittleGolem = 40, LightWisp = 33, CrystalFox = 17, EmberDrake = 10 },
		},
		-- Œufs royaux : Robux (Product), aussi offerts par le temps de jeu et le parcours.
		{
			Id = "RoyalEgg",
			Name = "Œuf royal",
			Product = "RoyalEgg",
			Color = { 255, 200, 70 },
			Position = { -14.5, -16.2 },
			Weights = { CrystalFox = 35, EmberDrake = 30, EtherPhoenix = 22, AstralUnicorn = 10, SunGuardian = 3 },
		},
		{
			Id = "CelestialEgg",
			Name = "Œuf céleste",
			Product = "CelestialEgg",
			Color = { 120, 255, 230 },
			Position = { 14.5, -16.2 },
			Weights = { EtherPhoenix = 40, AstralUnicorn = 34, SunGuardian = 18, CelestialDragon = 8 },
		},
	},
}
