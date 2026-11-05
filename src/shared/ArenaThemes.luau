--[[
	ArenaThemes : décors d'arène de la Rue des boss, d'après les maquettes 3D du créateur
	(« Arène des Cristaux », « Salle des Glaces », « Cour du Sanctuaire », « Arène de la Forge »).

	Chaque thème habille UNE section de la rue (26 x 40 studs) : sol en damier, remparts et
	chaperons, porte au bout de la section, tours d'angle, braseros allumés, cristaux, piliers,
	emblème lumineux au sol, bannières et élément signature (épée, trône de glace, grand arbre,
	enclume). Les proportions des maquettes sont adaptées à la largeur de la rue ; la porte est
	élargie pour laisser passer le combat.

	Purement décoratif et construit côté client : non collisionnable et ignoré par les rayons
	(la rue du serveur garde ses murs et ses portes). `frame` : centre de la section au niveau
	du sol, -Z = sens de progression (bout de la section en z = -20).
]]

local ArenaThemes = {}

local HX, HZ = 13, 20 -- demi-largeur et demi-longueur d'une section
local WALL_X = 14 -- axe des murs de la rue
local GATE = 8 -- demi-largeur de l'ouverture des portes

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function rng(seed: number)
	local state = math.floor(math.abs(seed) * 7919 + 12345) % 2147483646 + 1
	return function(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material, o)
	local p = Instance.new(if o and o.Wedge then "WedgePart" else "Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = o ~= nil and o.Shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o and o.Shape then
		(p :: Part).Shape = o.Shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if o and o.Transparency then
		p.Transparency = o.Transparency
	end
	p.Parent = parent
	return p
end

local function cyl(parent, name, h: number, d: number, cf: CFrame, color, material, o)
	o = table.clone(o or {})
	o.Shape = Enum.PartType.Cylinder
	return P(parent, name, Vector3.new(h, d, d), cf * CFrame.new(0, h / 2, 0) * VERTICAL, color, material, o)
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function fire(parent: BasePart, color: Color3, secondary: Color3, size: number)
	local f = Instance.new("Fire")
	f.Color = color
	f.SecondaryColor = secondary
	f.Size = size
	f.Heat = size * 1.4
	f.Parent = parent
end

-- Éléments communs ------------------------------------------------------------------------------

-- Sol : dalle de fond (cases sombres) + cases claires en damier (6 x 10).
local function floor(m, f: CFrame, st, rand)
	P(
		m,
		"ThemeFloor",
		Vector3.new(HX * 2 + 0.3, 0.1, HZ * 2 + 0.3),
		f * CFrame.new(0, 0.04, 0),
		st.FloorDark,
		st.FloorDarkMat
	)
	local cols, rows = 6, 10
	local w, l = HX * 2 / cols, HZ * 2 / rows
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			if (i + j) % 2 == 0 then
				local v = (rand() - 0.5) * 0.06
				P(
					m,
					"ThemeTile",
					Vector3.new(w, 0.1, l),
					f * CFrame.new(-HX + (i + 0.5) * w, 0.08, -HZ + (j + 0.5) * l),
					st.FloorLight:Lerp(if v > 0 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0), math.abs(v)),
					st.FloorLightMat
				)
			end
		end
	end
end

