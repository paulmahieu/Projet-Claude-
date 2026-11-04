--[[
	CostPanel : panneau 3D lisible au-dessus des socles de construction, des machines et du
	panneau d'agrandissement.

	Remplace l'ancien texte blanc sur fond transparent, illisible sur le ciel et le dallage :
	- fond sombre arrondi, bordure colorée selon l'état (prêt, manquant, verrouillé) ;
	- une ligne par ressource : pastille de la couleur du matériau, nom, et « stock / coût » en
	  vert si le groupe en a assez, en rouge sinon ;
	- taille de texte fixe (pas de TextScaled qui rapetissait le texte des longues lignes) ;
	- le panneau s'élève au-dessus de son ancre (il ne cache pas la gemme d'état).
	Les lignes sont réutilisées : une mise à jour ne recrée aucune instance.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Materials = require(Shared.Config.Materials)
local Formulas = require(Shared.Formulas)

local CostPanel = {}

local WIDTH = 280
local TITLE_H = 26
local ROW_H = 26
local LINE_H = 18
local STATUS_H = 22
local GAP = 3
local PAD = 8

local GOLD = Color3.fromRGB(222, 176, 64)
local KIND_COLOR = {
	ok = Color3.fromRGB(110, 230, 120),
	missing = Color3.fromRGB(255, 110, 95),
	locked = Color3.fromRGB(170, 170, 185),
	info = Color3.fromRGB(255, 225, 150),
}

export type Info = {
	Title: string,
	Cost: { [string]: number }?,
	Have: { [string]: number }?,
	Lines: { string }?,
	Status: string?,
	Kind: string?, -- "ok" | "missing" | "locked" | "info"
}

local function rgb(c): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function label(parent: Instance, order: number, size: number, font: Enum.Font, color: Color3, height: number)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height)
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.55
	l.TextWrapped = true
	l.LayoutOrder = order
	l.Text = ""
	l.Parent = parent
	return l
end

function CostPanel.new(adornee: BasePart, offsetY: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CostPanel"
	gui.Size = UDim2.fromOffset(WIDTH, 80)
	gui.SizeOffset = Vector2.new(0, 0.5) -- le bas du panneau sur l'ancre
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 60
	gui.Adornee = adornee
	gui.Parent = adornee

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(22, 20, 32)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = GOLD
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD)
	pad.PaddingTop = UDim.new(0, PAD - 2)
	pad.PaddingBottom = UDim.new(0, PAD - 2)
	pad.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = frame

	local title = label(frame, 1, 20, Enum.Font.GothamBold, Color3.fromRGB(255, 228, 160), TITLE_H)
	local status = label(frame, 100, 16, Enum.Font.GothamBold, KIND_COLOR.info, STATUS_H)
	return { Gui = gui, Frame = frame, Stroke = stroke, Title = title, Status = status, Rows = {}, Lines = {} }
end

local function row(panel, index: number)
	local r = panel.Rows[index]
	if r then
		return r
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, ROW_H)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.92
	f.LayoutOrder = 10 + index
	f.Parent = panel.Frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = f
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(14, 14)
	swatch.Position = UDim2.new(0, 6, 0.5, -7)
	swatch.BorderSizePixel = 0
	swatch.Parent = f
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 4)
	sc.Parent = swatch
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(28, 0)
	name.Size = UDim2.new(0.5, -28, 1, 0)
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 17
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextStrokeTransparency = 0.6
	name.Parent = f
	local amount = Instance.new("TextLabel")
	amount.BackgroundTransparency = 1
	amount.Position = UDim2.fromScale(0.4, 0)
	amount.Size = UDim2.new(0.6, -8, 1, 0)
	amount.Font = Enum.Font.GothamBold
	amount.TextSize = 17
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextStrokeTransparency = 0.6
	amount.Parent = f
	r = { Frame = f, Swatch = swatch, Name = name, Amount = amount }
	panel.Rows[index] = r
	return r
end

-- Hauteur d'une ligne de texte (retour à la ligne au-delà d'environ 34 caractères).
local function lineHeight(text: string): number
	local n = utf8.len(text) or #text
	return math.max(1, math.ceil(n / 34)) * LINE_H
end

function CostPanel.set(panel, info: Info)
	local kind = info.Kind or "info"
	local height = PAD * 2 - 4 + TITLE_H
	panel.Title.Text = info.Title
	panel.Stroke.Color = if kind == "info" then GOLD else KIND_COLOR[kind]

	local count = 0
	if info.Cost then
		for _, mat in Materials do
			local need = info.Cost[mat.Id]
			if need then
				count += 1
				local r = row(panel, count)
				local have = if info.Have then info.Have[mat.Id] or 0 else 0
				r.Frame.Visible = true
				r.Swatch.BackgroundColor3 = rgb(mat.Color)
				r.Name.Text = mat.Name
				r.Amount.Text =
					string.format("%s / %s", Formulas.formatNumber(math.floor(have)), Formulas.formatNumber(need))
				r.Amount.TextColor3 = if have >= need then KIND_COLOR.ok else KIND_COLOR.missing
				height += ROW_H + GAP
			end
		end
	end
	for i = count + 1, #panel.Rows do
		panel.Rows[i].Frame.Visible = false
	end

	local lines = info.Lines or {}
	for i, text in lines do
		local l = panel.Lines[i]
		if not l then
			l = label(panel.Frame, 50 + i, 15, Enum.Font.Gotham, Color3.fromRGB(205, 205, 220), LINE_H)
			panel.Lines[i] = l
		end
		local h = lineHeight(text)
		l.Visible = true
		l.Text = text
		l.Size = UDim2.new(1, 0, 0, h)
		height += h + GAP
	end
	for i = #lines + 1, #panel.Lines do
		panel.Lines[i].Visible = false
	end

	panel.Status.Visible = info.Status ~= nil
	if info.Status then
		local n = utf8.len(info.Status) or #info.Status
		local h = math.max(1, math.ceil(n / 28)) * STATUS_H
		panel.Status.Text = info.Status
		panel.Status.TextColor3 = KIND_COLOR[kind]
		panel.Status.Size = UDim2.new(1, 0, 0, h)
		height += h + GAP
	end
	panel.Gui.Size = UDim2.fromOffset(WIDTH, height)
end

return CostPanel
