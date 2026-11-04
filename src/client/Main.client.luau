--[[
	Client — Bastions d'Éther.
	Affiche l'état envoyé par le serveur et transmet des INTENTIONS (jamais de montants).

	Commandes (cahier §12), toutes utilisables sans souris :
	  Menu : M (clavier) · Y (manette) · bouton « Menu » (tactile). Fermer : B (manette) / X.
	  Dans le menu, la manette navigue entre les boutons (sélection visible).
	  Construire, récolter, s'entraîner : ProximityPrompt (E / X manette / toucher).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Structures = require(Shared.Config.Structures)
local Materials = require(Shared.Config.Materials)
local Tree = require(Shared.Config.Tree)
local Products = require(Shared.Config.Products)
local Texts = require(Shared.Config.Texts)
local Pets = require(Shared.Config.Pets)
local Rebirth = require(Shared.Config.Rebirth)
local Rewards = require(Shared.Config.Rewards)
local Titles = require(Shared.Config.Titles)
local Quests = require(Shared.Config.Quests)
local Pass = require(Shared.Config.Pass)
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)
local PetFollowers = require(script.Parent.PetFollowers)
local CombatUi = require(script.Parent.CombatUi)
local StreetUi = require(script.Parent.StreetUi)
local FarmUi = require(script.Parent.FarmUi)
local DiagnosticsUi = require(script.Parent.DiagnosticsUi)
local ProximityPromptService = game:GetService("ProximityPromptService")
local PolicyService = game:GetService("PolicyService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request") :: RemoteFunction
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local GroupUpdate = Remotes:WaitForChild("GroupUpdate") :: RemoteEvent
local PetsUpdate = Remotes:WaitForChild("PetsUpdate") :: RemoteEvent

local player = Players.LocalPlayer
local C = Ui.Colors

local groupState = nil
local petState = nil -- { Pets, Equipped, Slots, Size }
local devTools = false
local menuOpen = false
local currentTab = "Group"
local toast -- défini plus bas

local function request(action: string, payload)
	local ok, res = pcall(function()
		return Request:InvokeServer(action, payload)
	end)
	if not ok or type(res) ~= "table" then
		res = { ok = false, msg = "Connexion au serveur impossible." }
	end
	if res.msg then
		toast(res.msg, if res.ok then "success" else "error")
	end
	return res
end

-- Racine ------------------------------------------------------------------------------

local gui = Ui.create("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	-- Évite les boutons Roblox (menu, chat) en haut de l'écran et les zones non sûres (encoches).
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
-- La liste des joueurs de Roblox recouvrait le panneau du bastion (haut droite) ; les joueurs
-- du serveur restent visibles dans Menu > Groupe et sur les panneaux de classement.
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- Diagnostic (Studio) démarré tout de suite : il doit pouvoir afficher les erreurs même si la
-- suite de ce script échoue.
DiagnosticsUi.start(gui)

-- Monnaies (gauche, sous la colonne de boutons) et barre de niveau (bas, centre) ---------
-- Disposition inspirée des simulateurs : gros boutons à icônes à gauche, monnaies dessous,
-- grande barre de niveau en bas au centre ; couleurs bois, or et cristal du jeu.

local currencies = Ui.create("Frame", {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 10, 0, 314),
	Size = UDim2.fromOffset(170, 64),
	BackgroundTransparency = 1,
	Parent = gui,
})
local function currencyLine(y: number, color: Color3)
	return Ui.label({
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		Parent = currencies,
	})
end
local goldLabel = currencyLine(0, C.Gold)
local powerLabel = currencyLine(32, Color3.fromRGB(255, 225, 140))

local levelBar = Ui.create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.5, 0, 0, 40),
	BackgroundColor3 = Color3.fromRGB(30, 24, 18),
	Parent = gui,
}, {
	Ui.corner(10),
	Ui.stroke(),
	Ui.create("UISizeConstraint", { MinSize = Vector2.new(280, 40), MaxSize = Vector2.new(520, 40) }),
})
local xpBack = Ui.create("Frame", {
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -8, 1, -8),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	Parent = levelBar,
}, { Ui.corner(7) })
local xpFill = Ui.create(
	"Frame",
	{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(240, 190, 60), Parent = xpBack },
	{
		Ui.corner(7),
		Ui.create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(230, 150, 40)),
		}),
	}
)
local levelLabel = Ui.label({
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.FredokaOne,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0,
	ZIndex = 3,
	Parent = levelBar,
})
local objectiveLabel = Ui.label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -58),
	Size = UDim2.new(0.5, 0, 0, 22),
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = C.Ether,
	TextStrokeTransparency = 0.2,
	Parent = gui,
})
Ui.create("UISizeConstraint", { MinSize = Vector2.new(280, 22), MaxSize = Vector2.new(560, 22) }).Parent =
	objectiveLabel

-- Panneau du groupe (haut droite) -----------------------------------------------------

local groupPanel = Ui.create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(220, 40 + 22 * #Materials),
	BackgroundColor3 = C.Panel,
	BackgroundTransparency = 0.1,
	Parent = gui,
}, { Ui.corner(10), Ui.stroke(), Ui.padding(10) })
local groupTitle = Ui.label({
	Size = UDim2.new(1, 0, 0, 20),
	Font = Enum.Font.GothamBold,
	TextColor3 = C.Ether,
	TextScaled = true,
	Parent = groupPanel,
})
local materialLabels = {}
for i, mat in Materials do
	materialLabels[mat.Id] = Ui.label({
		Position = UDim2.fromOffset(0, 4 + 22 * i),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Color3.fromRGB(mat.Color[1], mat.Color[2], mat.Color[3]):Lerp(Color3.new(1, 1, 1), 0.35),
		Parent = groupPanel,
	})
end

-- Encart cadeaux (sous le panneau du groupe) : temps de jeu et quotidien
local giftPanel = Ui.button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10 + 40 + 22 * #Materials + 8),
	Size = UDim2.fromOffset(220, 46),
	BackgroundColor3 = C.Panel,
	AutoButtonColor = true,
	Text = "",
	Parent = gui,
})
Ui.stroke().Parent = giftPanel
local giftLabel = Ui.label({
	Position = UDim2.fromOffset(10, 3),
	Size = UDim2.new(1, -20, 0, 20),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = C.Gold,
	Parent = giftPanel,
})
local giftBarBack = Ui.create("Frame", {
	Position = UDim2.new(0, 10, 0, 27),
	Size = UDim2.new(1, -20, 0, 10),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	Parent = giftPanel,
}, { Ui.corner(5) })
local giftBar = Ui.create(
	"Frame",
	{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Free, Parent = giftBarBack },
	{ Ui.corner(5) }
)
local dailyBadge = Ui.create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(16, 16),
	BackgroundColor3 = Color3.fromRGB(230, 50, 50),
	Visible = false,
	Parent = giftPanel,
}, { Ui.corner(8) })