-- Murs latéraux : segments alternés haut/bas, chaperons, détail du thème sur la face intérieure.
local function sideWalls(m, f: CFrame, st, rand)
	local n = 10
	local len = HZ * 2 / n
	for _, sx in { -1, 1 } do
		for i = 0, n - 1 do
			local z = -HZ + (i + 0.5) * len
			local tall = i % 2 == 0
			local h = st.H + (if tall then 1 else 0) + (rand() - 0.5) * 0.4
			P(
				m,
				"ThemeWall",
				Vector3.new(2.6, h, len * 0.99),
				f * CFrame.new(sx * WALL_X, h / 2, z),
				st.Wall[1 + math.floor(rand() * #st.Wall)],
				st.WallMat
			)
			P(
				m,
				"ThemeWallCap",
				Vector3.new(if tall then 3.2 else 2.9, 0.7, len * (if tall then 1.04 else 0.94)),
				f * CFrame.new(sx * WALL_X, h + 0.3, z),
				if tall then st.Cap else st.Cap2 or st.Cap,
				st.CapMat
			)
			if st.WallDetail then
				-- Repère sur la face intérieure du mur, en haut : -X local = vers l'intérieur.
				st.WallDetail(
					m,
					f * CFrame.new(sx * (WALL_X - 1.3), h, z) * CFrame.Angles(0, if sx > 0 then 0 else math.pi, 0),
					len,
					h,
					rand
				)
			end
		end
	end
end

-- Bout de section : murets, tours d'angle et porte élargie (z = -20). Si `near`, aussi au début.
local function ends(m, f: CFrame, st, _rand, near: boolean)
	for _, zs in (if near then { -1, 1 } else { -1 }) do
		local z = zs * HZ
		for _, sx in { -1, 1 } do
			local x = sx * (GATE + 2.6 + (HX - GATE - 2.6) / 2)
			local w = HX - GATE - 2.6 + 1.4
			P(m, "ThemeEndWall", Vector3.new(w, st.H, 2.6), f * CFrame.new(x, st.H / 2, z), st.Wall[1], st.WallMat)
			P(m, "ThemeEndCap", Vector3.new(w + 0.3, 0.7, 3.0), f * CFrame.new(x, st.H + 0.3, z), st.Cap, st.CapMat)
			-- Tour d'angle
			P(
				m,
				"ThemeTower",
				Vector3.new(3.6, st.H + 3, 3.6),
				f * CFrame.new(sx * WALL_X, (st.H + 3) / 2, z),
				st.Wall[#st.Wall],
				st.WallMat
			)
			P(
				m,
				"ThemeTowerCap",
				Vector3.new(4.2, 0.9, 4.2),
				f * CFrame.new(sx * WALL_X, st.H + 3.4, z),
				st.Cap,
				st.CapMat
			)
			-- Pilier de porte
			P(
				m,
				"ThemeGatePillar",
				Vector3.new(2.6, 11.2, 3.0),
				f * CFrame.new(sx * (GATE + 1.3), 5.6, z),
				st.Gate,
				st.GateMat
			)
			P(
				m,
				"ThemeGateBand",
				Vector3.new(2.8, 0.3, 3.2),
				f * CFrame.new(sx * (GATE + 1.3), 8.6, z),
				st.Trim,
				st.TrimMat
			)
			if st.GateBanner then
				for _, face in { -1, 1 } do
					st.GateBanner(
						m,
						f
							* CFrame.new(sx * (GATE + 1.3), 4.8, z + face * 1.56)
							* CFrame.Angles(0, if face > 0 then math.pi else 0, 0)
					)
				end
			end
		end
		-- Linteau (au-dessus de la barrière de la porte) et emblème sur les deux faces
		P(m, "ThemeLintel", Vector3.new(GATE * 2 + 5.2, 1.8, 3.0), f * CFrame.new(0, 12.1, z), st.Gate, st.GateMat)
		P(m, "ThemeLintelCap", Vector3.new(GATE * 2 + 5.8, 0.4, 3.4), f * CFrame.new(0, 13.2, z), st.Cap, st.CapMat)
		if st.GateEmblem then
			for _, face in { -1, 1 } do
				st.GateEmblem(
					m,
					f * CFrame.new(0, 12.1, z + face * 1.55) * CFrame.Angles(0, if face > 0 then math.pi else 0, 0)
				)
			end
		end
	end
end

-- Bannière murale simple (tissu, tringle, motif) ; -Z du repère = face visible.
local function banner(m, cf: CFrame, w: number, h: number, cloth: Color3, trim: Color3, motif: Color3?)
	P(m, "ThemeBanner", Vector3.new(w, h, 0.12), cf, cloth, Enum.Material.Fabric)
	P(
		m,
		"ThemeBannerRod",
		Vector3.new(w + 0.5, 0.24, 0.26),
		cf * CFrame.new(0, h / 2, -0.05),
		trim,
		Enum.Material.Metal
	)
	P(
		m,
		"ThemeBannerHem",
		Vector3.new(w + 0.06, 0.18, 0.22),
		cf * CFrame.new(0, -h / 2, -0.02),
		trim,
		Enum.Material.Metal
	)
	if motif then
		P(
			m,
			"ThemeBannerMotif",
			Vector3.new(w * 0.4, w * 0.4, 0.05),
			cf * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, 0, math.rad(45)),
			motif,
			Enum.Material.Neon
		)
	end
end

-- Bannières des murs latéraux (deux par côté)
local function wallBanners(m, f: CFrame, st)
	for _, sx in { -1, 1 } do
		for _, z in { -7, 7 } do
			banner(
				m,
				f * CFrame.new(sx * (WALL_X - 1.36), 3.6, z) * CFrame.Angles(0, sx * math.pi / 2, 0),
				1.6,
				3.6,
				st.Banner,
				st.Trim,
				st.BannerMotif
			)
		end
	end
end

-- Cristal : fût tourné et pointe en losange
local function shard(m, base: CFrame, h: number, r: number, color: Color3)
	P(
		m,
		"ThemeCrystal",
		Vector3.new(r * 1.8, h, r * 1.8),
		base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(30), 0),
		color,
		Enum.Material.Neon,
		{
			Transparency = 0.1,
		}
	)
	P(
		m,
		"ThemeCrystalTip",
		Vector3.new(r * 1.3, r * 1.3, r * 1.3),
		base * CFrame.new(0, h, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		color,
		Enum.Material.Neon,
		{ Transparency = 0.1 }
	)
end

local function cluster(m, base: CFrame, st, s: number)
	P(
		m,
		"ThemeRock",
		Vector3.new(3.4 * s, 1.1 * s, 2.8 * s),
		base * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0.2, 0.5, 0.1),
		st.Rock,
		Enum.Material.Rock
	)
	P(
		m,
		"ThemeRock",
		Vector3.new(1.5 * s, 1.3 * s, 1.5 * s),
		base * CFrame.new(1.4 * s, 0.3 * s, 0.6 * s) * CFrame.Angles(0.6, 0.3, 0.5),
		st.Rock,
		Enum.Material.Rock
	)
	for _, sp in
		{
			{ 0, 0, 2.6, 0.5, 0, 0 },
			{ 0.7, 0.2, 1.9, 0.4, -0.45, 0.2 },
			{ -0.75, 0.1, 1.8, 0.4, 0.5, -0.1 },
			{ 0.2, -0.7, 1.5, 0.34, 0.15, 0.5 },
			{ -0.2, 0.8, 1.3, 0.3, -0.1, -0.5 },
		}
	do
		shard(
			m,
			base * CFrame.new(sp[1] * s, 0.6 * s, sp[2] * s) * CFrame.Angles(sp[6], 0, sp[5]),
			sp[3] * s,
			sp[4] * s,
			if sp[3] > 1.85 then st.Crystal else st.Crystal2 or st.Crystal
		)
	end
end

local function pedestal(m, base: CFrame, st)
	P(m, "ThemePedestalFoot", Vector3.new(1.9, 0.4, 1.9), base * CFrame.new(0, 0.2, 0), st.Gate, st.GateMat)
	P(m, "ThemePedestal", Vector3.new(1.3, 1.2, 1.3), base * CFrame.new(0, 1, 0), st.Pedestal or st.Gate, st.GateMat)
	P(m, "ThemePedestalCap", Vector3.new(1.7, 0.25, 1.7), base * CFrame.new(0, 1.7, 0), st.Cap, st.CapMat)
	P(
		m,
		"ThemeFloatingCrystal",
		Vector3.new(0.55, 1.1, 0.55),
		base * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, math.rad(45), 0),
		st.Crystal2 or st.Crystal,
		Enum.Material.Neon
	)
