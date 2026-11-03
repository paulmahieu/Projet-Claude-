--[[
	DataService : chargement / sauvegarde des données joueur via DataStoreService.

	Protections :
	- Verrou de session : un seul serveur à la fois possède les données d'un joueur.
	  Évite la duplication / perte de progression quand un joueur change vite de serveur.
	- Un serveur qui a perdu le verrou n'écrit plus (pas d'écrasement).
	- Sauvegarde automatique + sauvegarde à la fermeture du serveur (BindToClose).
	- Si le chargement échoue, le joueur est expulsé plutôt que de jouer sur des données vides
	  qui écraseraient sa vraie progression.
	- En Studio sans « Enable Studio Access to API Services », bascule en mode mémoire
	  (rien n'est sauvegardé, un avertissement l'indique).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DataSchema = require(Shared.DataSchema)
local Economy = require(Shared.Config.Economy)

local STORE_NAME = "PlayerData_v1"
local LOAD_ATTEMPTS = 6
local RETRY_DELAY = 5

local DataService = {}

local store: DataStore? = nil
local memoryMode = false
local memoryStore = {} -- utilisé uniquement en mode mémoire

local profiles = {} -- [Player] = data
local loadedCallbacks = {}
local releasing = {} -- [Player] = true pendant la sauvegarde finale

local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(math.random(1, 1e9))

local function keyFor(userId: number): string
	return "u_" .. userId
end

local function enableMemoryMode(reason: string)
	if not memoryMode then
		memoryMode = true
		warn("[DataService] Mode mémoire : la progression NE SERA PAS sauvegardée. Raison : " .. reason)
	end
end

local function isStudioApiError(err): boolean
	-- Le libellé exact varie selon les versions ; on reste large mais limité à Studio.
	local text = string.lower(tostring(err))
	return RunService:IsStudio() and (string.find(text, "studio") ~= nil or string.find(text, "api") ~= nil)
end

-- Exécute UpdateAsync avec gestion du mode mémoire. Retourne ok, result|err.
local function update(key: string, transform)
	if memoryMode then
		local newValue = transform(memoryStore[key])
		if newValue ~= nil then
			memoryStore[key] = newValue
		end
		return true, newValue
	end
	local ok, result = pcall(function()
		return (store :: DataStore):UpdateAsync(key, transform)
	end)
	if not ok and isStudioApiError(result) then
		enableMemoryMode("Studio sans accès aux API (Game Settings > Security)")
		return update(key, transform)
	end
	return ok, result
end

local function loadAsync(player: Player)
	local key = keyFor(player.UserId)

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local loadedData = nil
		-- Au dernier essai, on vole un verrou même récent : l'autre serveur ne pourra plus écrire.
		local forceSteal = attempt == LOAD_ATTEMPTS

		local ok, err = update(key, function(old)
			local lock = old and old.Lock
			if
				lock
				and lock.JobId ~= jobId
				and not forceSteal
				and os.time() - (lock.Time or 0) < Economy.Save.LockTimeoutSeconds
			then
				lockedElsewhere = true
				return nil -- annule l'écriture
			end
			loadedData = DataSchema.load(old and old.Data, Economy.StartingGold)
			return {
				Data = loadedData,
				Lock = { JobId = jobId, Time = os.time() },
			}
		end)

		if ok and loadedData then
			return loadedData
		end

		if not ok then
			warn(
				string.format(
					"[DataService] Échec du chargement de %s (essai %d) : %s",
					player.Name,
					attempt,
					tostring(err)
				)
			)
		elseif lockedElsewhere then
			warn(
				string.format(
					"[DataService] Données de %s verrouillées par un autre serveur, nouvel essai...",
					player.Name
				)
			)
		end

		if player.Parent == nil then
			return nil
		end
		task.wait(RETRY_DELAY)
	end
	return nil
end

-- Sauvegarde. release = true libère le verrou (départ du joueur / arrêt du serveur).
local function saveAsync(player: Player, data, release: boolean): boolean
	data.LastOnline = os.time()
	local lostLock = false

	local ok, err = update(keyFor(player.UserId), function(old)
		if old and old.Lock and old.Lock.JobId ~= jobId then
			lostLock = true
			return nil
		end
		return {
			Data = data,
			Lock = if release then nil else { JobId = jobId, Time = os.time() },
		}
	end)

	if not ok then
		warn(string.format("[DataService] Échec de sauvegarde de %s : %s", player.Name, tostring(err)))
		return false
	end
	if lostLock then
		warn(
			string.format(
				"[DataService] %s : verrou perdu, sauvegarde ignorée pour éviter un écrasement.",
				player.Name
			)
		)
		return false
	end
	return true
end

function DataService.get(player: Player)
	return profiles[player]
end

-- Appelé une fois les données chargées : fn(player, data)
function DataService.onLoaded(fn)
	table.insert(loadedCallbacks, fn)
	for player, data in profiles do
		task.spawn(fn, player, data)
	end
end

-- Sauvegarde immédiate (ex. après un achat Robux). Retourne true si réussi.
function DataService.saveNow(player: Player): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	return saveAsync(player, data, false)
end

function DataService.isMemoryMode(): boolean
	return memoryMode
end

local function onPlayerAdded(player: Player)
	local data = loadAsync(player)

	if player.Parent == nil then
		-- Parti pendant le chargement : on libère le verrou qu'on vient de prendre.
		if data then
			saveAsync(player, data, true)
		end
		return
	end

	if not data then
		player:Kick("Impossible de charger votre progression. Réessayez dans quelques instants.")
		return
	end

	profiles[player] = data
	for _, fn in loadedCallbacks do
		task.spawn(fn, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local data = profiles[player]
	if not data or releasing[player] then
		return
	end
	releasing[player] = true
	saveAsync(player, data, true)
	profiles[player] = nil
	releasing[player] = nil
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		enableMemoryMode(tostring(result))
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Sauvegarde automatique (renouvelle aussi le verrou).
	task.spawn(function()
		while true do
			task.wait(Economy.Save.AutosaveSeconds)
			for player, data in profiles do
				if not releasing[player] then
					task.spawn(saveAsync, player, data, false)
				end
			end
		end
	end)

	-- Arrêt du serveur : on sauvegarde tout le monde en parallèle (Roblox laisse ~30 s).
	game:BindToClose(function()
		for player in profiles do
			task.spawn(onPlayerRemoving, player)
		end
		-- onPlayerRemoving retire le profil une fois la sauvegarde terminée
		-- (y compris quand c'est PlayerRemoving qui l'a déclenchée).
		local deadline = os.clock() + 25
		while next(profiles) ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
