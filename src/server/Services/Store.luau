--[[
	Store : enregistrements DataStore protégés par un verrou de session (cahier §10).
	Utilisé pour les profils ("u_<UserId>") et les groupes ("g_<GroupId>").

	Garanties :
	- Un seul serveur détient l'autorité sur une clé (SessionLock). Chaque écriture vérifie
	  que ce serveur la détient toujours ; sinon la session est marquée « perdue » et toute
	  modification ultérieure est refusée (canMutate).
	- Si le renouvellement échoue trop longtemps, canMutate devient faux AVANT l'expiration
	  du verrou : un serveur figé qui se réveille ne modifie plus rien.
	- Les transformations UpdateAsync sont rejouables : elles ne dépendent que de l'ancienne
	  valeur et d'une heure capturée AVANT l'appel (pas d'attente ni d'effet externe).
	- Erreurs : nouvelles tentatives à délai croissant borné, respect du budget de requêtes.
	- Un échec de chargement n'est JAMAIS traité comme un nouveau compte.
	- Studio sans accès API : bascule en mode mémoire (rien n'est sauvegardé, signalé).
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SessionLock = require(Shared.SessionLock)
local Economy = require(Shared.Config.Economy)

local SAVE = Economy.Save

local Store = {}
Store.__index = Store

local memoryMode = false
local memory: { [string]: { [string]: any } } = {}
local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(math.random(1, 1e9))

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function enableMemoryMode(reason: string)
	if not memoryMode then
		memoryMode = true
		warn("[Store] Mode mémoire : rien ne sera sauvegardé. Raison : " .. reason)
	end
end

local function isStudioApiError(err): boolean
	-- Le libellé exact varie selon les versions ; on reste large mais limité à Studio.
	local text = string.lower(tostring(err))
	return RunService:IsStudio()
		and (
			string.find(text, "studio") ~= nil
			or string.find(text, "api") ~= nil
			or string.find(text, "publish") ~= nil
		)
end

local function waitForBudget()
	local deadline = os.clock() + 10
	while os.clock() < deadline do
		local ok, budget = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		end)
		if not ok or budget > 0 then
			return
		end
		task.wait(1)
	end
end

function Store.isMemoryMode(): boolean
	return memoryMode
end

function Store.jobId(): string
	return jobId
end

function Store.new(name: string)
	local self = setmetatable({ Name = name, Sessions = {}, DataStore = nil }, Store)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok then
		self.DataStore = result
	else
		enableMemoryMode(tostring(result))
	end
	return self
end

function Store:_updateOnce(key: string, transform)
	if memoryMode then
		local bucket = memory[self.Name]
		if not bucket then
			bucket = {}
			memory[self.Name] = bucket
		end
		-- Copies pour imiter la sérialisation réelle (aucun partage de référence).
		local newValue = transform(deepCopy(bucket[key]))
		if newValue ~= nil then
			bucket[key] = deepCopy(newValue)
		end
		return true, nil
	end
	waitForBudget()
	local ok, err = pcall(function()
		return self.DataStore:UpdateAsync(key, transform)
	end)
	if not ok and isStudioApiError(err) then
		enableMemoryMode("Studio sans accès aux API (Game Settings > Security)")
		return self:_updateOnce(key, transform)
	end
	return ok, err
end

function Store:_update(key: string, transform, attempts: number)
	local lastErr
	for attempt = 1, attempts do
		local ok, err = self:_updateOnce(key, transform)
		if ok then
			return true, nil
		end
		lastErr = err
		warn(string.format("[Store:%s] %s essai %d/%d : %s", self.Name, key, attempt, attempts, tostring(err)))
		if attempt < attempts then
			task.wait(math.min(2 ^ attempt, 8))
		end
	end
	return false, lastErr
end

--[[
	Charge une clé et prend son verrou.
	opts.loader(rawData) -> data | nil   (pur ; nil = données inexploitables -> "missing")
	opts.create(now)     -> data | nil   (si la clé n'existe pas ; nil = ne pas créer)
	opts.onLoad(data, now) -> extra      (pur ; ex. crédit hors ligne appliqué dans la même écriture)
	opts.steal           : prendre le verrou même s'il est détenu ailleurs
	Retourne status ("ok" | "locked" | "missing" | "error"), data, extra
	(pour "locked", extra = JobId du serveur détenteur du verrou)
]]
function Store:load(key: string, opts)
	local now = os.time() -- capturée une fois : stable si la transformation est rejouée
	local status, result, extra

	local ok = self:_update(key, function(old)
		status, result, extra = nil, nil, nil
		local lock = SessionLock.acquire(old, jobId, now, SAVE.LockSeconds, opts.steal)
		if not lock then
			status = "locked"
			extra = old and old.Lock and old.Lock.JobId -- serveur qui détient la clé (rejoindre)
			return nil
		end
		local data
		if type(old) ~= "table" or old.Data == nil then
			data = opts.create and opts.create(now)
		else
			data = opts.loader(old.Data)
		end
		if data == nil then
			status = "missing"
			return nil
		end
		if opts.onLoad then
			extra = opts.onLoad(data, now)
		end
		status, result = "ok", data
		return { Data = data, Lock = lock }
	end, 3)

	if not ok then
		return "error", nil, nil
	end
	if status == "ok" then
		self.Sessions[key] = { LastRenew = now, Lost = false }
	end
	return status, result, extra
end

-- Sauvegarde (et renouvelle le verrou). release = libérer le verrou.
function Store:save(key: string, data, release: boolean?): boolean
	local session = self.Sessions[key]
	if not session or session.Lost then
		return false
	end
	local now = os.time()
	local lost = false
	local ok = self:_update(key, function(old)
		lost = false
		if not SessionLock.canWrite(old, jobId) then
			lost = true
			return nil
		end
		return {
			Data = data,
			Lock = if release then nil else { JobId = jobId, Expires = now + SAVE.LockSeconds },
		}
	end, 3)

	if lost then
		session.Lost = true
		warn(string.format("[Store:%s] %s : autorité perdue, plus aucune écriture.", self.Name, key))
		return false
	end
	if not ok then
		return false
	end
	session.LastRenew = now
	if release then
		self.Sessions[key] = nil
	end
	return true
end

-- Ce serveur peut-il encore modifier cet enregistrement ?
function Store:canMutate(key: string): boolean
	local session = self.Sessions[key]
	if not session or session.Lost then
		return false
	end
	if memoryMode then
		return true
	end
	return os.time() - session.LastRenew < SAVE.LockSeconds - SAVE.LockSafetyMargin
end

function Store:isLost(key: string): boolean
	local session = self.Sessions[key]
	return session ~= nil and session.Lost
end

function Store:forget(key: string)
	self.Sessions[key] = nil
end

function Store.nextAutosaveDelay(): number
	return SAVE.AutosaveSeconds + math.random() * SAVE.AutosaveJitter
end

return Store
