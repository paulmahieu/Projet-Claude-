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

	-- Types d'ennemis : alternent selon l'étape.
	Kinds = {
		{ Id = "Goblin", Name = "Gobelin", Color = { 110, 160, 70 }, Scale = 0.9 },
		{ Id = "Skeleton", Name = "Squelette", Color = { 225, 220, 205 }, Scale = 1 },
		{ Id = "Ghoul", Name = "Goule", Color = { 130, 150, 170 }, Scale = 1 },
		{ Id = "ShadowWolf", Name = "Loup d'ombre", Color = { 60, 55, 80 }, Scale = 0.9 },
	},
	PatronNames = { "Chef gobelin", "Roi des os", "Goule vorace", "Alpha d'ombre" },
}
