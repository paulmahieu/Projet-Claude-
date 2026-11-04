--[[
	Arbre d'améliorations PERSONNELLES (inspiré des arbres hexagonaux des simulateurs).
	Remplace les anciennes améliorations « Concentration » et « Robustesse » (migrées).

	Chaque nœud s'achète une fois, si le nœud précédent de sa branche est acheté.
	Coût en or (branches de progression) ou en trophées (gagnés en combat).
	Stats additives, toutes plafonnées par le nombre de nœuds :
	  TrainingMult  +x  XP et or des tapis et des zones (0.10 = +10 %)
	  Damage        +x  dégâts en combat
	  MaxHealth     +n  points de vie
	  OfflineHours  +n  heures au plafond hors ligne (8 h de base)
	  OfflineRate   +x  taux hors ligne (25 % de base)
	  PetSlots      +n  emplacement de compagnon
	  Luck          +x  chances des compagnons Rares et plus dans les œufs
	  WalkSpeed     +n  vitesse de déplacement
	  TrophyMult    +x  trophées gagnés
	Module pur.
]]

local Tree = {}

Tree.Branches = {
	{ Id = "Focus", Name = "Concentration", Color = { 90, 170, 255 }, Angle = -90 },
	{ Id = "Strength", Name = "Force", Color = { 235, 90, 70 }, Angle = -38 },
	{ Id = "Pets", Name = "Compagnons", Color = { 170, 110, 255 }, Angle = 14 },
	{ Id = "Offline", Name = "Hors ligne", Color = { 110, 120, 220 }, Angle = 66 },
	{ Id = "Trophies", Name = "Trophées", Color = { 255, 200, 60 }, Angle = 118 },
	{ Id = "Speed", Name = "Vitesse", Color = { 90, 220, 140 }, Angle = 170 },
	{ Id = "Toughness", Name = "Robustesse", Color = { 230, 140, 80 }, Angle = 222 },
}

