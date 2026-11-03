--[[
	Améliorations PERSONNELLES payées en or individuel (cahier §3). Module pur.
	Coût du niveau suivant : floor(BaseCost * Growth ^ niveauActuel)
	Rendements plafonnés par MaxLevel (pas de multiplicateur infini).
]]

return {
	{
		Id = "Focus",
		Name = "Concentration",
		Effect = "+10 % d'XP et d'or sur les tapis (par niveau)",
		BaseCost = 40,
		Growth = 1.7,
		MaxLevel = 10,
		PerLevel = 0.10,
	},
	{
		Id = "Toughness",
		Name = "Robustesse",
		Effect = "+10 points de vie maximum (par niveau)",
		BaseCost = 60,
		Growth = 1.6,
		MaxLevel = 10,
		PerLevel = 10,
	},
}
