--[[
	Entraînement AFK sur mannequin.
	Module pur : testable avec Lune.
]]

return {
	XpPerSecond = 5,

	-- Distance max (studs) entre le joueur et le mannequin pour continuer à s'entraîner.
	MaxRange = 16,

	-- XP nécessaire pour passer du niveau N au niveau N+1 : floor(BaseXp * N ^ Exponent)
	BaseXp = 50,
	Exponent = 1.5,
	MaxLevel = 200,

	-- Position du mannequin {x, z} relative au centre de la parcelle.
	DummyOffset = { 0, -24 },
}
