--[[
	Profil PERSONNEL d'un joueur (cahier §3, §8, §10). Module pur.
	Règle : ne jamais supprimer/renommer un champ publié sans migration.
]]

local ProfileSchema = {}

ProfileSchema.VERSION = 3

function ProfileSchema.template()
	return {
		Version = ProfileSchema.VERSION,
		GroupId = "", -- "" = aucun groupe (un bastion solo sera créé)
		Gold = 0,
		Level = 1,
		TrainXp = 0,
		Tree = {}, -- arbre d'améliorations : { [NodeId] = true }
		Trophies = 0, -- monnaie de combat (Rue des boss, boss)
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
		Daily = { Day = 0, Cycle = 1, LastClaimDay = -1 }, -- calendrier 7 jours cumulés
		Title = "", -- titre équipé ("" = le plus prestigieux débloqué)
		Quest = 1, -- index de la mission personnelle en cours (Config/Quests)
		TitlesSeen = {}, -- titres déjà annoncés { [Id] = true }
		BestLevel = 1, -- plus haut niveau atteint (ne baisse pas à la renaissance)
		Playtime = { Day = -1, Seconds = 0, Claimed = {} }, -- temps de jeu actif du jour UTC
		Pass = { Season = 0, Xp = 0, Free = {}, Premium = {} }, -- parcours du champion (saison)
		Stats = { FirstJoin = 0, PlaySeconds = 0, Harvests = 0, TrophiesEarned = 0, TrainSeconds = 0 },
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
	-- v2 -> v3 : améliorations « Concentration » / « Robustesse » converties en nœuds de l'arbre.
	[2] = function(data)
		data.Tree = data.Tree or {}
		local upgrades = data.Upgrades or {}
		for i = 1, math.min(upgrades.Focus or 0, 5) do
			data.Tree["Focus" .. i] = true
		end
		for i = 1, math.min(upgrades.Toughness or 0, 3) do
			data.Tree["Tough" .. i] = true
		end
		data.Upgrades = nil
		data.Version = 3
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
