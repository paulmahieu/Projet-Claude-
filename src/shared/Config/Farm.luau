--[[
	Champ des champions : esplanade de farm publique, découpée en zones à multiplicateur.
	On se place dans une zone et on frappe automatiquement les mannequins : XP et or chaque
	seconde. Chaque zone exige un nombre de renaissances ; une zone royale exige un pass
	(Zone royale) ou un droit gagné sur la piste premium du parcours (tapis x100 et x500).
	Module pur.
]]

return {
	Origin = { 0, 300, -260 }, -- île suspendue (aucun conflit avec la carte ni la Rue des boss)
	Portal = { 18.5, 28.5 }, -- portail dans la cour royale, devant le donjon
	ZoneSize = 22,
	Gap = 6,
	Columns = 7,

	-- Mult : multiplicateur d'XP et d'or ; Rebirths : renaissances requises ;
	-- PassKey : pass Robux OU droit du profil (Entitlements) requis.
	Zones = {
		{ Mult = 1, Rebirths = 0 },
		{ Mult = 2, Rebirths = 1 },
		{ Mult = 2.5, Rebirths = 2 },
		{ Mult = 4, Rebirths = 3 },
		{ Mult = 6, Rebirths = 5 },
		{ Mult = 8, Rebirths = 7 },
		{ Mult = 12, Rebirths = 10 },
		{ Mult = 16, Rebirths = 14 },
		{ Mult = 22, Rebirths = 19 },
		{ Mult = 30, Rebirths = 25 },
		{ Mult = 50, Rebirths = 0, PassKey = "RoyalTraining", Royal = true },
		-- Récompenses de la piste premium du parcours (droit durable du profil).
		{ Mult = 100, Rebirths = 0, PassKey = "ChampionMat100", Royal = true, Name = "TAPIS DU CHAMPION" },
		{ Mult = 500, Rebirths = 0, PassKey = "ChampionMat500", Royal = true, Name = "TAPIS DU HÉROS" },
	},
}
