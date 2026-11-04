--[[
	Agrandissement du terrain du bastion. Module pur.

	- Le terrain de base (90 x 90) s'agrandit par 6 extensions achetées DANS L'ORDRE avec les
	  matériaux COMMUNS du groupe (permission Construire), comme les constructions.
	- Les extensions existent toujours physiquement (friche clôturée) ; une fois achetées, le sol
	  est pavé, les barrières tombent et leurs emplacements de machines apparaissent.
	- Coordonnées locales à la parcelle : x latéral, z vers l'extérieur (z négatif = entrée côté
	  château). Rect = { xMin, xMax, zMin, zMax }, multiples de 2,5.
	- Place disponible : les ailes s'arrêtent avant la bissectrice entre deux parcelles et le
	  fond s'arrête à 405 studs du centre (arènes à 490, collines au-delà) — vérifié par les tests.

	Openings : passages de 10 studs entre deux zones (Base = terrain de départ). Une barrière
	ferme le passage tant que les DEUX zones ne sont pas possédées.
	Slots : emplacements de machines { Id, Machine, X, Z, Rot (degrés, 0 = face à l'entrée) }.
]]

return {
	OpeningWidth = 10,
	Grid = 2.5,

	Areas = {
		{
			Id = "Back1",
			Name = "Arrière I",
			Rect = { -45, 45, 45, 85 },
			Cost = { Wood = 150, Stone = 100 },
			Slots = {
				{ Id = "Back1_1", Machine = "LumberMill", X = -25, Z = 66, Rot = 0 },
				{ Id = "Back1_2", Machine = "StoneCrusher", X = 25, Z = 66, Rot = 0 },
			},
		},
		{
			Id = "WingL",
			Name = "Aile gauche",
			Rect = { 45, 70, -10, 85 },
			Cost = { Wood = 320, Stone = 240 },
			Slots = {
				{ Id = "WingL_1", Machine = "LumberMill", X = 58, Z = 8, Rot = 0 },
				{ Id = "WingL_2", Machine = "OreDrill", X = 58, Z = 50, Rot = 0 },
			},
		},
		{
			Id = "WingR",
			Name = "Aile droite",
			Rect = { -70, -45, -10, 85 },
			Cost = { Wood = 480, Stone = 380 },
			Slots = {
				{ Id = "WingR_1", Machine = "StoneCrusher", X = -58, Z = 8, Rot = 0 },
				{ Id = "WingR_2", Machine = "OreDrill", X = -58, Z = 50, Rot = 0 },
			},
		},
		{
			Id = "Back2",
			Name = "Arrière II",
			Rect = { -70, 70, 85, 125 },
			Cost = { Wood = 900, Stone = 750, Ore = 80 },
			Slots = {
				{ Id = "Back2_1", Machine = "EtherCondenser", X = -42, Z = 106, Rot = 0 },
				{ Id = "Back2_2", Machine = "LumberMill", X = -20, Z = 106, Rot = 0 },
				{ Id = "Back2_3", Machine = "OreDrill", X = 30, Z = 106, Rot = 0 },
			},
		},
		{
			Id = "Back3",
			Name = "Arrière III",
			Rect = { -70, 70, 125, 165 },
			Cost = { Wood = 1600, Stone = 1400, Ore = 250, Crystal = 20 },
			Slots = {
				{ Id = "Back3_1", Machine = "EtherCondenser", X = 42, Z = 146, Rot = 0 },
				{ Id = "Back3_2", Machine = "StoneCrusher", X = 20, Z = 146, Rot = 0 },
				{ Id = "Back3_3", Machine = "OreDrill", X = -30, Z = 146, Rot = 0 },
			},
		},
		{
			Id = "Back4",
			Name = "Arrière IV · Forges royales",
			Rect = { -70, 70, 165, 205 },
			Cost = { Wood = 3200, Stone = 2800, Ore = 600, Crystal = 60 },
			Slots = {
				{ Id = "Back4_1", Machine = "RoyalForge", X = -38, Z = 186, Rot = 0 },
				{ Id = "Back4_2", Machine = "EtherCondenser", X = 0, Z = 190, Rot = 0 },
				{ Id = "Back4_3", Machine = "RoyalForge", X = 38, Z = 186, Rot = 0 },
			},
		},
	},

	-- Passages : A et B = zones reliées ; X, Z = centre ; Along = direction du mur ("X" ou "Z").
	Openings = {
		{ A = "Base", B = "Back1", X = 0, Z = 45, Along = "X" },
		{ A = "Base", B = "WingL", X = 45, Z = 17.5, Along = "Z" },
		{ A = "Base", B = "WingR", X = -45, Z = 17.5, Along = "Z" },
		{ A = "Back1", B = "WingL", X = 45, Z = 65, Along = "Z" },
		{ A = "Back1", B = "WingR", X = -45, Z = 65, Along = "Z" },
		{ A = "Back1", B = "Back2", X = 0, Z = 85, Along = "X" },
		{ A = "WingL", B = "Back2", X = 57.5, Z = 85, Along = "X" },
		{ A = "WingR", B = "Back2", X = -57.5, Z = 85, Along = "X" },
		{ A = "Back2", B = "Back3", X = 0, Z = 125, Along = "X" },
		{ A = "Back3", B = "Back4", X = 0, Z = 165, Along = "X" },
	},

	-- Panneau d'achat de chaque extension : devant ce passage, côté terrain déjà possédé.
	SignOpening = { Back1 = 1, WingL = 2, WingR = 3, Back2 = 6, Back3 = 9, Back4 = 10 },
}
