--[[
	Format des données sauvegardées d'un joueur + migrations.
	Module pur : testable avec Lune.

	Règle : on n'enlève ni ne renomme jamais un champ publié ; on ajoute une migration.
]]

local DataSchema = {}

DataSchema.VERSION = 1
DataSchema.MAX_RECEIPTS = 50

function DataSchema.template(startingGold: number)
	return {
		Version = DataSchema.VERSION,
		Gold = startingGold,
		Buildings = {}, -- { [buildingId] = true }
		Level = 1,
		Xp = 0,
		LastOnline = 0, -- os.time() de la dernière sauvegarde
		Receipts = {}, -- liste des PurchaseId déjà traités (anti double-crédit)
		Stats = {
			TotalEarned = 0,
			PlaySeconds = 0,
		},
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
DataSchema.deepCopy = deepCopy

-- Ajoute les champs manquants (nouvelles fonctionnalités) sans écraser l'existant.
function DataSchema.reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			DataSchema.reconcile(data[key], value)
		end
	end
	return data
end

-- Migrations successives : MIGRATIONS[n] transforme la version n en n+1.
local MIGRATIONS = {
	-- [1] = function(data) ... data.Version = 2 end,
}

function DataSchema.migrate(data)
	data.Version = data.Version or 1
	while MIGRATIONS[data.Version] do
		MIGRATIONS[data.Version](data)
	end
	return data
end

-- Charge des données brutes (ou nil pour un nouveau joueur) en données utilisables.
function DataSchema.load(raw, startingGold: number)
	local template = DataSchema.template(startingGold)
	if type(raw) ~= "table" then
		return template
	end
	local data = deepCopy(raw)
	DataSchema.migrate(data)
	DataSchema.reconcile(data, template)
	return data
end

function DataSchema.hasReceipt(data, purchaseId: string): boolean
	return table.find(data.Receipts, purchaseId) ~= nil
end

function DataSchema.addReceipt(data, purchaseId: string)
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > DataSchema.MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
end

return DataSchema
