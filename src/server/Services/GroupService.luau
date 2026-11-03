--[[
	GroupService : groupes persistants et base commune (cahier §4, §10).

	- Chaque joueur appartient à un seul groupe (bastion solo créé automatiquement au départ).
	- L'enregistrement du groupe ("g_<GroupId>") contient membres, rôles, matériaux communs et
	  constructions. Il est chargé sur le serveur où se trouve un membre, avec un verrou :
	  un seul serveur peut le modifier. Les membres peuvent tout faire sans l'administrateur.
	- Si le bastion est déjà ouvert sur un autre serveur, le joueur voit l'état « Remote » et
	  AUCUNE copie modifiable n'est ouverte ici. (Téléportation vers ce serveur : étape 2.)
	- Quand le dernier membre présent quitte le serveur : sauvegarde, libération du verrou
	  et de la parcelle.
	- Changements d'appartenance : protocole en 3 étapes décrit dans shared/Membership.luau.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GroupSchema = require(Shared.GroupSchema)
local Membership = require(Shared.Membership)
local Formulas = require(Shared.Formulas)
local Game = require(Shared.Config.Game)
local Groups = require(Shared.Config.Groups)
local Structures = require(Shared.Config.Structures)
local Texts = require(Shared.Config.Texts)

local Store = require(script.Parent.Store)
local ProfileService = require(script.Parent.ProfileService)
local PlotService = require(script.Parent.PlotService)
local Notifier = require(script.Parent.Notifier)

local GroupUpdate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GroupUpdate") :: RemoteEvent

local GroupService = {}

local REMOTE_RETRY = 30
local ERROR_RETRY = 15

export type Group = {
	Id: string,
	Key: string,
	Data: any,
	Online: { [Player]: boolean },
	Busy: boolean,
	PublishQueued: boolean,
}

local store
local groups: { [string]: Group } = {}
local loading: { [string]: boolean } = {}
local playerGroup: { [Player]: string } = {}
local invites: { [Player]: { GroupId: string, GroupName: string, FromName: string, Expires: number } } = {}

local attachedCallbacks, detachedCallbacks, releasedCallbacks, structuresCallbacks = {}, {}, {}, {}

local function fire(list, ...)
	for _, fn in list do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[GroupService] callback : " .. tostring(err))
		end
	end
end

local function result(ok: boolean, msg: string?, code: string?)
	return { ok = ok, msg = msg, code = code }
end

local function keyFor(id: string): string
	return "g_" .. id
end

local function newGroupId(): string
	return (string.gsub(HttpService:GenerateGUID(false), "%-", ""))
end

local function setState(player: Player, state: string)
	player:SetAttribute("GroupState", state)
end

-- Abonnements --------------------------------------------------------------------------

function GroupService.onAttached(fn)
	table.insert(attachedCallbacks, fn) -- fn(player, group)
end
function GroupService.onDetached(fn)
	table.insert(detachedCallbacks, fn) -- fn(player, group)
end
function GroupService.onReleased(fn)
	table.insert(releasedCallbacks, fn) -- fn(group)
end
function GroupService.onStructuresChanged(fn)
	table.insert(structuresCallbacks, fn) -- fn(group)
end

-- Lecture ------------------------------------------------------------------------------

function GroupService.groupOf(player: Player): Group?
	local id = playerGroup[player]
	return id and groups[id] or nil
end

function GroupService.get(id: string): Group?
	return groups[id]
end

function GroupService.canMutate(group: Group): boolean
	return groups[group.Id] == group and store:canMutate(group.Key)
end

function GroupService.onlineMembers(group: Group): { Player }
	local list = {}
	for player in group.Online do
		table.insert(list, player)
	end
	return list
end

-- Vérifie membre actif + permission + autorité d'écriture. Retourne group | nil, message.
function GroupService.authorize(player: Player, permission: string): (Group?, string?)
	local group = GroupService.groupOf(player)
	if not group then
		return nil, Texts.NotMember
	end
	if not Membership.can(Groups, group.Data, player.UserId, permission) then
		return nil, Texts.NoPermission
	end
	if not GroupService.canMutate(group) then
		return nil, Texts.ReadOnly
	end
	return group, nil
end

-- Diffusion de l'état ------------------------------------------------------------------

local function snapshot(group: Group?, viewer: Player)
	local invite = invites[viewer]
	local snap = {
		Invite = invite and { GroupName = invite.GroupName, FromName = invite.FromName, Expires = invite.Expires },
	}
	if group then
		local members = {}
		for key, entry in group.Data.Members do
			local userId = tonumber(key)
			local online = userId ~= nil and Players:GetPlayerByUserId(userId) ~= nil
			table.insert(members, {
				UserId = userId,
				Name = entry.Name,
				Role = entry.Role,
				Status = entry.Status,
				Online = online,
			})
		end
		table.sort(members, function(a, b)
			if a.Role ~= b.Role then
				return a.Role == "Admin"
			end
			return tostring(a.Name) < tostring(b.Name)
		end)
		local owned = {}
		for id in group.Data.Structures do
			table.insert(owned, id)
		end
		snap.Id = group.Id
		snap.Name = group.Data.Name
		snap.MyRole = Membership.role(group.Data, viewer.UserId)
		snap.Members = members
		snap.Materials = group.Data.Materials
		snap.Structures = owned
		snap.BastionLevel = Formulas.bastionLevel(Structures, group.Data.Structures)
		snap.MaxSize = Game.MaxGroupSize
	end
	return snap
end

function GroupService.snapshotFor(player: Player)
	return snapshot(GroupService.groupOf(player), player)
end

local function publishTo(player: Player)
	if player.Parent then
		GroupUpdate:FireClient(player, GroupService.snapshotFor(player))
	end
end

-- Signale un changement : diffusion groupée (une fois par image) + rafraîchissement de la parcelle.
function GroupService.markChanged(group: Group, structuresChanged: boolean?)
	PlotService.refresh(group.Id, group.Data)
	if structuresChanged then
		fire(structuresCallbacks, group)
	end
	if group.PublishQueued then
		return
	end
	group.PublishQueued = true
	task.defer(function()
		group.PublishQueued = false
		for player in group.Online do
			publishTo(player)
		end
	end)
end

-- Chargement / libération ---------------------------------------------------------------

local function register(id: string, data): Group
	local group: Group = { Id = id, Key = keyFor(id), Data = data, Online = {}, Busy = false, PublishQueued = false }
	groups[id] = group
	PlotService.claim(id, data)
	return group
end

local function releaseGroup(group: Group)
	if groups[group.Id] ~= group then
		return
	end
	groups[group.Id] = nil
	fire(releasedCallbacks, group)
	PlotService.release(group.Id)
	store:save(group.Key, group.Data, true)
end

-- Charge un groupe une seule fois même si plusieurs membres arrivent en même temps.
local function ensureLoaded(id: string): (string, Group?)
	if groups[id] then
		return "ok", groups[id]
	end
	if loading[id] then
		while loading[id] do
			task.wait(0.2)
		end
		return (if groups[id] then "ok" else "retry"), groups[id]
	end
	loading[id] = true
	local status, data = store:load(keyFor(id), { loader = GroupSchema.load })
	local group = nil
	if status == "ok" then
		group = register(id, data)
	end
	loading[id] = nil
	return status, group
end

local function createSoloGroup(player: Player): Group?
	local id = newGroupId()
	local status, data = store:load(keyFor(id), {
		loader = GroupSchema.load,
		create = function(now)
			return GroupSchema.new(id, "Bastion de " .. player.DisplayName, player.UserId, player.DisplayName, now)
		end,
	})
	if status ~= "ok" then
		return nil
	end
	return register(id, data)
end

local function attach(player: Player, group: Group)
	group.Online[player] = true
	playerGroup[player] = group.Id
	setState(player, if PlotService.get(group.Id) then "Active" else "NoPlot")
	if not PlotService.get(group.Id) then
		Notifier.send(player, Texts.NoPlot, "error")
	end
	PlotService.teleportToPlot(player, group.Id)
	fire(attachedCallbacks, player, group)
	GroupService.markChanged(group)
	publishTo(player)
end

-- Retire le joueur du groupe chargé ; libère le groupe s'il n'y a plus personne. Peut céder.
local function detach(player: Player)
	local group = GroupService.groupOf(player)
	playerGroup[player] = nil
	if not group then
		return
	end
	fire(detachedCallbacks, player, group)
	group.Online[player] = nil
	if next(group.Online) == nil then
		releaseGroup(group)
	else
		GroupService.markChanged(group)
	end
end

-- Rattache un joueur (profil chargé) à son groupe ; crée un bastion solo si besoin.
local function connectPlayer(player: Player)
	setState(player, "Loading")
	local remoteNotified = false
	while player.Parent do
		local profile = ProfileService.get(player)
		if not profile then
			return
		end

		if profile.GroupId == "" then
			local solo = createSoloGroup(player)
			if not solo then
				setState(player, "Error")
				task.wait(ERROR_RETRY)
				continue
			end
			profile.GroupId = solo.Id
			ProfileService.saveNow(player) -- si échec : le pointeur sera écrit à la prochaine sauvegarde
		end

		local id = profile.GroupId
		local status, group = ensureLoaded(id)
		if status == "retry" then
			continue
		elseif status == "locked" then
			setState(player, "Remote")
			if not remoteNotified then
				remoteNotified = true
				Notifier.send(player, Texts.GroupRemote, "error")
			end
			task.wait(REMOTE_RETRY)
			continue
		elseif status == "missing" then
			profile.GroupId = ""
			continue
		elseif status ~= "ok" or not group then
			setState(player, "Error")
			Notifier.send(player, Texts.GroupError, "error")
			task.wait(ERROR_RETRY)
			continue
		end

		if profile.GroupId ~= id then
			continue -- le pointeur a changé pendant l'attente
		end

		local resolution = Membership.resolveOnLoad(group.Data, player.UserId)
		if resolution == "notMember" then
			profile.GroupId = ""
			Notifier.send(player, string.format(Texts.Kicked, group.Data.Name), "error")
			if next(group.Online) == nil then
				releaseGroup(group)
			end
			continue
		end
		local entry = Membership.entry(group.Data, player.UserId)
		if resolution == "promote" then
			entry.Status = "Active" -- l'étape 2 du protocole avait abouti
		end
		entry.Name = player.DisplayName
		attach(player, group)
		return
	end
end

-- Opérations d'appartenance (appelées via Net) ------------------------------------------

function GroupService.invite(player: Player, targetUserId: number)
	local group = GroupService.groupOf(player)
	if not group then
		return result(false, Texts.NotMember)
	end
	if not GroupService.canMutate(group) then
		return result(false, Texts.ReadOnly)
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or not ProfileService.get(target) then
		return result(false, "Joueur introuvable sur ce serveur.")
	end
	local ok, reason = Membership.canInvite(Groups, group.Data, player.UserId, targetUserId, Game.MaxGroupSize)
	if not ok then
		local messages = { NoPermission = Texts.NoPermission, AlreadyMember = "Déjà membre.", Full = Texts.GroupFull }
		return result(false, messages[reason] or reason)
	end
	invites[target] = {
		GroupId = group.Id,
		GroupName = group.Data.Name,
		FromName = player.DisplayName,
		Expires = os.time() + Game.InviteSeconds,
	}
	Notifier.send(target, string.format(Texts.InviteReceived, player.DisplayName, group.Data.Name), "info")
	publishTo(target)
	return result(true, string.format(Texts.InviteSent, target.DisplayName))
end

function GroupService.respondInvite(player: Player, accept: boolean, confirmAbandon: boolean)
	local invite = invites[player]
	if not invite or invite.Expires < os.time() then
		invites[player] = nil
		publishTo(player)
		return result(false, Texts.InviteExpired)
	end
	if not accept then
		invites[player] = nil
		publishTo(player)
		return result(true, "Invitation refusée.")
	end

	local target = groups[invite.GroupId]
	local current = GroupService.groupOf(player)
	local profile = ProfileService.get(player)
	if not target or not current or not profile then
		return result(false, Texts.InviteExpired)
	end
	if target == current then
		invites[player] = nil
		return result(false, "Déjà membre.")
	end
	if target.Busy or current.Busy then
		return result(false, "Opération en cours, réessaie dans un instant.")
	end
	if
		not GroupService.canMutate(target)
		or not GroupService.canMutate(current)
		or not ProfileService.canMutate(player)
	then
		return result(false, Texts.ReadOnly)
	end
	local canLeave, reason = Membership.canLeave(current.Data, player.UserId)
	if not canLeave then
		return result(false, if reason == "AdminFirst" then Texts.AdminFirst else Texts.NotMember)
	end
	if Membership.activeCount(current.Data) == 1 and not confirmAbandon then
		return result(
			false,
			"Tu es seul dans ton bastion actuel : il sera abandonné (ses constructions restent avec lui). Confirme pour rejoindre.",
			"ConfirmAbandon"
		)
	end
	if Membership.count(target.Data) >= Game.MaxGroupSize then
		return result(false, Texts.GroupFull)
	end

	local key = Membership.key(player.UserId)
	target.Busy, current.Busy = true, true

	-- Étape 1 : réservation (Pending) dans le groupe cible, sauvegardée.
	target.Data.Members[key] =
		{ Role = Groups.DefaultRole, Status = "Pending", Name = player.DisplayName, JoinedAt = os.time() }
	if not store:save(target.Key, target.Data) then
		target.Data.Members[key] = nil
		target.Busy, current.Busy = false, false
		return result(false, "Sauvegarde impossible, réessaie.")
	end

	-- Étape 2 : le profil (référence) pointe vers le nouveau groupe.
	profile.GroupId = target.Id
	if not ProfileService.saveNow(player) then
		profile.GroupId = current.Id
		target.Data.Members[key] = nil
		task.spawn(store.save, store, target.Key, target.Data)
		target.Busy, current.Busy = false, false
		return result(false, "Sauvegarde impossible, réessaie.")
	end

	-- Étape 3 : confirmation et retrait de l'ancien groupe.
	target.Data.Members[key].Status = "Active"
	Membership.remove(current.Data, player.UserId)
	invites[player] = nil
	target.Busy, current.Busy = false, false

	detach(player) -- libère l'ancien bastion s'il est vide (sauvegarde incluse)
	if groups[current.Id] then
		task.spawn(store.save, store, current.Key, current.Data)
	end
	attach(player, target)
	task.spawn(store.save, store, target.Key, target.Data)

	for member in target.Online do
		if member ~= player then
			Notifier.send(member, string.format(Texts.MemberJoined, player.DisplayName), "success")
		end
	end
	return result(true, string.format(Texts.JoinedGroup, target.Data.Name))
end

function GroupService.leave(player: Player, confirm: boolean)
	local current = GroupService.groupOf(player)
	local profile = ProfileService.get(player)
	if not current or not profile then
		return result(false, Texts.NotMember)
	end
	if not GroupService.canMutate(current) or not ProfileService.canMutate(player) then
		return result(false, Texts.ReadOnly)
	end
	local canLeave, reason = Membership.canLeave(current.Data, player.UserId)
	if not canLeave then
		return result(false, if reason == "AdminFirst" then Texts.AdminFirst else Texts.NotMember)
	end
	if Membership.activeCount(current.Data) == 1 then
		return result(false, "Tu es le seul membre : ton bastion t'appartient déjà.")
	end
	if not confirm then
		return result(false, Texts.ConfirmNeeded, "Confirm")
	end
	if current.Busy then
		return result(false, "Opération en cours, réessaie dans un instant.")
	end
	current.Busy = true
	local solo = createSoloGroup(player)
	if not solo then
		current.Busy = false
		return result(false, "Sauvegarde impossible, réessaie.")
	end
	profile.GroupId = solo.Id
	if not ProfileService.saveNow(player) then
		profile.GroupId = current.Id
		current.Busy = false
		releaseGroup(solo)
		return result(false, "Sauvegarde impossible, réessaie.")
	end
	Membership.remove(current.Data, player.UserId)
	current.Busy = false
	detach(player)
	if groups[current.Id] then
		task.spawn(store.save, store, current.Key, current.Data)
		for member in current.Online do
			Notifier.send(member, player.DisplayName .. " a quitté le bastion.", "info")
		end
	end
	attach(player, solo)
	return result(true, Texts.LeftGroup)
end

function GroupService.kick(player: Player, targetUserId: number, confirm: boolean)
	local group, err = GroupService.authorize(player, "Manage")
	if not group then
		return result(false, err)
	end
	if targetUserId == player.UserId or not Membership.entry(group.Data, targetUserId) then
		return result(false, "Membre introuvable.")
	end
	if not confirm then
		return result(false, Texts.ConfirmNeeded, "Confirm")
	end
	local name = Membership.entry(group.Data, targetUserId).Name
	Membership.remove(group.Data, targetUserId)
	task.spawn(store.save, store, group.Key, group.Data)

	local target = Players:GetPlayerByUserId(targetUserId)
	if target and playerGroup[target] == group.Id then
		local profile = ProfileService.get(target)
		detach(target)
		if profile then
			profile.GroupId = ""
		end
		Notifier.send(target, string.format(Texts.Kicked, group.Data.Name), "error")
		task.spawn(connectPlayer, target) -- nouveau bastion solo
	end
	GroupService.markChanged(group)
	return result(true, tostring(name) .. " a été retiré du groupe.")
end

function GroupService.transferAdmin(player: Player, targetUserId: number)
	local group, err = GroupService.authorize(player, "Manage")
	if not group then
		return result(false, err)
	end
	local ok = Membership.transferAdmin(Groups, group.Data, player.UserId, targetUserId)
	if not ok then
		return result(false, "Membre introuvable.")
	end
	task.spawn(store.save, store, group.Key, group.Data)
	GroupService.markChanged(group)
	local name = Membership.entry(group.Data, targetUserId).Name
	for member in group.Online do
		Notifier.send(member, string.format(Texts.AdminTransferred, tostring(name)), "info")
	end
	return result(true)
end

-- Cycle de vie -------------------------------------------------------------------------

function GroupService.init()
	store = Store.new("Groups_v1")
end

function GroupService.start()
	ProfileService.onLoaded(function(player)
		connectPlayer(player)
	end)

	-- Au départ du joueur (avant la sauvegarde de son profil).
	ProfileService.onRemoving(function(player)
		invites[player] = nil
		detach(player)
	end)

	-- Chaque réapparition se fait dans la base du groupe.
	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			local id = playerGroup[player]
			if id then
				task.defer(PlotService.teleportToPlot, player, id)
			end
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end

	-- Sauvegardes périodiques étalées des groupes (renouvellent le verrou).
	task.spawn(function()
		local nextSave: { [string]: number } = {}
		while true do
			task.wait(5)
			local now = os.clock()
			for id, group in groups do
				if not nextSave[id] then
					nextSave[id] = now + Store.nextAutosaveDelay()
				elseif now >= nextSave[id] then
					nextSave[id] = now + Store.nextAutosaveDelay()
					task.spawn(function()
						local ok = store:save(group.Key, group.Data)
						if not ok and store:isLost(group.Key) then
							for player in group.Online do
								setState(player, "ReadOnly")
								Notifier.send(player, Texts.ReadOnly, "error")
							end
						end
					end)
				end
			end
			for id in nextSave do
				if not groups[id] then
					nextSave[id] = nil
				end
			end
		end
	end)

	-- Expiration des invitations.
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for player, invite in invites do
				if invite.Expires < now then
					invites[player] = nil
					publishTo(player)
				end
			end
		end
	end)
end

return GroupService