local function refreshGifts()
	local played = player:GetAttribute("PlaySeconds") or 0
	local nextTier = nil
	local previous = 0
	for _, tier in Rewards.Playtime do
		if played < tier.Minutes * 60 then
			nextTier = tier
			break
		end
		previous = tier.Minutes * 60
	end
	if nextTier then
		local goal = nextTier.Minutes * 60
		local remaining = goal - played
		giftLabel.Text = string.format("Cadeau dans %d:%02d", remaining // 60, remaining % 60)
		giftBar.Size = UDim2.fromScale(math.clamp((played - previous) / (goal - previous), 0, 1), 1)
	else
		giftLabel.Text = "Cadeaux du jour terminés"
		giftBar.Size = UDim2.fromScale(1, 1)
	end
	local claimable = player:GetAttribute("DailyClaimable") == true
	dailyBadge.Visible = claimable
	if claimable then
		giftLabel.Text = "Quotidien prêt ! · " .. giftLabel.Text
	end
end
for _, name in { "PlaySeconds", "DailyClaimable" } do
	player:GetAttributeChangedSignal(name):Connect(refreshGifts)
end
refreshGifts()

-- Bandeau d'état (haut centre) --------------------------------------------------------

local banner = Ui.label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(380, 34),
	BackgroundTransparency = 0,
	BackgroundColor3 = C.success,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 15,
	Visible = false,
	Parent = gui,
})
Ui.corner(8).Parent = banner
Ui.create("UISizeConstraint", { MaxSize = Vector2.new(380, 60) }).Parent = banner

local STATE_TEXT = {
	Loading = Texts.Loading,
	Remote = Texts.GroupRemote,
	Error = Texts.GroupError,
	NoPlot = Texts.NoPlot,
	ReadOnly = Texts.ReadOnly,
}

-- Mise à jour du HUD ------------------------------------------------------------------

local function ownedSet()
	local set = {}
	if groupState and groupState.Structures then
		for _, id in groupState.Structures do
			set[id] = true
		end
	end
	return set
end

local function objectiveText(): string
	-- Mission d'introduction en cours (prioritaire tant qu'il en reste).
	local questIndex = player:GetAttribute("QuestIndex")
	local quest = questIndex and Quests.Personal[questIndex]
	if quest then
		return string.format(
			"📜 Mission %d/%d : %s (%d/%d)",
			questIndex,
			#Quests.Personal,
			quest.Text,
			player:GetAttribute("QuestProgress") or 0,
			quest.Target
		)
	end
	if not groupState or not groupState.Materials then
		return Texts.Loading
	end
	local nextStructure = Formulas.availableStructures(Structures, ownedSet())[1]
	if not nextStructure then
		return "Objectif : entraîne-toi et améliore ta Concentration"
	end
	if Formulas.canAfford(groupState.Materials, nextStructure.Cost) then
		return "Objectif : construis « " .. nextStructure.Name .. " » (socle vert)"
	end
	local parts = {}
	for _, m in Formulas.missingMaterials(Materials, groupState.Materials, nextStructure.Cost) do
		table.insert(parts, m.Missing .. " " .. m.Name)
	end
	return "Objectif : récolte " .. table.concat(parts, ", ") .. " pour « " .. nextStructure.Name .. " »"
end

local function refreshHud()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("TrainXp") or 0
	local xpNext = player:GetAttribute("XpNext") or 1
	goldLabel.Text = "💰 " .. Formulas.formatNumber(player:GetAttribute("Gold") or 0)
	powerLabel.Text = "🏆 " .. Formulas.formatNumber(player:GetAttribute("Trophies") or 0)
	levelLabel.Text = string.format(
		"Niveau %d   ·   %s / %s XP   ·   🔥 Puissance %s",
		level,
		Formulas.formatNumber(xp),
		Formulas.formatNumber(xpNext),
		Formulas.formatNumber(player:GetAttribute("Power") or 10)
	)
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(math.clamp(xp / xpNext, 0, 1), 1) })
		:Play()
	objectiveLabel.Text = objectiveText()

	if groupState and groupState.Name then
		groupTitle.Text = string.format("%s · niv. %d", groupState.Name, groupState.BastionLevel or 1)
		for _, mat in Materials do
			materialLabels[mat.Id].Text =
				string.format("%s : %s", mat.Name, Formulas.formatNumber(groupState.Materials[mat.Id] or 0))
		end
	end

	local profileState = player:GetAttribute("ProfileState")
	local groupStateAttr = player:GetAttribute("GroupState")
	if profileState == "Loading" or profileState == "Error" then
		banner.Text = if profileState == "Error" then Texts.LoadError else Texts.Loading
		banner.BackgroundColor3 = if profileState == "Error" then C.error else C.info
		banner.Visible = true
	elseif groupStateAttr and STATE_TEXT[groupStateAttr] then
		banner.Text = STATE_TEXT[groupStateAttr]
		banner.BackgroundColor3 = if groupStateAttr == "Loading" then C.info else C.error
		banner.Visible = true
	elseif (player:GetAttribute("FarmZone") or 0) > 0 then
		banner.Text = string.format("Champ des champions · zone x%s", tostring(player:GetAttribute("FarmZone")))
		banner.BackgroundColor3 = C.success
		banner.Visible = true
	elseif player:GetAttribute("Training") then
		banner.Text = "Entraînement · " .. tostring(player:GetAttribute("TrainingRate") or "")
		banner.BackgroundColor3 = C.success
		banner.Visible = true
	else
		banner.Visible = false
	end
end

for _, name in
	{
		"Gold",
		"Level",
		"TrainXp",
		"XpNext",
		"Power",
		"Training",
		"TrainingRate",
		"ProfileState",
		"GroupState",
		"FarmZone",
		"Trophies",
		"QuestIndex",
		"QuestProgress",
	}
do
	player:GetAttributeChangedSignal(name):Connect(refreshHud)
end

-- Notifications -----------------------------------------------------------------------

local toastContainer = Ui.create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -88),
	Size = UDim2.new(0.9, 0, 0, 240),
	BackgroundTransparency = 1,
	Parent = gui,
}, { Ui.create("UISizeConstraint", { MaxSize = Vector2.new(440, 240) }) })
Ui.create("UIListLayout", {
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = toastContainer,
})

local toastCount = 0
function toast(text: string, kind: string?)
	toastCount += 1
	local frame = Ui.label({
		LayoutOrder = toastCount,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 0,
		BackgroundColor3 = C[kind or "info"] or C.info,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		Text = text,
		Parent = toastContainer,
	})
	Ui.corner(8).Parent = frame
	Ui.padding(6).Parent = frame

	local labels = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #labels - 4 do
		labels[i]:Destroy()
	end

	task.delay(if kind == "reward" then 8 else 4, function()
		if frame.Parent then
			local tween =
				TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			frame:Destroy()
		end
	end)
end

NotifyRemote.OnClientEvent:Connect(toast)

-- Menu --------------------------------------------------------------------------------

local menuButton = Ui.button({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -12),
	Size = UDim2.fromOffset(110, 64), -- assez grand pour le tactile
	BackgroundColor3 = C.reward,
	TextSize = 18,
	Text = "Menu",
	Parent = gui,
})
Ui.stroke().Parent = menuButton

-- Bouton « Mon bastion » : les joueurs apparaissent au point d'accueil (portails, œufs).
local homeButton = Ui.button({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -132, 1, -12),
	Size = UDim2.fromOffset(130, 64),
	BackgroundColor3 = C.Robux,
	TextSize = 17,
	Text = "Mon bastion",
	Parent = gui,
}, function()
	request("GoToBastion", {})
