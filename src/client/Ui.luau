--[[
	Petits utilitaires d'interface : création d'instances et style commun.

	Rendu « pro » avec les outils intégrés de Roblox (aucun asset externe) :
	- police officielle Builder Sans (repli sur Gotham si indisponible), FredokaOne pour les titres ;
	- UIGradient : relief des boutons et des panneaux ; UIStroke : contours nets ;
	- UIScale + TweenService : boutons qui réagissent au survol et à l'appui, fenêtres qui
	  s'ouvrent avec un léger rebond ; BlurEffect : arrière-plan flouté derrière les fenêtres.
]]

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Ui = {}

-- Police intégrée par son nom, avec repli si l'énumération n'existe pas sur ce client.
local function font(name: string, fallback: Enum.Font): Enum.Font
	local ok, value = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	return if ok and value then value else fallback
end

Ui.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = font("BuilderSans", Enum.Font.Gotham),
	Medium = font("BuilderSansMedium", Enum.Font.GothamMedium),
	Bold = font("BuilderSansBold", Enum.Font.GothamBold),
	Black = font("BuilderSansExtraBold", Enum.Font.GothamBlack),
}

Ui.Colors = {
	Panel = Color3.fromRGB(32, 27, 24),
	Row = Color3.fromRGB(52, 44, 38),
	Border = Color3.fromRGB(190, 150, 80),
	Gold = Color3.fromRGB(255, 210, 80),
	Text = Color3.fromRGB(245, 236, 220),
	Muted = Color3.fromRGB(170, 160, 145),
	Xp = Color3.fromRGB(90, 170, 255),
	Ether = Color3.fromRGB(120, 200, 255),
	-- « Récupérer gratuitement » (vert) et « Acheter en Robux » (bleu) restent distincts.
	Free = Color3.fromRGB(55, 135, 70),
	Robux = Color3.fromRGB(40, 110, 190),
	Danger = Color3.fromRGB(150, 50, 45),
	Disabled = Color3.fromRGB(75, 72, 70),
	info = Color3.fromRGB(60, 60, 72),
	success = Color3.fromRGB(50, 120, 60),
	error = Color3.fromRGB(140, 45, 40),
	reward = Color3.fromRGB(150, 110, 30),
}

function Ui.create(className: string, props, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

function Ui.corner(radius: number)
	return Ui.create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Ui.stroke()
	return Ui.create(
		"UIStroke",
		{ Color = Ui.Colors.Border, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
end

-- Léger relief vertical (haut plus clair) sur un panneau ou une ligne.
function Ui.sheen(strength: number?)
	local k = strength or 0.78
	return Ui.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(k, k, k)),
	})
end

-- Contour doré d'un bouton (remplace son contour sombre au lieu d'en ajouter un second).
function Ui.goldEdge(button: GuiObject, color: Color3?, thickness: number?)
	local edge = button:FindFirstChild("Edge") :: UIStroke?
	if not edge then
		edge = Ui.create("UIStroke", { Name = "Edge", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	end
	local e = edge :: UIStroke
	e.Color = color or Ui.Colors.Border
	e.Thickness = thickness or 2
	e.Transparency = 0
	return e
end

-- Petite animation d'échelle (UIScale) sur un objet.
local function scaleOf(obj: GuiObject): UIScale
	local s = obj:FindFirstChild("Pop") :: UIScale?
	if not s then
		s = Ui.create("UIScale", { Name = "Pop", Parent = obj })
	end
	return s :: UIScale
end

function Ui.tweenScale(obj: GuiObject, value: number, time: number?, style: Enum.EasingStyle?)
	TweenService:Create(
		scaleOf(obj),
		TweenInfo.new(time or 0.12, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = value }
	):Play()
end

-- Ouverture d'une fenêtre : rebond d'échelle et arrière-plan flouté.
local blur: BlurEffect? = nil
local openWindows = 0
function Ui.popIn(obj: GuiObject)
	scaleOf(obj).Scale = 0.88
	Ui.tweenScale(obj, 1, 0.22, Enum.EasingStyle.Back)
end

function Ui.setBlur(open: boolean)
	openWindows = math.max(0, openWindows + (if open then 1 else -1))
	if not blur then
		local b = Instance.new("BlurEffect")
		b.Name = "MenuBlur"
		b.Size = 0
		b.Parent = Lighting
		blur = b
	end
	TweenService:Create(blur :: BlurEffect, TweenInfo.new(0.25), { Size = if openWindows > 0 then 12 else 0 }):Play()
end

function Ui.padding(px: number)
	return Ui.create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function Ui.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.Fonts.Body,
		TextSize = 16,
		TextColor3 = Ui.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	return Ui.create("TextLabel", defaults)
end

-- Bouton large (tactile) et sélectionnable à la manette. Relief (dégradé), contour sombre
-- « Edge », texte cerné, et réaction au survol (souris) et à l'appui (souris, tactile, manette).
function Ui.button(props, onClick: (() -> ())?)
	local defaults = {
		AutoButtonColor = true,
		Font = Ui.Fonts.Bold,
		TextStrokeTransparency = 0.6,
		TextSize = 16,
		TextColor3 = Ui.Colors.Text,
		BackgroundColor3 = Ui.Colors.Free,
		Selectable = true,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = Ui.create("TextButton", defaults, {
		Ui.corner(8),
		Ui.create("UIStroke", {
			Name = "Edge",
			Color = Color3.fromRGB(20, 14, 10),
			Transparency = 0.35,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Ui.create("UIGradient", {
			Name = "Relief",
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 175, 175)),
			}),
		}),
	})
	button.MouseEnter:Connect(function()
		Ui.tweenScale(button, 1.04)
	end)
	button.MouseLeave:Connect(function()
		Ui.tweenScale(button, 1)
	end)
	button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			Ui.tweenScale(button, 0.94, 0.08)
		end
	end)
	button.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			Ui.tweenScale(button, 1, 0.12)
		end
	end)
	button.SelectionGained:Connect(function()
		Ui.tweenScale(button, 1.05)
	end)
	button.SelectionLost:Connect(function()
		Ui.tweenScale(button, 1)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Bouton à confirmation en deux temps (actions destructrices).
function Ui.confirmButton(props, onConfirm: () -> ())
	local original = props.Text
	local armedUntil = 0
	local button
	button = Ui.button(props, function()
		if os.clock() < armedUntil then
			armedUntil = 0
			button.Text = original
			onConfirm()
		else
			armedUntil = os.clock() + 4
			button.Text = "Confirmer ?"
			task.delay(4, function()
				if os.clock() >= armedUntil and button.Parent then
					button.Text = original
				end
			end)
		end
	end)
	return button
end

function Ui.list(parent: Instance, padding: number?)
	return Ui.create("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

return Ui
