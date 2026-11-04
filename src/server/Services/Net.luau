--[[
	Net : unique point d'entrée des demandes client -> serveur (RemoteFunction « Request »).

	Le client n'envoie que des INTENTIONS limitées (cahier §11) : inviter un joueur,
	répondre à une invitation, acheter une amélioration... Jamais de montant ni de résultat.
	- Liste blanche d'actions, validation stricte des types de chaque champ.
	- Limitation de fréquence : 10 demandes / 2 s par joueur, et anti-rafale par action.
	- Les opérations de groupe d'un même joueur sont sérialisées (pas d'exécution parallèle).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Validate = require(Shared.Validate)
local Texts = require(Shared.Config.Texts)

local GroupService = require(script.Parent.GroupService)
local TreeService = require(script.Parent.TreeService)
local TrainingService = require(script.Parent.TrainingService)
local MonetizationService = require(script.Parent.MonetizationService)
local RebirthService = require(script.Parent.RebirthService)
local PetService = require(script.Parent.PetService)
local BossService = require(script.Parent.BossService)
local RewardService = require(script.Parent.RewardService)
local TitleService = require(script.Parent.TitleService)
local ProfileService = require(script.Parent.ProfileService)
local Formulas = require(Shared.Formulas)
local Training = require(Shared.Config.Training)

local Request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request") :: RemoteFunction

local Net = {}

local WINDOW, MAX_IN_WINDOW, MIN_INTERVAL = 2, 10, 0.25

local history: { [Player]: { number } } = {}
local lastByAction: { [Player]: { [string]: number } } = {}
local groupBusy: { [Player]: boolean } = {}

local MAX_USER_ID = 2 ^ 53

local function bad()
	return { ok = false, msg = "Demande invalide." }
end

local function groupOp(player: Player, fn)
	if groupBusy[player] then
		return { ok = false, msg = "Opération en cours..." }
	end
	groupBusy[player] = true
	local ok, res = pcall(fn)
	groupBusy[player] = nil
	if not ok then
		warn("[Net] " .. tostring(res))
		return { ok = false, msg = "Erreur, réessaie." }
	end
	return res
end

local handlers = {
	Sync = function(player)
		return {
			ok = true,
			group = GroupService.snapshotFor(player),
			pets = PetService.snapshot(player),
			devTools = MonetizationService.devToolsEnabled(),
		}
	end,

	EquipTitle = function(player, p)
		if not Validate.id(p.Id, 32) then
			return bad()
		end
		return TitleService.equip(player, p.Id)
	end,

	ClaimDaily = function(player)
		return RewardService.claimDaily(player)
	end,

	GoToBastion = function(player)
		return GroupService.goToBastion(player)
	end,

	Invite = function(player, p)
		if not Validate.positiveInteger(p.UserId, MAX_USER_ID) then
			return bad()
		end
		return groupOp(player, function()
			return GroupService.invite(player, p.UserId)
		end)
	end,

	RespondInvite = function(player, p)
		if not Validate.boolean(p.Accept) or not Validate.boolean(p.Confirm) then
			return bad()
		end
		return groupOp(player, function()
			return GroupService.respondInvite(player, p.Accept, p.Confirm)
		end)
	end,

	Leave = function(player, p)
		if not Validate.boolean(p.Confirm) then
			return bad()
		end
		return groupOp(player, function()
			return GroupService.leave(player, p.Confirm)
		end)
	end,

	Kick = function(player, p)
		if not Validate.positiveInteger(p.UserId, MAX_USER_ID) or not Validate.boolean(p.Confirm) then
			return bad()
		end
		return groupOp(player, function()
			return GroupService.kick(player, p.UserId, p.Confirm)
		end)
	end,

	TransferAdmin = function(player, p)
		if not Validate.positiveInteger(p.UserId, MAX_USER_ID) then
			return bad()
		end
		return groupOp(player, function()
			return GroupService.transferAdmin(player, p.UserId)
		end)
	end,

	BuyNode = function(player, p)
		if not Validate.id(p.Id, 32) then
			return bad()
		end
		return TreeService.buy(player, p.Id)
	end,

	UnequipAllPets = function(player)
		return PetService.unequipAll(player)
	end,

	StopTraining = function(player)
		TrainingService.stop(player, Texts.TrainingStop)
		return { ok = true }
	end,

	Rebirth = function(player, p)
		if not Validate.boolean(p.Confirm) or not p.Confirm then
			return bad()
		end
		return RebirthService.rebirth(player)
	end,

	HatchEgg = function(player, p)
		if not Validate.id(p.EggId, 32) then
			return bad()
		end
		return PetService.hatch(player, p.EggId)
	end,

	TogglePet = function(player, p)
		if not Validate.positiveInteger(p.Uid, 1e9) then
			return bad()
		end
		return PetService.toggleEquip(player, p.Uid)
	end,

	EquipBestPets = function(player)
		return PetService.equipBest(player)
	end,

	ReleasePet = function(player, p)
		if not Validate.positiveInteger(p.Uid, 1e9) then
			return bad()
		end
		return PetService.release(player, p.Uid)
	end,

	UseSkill = function(player, p)
		if p.Id ~= "Strike" and p.Id ~= "Dodge" then
			return bad()
		end
		return BossService.useSkill(player, p.Id)
	end,

	-- Outil de test, UNIQUEMENT dans Studio (refusé dans le jeu publié).
	DevBoost = function(player, p)
		if not MonetizationService.devToolsEnabled() then
			return bad()
		end
		local profile = ProfileService.get(player)
		if not profile then
			return bad()
		end
		if p.Kind == "Gold" then
			profile.Gold += 10000
		elseif p.Kind == "NextDay" then
			return RewardService.devNextDay(player)
		elseif p.Kind == "Trophies" then
			profile.Trophies += 500
		elseif p.Kind == "Levels" then
			local target = profile.Level + 10
			while profile.Level < target and profile.Level < Training.MaxLevel do
				profile.Level, profile.TrainXp =
					Formulas.addXp(profile.Level, profile.TrainXp, Formulas.xpToNext(profile.Level, Training), Training)
			end
		else
			return bad()
		end
		ProfileService.sync(player)
		return { ok = true, msg = "Test Studio : appliqué." }
	end,

	DevSimulatePurchase = function(player, p)
		if not Validate.id(p.Key, 32) then
			return bad()
		end
		return MonetizationService.simulate(player, p.Key)
	end,
}

local function rateLimited(player: Player, action: string): boolean
	local now = os.clock()
	local list = history[player]
	if not list then
		list = {}
		history[player] = list
	end
	while list[1] and list[1] < now - WINDOW do
		table.remove(list, 1)
	end
	if #list >= MAX_IN_WINDOW then
		return true
	end
	local perAction = lastByAction[player]
	if not perAction then
		perAction = {}
		lastByAction[player] = perAction
	end
	if (perAction[action] or 0) + MIN_INTERVAL > now then
		return true
	end
	table.insert(list, now)
	perAction[action] = now
	return false
end

function Net.init()
	Request.OnServerInvoke = function(player: Player, action, payload)
		if type(action) ~= "string" or not handlers[action] then
			return bad()
		end
		if payload ~= nil and type(payload) ~= "table" then
			return bad()
		end
		if rateLimited(player, action) then
			return { ok = false, msg = Texts.TooFast }
		end
		return handlers[action](player, payload or {})
	end

	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
		lastByAction[player] = nil
		groupBusy[player] = nil
	end)
end

return Net
