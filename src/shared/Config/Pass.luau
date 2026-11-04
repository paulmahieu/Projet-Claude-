--[[
	Parcours du champion : pass de saison à deux pistes. Module pur.

	- XP de parcours gagnée en JOUANT (temps actif, missions, boss, Rue des boss, défense,
	  quotidien). Le temps hors ligne ne compte pas.
	- Piste gratuite : pour tous.
	- Piste premium : pass Robux « PremiumTrack » (Config/Products). Volontairement bien plus
	  forte (décision du porteur du projet) : œufs royaux et célestes, tapis de ferme x100 puis
	  x500 au dernier palier. Achetée en cours de saison, elle donne aussi les paliers déjà atteints.
	- Chaque récompense se récupère une seule fois par saison (état dans le profil). Changer
	  Season remet l'XP et les récupérations à zéro ; les droits obtenus (tapis) sont conservés.

	Récompense : { Gold, Trophies, Xp, Egg, Pet, Entitlement = { Key, Name } }.
]]

local CHAMPION_100 = { Key = "ChampionMat100", Name = "Tapis du champion x100" }
local CHAMPION_500 = { Key = "ChampionMat500", Name = "Tapis du héros x500" }

return {
	Season = 1,
	Name = "Saison 1 · L'Éveil de l'Éther",
	PremiumPass = "PremiumTrack",
	XpPerTier = 200,

	-- XP de parcours par source.
	Xp = {
		ActiveMinute = 10, -- chaque minute de jeu actif
		Quest = 80, -- mission personnelle accomplie
		BossWin = 60, -- boss d'arène vaincu (participant)
		StreetStage = 10, -- étape de la Rue des boss franchie
		DefenseWin = 150, -- défense du bastion réussie (participant)
		Daily = 50, -- récompense quotidienne récupérée
	},

	Tiers = {
		{ Free = { Gold = 200 }, Premium = { Gold = 1500, Egg = "RuinEgg" } },
		{ Free = { Trophies = 15 }, Premium = { Trophies = 80 } },
		{ Free = { Egg = "ForestEgg" }, Premium = { Egg = "EtherEgg" } },
		{ Free = { Gold = 400 }, Premium = { Gold = 4000 } },
		{ Free = { Xp = 300 }, Premium = { Egg = "RoyalEgg" } },
		{ Free = { Trophies = 25 }, Premium = { Trophies = 150, Xp = 2000 } },
		{ Free = { Gold = 700 }, Premium = { Gold = 8000 } },
		{ Free = { Egg = "RuinEgg" }, Premium = { Egg = "EtherEgg", Trophies = 100 } },
		{ Free = { Gold = 1000 }, Premium = { Gold = 12000 } },
		{ Free = { Trophies = 40 }, Premium = { Egg = "RoyalEgg" } },
		{ Free = { Xp = 800 }, Premium = { Xp = 6000 } },
		{ Free = { Gold = 1500 }, Premium = { Egg = "CelestialEgg" } },
		{ Free = { Trophies = 60 }, Premium = { Trophies = 300 } },
		{ Free = { Egg = "RuinEgg" }, Premium = { Gold = 25000 } },
		{ Free = { Gold = 2500 }, Premium = { Entitlement = CHAMPION_100 } },
		{ Free = { Xp = 1500 }, Premium = { Egg = "RoyalEgg" } },
		{ Free = { Trophies = 80 }, Premium = { Trophies = 450 } },
		{ Free = { Gold = 4000 }, Premium = { Gold = 40000 } },
		{ Free = { Egg = "EtherEgg" }, Premium = { Egg = "RoyalEgg", Xp = 10000 } },
		{ Free = { Trophies = 100 }, Premium = { Egg = "CelestialEgg" } },
		{ Free = { Gold = 6000 }, Premium = { Gold = 60000 } },
		{ Free = { Xp = 3000 }, Premium = { Trophies = 700 } },
		{ Free = { Trophies = 130 }, Premium = { Egg = "RoyalEgg" } },
		{ Free = { Gold = 9000 }, Premium = { Gold = 90000, Xp = 20000 } },
		{ Free = { Egg = "EtherEgg" }, Premium = { Egg = "CelestialEgg" } },
		{ Free = { Trophies = 160 }, Premium = { Trophies = 1000 } },
		{ Free = { Gold = 13000 }, Premium = { Gold = 150000 } },
		{ Free = { Xp = 6000 }, Premium = { Egg = "RoyalEgg", Trophies = 600 } },
		{ Free = { Trophies = 200 }, Premium = { Egg = "CelestialEgg" } },
		{ Free = { Egg = "EtherEgg", Gold = 20000 }, Premium = { Entitlement = CHAMPION_500 } },
	},
}