end)
Ui.stroke().Parent = homeButton

local menu = Ui.create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(0.94, 0, 0.8, 0),
	BackgroundColor3 = C.Panel,
	Visible = false,
	Parent = gui,
}, { Ui.corner(12), Ui.stroke(), Ui.create("UISizeConstraint", { MaxSize = Vector2.new(580, 540) }) })

local tabBar = Ui.create("Frame", {
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(1, -70, 0, 44),
	BackgroundTransparency = 1,
	Parent = menu,
})
Ui.create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = tabBar,
})

local closeButton = Ui.button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = C.Danger,
	Text = "X",
	Parent = menu,
})

local content = Ui.create("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 62),
	Size = UDim2.new(1, -20, 1, -72),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Selectable = false,
	Parent = menu,
})

local order = 0
local function clearContent()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	Ui.list(content, 6)
	order = 0
end

local function row(height: number?)
	order += 1
	return Ui.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height or 56),
		BackgroundColor3 = C.Row,
		Parent = content,
	}, { Ui.corner(8) })
end

local function heading(text: string)
	order += 1
	return Ui.label({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 28),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = C.Gold,
		Text = text,
		Parent = content,
	})
end

local function rowText(parent, title: string, subtitle: string?, rightReserve: number)
	Ui.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -(rightReserve + 14), 0, 22),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	})
	if subtitle then
		Ui.label({
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -(rightReserve + 14), 1, -30),
			TextSize = 13,
			TextColor3 = C.Muted,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = subtitle,
			Parent = parent,
		})
	end
end

local function rightButton(parent, text: string, color: Color3, index: number, onClick, confirm: boolean?)
	local props = {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8 - (index - 1) * 118, 0.5, 0),
		Size = UDim2.fromOffset(112, 44),
		BackgroundColor3 = color,
		TextSize = 14,
		Text = text,
		Parent = parent,
	}
	if not onClick then
		props.AutoButtonColor = false
	end
	return if confirm then Ui.confirmButton(props, onClick) else Ui.button(props, onClick)
end

local renderTab -- défini plus bas

-- Onglet Groupe
local pendingAbandonConfirm = false
-- Amis en ligne dans cette expérience (lu par le client : Player:GetFriendsOnline).
local friendsOnline: { any }? = nil
local friendsLoading = false
local function loadFriends()
	if friendsLoading then
		return
	end
	friendsLoading = true
	task.spawn(function()
		local ok, list = pcall(function()
			return player:GetFriendsOnline(200)
		end)
		local result = {}
		if ok and type(list) == "table" then
			for _, f in list do
				-- LocationType 4 = dans une expérience ; même lieu = même jeu.
				if f.PlaceId == game.PlaceId and f.VisitorId then
					table.insert(result, {
						UserId = f.VisitorId,
						Name = f.DisplayName or f.UserName,
						JobId = f.GameId,
						Here = f.GameId == game.JobId or Players:GetPlayerByUserId(f.VisitorId) ~= nil,
					})
				end
			end
		end
		friendsOnline = result
		friendsLoading = false
		if menuOpen and currentTab == "Group" then
			renderTab()
		end
	end)
end

local function renderFriends()
	heading("Amis en jeu (Rue des boss, œufs et Champ sont communs à tout le serveur)")
	if friendsOnline == nil then
		heading("Recherche des amis en ligne...")
		loadFriends()
		return
	end
	local list = friendsOnline :: { any }
	if #list == 0 then
		heading("(aucun ami Roblox dans Bastions d'Éther pour l'instant)")
	end
	for _, f in list do
		local r = row(52)
		rowText(r, tostring(f.Name), if f.Here then "sur ce serveur" else "sur un autre serveur", 130)
		rightButton(r, if f.Here then "Visiter" else "Rejoindre", if f.Here then C.Free else C.info, 1, function()
			request("JoinFriend", { UserId = f.UserId, JobId = if f.Here then nil else f.JobId })
		end)
	end
	local refresh = row(48)
	rowText(refresh, "Actualiser la liste", nil, 130)
	rightButton(refresh, "Actualiser", C.Row, 1, function()
		friendsOnline = nil
		renderTab()
	end)
end

