--[[
	Récompenses gratuites (cahier §9.3 et §9.4). Module pur.

	Quotidien : 7 jours de présence CUMULÉS. Une journée manquée ne fait rien perdre.
	Changement de jour à 00:00 UTC. Le jour 7 du premier cycle donne un compagnon (une seule
	fois) ; les cycles suivants utilisent Repeat (aucun objet unique recrédité).

	Temps de jeu : paliers de jeu ACTIF cumulé dans la journée UTC (sessions additionnées),
	crédités automatiquement et une seule fois à l'atteinte. Le temps hors ligne ne compte pas.
	Récompense : { Gold, Trophies, Xp, Pet }.
]]

return {
	DayLength = 86400,

	Daily = {
		{ Gold = 150 },
		{ Trophies = 15 },
		{ Gold = 400 },
		{ Trophies = 30, Xp = 300 },
		{ Gold = 1000 },
		{ Trophies = 60 },
		{ Pet = "LightWisp", Gold = 1500 }, -- compagnon offert au premier cycle
	},
	Repeat = {
		{ Gold = 300 },
		{ Trophies = 25 },
		{ Gold = 800 },
		{ Trophies = 50, Xp = 600 },
		{ Gold = 2000 },
		{ Trophies = 90 },
		{ Gold = 4000, Trophies = 120 },
	},

	-- Paliers en minutes de jeu actif dans la journée.
	Playtime = {
		{ Minutes = 5, Reward = { Gold = 100 } },
		{ Minutes = 10, Reward = { Trophies = 10 } },
		{ Minutes = 20, Reward = { Gold = 300, Xp = 200 } },
		{ Minutes = 30, Reward = { Trophies = 30 } },
	},

	-- Un joueur est « actif » s'il a bougé ou agi dans ce délai (secondes).
	ActivityWindow = 180,
}
