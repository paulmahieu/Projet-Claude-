--[[
	Champ des champions : esplanade de farm publique, découpée en zones à multiplicateur.
	On se place dans une zone et on frappe automatiquement les mannequins : XP et or chaque
	seconde. Chaque zone exige un nombre de renaissances ; une zone royale exige un pass
	(Zone royale) ou un droit gagné sur la piste premium du parcours (tapis x100 et x500).
	Module pur.
]]

return {
	-- Salle mystique SOUS la carte (invisible depuis la surface), sous la Rue des boss.
	Origin = { 0, -260, -260 },
	Hall = { HalfWidth = 112, Front = 28, Back = -76, Height = 42, Floor = -26 },
	Portal = { 32, -26 }, -- portail dans la cour du château (côté est)
	ZoneSize = 22,
	Gap = 6,
	Columns = 7,

	-- Mult : multiplicateur d'XP et d'or ; Rebirths : renaissances requises ;
	-- PassKey : pass Robux OU droit du profil (Entitlements) requis.
	-- Puppet : pantin du créateur (Art/PuppetDesigns), du plus simple au plus riche.
	Zones = {
		{ Mult = 1, Rebirths = 0, Puppet = "Epouvantail" },
		{ Mult = 2, Rebirths = 1, Puppet = "Epouvantail" },
		{ Mult = 2.5, Rebirths = 2, Puppet = "Vagabond" },
		{ Mult = 4, Rebirths = 3, Puppet = "Vagabond" },
		{ Mult = 6, Rebirths = 5, Puppet = "EpouvantailCorrompu" },
		{ Mult = 8, Rebirths = 7, Puppet = "EpouvantailCorrompu" },
		{ Mult = 12, Rebirths = 10, Puppet = "Scaphandrier" },
		{ Mult = 16, Rebirths = 14, Puppet = "Scaphandrier" },
		{ Mult = 22, Rebirths = 19, Puppet = "InsecteAlchimiste" },
		{ Mult = 30, Rebirths = 25, Puppet = "InsecteAlchimiste" },
		{ Mult = 50, Rebirths = 0, PassKey = "RoyalTraining", Royal = true, Puppet = "AlchimisteVapeur" },
		-- Récompenses de la piste premium du parcours (droit durable du profil).
		{
			Mult = 100,
			Rebirths = 0,
			PassKey = "ChampionMat100",
			Royal = true,
			Name = "TAPIS DU CHAMPION",
			Puppet = "AlchimisteVapeur",
		},
		{
			Mult = 500,
			Rebirths = 0,
			PassKey = "ChampionMat500",
			Royal = true,
			Name = "TAPIS DU HÉROS",
			Puppet = "AlchimisteVapeur",
		},
	},
}
