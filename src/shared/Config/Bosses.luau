--[[
	Arènes de boss (cahier §6). Module pur.

	Arena    : centre {x, z} de l'arène dans le monde (hors des parcelles).
	Portal   : position {x, z} du portail au hub.
	MaxHealth: PV pour 1 participant ; + HealthPerExtraPlayer par participant supplémentaire,
	           figés au début du combat (règle stable).
	Attacks  : attaques annoncées par une forme au sol (Telegraph secondes avant l'impact).
	Participation : dégâts >= ParticipationRatio x PV max pour être récompensé.
	Rewards  : Personal (chaque participant validé), Group (une fois par groupe et par victoire).
]]

return {
	{
		Id = "ForestGuardian",
		Name = "Gardien sylvestre",
		RecommendedPower = 20,
		Arena = { 0, -490 }, -- au-delà des extensions de terrain des bastions
		ArenaRadius = 55,
		Portal = { -32, -11 },
		MaxHealth = 2500,
		HealthPerExtraPlayer = 0.6,
		RespawnSeconds = 90,
		AttackInterval = { 3.5, 2.4 }, -- phase 1, phase 2 (< 50 % PV)
		Attacks = {
			{ Id = "Slam", Name = "Coup circulaire", Shape = "Around", Radius = 16, Damage = 30, Telegraph = 1.6 },
			{ Id = "Roots", Name = "Racines", Shape = "Target", Radius = 9, Damage = 25, Telegraph = 1.4 },
			{
				Id = "Rain",
				Name = "Pluie de glands",
				Shape = "Multi",
				Count = 4,
				Radius = 7,
				Damage = 20,
				Telegraph = 1.4,
				Phase = 2,
			},
		},
		ParticipationRatio = 0.03,
		Rewards = {
			Personal = { Gold = 400, Xp = 600 },
			Group = { Wood = 80, Crystal = 6 },
		},
		Colors = { Body = { 100, 75, 45 }, Accent = { 90, 170, 70 }, Eyes = { 255, 230, 120 } },
		Kind = "Treant",
	},
	{
		Id = "MineGolem",
		Name = "Golem des profondeurs",
		RecommendedPower = 60,
		Arena = { 490, 0 },
		ArenaRadius = 55,
		Portal = { -32, -26 },
		MaxHealth = 12000,
		HealthPerExtraPlayer = 0.6,
		RespawnSeconds = 120,
		AttackInterval = { 3.0, 2.0 },
		Attacks = {
			{ Id = "Slam", Name = "Séisme", Shape = "Around", Radius = 18, Damage = 45, Telegraph = 1.5 },
			{ Id = "Boulder", Name = "Rocher", Shape = "Target", Radius = 10, Damage = 40, Telegraph = 1.3 },
			{
				Id = "Shards",
				Name = "Éclats de cristal",
				Shape = "Multi",
				Count = 6,
				Radius = 7,
				Damage = 30,
				Telegraph = 1.3,
				Phase = 2,
			},
		},
		ParticipationRatio = 0.03,
		Rewards = {
			Personal = { Gold = 2500, Xp = 4000 },
			Group = { Stone = 150, Ore = 25, Crystal = 15 },
		},
		Colors = { Body = { 110, 105, 110 }, Accent = { 120, 210, 255 }, Eyes = { 120, 230, 255 } },
		Kind = "Golem",
	},
}
