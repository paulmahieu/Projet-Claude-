--[[
	Tests des modules purs (formules, schéma de données, configuration).
	Lancement : lune run tests/shared.spec
]]

local Formulas = require("../src/shared/Formulas")
local DataSchema = require("../src/shared/DataSchema")
local Buildings = require("../src/shared/Config/Buildings")
local Economy = require("../src/shared/Config/Economy")
local Training = require("../src/shared/Config/Training")
local Products = require("../src/shared/Config/Products")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

local function eq(actual, expected, msg: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sattendu %s, obtenu %s",
				if msg then msg .. " : " else "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

print("Formulas")

test("production de base = somme des bâtiments possédés", function()
	eq(Formulas.baseIncome(Buildings, {}), 0)
	eq(Formulas.baseIncome(Buildings, { Campfire = true, WoodcutterHut = true }), 4)
end)

test("bonus de niveau et passe multiplient la production", function()
	local owned = { Campfire = true, WoodcutterHut = true } -- 4 or/s
	eq(Formulas.incomePerSecond(Buildings, owned, 1, 0.01, 1), 4)
	eq(Formulas.incomePerSecond(Buildings, owned, 11, 0.01, 2), 4 * 1.1 * 2)
end)

test("canBuy vérifie existence, doublon, prérequis et or", function()
	local camp = Buildings[1]
	local hut = Buildings[2]
	eq(select(2, Formulas.canBuy(nil, {}, 1e9)), "Bâtiment inconnu")
	eq(select(2, Formulas.canBuy(camp, { Campfire = true }, 1e9)), "Déjà construit")
	eq(select(2, Formulas.canBuy(hut, {}, 1e9)), "Prérequis manquant")
	eq(select(2, Formulas.canBuy(camp, {}, camp.Cost - 1)), "Or insuffisant")
	eq(Formulas.canBuy(camp, {}, camp.Cost), true)
end)

test("availableBuildings suit la chaîne de prérequis", function()
	local list = Formulas.availableBuildings(Buildings, {})
	eq(#list, 1)
	eq(list[1].Id, "Campfire")
	list = Formulas.availableBuildings(Buildings, { Campfire = true })
	eq(list[1].Id, "WoodcutterHut")
end)

test("addXp gère plusieurs montées de niveau d'un coup", function()
	local need1 = Formulas.xpToNext(1, Training)
	local need2 = Formulas.xpToNext(2, Training)
	local level, xp, gained = Formulas.addXp(1, 0, need1 + need2 + 3, Training)
	eq(level, 3)
	eq(xp, 3)
	eq(gained, 2)
end)

test("addXp plafonne au niveau max", function()
	local level, xp = Formulas.addXp(Training.MaxLevel - 1, 0, 1e12, Training)
	eq(level, Training.MaxLevel)
	eq(xp, 0)
end)

test("gains hors ligne : plafond, taux, absence trop courte, horloge négative", function()
	local cfg = Economy.Offline
	eq(Formulas.offlineEarnings(10, 30, cfg), 0, "absence < minimum")
	eq(Formulas.offlineEarnings(10, -500, cfg), 0, "horloge négative")
	eq(Formulas.offlineEarnings(0, 3600, cfg), 0, "aucune production")
	local gold, seconds = Formulas.offlineEarnings(10, 3600, cfg)
	eq(gold, 10 * 3600 * cfg.Rate)
	eq(seconds, 3600)
	gold, seconds = Formulas.offlineEarnings(10, 10 * 24 * 3600, cfg)
	eq(seconds, cfg.MaxSeconds, "plafond")
	eq(gold, 10 * cfg.MaxSeconds * cfg.Rate)
end)

test("récompense indexée sur la production avec minimum", function()
	eq(Formulas.incomeMinutesReward(0, 10, 500), 500)
	eq(Formulas.incomeMinutesReward(100, 10, 500), 60000)
end)

test("clampGold rejette NaN et négatifs", function()
	eq(Formulas.clampGold(0 / 0, 100), 0)
	eq(Formulas.clampGold(-5, 100), 0)
	eq(Formulas.clampGold(1e20, 100), 100)
end)

test("formatNumber", function()
	eq(Formulas.formatNumber(999), "999")
	eq(Formulas.formatNumber(1000), "1K")
	eq(Formulas.formatNumber(1234), "1,2K")
	eq(Formulas.formatNumber(250000), "250K")
	eq(Formulas.formatNumber(3.75e6), "3,7M")
end)

test("formatDuration", function()
	eq(Formulas.formatDuration(45), "45 s")
	eq(Formulas.formatDuration(600), "10 min")
	eq(Formulas.formatDuration(8130), "2 h 15 min")
end)

print("DataSchema")

test("nouveau joueur = modèle par défaut", function()
	local data = DataSchema.load(nil, 50)
	eq(data.Gold, 50)
	eq(data.Level, 1)
	eq(data.Version, DataSchema.VERSION)
end)

test("reconcile ajoute les champs manquants sans écraser", function()
	local data = DataSchema.load({ Gold = 999, Buildings = { Campfire = true } }, 50)
	eq(data.Gold, 999)
	eq(data.Buildings.Campfire, true)
	eq(data.Level, 1)
	eq(data.Stats.TotalEarned, 0)
end)

test("load ne modifie pas l'objet brut", function()
	local raw = { Gold = 1 }
	DataSchema.load(raw, 50)
	eq(raw.Level, nil)
end)

test("reçus : idempotence et taille bornée", function()
	local data = DataSchema.load(nil, 0)
	for i = 1, DataSchema.MAX_RECEIPTS + 10 do
		DataSchema.addReceipt(data, "p" .. i)
	end
	eq(#data.Receipts, DataSchema.MAX_RECEIPTS)
	eq(DataSchema.hasReceipt(data, "p1"), false, "les plus anciens sont oubliés")
	eq(DataSchema.hasReceipt(data, "p" .. (DataSchema.MAX_RECEIPTS + 10)), true)
end)

print("Configuration")

test("bâtiments : Id uniques, prérequis existants et antérieurs", function()
	local seen = {}
	for _, def in Buildings do
		assert(not seen[def.Id], "Id en double : " .. def.Id)
		if def.Requires then
			assert(seen[def.Requires], def.Id .. " requiert " .. def.Requires .. " qui n'est pas défini avant")
		end
		seen[def.Id] = true
		assert(def.Cost > 0 and def.Income >= 0, def.Id .. " : coût/production invalides")
	end
end)

test("bâtiments : rentabilité croissante raisonnable (< 10 min)", function()
	for _, def in Buildings do
		local payback = def.Cost / math.max(def.Income, 1e-9)
		assert(payback <= 600, string.format("%s rentabilisé en %ds", def.Id, payback))
	end
end)

test("bâtiments : emprises sans chevauchement et dans la parcelle", function()
	local half = 55
	local function box(def)
		local x, z, sx, sz = def.Offset[1], def.Offset[2], def.Size[1], def.Size[3]
		-- Le pad d'achat est devant le bâtiment : on l'inclut dans l'emprise.
		return x - sx / 2, x + sx / 2, z - sz / 2 - 7, z + sz / 2
	end
	for i, a in Buildings do
		local ax1, ax2, az1, az2 = box(a)
		assert(ax1 >= -half and ax2 <= half and az1 >= -half and az2 <= half, a.Id .. " sort de la parcelle")
		for j = i + 1, #Buildings do
			local b = Buildings[j]
			local bx1, bx2, bz1, bz2 = box(b)
			local overlap = ax1 < bx2 and bx1 < ax2 and az1 < bz2 and bz1 < az2
			assert(not overlap, a.Id .. " chevauche " .. b.Id)
		end
	end
end)

test("produits : clés uniques et récompenses connues", function()
	local keys = {}
	for _, p in Products.DevProducts do
		assert(not keys[p.Key], "clé en double " .. p.Key)
		keys[p.Key] = true
		eq(p.Reward.Type, "IncomeMinutes")
	end
end)

print(string.format("\n%d réussi(s), %d échec(s)", passed, failed))
if failed > 0 then
	error("Des tests ont échoué")
end
