--[[
	StreetUi : affichage de la Rue des boss pour le joueur local.
	- Portes LOCALES : une barrière rouge ferme chaque section non terminée. Elle n'existe que
	  chez ce joueur (chacun progresse à son étape dans la même rue). Le serveur reste
	  l'autorité : il ne fait apparaître les ennemis que dans la section de l'étape en cours.
	- Panneau d'étape : numéro, Puissance conseillée (rouge si la tienne est plus faible),
	  ennemis restants, meilleure étape, ennemis vaincus.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Street = require(Shared.Config.Street)
local Ui = require(script.Parent.Ui)

local StreetUi = {}

local player = Players.LocalPlayer
local C = Ui.Colors

local origin = CFrame.lookAt(
	Vector3.new(Street.Origin[1], Street.Origin[2], Street.Origin[3]),
	Vector3.new(Street.Origin[1] + 1, Street.Origin[2], Street.Origin[3])
)

function StreetUi.start(gui: ScreenGui)
	-- Portes locales -----------------------------------------------------------------------
	local folder = Instance.new("Folder")
	folder.Name = "LocalStreetGates"
	folder.Parent = workspace
	local gates = {}
	for i = 1, Street.Sections do
		local cf = origin * CFrame.new(0, 6, -i * Street.SectionLength)
		local wall = Instance.new("Part")
		wall.Name = "Gate" .. i
		wall.Anchored = true
		wall.CanCollide = true
		wall.CastShadow = false
		wall.Material = Enum.Material.ForceField
		wall.Color = Color3.fromRGB(255, 70, 70)
		wall.Size = Vector3.new(Street.Width - 2, 12, 1)
		wall.CFrame = cf
		wall.Parent = folder
		local gui3d = Instance.new("BillboardGui")
		gui3d.Size = UDim2.fromScale(14, 3)
		gui3d.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		gui3d.MaxDistance = 120
		gui3d.AlwaysOnTop = true
		gui3d.Adornee = wall
		gui3d.Parent = wall
		local label = Ui.label({
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0,
			Parent = gui3d,
		})
		gates[i] = { Wall = wall, Label = label }
	end

	local function refreshGates()
		local stage = player:GetAttribute("StreetStage") or 1
		local section = Formulas.streetSection(stage, Street)
		for i, gate in gates do
			local closed = i >= section -- la section i doit être terminée pour franchir la porte i
			gate.Wall.Transparency = if closed then 0.35 else 1
			gate.Wall.CanCollide = closed
			if i == section then
				local s = stage
				gate.Label.Text = string.format(
					"%sÉtape %d\nPuissance conseillée %d",
					if Formulas.streetIsPatron(s, Street) then "PATRON · " else "",
					s,
					Formulas.streetRecommendedPower(s, Street)
				)
			else
				gate.Label.Text = ""
			end
		end
	end
	player:GetAttributeChangedSignal("StreetStage"):Connect(refreshGates)
	refreshGates()

	-- Panneau d'étape -----------------------------------------------------------------------
	local panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0.7, 0, 0, 96),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(), Ui.sheen(), Ui.create("UISizeConstraint", { MaxSize = Vector2.new(460, 96) }) })
	local title = Ui.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 34),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0,
		Parent = panel,
	})
	local power = Ui.label({
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, 22),
		Font = Ui.Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})
	local info = Ui.label({
		Position = UDim2.fromOffset(10, 64),
		Size = UDim2.new(1, -20, 0, 24),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Muted,
		Parent = panel,
	})

	local function refreshPanel()
		local inside = player:GetAttribute("InStreet") == true
		panel.Visible = inside
		if not inside then
			return
		end
		local stage = player:GetAttribute("StreetStage") or 1
		local recommended = player:GetAttribute("StreetRecPower") or Formulas.streetRecommendedPower(stage, Street)
		local mine = player:GetAttribute("Power") or 0
		local remaining = player:GetAttribute("StreetRemaining") or 0
		title.Text =
			string.format("%sÉtape %d", if player:GetAttribute("StreetPatron") then "PATRON · " else "", stage)
		power.Text = string.format("Puissance conseillée %d · la tienne %d", recommended, mine)
		power.TextColor3 = if mine >= recommended then Color3.fromRGB(120, 230, 120) else Color3.fromRGB(255, 110, 100)
		info.Text = string.format(
			"%s · meilleure étape %d · %s ennemis vaincus",
			if remaining > 0 then remaining .. " restant(s)" else "Avance jusqu'à la vague !",
			player:GetAttribute("StreetBest") or 0,
			Formulas.formatNumber(player:GetAttribute("StreetKills") or 0)
		)
	end
	for _, name in
		{
			"InStreet",
			"StreetStage",
			"StreetRecPower",
			"Power",
			"StreetRemaining",
			"StreetBest",
			"StreetKills",
			"StreetPatron",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(refreshPanel)
	end
	refreshPanel()
end

return StreetUi
