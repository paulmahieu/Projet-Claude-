--[[
	Enregistrement d'un GROUPE et de sa base (cahier §4, §10). Module pur.
	Clé DataStore : "g_<GroupId>". GroupId est stable, indépendant du serveur et de la parcelle.
]]

-- Pas de require entre modules purs : ils doivent fonctionner à l'identique dans Roblox et Lune.
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

local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local GroupSchema = {}

GroupSchema.VERSION = 1

function GroupSchema.template()
	return {
		Version = GroupSchema.VERSION,
		Id = "",
		Name = "",
		CreatedAt = 0,
		-- { [tostring(UserId)] = { Role, Status = "Active" | "Pending", Name, JoinedAt } }
		Members = {},
		Materials = { Wood = 0, Stone = 0, Ore = 0, Crystal = 0 },
		Structures = {}, -- { [StructureId] = true }
		-- Placement libre (étape 2) : { { Id, Item, X, Z, Rot } } en coordonnées de grille
		-- relatives à l'origine de la parcelle -> reconstructible sur n'importe quelle parcelle.
		Placements = {},
		Ops = {},
		Abandoned = false, -- plus aucun membre : conservé mais inactif
	}
end

function GroupSchema.new(id: string, name: string, founderUserId: number, founderName: string, now: number)
	local data = GroupSchema.template()
	data.Id = id
	data.Name = name
	data.CreatedAt = now
	data.Members[tostring(founderUserId)] = { Role = "Admin", Status = "Active", Name = founderName, JoinedAt = now }
	return data
end

local MIGRATIONS = {}

function GroupSchema.load(raw)
	if type(raw) ~= "table" then
		return nil -- un groupe n'est jamais créé implicitement par un chargement
	end
	local data = deepCopy(raw)
	data.Version = data.Version or 1
	while MIGRATIONS[data.Version] do
		MIGRATIONS[data.Version](data)
	end
	reconcile(data, GroupSchema.template())
	return data
end

return GroupSchema
