--[[
	Petits utilitaires d'interface : création d'instances et style commun.
]]

local Ui = {}

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
		Font = Enum.Font.Gotham,
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

-- Bouton large (tactile) et sélectionnable à la manette.
function Ui.button(props, onClick: (() -> ())?)
	local defaults = {
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Ui.Colors.Text,
		BackgroundColor3 = Ui.Colors.Free,
		Selectable = true,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = Ui.create("TextButton", defaults, { Ui.corner(8) })
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
