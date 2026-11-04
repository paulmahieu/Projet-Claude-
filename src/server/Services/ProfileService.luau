--[[
	ProfileService : profil PERSONNEL des joueurs (or, niveau, améliorations, hors ligne).

	- Chargement avec verrou de session ; vol du verrou après plusieurs essais (un compte
	  Roblox ne peut pas être sur deux serveurs : l'ancien serveur perd alors le droit d'écrire).
	- Gains hors ligne crédités DANS la transformation de chargement : crédit et nouvel
	  instant comptabilisé sont écrits ensemble (cahier §8). Une reconnexion immédiate ne
	  recrédite donc jamais la même période.
	- Échec de chargement : état « Error » affiché, nouvel essai automatique, actions bloquées.
	  Le profil existant n'est jamais remplacé par des valeurs par défaut.
	- Fenêtre de perte maximale après un arrêt brutal : l'intervalle de sauvegarde
	  automatique (90 à 120 s). Achats Robux : sauvegarde immédiate avant confirmation.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProfileSchema = require(Shared.ProfileSchema)
local Formulas = require(Shared.Formulas)
local Economy = require(Shared.Config.Economy)
local Training = require(Shared.Config.Training)
local Tree = require(Shared.Config.Tree)
local Rebirth = require(Shared.Config.Rebirth)
local Pets = require(Shared.Config.Pets)
local Texts = require(Shared.Config.Texts)

local Store = require(script.Parent.Store)
local Notifier = require(script.Parent.Notifier)

local ProfileService = {}

local LOCK_RETRIES_BEFORE_STEAL = 5
local LOCK_RETRY_DELAY = 5
local ERROR_RETRY_DELAY = 15

local store
local profiles: { [Player]: any } = {}
local loadedCallbacks = {}
local beforeSaveHooks = {}
local removingCallbacks = {}
local releasing: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- Crédit hors ligne appliqué au profil (fonction pure, rejouable).
local function applyOffline(data, now: number)
	-- Plafond et taux augmentés par les nœuds « Hors ligne » de l'arbre (déjà possédés).
	local offlineCfg = Formulas.offlineConfig(Economy.Offline, Tree, data.Tree)
	local credit = Formulas.offlineCredit(data.AfkRate, data.LastAccounted, now, data.OfflineCarry, offlineCfg)
	if credit.Xp > 0 then
		data.Level, data.TrainXp = Formulas.addXp(data.Level, data.TrainXp, credit.Xp, Training)
	end
	if credit.Gold > 0 then
		data.Gold = Formulas.clamp(data.Gold + credit.Gold, Economy.GoldCap)
	end
	data.OfflineCarry = credit.Carry
	data.LastAccounted = now
	return credit
end

function ProfileService.get(player: Player)
	return profiles[player]
end

function ProfileService.canMutate(player: Player): boolean
	return profiles[player] ~= nil and store:canMutate(keyFor(player))
end

function ProfileService.onLoaded(fn)
	table.insert(loadedCallbacks, fn)
end

-- fn(player, data) appelé juste avant chaque sauvegarde (ex. instantané du rendement AFK).
function ProfileService.beforeSave(fn)
	table.insert(beforeSaveHooks, fn)
end

-- fn(player) appelé au départ, AVANT la sauvegarde finale (arrêter l'entraînement, etc.).
function ProfileService.onRemoving(fn)
	table.insert(removingCallbacks, fn)
end

local function save(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	for _, hook in beforeSaveHooks do
		local ok, err = pcall(hook, player, data)
		if not ok then
			warn("[ProfileService] beforeSave : " .. tostring(err))
		end
	end
	-- La période en ligne est comptabilisée jusqu'ici : elle ne sera pas créditée hors ligne.
	local previous = data.LastAccounted
	data.LastAccounted = os.time()
	local ok = store:save(keyFor(player), data, release)
	if not ok then
		data.LastAccounted = previous
		if store:isLost(keyFor(player)) then
			Notifier.send(player, Texts.ReadOnly, "error")
		end
	end
	return ok
end

function ProfileService.saveNow(player: Player): boolean
	return save(player, false)
end

-- Id des compagnons équipés (dans l'ordre d'équipement).
function ProfileService.equippedPetIds(player: Player): { string }
	local data = profiles[player]
	local ids = {}
	if not data then
		return ids
	end
	local byUid = {}
	for _, pet in data.Pets do
		byUid[pet.Uid] = pet.PetId
	end
	for _, uid in data.EquippedPets do
		if byUid[uid] then
			table.insert(ids, byUid[uid])
		end
	end
	return ids
end

-- Multiplicateur durable hors bastion : renaissances x compagnons équipés.
function ProfileService.personalMultiplier(player: Player): number
	local data = profiles[player]
	if not data then
		return 1
	end
	return Formulas.rebirthMultiplier(data.Rebirths, Rebirth)
		* Formulas.petMultiplier(Pets, ProfileService.equippedPetIds(player))
end

function ProfileService.treeStat(player: Player, stat: string): number
	local data = profiles[player]
	return if data then Formulas.treeStat(Tree, data.Tree, stat) else 0
end

function ProfileService.petSlots(player: Player): number
	local data = profiles[player]
	if not data then
		return 1
	end
	return Formulas.petSlots(data.Rebirths, Rebirth) + Formulas.treeStat(Tree, data.Tree, "PetSlots")
end

-- Multiplicateur de dégâts : compagnons x nœuds « Force ».
function ProfileService.damageMultiplier(player: Player): number
	return Formulas.petMultiplier(Pets, ProfileService.equippedPetIds(player))
		* (1 + ProfileService.treeStat(player, "Damage"))
end

-- Ajoute des trophées (bonus de l'arbre inclus). Retourne le montant crédité.
function ProfileService.addTrophies(player: Player, base: number): number
	local data = profiles[player]
	if not data or base <= 0 then
		return 0
	end
	local amount = Formulas.trophies(base, Formulas.treeStat(Tree, data.Tree, "TrophyMult"))
	data.Trophies += amount
	data.Stats.TrophiesEarned += amount -- total gagné (classement), indépendant des dépenses
	return amount
end

function ProfileService.power(player: Player): number
	local data = profiles[player]
	if not data then
		return Training.PowerBase
	end
	return Formulas.power(data.Level, Training, data.Rebirths, Rebirth)
end

-- Pousse l'état personnel vers le client (attributs répliqués automatiquement).
function ProfileService.sync(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Gold", math.floor(data.Gold))
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("TrainXp", math.floor(data.TrainXp))
	player:SetAttribute("XpNext", Formulas.xpToNext(data.Level, Training))
	player:SetAttribute("Power", ProfileService.power(player))
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("RebirthLevel", Formulas.rebirthRequiredLevel(data.Rebirths, Rebirth))
	player:SetAttribute("PetSlots", ProfileService.petSlots(player))
	player:SetAttribute("PetMult", Formulas.petMultiplier(Pets, ProfileService.equippedPetIds(player)))
	-- Lu par tous les clients pour afficher les compagnons qui suivent ce joueur.
	player:SetAttribute("EquippedPets", table.concat(ProfileService.equippedPetIds(player), ","))
	player:SetAttribute("Trophies", data.Trophies)
	player:SetAttribute("Luck", Formulas.treeStat(Tree, data.Tree, "Luck"))
	local owned = {}
	for id in data.Tree do
		table.insert(owned, id)
	end
	player:SetAttribute("TreeOwned", table.concat(owned, ","))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Niveau.Value = data.Level
	end
end

local function createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Niveau"
	level.Parent = folder
	folder.Parent = player
end

local function loadPlayer(player: Player)
	player:SetAttribute("ProfileState", "Loading")
	local lockedAttempts = 0

	while player.Parent do
		local status, data, credit = store:load(keyFor(player), {
			steal = lockedAttempts >= LOCK_RETRIES_BEFORE_STEAL,
			loader = ProfileSchema.load,
			create = function(now)
				local fresh = ProfileSchema.template()
				fresh.Gold = Economy.StartingGold
				fresh.Stats.FirstJoin = now
				return fresh
			end,
			onLoad = applyOffline,
		})

		if status == "ok" then
			if not player.Parent then
				-- Parti pendant le chargement : on libère le verrou.
				profiles[player] = data
				save(player, true)
				profiles[player] = nil
				return
			end
			profiles[player] = data
			player:SetAttribute("ProfileState", "Ready")
			createLeaderstats(player)
			ProfileService.sync(player)
			if Store.isMemoryMode() then
				Notifier.send(player, Texts.StudioMemory, "error")
			end
			if data.Stats.FirstJoin == data.LastAccounted then
				Notifier.send(player, Texts.Welcome, "info")
			elseif
				credit
				and credit.Seconds >= Economy.Offline.RecapMinSeconds
				and (credit.Xp > 0 or credit.Gold > 0)
			then
				Notifier.send(
					player,
					string.format(
						Texts.OfflineRecap,
						Formulas.formatDuration(credit.Seconds),
						Formulas.formatNumber(credit.Xp),
						Formulas.formatNumber(credit.Gold)
					),
					"reward"
				)
			end
			for _, fn in loadedCallbacks do
				task.spawn(fn, player, data)
			end
			return
		elseif status == "locked" then
			lockedAttempts += 1
			task.wait(LOCK_RETRY_DELAY)
		else
			-- "error" ou "missing" (données illisibles) : jamais de remplacement par défaut.
			player:SetAttribute("ProfileState", "Error")
			Notifier.send(player, Texts.LoadError, "error")
			task.wait(ERROR_RETRY_DELAY)
		end
	end
end

local function onPlayerRemoving(player: Player)
	if releasing[player] then
		return
	end
	releasing[player] = true
	for _, fn in removingCallbacks do
		local ok, err = pcall(fn, player)
		if not ok then
			warn("[ProfileService] onRemoving : " .. tostring(err))
		end
	end
	if profiles[player] then
		save(player, true)
	end
	profiles[player] = nil
	releasing[player] = nil
end

function ProfileService.init()
	store = Store.new("Profiles_v2")
end

function ProfileService.start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	-- Sauvegardes périodiques étalées (une boucle par joueur, délai aléatoire).
	task.spawn(function()
		local nextSave: { [Player]: number } = {}
		while true do
			task.wait(5)
			local now = os.clock()
			for player in profiles do
				if not nextSave[player] then
					nextSave[player] = now + Store.nextAutosaveDelay()
				elseif now >= nextSave[player] and not releasing[player] then
					nextSave[player] = now + Store.nextAutosaveDelay()
					task.spawn(save, player, false)
				end
			end
			for player in nextSave do
				if not profiles[player] then
					nextSave[player] = nil
				end
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(onPlayerRemoving, player)
		end
		local deadline = os.clock() + 25
		while next(profiles) ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return ProfileService
