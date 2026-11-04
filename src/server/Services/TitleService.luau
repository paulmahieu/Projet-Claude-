--[[
	TitleService : titres gagnés par le travail et plaque visible au-dessus de chaque joueur.

	Plaque (visible par tous, à moins de 60 studs, jamais cachée par un bâtiment) :
	  titre coloré · pseudo · 🔥 Puissance · 🏆 trophées · 🔁 renaissances · 🏰 bastion (membres)
	Le nom par défaut de Roblox est masqué pour éviter le doublon.

	Titres : conditions sur des statistiques durables (Config/Titles). Un nouveau titre est
	annoncé à tout le serveur et équipé s'il est plus prestigieux ; le joueur peut en choisir
	un autre (Menu > Titres). Le titre « Gardien d'Éther » dépend d'un pass (vérifié serveur).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Titles = require(Shared.Config.Titles)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)
local MonetizationService = require(script.Parent.MonetizationService)
local Notifier = require(script.Parent.Notifier)

local TitleService = {}

local REFRESH = 2
local titleById = {}
for _, title in Titles do
	titleById[title.Id] = title
end

local function statsOf(player: Player, profile)
	return {
		Rebirths = profile.Rebirths,
		BestLevel = math.max(profile.BestLevel or 1, profile.Level),
		Harvests = profile.Stats.Harvests,
		StreetBest = profile.Street.Best,
		TrophiesEarned = profile.Stats.TrophiesEarned,
		ForestKills = profile.BossKills.ForestGuardian or 0,
		GolemKills = profile.BossKills.MineGolem or 0,
		Passes = { TitleWarden = MonetizationService.ownsPass(player, "TitleWarden") },
	}
end

local function color(rgb): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Titre affiché : celui choisi s'il est toujours débloqué, sinon le plus prestigieux.
local function equippedTitle(profile, unlocked)
	for _, title in unlocked do
		if title.Id == profile.Title then
			return title
		end
	end
	return unlocked[1] or Titles[1]
end

-- Plaque ---------------------------------------------------------------------------------

local function line(parent: Instance, order: number, height: number, font, textColor: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Line" .. order
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = parent
	return label
end

local function ensurePlate(player: Player): BillboardGui?
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local plate = head:FindFirstChild("Nameplate") :: BillboardGui?
	if plate then
		return plate
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- évite le double nom
	end
	plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(220, 92)
	plate.StudsOffset = Vector3.new(0, 3.4, 0)
	plate.AlwaysOnTop = true
	plate.LightInfluence = 0
	plate.MaxDistance = 60
	plate.Adornee = head
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = plate
	line(plate, 1, 20, Enum.Font.FredokaOne, Color3.new(1, 1, 1)) -- titre
	line(plate, 2, 24, Enum.Font.FredokaOne, Color3.new(1, 1, 1)) -- pseudo
	line(plate, 3, 22, Enum.Font.GothamBold, Color3.fromRGB(255, 220, 120)) -- puissance, trophées
	line(plate, 4, 18, Enum.Font.GothamBold, Color3.fromRGB(150, 205, 255)) -- bastion
	plate.Parent = head
	return plate
end

local function updatePlate(player: Player, title)
	local plate = ensurePlate(player)
	local profile = ProfileService.get(player)
	if not plate or not profile then
		return
	end
	local l1 = plate:FindFirstChild("Line1") :: TextLabel
	local l2 = plate:FindFirstChild("Line2") :: TextLabel
	local l3 = plate:FindFirstChild("Line3") :: TextLabel
	local l4 = plate:FindFirstChild("Line4") :: TextLabel
	l1.Text = "« " .. title.Name .. " »"
	l1.TextColor3 = color(title.Color)
	l2.Text = player.DisplayName
	local rebirths = if profile.Rebirths > 0 then string.format("   🔁 %d", profile.Rebirths) else ""
	l3.Text = string.format(
		"🔥 %s   🏆 %s%s",
		Formulas.formatNumber(ProfileService.power(player)),
		Formulas.formatNumber(profile.Stats.TrophiesEarned),
		rebirths
	)
	local bastion = player:GetAttribute("BastionName")
	local size = player:GetAttribute("BastionSize") or 1
	l4.Text = if bastion
		then string.format("🏰 %s%s", tostring(bastion), if size > 1 then string.format(" (%d)", size) else "")
		else ""
end

-- Titres ---------------------------------------------------------------------------------

local function refresh(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	local unlocked = Formulas.unlockedTitles(Titles, statsOf(player, profile))
	local current = equippedTitle(profile, unlocked)
	local ids = {}
	for _, title in unlocked do
		table.insert(ids, title.Id)
		if not profile.TitlesSeen[title.Id] then
			profile.TitlesSeen[title.Id] = true
			if title.Order > 1 then
				Notifier.broadcast(
					string.format("🎖 %s a obtenu le titre « %s » !", player.DisplayName, title.Name),
					"reward"
				)
				-- Équipé automatiquement s'il est plus prestigieux que l'actuel.
				if title.Order > current.Order then
					profile.Title = title.Id
					current = title
				end
			end
		end
	end
	player:SetAttribute("TitlesUnlocked", table.concat(ids, ","))
	player:SetAttribute("Title", current.Id)
	updatePlate(player, current)
end

function TitleService.equip(player: Player, titleId: string)
	local profile = ProfileService.get(player)
	local title = titleById[titleId]
	if not profile or not title then
		return { ok = false, msg = Texts.Loading }
	end
	if not Formulas.titleUnlocked(title, statsOf(player, profile)) then
		return { ok = false, msg = "Titre pas encore débloqué : " .. title.Hint }
	end
	profile.Title = titleId
	refresh(player)
	return { ok = true, msg = "Titre équipé : " .. title.Name }
end

function TitleService.start()
	ProfileService.onLoaded(function(player, profile)
		-- Titres déjà mérités avant l'arrivée de ce système : marqués sans annonce.
		if next(profile.TitlesSeen) == nil then
			for _, title in Formulas.unlockedTitles(Titles, statsOf(player, profile)) do
				profile.TitlesSeen[title.Id] = true
			end
		end
		refresh(player)
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			task.defer(refresh, player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	task.spawn(function()
		while true do
			task.wait(REFRESH)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(refresh, player)
				if not ok then
					warn("[TitleService] " .. tostring(err))
				end
			end
		end
	end)
end

return TitleService