end

-- Anneau plat au sol (segments), rayon r, épaisseur radiale w.
local function floorRing(m, f: CFrame, r: number, w: number, n: number, color: Color3, y: number)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		P(
			m,
			"ThemeRune",
			Vector3.new(w, 0.05, 2 * math.pi * r / n * 1.06),
			f * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(0, -a, 0),
			color,
			Enum.Material.Neon,
			{ Transparency = 0.15 }
		)
	end
end

-- Barre plate lumineuse au sol, de (x1, z1) à (x2, z2).
local function floorBar(
	m,
	f: CFrame,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	w: number,
	color: Color3,
	y: number
)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	P(
		m,
		"ThemeRune",
		Vector3.new(w, 0.05, len),
		f * CFrame.new((x1 + x2) / 2, y, (z1 + z2) / 2) * CFrame.Angles(0, math.atan2(dx, dz), 0),
		color,
		Enum.Material.Neon,
		{ Transparency = 0.12 }
	)
end

-- Thèmes ---------------------------------------------------------------------------------------

local THEMES = {}

-- Arène des Cristaux : sable et ardoise, mousse, bannières rouges, cristaux turquoise, épée.
THEMES.Crystal = {
	Sky = rgb(106, 130, 228),
	FloorLight = rgb(216, 192, 143),
	FloorLightMat = Enum.Material.Sandstone,
	FloorDark = rgb(160, 168, 182),
	FloorDarkMat = Enum.Material.Slate,
	Wall = { rgb(102, 114, 140), rgb(93, 104, 130), rgb(113, 126, 152) },
	WallMat = Enum.Material.Slate,
	Cap = rgb(226, 198, 139),
	Cap2 = rgb(210, 178, 115),
	CapMat = Enum.Material.Sandstone,
	Gate = rgb(161, 168, 184),
	GateMat = Enum.Material.Slate,
	Trim = rgb(240, 181, 46),
	TrimMat = Enum.Material.Metal,
	Banner = rgb(160, 42, 66),
	BannerMotif = rgb(240, 181, 46),
	Rock = rgb(142, 148, 163),
	Crystal = rgb(103, 242, 226),
	Crystal2 = rgb(184, 255, 246),
	Fire = { rgb(255, 138, 30), rgb(255, 224, 102) },
	H = 7,
}
THEMES.Crystal.WallDetail = function(m, cf: CFrame, len: number, _h: number, rand)
	if rand() < 0.5 then
		local mh = 1 + rand() * 2.4
		P(
			m,
			"ThemeMoss",
			Vector3.new(0.14, mh, len * (0.4 + rand() * 0.5)),
			cf * CFrame.new(-0.05, -mh / 2 + 0.05, (rand() - 0.5) * 0.6),
			if rand() < 0.5 then rgb(95, 154, 52) else rgb(130, 187, 69),
			Enum.Material.Grass
		)
	end
end
THEMES.Crystal.GateBanner = function(m, cf: CFrame)
	banner(m, cf, 1.5, 3.6, rgb(160, 42, 66), rgb(240, 181, 46), rgb(240, 181, 46))
