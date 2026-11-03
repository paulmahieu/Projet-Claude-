--[[
	Bâtiments du tycoon, dans l'ordre de déblocage.

	Id        : identifiant stable, sauvegardé (ne jamais renommer un Id déjà publié)
	Name      : nom affiché (librement modifiable)
	Cost      : prix en or
	Income    : or produit par seconde
	Requires  : Id du bâtiment qui doit être possédé avant (nil = disponible au départ)
	Offset    : position {x, z} relative au centre de la parcelle (en studs).
	            z négatif = côté entrée (vers le hub central), z positif = fond de la base.
	Size      : taille {x, y, z} du bloc principal (placeholder en attendant les modèles 3D)
	Color     : couleur {r, g, b} 0-255
	Material  : nom d'un Enum.Material

	Module pur : testable avec Lune.
]]

return {
	{
		Id = "Campfire",
		Name = "Feu de camp",
		Cost = 25,
		Income = 1,
		Requires = nil,
		Offset = { 0, 0 },
		Size = { 6, 2, 6 },
		Color = { 255, 120, 40 },
		Material = "Neon",
	},
	{
		Id = "WoodcutterHut",
		Name = "Cabane du bûcheron",
		Cost = 100,
		Income = 3,
		Requires = "Campfire",
		Offset = { -30, -28 },
		Size = { 14, 10, 12 },
		Color = { 120, 80, 45 },
		Material = "WoodPlanks",
	},
	{
		Id = "WheatField",
		Name = "Champ de blé",
		Cost = 300,
		Income = 6,
		Requires = "WoodcutterHut",
		Offset = { 30, -28 },
		Size = { 20, 1, 16 },
		Color = { 225, 190, 80 },
		Material = "Grass",
	},
	{
		Id = "IronMine",
		Name = "Mine de fer",
		Cost = 900,
		Income = 15,
		Requires = "WheatField",
		Offset = { -34, 4 },
		Size = { 14, 12, 14 },
		Color = { 95, 95, 105 },
		Material = "Slate",
	},
	{
		Id = "Forge",
		Name = "Forge",
		Cost = 2500,
		Income = 35,
		Requires = "IronMine",
		Offset = { 34, 4 },
		Size = { 14, 12, 12 },
		Color = { 70, 60, 60 },
		Material = "Cobblestone",
	},
	{
		Id = "Tavern",
		Name = "Taverne",
		Cost = 7000,
		Income = 80,
		Requires = "Forge",
		Offset = { -30, 32 },
		Size = { 18, 14, 16 },
		Color = { 150, 100, 60 },
		Material = "Wood",
	},
	{
		Id = "Ramparts",
		Name = "Remparts",
		Cost = 18000,
		Income = 150,
		Requires = "Tavern",
		Offset = { 0, 50 },
		Size = { 100, 10, 4 },
		Color = { 160, 160, 150 },
		Material = "Brick",
	},
	{
		Id = "MageTower",
		Name = "Tour du mage",
		Cost = 50000,
		Income = 400,
		Requires = "Ramparts",
		Offset = { 30, 32 },
		Size = { 10, 30, 10 },
		Color = { 90, 70, 160 },
		Material = "Marble",
	},
	{
		Id = "Keep",
		Name = "Donjon",
		Cost = 150000,
		Income = 1000,
		Requires = "MageTower",
		Offset = { 0, 32 },
		Size = { 22, 26, 18 },
		Color = { 130, 130, 125 },
		Material = "Cobblestone",
	},
}