local function renderGroup()
	local state = groupState
	if player:GetAttribute("GroupState") == "Remote" then
		heading("Ton bastion est ouvert sur un autre serveur")
		local r = row(60)
		rowText(r, "Rejoins tes compagnons de bastion", "Téléportation vers le serveur qui l'a ouvert.", 200)
		local b = rightButton(r, "Rejoindre mon bastion", C.Free, 1, function()
			request("JoinBastionServer", {})
		end)
		b.Size = UDim2.fromOffset(190, 44)
	end
	if not state or not state.Name then
		heading(Texts.Loading)
		renderFriends()
		return
	end

	if state.Invite then
		heading("Invitation")
		local r = row(64)
		rowText(r, state.Invite.FromName .. " t'invite", "« " .. state.Invite.GroupName .. " »", 236)
		rightButton(r, if pendingAbandonConfirm then "Confirmer" else "Accepter", C.Free, 2, function()
			local res = request("RespondInvite", { Accept = true, Confirm = pendingAbandonConfirm })
			pendingAbandonConfirm = res.code == "ConfirmAbandon"
			renderTab()
		end)
		rightButton(r, "Refuser", C.Danger, 1, function()
			pendingAbandonConfirm = false
			request("RespondInvite", { Accept = false, Confirm = false })
		end)
	end

	local roleName = if state.MyRole == "Admin" then "Administrateur" else "Membre"
	heading(string.format("%s · %d/%d · ton rôle : %s", state.Name, #state.Members, state.MaxSize, roleName))
	local memberIds = {}
	for _, m in state.Members do
		memberIds[m.UserId] = true
		local r = row()
		local status = (if m.Role == "Admin" then "Administrateur" else "Membre")
			.. (if m.Status == "Pending" then " · en attente" else "")
			.. (if m.Online then " · en ligne" else " · hors ligne")
		rowText(r, tostring(m.Name), status, 236)
		if state.MyRole == "Admin" and m.UserId ~= player.UserId then
			rightButton(r, "Retirer", C.Danger, 1, function()
				request("Kick", { UserId = m.UserId, Confirm = true })
			end, true)
			if m.Status == "Active" then
				rightButton(r, "Nommer admin", C.info, 2, function()
					request("TransferAdmin", { UserId = m.UserId })
				end, true)
			end
		end
	end

	if state.MyRole == "Admin" and #state.Members < state.MaxSize then
		heading("Inviter un joueur du serveur")
		local any = false
		for _, other in Players:GetPlayers() do
			if other ~= player and not memberIds[other.UserId] then
				any = true
				local r = row(52)
				rowText(r, other.DisplayName, nil, 120)
				rightButton(r, "Inviter", C.Free, 1, function()
					request("Invite", { UserId = other.UserId })
				end)
			end
		end
		if not any then
			heading("(aucun autre joueur sur ce serveur)")
		end
	end

	if #state.Members > 1 then
		heading("Quitter")
		local r = row(60)
		rowText(r, "Quitter le groupe", "Tu gardes ta progression personnelle ; le bastion reste au groupe.", 120)
		rightButton(r, "Quitter", C.Danger, 1, function()
			request("Leave", { Confirm = true })
		end, true)
	end
	renderFriends()
end

-- Onglet Améliorations
-- Onglet Arbre d'améliorations (or + trophées)
local selectedNode = nil

local function ownedNodes()
	local set = {}
	for id in string.gmatch(tostring(player:GetAttribute("TreeOwned") or ""), "[^,]+") do
		set[id] = true
	end
	return set
end

local function nodeEffect(node): string
	local value = if Tree.PercentStats[node.Stat] then math.floor(node.Value * 100 + 0.5) else node.Value
	return string.format(Tree.StatText[node.Stat], value)
end

local function costText(cost): string
	local parts = {}
	if cost.Gold then
		table.insert(parts, Formulas.formatNumber(cost.Gold) .. " or")
	end
	if cost.Trophies then
		table.insert(parts, Formulas.formatNumber(cost.Trophies) .. " trophées")
	end
	return table.concat(parts, " + ")
end

local function renderUpgrades()
	local owned = ownedNodes()
	heading(
		string.format(
			"Or : %s · Trophées : %s",
			Formulas.formatNumber(player:GetAttribute("Gold") or 0),
			Formulas.formatNumber(player:GetAttribute("Trophies") or 0)
		)
	)

	-- Arbre en étoile : une branche par direction, du centre vers l'extérieur.
	order += 1
	local size = 520
	local holder = Ui.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, size),
		BackgroundColor3 = Color3.fromRGB(22, 18, 30),
		ClipsDescendants = true,
		Parent = content,
	}, { Ui.corner(10) })
	local canvas = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	-- Mise à l'échelle sur les écrans étroits (téléphone en portrait).
	local scale = Ui.create("UIScale", { Parent = canvas })
	local function fit()
		scale.Scale = math.min(1, holder.AbsoluteSize.X / size)
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)

	local center = size / 2
	Ui.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center, center),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = Color3.fromRGB(200, 40, 50),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = C.Text,
		Text = "Arbre",
		Parent = canvas,
	}, { Ui.corner(32), Ui.padding(6) })

	local romans = { "I", "II", "III", "IV", "V" }
	local firstButton = nil
	for _, branch in Tree.Branches do
		local color = Color3.fromRGB(branch.Color[1], branch.Color[2], branch.Color[3])
		local angle = math.rad(branch.Angle)
		local index = 0
		for _, node in Tree.Nodes do
			if node.Branch == branch.Id then
				index += 1
				local dist = 30 + index * 42
				local x, y = center + math.cos(angle) * dist, center + math.sin(angle) * dist
				local isOwned = owned[node.Id] == true
				local previous = Formulas.treePrevious(Tree, node.Id)
				local available = not isOwned and (previous == nil or owned[previous] == true)
				local button = Ui.button({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(38, 38),
					BackgroundColor3 = if isOwned
						then color
						elseif available then color:Lerp(C.Panel, 0.55)
						else C.Disabled,
					TextSize = 13,
					Text = if isOwned then "✔" elseif available then romans[index] or "+" else "?",
					Parent = canvas,
				}, function()
					selectedNode = node.Id
					renderTab()
				end)
				button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
				if selectedNode == node.Id then
					Ui.create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Parent = button })
				end
				firstButton = firstButton or button
			end
		end
		-- Nom de la branche au bout
		local dist = 30 + (index + 1) * 42
		Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center + math.cos(angle) * dist, center + math.sin(angle) * dist),
			Size = UDim2.fromOffset(90, 18),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			Text = branch.Name,
			Parent = canvas,
		})
	end

	-- Détail du nœud sélectionné
	local node = nil
	for _, n in Tree.Nodes do
		if n.Id == selectedNode then
			node = n
		end
	end
	local r = row(70)
	if not node then
		rowText(
			r,
			"Choisis une amélioration dans l'arbre.",
			"Or : branches de progression · Trophées : gagnés en combat (Rue des boss, boss).",
			0
		)
		return
	end
	local previous = Formulas.treePrevious(Tree, node.Id)
	local status = if owned[node.Id]
		then "Acquis"
		elseif previous and not owned[previous] then "Verrouillé : achète d'abord l'amélioration précédente"
		else "Coût : " .. costText(node.Cost)
	rowText(r, node.Name .. " · " .. nodeEffect(node), status, 130)
	if not owned[node.Id] and (previous == nil or owned[previous]) then
		rightButton(r, "Acheter", C.Free, 1, function()
			request("BuyNode", { Id = node.Id })
		end)
	end
end

-- Onglet Boutique
-- Pays où les objets aléatoires payants sont interdits : les œufs royaux ne sont pas vendus
-- (ils restent gagnables en jouant). En cas d'erreur, on applique la règle la plus stricte.
local paidRandomRestricted = true
task.spawn(function()
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	paidRandomRestricted = not (ok and info and info.ArePaidRandomItemsRestricted == false)
end)
local productByKey = {}
for _, item in Products do
	productByKey[item.Key] = item
end
local priceCache = {}
local onPriceLoaded: (() -> ())? = nil -- rafraîchit la fenêtre d'œuf ouverte
local function priceText(item): string?
	if item.Id == 0 then
		return nil
	end
	if priceCache[item.Key] == nil then
		priceCache[item.Key] = false
		task.spawn(function()
			-- Prix fourni par Roblox (tarification régionale) ; jamais codé en dur.
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(
					item.Id,
					if item.Kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
				)
			end)
			priceCache[item.Key] = if ok and info and info.PriceInRobux then tostring(info.PriceInRobux) else false
			if menuOpen and currentTab == "Shop" then
				renderTab()
			end
			if onPriceLoaded then
				onPriceLoaded()
			end
		end)
	end
	return priceCache[item.Key] or nil
end

local function renderShop()
	if devTools then
		heading("Outils de test (Studio uniquement)")
		local r = row(56)
		rowText(r, "Accélérer les tests", "Invisible et refusé dans le jeu publié.", 236)
		rightButton(r, "+10 niveaux", C.info, 1, function()
			request("DevBoost", { Kind = "Levels" })
		end)
		rightButton(r, "+10 000 or", C.info, 2, function()
			request("DevBoost", { Kind = "Gold" })
		end)
		local r2 = row(56)
		rowText(r2, "Trophées", nil, 120)
		rightButton(r2, "+500 trophées", C.info, 1, function()
			request("DevBoost", { Kind = "Trophies" })
		end)
	end
	heading("Boutique du royaume")
	for _, item in Products do
		if item.Delivery.Type == "Egg" and paidRandomRestricted then
			continue -- objets aléatoires payants interdits pour ce joueur (PolicyService)
		end
		local sellable = item.Id ~= 0 and item.Ready
		local price = if sellable then priceText(item) else nil
		local devButton = devTools and item.Ready
		local r = row(70)
		rowText(r, item.Name .. " · " .. item.Preview, item.Description, if devButton then 236 else 120)
		if price then
			rightButton(r, "R$ " .. price, C.Robux, 1, function()
				-- La fenêtre de paiement Roblox ne s'ouvre qu'après ce choix explicite.
				if item.Kind == "Pass" then
					MarketplaceService:PromptGamePassPurchase(player, item.Id)
				else
					MarketplaceService:PromptProductPurchase(player, item.Id)
				end
			end)
		else
			rightButton(r, "Bientôt", C.Disabled, 1, nil)
		end
		if devButton then
			rightButton(r, "Simuler (Studio)", C.info, 2, function()
				request("DevSimulatePurchase", { Key = item.Key })
			end)
		end
	end