end
THEMES.Crystal.GateEmblem = function(m, cf: CFrame)
	P(m, "ThemeShield", Vector3.new(1.6, 0.9, 0.2), cf * CFrame.new(0, 0.3, 0), rgb(240, 181, 46), Enum.Material.Metal)
	P(
		m,
		"ThemeShield",
		Vector3.new(1.1, 1.1, 0.2),
		cf * CFrame.new(0, -0.25, 0) * CFrame.Angles(0, 0, math.rad(45)),
		rgb(240, 181, 46),
		Enum.Material.Metal
	)
end
THEMES.Crystal.Emblem = function(m, f: CFrame, _st)
	floorRing(m, f, 6.3, 0.4, 32, rgb(63, 232, 212), 0.17)
	floorRing(m, f, 4.05, 0.3, 24, rgb(63, 232, 212), 0.17)
	for _, p in { { 6.3, 0 }, { -6.3, 0 }, { 0, 6.3 }, { 0, -6.3 } } do
		P(
			m,
			"ThemeRune",
			Vector3.new(1.2, 0.06, 1.2),
			f * CFrame.new(p[1], 0.18, p[2]) * CFrame.Angles(0, math.rad(45), 0),
			rgb(63, 232, 212),
			Enum.Material.Neon
		)
	end
	for k = 0, 3 do
		P(
			m,
			"ThemeRune",
			Vector3.new(1.4, 0.05, 0.3),
			f * CFrame.new(0, 0.17, 0) * CFrame.Angles(0, k * math.pi / 2 + math.rad(45), 0) * CFrame.new(0, 0, 0.86),
			rgb(63, 232, 212),
			Enum.Material.Neon
		)
	end
