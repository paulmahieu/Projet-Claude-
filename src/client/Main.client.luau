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
local Upgrades = require(Shared.Config.Upgrades)
local Products = require(Shared.Config.Products)
local Texts = require(Shared.Config.Texts)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request") :: RemoteFunction
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local GroupUpdate = Remotes:WaitForChild("GroupUpdate") :: RemoteEvent

local player = Players.LocalPlayer
local C = Ui.Colors

local groupState = nil
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
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, -- zones sûres (encoches, coins arrondis)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Panneau personnel (haut gauche) ----------------------------------------------------

local stats = Ui.create("Frame", {
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(250, 128),
	BackgroundColor3 = C.Panel,
	BackgroundTransparency = 0.1,
	Parent = gui,
}, { Ui.corner(10), Ui.stroke(), Ui.padding(10) })

local goldLabel = Ui.label({
	Size = UDim2.new(1, 0, 0, 26),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = C.Gold,
	Parent = stats,
})
local levelLabel = Ui.label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 18), Parent = stats })
local xpBack = Ui.create("Frame", {
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 0, 10),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	Parent = stats,
}, { Ui.corner(5) })
local xpFill = Ui.create(
	"Frame",
	{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Xp, Parent = xpBack },
	{ Ui.corner(5) }
)
local powerLabel = Ui.label({
	Position = UDim2.fromOffset(0, 66),
	Size = UDim2.new(1, 0, 0, 18),
	TextColor3 = C.Muted,
	TextSize = 14,
	Parent = stats,
})
local objectiveLabel = Ui.label({
	Position = UDim2.fromOffset(0, 86),
	Size = UDim2.new(1, 0, 0, 22),
	TextColor3 = C.Ether,
	TextScaled = true,
	Parent = stats,
})

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
	goldLabel.Text = "Or : " .. Formulas.formatNumber(player:GetAttribute("Gold") or 0)
	levelLabel.Text =
		string.format("Niveau %d · %s / %s XP", level, Formulas.formatNumber(xp), Formulas.formatNumber(xpNext))
	powerLabel.Text = "Puissance " .. tostring(player:GetAttribute("Power") or 10)
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
	elseif player:GetAttribute("Training") then
		banner.Text = "Entraînement · " .. tostring(player:GetAttribute("TrainingRate") or "")
		banner.BackgroundColor3 = C.success
		banner.Visible = true
	else
		banner.Visible = false
	end
end

for _, name in
	{ "Gold", "Level", "TrainXp", "XpNext", "Power", "Training", "TrainingRate", "ProfileState", "GroupState" }
do
	player:GetAttributeChangedSignal(name):Connect(refreshHud)
end

-- Notifications -----------------------------------------------------------------------

local toastContainer = Ui.create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -90),
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
local function renderGroup()
	local state = groupState
	if not state or not state.Name then
		heading(Texts.Loading)
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
end

-- Onglet Améliorations
local function renderUpgrades()
	heading("Améliorations personnelles (or)")
	for _, def in Upgrades do
		local level = player:GetAttribute("Upg_" .. def.Id) or 0
		local cost = Formulas.upgradeCost(def, level)
		local r = row(64)
		rowText(r, string.format("%s · niv. %d/%d", def.Name, level, def.MaxLevel), def.Effect, 130)
		rightButton(
			r,
			if cost then Formulas.formatNumber(cost) .. " or" else "Maximum",
			if cost then C.Free else C.Disabled,
			1,
			if cost
				then function()
					request("BuyUpgrade", { Id = def.Id })
					renderTab()
				end
				else nil
		)
	end
end

-- Onglet Boutique
local priceCache = {}
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
		end)
	end
	return priceCache[item.Key] or nil
end

local function renderShop()
	heading("Boutique du royaume")
	for _, item in Products do
		local sellable = item.Id ~= 0 and item.Ready
		local price = if sellable then priceText(item) else nil
		local devButton = devTools and item.Ready and item.Kind == "Product"
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

local TABS = {
	{ Id = "Group", Label = "Groupe", Render = renderGroup },
	{ Id = "Upgrades", Label = "Améliorations", Render = renderUpgrades },
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
		Size = UDim2.new(1 / 3, -6, 1, 0),
		BackgroundColor3 = C.Row,
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
for _, name in { "Upg_Focus", "Upg_Toughness", "Gold" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if menuOpen and currentTab == "Upgrades" and name ~= "Gold" then
			renderTab()
		end
	end)
end

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
		refreshHud()
	end
end)
