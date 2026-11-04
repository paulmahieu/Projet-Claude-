--[[
	Tapis d'entraînement, niveaux et statistiques (cahier §8). Module pur.
	Unités : XP par seconde, or par seconde.
]]

return {
	BaseXpPerSecond = 4,
	BaseGoldPerSecond = 1,

	-- Multiplicateur par palier de tapis (StationTier).
	TierMultiplier = { [1] = 1, [2] = 1.5, [3] = 3, [4] = 6 },

	-- Distance max (studs) entre le joueur et le centre du tapis.
	MaxRange = 6,

	-- XP pour passer du niveau N à N+1 : floor(BaseXp * N ^ Exponent)
	BaseXp = 40,
	Exponent = 1.45,
	MaxLevel = 150,

	-- Statistique dérivée du niveau : Puissance = PowerBase + PowerPerLevel * (niveau - 1).
	-- Utilisée par le combat (étape 3).
	PowerBase = 10,
	PowerPerLevel = 2,
}