end

local petById = {}
for _, def in Pets.List do
	petById[def.Id] = def
end

local function rarityColor(rarityId: string): Color3
	local r = Pets.Rarities[rarityId]
	return Color3.fromRGB(r.Color[1], r.Color[2], r.Color[3])
end

-- Onglet Compagnons
local function renderPets()
	local state = petState
	if not state then
		heading(Texts.Loading)
		return
	end
	local mult = player:GetAttribute("PetMult") or 1
	heading(
		string.format(
			"Équipés %d/%d · bonus total +%d %% · inventaire %d/%d",
			#state.Equipped,
			state.Slots,
			math.floor((mult - 1) * 100 + 0.5),
			#state.Pets,
			state.Size
		)
	)
	local top = row(52)
	rowText(top, "Œufs au point d'accueil.", "Emplacements : renaissances 1 et 3, arbre « Équiper ».", 236)
	rightButton(top, "Équiper le meilleur", C.Robux, 1, function()
		request("EquipBestPets", {})
	end)
	rightButton(top, "Tout retirer", C.Danger, 2, function()
		request("UnequipAllPets", {})
	end)

	local list = table.clone(state.Pets)
	table.sort(list, function(a, b)
		local da, db = petById[a.PetId], petById[b.PetId]
		local ba, bb = da and da.Bonus or 0, db and db.Bonus or 0
		if ba ~= bb then
			return ba > bb
		end
		return a.Uid < b.Uid
	end)
	for _, pet in list do
		local def = petById[pet.PetId]
		if def then
			local equipped = table.find(state.Equipped, pet.Uid) ~= nil
			local r = row(58)
			r.BackgroundColor3 = C.Row:Lerp(rarityColor(def.Rarity), 0.18)
			rowText(
				r,
				(if equipped then "✔ " else "") .. def.Name,
				string.format("%s · +%d %%", Pets.Rarities[def.Rarity].Name, math.floor(def.Bonus * 100 + 0.5)),
				236
			)
			rightButton(r, "Relâcher", C.Danger, 1, function()
				request("ReleasePet", { Uid = pet.Uid })
			end, true)
			rightButton(
				r,
				if equipped then "Retirer" else "Équiper",
				if equipped then C.info else C.Free,
				2,
				function()
					request("TogglePet", { Uid = pet.Uid })
				end
			)
		end
	end
	if #list == 0 then
		heading("Aucun compagnon : ouvre un œuf au point d'accueil !")
	end
end

-- Onglet Renaissance
local function renderRebirth()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local level = player:GetAttribute("Level") or 1
	local required = player:GetAttribute("RebirthLevel") or Formulas.rebirthRequiredLevel(rebirths, Rebirth)
	local now = Formulas.rebirthMultiplier(rebirths, Rebirth)
	local nextMult = Formulas.rebirthMultiplier(rebirths + 1, Rebirth)
	heading(string.format("Renaissances : %d · multiplicateur actuel x%.2f", rebirths, now))
	local r = row(84)
	rowText(
		r,
		string.format("x%.2f  →  x%.2f (XP, or et Puissance)", now, nextMult),
		string.format(
			"Niveau requis : %d (tu es niveau %d).\nRemet à zéro : niveau, XP et or. Conserve : améliorations, compagnons, bastion.",
			required,
			level
		),
		130
	)
	if rebirths >= Rebirth.MaxRebirths then
		rightButton(r, "Maximum", C.Disabled, 1, nil)
	elseif level >= required then
		rightButton(r, "Renaître", C.reward, 1, function()
			request("Rebirth", { Confirm = true })
			task.defer(renderTab)
		end, true)
	else
		rightButton(r, "Niveau " .. required, C.Disabled, 1, nil)
	end
	heading("Débloqué par la renaissance")
	local unlocks = {
		{ 1, "Tapis d'Éther (x3) · 2e emplacement de compagnon" },
		{ 3, "Tapis célestes (x6) · 3e emplacement de compagnon" },
	}
	for _, u in unlocks do
		local ur = row(44)
		rowText(ur, (if rebirths >= u[1] then "✔ " else "") .. "Renaissance " .. u[1] .. " : " .. u[2], nil, 0)
	end
end

-- Onglet Cadeaux (gratuit) : calendrier 7 jours et temps de jeu
local function rewardText(reward): string
	local parts = {}
	if reward.Gold then
		table.insert(parts, "+" .. Formulas.formatNumber(reward.Gold) .. " or")
	end
	if reward.Trophies then
		table.insert(parts, "+" .. reward.Trophies .. " trophées")
	end
	if reward.Xp then
		table.insert(parts, "+" .. reward.Xp .. " XP")
	end
	if reward.Pet and petById[reward.Pet] then
		table.insert(parts, petById[reward.Pet].Name)
	end
	if reward.Egg then
		for _, egg in Pets.Eggs do
			if egg.Id == reward.Egg then
				table.insert(parts, "🥚 " .. egg.Name)
			end
		end
	end
	if reward.Entitlement then
		table.insert(parts, "⭐ " .. reward.Entitlement.Name)
	end
	return table.concat(parts, " · ")
end

