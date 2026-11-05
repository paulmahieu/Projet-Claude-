--[[
	StreetThemes : thème d'arène de la Rue des boss, propre à chaque joueur.

	La rue est partagée par tous les joueurs du serveur, mais chacun voit le décor de SON étape :
	le thème change toutes les Street.ThemeEvery (5) étapes, dans l'ordre de Street.Themes
	(Cristaux, Glaces, Sanctuaire, Forge), puis recommence. Les 10 sections du tour en cours sont
	habillées (2 thèmes par tour) ; le décor générique de la rue est masqué pour ce joueur
	(LocalTransparencyModifier : rien n'est modifié sur le serveur, collisions inchangées).
	Le faux ciel de la salle prend la couleur du thème de la section où se trouve le joueur, et le
	nom de l'arène s'affiche à chaque changement de thème.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Street = require(Shared.Config.Street)
local Formulas = require(Shared.Formulas)
local ArenaThemes = require(Shared.ArenaThemes)
local Ui = require(script.Parent.Ui)

local StreetThemes = {}

local player = Players.LocalPlayer
local origin = CFrame.new(Street.Origin[1], Street.Origin[2], Street.Origin[3])

-- Décor générique de la rue remplacé par les thèmes (noms des pièces de Models.street).
local HIDDEN = {
	Carpet = true,
	Sconce = true,
	Flame = true,
	Banner = true,
	Merlon = true,
	Wall = true,
	ArchPillar = true,
	ArchTop = true,
	ArchGem = true,
}

local folder: Folder? = nil
local builtKey = ""
local hiddenParts: { BasePart } = {}
local skyParts: { [BasePart]: Color3 } = {}
local lastTheme = 0

local function geometry(): Instance?
	local world = workspace:FindFirstChild("World")
	local street = world and world:FindFirstChild("Street")
	return street and street:FindFirstChild("Geometry")
end

local function setGenericHidden(hidden: boolean)
	if hidden and #hiddenParts == 0 then
		local geo = geometry()
		if not geo then
			return
		end
		for _, p in geo:GetDescendants() do
			if p:IsA("BasePart") and (HIDDEN[p.Name] or string.sub(p.Name, 1, 6) == "Carpet") then
				table.insert(hiddenParts, p)
			elseif p:IsA("BasePart") and p.Name == "FalseSky" then
				skyParts[p] = p.Color
			end
		end
	end
	for _, p in hiddenParts do
		p.LocalTransparencyModifier = if hidden then 1 else 0
		local l = p:FindFirstChildOfClass("PointLight")
		if l then
			l.Enabled = not hidden
		end
	end
	if not hidden then
		for p, color in skyParts do
			p.Color = color
		end
	end
end

-- Nom de l'arène affiché à l'écran à chaque changement de thème.
local banner: TextLabel? = nil
local function announce(name: string)
	if not banner then
		local gui = Instance.new("ScreenGui")
		gui.Name = "StreetThemeTitle"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = player:WaitForChild("PlayerGui")
		banner = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.16),
			Size = UDim2.fromOffset(520, 56),
			Font = Ui.Fonts.Title,
			TextSize = 40,
			TextColor3 = Color3.fromRGB(255, 232, 170),
			TextStrokeTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = 1,
			TextStrokeColor3 = Color3.fromRGB(30, 20, 10),
			Parent = gui,
		})
	end
	local label = banner :: TextLabel
	label.Text = name
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.2
	Ui.popIn(label)
	task.delay(2.6, function()
		if label.Text == name then
			TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
	builtKey = ""
	setGenericHidden(false)
	lastTheme = 0
end

local function refresh()
	if player:GetAttribute("InStreet") ~= true then
		clear()
		return
	end
	local stage = player:GetAttribute("StreetStage") or 1
	-- Thèmes des 10 sections du tour en cours
	local themes = {}
	for section = 1, Street.Sections do
		local s = Formulas.streetStageOfSection(stage, section, Street)
		themes[section] = Street.Themes[Formulas.streetTheme(s, Street)].Id
	end
	local key = table.concat(themes, ",")
	if key ~= builtKey then
		if folder then
			folder:Destroy()
		end
		local f = Instance.new("Folder")
		f.Name = "StreetThemes"
		f.Parent = workspace
		folder = f
		for section = 1, Street.Sections do
			local frame = origin * CFrame.new(0, 0, -(section - 1) * Street.SectionLength - Street.SectionLength / 2)
			ArenaThemes.buildSection(themes[section], frame, f, section * 13 + stage, section == 1)
			if section % 3 == 0 then
				task.wait() -- étale la construction sur plusieurs images
			end
		end
		builtKey = key
		setGenericHidden(true)
	end
	-- Ciel et titre selon le thème de l'étape en cours
	local index = Formulas.streetTheme(stage, Street)
	local def = Street.Themes[index]
	local sky = ArenaThemes.skyColor(def.Id)
	if sky then
		for p in skyParts do
			p.Color = sky
		end
	end
	if index ~= lastTheme then
		lastTheme = index
		announce(def.Name)
	end
end

function StreetThemes.start()
	local busy = false
	local function schedule()
		if busy then
			return
		end
		busy = true
		task.defer(function()
			local ok, err = pcall(refresh)
			if not ok then
				warn("[StreetThemes] " .. tostring(err))
			end
			busy = false
		end)
	end
	player:GetAttributeChangedSignal("InStreet"):Connect(schedule)
	player:GetAttributeChangedSignal("StreetStage"):Connect(schedule)
	schedule()
end

return StreetThemes
