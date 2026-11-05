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

	-- Néon : gardé pour les accents et les repères de jeu (portails, runes, bordures de zones,
	-- gemmes d'état, voyants). Seuls les cristaux (silhouettes blanches surexposées) et les
	-- flammes (blocs jaunes) passent en surfaces lisses.
	Neon = {
		-- Noms (préfixes) de cristaux : facettes turquoise visibles au lieu d'une silhouette blanche.
		CrystalNames = { "Crystal", "ThemeCrystal", "Shard", "FloatingCrystal", "WallCrystal", "Orb" },
		-- Noms de flammes : forme lisible, légèrement translucide (le Fire de Roblox fait l'effet).
		FlameNames = { "Flame", "ThemeFlame", "Spark", "Mouth" },
		FlameTransparency = 0.5,
		-- Couleur très claire d'un cristal : rapprochée du turquoise (une seule fois, idempotent).
		CrystalTint = { 88, 214, 205 },
		CrystalPaleThreshold = 0.88, -- luminance au-delà de laquelle on teinte
	},

	-- Lumières et feux : plafonnés (pas de grandes nappes orange ou cyan).
	Lights = { MaxBrightness = 1.2, MaxRange = 18 }, -- accents lumineux dosés, sans nappes
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

	-- Éclairage doux et lisible : plein jour calme, couleurs naturelles, légère brume de profondeur ;
	-- le bloom ne touche que les vrais accents (néon, cristaux).
	Lighting = {
		Style = "Soft", -- Lighting.LightingStyle si disponible
		Brightness = 2.0,
		ClockTime = 14.2,
		ExposureCompensation = -0.1,
		OutdoorAmbient = { 128, 132, 146 }, -- plus bas : les ombres redonnent du volume
		ColorShiftTop = { 252, 240, 222 }, -- soleil légèrement chaud
		ShadowSoftness = 0.35,
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.2,
		Atmosphere = { Density = 0.28, Haze = 1.2, Glare = 0, Color = { 199, 210, 224 }, Decay = { 106, 122, 150 } },
		Bloom = { Intensity = 0.12, Threshold = 2.2, Size = 18 },
		SunRays = { Intensity = 0.02, Spread = 0.5 },
		Grading = { Saturation = -0.05, Contrast = 0.06, Brightness = 0, Tint = { 255, 250, 244 } },
		-- Salles fermées (Rue des boss, Champ) : ambiance claire, jamais sombre.
		IndoorAmbient = { 92, 90, 108 },
	},
}