end
THEMES.Crystal.Signature = function(m, f: CFrame, st)
	local sb = f * CFrame.new(6.5, 0, -15.5)
	P(
		m,
		"ThemeSwordRock",
		Vector3.new(3.6, 2, 3),
		sb * CFrame.new(0, 0.6, 0) * CFrame.Angles(0.15, 0.4, 0.1),
		st.Rock,
		Enum.Material.Rock
	)
	local sw = sb * CFrame.new(0, 1.2, 0) * CFrame.Angles(0.08, 0, -0.32)
	P(m, "ThemeBlade", Vector3.new(0.88, 6.8, 0.2), sw * CFrame.new(0, 3.4, 0), rgb(223, 227, 236), Enum.Material.Metal)
	P(m, "ThemeGuard", Vector3.new(3.1, 0.48, 0.6), sw * CFrame.new(0, 7, 0), rgb(240, 181, 46), Enum.Material.Metal)
	P(m, "ThemeGrip", Vector3.new(0.4, 1.6, 0.4), sw * CFrame.new(0, 8, 0), rgb(95, 59, 30), Enum.Material.Wood)
	P(
		m,
		"ThemePommel",
		Vector3.new(0.6, 0.6, 0.6),
		sw * CFrame.new(0, 9.1, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		rgb(240, 181, 46),
		Enum.Material.Metal
	)
end

-- Salle des Glaces : pierre bleutée, neige et stalactites, bannières bleu roi, flammes bleues,
-- flocon lumineux, trône de glace.
THEMES.Ice = {
	Sky = rgb(142, 176, 239),
	FloorLight = rgb(168, 179, 214),
	FloorLightMat = Enum.Material.Slate,
	FloorDark = rgb(135, 139, 186),
	FloorDarkMat = Enum.Material.Slate,
	Wall = { rgb(120, 135, 171), rgb(107, 121, 158), rgb(116, 130, 166) },
	WallMat = Enum.Material.Slate,
	Cap = rgb(244, 247, 255),
	CapMat = Enum.Material.Snow,
	Gate = rgb(120, 135, 171),
	GateMat = Enum.Material.Slate,
	Trim = rgb(166, 178, 207),
	TrimMat = Enum.Material.Slate,
	Banner = rgb(52, 70, 166),
	BannerMotif = rgb(238, 243, 255),
	Pedestal = rgb(199, 209, 230),
	Rock = rgb(227, 233, 248),
	Crystal = rgb(166, 226, 247),
	Crystal2 = rgb(200, 248, 255),
	Fire = { rgb(63, 210, 255), rgb(157, 245, 255) },
	H = 7,
}
THEMES.Ice.WallDetail = function(m, cf: CFrame, len: number, _h: number, rand)
	-- Stalactites sous le chaperon enneigé
	for k = 1, 3 do
		if rand() < 0.7 then
			local l = 0.6 + rand() * 1.4
			P(
				m,
				"ThemeIcicle",
				Vector3.new(0.3, l, 0.3),
				cf * CFrame.new(-0.2, -l / 2, (k - 2) * len * 0.3 + (rand() - 0.5)) * CFrame.Angles(0, math.rad(45), 0),
				rgb(166, 226, 247),
				Enum.Material.Ice,
				{ Transparency = 0.15 }
			)
		end
	end
end
THEMES.Ice.GateBanner = function(m, cf: CFrame)
	banner(m, cf, 1.6, 3.6, rgb(52, 70, 166), rgb(217, 205, 180), rgb(238, 243, 255))
end
local function snowflake(m, cf: CFrame, r: number, color: Color3, flat: boolean)
	-- `flat` : posé au sol (dans le plan XZ) ; sinon vertical (plan XY du repère).
	for k = 0, 5 do
		local a = k * math.pi / 3
		local rot = if flat then CFrame.Angles(0, a, 0) else CFrame.Angles(0, 0, a)
		local arm = cf * rot
		local function bar(len: number, w: number, at: CFrame)
			P(
				m,
				"ThemeFlake",
				if flat then Vector3.new(len, 0.05, w) else Vector3.new(len, w, 0.12),
				at,
				color,
				Enum.Material.Neon
			)
		end
		bar(r, r * 0.07, arm * CFrame.new(r / 2, 0, 0))
		for _, d in { 0.4, 0.68 } do
			for _, sgn in { -1, 1 } do
				local branch = arm * CFrame.new(r * d, 0, 0)
				local turn = if flat
					then CFrame.Angles(0, sgn * math.pi / 3, 0)
					else CFrame.Angles(0, 0, sgn * math.pi / 3)
				bar(r * 0.26, r * 0.05, branch * turn * CFrame.new(r * 0.13, 0, 0))
			end
		end
	end
end
THEMES.Ice.GateEmblem = function(m, cf: CFrame)
	snowflake(m, cf, 0.9, rgb(238, 248, 255), false)
end
THEMES.Ice.Emblem = function(m, f: CFrame, _st)
	snowflake(m, f * CFrame.new(0, 0.17, -0.8), 6.6, rgb(134, 242, 255), true)
end
THEMES.Ice.Signature = function(m, f: CFrame, _st)
	local t = f * CFrame.new(7, 0, -16)
	local ice = rgb(210, 228, 245)
	P(
		m,
		"ThemeThroneBase",
		Vector3.new(4, 0.44, 3.2),
		t * CFrame.new(0, 0.22, 0),
		rgb(199, 209, 230),
		Enum.Material.Slate
	)
	P(m, "ThemeThroneSeat", Vector3.new(2.8, 1.1, 2.1), t * CFrame.new(0, 0.99, 0.2), ice, Enum.Material.Ice)
	P(m, "ThemeThroneBack", Vector3.new(2.8, 3.4, 0.76), t * CFrame.new(0, 2.14, -0.84), ice, Enum.Material.Ice)
	P(m, "ThemeThroneBack", Vector3.new(1.6, 0.9, 0.68), t * CFrame.new(0, 4.29, -0.84), ice, Enum.Material.Ice)
	for _, s in { -1, 1 } do
		P(m, "ThemeThroneArm", Vector3.new(0.6, 1, 2), t * CFrame.new(s * 1.24, 2.04, 0.2), ice, Enum.Material.Ice)
	end
	local gem = P(
		m,
		"ThemeThroneGem",
		Vector3.new(0.6, 1.2, 0.6),
		t * CFrame.new(0, 6.1, -0.84) * CFrame.Angles(0, math.rad(45), 0),
		rgb(200, 248, 255),
		Enum.Material.Neon
	)
	light(gem, rgb(143, 242, 255), 14, 1)
	-- Congères au pied des murs
	for _, p in { { -11.5, -17.5 }, { 11.5, 17.5 }, { -11.5, 9 }, { 11.5, -5 } } do
		P(
			m,
			"ThemeDrift",
			Vector3.new(2.6, 0.9, 3.4),
			f * CFrame.new(p[1], 0.2, p[2]),
			rgb(244, 247, 255),
			Enum.Material.Snow,
			{
				Shape = Enum.PartType.Ball,
			}
		)
	end
end

-- Cour du Sanctuaire : pierre verte et lierre, bannières vertes et or, flammes vertes, pousse
-- lumineuse au sol, grand arbre et champignons.
THEMES.Sanctuary = {
	Sky = rgb(63, 178, 222),
	FloorLight = rgb(228, 217, 175),
	FloorLightMat = Enum.Material.Sandstone,
	FloorDark = rgb(184, 201, 142),
	FloorDarkMat = Enum.Material.Slate,
	Wall = { rgb(127, 148, 121), rgb(136, 156, 129), rgb(117, 137, 110), rgb(138, 154, 124) },
	WallMat = Enum.Material.Slate,
	Cap = rgb(207, 201, 164),
	CapMat = Enum.Material.Sandstone,
	Gate = rgb(142, 150, 138),
	GateMat = Enum.Material.Slate,
	Trim = rgb(224, 178, 60),
	TrimMat = Enum.Material.Metal,
	Banner = rgb(29, 90, 49),
	BannerMotif = rgb(226, 181, 68),
	Pedestal = rgb(207, 199, 163),
	Rock = rgb(155, 158, 151),
	Crystal = rgb(156, 240, 96),
	Crystal2 = rgb(180, 255, 122),
	Fire = { rgb(141, 255, 79), rgb(234, 255, 196) },
	H = 7.5,
}
THEMES.Sanctuary.WallDetail = function(m, cf: CFrame, len: number, _h: number, rand)
	-- Lierre : quelques feuilles qui tombent du chaperon
	if rand() < 0.7 then
		local off = (rand() - 0.5) * len * 0.7
		local length = 1 + rand() * 3.5
		for d = 0, length, 0.45 do
			P(
				m,
				"ThemeIvy",
				Vector3.new(0.3, 0.32, 0.36),
				cf * CFrame.new(-0.15, -d, off + math.sin(d * 2) * 0.2) * CFrame.Angles(d, d * 0.7, 0),
				if math.floor(d * 2) % 2 == 0 then rgb(93, 158, 63) else rgb(125, 189, 85),
				Enum.Material.Grass
			)
		end
	end
end
THEMES.Sanctuary.GateBanner = function(m, cf: CFrame)
	banner(m, cf, 1.7, 3.8, rgb(29, 90, 49), rgb(217, 169, 58), rgb(226, 181, 68))
end
local function sprout(m, cf: CFrame, s: number, color: Color3, flat: boolean, material)
	-- Pousse à trois feuilles (losanges allongés) ; `flat` : posée au sol.
	local function leaf(dx: number, dy: number, angle: number, len: number)
		local rot = if flat then CFrame.Angles(0, -angle, 0) else CFrame.Angles(0, 0, angle)
		local pos = if flat then CFrame.new(dx * s, 0, -dy * s) else CFrame.new(dx * s, dy * s, 0)
		P(
			m,
			"ThemeSprout",
			if flat then Vector3.new(len * 0.38 * s, 0.05, len * s) else Vector3.new(len * 0.38 * s, len * s, 0.12),
			cf * pos * rot,
			color,
			material or Enum.Material.Neon
		)
	end
	leaf(0, 0.45, 0, 0.8)
	leaf(-0.36, 0.08, 0.95, 0.62)
	leaf(0.36, 0.08, -0.95, 0.62)
	leaf(0, -0.25, 0, 0.6)
end
THEMES.Sanctuary.GateEmblem = function(m, cf: CFrame)
	sprout(m, cf, 1.4, rgb(224, 178, 60), false, Enum.Material.Metal)
end
THEMES.Sanctuary.Emblem = function(m, f: CFrame, _st)
	local c = rgb(190, 255, 130)
	floorRing(m, f, 6.6, 0.32, 32, c, 0.17)
	sprout(m, f * CFrame.new(0, 0.17, 0.4), 5.2, c, true)
end
THEMES.Sanctuary.Signature = function(m, f: CFrame, _st, _rand)
	-- Grand arbre (fond de la section) : tronc, racines, quatre masses de feuillage
	local t = f * CFrame.new(8.2, 0, -15.5)
	cyl(m, "ThemeTrunk", 7, 2.4, t, rgb(123, 74, 43), Enum.Material.Wood, { Shadow = true })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		P(
			m,
			"ThemeRoot",
			Vector3.new(0.8, 0.8, 3),
			t * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.3, 1.8) * CFrame.Angles(-0.35, 0, 0),
			rgb(103, 64, 31),
			Enum.Material.Wood
		)
	end
	local leaves = { rgb(109, 197, 68), rgb(92, 180, 59), rgb(127, 208, 82) }
	for i, b in { { -2.4, 8.4, 1.1, 4.6 }, { 2.4, 8.6, -0.4, 4.8 }, { 0.2, 10.2, -1.4, 5 }, { 0, 8.8, 1.8, 4 } } do
		P(
			m,
			"ThemeLeaves",
			Vector3.new(b[4], b[4] * 0.8, b[4]),
			t * CFrame.new(b[1], b[2], b[3]) * CFrame.Angles(i, i * 0.7, 0.3),
			leaves[1 + i % 3],
			Enum.Material.Grass,
			{
				Shadow = true,
			}
		)
	end
	-- Champignons et rochers dans les coins
	for _, p in { { -11, -17.5 }, { -10.2, -17 }, { 11, 17.4 }, { -11.2, 17 }, { 11.3, 10 } } do
		local base = f * CFrame.new(p[1], 0, p[2])
		P(m, "ThemeMushStem", Vector3.new(0.3, 0.5, 0.3), base * CFrame.new(0, 0.25, 0), rgb(243, 236, 217))
		P(
			m,
			"ThemeMushCap",
			Vector3.new(0.3, 0.9, 0.9),
			base * CFrame.new(0, 0.55, 0) * VERTICAL,
			rgb(216, 71, 58),
			nil,
			{
				Shape = Enum.PartType.Cylinder,
			}
		)
	end
