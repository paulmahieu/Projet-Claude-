--[[
	EggPreview : montre les compagnons qu'un œuf peut donner AVANT de l'ouvrir.

	- Portrait de face : le vrai modèle du compagnon (PetModels) dans un ViewportFrame, caméra
	  devant lui (face = -Z), fond dégradé de la couleur de sa rareté.
	- Carte : portrait, nom, rareté (couleur), multiplicateur (×1,1 = +10 %) et probabilité.
	- Panneau 3D au-dessus du présentoir le plus proche (moins de 16 studs) : grille de petites
	  cartes, visible seulement près d'un œuf (un seul à la fois, pour la lisibilité et les
	  performances). La fenêtre d'ouverture (Main) utilise les grandes cartes.
	Purement local : les probabilités viennent de Config/Pets (avec le bonus de chance du joueur),
	le tirage reste fait par le serveur.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local PetModels = require(Shared.PetModels)
local Formulas = require(Shared.Formulas)

local EggPreview = {}

local RANGE = 16 -- distance d'affichage du panneau au-dessus d'un œuf
local GOLD = Color3.fromRGB(255, 215, 90)

local petById = {}
for _, def in Pets.List do
	petById[def.Id] = def
end
local eggById = {}
for _, egg in Pets.Eggs do
	eggById[egg.Id] = egg
end

local function rarityColor(rarityId: string): Color3
	local c = Pets.Rarities[rarityId].Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function create(className: string, props, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

-- Portrait de face du compagnon dans un ViewportFrame (remplit `parent`).
function EggPreview.portrait(def, parent: GuiObject): ViewportFrame
	local color = rarityColor(def.Rarity)
	local vp = create("ViewportFrame", {
		Name = "Portrait",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.4, -0.9, 0.7), -- éclaire la face (-Z) du compagnon
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, vp)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.55)),
	}, vp)

	local model = PetModels.build(def, color)
	model.Parent = vp
	local box, size = model:GetBoundingBox()
	local center = box.Position
	local camera = create("Camera", { FieldOfView = 30 }, vp)
	-- Distance pour que le compagnon remplisse le cadre (cadre bien rempli).
	-- Distance pour que le compagnon remplisse le cadre (hauteur ou largeur, cadre ~1,15:1).
	local tanHalf = math.tan(math.rad(camera.FieldOfView / 2))
	local distance = math.max(size.Y / (2 * tanHalf), size.X / (2 * tanHalf * 1.15)) * 1.08 + size.Z / 2
	-- De face (-Z), légèrement de trois quarts et en plongée pour donner du relief.
	local dir = Vector3.new(math.sin(math.rad(18)), 0.22, -math.cos(math.rad(18))).Unit
	camera.CFrame = CFrame.lookAt(center + dir * distance, center)
	vp.CurrentCamera = camera
	return vp
end

