--[[
	Rue des boss : une rue suspendue découpée en sections. Chaque étape = une vague d'ennemis
	propres au joueur ; la porte de la section s'ouvre quand la vague est éliminée.
	Toutes les PatronEvery étapes, un Patron (mini-boss) avec butin affiché.
	Après la dernière section, le joueur revient au début et la numérotation continue
	(étape 11, 12...) avec des ennemis plus forts. Module pur.
]]

return {
	-- Salle mystique SOUS la carte (invisible depuis la surface) : murs et plafond en faux ciel.
	Origin = { 0, -160, 0 }, -- début de la rue
	Hall = { HalfWidth = 19, Front = 26, Back = -404, Height = 34, Floor = -10 },
	Sections = 10,
	-- Thème d'arène (designs du créateur) : change toutes les ThemeEvery étapes, dans cet ordre,
	-- puis recommence. Le décor est dessiné côté client selon l'étape du joueur.
	ThemeEvery = 5,
	Themes = {
		{ Id = "Crystal", Name = "Arène des Cristaux" },
		{ Id = "Ice", Name = "Salle des Glaces" },
		{ Id = "Sanctuary", Name = "Cour du Sanctuaire" },
		{ Id = "Forge", Name = "Arène de la Forge" },
	},
	SectionLength = 40,
	Width = 26,
	Portal = { 32, -11 }, -- portail dans la cour du château (côté est)

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
			Behavior = "Split",
			Name = "Gelée épineuse",
			Tier = "Petit",
			Scale = 1,
			Health = 0.7,
			Damage = 0.8,
			Speed = 0.8,
		},
		{
			Id = "RuinSpider",
			Behavior = "Leap",
			Name = "Araignée des ruines",
			Tier = "Petit",
			Scale = 0.9,
			Health = 0.8,
			Damage = 1.0,
			Speed = 1.25,
		},
		{
			Id = "ScrapGoblin",
			Behavior = "Melee",
			Name = "Gobelin ferrailleur",
			Tier = "Petit",
			Scale = 1,
			Health = 1.0,
			Damage = 1.0,
			Speed = 1.0,
		},
		{
			Id = "SkeletonSentinel",
			Behavior = "Melee",
			Name = "Squelette sentinelle",
			Tier = "Frontière",
			Scale = 1,
			Health = 1.1,
			Damage = 1.1,
			Speed = 0.95,
		},
		{
			Id = "BrambleWolf",
			Behavior = "Charge",
			Name = "Loup des ronces",
			Tier = "Frontière",
			Scale = 1,
			Health = 0.9,
			Damage = 1.2,
			Speed = 1.35,
		},
		{
			Id = "AshCultist",
			Behavior = "Ranged",
			Name = "Cultiste des cendres",
			Tier = "Frontière",
			Scale = 1,
			Health = 0.85,
			Damage = 1.35,
			Speed = 0.9,
		},
		{
			Id = "ShieldbreakerOrc",
			Behavior = "Unblockable",
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
			Behavior = "Knockback",
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
			Behavior = "Roots",
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
			Special = "Summon",
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
			Special = "RootField",
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
			Special = "Spit",
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
			Special = "Icefall",
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
			Special = "Breath",
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
			Special = "Nova",
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

	-- Comportements (Behavior) et attaques spéciales des boss (Special). Toutes les attaques
	-- dangereuses sont annoncées au sol (zone rouge) : on peut les esquiver en se déplaçant ou
	-- avec l'Esquive, sauf « Unblockable » (orque : ses coups brisent l'Esquive).
	Behaviors = {
		Leap = { Cooldown = 4.5, Windup = 0.45, Time = 0.55, MinRange = 6, MaxRange = 16, Radius = 3.5, Damage = 1.5 },
		Charge = { Cooldown = 5.5, Windup = 0.6, SpeedMult = 4, MinRange = 8, MaxRange = 22, Width = 3.5, Damage = 1.6 },
		Ranged = { Near = 9, Far = 16, Cooldown = 2.6, ProjectileSpeed = 28, Radius = 3.2, Damage = 1.0 },
		Split = { Count = 2, Health = 0.3, Scale = 0.55, Reward = 0.25 },
		Knockback = { Distance = 9 },
		Roots = { Cooldown = 7, Radius = 4.5, Telegraph = 1.2, Slow = 0.5, SlowSeconds = 2, Damage = 0.8 },
	},
	Specials = {
		Every = 7, -- secondes entre deux attaques spéciales (en alternance avec le coup de zone)
		Summon = { Count = 2, MaxAlive = 4 },
		RootField = { Count = 4, Radius = 5, Spread = 10, Telegraph = 1.4, Damage = 1.6 },
		Spit = { Count = 3, Spread = 5, Radius = 4, Damage = 1.4 },
		Icefall = { Count = 6, Radius = 4.5, Spread = 12, Telegraph = 1.3, Damage = 1.8 },
		Breath = { Length = 40, Width = 8, Telegraph = 1.3, Damage = 2.5 },
		Nova = { Radius = 20, Telegraph = 2.0, Damage = 3, Rocks = 3 },
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