end

-- Arène de la Forge : sol rouille et prune, remparts violets à chaperons orange, coulures d'or,
-- bannières rouges, têtes de dragon dorées, braseros, chaînes, enclume et marteau.
THEMES.Forge = {
	Sky = rgb(120, 102, 176),
	FloorLight = rgb(168, 105, 90),
	FloorLightMat = Enum.Material.Slate,
	FloorDark = rgb(127, 94, 102),
	FloorDarkMat = Enum.Material.Slate,
	Wall = { rgb(111, 96, 130), rgb(124, 108, 142), rgb(105, 90, 122) },
	WallMat = Enum.Material.Slate,
	Cap = rgb(216, 146, 61),
	CapMat = Enum.Material.Metal,
	Gate = rgb(68, 62, 77),
	GateMat = Enum.Material.Slate,
	Trim = rgb(232, 165, 64),
	TrimMat = Enum.Material.Metal,
	Banner = rgb(176, 38, 45),
	BannerMotif = rgb(255, 194, 77),
	Pedestal = rgb(79, 69, 96),
	Rock = rgb(79, 69, 96),
	Crystal = rgb(255, 197, 79),
	Crystal2 = rgb(255, 180, 70),
	Fire = { rgb(255, 138, 31), rgb(255, 214, 64) },
	H = 6.5,
}
THEMES.Forge.WallDetail = function(m, cf: CFrame, len: number, _h: number, rand)
	-- Coulures d'or fondu sous le chaperon
	if rand() < 0.65 then
		local l = 0.6 + rand() * 1.4
		local off = (rand() - 0.5) * len * 0.7
		P(
			m,
			"ThemeDrip",
			Vector3.new(0.2, l, 0.2),
			cf * CFrame.new(-0.1, -l / 2, off),
			rgb(255, 184, 63),
			Enum.Material.Neon
		)
		P(
			m,
			"ThemeDripTip",
			Vector3.new(0.34, 0.34, 0.34),
			cf * CFrame.new(-0.1, -l, off),
			rgb(255, 184, 63),
			Enum.Material.Neon,
			{
				Shape = Enum.PartType.Ball,
			}
		)
	end
