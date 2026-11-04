--[[
	Missions d'introduction (cahier §7) : courtes, elles présentent chaque système.
	Personnelles : enchaînées dans l'ordre, créditées automatiquement une seule fois
	("quest:<Id>"). Collectives : une seule fois par groupe ("groupquest:<Id>" dans le journal
	du groupe), même si plusieurs membres remplissent la condition en même temps.

	Stat (personnelles) : Harvests, Structure (Value = Id), TrainSeconds, TreeNodes, PetsOwned,
	  PetsEquipped, StreetKills, StreetBest, BestLevel, Rebirths, BossKills
	Stat (collectives) : BastionLevel, Structure, Members
	Reward personnelle : { Gold, Trophies, Xp } ; collective : matériaux du groupe.
]]

return {
	Personal = {
		{
			Id = "Harvest10",
			Text = "Récolte 10 fois dans les bosquets",
			Stat = "Harvests",
			Target = 10,
			Reward = { Gold = 100 },
		},
		{
			Id = "BuildGround",
			Text = "Construis le Terrain d'entraînement",
			Stat = "Structure",
			Value = "TrainingGround",
			Target = 1,
			Reward = { Gold = 80, Trophies = 5 },
		},
		{
			Id = "Train60",
			Text = "Entraîne-toi 60 secondes sur un tapis ou une zone",
			Stat = "TrainSeconds",
			Target = 60,
			Reward = { Gold = 150 },
		},
		{
			Id = "TreeNode",
			Text = "Achète une amélioration dans l'Arbre",
			Stat = "TreeNodes",
			Target = 1,
			Reward = { Trophies = 10 },
		},
		{
			Id = "HatchEgg",
			Text = "Ouvre un œuf au château",
			Stat = "PetsOwned",
			Target = 1,
			Reward = { Gold = 200 },
		},
		{
			Id = "EquipPet",
			Text = "Équipe un compagnon",
			Stat = "PetsEquipped",
			Target = 1,
			Reward = { Trophies = 10 },
		},
		{
			Id = "StreetKill",
			Text = "Vaincs un ennemi de la Rue des boss",
			Stat = "StreetKills",
			Target = 1,
			Reward = { Gold = 300 },
		},
		{
			Id = "Street3",
			Text = "Termine l'étape 3 de la Rue des boss",
			Stat = "StreetBest",
			Target = 3,
			Reward = { Trophies = 25 },
		},
		{ Id = "Level15", Text = "Atteins le niveau 15", Stat = "BestLevel", Target = 15, Reward = { Gold = 500 } },
		{
			Id = "Rebirth1",
			Text = "Fais ta première renaissance",
			Stat = "Rebirths",
			Target = 1,
			Reward = { Trophies = 50 },
		},
		{
			Id = "Boss1",
			Text = "Vaincs un boss d'arène",
			Stat = "BossKills",
			Target = 1,
			Reward = { Trophies = 100, Xp = 1000 },
		},
	},
	Group = {
		{
			Id = "Bastion3",
			Text = "Le bastion atteint le niveau 3",
			Stat = "BastionLevel",
			Target = 3,
			Reward = { Wood = 40, Stone = 20 },
		},
		{
			Id = "Together",
			Text = "Le bastion compte 2 membres",
			Stat = "Members",
			Target = 2,
			Reward = { Wood = 60, Stone = 40 },
		},
		{
			Id = "Tower",
			Text = "Construisez la Tour de guet",
			Stat = "Structure",
			Value = "Watchtower",
			Target = 1,
			Reward = { Crystal = 5 },
		},
	},
}
