--[[
	PetModels : apparence des compagnons, générée par code (formes simples, couleurs de rareté).
	Utilisé par le client (suiveurs) ; aucune logique de jeu. Pièces non collisionnables :
	les compagnons ne bloquent jamais les personnages (cahier §7).
]]

local PetModels = {}

local function part(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props and props.Shape then
		p.Shape = props.Shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if props and props.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if props and props.Transparency then
		p.Transparency = props.Transparency
	end
	p.Parent = m
	return p
end

local BALL = { Shape = Enum.PartType.Ball }
local DARK = Color3.fromRGB(25, 25, 30)

-- def : entrée de Config/Pets.List ; rarityColor : Color3. Origine = centre du corps.
function PetModels.build(def, rarityColor: Color3): Model
	local m = Instance.new("Model")
	m.Name = def.Id
	local c = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
	local o = CFrame.new()
	local body

	if def.Kind == "Beast" then
		body = part(m, "Body", Vector3.new(1.4, 1.1, 1.9), o, c)
		local head = part(m, "Head", Vector3.new(1.1, 1, 1), o * CFrame.new(0, 0.55, -1.05), c)
		for _, x in { -0.32, 0.32 } do
			part(m, "Ear", Vector3.new(0.25, 0.5, 0.2), head.CFrame * CFrame.new(x, 0.65, 0.1), c:Lerp(DARK, 0.25))
			part(m, "Eye", Vector3.new(0.16, 0.16, 0.05), head.CFrame * CFrame.new(x * 0.8, 0.12, -0.51), DARK)
		end
		part(m, "Tail", Vector3.new(0.3, 0.3, 0.9), o * CFrame.new(0, 0.35, 1.2) * CFrame.Angles(math.rad(30), 0, 0), c)
		for _, p in { { -0.45, -0.6 }, { 0.45, -0.6 }, { -0.45, 0.6 }, { 0.45, 0.6 } } do
			part(m, "Leg", Vector3.new(0.3, 0.6, 0.3), o * CFrame.new(p[1], -0.75, p[2]), c:Lerp(DARK, 0.15))
		end
	elseif def.Kind == "Bird" then
		body = part(m, "Body", Vector3.new(1.3, 1.3, 1.3), o, c, BALL)
		part(m, "Beak", Vector3.new(0.3, 0.25, 0.45), o * CFrame.new(0, 0.05, -0.75), Color3.fromRGB(240, 180, 60))
		for _, side in { -1, 1 } do
			part(
				m,
				"Wing",
				Vector3.new(0.9, 0.18, 0.9),
				o * CFrame.new(side * 0.85, 0.1, 0.1) * CFrame.Angles(0, 0, math.rad(side * -25)),
				c:Lerp(rarityColor, 0.35)
			)
			part(m, "Eye", Vector3.new(0.18, 0.18, 0.05), o * CFrame.new(side * 0.28, 0.25, -0.62), DARK)
		end
	elseif def.Kind == "Golem" then
		body = part(m, "Body", Vector3.new(1.5, 1.4, 1.1), o, c)
		part(m, "Head", Vector3.new(0.9, 0.8, 0.8), o * CFrame.new(0, 1.05, 0), c:Lerp(Color3.new(1, 1, 1), 0.15))
		part(m, "Eye", Vector3.new(0.5, 0.15, 0.05), o * CFrame.new(0, 1.1, -0.41), rarityColor, { Neon = true })
		for _, side in { -1, 1 } do
			part(m, "Arm", Vector3.new(0.45, 1.2, 0.45), o * CFrame.new(side * 1, -0.2, 0), c:Lerp(DARK, 0.2))
		end
		part(
			m,
			"Gem",
			Vector3.new(0.35, 0.35, 0.35),
			o * CFrame.new(0, 0.2, -0.56) * CFrame.Angles(0.8, 0.8, 0),
			rarityColor,
			{ Neon = true }
		)
	elseif def.Kind == "Wisp" then
		body = part(m, "Body", Vector3.new(1.2, 1.2, 1.2), o, c, { Shape = Enum.PartType.Ball, Neon = true })
		part(
			m,
			"Halo",
			Vector3.new(1.9, 1.9, 1.9),
			o,
			c,
			{ Shape = Enum.PartType.Ball, Neon = true, Transparency = 0.75 }
		)
		for _, x in { -0.22, 0.22 } do
			part(m, "Eye", Vector3.new(0.15, 0.22, 0.05), o * CFrame.new(x, 0.1, -0.6), DARK)
		end
	else -- Sprout
		body = part(m, "Body", Vector3.new(1.2, 1.2, 1.2), o, c, BALL)
		part(m, "Stem", Vector3.new(0.15, 0.6, 0.15), o * CFrame.new(0, 0.85, 0), Color3.fromRGB(80, 140, 60))
		for _, side in { -1, 1 } do
			part(
				m,
				"Leaf",
				Vector3.new(0.6, 0.12, 0.35),
				o * CFrame.new(side * 0.3, 1.15, 0) * CFrame.Angles(0, 0, math.rad(side * 20)),
				Color3.fromRGB(110, 200, 80)
			)
			part(m, "Eye", Vector3.new(0.15, 0.15, 0.05), o * CFrame.new(side * 0.22, 0.15, -0.58), DARK)
		end
	end

	-- Halo de rareté au sol pour les raretés hautes.
	if def.Rarity == "Legendary" or def.Rarity == "Mythic" then
		part(
			m,
			"Aura",
			Vector3.new(0.1, 2.2, 2.2),
			o * CFrame.new(0, -1.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			rarityColor,
			{
				Shape = Enum.PartType.Cylinder,
				Neon = true,
				Transparency = 0.5,
			}
		)
	end
	m.PrimaryPart = body
	return m
end

return PetModels