-- Carte d'un compagnon. size : "big" (fenêtre d'ouverture) ou "small" (panneau 3D).
function EggPreview.card(def, chance: number, size: string, order: number?): Frame
	local big = size == "big"
	local color = rarityColor(def.Rarity)
	local card = create("Frame", {
		Name = def.Id,
		BackgroundColor3 = Color3.fromRGB(34, 29, 26),
		LayoutOrder = order or 0,
	}, nil)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
	create("UIStroke", { Color = color, Thickness = if big then 2 else 1.5 }, card)

	local photoH = if big then 92 else 58
	local photo = create("Frame", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0, photoH),
		BackgroundTransparency = 1,
	}, card)
	EggPreview.portrait(def, photo)
	-- Probabilité (pastille en haut à gauche de la photo)
	local badge = create("TextLabel", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(if big then 58 else 44, if big then 18 else 14),
		BackgroundColor3 = Color3.fromRGB(15, 13, 20),
		BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBold,
		TextSize = if big then 12 else 10,
		TextColor3 = Color3.new(1, 1, 1),
		Text = Formulas.chanceText(chance),
		ZIndex = 3,
	}, photo)
	create("UICorner", { CornerRadius = UDim.new(0, 6) }, badge)

	local y = photoH + 6
	if big then
		create("TextLabel", {
			Position = UDim2.fromOffset(4, y),
			Size = UDim2.new(1, -8, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(245, 236, 220),
			Text = def.Name,
		}, card)
		y += 30
		create("TextLabel", {
			Position = UDim2.fromOffset(4, y),
			Size = UDim2.new(1, -8, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = color,
			Text = Pets.Rarities[def.Rarity].Name,
		}, card)
		y += 16
	else
		-- Petite carte : rareté en petit sous la photo (le nom reste dans la fenêtre d'ouverture).
		create("TextLabel", {
			Position = UDim2.fromOffset(2, y),
			Size = UDim2.new(1, -4, 0, 12),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = color,
			Text = Pets.Rarities[def.Rarity].Name,
		}, card)
		y += 12
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(4, y),
		Size = UDim2.new(1, -8, 0, if big then 22 else 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = if big then 19 else 15,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.5,
		Text = Formulas.petMultiplierText(def.Bonus),
	}, card)
	return card
end

-- Hauteur d'une carte (pour dimensionner les grilles).
function EggPreview.cardSize(size: string): Vector2
	return if size == "big" then Vector2.new(116, 176) else Vector2.new(78, 98)
end

-- Probabilités de l'œuf pour ce joueur (bonus de chance compris), de la plus rare à la plus
-- commune pour mettre en valeur les meilleurs compagnons.
function EggPreview.odds(egg)
	local luck = Players.LocalPlayer:GetAttribute("Luck") or 0
	local list = Formulas.eggOdds(Formulas.luckyEgg(egg, Pets, luck))
	table.sort(list, function(a, b)
		local ra, rb = Pets.Rarities[petById[a.Id].Rarity].Order, Pets.Rarities[petById[b.Id].Rarity].Order
		if ra ~= rb then
			return ra > rb
		end
		return petById[a.Id].Bonus > petById[b.Id].Bonus
	end)
	return list
end

-- Grille de cartes dans `parent` (UIGridLayout). Retourne le nombre de cartes.
function EggPreview.fill(parent: Instance, egg, size: string): number
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local count = 0
	for i, entry in EggPreview.odds(egg) do
		local def = petById[entry.Id]
		if def then
			EggPreview.card(def, entry.Chance, size, i).Parent = parent
			count += 1
		end
	end
	return count
end

-- Panneau 3D au-dessus du présentoir le plus proche ---------------------------------------------

local board: BillboardGui? = nil
local boardEgg: string? = nil
local boardLuck = -1
local suppressed = false

local function clearBoard()
	if board then
		board:Destroy()
	end
	board, boardEgg = nil, nil
end

local function buildBoard(egg, adornee: BasePart)
	clearBoard()
	local cell = EggPreview.cardSize("small")
	local count = 0
	for _ in egg.Weights do
		count += 1
	end
	local cols = math.min(count, 5)
	local rows = math.ceil(count / cols)
	local width = cols * (cell.X + 6) + 14
	local height = rows * (cell.Y + 6) + 44
	local gui = create("BillboardGui", {
		Name = "EggPreview",
		Size = UDim2.fromOffset(width, height),
		SizeOffset = Vector2.new(0, 0.5),
		StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = RANGE + 6,
		Adornee = adornee,
	}, nil)
	local frame = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 20, 30),
		BackgroundTransparency = 0.12,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
	create("UIStroke", { Color = Color3.fromRGB(egg.Color[1], egg.Color[2], egg.Color[3]), Thickness = 2 }, frame)
	create("TextLabel", {
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 228, 160),
		Text = egg.Name .. " · compagnons possibles",
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame)
	local grid = create("Frame", {
		Position = UDim2.fromOffset(7, 36),
		Size = UDim2.new(1, -14, 1, -40),
		BackgroundTransparency = 1,
	}, frame)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, grid)
	EggPreview.fill(grid, egg, "small")
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	board, boardEgg = gui, egg.Id
	boardLuck = Players.LocalPlayer:GetAttribute("Luck") or 0
end

-- Masque le panneau 3D (quand la fenêtre d'ouverture est affichée).
function EggPreview.setSuppressed(value: boolean)
	suppressed = value
	if value then
		clearBoard()
	end
end

function EggPreview.start()
	local player = Players.LocalPlayer
	local stands: { { Egg: any, Part: BasePart } } = {}
	local function scan()
		table.clear(stands)
		local world = workspace:FindFirstChild("World")
		local folder = world and world:FindFirstChild("Eggs")
		if not folder then
			return
		end
		for _, prompt in folder:GetDescendants() do
			if prompt:IsA("ProximityPrompt") then
				local egg = eggById[prompt:GetAttribute("EggId") or ""]
				if egg and prompt.Parent and prompt.Parent:IsA("BasePart") then
					table.insert(stands, { Egg = egg, Part = prompt.Parent })
				end
			end
		end
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if #stands == 0 then
			scan()
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if suppressed or not root then
			clearBoard()
			return
		end
		local best, bestDist = nil, RANGE
		for _, stand in stands do
			if stand.Part.Parent then
				local d = (stand.Part.Position - root.Position).Magnitude
				if d < bestDist then
					best, bestDist = stand, d
				end
			else
				table.clear(stands) -- monde régénéré : on rescanne au prochain tour
				break
			end
		end
		if not best then
			clearBoard()
		elseif best.Egg.Id ~= boardEgg or (player:GetAttribute("Luck") or 0) ~= boardLuck then
			buildBoard(best.Egg, best.Part)
		end
	end)
end

return EggPreview