local function formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function renderRewards()
	local cycle = player:GetAttribute("DailyCycle") or 1
	local done = player:GetAttribute("DailyDay") or 0
	local claimable = player:GetAttribute("DailyClaimable") == true
	local list = if cycle <= 1 then Rewards.Daily else Rewards.Repeat
	heading(string.format("Récompense quotidienne · cycle %d (jours cumulés, rien n'est perdu)", cycle))
	for day, reward in list do
		local r = row(44)
		local status = if day <= done
			then "✔ récupéré"
			elseif day == done + 1 then (if claimable then "aujourd'hui" else "demain")
			else "à venir"
		r.BackgroundColor3 = if day == done + 1 and claimable then C.Free:Lerp(C.Row, 0.5) else C.Row
		rowText(r, string.format("Jour %d · %s", day, rewardText(reward)), nil, 130)
		Ui.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.Muted,
			Text = status,
			Parent = r,
		})
	end
	local claim = row(60)
	if claimable then
		rowText(claim, "Ta récompense du jour est prête !", "Gratuit, sans achat.", 220)
		local button = rightButton(claim, "Récupérer gratuitement", C.Free, 1, function()
			request("ClaimDaily", {})
		end)
		button.Size = UDim2.fromOffset(200, 44)
	else
		local resetAt = player:GetAttribute("DailyResetAt") or 0
		rowText(
			claim,
			"Prochaine récompense dans " .. formatClock(resetAt - workspace:GetServerTimeNow()),
			"Nouveau jour à 00:00 UTC.",
			0
		)
	end

	local played = player:GetAttribute("PlaySeconds") or 0
	heading(string.format("Temps de jeu aujourd'hui : %d min", played // 60))
	for _, tier in Rewards.Playtime do
		local r = row(44)
		local reached = played >= tier.Minutes * 60
		rowText(r, string.format("%d min · %s", tier.Minutes, rewardText(tier.Reward)), nil, 130)
		Ui.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if reached then C.Free else C.Muted,
			Text = if reached
				then "✔ reçu"
				else string.format("encore %d min", math.ceil((tier.Minutes * 60 - played) / 60)),
			Parent = r,
		})
	end
	if played >= Rewards.Playtime[#Rewards.Playtime].Minutes * 60 then
		heading("Tous les cadeaux de temps de jeu du jour sont récupérés.")
	end
	if devTools then
		local dev = row(52)
		rowText(dev, "Test Studio", "Simule le passage au jour suivant.", 120)
		rightButton(dev, "Jour suivant", C.info, 1, function()
			request("DevBoost", { Kind = "NextDay" })
		end)
	end
end

-- Onglet Titres : récompenses de prestige visibles par tous au-dessus du personnage
local function renderTitles()
	local unlocked = {}
	for id in string.gmatch(tostring(player:GetAttribute("TitlesUnlocked") or ""), "[^,]+") do
		unlocked[id] = true
	end
	local equipped = player:GetAttribute("Title")
	heading("Titres : affichés au-dessus de ton personnage, visibles par tous")
	local sorted = table.clone(Titles)
	table.sort(sorted, function(a, b)
		return a.Order < b.Order
	end)
	for _, title in sorted do
		local r = row(54)
		local isUnlocked = unlocked[title.Id] == true
		local color = Color3.fromRGB(title.Color[1], title.Color[2], title.Color[3])
		r.BackgroundColor3 = if title.Id == equipped then C.Row:Lerp(color, 0.35) else C.Row
		rowText(r, (if isUnlocked then "" else "🔒 ") .. "« " .. title.Name .. " »", title.Hint, 130)
		if title.Id == equipped then
			rightButton(r, "Équipé", C.Disabled, 1, nil)
		elseif isUnlocked then
			rightButton(r, "Équiper", C.Free, 1, function()
				request("EquipTitle", { Id = title.Id })
			end)
		else
			rightButton(r, "Verrouillé", C.Disabled, 1, nil)
		end
	end
end

-- Onglet Quêtes : missions personnelles (enchaînées) et de groupe
local function questReward(reward): string
	local parts = {}
	for key, value in reward do
		local names = {
			Gold = "or",
			Trophies = "trophées",
			Xp = "XP",
			Wood = "Bois",
			Stone = "Pierre",
			Ore = "Minerai",
			Crystal = "Cristal",
		}
		table.insert(parts, string.format("+%s %s", Formulas.formatNumber(value), names[key] or key))
	end
	table.sort(parts)
	return table.concat(parts, " · ")
end

local function renderQuests()
	local index = player:GetAttribute("QuestIndex") or 1
	heading(
		string.format(
			"Missions personnelles · %d/%d terminées",
			math.min(index - 1, #Quests.Personal),
			#Quests.Personal
		)
	)
	for i, quest in Quests.Personal do
		local r = row(54)
		local status
		if i < index then
			status = "✔ "
		elseif i == index then
			status = string.format("▶ (%d/%d) ", player:GetAttribute("QuestProgress") or 0, quest.Target)
			r.BackgroundColor3 = C.Row:Lerp(C.Ether, 0.2)
		else
			status = "🔒 "
		end
		rowText(r, status .. quest.Text, "Récompense : " .. questReward(quest.Reward), 0)
	end
	local done = {}
	for id in string.gmatch(tostring(player:GetAttribute("GroupQuestsDone") or ""), "[^,]+") do
		done[id] = true
	end
	heading("Missions de groupe (une récompense par bastion)")
	for _, quest in Quests.Group do
		local r = row(54)
		rowText(
			r,
			(if done[quest.Id] then "✔ " else "▶ ") .. quest.Text,
			"Récompense du bastion : " .. questReward(quest.Reward),
			0
		)
	end
end

-- Onglet Parcours du champion : pass de saison (piste gratuite + piste premium)
local function renderPass()
	local xp = player:GetAttribute("PassXp") or 0
	local tier = player:GetAttribute("PassTier") or 0
	local isPremium = player:GetAttribute("PassPremium") == true
	local claimable = player:GetAttribute("PassClaimable") or 0
	local freeDone, premiumDone = {}, {}
	for id in string.gmatch(player:GetAttribute("PassFree") or "", "[^,]+") do
		freeDone[tonumber(id)] = true
	end
	for id in string.gmatch(player:GetAttribute("PassPremiumClaimed") or "", "[^,]+") do
		premiumDone[tonumber(id)] = true
	end

	heading(Pass.Name)
	local top = row(64)
	local nextText = if tier >= #Pass.Tiers
		then "Parcours terminé !"
		else string.format("Palier suivant : %d / %d XP", xp - tier * Pass.XpPerTier, Pass.XpPerTier)
	rowText(
		top,
		string.format("Palier %d / %d", tier, #Pass.Tiers),
		nextText .. " · XP en jouant : minutes actives, missions, boss, Rue, défense",
		220
	)
	local claimButton = rightButton(
		top,
		if claimable > 0 then string.format("Tout récupérer (%d)", claimable) else "Rien à récupérer",
		if claimable > 0 then C.Free else C.Disabled,
		1,
		if claimable > 0
			then function()
				request("ClaimPass", {})
			end
			else nil
	)
	claimButton.Size = UDim2.fromOffset(200, 44)

	local prem = row(60)
	if isPremium then
		rowText(prem, "👑 Piste premium active", "Toutes les récompenses premium atteintes sont à toi.", 0)
	else
		local item = productByKey[Pass.PremiumPass]
		local price = if item and item.Id ~= 0 then priceText(item) else nil
		rowText(
			prem,
			"👑 Piste premium : œufs royaux et célestes, tapis x100 puis x500",
			"Paliers déjà atteints inclus.",
			200
		)
		if price then
			rightButton(prem, "R$ " .. price, C.Robux, 1, function()
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			end)
		elseif devTools then
			rightButton(prem, "Simuler (Studio)", C.info, 1, function()
				request("DevSimulatePurchase", { Key = Pass.PremiumPass })
			end)
		else
			rightButton(prem, "Bientôt", C.Disabled, 1, nil)
		end
	end
	if devTools then
		local dev = row(52)
		rowText(dev, "Test Studio", nil, 130)
		rightButton(dev, "+3 paliers", C.info, 1, function()
			request("DevBoost", { Kind = "Pass" })
		end)
	end

	heading("Paliers")
	for index, entry in Pass.Tiers do
		local reached = index <= tier
		local r = row(58)
		if index == #Pass.Tiers then
			r.BackgroundColor3 = C.Gold:Lerp(C.Row, 0.75)
		end
		rowText(
			r,
			string.format("%d · Gratuit : %s", index, rewardText(entry.Free)),
			"👑 " .. rewardText(entry.Premium),
			130
		)
		local status
		if not reached then
			status = "🔒"
		else
			local free = if freeDone[index] then "✔" else "prêt"
			local premium = if premiumDone[index] then "✔" elseif isPremium then "prêt" else "👑🔒"
			status = free .. " / " .. premium
		end
		Ui.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if reached then C.Free else C.Muted,
			Text = status,
			Parent = r,
		})
	end
end

local TABS = {
	{ Id = "Group", Label = "Groupe", Render = renderGroup },
	{ Id = "Pets", Label = "Compagnons", Render = renderPets },
	{ Id = "Upgrades", Label = "Arbre", Render = renderUpgrades },
	{ Id = "Rebirth", Label = "Renaissance", Render = renderRebirth },
	{ Id = "Rewards", Label = "Cadeaux", Render = renderRewards },
	{ Id = "Titles", Label = "Titres", Render = renderTitles },
	{ Id = "Quests", Label = "Quêtes", Render = renderQuests },
	{ Id = "Pass", Label = "Parcours", Render = renderPass },
	{ Id = "Shop", Label = "Boutique", Render = renderShop },
}

local tabButtons = {}
function renderTab()
	clearContent()
	for _, tab in TABS do
		tabButtons[tab.Id].BackgroundColor3 = if tab.Id == currentTab then C.reward else C.Row
		if tab.Id == currentTab then
			tab.Render()
		end
	end
end

for i, tab in TABS do
	tabButtons[tab.Id] = Ui.button({
		LayoutOrder = i,
		Size = UDim2.new(1 / #TABS, -6, 1, 0),
		BackgroundColor3 = C.Row,
		TextScaled = true,
		Text = tab.Label,
		Parent = tabBar,
	}, function()
		currentTab = tab.Id
		renderTab()
	end)
end

local function isGamepad(): boolean
	return UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
end

local function setMenu(open: boolean)
	menuOpen = open
	menu.Visible = open
	if open then
		renderTab()
		if isGamepad() then
			GuiService.SelectedObject = tabButtons[currentTab]
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(menu) then
		GuiService.SelectedObject = nil
	end
end

menuButton.Activated:Connect(function()
	setMenu(not menuOpen)
end)
closeButton.Activated:Connect(function()
	setMenu(false)
end)

ContextActionService:BindAction("ToggleMenu", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		setMenu(not menuOpen)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonY)

ContextActionService:BindAction("CloseMenu", function(_, inputState)
	if not menuOpen then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		setMenu(false)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonB)

-- Libellé du bouton selon l'appareil actif.
local function refreshHint()
	local t = UserInputService:GetLastInputType()
	if isGamepad() then
		menuButton.Text = "Menu (Y)"
	elseif t == Enum.UserInputType.Touch then
		menuButton.Text = "Menu"
	else
		menuButton.Text = "Menu (M)"
	end
end
UserInputService.LastInputTypeChanged:Connect(refreshHint)
refreshHint()

-- État du groupe ----------------------------------------------------------------------

GroupUpdate.OnClientEvent:Connect(function(state)
	groupState = state
	if not (state and state.Invite) then
		pendingAbandonConfirm = false
	end
	refreshHud()
	if menuOpen and currentTab == "Group" then
		renderTab()
	end
end)

local function rerenderGroupTab()
	if menuOpen and currentTab == "Group" then
		task.defer(renderTab)
	end
end
Players.PlayerAdded:Connect(rerenderGroupTab)
Players.PlayerRemoving:Connect(rerenderGroupTab)
for _, name in { "TreeOwned", "Trophies" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if menuOpen and currentTab == "Upgrades" then
			renderTab()
		end
	end)
end

-- Fenêtre d'œuf : ouverte quand le joueur utilise l'invite d'un présentoir --------------------

local eggById = {}
for _, egg in Pets.Eggs do
	eggById[egg.Id] = egg
end

local eggPanel = Ui.create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 380),
	BackgroundColor3 = C.Panel,
	Visible = false,
	Parent = gui,
}, { Ui.corner(12), Ui.stroke(), Ui.create("UISizeConstraint", { MaxSize = Vector2.new(420, 380) }) })
local eggTitle = Ui.label({
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -70, 0, 30),
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = C.Gold,
	Parent = eggPanel,
})
local eggClose = Ui.button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = C.Danger,
	Text = "X",
	Parent = eggPanel,
})
local eggList = Ui.create("Frame", {
	Position = UDim2.fromOffset(14, 58),
	Size = UDim2.new(1, -28, 0, 220),
	BackgroundTransparency = 1,
	Parent = eggPanel,
})
Ui.list(eggList, 4)
local eggResult = Ui.label({
	Position = UDim2.new(0, 14, 1, -100),
	Size = UDim2.new(1, -28, 0, 30),
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = eggPanel,
})
local eggButton = Ui.button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(1, -28, 0, 52),
	BackgroundColor3 = C.reward,
	TextSize = 18,
	Parent = eggPanel,
})
local currentEgg = nil

