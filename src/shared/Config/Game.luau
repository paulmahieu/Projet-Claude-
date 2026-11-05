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

	-- Château royal (hub) : Art/CastleDesign à l'échelle CastleScale, centré sur l'origine, un seul
	-- portail au sud (-Z). La cour s'étend environ de x = -43 à 43 et de z = -35 à -3 (le donjon
	-- occupe le nord) : point d'apparition, œufs et portails y sont placés.
	CastleScale = 0.6,
	CastleRadius = 91, -- rayon de l'emprise au sol (coins des tours d'angle)
	CastleGateFront = 56.6, -- distance du centre à l'entrée du passage du portail (côté -Z)
	GateWidth = 10, -- largeur de la route du portail
	HubSpawn = { 0, -20 }, -- centre de l'estrade d'apparition (x, z)
	HubFloor = 0.27, -- dessus du dallage de la cour
	Courtyard = { MinX = -43, MaxX = 43, MinZ = -34, MaxZ = -3 }, -- zone libre de la cour
	RingRoadRadius = 97, -- route pavée qui fait le tour du château
	RingRoadWidth = 10,

	MaxGroupSize = 4,
	InviteSeconds = 90,

	-- Outils de développement (simulation d'achats, etc.) : actifs UNIQUEMENT dans Studio.
	DevToolsInStudio = true,
}