-- Ordre dans une branche = ordre de déblocage.
Tree.Nodes = {
	{
		Id = "Focus1",
		Branch = "Focus",
		Name = "Concentration I",
		Cost = { Gold = 100 },
		Stat = "TrainingMult",
		Value = 0.10,
	},
	{
		Id = "Focus2",
		Branch = "Focus",
		Name = "Concentration II",
		Cost = { Gold = 400 },
		Stat = "TrainingMult",
		Value = 0.10,
	},
	{
		Id = "Focus3",
		Branch = "Focus",
		Name = "Concentration III",
		Cost = { Gold = 1500 },
		Stat = "TrainingMult",
		Value = 0.15,
	},
	{
		Id = "Focus4",
		Branch = "Focus",
		Name = "Concentration IV",
		Cost = { Gold = 6000 },
		Stat = "TrainingMult",
		Value = 0.20,
	},
	{
		Id = "Focus5",
		Branch = "Focus",
		Name = "Méga concentration",
		Cost = { Gold = 25000 },
		Stat = "TrainingMult",
		Value = 0.45,
	},

	{ Id = "Str1", Branch = "Strength", Name = "Force I", Cost = { Trophies = 20 }, Stat = "Damage", Value = 0.15 },
	{ Id = "Str2", Branch = "Strength", Name = "Force II", Cost = { Trophies = 60 }, Stat = "Damage", Value = 0.15 },
	{ Id = "Str3", Branch = "Strength", Name = "Force III", Cost = { Trophies = 180 }, Stat = "Damage", Value = 0.20 },
	{ Id = "Str4", Branch = "Strength", Name = "Force IV", Cost = { Trophies = 500 }, Stat = "Damage", Value = 0.25 },
	{
		Id = "Str5",
		Branch = "Strength",
		Name = "Méga force",
		Cost = { Trophies = 1500 },
		Stat = "Damage",
		Value = 0.50,
	},

	{ Id = "Equip1", Branch = "Pets", Name = "Équiper I", Cost = { Trophies = 100 }, Stat = "PetSlots", Value = 1 },
	{ Id = "Luck1", Branch = "Pets", Name = "Chance I", Cost = { Trophies = 150 }, Stat = "Luck", Value = 0.10 },
	{ Id = "Luck2", Branch = "Pets", Name = "Chance II", Cost = { Trophies = 400 }, Stat = "Luck", Value = 0.15 },
	{ Id = "Equip2", Branch = "Pets", Name = "Équiper II", Cost = { Trophies = 1000 }, Stat = "PetSlots", Value = 1 },

	{
		Id = "Off1",
		Branch = "Offline",
		Name = "Hors ligne I",
		Cost = { Trophies = 40 },
		Stat = "OfflineHours",
		Value = 1,
	},
	{
		Id = "Off2",
		Branch = "Offline",
		Name = "Hors ligne II",
		Cost = { Trophies = 120 },
		Stat = "OfflineRate",
		Value = 0.05,
	},
	{
		Id = "Off3",
		Branch = "Offline",
		Name = "Hors ligne III",
		Cost = { Trophies = 300 },
		Stat = "OfflineHours",
		Value = 1,
	},
	{
		Id = "Off4",
		Branch = "Offline",
		Name = "Hors ligne IV",
		Cost = { Trophies = 800 },
		Stat = "OfflineRate",
		Value = 0.05,
	},

	{
		Id = "Troph1",
		Branch = "Trophies",
		Name = "Trophées I",
		Cost = { Trophies = 30 },
		Stat = "TrophyMult",
		Value = 0.10,
	},
	{
		Id = "Troph2",
		Branch = "Trophies",
		Name = "Trophées II",
		Cost = { Trophies = 150 },
		Stat = "TrophyMult",
		Value = 0.15,
	},
	{
		Id = "Troph3",
		Branch = "Trophies",
		Name = "Trophées III",
		Cost = { Trophies = 600 },
		Stat = "TrophyMult",
		Value = 0.25,
	},

	{ Id = "Speed1", Branch = "Speed", Name = "Vitesse I", Cost = { Gold = 200 }, Stat = "WalkSpeed", Value = 2 },
	{ Id = "Speed2", Branch = "Speed", Name = "Vitesse II", Cost = { Gold = 1000 }, Stat = "WalkSpeed", Value = 2 },
	{ Id = "Speed3", Branch = "Speed", Name = "Vitesse III", Cost = { Gold = 5000 }, Stat = "WalkSpeed", Value = 3 },

	{
		Id = "Tough1",
		Branch = "Toughness",
		Name = "Robustesse I",
		Cost = { Gold = 150 },
		Stat = "MaxHealth",
		Value = 20,
	},
	{
		Id = "Tough2",
		Branch = "Toughness",
		Name = "Robustesse II",
		Cost = { Gold = 800 },
		Stat = "MaxHealth",
		Value = 20,
	},
	{
		Id = "Tough3",
		Branch = "Toughness",
		Name = "Robustesse III",
		Cost = { Gold = 4000 },
		Stat = "MaxHealth",
		Value = 30,
	},
}

Tree.StatText = {
	TrainingMult = "+%d %% XP et or (tapis et zones)",
	Damage = "+%d %% dégâts",
	MaxHealth = "+%d points de vie",
	OfflineHours = "+%d h de gains hors ligne",
	OfflineRate = "+%d %% de taux hors ligne",
	PetSlots = "+%d emplacement de compagnon",
	Luck = "+%d %% de chance (Rare et plus)",
	WalkSpeed = "+%d de vitesse",
	TrophyMult = "+%d %% de trophées",
}

-- Statistiques exprimées en pourcentage (affichage x100).
Tree.PercentStats = { TrainingMult = true, Damage = true, OfflineRate = true, Luck = true, TrophyMult = true }

-- Trophées (monnaie de combat) gagnés, avant le bonus TrophyMult.
Tree.TrophyRewards = {
	StreetKillPerStage = 0.5, -- par ennemi : ceil(étape x 0,5)
	StreetStagePerStage = 2, -- fin d'étape : étape x 2
	StreetPatronPerStage = 5, -- patron : étape x 5
	BossVictory = { ForestGuardian = 40, MineGolem = 150 },
}

return Tree