local function openEgg(eggId: string)
	local egg = eggById[eggId]
	if not egg then
		return
	end
	currentEgg = egg
	eggTitle.Text = egg.Name
	eggResult.Text = ""
	for _, child in eggList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	-- Probabilités affichées avant l'achat.
	local luck = player:GetAttribute("Luck") or 0
	if luck > 0 then
		eggTitle.Text = egg.Name .. string.format(" (chance +%d %%)", math.floor(luck * 100 + 0.5))
	end
	for i, entry in Formulas.eggOdds(Formulas.luckyEgg(egg, Pets, luck)) do
		local def = petById[entry.Id]
		Ui.label({
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 24),
			TextColor3 = rarityColor(def.Rarity),
			Font = Enum.Font.GothamBold,
			Text = string.format(
				"%s · %s · +%d %%   —   %s %%",
				def.Name,
				Pets.Rarities[def.Rarity].Name,
				math.floor(def.Bonus * 100 + 0.5),
				string.format("%.1f", entry.Chance * 100):gsub("%.", ",")
			),
			Parent = eggList,
		})
	end
	if egg.Cost then
		eggButton.Text = string.format("Ouvrir (%s or)", Formulas.formatNumber(egg.Cost))
		eggButton.BackgroundColor3 = C.reward
	else
		local item = productByKey[egg.Product]
		local price = if item and item.Id ~= 0 and not paidRandomRestricted then priceText(item) else nil
		if price then
			eggButton.Text = "Ouvrir (R$ " .. price .. ")"
			eggButton.BackgroundColor3 = C.Robux
		elseif devTools and not paidRandomRestricted then
			eggButton.Text = "Simuler l'achat (Studio)"
			eggButton.BackgroundColor3 = C.info
		else
			eggButton.Text = "Offert après 1 h de jeu (Cadeaux)"
			eggButton.BackgroundColor3 = C.Disabled
		end
	end
	eggPanel.Visible = true
	if UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad" then
		GuiService.SelectedObject = eggButton
	end
end

eggButton.Activated:Connect(function()
	if not currentEgg then
		return
	end
	if not currentEgg.Cost then
		-- Œuf royal : paiement Robux après ce clic explicite ; le serveur livre et annonce.
		local item = productByKey[currentEgg.Product]
		if not item or paidRandomRestricted then
			return
		end
		if item.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, item.Id)
		elseif devTools then
			request("DevSimulatePurchase", { Key = item.Key })
		end
		return
	end
	local res = request("HatchEgg", { EggId = currentEgg.Id })
	if res.ok and res.pet then
		local def = petById[res.pet.PetId]
		eggResult.TextColor3 = rarityColor(def.Rarity)
		eggResult.Text = "Obtenu : " .. def.Name .. " (" .. Pets.Rarities[def.Rarity].Name .. ")"
		Effects.float(def.Name .. " !", rarityColor(def.Rarity), true)
	end