end
THEMES.Forge.GateBanner = function(m, cf: CFrame)
	banner(m, cf, 1.3, 3.6, rgb(176, 38, 45), rgb(232, 165, 64), rgb(255, 194, 77))
end
THEMES.Forge.GateEmblem = function(m, cf: CFrame)
	-- Tête de dragon dorée (vue de face) : museau, cornes, yeux lumineux
	local gold = rgb(232, 165, 64)
	P(m, "ThemeDragon", Vector3.new(1.6, 1.1, 0.5), cf * CFrame.new(0, 0, -0.1), gold, Enum.Material.Metal)
	P(m, "ThemeDragon", Vector3.new(1, 0.6, 0.5), cf * CFrame.new(0, -0.65, -0.3), gold, Enum.Material.Metal)
	for _, s in { -1, 1 } do
		P(
			m,
			"ThemeDragonHorn",
			Vector3.new(0.3, 1.3, 0.3),
			cf * CFrame.new(s * 0.7, 0.9, -0.1) * CFrame.Angles(0, 0, -s * 0.45),
			gold,
			Enum.Material.Metal
		)
		P(
			m,
			"ThemeDragonEye",
			Vector3.new(0.3, 0.16, 0.1),
			cf * CFrame.new(s * 0.36, 0.15, -0.38),
			rgb(255, 240, 122),
			Enum.Material.Neon
		)
	end
end
THEMES.Forge.Emblem = function(m, f: CFrame, _st)
	local c = rgb(243, 164, 60)
	floorRing(m, f, 6.2, 0.36, 32, c, 0.17)
	-- Marteau : tête, manche, losanges
	floorBar(m, f, -2.5, -2.4, 2.5, -2.4, 1.3, c, 0.17)
	floorBar(m, f, 0, -1.8, 0, 2.2, 0.8, c, 0.17)
	for _, p in { { -3.1, -0.3, 0.72 }, { 3.1, -0.3, 0.72 }, { 0, 3.5, 1.1 } } do
		P(
			m,
			"ThemeRune",
			Vector3.new(p[3], 0.05, p[3]),
			f * CFrame.new(p[1], 0.17, p[2]) * CFrame.Angles(0, math.rad(45), 0),
			c,
			Enum.Material.Neon
		)
	end
	-- Liseré lumineux au pied des murs
	for _, sx in { -1, 1 } do
		P(
			m,
			"ThemeGlowLine",
			Vector3.new(0.12, 0.14, HZ * 2),
			f * CFrame.new(sx * (WALL_X - 1.36), 0.2, 0),
			rgb(255, 174, 60),
			Enum.Material.Neon
		)
	end
