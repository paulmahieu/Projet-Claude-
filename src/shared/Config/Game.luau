--[[
	Réglages généraux. Module pur (testable avec Lune).
	Valeurs issues du cahier des charges §2, ajustables.
]]

return {
	Name = "Bastions d'Éther", -- nom de travail

	-- Le cahier propose 16 joueurs / 4 bases. Avec des groupes de 1 joueur autorisés, 4 bases
	-- bloqueraient le serveur dès 4 joueurs solo : on retient 8 parcelles (voir docs/CONCEPTION.md, I1).
	MaxPlayers = 16, -- à régler dans Game Settings > Places (non modifiable par script)
	PlotCount = 8,
	PlotSize = 90,
	PlotRingRadius = 200,

	-- Cour royale (point d'apparition) : enceinte octogonale fermée par des remparts.
	CourtyardApothem = 54, -- distance du centre à la face intérieure des remparts
	WallHeight = 15,
	WallThickness = 4,
	GateAngles = { 0, 180, 270 }, -- portes : est, ouest, sud (le donjon occupe le nord)
	GateWidth = 12,
	RingRoadRadius = 72, -- route pavée qui fait le tour du château
	RingRoadWidth = 10,

	MaxGroupSize = 4,
	InviteSeconds = 90,

	-- Outils de développement (simulation d'achats, etc.) : actifs UNIQUEMENT dans Studio.
	DevToolsInStudio = true,
}