end)
onPriceLoaded = function()
	if eggPanel.Visible and currentEgg and not currentEgg.Cost then
		openEgg(currentEgg.Id)
	end
end
eggClose.Activated:Connect(function()
	eggPanel.Visible = false
	currentEgg = nil
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local tab = prompt:GetAttribute("OpenTab")
	if type(tab) == "string" then
		currentTab = tab
		setMenu(true)
		return
	end
	local eggId = prompt:GetAttribute("EggId")
	if type(eggId) == "string" then
		openEgg(eggId)
	end
end)

PetsUpdate.OnClientEvent:Connect(function(state)
	petState = state
	if menuOpen and currentTab == "Pets" then
		renderTab()
	end
end)

-- Colonne de boutons à icônes (gauche) ---------------------------------------------------
-- Chaque bouton ouvre l'onglet correspondant ; une pastille rouge signale une nouveauté
-- (amélioration achetable, compagnon à équiper, renaissance possible, cadeau prêt).
local iconColumn = Ui.create("Frame", {
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(160, 304),
	BackgroundTransparency = 1,
	Parent = gui,
})
Ui.create("UIGridLayout", {
	CellSize = UDim2.fromOffset(76, 56), -- 2 colonnes x 5 rangées, au-dessus des monnaies
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = iconColumn,
})
local ICONS = {
	{ Tab = "Shop", Icon = "🛒", Label = "Boutique", Color = Color3.fromRGB(230, 170, 40) },
	{ Tab = "Upgrades", Icon = "🌳", Label = "Arbre", Color = Color3.fromRGB(70, 160, 80) },
	{ Tab = "Pets", Icon = "🐾", Label = "Compagnons", Color = Color3.fromRGB(150, 90, 220) },
	{ Tab = "Rebirth", Icon = "🔁", Label = "Renaissance", Color = Color3.fromRGB(210, 60, 70) },
	{ Tab = "Rewards", Icon = "🎁", Label = "Cadeaux", Color = Color3.fromRGB(240, 120, 40) },
	{ Tab = "Group", Icon = "🏰", Label = "Groupe", Color = Color3.fromRGB(60, 110, 200) },
	{ Tab = "Titles", Icon = "🎖", Label = "Titres", Color = Color3.fromRGB(200, 160, 60) },
	{ Tab = "Quests", Icon = "📜", Label = "Quêtes", Color = Color3.fromRGB(140, 110, 80) },
	{ Tab = "Pass", Icon = "🏅", Label = "Parcours", Color = Color3.fromRGB(230, 200, 60) },
}
local badges = {}
for i, entry in ICONS do
	local button = Ui.button({
		LayoutOrder = i,
		BackgroundColor3 = entry.Color,
		Text = "",
		Parent = iconColumn,
	}, function()
		currentTab = entry.Tab
		setMenu(true)
	end)
	Ui.create("UIStroke", {
		Color = Color3.fromRGB(40, 28, 16),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	Ui.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180)),
		Parent = button,
	})
	Ui.label({
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 0, 32),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = entry.Icon,
		Parent = button,
	})
	Ui.label({
		Position = UDim2.new(0, 2, 1, -20),
		Size = UDim2.new(1, -4, 0, 17),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		Text = entry.Label,
		Parent = button,
	})
	local badge = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(225, 40, 40),
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 4,
		Parent = button,
	})
	Ui.corner(12).Parent = badge
	Ui.create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = badge })
	badges[entry.Tab] = badge
end

local function setBadge(tab: string, count: number)
	local badge = badges[tab]
	if badge then
		badge.Visible = count > 0
		badge.Text = if count > 9 then "9+" else tostring(count)
	end
end

local function refreshBadges()
	-- Arbre : nœuds achetables avec l'or et les trophées actuels
	local owned = ownedNodes()
	local wallet = { Gold = player:GetAttribute("Gold") or 0, Trophies = player:GetAttribute("Trophies") or 0 }
	local buyable = 0
	for _, node in Tree.Nodes do
		if Formulas.canBuyNode(Tree, owned, node.Id, wallet) then
			buyable += 1
		end
	end
	setBadge("Upgrades", buyable)
	-- Compagnons : emplacements libres alors que des compagnons attendent
	local pets = petState and #petState.Pets or 0
	local equipped = petState and #petState.Equipped or 0
	local slots = player:GetAttribute("PetSlots") or 1
	setBadge("Pets", if pets > equipped and equipped < slots then math.min(slots - equipped, pets - equipped) else 0)
	-- Renaissance possible
	local canRebirth = (player:GetAttribute("Level") or 1) >= (player:GetAttribute("RebirthLevel") or math.huge)
	setBadge("Rebirth", if canRebirth then 1 else 0)
	-- Cadeau quotidien prêt
	setBadge("Rewards", if player:GetAttribute("DailyClaimable") then 1 else 0)
	-- Invitation de groupe en attente
	setBadge("Group", if groupState and groupState.Invite then 1 else 0)
	-- Paliers du parcours à récupérer
	setBadge("Pass", player:GetAttribute("PassClaimable") or 0)
end
for _, name in
	{
		"Gold",
		"Trophies",
		"TreeOwned",
		"PetSlots",
		"Level",
		"RebirthLevel",
		"DailyClaimable",
		"EquippedPets",
		"PassClaimable",
	}
do
	player:GetAttributeChangedSignal(name):Connect(refreshBadges)
end
GroupUpdate.OnClientEvent:Connect(refreshBadges)
PetsUpdate.OnClientEvent:Connect(function()
	task.defer(refreshBadges)
end)
task.defer(refreshBadges)

-- Le bouton « Menu » texte est remplacé par la colonne d'icônes (M / Y restent actifs).
menuButton.Visible = false

giftPanel.Activated:Connect(function()
	currentTab = "Rewards"
	setMenu(true)
end)
for _, name in { "QuestIndex", "QuestProgress", "GroupQuestsDone" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if menuOpen and currentTab == "Quests" then
			renderTab()
		end
	end)
end
for _, name in { "Title", "TitlesUnlocked" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if menuOpen and currentTab == "Titles" then
			renderTab()
		end
	end)
end
for _, name in { "DailyDay", "DailyClaimable", "PlaySeconds" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if menuOpen and currentTab == "Rewards" then
			renderTab()
		end
	end)
end

player:GetAttributeChangedSignal("GroupState"):Connect(function()
	if menuOpen and currentTab == "Group" then
		renderTab()
	end
end)

for _, name in { "PassXp", "PassPremium", "PassClaimable" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if menuOpen and currentTab == "Pass" then
			renderTab()
		end
	end)
end

for _, name in { "Rebirths", "Level", "RebirthLevel" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if menuOpen and currentTab == "Rebirth" then
			renderTab()
		end
	end)
end

Effects.start()
PetFollowers.start()
CombatUi.start(gui, toast)
StreetUi.start(gui)
FarmUi.start()
refreshHud()
task.spawn(function()
	local ok, res = pcall(function()
		return Request:InvokeServer("Sync", {})
	end)
	if ok and type(res) == "table" then
		devTools = res.devTools == true
		if res.group and res.group.Name then
			groupState = res.group
		end
		if res.pets then
			petState = res.pets
		end
		refreshHud()
	end
end)
