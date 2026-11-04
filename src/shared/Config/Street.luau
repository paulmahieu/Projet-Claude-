--[[
	Rue des boss : une rue suspendue découpée en sections. Chaque étape = une vague d'ennemis
	propres au joueur ; la porte de la section s'ouvre quand la vague est éliminée.
	Toutes les PatronEvery étapes, un Patron (mini-boss) avec butin affiché.
	Après la dernière section, le joueur revient au début et la numérotation continue
	(étape 11, 12...) avec des ennemis plus forts. Module pur.
]]

return {
	Origin = { 0, 420, 0 }, -- début de la rue (dans le ciel : aucun conflit avec la carte)
	Sections = 10,
	SectionLength = 40,
	Width = 26,
	Portal = { 6.5, 33.4 }, -- portail dans la cour royale, devant le donjon

	-- Ennemis par vague : Base + floor(étape / PerStages), plafonné.
	WaveBase = 3,
	WaveExtraPerStages = 10,
	WaveMax = 6,

	-- Croissance par étape (exposants), étape 1 = valeurs de base.
	Enemy = { Health = 60, Damage = 6, Speed = 11, AttackRange = 4.5, AttackCooldown = 1.2 },
	HealthGrowth = 1.22,
	DamageGrowth = 1.10,

	-- Récompenses par ennemi (or et XP) à l'étape 1, croissance par étape.
	Reward = { Gold = 5, Xp = 10 },
	RewardGrowth = 1.18,
	StageClearMultiplier = 5, -- bonus de fin d'étape = récompense d'un ennemi x5

	-- Puissance conseillée : pour vaincre un ennemi en ~6 coups.
	HitsToKill = 6,

	PatronEvery = 5,
	Patron = { HealthMult = 6, DamageMult = 2, RewardMult = 10, SlamRadius = 10, SlamTelegraph = 1.4, SlamEvery = 4 },
	-- Butin d'un Patron (chances affichées sur le Patron). Les matériaux vont au groupe.
	PatronDrops = {
		{ Kind = "Material", Id = "Crystal", Amount = 2, Chance = 1 },
		{ Kind = "Material", Id = "Ore", Amount = 3, Chance = 0.5 },
		{ Kind = "Pet", Id = "FrostWolf", Chance = 0.05 },
		{ Kind = "Pet", Id = "SolarLion", Chance = 0.005 },
	},

	-- Ennemis (planches du créateur). Health / Damage / Speed / Reward : multiplicateurs appliqués
	-- aux valeurs de l'étape. Scale : taille du modèle. Les élites servent aussi de patrons.
	Kinds = {
		{
			Id = "ThornJelly",
			Name = "Gelée épineuse",
			Tier = "Petit",
			Scale = 1,
			Health = 0.7,
			Damage = 0.8,
			Speed = 0.8,
		},
		{
			Id = "RuinSpider",
			Name = "Araignée des ruines",
			Tier = "Petit",
			Scale = 0.9,
			Health = 0.8,
			Damage = 1.0,
			Speed = 1.25,
		},
		{
			Id = "ScrapGoblin",
			Name = "Gobelin ferrailleur",
			Tier = "Petit",
			Scale = 1,
			Health = 1.0,
			Damage = 1.0,
			Speed = 1.0,
		},
		{
			Id = "SkeletonSentinel",
			Name = "Squelette sentinelle",
			Tier = "Frontière",
			Scale = 1,
			Health = 1.1,
			Damage = 1.1,
			Speed = 0.95,
		},
		{
			Id = "BrambleWolf",
			Name = "Loup des ronces",
			Tier = "Frontière",
			Scale = 1,
			Health = 0.9,
			Damage = 1.2,
			Speed = 1.35,
		},
		{
			Id = "AshCultist",
			Name = "Cultiste des cendres",
			Tier = "Frontière",
			Scale = 1,
			Health = 0.85,
			Damage = 1.35,
			Speed = 0.9,
		},
		{
			Id = "ShieldbreakerOrc",
			Name = "Orque brise-bouclier",
			Tier = "Élite",
			Scale = 1,
			Health = 2.2,
			Damage = 1.6,
			Speed = 0.85,
			Reward = 2,
		},
		{
			Id = "QuarryGolem",
			Name = "Golem des carrières",
			Tier = "Élite",
			Scale = 1,
			Health = 3.0,
			Damage = 1.3,
			Speed = 0.7,
			Reward = 2,
		},
		{
			Id = "ThornKnight",
			Name = "Chevalier des épines",
			Tier = "Élite",
			Scale = 1,
			Health = 2.4,
			Damage = 1.8,
			Speed = 0.9,
			Reward = 2,
		},
	},

	-- Boss (étape 10 de chaque région) : multiplicateurs EN PLUS de ceux d'un patron.
	Bosses = {
		{
			Id = "GoblinKing",
			Name = "Roi gobelin",
			Tier = "Boss régional",
			Boss = true,
			Scale = 1,
			Health = 1.5,
			Damage = 1.2,
			Speed = 0.8,
			Reward = 1.5,
			SlamRadius = 12,
		},
		{
			Id = "RootGuardian",
			Name = "Gardien des racines",
			Tier = "Boss régional",
			Boss = true,
			Scale = 1,
			Health = 1.7,
			Damage = 1.2,
			Speed = 0.7,
			Reward = 1.7,
			SlamRadius = 13,
		},
		{
			Id = "MarshHydra",
			Name = "Hydre des marais",
			Tier = "Boss régional",
			Boss = true,
			Scale = 1,
			Health = 1.9,
			Damage = 1.3,
			Speed = 0.75,
			Reward = 1.9,
			SlamRadius = 14,
		},
		{
			Id = "FrostTitan",
			Name = "Titan du givre",
			Tier = "Boss majeur",
			Boss = true,
			Scale = 1,
			Health = 2.3,
			Damage = 1.4,
			Speed = 0.65,
			Reward = 2.3,
			SlamRadius = 15,
		},
		{
			Id = "FurnaceDragon",
			Name = "Dragon de la fournaise",
			Tier = "Boss majeur",
			Boss = true,
			Scale = 1,
			Health = 2.6,
			Damage = 1.5,
			Speed = 0.7,
			Reward = 2.6,
			SlamRadius = 15,
		},
		{
			Id = "VoidColossus",
			Name = "Colosse du néant",
			Tier = "Boss final",
			Boss = true,
			Scale = 1,
			Health = 3.2,
			Damage = 1.6,
			Speed = 0.6,
			Reward = 3.5,
			SlamRadius = 16,
		},
	},

	-- Régions de 10 étapes : ennemis des vagues (en alternance) et patrons (étapes 5 et 10).
	-- Après la région 6, on recommence à la région 1 (statistiques toujours croissantes).
	RegionLength = 10,
	Regions = {
		{
			Name = "Faubourgs",
			Pool = { "ThornJelly", "RuinSpider", "ScrapGoblin" },
			Patrons = { "ShieldbreakerOrc", "GoblinKing" },
		},
		{
			Name = "Frontières",
			Pool = { "ScrapGoblin", "SkeletonSentinel", "BrambleWolf", "AshCultist" },
			Patrons = { "QuarryGolem", "RootGuardian" },
		},
		{
			Name = "Marches sauvages",
			Pool = { "SkeletonSentinel", "BrambleWolf", "AshCultist", "ShieldbreakerOrc" },
			Patrons = { "ThornKnight", "MarshHydra" },
		},
		{
			Name = "Cimes gelées",
			Pool = { "AshCultist", "SkeletonSentinel", "QuarryGolem", "BrambleWolf" },
			Patrons = { "ShieldbreakerOrc", "FrostTitan" },
		},
		{
			Name = "Fournaise",
			Pool = { "AshCultist", "ShieldbreakerOrc", "ThornKnight", "BrambleWolf" },
			Patrons = { "QuarryGolem", "FurnaceDragon" },
		},
		{
			Name = "Néant",
			Pool = { "ThornKnight", "QuarryGolem", "ShieldbreakerOrc", "AshCultist" },
			Patrons = { "ThornKnight", "VoidColossus" },
		},
	},
}
