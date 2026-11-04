--[[
	Profil PERSONNEL d'un joueur (cahier §3, §8, §10). Module pur.
	Règle : ne jamais supprimer/renommer un champ publié sans migration.
]]

local ProfileSchema = {}

ProfileSchema.VERSION = 2

function ProfileSchema.template()
	return {
		Version = ProfileSchema.VERSION,
		GroupId = "", -- "" = aucun groupe (un bastion solo sera créé)
		Gold = 0,
		Level = 1,
		TrainXp = 0,
		Upgrades = {}, -- { [UpgradeId] = niveau }
		-- Rendement AFK durable (par seconde) au dernier instant comptabilisé, hors bonus temporaires.
		-- Sert au calcul hors ligne : les améliorations obtenues pendant l'absence ne s'appliquent pas.
		AfkRate = { Xp = 0, Gold = 0 },
		LastAccounted = 0, -- os.time() de la dernière période comptabilisée (en ligne ou hors ligne)
		OfflineCarry = { Xp = 0, Gold = 0 }, -- fractions reportées
		Ops = {}, -- OpLog : reçus et récompenses uniques traités
		Entitlements = {}, -- droits durables { [Key] = true } (passes, cadeaux uniques)
		Rebirths = 0,
		Pets = {}, -- inventaire { { Uid, PetId } }
		EquippedPets = {}, -- liste d'Uid équipés
		NextPetUid = 1,
		BossKills = {}, -- { [BossId] = nombre de victoires validées }
		Street = { Stage = 1, Best = 0, Kills = 0 }, -- Rue des boss : étape en cours, meilleure, ennemis vaincus
		Stats = { FirstJoin = 0, PlaySeconds = 0, Harvests = 0 },
	}
end

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
ProfileSchema.deepCopy = deepCopy

function ProfileSchema.reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			ProfileSchema.reconcile(data[key], value)
		end
	end
	return data
end

local MIGRATIONS = {
	-- v1 (prototype initial, bases personnelles produisant de l'or) -> v2
	[1] = function(data)
		data.TrainXp = data.Xp or 0
		data.Xp = nil
		data.LastAccounted = data.LastOnline or 0
		data.LastOnline = nil
		data.Ops = {}
		for _, purchaseId in data.Receipts or {} do
			table.insert(data.Ops, "receipt:" .. tostring(purchaseId))
		end
		data.Receipts = nil
		data.Buildings = nil -- les bâtiments appartiennent désormais au groupe
		data.Version = 2
	end,
}

function ProfileSchema.migrate(data)
	data.Version = data.Version or 1
	while MIGRATIONS[data.Version] do
		MIGRATIONS[data.Version](data)
	end
	return data
end

-- Données brutes (nil = nouveau joueur) -> profil utilisable. Ne modifie pas `raw`.
function ProfileSchema.load(raw)
	if type(raw) ~= "table" then
		return ProfileSchema.template()
	end
	local data = deepCopy(raw)
	ProfileSchema.migrate(data)
	ProfileSchema.reconcile(data, ProfileSchema.template())
	return data
end

return ProfileSchema
