--[[
	Pack de décors du créateur (Blender -> FBX/glTF -> Roblox Studio). Module pur.

	Les modèles NE SONT PAS dans le projet tant qu'ils n'ont pas été importés dans Roblox Studio
	(l'import crée les maillages sur le compte du créateur). Une fois importés et placés dans
	ServerStorage > Assets avec le nom ci-dessous (celui du fichier, ex. « 01_Mur_pierre »), le
	jeu les utilise automatiquement ; sinon il garde ses décors générés. Aucun identifiant
	d'asset n'est écrit dans le code (voir docs/IMPORT_DECORS.md).

	Size : dimensions attendues en studs, ordre Roblox { X = largeur, Y = hauteur, Z = profondeur }
	(manifeste du pack : largeur / profondeur / hauteur). Un modèle importé à une autre échelle
	est remis à cette taille (tolérance Tolerance).

	Collision (collisions simples, maillages eux-mêmes non collisionnables) :
	  Boxes   : boîtes invisibles { Size, Offset } (studs, origine = centre du dessous)
	  None    : aucune collision (feuillage)
	Parts sans collision : noms (préfixes) des pièces purement décoratives.
]]

return {
	Tolerance = 0.12, -- écart de taille accepté avant remise à l'échelle (12 %)

	List = {
		{
			Id = "01_Mur_pierre",
			Name = "Mur de pierre",
			Size = { 12, 7, 2 },
			Collision = { Boxes = { { Size = { 12, 7, 2 }, Offset = { 0, 3.5, 0 } } } },
			Tile = true, -- module répété sans décalage (12 studs)
		},
		{
			Id = "02_Sol_pave",
			Name = "Dalle de pavés",
			Size = { 8, 0.5, 8 },
			-- Volume plat unique : pas d'accroc entre les pierres (recommandation du pack).
			Collision = { Boxes = { { Size = { 8, 0.5, 8 }, Offset = { 0, 0.25, 0 } } } },
			Tile = true, -- module répété sans décalage (8 studs)
		},
		{
			Id = "03_Rocher",
			Name = "Rocher",
			Size = { 5, 4, 4 },
			Collision = { Boxes = { { Size = { 3.6, 3.4, 3.2 }, Offset = { 0, 1.7, 0 } } } },
		},
		{
			Id = "04_Palissade",
			Name = "Palissade",
			Size = { 8, 6, 1 },
			Collision = { Boxes = { { Size = { 8, 6, 1 }, Offset = { 0, 3, 0 } } } },
			Tile = true,
		},
		{
			Id = "05_Portail",
			Name = "Portail",
			Size = { 10, 9, 2 },
			-- Piliers et linteau ; les battants ont chacun leur propre boîte qui tourne avec eux.
			Collision = {
				Boxes = {
					{ Size = { 1.5, 9, 2 }, Offset = { -4.25, 4.5, 0 } },
					{ Size = { 1.5, 9, 2 }, Offset = { 4.25, 4.5, 0 } },
					{ Size = { 10, 1.2, 2 }, Offset = { 0, 8.4, 0 } },
				},
			},
			Doors = {
				-- Charnière (studs, repère du modèle) et angle d'ouverture du manifeste.
				{ Part = "Porte_gauche", Hinge = { -3.5, 0, 0 }, OpenAngle = -65, Size = { 3.5, 7.6, 0.4 } },
				{ Part = "Porte_droite", Hinge = { 3.5, 0, 0 }, OpenAngle = 65, Size = { 3.5, 7.6, 0.4 } },
			},
		},
		{
			Id = "06_Caisse",
			Name = "Caisse",
			Size = { 3, 3, 3 },
			Collision = { Boxes = { { Size = { 3, 3, 3 }, Offset = { 0, 1.5, 0 } } } },
		},
		{
			Id = "07_Tonneau",
			Name = "Tonneau",
			Size = { 3, 4, 3 },
			Collision = { Boxes = { { Size = { 2.6, 4, 2.6 }, Offset = { 0, 2, 0 } } } },
		},
		{
			Id = "08_Torche",
			Name = "Torche",
			Size = { 2, 6, 2 },
			Collision = {
				Boxes = {
					{ Size = { 1.6, 0.8, 1.6 }, Offset = { 0, 0.4, 0 } },
					{ Size = { 0.5, 5, 0.5 }, Offset = { 0, 2.5, 0 } },
				},
			},
			NoCollide = { "Flamme" },
			-- Lumière ajoutée par le jeu au-dessus du brasero (hauteur en studs).
			Light = { Height = 5, Range = 18, Color = { 255, 170, 90 } },
		},
		{
			Id = "09_Buisson",
			Name = "Buisson",
			Size = { 4, 3, 3 },
			Collision = { None = true },
		},
		{
			Id = "10_Minerai_cristal",
			Name = "Minerai de cristal",
			Size = { 4, 4, 3 },
			Collision = { Boxes = { { Size = { 3.6, 1.2, 2.8 }, Offset = { 0, 0.6, 0 } } } },
			NoCollide = { "Cristal" },
			Depletable = { "Cristal" }, -- pièces qui disparaissent à la récolte
		},
	},
}
