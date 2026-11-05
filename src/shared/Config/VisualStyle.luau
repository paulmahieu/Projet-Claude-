--[[
	Style visuel central du jeu (module pur) : low-poly stylisé, surfaces lisses, couleurs douces,
	lumière tendre, lueurs discrètes. TOUT réglage visuel global se fait ici.

	Utilisé par :
	- EnvironmentStyle (application aux pièces : matériaux, néon, lumières, feux, textures) ;
	- les générateurs (Art/Models, Art/Outdoors, ArenaThemes, PlotService) au moment de la création ;
	- PlotService.setupLighting (éclairage).

	Cause de l'aspect granuleux corrigée : matériaux texturés de Roblox (Cobblestone, Slate, Brick,
	Rock, WoodPlanks, Sandstone, Grass, Metal...), gros volumes en Neon (cristaux et flammes
	surexposés en blanc), bloom fort et lumières orange/cyan trop puissantes.

	Exemption : attribut PreserveOriginalStyle = true sur une pièce ou un de ses ancêtres.
]]

return {
	Version = 1, -- change si les règles changent : les pièces déjà traitées seront retraitées

	-- Matériaux conservés tels quels (effets voulus) ; tous les autres deviennent SmoothPlastic.
	KeepMaterials = { "Glass", "ForceField", "Water", "Neon" },
	Reflectance = 0,

	-- Néon autorisé seulement pour les petits accents (runes, braises, yeux, voyants) :
	-- un volume plus gros ou un nom de cristal/flamme passe en SmoothPlastic.
	Neon = {
		MaxVolume = 3, -- studs³
		MaxSide = 2.5, -- studs
		-- Noms (préfixes) de cristaux : facettes turquoise visibles au lieu d'une silhouette blanche.
		CrystalNames = { "Crystal", "ThemeCrystal", "Shard", "Gem", "FloatingCrystal", "WallCrystal", "Orb" },
		-- Noms de flammes : forme lisible, légèrement translucide (le Fire de Roblox fait l'effet).
		FlameNames = { "Flame", "ThemeFlame", "Spark", "Mouth" },
		FlameTransparency = 0.5,
		-- Couleur très claire d'un cristal : rapprochée du turquoise (une seule fois, idempotent).
		CrystalTint = { 88, 214, 205 },
		CrystalPaleThreshold = 0.88, -- luminance au-delà de laquelle on teinte
	},

	-- Lumières et feux : plafonnés (pas de grandes nappes orange ou cyan).
	Lights = { MaxBrightness = 0.9, MaxRange = 16 },
	Fire = { MaxSize = 4, MaxHeat = 6 },

	-- Palette de référence (blue-gray, sable, mousse, bordeaux, turquoise) et damier en deux tons.
	Palette = {
		Wall = { 118, 132, 158 },
		Wall2 = { 108, 122, 148 },
		Wall3 = { 128, 142, 166 },
		Trim = { 226, 206, 162 },
		Trim2 = { 212, 190, 146 },
		Moss = { 122, 160, 98 },
		Moss2 = { 140, 176, 112 },
		Banner = { 140, 46, 66 },
		Gold = { 222, 184, 96 },
		Crystal = { 88, 214, 205 },
		CrystalLight = { 150, 236, 228 },
		FloorA = { 220, 204, 166 },
		FloorB = { 162, 172, 188 },
		Rock = { 150, 156, 170 },
	},

	-- Éclairage doux de début d'après-midi.
	Lighting = {
		Style = "Soft", -- Lighting.LightingStyle si disponible
		Brightness = 2,
		ClockTime = 14,
		ExposureCompensation = 0,
		OutdoorAmbient = { 150, 150, 165 },
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.15,
		Atmosphere = { Density = 0.05, Haze = 0, Glare = 0, Color = { 214, 222, 236 }, Decay = { 150, 160, 186 } },
		Bloom = { Intensity = 0.05, Threshold = 2.6, Size = 8 },
		SunRays = { Intensity = 0.015, Spread = 0.5 },
		Grading = { Saturation = 0.04, Contrast = 0.04, Brightness = 0.02, Tint = { 255, 252, 246 } },
	},
}
