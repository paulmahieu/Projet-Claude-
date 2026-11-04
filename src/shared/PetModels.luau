--[[
	PetModels : apparence des compagnons, construite par code d'après les planches du créateur
	(30 compagnons, 6 raretés). Utilisé par le client (suiveurs) et par l'outil d'aperçu ;
	aucune logique de jeu.

	- Constructeurs paramétriques : quadrupède, oiseau, serpent, tortue, golem. Chaque espèce
	  est décrite par une fiche (SPECIES) : couleurs, oreilles, queue, motifs, collier, extras
	  (bois, cornes, crinière, ailes, cristaux...).
	- Pièces non collisionnables (les compagnons ne bloquent jamais les personnages). Toutes
	  les pièces sont soudées à la pièce principale : déplacer le compagnon = déplacer une seule
	  pièce (bon pour les performances avec plusieurs joueurs).
	- Repère : origine = centre du corps, -Z = avant (tête), +Y = haut.
]]

local PetModels = {}

local DARK = Color3.fromRGB(28, 24, 30)
local WHITE = Color3.fromRGB(250, 250, 250)
local GOLD = Color3.fromRGB(226, 178, 64)
local SILVER = Color3.fromRGB(190, 194, 206)

-- Générateur pseudo-aléatoire déterministe (même apparence partout, utilisable hors Roblox).
local function seeded(seed: number)
	local state = seed * 7919 % 2147483646 + 1
	return {
		NextNumber = function(_, a: number?, b: number?): number
			state = (state * 16807) % 2147483647
			local t = (state - 1) / 2147483646
			return (a or 0) + t * ((b or 1) - (a or 0))
		end,
	}