end
THEMES.Forge.Signature = function(m, f: CFrame, _st)
	local a = f * CFrame.new(7.4, 0, -15.6) * CFrame.Angles(0, -0.2, 0)
	local iron = rgb(59, 53, 67)
	P(m, "ThemeAnvilBase", Vector3.new(4, 0.72, 2.4), a * CFrame.new(0, 0.36, 0), rgb(79, 69, 96), Enum.Material.Slate)
	P(m, "ThemeAnvil", Vector3.new(2.6, 0.5, 1.6), a * CFrame.new(0, 0.97, 0), iron, Enum.Material.Metal)
	P(m, "ThemeAnvil", Vector3.new(1.2, 1, 1), a * CFrame.new(0, 1.72, 0), iron, Enum.Material.Metal)
	P(m, "ThemeAnvil", Vector3.new(3.4, 0.84, 1.7), a * CFrame.new(0.2, 2.64, 0), iron, Enum.Material.Metal)
	P(
		m,
		"ThemeAnvilHorn",
		Vector3.new(1.7, 0.84, 1.4),
		a * CFrame.new(-2.3, 2.64, 0) * CFrame.Angles(0, math.rad(90), 0),
		iron,
		Enum.Material.Metal,
		{
			Wedge = true,
		}
	)
	local hm = a * CFrame.new(2.9, 0, 0.7) * CFrame.Angles(0, 0.2, 0.33)
	P(m, "ThemeHammerHandle", Vector3.new(0.3, 4, 0.3), hm * CFrame.new(0, 2, 0), rgb(122, 74, 42), Enum.Material.Wood)
	P(
		m,
		"ThemeHammerHead",
		Vector3.new(1.64, 0.84, 0.84),
		hm * CFrame.new(0, 4.1, 0),
		rgb(232, 165, 64),
		Enum.Material.Metal
	)
	-- Lingots d'or
	for i, p in { { -10.5, 17.6 }, { -9.6, 17.9 }, { -10, 17.7 } } do
		P(
			m,
			"ThemeIngot",
			Vector3.new(0.84, 0.3, 0.44),
			f * CFrame.new(p[1], 0.3 + (if i == 3 then 0.3 else 0), p[2]),
			rgb(255, 194, 77),
			Enum.Material.Neon
		)
	end
	-- Chaînes pendues aux murs latéraux (maillons alternés)
	for _, sx in { -1, 1 } do
		for _, span in { { -16, -12 }, { 2, 6 } } do
			local n = 12
			for k = 0, n - 1 do
				local u = (k + 0.5) / n
				local z = span[1] + (span[2] - span[1]) * u
				local y = 4.5 - 1 * 4 * u * (1 - u)
				P(
					m,
					"ThemeChain",
					Vector3.new(0.12, 0.2, 0.42),
					f
						* CFrame.new(sx * (WALL_X - 1.42), y, z)
						* CFrame.Angles(if k % 2 == 0 then 0 else math.rad(90), 0, 0),
					iron,
					Enum.Material.Metal
				)
			end
		end
	end
end

-- Braseros ---------------------------------------------------------------------------------------

local function brazier(m, base: CFrame, st)
	P(m, "ThemeBrazierBase", Vector3.new(1.9, 1, 1.9), base * CFrame.new(0, 0.5, 0), st.Gate, st.GateMat)
	P(
		m,
		"ThemeBrazierBowl",
		Vector3.new(2.2, 0.9, 2.2),
		base * CFrame.new(0, 1.45, 0) * CFrame.Angles(0, math.rad(45), 0),
		rgb(46, 48, 57),
		Enum.Material.Metal
	)
	P(
		m,
		"ThemeBrazierRim",
		Vector3.new(2.5, 0.2, 2.5),
		base * CFrame.new(0, 1.95, 0) * CFrame.Angles(0, math.rad(45), 0),
		st.Trim,
		st.TrimMat
	)
	local coals = P(
		m,
		"ThemeEmbers",
		Vector3.new(1.7, 0.2, 1.7),
		base * CFrame.new(0, 1.98, 0) * CFrame.Angles(0, math.rad(45), 0),
		st.Fire[1],
		Enum.Material.Neon
	)
	P(
		m,
		"ThemeFlame",
		Vector3.new(0.7, 1.3, 0.7),
		base * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, math.rad(45), 0),
		st.Fire[2],
		Enum.Material.Neon,
		{
			Transparency = 0.2,
		}
	)
	fire(coals, st.Fire[1], st.Fire[2], 5)
end

-- Construction ---------------------------------------------------------------------------------

ArenaThemes.Ids = { "Crystal", "Ice", "Sanctuary", "Forge" }

function ArenaThemes.skyColor(themeId: string): Color3?
	local st = THEMES[themeId]
	return st and st.Sky
end

-- Habille une section. `near` : dessine aussi la porte de début de section (section 1).
function ArenaThemes.buildSection(
	themeId: string,
	frame: CFrame,
	parent: Instance,
	seed: number,
	near: boolean?
): Model?
	local st = THEMES[themeId]
	if not st then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Theme_" .. themeId
	local rand = rng(seed)
	floor(m, frame, st, rand)
	sideWalls(m, frame, st, rand)
	ends(m, frame, st, rand, near == true)
	wallBanners(m, frame, st)
	for _, sx in { -1, 1 } do
		for _, z in { -9, 7 } do
			brazier(m, frame * CFrame.new(sx * 10.4, 0, z), st)
		end
		cluster(m, frame * CFrame.new(sx * 9.6, 0, -16.6) * CFrame.Angles(0, sx * 0.6, 0), st, 0.9)
		pedestal(m, frame * CFrame.new(sx * 6.4, 0, 12), st)
	end
	st.Emblem(m, frame, st)
	st.Signature(m, frame, st, rand)
	-- Lumière d'ambiance de l'emblème
	local glow = P(
		m,
		"ThemeGlow",
		Vector3.new(0.2, 0.2, 0.2),
		frame * CFrame.new(0, 3, 0),
		st.Crystal,
		nil,
		{ Transparency = 1 }
	)
	light(glow, st.Crystal, 26, 0.9)
	m.Parent = parent
	return m
end

return ArenaThemes
