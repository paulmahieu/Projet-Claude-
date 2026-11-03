--[[
	Interface du joueur : HUD (or, production, niveau, XP), notifications, boutique.
	Le client ne fait qu'AFFICHER l'état envoyé par le serveur (attributs du joueur).
	L'interface est générée par code pour rester versionnée ; elle pourra être remplacée
	par une interface dessinée dans Studio plus tard.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Products = require(Shared.Config.Products)
local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(35, 28, 22),
	Border = Color3.fromRGB(190, 150, 80),
	Gold = Color3.fromRGB(255, 210, 80),
	Text = Color3.fromRGB(245, 235, 215),
	Xp = Color3.fromRGB(90, 170, 255),
	info = Color3.fromRGB(60, 60, 70),
	success = Color3.fromRGB(50, 120, 60),
	error = Color3.fromRGB(140, 45, 40),
	reward = Color3.fromRGB(150, 110, 30),
}

local function create(className: string, props, children: { Instance }?): any
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

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke()
	return create("UIStroke", { Color = COLORS.Border, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local gui = create("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Panneau principal ------------------------------------------------------------------

local panel = create("Frame", {
	Name = "Stats",
	Position = UDim2.new(0, 12, 0, 12),
	Size = UDim2.fromOffset(250, 112),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.1,
	Parent = gui,
}, {
	corner(10),
	stroke(),
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	}),
})

local function label(name: string, y: number, height: number, color: Color3, bold: boolean?)
	return create("TextLabel", {
		Name = name,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Text = "",
		Parent = panel,
	})
end

local goldLabel = label("Gold", 0, 28, COLORS.Gold, true)
local incomeLabel = label("Income", 30, 18, COLORS.Text)
local levelLabel = label("Level", 52, 18, COLORS.Text)

local xpBack = create("Frame", {
	Position = UDim2.fromOffset(0, 76),
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
	Parent = panel,
}, { corner(6) })
local xpFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = COLORS.Xp,
	Parent = xpBack,
}, { corner(6) })

local trainingLabel = create("TextLabel", {
	Position = UDim2.new(0.5, -110, 0, 12),
	Size = UDim2.fromOffset(220, 30),
	BackgroundColor3 = COLORS.success,
	Visible = false,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = COLORS.Text,
	Text = "Entraînement en cours...",
	Parent = gui,
}, { corner(8), create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })

local function refresh()
	local gold = player:GetAttribute("Gold") or 0
	local income = player:GetAttribute("IncomePerSec") or 0
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("Xp") or 0
	local xpNext = player:GetAttribute("XpNext") or 1

	goldLabel.Text = "Or : " .. Formulas.formatNumber(gold)
	incomeLabel.Text = "+" .. Formulas.formatNumber(income) .. " or / seconde"
	levelLabel.Text =
		string.format("Niveau %d  (%s / %s XP)", level, Formulas.formatNumber(xp), Formulas.formatNumber(xpNext))
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(xp / xpNext, 0, 1), 1) }):Play()
	trainingLabel.Visible = player:GetAttribute("Training") == true
end

for _, name in { "Gold", "IncomePerSec", "Level", "Xp", "XpNext", "Training" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

-- Notifications ----------------------------------------------------------------------

local toastContainer = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(420, 300),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local toastCount = 0
local function toast(text: string, kind: string)
	toastCount += 1
	local frame = create("TextLabel", {
		LayoutOrder = toastCount,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = COLORS[kind] or COLORS.info,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = COLORS.Text,
		Text = text,
		Parent = toastContainer,
	}, { corner(8), create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

	local children = toastContainer:GetChildren()
	if #children > 6 then -- 5 toasts max + le layout
		for _, child in children do
			if child:IsA("TextLabel") and child ~= frame then
				child:Destroy()
				break
			end
		end
	end

	task.delay(if kind == "reward" then 7 else 4, function()
		if frame.Parent then
			local tween =
				TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			frame:Destroy()
		end
	end)
end

NotifyRemote.OnClientEvent:Connect(toast)

-- Boutique ---------------------------------------------------------------------------

local shopButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(110, 44),
	BackgroundColor3 = COLORS.reward,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = COLORS.Text,
	Text = "Boutique",
	Parent = gui,
}, { corner(10), stroke() })

local shop = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(360, 330),
	BackgroundColor3 = COLORS.Panel,
	Visible = false,
	Parent = gui,
}, { corner(12), stroke() })

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	Font = Enum.Font.Fantasy,
	TextSize = 26,
	TextColor3 = COLORS.Gold,
	Text = "Boutique du royaume",
	Parent = shop,
})

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = COLORS.error,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = COLORS.Text,
	Text = "X",
	Parent = shop,
}, { corner(6) })

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 46),
	Size = UDim2.new(1, -20, 1, -56),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = shop,
}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function shopEntry(order: number, name: string, description: string, enabled: boolean, onBuy: () -> ())
	local row = create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 58),
		BackgroundColor3 = Color3.fromRGB(55, 45, 35),
		Parent = list,
	}, { corner(8) })
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -110, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Gold,
		Text = name,
		Parent = row,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -110, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.Text,
		Text = description,
		Parent = row,
	})
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(90, 36),
		BackgroundColor3 = if enabled then COLORS.success else COLORS.info,
		AutoButtonColor = enabled,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = COLORS.Text,
		Text = if enabled then "Acheter" else "Bientôt",
		Parent = row,
	}, { corner(8) })
	if enabled then
		button.Activated:Connect(onBuy)
	end
end

local order = 0
for _, key in { "DoubleGold", "FastTraining" } do
	local pass = Products.GamePasses[key]
	order += 1
	shopEntry(order, pass.Name, pass.Description, pass.GamePassId ~= 0, function()
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
	end)
end
for _, product in Products.DevProducts do
	order += 1
	shopEntry(order, product.Name, product.Description, product.ProductId ~= 0, function()
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
	end)
end

shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)
closeButton.Activated:Connect(function()
	shop.Visible = false
end)