end

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, props)
	local p = Instance.new(if props and props.Wedge then "WedgePart" else "Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props and props.Shape then
		(p :: Part).Shape = props.Shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if props and props.Neon
		then Enum.Material.Neon
		elseif props and props.Material then props.Material
		else Enum.Material.SmoothPlastic
	if props and props.Transparency then
		p.Transparency = props.Transparency
	end
	if props and props.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = m
	return p
end

local NEON = { Neon = true }
local SILVER_T = { 190, 194, 206 }
local GOLD_T = { 226, 178, 64 }

local function ball(m, name, d: number, cf: CFrame, color: Color3, props)
	local p = table.clone(props or {})
	p.Shape = Enum.PartType.Ball
	return part(m, name, Vector3.new(d, d, d), cf, color, p)
end

-- Ellipsoïde (SpecialMesh) : corps, têtes, oreilles arrondies, plumes.
local function ell(m, name, size: Vector3, cf: CFrame, color: Color3, props)
	local p = table.clone(props or {})
	p.Mesh = true
	return part(m, name, size, cf, color, p)
end

-- Cylindre dont la BASE est en `cf`, orienté selon l'axe Y de `cf`.
local function limb(m, name, len: number, d: number, cf: CFrame, color: Color3, props)
	local p = table.clone(props or {})
	p.Shape = Enum.PartType.Cylinder
	return part(
		m,
		name,
		Vector3.new(len, d, d),
		cf * CFrame.new(0, len / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		p
	)
end

-- Losange (gemme, pointe d'oreille, écaille).
local function diamond(m, name, s: number, depth: number, cf: CFrame, color: Color3, props)
	return part(m, name, Vector3.new(s, s, depth), cf * CFrame.Angles(0, 0, math.rad(45)), color, props)
end

-- Grands yeux expressifs : iris coloré, pupille, reflet.
local function eyes(m, head: CFrame, hs: Vector3, iris: Color3, spread: number?, size: number?)
	local s = (size or 0.28) * hs.X
	for _, side in { -1, 1 } do
		local at = head * CFrame.new(side * hs.X * (spread or 0.22), hs.Y * 0.08, -hs.Z * 0.42)
		ell(m, "EyeWhite", Vector3.new(s * 1.05, s * 1.25, 0.08), at, WHITE)
		ell(m, "Iris", Vector3.new(s * 0.85, s * 1.05, 0.09), at * CFrame.new(0, -s * 0.05, -0.02), iris)
		ell(m, "Pupil", Vector3.new(s * 0.5, s * 0.65, 0.1), at * CFrame.new(0, -s * 0.05, -0.04), DARK)
		ball(m, "Shine", s * 0.28, at * CFrame.new(-side * s * 0.12, s * 0.22, -0.07), WHITE)
	end
end

-- Point sur un ellipsoïde (demi-axes rx, ry, rz) vu de son centre `c` : angle autour de Z (a)
-- et position z (fraction -1..1 de la longueur). Retourne un repère posé, -Z vers l'extérieur.
local function onBody(c: CFrame, rx: number, ry: number, rz: number, a: number, zf: number, lift: number?): CFrame
	local k = math.sqrt(math.max(0.02, 1 - zf * zf))
	local x, y, z = math.sin(a) * rx * k, math.cos(a) * ry * k, zf * rz
	local n = Vector3.new(x / (rx * rx), y / (ry * ry), z / (rz * rz)).Unit
	local p = Vector3.new(x, y, z) + n * (lift or 0)
	local up = if math.abs(n.Z) > 0.95 then Vector3.new(0, 1, 0) else Vector3.new(0, 0, -1)
	return c * CFrame.lookAt(p, p + n, up)
end

-- Anneau de petits blocs (collier, bracelet, bande de queue).
local function ring(m, name, c: CFrame, r: number, thick: number, width: number, color: Color3, props, count: number?)
	local n = count or 12
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		part(
			m,
			name,
			Vector3.new(2 * math.pi * r / n * 1.15, width, thick),
			c * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -r),
			color,
			props
		)
	end
end

-- Extras partagés -------------------------------------------------------------------------

local function collar(m, neck: CFrame, r: number, spec)
	if not spec then
		return
	end
	local color = rgb(spec.Color)
	ring(m, "Collar", neck, r, 0.08, spec.Width or 0.15, color, nil, 20)
	if spec.Scarf then
		-- Foulard : pointe nouée qui pend devant
		part(
			m,
			"ScarfKnot",
			Vector3.new(0.3, 0.42, 0.16),
			neck * CFrame.new(0.12, -0.18, -r - 0.05) * CFrame.Angles(0, 0, 0.5),
			color,
			{ Wedge = true }
		)
	end
	if spec.Gem then
		local gemCf = neck * CFrame.new(0, -0.16, -r - 0.08)
		if spec.Setting then
			diamond(m, "GemSetting", 0.3, 0.08, gemCf * CFrame.new(0, 0, 0.03), rgb(spec.Setting))
		end
		diamond(m, "Gem", 0.2, 0.1, gemCf, rgb(spec.Gem), if spec.Plain then nil else NEON)
	end
end

local function pointyEar(m, head: CFrame, side: number, size: number, color: Color3, inner: Color3?, tilt: number?)
	local base = head * CFrame.new(side * size * 0.85, size * 1.15, 0.05) * CFrame.Angles(0, 0, -side * (tilt or 0.18))
	diamond(m, "Ear", size, 0.14, base, color)
	if inner then
		diamond(m, "EarInner", size * 0.6, 0.1, base * CFrame.new(0, -size * 0.05, -0.05), inner)
	end
	return base
end

local function antlers(m, head: CFrame, spec)
	local color = rgb(spec.Color)
	for _, side in { -1, 1 } do
		local base = head * CFrame.new(side * 0.22, 0.38, 0.05)
		local cf = base * CFrame.Angles(0, 0, -side * 0.45)
		limb(m, "Antler", 0.7, 0.09, cf, color)
		local top = cf * CFrame.new(0, 0.7, 0)
		limb(m, "Antler", 0.5, 0.07, top * CFrame.Angles(0, 0, side * 0.6), color)
		limb(m, "Antler", 0.45, 0.07, top * CFrame.Angles(0, 0, -side * 0.5), color)
		limb(m, "Antler", 0.35, 0.06, cf * CFrame.new(0, 0.35, 0) * CFrame.Angles(0.5, 0, -side * 0.7), color)
		if spec.Tips then
			for _, tip in
				{
					top * CFrame.Angles(0, 0, side * 0.6) * CFrame.new(0, 0.5, 0),
					top * CFrame.Angles(0, 0, -side * 0.5) * CFrame.new(0, 0.45, 0),
				}
			do
				ball(m, "AntlerTip", 0.1, tip, rgb(spec.Tips), NEON)
			end
		end
	end
end

local function curledHorns(m, head: CFrame, spec)
	local color = rgb(spec.Color)
	for _, side in { -1, 1 } do
		for k = 0, 9 do
			local t = k / 9
			local ang = t * math.pi * 1.6
			local r = 0.32 - t * 0.12
			local at = head
				* CFrame.new(side * (0.42 + math.sin(ang) * 0.05), 0.25 + math.cos(ang) * r, 0.1 + math.sin(ang) * r)
			local d = 0.26 - t * 0.12
			ball(
				m,
				"Horn",
				d,
				at,
				if spec.Bands and k % 3 == 1 then rgb(spec.Bands) else color,
				if spec.Bands and k % 3 == 1 then NEON else nil
			)
		end
	end
end

local function dragonHorns(m, head: CFrame, spec, hy: number?)
	local color = rgb(spec.Color)
	for _, side in { -1, 1 } do
		local cf = head * CFrame.new(side * 0.22, (hy or 0.8) * 0.38, 0.12) * CFrame.Angles(0.6, 0, -side * 0.35)
		for _, w in { 0.16, 0.13, 0.1, 0.07 } do
			part(m, "Horn", Vector3.new(w, 0.2, w), cf * CFrame.new(0, 0.1, 0), color)
			cf = cf * CFrame.new(0, 0.18, 0) * CFrame.Angles(0.25, 0, 0)
		end
	end
end

local function featherWings(m, at: CFrame, spec, span: number)
	local base, tip = rgb(spec.Color), rgb(spec.Tip or spec.Color)
	for _, side in { -1, 1 } do
		local root = at
			* CFrame.new(side * 0.35, 0.15, 0.1)
			* CFrame.Angles(0, side * 0.2, side * (spec.Spread or 0.55))
		for k = 0, 4 do
			local len = span * (0.55 + k * 0.12)
			local f = root * CFrame.Angles(0, 0, -side * k * 0.16) * CFrame.new(side * len * 0.45, 0, 0.05 * k)
			ell(m, "Feather", Vector3.new(len, 0.28, 0.12), f, base:Lerp(tip, k / 4))
		end
	end
end

local function batWings(m, at: CFrame, spec, span: number)
	local bone, skin = rgb(spec.Bone or spec.Color), rgb(spec.Color)
	for _, side in { -1, 1 } do
		local root = at * CFrame.new(side * 0.3, 0.25, 0.05) * CFrame.Angles(0, 0, side * 0.45)
		part(m, "WingArm", Vector3.new(span, 0.1, 0.1), root * CFrame.new(side * span / 2, 0, 0), bone)
		ball(m, "WingClaw", 0.14, root * CFrame.new(side * span, 0, 0), bone)
		-- Membranes en éventail, de l'aile vers l'arrière du corps
		for k = 0, 2 do
			local len = span * (1 - k * 0.18)
			local fan = root * CFrame.Angles(0, -side * (0.35 + k * 0.4), 0)
			ell(
				m,
				"WingSkin",
				Vector3.new(len, 0.05, 0.42),
				fan * CFrame.new(side * len * 0.48, -0.02, 0),
				skin:Lerp(DARK, k * 0.08)
			)
			part(m, "WingBone", Vector3.new(len, 0.06, 0.06), fan * CFrame.new(side * len * 0.5, 0.02, -0.2), bone)
		end
	end
end

local function crystals(m, list, color: Color3)
	for _, c in list do
		part(
			m,
			"Crystal",
			Vector3.new(0.14, c[2], 0.14),
			c[1] * CFrame.new(0, c[2] / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
			color,
			NEON
		)
		diamond(
			m,
			"CrystalTip",
			0.1,
			0.1,
			c[1] * CFrame.new(0, c[2], 0) * CFrame.Angles(0, math.rad(45), 0),
			color,
			NEON
		)
	end
end

-- Quadrupède ---------------------------------------------------------------------------------

local function quadruped(m: Model, s)
	local c = rgb(s.Color)
	local w, h, l = s.Size[1], s.Size[2], s.Size[3]
	local o = CFrame.new()
	local body = ell(m, "Body", Vector3.new(w, h, l), o, c)
	local belly = rgb(s.Belly or s.Color)
	ell(m, "Chest", Vector3.new(w * 0.72, h * 0.78, l * 0.4), o * CFrame.new(0, -h * 0.06, -l * 0.33), belly)
	local legColor = rgb(s.Legs or s.Color)
	local legLen = s.LegLen or 0.6
	local legD = s.LegD or w * 0.26
	for _, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local at = o * CFrame.new(p[1] * w * 0.28, -h * 0.3 - legLen, p[2] * l * 0.3)
		limb(m, "Leg", legLen + h * 0.15, legD, at, legColor)
		local paw = rgb(s.Paw or s.Legs or s.Color)
		if s.Hooves then
			limb(m, "Hoof", 0.14, legD * 1.05, at, rgb(s.Hooves))
		else
			ell(
				m,
				"Paw",
				Vector3.new(legD * 1.25, legD * 0.7, legD * 1.45),
				at * CFrame.new(0, legD * 0.25, -legD * 0.2),
				paw
			)
		end
		if s.Cuffs then
			limb(
				m,
				"Cuff",
				0.12,
				legD * 1.2,
				at * CFrame.new(0, 0.2, 0),
				rgb(s.Cuffs),
				{ Material = Enum.Material.Metal }
			)
		end
	end

	-- Cou et tête
	local neckUp = s.Neck or 0
	local hs = s.Head and Vector3.new(s.Head[1], s.Head[2], s.Head[3]) or Vector3.new(w * 0.95, w * 0.85, w * 0.85)
	local headAt = o * CFrame.new(0, h * 0.42 + neckUp, -l * 0.46 - neckUp * 0.25)
	if neckUp > 0 then
		ell(
			m,
			"Neck",
			Vector3.new(w * 0.5, neckUp + h * 0.5, w * 0.55),
			o * CFrame.new(0, h * 0.25 + neckUp * 0.5, -l * 0.4) * CFrame.Angles(-0.25, 0, 0),
			c
		)
	end
	local heads = s.Heads or { 0 }
	for _, angle in heads do
		local head = headAt
		if angle ~= 0 then
			-- Têtes latérales (hydre) : écartées sur leur propre cou, tournées vers l'extérieur
			local side = math.sign(angle)
			head = headAt * CFrame.new(side * w * 0.55, -0.1, l * 0.08) * CFrame.Angles(0, -angle * 0.6, 0)
			ell(
				m,
				"Neck",
				Vector3.new(w * 0.32, h * 0.7, w * 0.36),
				o * CFrame.new(side * w * 0.38, h * 0.38, -l * 0.33) * CFrame.Angles(-0.3, 0, -side * 0.5),
				c
			)
		elseif #heads > 1 then
			head = headAt * CFrame.new(0, 0.25, 0)
			ell(
				m,
				"Neck",
				Vector3.new(w * 0.34, h * 0.8, w * 0.38),
				o * CFrame.new(0, h * 0.5, -l * 0.38) * CFrame.Angles(-0.3, 0, 0),
				c
			)
		end
		ell(m, "Head", hs, head, rgb(s.HeadColor or s.Color))
		if s.Face then
			ell(
				m,
				"Face",
				Vector3.new(hs.X * 0.72, hs.Y * 0.6, hs.Z * 0.5),
				head * CFrame.new(0, -hs.Y * 0.12, -hs.Z * 0.28),
				rgb(s.Face)
			)
		end
		if s.Mask then
			for _, side in { -1, 1 } do
				ell(
					m,
					"Mask",
					Vector3.new(hs.X * 0.36, hs.Y * 0.26, 0.08),
					head * CFrame.new(side * hs.X * 0.22, hs.Y * 0.06, -hs.Z * 0.43) * CFrame.Angles(0, 0, side * 0.25),
					rgb(s.Mask)
				)
			end
		end
		local snout = s.Snout or 0.3
		local muzzle = ell(
			m,
			"Muzzle",
			Vector3.new(hs.X * 0.5, hs.Y * 0.42, snout + hs.Z * 0.2),
			head * CFrame.new(0, -hs.Y * 0.2, -hs.Z * 0.45 - snout * 0.3),
			rgb(s.Muzzle or s.Belly or s.Color)
		)
		if s.PigNose then
			limb(
				m,
				"Snout",
				0.18,
				hs.X * 0.38,
				head * CFrame.new(0, -hs.Y * 0.12, -hs.Z * 0.5) * CFrame.Angles(math.rad(-90), 0, 0),
				rgb(s.PigNose)
			)
			for _, side in { -1, 1 } do
				ball(m, "Nostril", 0.07, head * CFrame.new(side * 0.07, -hs.Y * 0.12, -hs.Z * 0.5 - 0.19), DARK)
			end
		else
			ball(
				m,
				"Nose",
				hs.X * 0.16,
				muzzle.CFrame * CFrame.new(0, hs.Y * 0.1, -(snout + hs.Z * 0.2) * 0.48),
				rgb(s.Nose or { 40, 30, 32 })
			)
		end
		if s.Tongue then
			ell(
				m,
				"Tongue",
				Vector3.new(0.14, 0.05, 0.2),
				muzzle.CFrame * CFrame.new(0, -hs.Y * 0.18, -snout * 0.3),
				Color3.fromRGB(230, 110, 120)
			)
		end
		eyes(m, head, hs, rgb(s.Eye or { 70, 45, 30 }), s.EyeSpread, s.EyeSize)
		if s.Glow then
			for _, side in { -1, 1 } do
				ell(
					m,
					"EyeGlow",
					Vector3.new(hs.X * 0.2, hs.Y * 0.16, 0.06),
					head * CFrame.new(side * hs.X * 0.22, hs.Y * 0.1, -hs.Z * 0.48),
					rgb(s.Glow),
					NEON
				)
			end
		end
		-- Oreilles
		local ears = s.Ears or "Pointy"
		local earColor = rgb(s.EarColor or s.Color)
		local inner = s.EarInner and rgb(s.EarInner)
		for _, side in { -1, 1 } do
			if ears == "Pointy" or ears == "Tufted" then
				local e = pointyEar(m, head, side, hs.X * (s.EarSize or 0.38), earColor, inner)
				if ears == "Tufted" then
					part(m, "EarTuft", Vector3.new(0.05, 0.3, 0.05), e * CFrame.new(0, hs.X * 0.3, 0), DARK)
				end
			elseif ears == "Long" then
				local e = head
					* CFrame.new(side * hs.X * 0.2, hs.Y * 0.5, 0.05)
					* CFrame.Angles(0, 0, -side * 0.15)
					* CFrame.new(0, 0.45, 0)
				ell(m, "Ear", Vector3.new(0.28, 1.0, 0.12), e, earColor)
				if inner then
					ell(m, "EarInner", Vector3.new(0.16, 0.8, 0.1), e * CFrame.new(0, 0, -0.03), inner)
				end
			elseif ears == "Floppy" then
				ell(
					m,
					"Ear",
					Vector3.new(0.18, 0.6, 0.36),
					head * CFrame.new(side * hs.X * 0.5, -hs.Y * 0.05, 0.05) * CFrame.Angles(0, 0, side * 0.25),
					earColor
				)
			elseif ears == "Round" then
				ball(m, "Ear", hs.X * 0.32, head * CFrame.new(side * hs.X * 0.36, hs.Y * 0.42, 0.05), earColor)
				if inner then
					ball(m, "EarInner", hs.X * 0.18, head * CFrame.new(side * hs.X * 0.36, hs.Y * 0.42, -0.06), inner)
				end
			elseif ears == "Wide" then
				local e = head * CFrame.new(side * hs.X * 0.62, hs.Y * 0.3, 0.05) * CFrame.Angles(0, 0, -side * 0.5)
				ell(m, "Ear", Vector3.new(0.6, 0.3, 0.1), e, earColor)
				if inner then
					ell(m, "EarInner", Vector3.new(0.42, 0.18, 0.08), e * CFrame.new(0, 0, -0.03), inner)
				end
			elseif ears == "Pig" then
				diamond(
					m,
					"Ear",
					hs.X * 0.32,
					0.1,
					head * CFrame.new(side * hs.X * 0.32, hs.Y * 0.42, -0.05) * CFrame.Angles(-0.6, 0, side * 0.3),
					earColor
				)
			end
		end
		if s.Mane then
			local mane = rgb(s.Mane)
			local mane2 = rgb(s.Mane2 or s.Mane)
			for k = 0, 13 do
				local a = k / 14 * math.pi * 2
				ell(
					m,
					"Mane",
					Vector3.new(0.32, 0.6, 0.2),
					head
						* CFrame.new(math.sin(a) * hs.X * 0.55, math.cos(a) * hs.Y * 0.55, 0.12)
						* CFrame.Angles(0, 0, -a),
					if k % 2 == 0 then mane else mane2
				)
			end
		end
		if s.Crest then
			for k = 0, 4 do
				diamond(
					m,
					"Crest",
					0.22 - k * 0.02,
					0.08,
					head * CFrame.new(0, hs.Y * 0.45 - k * 0.05, 0.05 + k * 0.12),
					rgb(s.Crest),
					{ Material = Enum.Material.Metal }
				)
			end
		end
		if s.Antlers then
			antlers(m, head, s.Antlers)
		end
		if s.RamHorns then
			curledHorns(m, head, s.RamHorns)
		end
		if s.DragonHorns then
			dragonHorns(m, head, s.DragonHorns, hs.Y)
		end
		if s.UnicornHorn then
			for k = 0, 4 do
				limb(
					m,
					"Horn",
					0.16,
					0.14 - k * 0.025,
					head * CFrame.new(0, hs.Y * 0.45 + k * 0.15, -hs.Z * 0.15) * CFrame.Angles(-0.3, 0, 0),
					rgb(s.UnicornHorn),
					{ Material = Enum.Material.Metal }
				)
			end
		end
		if s.Forehead then
			diamond(m, "Forehead", 0.16, 0.06, head * CFrame.new(0, hs.Y * 0.32, -hs.Z * 0.42), rgb(s.Forehead), NEON)
		end
	end

	-- Crinière d'encolure (licorne, qilin)
	if s.NeckMane then
		local mane = rgb(s.NeckMane)
		for k = 0, 6 do
			ell(
				m,
				"NeckMane",
				Vector3.new(0.3, 0.55, 0.42),
				o
					* CFrame.new(0, h * 0.42 + neckUp * (1 - k / 7), -l * 0.3 + k * 0.1)
					* CFrame.Angles(0.5, 0, (k % 2 - 0.5) * 0.5),
				mane:Lerp(WHITE, k % 2 * 0.15)
			)
		end
	end

	-- Motifs
	local pattern = s.Pattern
	if pattern then
		local pc = rgb(pattern.Color)
		local rand = seeded(pattern.Seed or 7)
		if pattern.Type == "Stripes" then
			for k = 0, (pattern.Count or 5) - 1 do
				local zf = -0.55 + k * 1.2 / (pattern.Count or 5)
				for _, a in { -0.9, -0.45, 0, 0.45, 0.9 } do
					part(
						m,
						"Stripe",
						Vector3.new(0.12, 0.3, 0.05),
						onBody(o, w / 2, h / 2, l / 2, a, zf, 0) * CFrame.Angles(0, 0, a * 0.3),
						pc
					)
				end
			end
		elseif pattern.Type == "Spots" or pattern.Type == "Patches" then
			local n = pattern.Count or (if pattern.Type == "Spots" then 14 else 4)
			for _ = 1, n do
				local size = if pattern.Type == "Spots"
					then 0.16 + rand:NextNumber() * 0.1
					else 0.45 + rand:NextNumber() * 0.25
				ell(
					m,
					"Spot",
					Vector3.new(size, size * 0.85, 0.06),
					onBody(o, w / 2, h / 2, l / 2, rand:NextNumber(-1.6, 1.6), rand:NextNumber(-0.7, 0.7), -0.01),
					pc,
					if pattern.Neon then NEON else nil
				)
			end
		elseif pattern.Type == "Runes" or pattern.Type == "Marks" then
			for _, side in { -1, 1 } do
				for k = 0, 2 do
					local cf = onBody(o, w / 2, h / 2, l / 2, side * 1.35, -0.4 + k * 0.4, 0)
					part(m, "Rune", Vector3.new(0.35, 0.06, 0.04), cf * CFrame.Angles(0, 0, 0.6), pc, NEON)
					part(m, "Rune", Vector3.new(0.06, 0.25, 0.04), cf * CFrame.new(0.15, 0.1, 0), pc, NEON)
				end
			end
		elseif pattern.Type == "Suns" then
			for _, side in { -1, 1 } do
				local cf = onBody(o, w / 2, h / 2, l / 2, side * 1.4, 0.15, 0)
				part(
					m,
					"Sun",
					Vector3.new(0.05, 0.36, 0.36),
					cf * CFrame.Angles(0, math.rad(90), 0),
					pc,
					{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal }
				)
				for k = 0, 7 do
					diamond(
						m,
						"SunRay",
						0.1,
						0.04,
						cf * CFrame.Angles(0, 0, k * math.pi / 4) * CFrame.new(0, 0.26, 0),
						pc,
						{ Material = Enum.Material.Metal }
					)
				end
			end
		end
	end

	-- Extras du corps
	if s.Quills then
		local qc = rgb(s.Quills)
		local rand = seeded(31)
		for row = 0, 6 do
			for k = 0, 7 do
				local a = -1.9 + k * 3.8 / 7 + (row % 2) * 0.2
				local zf = -0.75 + row * 0.25
				local cf = onBody(o, w / 2, h / 2, l / 2, a, zf, 0.05) * CFrame.Angles(math.rad(-80), 0, 0)
				part(
					m,
					"Quill",
					Vector3.new(0.22, 0.42, 0.22),
					cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, math.rad(45), 0),
					qc:Lerp(DARK, rand:NextNumber() * 0.25)
				)
			end
		end
		for _ = 1, 6 do
			ball(
				m,
				"Moss",
				0.28,
				onBody(o, w / 2, h / 2, l / 2, rand:NextNumber(-1.5, 1.5), rand:NextNumber(-0.6, 0.7), 0.25),
				Color3.fromRGB(120, 160, 60)
			)
		end
	end
	if s.Scales then
		local sc = rgb(s.Scales)
		for row = 0, 5 do
			for k = 0, 6 do
				local a = -1.5 + k * 0.5
				diamond(
					m,
					"Scale",
					0.26,
					0.05,
					onBody(o, w / 2, h / 2, l / 2, a, -0.7 + row * 0.28, -0.01),
					sc:Lerp(DARK, (row + k) % 2 * 0.15)
				)
			end
		end
	end
	if s.Spines then
		local list = {}
		for k = 0, (s.Spines.Count or 5) - 1 do
			local zf = -0.6 + k * 1.2 / ((s.Spines.Count or 5) - 1)
			table.insert(list, {
				onBody(o, w / 2, h / 2, l / 2, 0, zf, -0.05) * CFrame.Angles(math.rad(-90), 0, 0),
				0.32 - math.abs(zf) * 0.15,
			})
		end
		if s.Spines.Crystal then
			crystals(m, list, rgb(s.Spines.Color))
		else
			for _, sp in list do
				part(
					m,
					"Spine",
					Vector3.new(0.18, sp[2], 0.18),
					sp[1] * CFrame.new(0, sp[2] / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
					rgb(s.Spines.Color)
				)
			end
		end
	end
	if s.Shoulders then
		for _, side in { -1, 1 } do
			ell(
				m,
				"Pauldron",
				Vector3.new(0.42, 0.4, 0.55),
				o * CFrame.new(side * w * 0.45, h * 0.2, -l * 0.25),
				rgb(s.Shoulders),
				{ Material = Enum.Material.Metal }
			)
			diamond(
				m,
				"PauldronStud",
				0.12,
				0.06,
				o * CFrame.new(side * (w * 0.45 + 0.21), h * 0.2, -l * 0.25) * CFrame.Angles(0, side * math.rad(90), 0),
				SILVER:Lerp(DARK, 0.3),
				{ Material = Enum.Material.Metal }
			)
		end
	end
	if s.Harness then
		ring(
			m,
			"Harness",
			o * CFrame.new(0, 0, -l * 0.1) * CFrame.Angles(math.rad(90), 0, 0),
			(w + h) / 4 + 0.02,
			0.08,
			0.14,
			rgb(s.Harness),
			{ Material = Enum.Material.Metal },
			16
		)
	end
	if s.Wings then
		local at = o * CFrame.new(0, h * 0.3, -l * 0.1)
		if s.Wings.Bat then
			batWings(m, at, s.Wings, s.Wings.Span or 1.2)
		else
			featherWings(m, at, s.Wings, s.Wings.Span or 1.1)
		end
	end
	if s.Fluff then
		for k = 0, 4 do
			ell(
				m,
				"Fluff",
				Vector3.new(0.34, 0.3, 0.2),
				o * CFrame.new((k - 2) * 0.13, h * 0.05 - math.abs(k - 2) * 0.06, -l * 0.5) * CFrame.Angles(0.3, 0, 0),
				rgb(s.Fluff)
			)
		end
	end

	-- Queue
	local tail = s.Tail
	if tail then
		local tc, tip = rgb(tail.Color or s.Color), rgb(tail.Tip or tail.Color or s.Color)
		local start = o * CFrame.new(0, h * 0.15, l * 0.46)
		if tail.Type == "Bushy" or tail.Type == "Flow" then
			local cf = start * CFrame.Angles(math.rad(tail.Lift or 50), 0, 0)
			for k = 0, 3 do
				local t = k / 3
				local size = (tail.Size or 0.5) * (0.7 + math.sin(t * math.pi) * 0.5)
				ell(
					m,
					"Tail",
					Vector3.new(size, size * 1.4, size),
					cf * CFrame.new(0, 0.25 + k * 0.28, 0.05 * k),
					if k == 3 then tip else tc
				)
			end
		elseif tail.Type == "Ringed" then
			local cf = start * CFrame.Angles(math.rad(35), 0, 0)
			for k = 0, 5 do
				ell(
					m,
					"Tail",
					Vector3.new(0.42, 0.34, 0.42),
					cf * CFrame.new(0, 0.18 + k * 0.22, 0),
					if k % 2 == 0 then tc else tip
				)
			end
		elseif tail.Type == "Curl" then
			for k = 0, 7 do
				local a = k / 7 * math.pi * 1.1
				ell(
					m,
					"Tail",
					Vector3.new(0.18, 0.24, 0.18),
					start * CFrame.new(0, math.sin(a) * 0.55, 0.15 + (1 - math.cos(a)) * 0.35),
					if k == 7 then tip elseif tail.Stripes and k % 2 == 1 then rgb(tail.Stripes) else tc
				)
			end
		elseif tail.Type == "Puff" then
			ball(m, "Tail", tail.Size or 0.4, start * CFrame.new(0, 0.05, 0.08), tip)
		elseif tail.Type == "Pig" then
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				ball(
					m,
					"Tail",
					0.09,
					start * CFrame.new(math.cos(a) * 0.1, 0.05 + math.sin(a) * 0.1, 0.1 + k * 0.01),
					tc
				)
			end
		elseif tail.Type == "Tuft" then
			local cf = start * CFrame.Angles(math.rad(-30), 0, 0)
			limb(m, "Tail", 0.75, 0.1, cf * CFrame.Angles(math.rad(80), 0, 0), tc)
			ell(
				m,
				"TailTuft",
				Vector3.new(0.3, 0.42, 0.3),
				cf * CFrame.Angles(math.rad(80), 0, 0) * CFrame.new(0, 0.8, 0),
				tip
			)
		elseif tail.Type == "Lizard" or tail.Type == "Dragon" then
			local cf = start * CFrame.new(0, -h * 0.15, 0)
			for k = 0, 5 do
				local d = 0.42 - k * 0.06
				ell(
					m,
					"Tail",
					Vector3.new(d, d * 0.8, 0.4),
					cf * CFrame.new(math.sin(k * 0.6) * 0.08 * k, -k * 0.03, 0.15 + k * 0.28),
					tc
				)
			end
			if tail.Type == "Dragon" then
				diamond(
					m,
					"TailTip",
					0.34,
					0.08,
					cf * CFrame.new(0.3, -0.15, 1.9) * CFrame.Angles(math.rad(90), 0, 0),
					tip,
					{ Material = Enum.Material.Metal }
				)
			end
		elseif tail.Type == "Nine" then
			for k = 0, 8 do
				local a = (k - 4) * 0.33
				local cf = start * CFrame.Angles(0, 0, a) * CFrame.Angles(math.rad(25), 0, 0)
				for j = 0, 2 do
					ell(
						m,
						"Tail",
						Vector3.new(0.34 + j * 0.06, 0.55, 0.28),
						cf * CFrame.new(0, 0.3 + j * 0.42, 0),
						if j == 2 then tip elseif j == 1 and tail.Mid then rgb(tail.Mid) else tc
					)
				end
			end
		elseif tail.Type == "Short" then
			ell(m, "Tail", Vector3.new(0.25, 0.4, 0.2), start * CFrame.new(0, 0.2, 0.05) * CFrame.Angles(0.5, 0, 0), tc)
		end
	end

	if s.Collar then
		collar(m, headAt * CFrame.new(0, -hs.Y * 0.55, hs.Z * 0.15), w * 0.33, s.Collar)
	end
	return body
end

-- Oiseau -------------------------------------------------------------------------------------

local function bird(m: Model, s)
	local c = rgb(s.Color)
	local o = CFrame.new()
	local sz = s.Size or { 1.2, 1.4, 1.1 }
	local body = ell(m, "Body", Vector3.new(sz[1], sz[2], sz[3]), o, c)
	ell(
		m,
		"Chest",
		Vector3.new(sz[1] * 0.75, sz[2] * 0.7, sz[3] * 0.4),
		o * CFrame.new(0, -0.05, -sz[3] * 0.33),
		rgb(s.Chest or s.Color)
	)
	if s.ChestFeathers then
		for k = 0, 8 do
			local x = ((k % 3) - 1) * 0.22
			local y = 0.15 - math.floor(k / 3) * 0.22
			diamond(m, "ChestFeather", 0.22, 0.05, o * CFrame.new(x, y, -sz[3] * 0.5), rgb(s.ChestFeathers))
		end
	end
	local hd = s.HeadSize or 0.9
	local head = o * CFrame.new(0, sz[2] * 0.48, -sz[3] * 0.18)
	local hs = Vector3.new(hd, hd * 0.95, hd * 0.9)
	ell(m, "Head", hs, head, rgb(s.HeadColor or s.Color))
	if s.Face then
		ell(m, "Face", Vector3.new(hd * 0.8, hd * 0.65, 0.3), head * CFrame.new(0, -0.02, -hd * 0.32), rgb(s.Face))
	end
	eyes(m, head, hs, rgb(s.Eye or { 240, 170, 40 }), 0.24, s.EyeSize or 0.3)
	-- Bec
	local beak = rgb(s.Beak or { 240, 180, 60 })
	if s.BeakType == "Hook" then
		part(m, "Beak", Vector3.new(0.22, 0.2, 0.32), head * CFrame.new(0, -0.08, -hd * 0.5), beak)
		part(
			m,
			"BeakHook",
			Vector3.new(0.16, 0.14, 0.14),
			head * CFrame.new(0, -0.18, -hd * 0.5 - 0.14) * CFrame.Angles(0.6, 0, 0),
			beak
		)
	elseif s.BeakType == "Long" then
		part(
			m,
			"Beak",
			Vector3.new(0.16, 0.16, 0.45),
			head * CFrame.new(0, -0.08, -hd * 0.55) * CFrame.Angles(-0.15, 0, 0),
			beak
		)
	else
		diamond(m, "Beak", 0.2, 0.25, head * CFrame.new(0, -0.1, -hd * 0.48), beak)
	end
	if s.Comb then
		for k = 0, 2 do
			ball(m, "Comb", 0.22, head * CFrame.new(0, hd * 0.45 + (k % 2) * 0.05, -0.15 + k * 0.15), rgb(s.Comb))
		end
		ell(m, "Wattle", Vector3.new(0.12, 0.25, 0.1), head * CFrame.new(0, -0.32, -hd * 0.4), rgb(s.Comb))
	end
	if s.Tufts then
		for _, side in { -1, 1 } do
			ell(
				m,
				"Tuft",
				Vector3.new(0.18, 0.45, 0.12),
				head * CFrame.new(side * hd * 0.32, hd * 0.48, 0) * CFrame.Angles(0, 0, -side * 0.4),
				rgb(s.Tufts)
			)
		end
	end
	if s.FlameCrest then
		for k = 0, 4 do
			local a = (k - 2) * 0.35
			ell(
				m,
				"Crest",
				Vector3.new(0.16, 0.6 - math.abs(k - 2) * 0.1, 0.12),
				head * CFrame.new(math.sin(a) * 0.2, hd * 0.55, 0.05) * CFrame.Angles(-0.3, 0, -a),
				rgb(s.FlameCrest):Lerp(rgb(s.FlameCrest2 or s.FlameCrest), math.abs(k - 2) / 2)
			)
		end
	end
	if s.Moon then
		for k = 0, 6 do
			local a = math.rad(200 + k * 25)
			part(
				m,
				"Moon",
				Vector3.new(0.08, 0.1, 0.08),
				head * CFrame.new(math.cos(a) * 0.15, hd * 0.42 + math.sin(a) * 0.15, -hd * 0.35),
				SILVER,
				{ Material = Enum.Material.Metal }
			)
		end
	end
	if s.Crown then
		for k = 0, 4 do
			diamond(
				m,
				"CrownSpike",
				0.14,
				0.06,
				head * CFrame.new((k - 2) * 0.12, hd * 0.5, -0.1 + math.abs(k - 2) * 0.05),
				rgb(s.Crown),
				{ Material = Enum.Material.Metal }
			)
		end
		diamond(
			m,
			"CrownGem",
			0.1,
			0.08,
			head * CFrame.new(0, hd * 0.42, -hd * 0.42),
			Color3.fromRGB(230, 40, 50),
			NEON
		)
	end
	-- Ailes (plumes étagées de la base vers la pointe)
	local wc, wt = rgb(s.Wing or s.Color), rgb(s.WingTip or s.Wing or s.Color)
	for _, side in { -1, 1 } do
		for k = 0, 3 do
			local len = (s.WingLen or 1.0) * (0.6 + k * 0.14)
			ell(
				m,
				"Wing",
				Vector3.new(0.18, 0.4, len),
				o
					* CFrame.new(side * (sz[1] * 0.45 + k * 0.03), 0.15 - k * 0.12, 0.1 + k * 0.08)
					* CFrame.Angles(math.rad(25 + k * 5), side * 0.15, 0),
				wc:Lerp(wt, k / 3)
			)
		end
	end
	if s.SpreadWings then
		featherWings(
			m,
			o * CFrame.new(0, sz[2] * 0.2, 0.05),
			{ Color = s.Wing or s.Color, Tip = s.WingTip, Spread = 0.9 },
			s.SpreadWings
		)
	end
	-- Queue
	local tc, tt = rgb(s.TailColor or s.Wing or s.Color), rgb(s.TailTip or s.TailColor or s.Wing or s.Color)
	local count = s.TailCount or 5
	for k = 0, count - 1 do
		local a = (k - (count - 1) / 2) * 0.22
		local len = (s.TailLen or 0.8) * (1 - math.abs(k - (count - 1) / 2) * 0.08)
		ell(
			m,
			"TailFeather",
			Vector3.new(0.22, 0.12, len),
			o
				* CFrame.new(math.sin(a) * 0.3, -sz[2] * 0.25, sz[3] * 0.45 + len * 0.4)
				* CFrame.Angles(math.rad(s.TailLift or 20), a, 0),
			tc:Lerp(tt, math.abs(k - (count - 1) / 2) / math.max(1, (count - 1) / 2))
		)
	end
	-- Pattes
	local legC = rgb(s.Legs or { 230, 170, 60 })
	for _, side in { -1, 1 } do
		local at = o * CFrame.new(side * 0.25, -sz[2] * 0.42 - 0.35, 0)
		limb(m, "Leg", 0.4, 0.12, at, legC)
		for k = -1, 1 do
			part(
				m,
				"Toe",
				Vector3.new(0.06, 0.06, 0.22),
				at * CFrame.new(k * 0.08, 0.03, -0.08) * CFrame.Angles(0, k * 0.4, 0),
				legC
			)
		end
	end
	if s.Collar then
		collar(m, head * CFrame.new(0, -hd * 0.45, 0.05), hd * 0.42, s.Collar)
	end
	return body
end

-- Serpent enroulé ------------------------------------------------------------------------------

local function serpent(m: Model, s)
	local c, belly = rgb(s.Color), rgb(s.Belly or s.Color)
	local o = CFrame.new(0, -0.35, 0)
	local body
	for coil = 0, 1 do
		local r = 0.75 - coil * 0.2
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			local p =
				ball(m, "Coil", 0.5 - coil * 0.06, o * CFrame.new(math.cos(a) * r, coil * 0.4, math.sin(a) * r), c)
			body = body or p
			if s.Stars and k % 4 == coil * 2 then
				diamond(
					m,
					"Star",
					0.14,
					0.05,
					o
						* CFrame.new(math.cos(a) * (r + 0.24), coil * 0.4 + 0.08, math.sin(a) * (r + 0.24))
						* CFrame.Angles(0, -a + math.pi / 2, 0),
					rgb(s.Stars),
					{ Material = Enum.Material.Metal }
				)
			end
		end
	end
	-- Cou dressé en S, tête
	local neck = {}
	for k = 0, 6 do
		local t = k / 6
		local at = o * CFrame.new(0, 0.6 + t * 1.2, -0.3 - math.sin(t * math.pi) * 0.35)
		ball(m, "Neck", 0.42 - t * 0.06, at, c)
		ell(m, "NeckBelly", Vector3.new(0.24, 0.3, 0.1), at * CFrame.new(0, 0, -0.18), belly)
		table.insert(neck, at.Position)
	end
	local head = o * CFrame.new(0, 2.0, -0.25)
	local hs = Vector3.new(0.6, 0.45, 0.7)
	ell(m, "Head", hs, head, c)
	eyes(m, head, hs, rgb(s.Eye or { 90, 230, 255 }), 0.3, 0.3)
	if s.Glow then
		for _, side in { -1, 1 } do
			ell(
				m,
				"EyeGlow",
				Vector3.new(0.12, 0.08, 0.05),
				head * CFrame.new(side * 0.15, 0.06, -0.33),
				rgb(s.Glow),
				NEON
			)
		end
	end
	if s.Horns then
		dragonHorns(m, head, { Color = s.Horns }, hs.Y)
	end
	if s.Stars then
		for k = 1, #neck - 1 do
			ball(m, "StarDot", 0.07, CFrame.new(neck[k]) * CFrame.new(0.2, 0, 0), rgb(s.Stars), NEON)
		end
	end
	return body
end

-- Tortue -----------------------------------------------------------------------------------------

local function turtle(m: Model, s)
	local skin, shell = rgb(s.Color), rgb(s.Shell)
	local o = CFrame.new()
	local body = ell(m, "Shell", Vector3.new(1.9, 1.3, 2.1), o * CFrame.new(0, 0.1, 0), shell)
	ell(m, "Plastron", Vector3.new(1.7, 0.4, 1.9), o * CFrame.new(0, -0.35, 0), rgb(s.Belly or s.Color))
	local trim = rgb(s.Trim or { 226, 178, 64 })
	ring(m, "ShellRim", o * CFrame.new(0, -0.15, 0), 0.98, 0.1, 0.18, trim, { Material = Enum.Material.Metal }, 18)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		part(
			m,
			"ShellLine",
			Vector3.new(0.06, 0.06, 0.9),
			o
				* CFrame.new(math.cos(a) * 0.45, 0.55, math.sin(a) * 0.45)
				* CFrame.Angles(0, -a + math.pi / 2, 0)
				* CFrame.Angles(0.5, 0, 0),
			trim,
			{ Material = Enum.Material.Metal }
		)
	end
	diamond(
		m,
		"ShellStar",
		0.3,
		0.06,
		o * CFrame.new(0, 0.62, 0.6) * CFrame.Angles(math.rad(-60), 0, 0),
		trim,
		{ Material = Enum.Material.Metal }
	)
	if s.Crystal then
		crystals(m, { { o * CFrame.new(0, 0.7, 0), 0.55 } }, rgb(s.Crystal))
	end
	local rand = seeded(11)
	for _ = 1, 8 do
		ball(
			m,
			"ShellStarDot",
			0.06,
			o * CFrame.new(rand:NextNumber(-0.6, 0.6), 0.5 + rand:NextNumber(0, 0.15), rand:NextNumber(-0.6, 0.6)),
			WHITE,
			NEON
		)
	end
	local head = o * CFrame.new(0, 0.05, -1.25)
	local hs = Vector3.new(0.7, 0.62, 0.7)
	ell(m, "Head", hs, head, skin)
	eyes(m, head, hs, rgb(s.Eye or { 90, 230, 255 }), 0.24, 0.32)
	part(
		m,
		"Brow",
		Vector3.new(0.5, 0.08, 0.1),
		head * CFrame.new(0, 0.22, -0.3),
		trim,
		{ Material = Enum.Material.Metal }
	)
	for _, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local at = o * CFrame.new(p[1] * 0.75, -0.85, p[2] * 0.7)
		limb(m, "Leg", 0.55, 0.42, at, skin)
		part(
			m,
			"LegMark",
			Vector3.new(0.05, 0.18, 0.18),
			at * CFrame.new(p[1] * 0.21, 0.3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			trim,
			{ Material = Enum.Material.Metal }
		)
	end
	part(m, "Tail", Vector3.new(0.2, 0.15, 0.4), o * CFrame.new(0, -0.3, 1.15), skin, { Wedge = true })
	return body
end

-- Golem (Gardien solaire) --------------------------------------------------------------------

local function golem(m: Model, s)
	local c = rgb(s.Color)
	local o = CFrame.new()
	local body = part(m, "Body", Vector3.new(1.5, 1.4, 1.1), o, c, { Material = Enum.Material.Slate })
	part(
		m,
		"Head",
		Vector3.new(0.9, 0.8, 0.8),
		o * CFrame.new(0, 1.05, 0),
		c:Lerp(WHITE, 0.15),
		{ Material = Enum.Material.Slate }
	)
	part(m, "Visor", Vector3.new(0.6, 0.15, 0.05), o * CFrame.new(0, 1.1, -0.41), rgb(s.Glow), NEON)
	for _, side in { -1, 1 } do
		part(
			m,
			"Arm",
			Vector3.new(0.45, 1.2, 0.45),
			o * CFrame.new(side * 1, -0.2, 0),
			c:Lerp(DARK, 0.2),
			{ Material = Enum.Material.Slate }
		)
		part(
			m,
			"Shoulder",
			Vector3.new(0.6, 0.35, 0.6),
			o * CFrame.new(side * 1, 0.45, 0),
			GOLD,
			{ Material = Enum.Material.Metal }
		)
	end
	diamond(m, "Core", 0.45, 0.2, o * CFrame.new(0, 0.2, -0.56), rgb(s.Glow), NEON)
	for k = 0, 7 do
		diamond(
			m,
			"Ray",
			0.14,
			0.06,
			o * CFrame.new(0, 0.2, -0.57) * CFrame.Angles(0, 0, k * math.pi / 4) * CFrame.new(0, 0.38, 0),
			GOLD,
			{ Material = Enum.Material.Metal }
		)
	end
	return body
end

-- Fiches des espèces (planches du créateur) ---------------------------------------------------

local SPECIES = {
	-- Commun
	BarnCat = {
		Kind = "Quad",
		Size = { 0.95, 0.85, 1.35 },
		Color = { 214, 150, 80 },
		Belly = { 245, 228, 200 },
		Face = { 245, 228, 200 },
		Ears = "Pointy",
		EarInner = { 240, 180, 170 },
		Eye = { 200, 140, 40 },
		Nose = { 230, 130, 140 },
		Pattern = { Type = "Stripes", Color = { 160, 100, 50 }, Count = 4 },
		Tail = { Type = "Curl", Color = { 214, 150, 80 }, Stripes = { 160, 100, 50 }, Tip = { 245, 228, 200 } },
		Collar = { Color = { 110, 70, 45 }, Gem = { 210, 150, 70 }, Plain = true },
		LegLen = 0.45,
	},
	VillageDog = {
		Kind = "Quad",
		Size = { 1.0, 0.9, 1.4 },
		Color = { 240, 220, 185 },
		Belly = { 248, 236, 212 },
		HeadColor = { 240, 220, 185 },
		Ears = "Floppy",
		EarColor = { 175, 110, 60 },
		Eye = { 90, 55, 30 },
		Tongue = true,
		Snout = 0.35,
		Pattern = { Type = "Patches", Color = { 190, 125, 70 }, Count = 3 },
		Tail = { Type = "Bushy", Color = { 240, 220, 185 }, Size = 0.35, Lift = 70 },
		Collar = { Color = { 110, 70, 45 }, Gem = { 200, 200, 210 }, Plain = true },
		LegLen = 0.5,
	},
	MeadowRabbit = {
		Kind = "Quad",
		Size = { 0.95, 0.9, 1.15 },
		Color = { 200, 160, 120 },
		Belly = { 240, 225, 200 },
		Ears = "Long",
		EarInner = { 235, 175, 170 },
		Eye = { 80, 50, 30 },
		Nose = { 230, 140, 150 },
		Snout = 0.12,
		Tail = { Type = "Puff", Tip = { 248, 244, 236 }, Size = 0.4 },
		Collar = { Color = { 110, 70, 45 }, Gem = { 90, 170, 70 }, Plain = true },
		LegLen = 0.3,
	},
	FarmPig = {
		Kind = "Quad",
		Size = { 1.15, 1.0, 1.4 },
		Color = { 240, 170, 165 },
		Ears = "Pig",
		Eye = { 70, 45, 35 },
		PigNose = { 235, 150, 150 },
		Snout = 0.05,
		Pattern = { Type = "Patches", Color = { 205, 120, 110 }, Count = 2 },
		Tail = { Type = "Pig", Color = { 235, 150, 150 } },
		Collar = { Color = { 230, 170, 60 }, Scarf = true },
		LegLen = 0.35,
		LegD = 0.3,
		Hooves = { 120, 80, 70 },
	},
	RedHen = {
		Kind = "Bird",
		Size = { 1.2, 1.25, 1.2 },
		Color = { 190, 95, 45 },
		Chest = { 220, 150, 70 },
		HeadColor = { 220, 150, 70 },
		Wing = { 170, 80, 40 },
		WingTip = { 120, 60, 35 },
		Eye = { 80, 50, 30 },
		Comb = { 220, 50, 45 },
		TailCount = 5,
		TailLen = 0.7,
		TailLift = 45,
		TailColor = { 140, 70, 40 },
		Collar = { Color = { 110, 70, 45 }, Gem = { 210, 150, 70 }, Plain = true },
	},

	-- Peu commun
	SylvanFox = {
		Kind = "Quad",
		Size = { 0.95, 0.85, 1.45 },
		Color = { 230, 120, 50 },
		Belly = { 248, 238, 222 },
		Face = { 248, 238, 222 },
		Legs = { 110, 70, 50 },
		Ears = "Pointy",
		EarSize = 0.45,
		EarInner = { 250, 235, 220 },
		Eye = { 150, 90, 40 },
		Snout = 0.35,
		Tail = { Type = "Bushy", Color = { 230, 120, 50 }, Tip = { 250, 245, 235 }, Size = 0.6 },
		Collar = { Color = { 100, 130, 60 }, Scarf = true, Width = 0.22, Gem = { 226, 178, 64 }, Plain = true },
	},
	WoodRaccoon = {
		Kind = "Quad",
		Size = { 1.0, 0.9, 1.4 },
		Color = { 140, 135, 135 },
		Belly = { 200, 195, 190 },
		Face = { 225, 220, 215 },
		Mask = { 60, 55, 58 },
		Legs = { 80, 72, 72 },
		Ears = "Round",
		EarInner = { 225, 220, 215 },
		Eye = { 90, 55, 35 },
		Tail = { Type = "Ringed", Color = { 140, 135, 135 }, Tip = { 70, 62, 64 } },
		Collar = { Color = { 100, 130, 60 }, Scarf = true, Gem = { 190, 130, 60 }, Plain = true },
	},
	MossHedgehog = {
		Kind = "Quad",
		Size = { 1.2, 1.05, 1.3 },
		Color = { 120, 85, 55 },
		HeadColor = { 230, 205, 170 },
		Belly = { 235, 215, 185 },
		Ears = "Round",
		EarColor = { 230, 205, 170 },
		Eye = { 80, 50, 30 },
		Snout = 0.15,
		Quills = { 115, 75, 45 },
		LegLen = 0.25,
		Collar = { Color = { 90, 130, 60 }, Gem = { 226, 178, 64 }, Plain = true },
	},
	GladeFawn = {
		Kind = "Quad",
		Size = { 0.85, 0.85, 1.35 },
		Color = { 200, 125, 65 },
		Belly = { 245, 230, 205 },
		Face = { 245, 230, 205 },
		Neck = 0.35,
		Ears = "Wide",
		EarInner = { 245, 200, 190 },
		Eye = { 90, 55, 30 },
		LegLen = 0.85,
		LegD = 0.18,
		Hooves = { 90, 60, 45 },
		Pattern = { Type = "Spots", Color = { 250, 245, 235 }, Count = 10 },
		Tail = { Type = "Short", Color = { 250, 245, 235 } },
		Collar = { Color = { 110, 160, 70 }, Gem = { 110, 160, 70 }, Plain = true },
	},
	OakOwl = {
		Kind = "Bird",
		Size = { 1.25, 1.35, 1.15 },
		Color = { 130, 90, 60 },
		Chest = { 225, 205, 175 },
		ChestFeathers = { 195, 170, 140 },
		Face = { 225, 205, 175 },
		Wing = { 125, 85, 55 },
		WingTip = { 170, 160, 70 },
		Eye = { 240, 170, 40 },
		EyeSize = 0.36,
		BeakType = "Short",
		Beak = { 80, 65, 55 },
		Tufts = { 140, 170, 70 },
		TailCount = 5,
		TailLen = 0.55,
		Collar = { Color = { 110, 70, 45 }, Gem = { 60, 190, 80 }, Setting = { 226, 178, 64 } },
	},

	-- Rare
	FrostWolf = {
		Kind = "Quad",
		Size = { 1.0, 0.95, 1.55 },
		Color = { 150, 155, 170 },
		Belly = { 235, 238, 245 },
		Face = { 235, 238, 245 },
		Fluff = { 240, 242, 248 },
		Ears = "Pointy",
		EarSize = 0.42,
		EarInner = { 120, 190, 255 },
		Eye = { 70, 150, 240 },
		Snout = 0.35,
		Pattern = { Type = "Marks", Color = { 110, 190, 255 } },
		Tail = { Type = "Bushy", Color = { 150, 155, 170 }, Tip = { 110, 190, 255 }, Size = 0.55 },
		Collar = { Color = SILVER_T, Gem = { 60, 130, 255 } },
	},
	GlacierBear = {
		Kind = "Quad",
		Size = { 1.35, 1.15, 1.6 },
		Color = { 238, 240, 245 },
		Belly = { 248, 249, 252 },
		Ears = "Round",
		Eye = { 70, 150, 240 },
		Snout = 0.25,
		LegD = 0.42,
		LegLen = 0.5,
		Pattern = { Type = "Marks", Color = { 110, 190, 255 } },
		Cuffs = { 190, 194, 206 },
		Tail = { Type = "Puff", Tip = { 238, 240, 245 }, Size = 0.35 },
		Collar = { Color = SILVER_T, Gem = { 60, 130, 255 } },
	},
	SnowLynx = {
		Kind = "Quad",
		Size = { 0.95, 0.9, 1.45 },
		Color = { 225, 228, 235 },
		Belly = { 245, 246, 250 },
		Face = { 245, 246, 250 },
		Ears = "Tufted",
		EarSize = 0.42,
		EarColor = { 120, 120, 135 },
		EarInner = { 230, 230, 238 },
		Eye = { 70, 150, 240 },
		Nose = { 230, 150, 160 },
		Pattern = { Type = "Spots", Color = { 110, 112, 128 }, Count = 16 },
		Tail = { Type = "Short", Color = { 110, 112, 128 } },
		Collar = { Color = { 45, 65, 130 }, Scarf = true, Width = 0.22, Gem = { 60, 130, 255 } },
	},
	SpringStag = {
		Kind = "Quad",
		Size = { 0.9, 0.9, 1.45 },
		Color = { 140, 145, 160 },
		Belly = { 235, 238, 245 },
		Face = { 225, 228, 235 },
		Neck = 0.4,
		Ears = "Wide",
		EarInner = { 230, 220, 225 },
		Eye = { 70, 150, 240 },
		LegLen = 0.9,
		LegD = 0.18,
		Hooves = { 70, 72, 85 },
		Antlers = { Color = { 170, 172, 185 }, Tips = { 90, 170, 255 } },
		Pattern = { Type = "Marks", Color = { 120, 190, 255 } },
		Tail = { Type = "Short", Color = { 245, 246, 250 } },
		Collar = { Color = SILVER_T, Gem = { 60, 130, 255 } },
	},
	PeakEagle = {
		Kind = "Bird",
		Size = { 1.2, 1.4, 1.15 },
		Color = { 120, 125, 145 },
		Chest = { 150, 155, 175 },
		HeadColor = { 245, 246, 250 },
		Wing = { 120, 125, 145 },
		WingTip = { 90, 160, 240 },
		Eye = { 70, 150, 240 },
		BeakType = "Hook",
		Beak = { 240, 190, 50 },
		TailCount = 5,
		TailLen = 0.9,
		TailTip = { 90, 160, 240 },
		Legs = { 240, 190, 50 },
		Collar = { Color = SILVER_T, Gem = { 60, 130, 255 } },
	},

	-- Épique
	RunePanther = {
		Kind = "Quad",
		Size = { 0.95, 0.9, 1.65 },
		Color = { 60, 40, 85 },
		Belly = { 70, 48, 98 },
		Ears = "Pointy",
		EarInner = { 120, 80, 150 },
		Eye = { 200, 140, 255 },
		Glow = { 210, 150, 255 },
		Pattern = { Type = "Runes", Color = { 200, 130, 255 } },
		Forehead = { 200, 130, 255 },
		Tail = { Type = "Curl", Color = { 60, 40, 85 }, Tip = { 200, 130, 255 } },
		Collar = { Color = SILVER_T, Gem = { 180, 100, 255 } },
	},
	DuskTiger = {
		Kind = "Quad",
		Size = { 1.1, 1.0, 1.7 },
		Color = { 95, 55, 130 },
		Belly = { 225, 215, 210 },
		Face = { 225, 215, 210 },
		Ears = "Round",
		EarInner = { 225, 215, 210 },
		Eye = { 200, 140, 255 },
		Pattern = { Type = "Stripes", Color = { 200, 185, 200 }, Count = 6 },
		Shoulders = { 185, 188, 200 },
		Tail = { Type = "Ringed", Color = { 95, 55, 130 }, Tip = { 200, 185, 200 } },
		Collar = { Color = SILVER_T },
	},
	ArcaneRaven = {
		Kind = "Bird",
		Size = { 1.2, 1.35, 1.15 },
		Color = { 55, 35, 80 },
		Chest = { 70, 45, 100 },
		Wing = { 70, 40, 110 },
		WingTip = { 170, 100, 240 },
		Eye = { 200, 140, 255 },
		BeakType = "Long",
		Beak = { 70, 70, 82 },
		Moon = true,
		TailCount = 5,
		TailLen = 1.0,
		TailTip = { 170, 100, 240 },
		Legs = { 45, 40, 50 },
		Collar = { Color = SILVER_T, Gem = { 180, 100, 255 } },
	},
	VioletSalamander = {
		Kind = "Quad",
		Size = { 1.05, 0.6, 1.7 },
		Color = { 75, 45, 105 },
		Belly = { 175, 140, 220 },
		Muzzle = { 75, 45, 105 },
		Ears = "None",
		Eye = { 200, 140, 255 },
		Snout = 0.15,
		LegLen = 0.2,
		LegD = 0.28,
		Pattern = { Type = "Spots", Color = { 190, 140, 255 }, Count = 14, Neon = true },
		Spines = { Color = { 200, 140, 255 }, Crystal = true, Count = 5 },
		Tail = { Type = "Lizard", Color = { 75, 45, 105 } },
		Head = { 0.95, 0.65, 0.85 },
	},
	RuneRam = {
		Kind = "Quad",
		Size = { 1.3, 1.15, 1.45 },
		Color = { 60, 45, 70 },
		HeadColor = { 230, 205, 185 },
		Belly = { 70, 52, 82 },
		Ears = "Floppy",
		EarColor = { 230, 205, 185 },
		Eye = { 160, 100, 220 },
		Snout = 0.12,
		LegLen = 0.45,
		Hooves = { 50, 40, 55 },
		Legs = { 230, 205, 185 },
		RamHorns = { Color = { 140, 90, 190 }, Bands = { 200, 140, 255 } },
		Quills = nil,
		Fluff = { 70, 55, 85 },
		Tail = { Type = "Puff", Tip = { 70, 55, 85 }, Size = 0.4 },
		Collar = { Color = SILVER_T, Gem = { 180, 100, 255 } },
	},

	-- Légendaire
	SolarLion = {
		Kind = "Quad",
		Size = { 1.15, 1.05, 1.7 },
		Color = { 225, 175, 90 },
		Belly = { 240, 200, 130 },
		Eye = { 200, 120, 30 },
		Ears = "Round",
		Mane = { 235, 110, 40 },
		Mane2 = { 245, 160, 50 },
		Pattern = { Type = "Suns", Color = { 226, 178, 64 } },
		Cuffs = { 226, 178, 64 },
		Harness = { 150, 95, 50 },
		Tail = { Type = "Tuft", Color = { 225, 175, 90 }, Tip = { 110, 70, 45 } },
		Collar = { Color = GOLD_T, Gem = { 255, 140, 30 }, Setting = { 226, 178, 64 } },
	},
	RoyalGriffin = {
		Kind = "Quad",
		Size = { 1.1, 1.0, 1.65 },
		Color = { 215, 170, 90 },
		HeadColor = { 245, 235, 215 },
		Belly = { 245, 235, 215 },
		Ears = "None",
		Eye = { 220, 150, 40 },
		Snout = 0.0,
		Muzzle = { 240, 190, 50 },
		Crest = { 226, 178, 64 },
		Wings = { Color = { 235, 190, 80 }, Tip = { 245, 225, 160 }, Span = 1.2 },
		Cuffs = { 226, 178, 64 },
		Legs = { 240, 190, 60 },
		Tail = { Type = "Tuft", Color = { 215, 170, 90 }, Tip = { 120, 75, 45 } },
		Collar = { Color = GOLD_T, Gem = { 230, 40, 50 }, Setting = { 226, 178, 64 } },
	},
	EmberPhoenix = {
		Kind = "Bird",
		Size = { 1.15, 1.35, 1.1 },
		Color = { 200, 50, 35 },
		Chest = { 240, 120, 40 },
		Wing = { 210, 60, 35 },
		WingTip = { 255, 190, 60 },
		Eye = { 255, 180, 40 },
		BeakType = "Hook",
		Beak = { 245, 190, 60 },
		FlameCrest = { 255, 120, 30 },
		FlameCrest2 = { 255, 210, 80 },
		SpreadWings = 1.2,
		TailCount = 7,
		TailLen = 1.6,
		TailLift = 10,
		TailColor = { 230, 70, 35 },
		TailTip = { 255, 210, 80 },
		Legs = { 120, 60, 40 },
		Collar = { Color = GOLD_T, Gem = { 255, 120, 30 }, Setting = { 226, 178, 64 } },
	},
	RubyDragon = {
		Kind = "Quad",
		Size = { 1.15, 1.05, 1.65 },
		Color = { 170, 40, 40 },
		Belly = { 235, 190, 110 },
		Ears = "None",
		Eye = { 240, 170, 40 },
		Snout = 0.3,
		DragonHorns = { Color = { 70, 45, 40 } },
		Wings = { Bat = true, Color = { 200, 70, 50 }, Bone = { 226, 178, 64 }, Span = 1.3 },
		Spines = { Color = { 60, 40, 40 }, Count = 5 },
		Cuffs = { 226, 178, 64 },
		Tail = { Type = "Dragon", Color = { 170, 40, 40 }, Tip = { 226, 178, 64 } },
		Collar = { Color = GOLD_T, Gem = { 230, 30, 40 }, Setting = { 226, 178, 64 } },
	},
	DawnUnicorn = {
		Kind = "Quad",
		Size = { 0.95, 0.95, 1.5 },
		Color = { 245, 235, 215 },
		Neck = 0.4,
		Ears = "Pointy",
		EarSize = 0.3,
		Eye = { 180, 120, 60 },
		Snout = 0.3,
		LegLen = 0.85,
		LegD = 0.2,
		Hooves = { 150, 95, 60 },
		Cuffs = { 226, 178, 64 },
		UnicornHorn = { 236, 196, 80 },
		NeckMane = { 245, 200, 90 },
		Tail = { Type = "Flow", Color = { 245, 200, 90 }, Tip = { 250, 225, 140 }, Size = 0.6, Lift = 20 },
		Collar = { Color = GOLD_T, Gem = { 255, 140, 30 }, Setting = { 226, 178, 64 } },
	},

	-- Mythique
	AstralKitsune = {
		Kind = "Quad",
		Size = { 0.9, 0.85, 1.35 },
		Color = { 238, 232, 245 },
		Belly = { 248, 246, 252 },
		Legs = { 90, 60, 140 },
		Ears = "Pointy",
		EarSize = 0.45,
		EarColor = { 238, 232, 245 },
		EarInner = { 90, 60, 140 },
		Eye = { 80, 230, 230 },
		Forehead = { 226, 178, 64 },
		Cuffs = { 226, 178, 64 },
		Tail = { Type = "Nine", Color = { 238, 232, 245 }, Mid = { 100, 70, 170 }, Tip = { 80, 225, 230 } },
		Collar = { Color = GOLD_T, Gem = { 80, 230, 230 }, Setting = { 226, 178, 64 } },
	},
	CelestialHydra = {
		Kind = "Quad",
		Size = { 1.2, 1.0, 1.6 },
		Color = { 30, 90, 105 },
		Belly = { 230, 220, 200 },
		Ears = "None",
		Eye = { 90, 240, 240 },
		Glow = { 90, 240, 240 },
		Snout = 0.3,
		Head = { 0.62, 0.55, 0.6 },
		Heads = { -0.55, 0, 0.55 },
		Crest = { 226, 178, 64 },
		Scales = { 40, 110, 125 },
		Spines = { Color = { 226, 178, 64 }, Count = 4 },
		Cuffs = { 226, 178, 64 },
		Tail = { Type = "Dragon", Color = { 30, 90, 105 }, Tip = { 226, 178, 64 } },
		Collar = { Color = GOLD_T, Gem = { 80, 230, 230 }, Setting = { 226, 178, 64 } },
	},
	ImperialQilin = {
		Kind = "Quad",
		Size = { 0.95, 0.95, 1.5 },
		Color = { 238, 232, 225 },
		Belly = { 245, 240, 232 },
		Neck = 0.4,
		Ears = "Wide",
		EarInner = { 230, 190, 180 },
		Eye = { 80, 230, 230 },
		Snout = 0.3,
		LegLen = 0.8,
		LegD = 0.2,
		Hooves = { 110, 80, 50 },
		Antlers = { Color = { 226, 178, 64 } },
		NeckMane = { 200, 170, 235 },
		Scales = { 50, 140, 140 },
		Cuffs = { 226, 178, 64 },
		Tail = { Type = "Flow", Color = { 200, 170, 235 }, Tip = { 225, 205, 250 }, Size = 0.65, Lift = 25 },
		Collar = { Color = GOLD_T, Gem = { 80, 230, 230 }, Setting = { 226, 178, 64 } },
	},
	StarSerpent = {
		Kind = "Serpent",
		Color = { 70, 45, 130 },
		Belly = { 200, 190, 230 },
		Eye = { 90, 230, 255 },
		Glow = { 90, 230, 255 },
		Horns = { 226, 178, 64 },
		Stars = { 226, 178, 64 },
	},
	CosmicTurtle = {
		Kind = "Turtle",
		Color = { 40, 140, 140 },
		Shell = { 75, 45, 130 },
		Belly = { 200, 190, 160 },
		Eye = { 90, 230, 255 },
		Crystal = { 90, 230, 255 },
	},

	-- Céleste
	SunGuardian = { Kind = "Golem", Color = { 235, 200, 110 }, Glow = { 255, 220, 90 } },
	CelestialDragon = {
		Kind = "Quad",
		Size = { 1.15, 1.05, 1.7 },
		Color = { 90, 210, 200 },
		Belly = { 235, 245, 245 },
		Ears = "None",
		Eye = { 255, 255, 255 },
		Glow = { 140, 255, 240 },
		Snout = 0.3,
		DragonHorns = { Color = { 226, 178, 64 } },
		Wings = { Bat = true, Color = { 140, 240, 230 }, Bone = { 226, 178, 64 }, Span = 1.4 },
		Spines = { Color = { 140, 255, 240 }, Crystal = true, Count = 5 },
		Cuffs = { 226, 178, 64 },
		Tail = { Type = "Dragon", Color = { 90, 210, 200 }, Tip = { 226, 178, 64 } },
		Collar = { Color = GOLD_T, Gem = { 255, 255, 255 }, Setting = { 226, 178, 64 } },
	},
}
PetModels.Species = SPECIES

-- Construit le compagnon `def` (entrée de Config/Pets.List). rarityColor : couleur de rareté
-- (aura des raretés hautes et repli pour une espèce sans fiche).
function PetModels.build(def, _rarityColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = def.Id
	local spec = SPECIES[def.Id]
	local body
	if not spec then
		body = ell(m, "Body", Vector3.new(1.2, 1.2, 1.2), CFrame.new(), rgb(def.Color or { 200, 200, 200 }))
		eyes(m, CFrame.new(0, 0.1, 0), Vector3.new(1.2, 1.2, 1.2), DARK)
	elseif spec.Kind == "Bird" then
		body = bird(m, spec)
	elseif spec.Kind == "Serpent" then
		body = serpent(m, spec)
	elseif spec.Kind == "Turtle" then
		body = turtle(m, spec)
	elseif spec.Kind == "Golem" then
		body = golem(m, spec)
	else
		body = quadruped(m, spec)
	end

	-- (Plus de disque de rareté sous le compagnon : il marche au sol, la rareté est visible
	-- dans le menu et à l'éclosion.)

	-- Une seule pièce ancrée ; les autres y sont soudées (déplacement en un seul bloc).
	m.PrimaryPart = body
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = p
			weld.Parent = p
			p.Anchored = false
			p.Massless = true
		end
	end
	return m
end

return PetModels
