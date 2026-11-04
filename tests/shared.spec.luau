--[[
	Tests des modules purs : formules, verrous, appartenance, schémas, validation, configuration.
	Lancement : lune run tests/shared.spec
]]

local Formulas = require("../src/shared/Formulas")
local SessionLock = require("../src/shared/SessionLock")
local Membership = require("../src/shared/Membership")
local ProfileSchema = require("../src/shared/ProfileSchema")
local GroupSchema = require("../src/shared/GroupSchema")
local OpLog = require("../src/shared/OpLog")
local Validate = require("../src/shared/Validate")
local Structures = require("../src/shared/Config/Structures")
local Materials = require("../src/shared/Config/Materials")
local Economy = require("../src/shared/Config/Economy")
local Training = require("../src/shared/Config/Training")
local Tree = require("../src/shared/Config/Tree")
local Products = require("../src/shared/Config/Products")
local Groups = require("../src/shared/Config/Groups")
local Game = require("../src/shared/Config/Game")
local Harvest = require("../src/shared/Config/Harvest")
local Rebirth = require("../src/shared/Config/Rebirth")
local Pets = require("../src/shared/Config/Pets")
local Bosses = require("../src/shared/Config/Bosses")
local Combat = require("../src/shared/Config/Combat")
local Street = require("../src/shared/Config/Street")
local Farm = require("../src/shared/Config/Farm")
local Rewards = require("../src/shared/Config/Rewards")
local Titles = require("../src/shared/Config/Titles")
local Quests = require("../src/shared/Config/Quests")
local Defense = require("../src/shared/Config/Defense")
local Pass = require("../src/shared/Config/Pass")
local Land = require("../src/shared/Config/Land")
local Machines = require("../src/shared/Config/Machines")

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

local function near(actual: number, expected: number, msg: string?)
	if math.abs(actual - expected) > 1e-6 then
		error(string.format("%sattendu ~%s, obtenu %s", if msg then msg .. " : " else "", expected, actual), 2)
	end
end

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in v do
		c[k] = deepCopy(x)
	end
	return c
end

----------------------------------------------------------------------------------------
print("Entraînement et progression")

test("addXp : plusieurs niveaux d'un coup, reste conservé", function()
	local n1, n2 = Formulas.xpToNext(1, Training), Formulas.xpToNext(2, Training)
	local level, xp, gained = Formulas.addXp(1, 0, n1 + n2 + 3, Training)
	eq(level, 3)
	eq(xp, 3)
	eq(gained, 2)
end)

test("addXp : plafond du niveau max", function()
	local level, xp = Formulas.addXp(Training.MaxLevel - 1, 0, 1e15, Training)
	eq(level, Training.MaxLevel)
	eq(xp, 0)
end)

test("rendement des tapis : palier x bastion x Concentration", function()
	local r0 = Formulas.trainingRates(0, 1, 0, 0.1, Training)
	eq(r0.Xp, 0, "sans tapis")
	local r = Formulas.trainingRates(2, 1.1, 3, 0.1, Training)
	near(r.Xp, Training.BaseXpPerSecond * 1.5 * 1.1 * 1.3)
	near(r.Gold, Training.BaseGoldPerSecond * 1.5 * 1.1 * 1.3)
end)

test("meilleur palier et bonus du bastion", function()
	eq(Formulas.bestStationTier(Structures, {}), 0)
	eq(Formulas.bestStationTier(Structures, { TrainingGround = true }), 1)
	eq(Formulas.bestStationTier(Structures, { TrainingGround = true, RuneMats = true }), 2)
	near(Formulas.groupTrainingMult(Structures, { Watchtower = true }), 1.1)
end)

----------------------------------------------------------------------------------------
print("Gains hors ligne (cahier §8 et vérification n°7)")

local rate = { Xp = 4, Gold = 1 }
local cfg = Economy.Offline

test("absence de 5 minutes", function()
	local c = Formulas.offlineCredit(rate, 1000, 1000 + 300, nil, cfg)
	eq(c.Seconds, 300)
	eq(c.Xp, 300) -- 300 s x 4 x 0,25
	eq(c.Gold, 75) -- 300 s x 1 x 0,25
end)

test("absence de 8 heures", function()
	local c = Formulas.offlineCredit(rate, 1000, 1000 + 8 * 3600, nil, cfg)
	eq(c.Seconds, 8 * 3600)
	eq(c.Gold, 8 * 3600 * 0.25)
end)

test("absence de 48 heures plafonnée à 8 heures", function()
	local c = Formulas.offlineCredit(rate, 1000, 1000 + 48 * 3600, nil, cfg)
	eq(c.Seconds, 8 * 3600)
	eq(c.Xp, 8 * 3600 * 4 * 0.25)
end)

test("horloge en arrière et premier chargement : aucun gain", function()
	eq(Formulas.offlineCredit(rate, 5000, 4000, nil, cfg).Seconds, 0)
	eq(Formulas.offlineCredit(rate, 0, 4000, nil, cfg).Gold, 0)
end)

test("fractions reportées, rien n'est perdu ni inventé", function()
	local carry = { Xp = 0, Gold = 0 }
	local total = 0
	for _ = 1, 10 do -- 10 absences de 3 s : 3 x 1 x 0,25 = 0,75 or chacune
		local c = Formulas.offlineCredit(rate, 100, 103, carry, cfg)
		total += c.Gold
		carry = c.Carry
	end
	eq(total, 7) -- 7,5 or -> 7 crédités + 0,5 reporté
	near(carry.Gold, 0.5)
end)

test("reconnexion immédiate : la même période n'est pas recréditée", function()
	-- Le crédit et le nouvel instant sont écrits ensemble : on rejoue la transformation.
	local stored = ProfileSchema.template()
	stored.AfkRate = { Xp = 4, Gold = 1 }
	stored.LastAccounted = 1000
	local function loadTransform(old, now)
		local data = ProfileSchema.load(old)
		local c = Formulas.offlineCredit(data.AfkRate, data.LastAccounted, now, data.OfflineCarry, cfg)
		data.Gold += c.Gold
		data.OfflineCarry = c.Carry
		data.LastAccounted = now
		return data
	end
	local first = loadTransform(stored, 1000 + 3600)
	local second = loadTransform(first, 1000 + 3600) -- reconnexion à la même seconde
	eq(first.Gold, 900)
	eq(second.Gold, 900, "pas de second crédit")
	-- Transformation rejouable : même entrée, même sortie, entrée intacte.
	local replay = loadTransform(stored, 1000 + 3600)
	eq(replay.Gold, first.Gold)
	eq(stored.Gold, 0)
end)

----------------------------------------------------------------------------------------
print("Verrou de session (vérification n°5, simulée)")

test("clé libre, verrou expiré, verrou détenu ailleurs", function()
	assert(SessionLock.acquire(nil, "A", 100, 300) ~= nil, "SessionLock.acquire(nil, 'A', 100, 300) ~= nil")
	local held = { Data = {}, Lock = { JobId = "B", Expires = 400 } }
	eq(SessionLock.acquire(held, "A", 100, 300), nil, "détenu par B")
	assert(SessionLock.acquire(held, "A", 401, 300) ~= nil, "expiré")
	assert(SessionLock.acquire(held, "B", 100, 300) ~= nil, "déjà à nous")
	assert(SessionLock.acquire(held, "A", 100, 300, true) ~= nil, "vol forcé")
end)

test("deux serveurs, une seule autorité ; l'ancien détenteur ne peut plus écrire", function()
	-- Simule le DataStore et des transformations UpdateAsync.
	local record = nil
	local function update(fn)
		local new = fn(deepCopy(record))
		if new ~= nil then
			record = deepCopy(new)
		end
	end
	local function load(job, now)
		local got = nil
		update(function(old)
			local lock = SessionLock.acquire(old, job, now, 300)
			if not lock then
				return nil
			end
			got = (old and old.Data) or { Wood = 0 }
			return { Data = got, Lock = lock }
		end)
		return got
	end
	local function save(job, data, now)
		local ok = false
		update(function(old)
			if not SessionLock.canWrite(old, job) then
				return nil
			end
			ok = true
			return { Data = data, Lock = { JobId = job, Expires = now + 300 } }
		end)
		return ok
	end

	local a = load("A", 0)
	assert(a, "A prend l'autorité")
	eq(load("B", 10), nil, "B refusé tant que le verrou de A est valide")
	a.Wood = 5
	assert(save("A", a, 20), "A sauvegarde et renouvelle")
	-- A se fige longtemps, son verrou expire, B le reprend.
	local b = load("B", 20 + 301)
	assert(b, "B reprend après expiration")
	eq(b.Wood, 5, "B repart de la dernière sauvegarde de A")
	a.Wood = 999
	eq(save("A", a, 400), false, "A ne peut plus écrire")
	eq(record.Data.Wood, 5, "aucun écrasement")
end)

----------------------------------------------------------------------------------------
print("Groupes et appartenance (cahier §4)")

local function makeGroup()
	local g = GroupSchema.new("G1", "Bastion test", 1, "Alice", 0)
	g.Members["2"] = { Role = "Member", Status = "Active", Name = "Bob", JoinedAt = 0 }
	return g
end

test("création : le fondateur est administrateur", function()
	local g = GroupSchema.new("G1", "B", 42, "Zoé", 0)
	eq(Membership.role(g, 42), "Admin")
	eq(Membership.activeCount(g), 1)
end)

test("permissions par rôle", function()
	local g = makeGroup()
	assert(Membership.can(Groups, g, 2, "Build"), "membre construit")
	assert(not Membership.can(Groups, g, 2, "Manage"), "membre n'administre pas")
	assert(Membership.can(Groups, g, 1, "Manage"), "Membership.can(Groups, g, 1, 'Manage')")
	assert(not Membership.can(Groups, g, 99, "Build"), "visiteur ne modifie rien")
end)

test("l'administrateur doit transférer son rôle avant de quitter un groupe non vide", function()
	local g = makeGroup()
	eq(select(2, Membership.canLeave(g, 1)), "AdminFirst")
	assert(Membership.canLeave(g, 2), "membre peut partir")
	assert(Membership.transferAdmin(Groups, g, 1, 2), "Membership.transferAdmin(Groups, g, 1, 2)")
	eq(Membership.role(g, 2), "Admin")
	eq(Membership.role(g, 1), "Member")
	assert(Membership.canLeave(g, 1), "Membership.canLeave(g, 1)")
end)

test("dernier membre : groupe abandonné, constructions conservées", function()
	local g = GroupSchema.new("G1", "B", 1, "A", 0)
	g.Structures.TrainingGround = true
	Membership.remove(g, 1)
	eq(g.Abandoned, true)
	eq(g.Structures.TrainingGround, true)
	eq(Membership.resolveOnLoad(g, 1), "notMember")
end)

test("invitations : permission, doublon, groupe complet", function()
	local g = makeGroup()
	eq(select(2, Membership.canInvite(Groups, g, 2, 3, 4)), "NoPermission")
	eq(select(2, Membership.canInvite(Groups, g, 1, 2, 4)), "AlreadyMember")
	g.Members["3"] = { Role = "Member", Status = "Pending", Name = "C", JoinedAt = 0 }
	g.Members["4"] = { Role = "Member", Status = "Active", Name = "D", JoinedAt = 0 }
	eq(select(2, Membership.canInvite(Groups, g, 1, 5, 4)), "Full", "Pending compte dans la taille")
end)

test("reprise après interruption : Pending confirmé par le profil -> promu", function()
	local g = makeGroup()
	g.Members["3"] = { Role = "Member", Status = "Pending", Name = "C", JoinedAt = 0 }
	eq(Membership.resolveOnLoad(g, 3), "promote")
	eq(Membership.isActive(g, 3), false, "Pending ne donne aucun droit")
	eq(Membership.resolveOnLoad(g, 2), "member")
	eq(Membership.resolveOnLoad(g, 77), "notMember")
	eq(Membership.resolveOnLoad(nil, 2), "notMember")
end)

----------------------------------------------------------------------------------------
print("Constructions (cahier §5)")

test("disponibilité, coût, achat répété", function()
	local owned, mats = {}, { Wood = 10, Stone = 0 }
	local first = Structures[1]
	eq(Formulas.availableStructures(Structures, owned)[1].Id, first.Id)
	assert(Formulas.canBuild(first, owned, mats), "Formulas.canBuild(first, owned, mats)")
	owned[first.Id] = true
	eq(select(2, Formulas.canBuild(first, owned, mats)), "Owned", "pas de double facturation")
	eq(select(2, Formulas.canBuild(Structures[3], owned, mats)), "Requires")
	eq(select(2, Formulas.canBuild(Structures[2], owned, { Wood = 0 })), "Cost")
end)

test("deux achats concurrents ne créent pas de solde négatif (simulé)", function()
	local mats = { Wood = 10 }
	local owned = {}
	local def = Structures[1]
	local successes = 0
	for _ = 1, 2 do -- deux membres, traités l'un après l'autre par le serveur
		if Formulas.canBuild(def, owned, mats) then
			for id, n in def.Cost do
				mats[id] -= n
			end
			owned[def.Id] = true
			successes += 1
		end
	end
	eq(successes, 1)
	eq(mats.Wood, 0)
end)

test("matériaux manquants et formatage du coût", function()
	local missing = Formulas.missingMaterials(Materials, { Wood = 5 }, { Wood = 30, Stone = 10 })
	eq(#missing, 2)
	eq(missing[1].Missing, 25)
	eq(Formulas.formatCost(Materials, { Wood = 30, Stone = 10 }), "30 Bois · 10 Pierre")
end)

test("bonus de récolte et niveau du bastion", function()
	eq(Formulas.harvestBonus(Structures, { Sawmill = true }, "Wood"), 1)
	eq(Formulas.harvestBonus(Structures, { Sawmill = true }, "Stone"), 0)
	eq(Formulas.bastionLevel(Structures, { TrainingGround = true, Palisade = true }), 3)
end)

----------------------------------------------------------------------------------------
print("Schémas, journal d'opérations, validation")

test("profil neuf et migration du prototype v1", function()
	eq(ProfileSchema.load(nil).Version, ProfileSchema.VERSION)
	local v1 = { Gold = 120, Level = 3, Xp = 7, LastOnline = 500, Receipts = { "abc" }, Buildings = { Forge = true } }
	local p = ProfileSchema.load(v1)
	eq(p.Version, ProfileSchema.VERSION)
	eq(p.TrainXp, 7)
	eq(p.LastAccounted, 500)
	eq(p.Buildings, nil)
	assert(OpLog.has(p.Ops, "receipt:abc"), "OpLog.has(p.Ops, 'receipt:abc')")
	eq(v1.Xp, 7, "données brutes intactes")
end)

test("groupe : jamais créé implicitement, champs ajoutés", function()
	eq(GroupSchema.load(nil), nil)
	local g = GroupSchema.load({ Id = "X", Members = {} })
	eq(g.Materials.Wood, 0)
	eq(g.Abandoned, false)
end)

test("journal d'opérations : idempotent et borné", function()
	local log = {}
	OpLog.add(log, "a", 3)
	OpLog.add(log, "a", 3)
	eq(#log, 1)
	for i = 1, 5 do
		OpLog.add(log, "op" .. i, 3)
	end
	eq(#log, 3)
	assert(not OpLog.has(log, "a"), "not OpLog.has(log, 'a')")
	assert(OpLog.has(log, "op5"), "OpLog.has(log, 'op5')")
end)

test("validation des entrées client (NaN, infini, types, identifiants)", function()
	assert(not Validate.finiteNumber(0 / 0), "not Validate.finiteNumber(0 / 0)")
	assert(not Validate.finiteNumber(math.huge), "not Validate.finiteNumber(math.huge)")
	assert(not Validate.positiveInteger(1.5, 10), "not Validate.positiveInteger(1.5, 10)")
	assert(not Validate.positiveInteger(-3, 10), "not Validate.positiveInteger(-3, 10)")
	assert(Validate.positiveInteger(7, 10), "Validate.positiveInteger(7, 10)")
	assert(not Validate.id("a b"), "not Validate.id('a b')")
	assert(not Validate.id(string.rep("a", 100), 32), "not Validate.id(string.rep('a', 100), 32)")
	assert(not Validate.id(123), "not Validate.id(123)")
	assert(Validate.id("Focus"), "Validate.id('Focus')")
	eq(Formulas.clamp(0 / 0, 10), 0)
	eq(Formulas.clamp(math.huge, 10), 0)
end)

test("formatage", function()
	eq(Formulas.formatNumber(999), "999")
	eq(Formulas.formatNumber(1234), "1,2K")
	eq(Formulas.formatDuration(8130), "2 h 15 min")
end)

----------------------------------------------------------------------------------------
print("Cohérence de la configuration")

test("constructions : Id uniques, prérequis définis avant, coûts en matériaux connus", function()
	local seen, matIds = {}, {}
	for _, m in Materials do
		matIds[m.Id] = true
	end
	for _, def in Structures do
		assert(not seen[def.Id], "Id en double " .. def.Id)
		assert(def.Requires == nil or seen[def.Requires], def.Id .. " : prérequis non défini avant")
		for id, n in def.Cost do
			assert(matIds[id] and n > 0, def.Id .. " : coût invalide")
		end
		assert(def.Effect and def.Effect ~= "", def.Id .. " : effet non affiché")
		seen[def.Id] = true
	end
end)

test("parcelle : emprises, socles et tapis sans chevauchement ni débordement", function()
	local half = Game.PlotSize / 2
	local boxes = {}
	local function add(name, x, z, sx, sz)
		table.insert(boxes, { name, x - sx / 2, x + sx / 2, z - sz / 2, z + sz / 2 })
	end
	for _, def in Structures do
		local x, z, sx, sz = def.Offset[1], def.Offset[2], def.Size[1], def.Size[3]
		add(def.Id, x, z, sx, sz)
		add(def.Id .. ":socle", x, z - sz / 2 - 4, 3, 3)
	end
	add("Noyau", 0, 8, 6, 6)
	add("Entrée", 0, -half + 6, 8, 8)
	for _, b in boxes do
		assert(b[2] >= -half and b[3] <= half and b[4] >= -half and b[5] <= half, b[1] .. " sort de la parcelle")
	end
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, b = boxes[i], boxes[j]
			local overlap = a[2] < b[3] and b[2] < a[3] and a[4] < b[5] and b[4] < a[5]
			assert(not overlap, a[1] .. " chevauche " .. b[1])
		end
	end
	-- Les tapis sont posés SUR leur construction.
	for _, def in Structures do
		for _, pos in def.Effects.Stations or {} do
			assert(math.abs(pos[1] - def.Offset[1]) + 2.5 <= def.Size[1] / 2, def.Id .. " : tapis hors emprise")
		end
	end
end)

test("catalogue : au moins 13 offres, clés uniques, identifiants non inventés", function()
	assert(#Products >= 13, "seulement " .. #Products .. " offres")
	local keys = {}
	for _, item in Products do
		assert(not keys[item.Key], "clé en double " .. item.Key)
		keys[item.Key] = true
		assert(item.Kind == "Product" or item.Kind == "Pass", "item.Kind == 'Product' or item.Kind == 'Pass'")
		eq(item.Id, 0, item.Key .. " : identifiant à créer dans le Creator Hub")
		assert(item.Name and item.Description and item.Preview, item.Key .. " : textes manquants")
		if item.Ready then
			assert(
				item.Delivery.Type == "Gold" or item.Delivery.Type == "Entitlement" or item.Delivery.Type == "Egg",
				item.Key .. " : livraison non implémentée"
			)
		end
	end
end)

test("première amélioration accessible en moins d'une minute de récolte", function()
	local first = Structures[1]
	local wood = first.Cost.Wood or 0
	local harvests = math.ceil(wood / Harvest.Nodes.Tree.Amount)
	local seconds = harvests * (Harvest.Nodes.Tree.HoldDuration + Harvest.PlayerCooldown + 3) -- + déplacements
	assert(seconds <= 60, "environ " .. seconds .. " s")
end)

----------------------------------------------------------------------------------------
print("Renaissance")

test("niveau requis croissant et plafond", function()
	eq(Formulas.rebirthRequiredLevel(0, Rebirth), Rebirth.RequiredLevelBase)
	eq(Formulas.rebirthRequiredLevel(2, Rebirth), Rebirth.RequiredLevelBase + 2 * Rebirth.RequiredLevelPerRebirth)
	eq(select(2, Formulas.canRebirth(Rebirth.RequiredLevelBase - 1, 0, Rebirth)), "Level")
	assert(Formulas.canRebirth(Rebirth.RequiredLevelBase, 0, Rebirth), "niveau atteint")
	eq(select(2, Formulas.canRebirth(999, Rebirth.MaxRebirths, Rebirth)), "Max")
end)

test("multiplicateur et Puissance plafonnés", function()
	eq(Formulas.rebirthMultiplier(0, Rebirth), 1)
	near(Formulas.rebirthMultiplier(4, Rebirth), 1 + 4 * Rebirth.MultiplierPerRebirth)
	eq(Formulas.rebirthMultiplier(1000, Rebirth), Formulas.rebirthMultiplier(Rebirth.MaxRebirths, Rebirth))
	assert(
		Formulas.power(10, Training, 2, Rebirth) > Formulas.power(10, Training),
		"la renaissance augmente la Puissance"
	)
end)

test("emplacements de compagnons : 1, puis 2 (R1), puis 3 (R3)", function()
	eq(Formulas.petSlots(0, Rebirth), 1)
	eq(Formulas.petSlots(1, Rebirth), 2)
	eq(Formulas.petSlots(2, Rebirth), 2)
	eq(Formulas.petSlots(3, Rebirth), 3)
end)

test("tapis supérieurs : ignorés sans la renaissance requise", function()
	local owned = { TrainingGround = true, RuneMats = true, EtherMats = true, CelestialMats = true }
	eq(Formulas.bestStationTier(Structures, owned, 0), 2)
	eq(Formulas.bestStationTier(Structures, owned, 1), 3)
	eq(Formulas.bestStationTier(Structures, owned, 3), 4)
end)

----------------------------------------------------------------------------------------
print("Œufs et compagnons")

test("œufs : probabilités totales = 100 %, compagnons existants, coût positif", function()
	local ids = {}
	for _, def in Pets.List do
		ids[def.Id] = true
		assert(Pets.Rarities[def.Rarity], def.Id .. " : rareté inconnue")
	end
	for _, egg in Pets.Eggs do
		assert((egg.Cost and egg.Cost > 0) or egg.Product, egg.Id .. " : coût ou produit Robux")
		local total = 0
		for _, entry in Formulas.eggOdds(egg) do
			assert(ids[entry.Id], egg.Id .. " : compagnon inconnu " .. entry.Id)
			total += entry.Chance
		end
		near(total, 1, egg.Id)
	end
end)

test("tirage : bornes et répartition conforme aux poids", function()
	local egg = Pets.Eggs[1]
	local odds = Formulas.eggOdds(egg)
	eq(Formulas.rollEgg(egg, 0), odds[1].Id)
	eq(Formulas.rollEgg(egg, 0.999999), odds[#odds].Id)
	local counts, n = {}, 20000
	for i = 0, n - 1 do
		local id = Formulas.rollEgg(egg, (i + 0.5) / n)
		counts[id] = (counts[id] or 0) + 1
	end
	for _, entry in odds do
		near(counts[entry.Id] / n, entry.Chance, entry.Id)
	end
end)

test("bonus des compagnons cumulé et plafonné", function()
	eq(Formulas.petMultiplier(Pets, {}), 1)
	near(Formulas.petMultiplier(Pets, { "BarnCat", "FrostWolf" }), 1.45)
	local many = {}
	for _ = 1, 20 do
		table.insert(many, "AstralKitsune")
	end
	eq(Formulas.petMultiplier(Pets, many), 1 + Pets.MaxTotalBonus)
end)

test("équiper le meilleur choisit les plus gros bonus", function()
	local inv = { { Uid = 1, PetId = "BarnCat" }, { Uid = 2, PetId = "RuneRam" }, { Uid = 3, PetId = "PeakEagle" } }
	local best = Formulas.bestPets(Pets, inv, 2)
	eq(#best, 2)
	eq(best[1], 2)
	eq(best[2], 3)
end)

----------------------------------------------------------------------------------------
print("Boss et combat")

test("PV figés selon les participants", function()
	local boss = Bosses[1]
	eq(Formulas.bossHealth(boss, 1), boss.MaxHealth)
	eq(Formulas.bossHealth(boss, 3), math.floor(boss.MaxHealth * (1 + 2 * boss.HealthPerExtraPlayer)))
end)

test("participation validée par les dégâts, pas par le dernier coup", function()
	local valid = Formulas.validParticipants({ [1] = 500, [2] = 10, [3] = 2000 }, 2500, 0.03)
	eq(#valid, 2)
	eq(valid[1], 1)
	eq(valid[2], 3)
end)

test("dégâts : Puissance x multiplicateur x compagnons, minimum 1", function()
	eq(Formulas.hitDamage(10, 1, 1), 10)
	eq(Formulas.hitDamage(10, Combat.Skills.Strike.DamageMult, 1.5), 75)
	eq(Formulas.hitDamage(0, 1, 1), 1)
end)

test("arènes : hors des parcelles, portails au hub, attaques valides", function()
	local plotOuter = 200 + 45 * math.sqrt(2)
	for _, boss in Bosses do
		local d = math.sqrt(boss.Arena[1] ^ 2 + boss.Arena[2] ^ 2)
		assert(d - boss.ArenaRadius > plotOuter, boss.Id .. " : arène trop proche des parcelles")
		assert(d + boss.ArenaRadius < 600, boss.Id .. " : arène hors du sol (sol de 1 240 studs)")
		assert(
			math.sqrt(boss.Portal[1] ^ 2 + boss.Portal[2] ^ 2) < Game.CourtyardApothem - 10,
			boss.Id .. " : portail hors de la cour royale"
		)
		for _, attack in boss.Attacks do
			assert(attack.Telegraph >= 1, boss.Id .. " : attaque non annoncée assez tôt")
		end
	end
end)

----------------------------------------------------------------------------------------
print("Rue des boss")

test("sections en boucle et patron toutes les 5 étapes", function()
	eq(Formulas.streetSection(1, Street), 1)
	eq(Formulas.streetSection(Street.Sections, Street), Street.Sections)
	eq(Formulas.streetSection(Street.Sections + 1, Street), 1, "retour au début")
	assert(not Formulas.streetIsPatron(4, Street), "étape 4 normale")
	assert(Formulas.streetIsPatron(5, Street), "étape 5 = patron")
	eq(Formulas.streetWaveSize(5, Street), 1, "le patron est seul")
	eq(Formulas.streetWaveSize(1, Street), Street.WaveBase)
	eq(Formulas.streetWaveSize(1001, Street), Street.WaveMax)
end)

test("difficulté et récompenses croissantes, patron plus fort", function()
	local a, b = Formulas.streetEnemy(1, Street), Formulas.streetEnemy(4, Street)
	assert(b.Health > a.Health and b.Damage >= a.Damage and b.Gold >= a.Gold, "croissance")
	local p = Formulas.streetEnemy(5, Street)
	local n = Formulas.streetEnemy(6, Street)
	assert(p.Health > n.Health, "le patron a plus de PV que l'étape suivante")
	eq(Formulas.streetRecommendedPower(1, Street), math.ceil(Street.Enemy.Health / Street.HitsToKill))
	assert(Formulas.streetRecommendedPower(1, Street) <= Training.PowerBase, "étape 1 faisable dès le départ")
end)

test("position -> section", function()
	eq(Formulas.streetSectionAt(-5, 0, Street), 0, "parvis")
	eq(Formulas.streetSectionAt(1, 0, Street), 1)
	eq(Formulas.streetSectionAt(Street.SectionLength + 1, 0, Street), 2)
	eq(Formulas.streetSectionAt(1, Street.Width, Street), 0, "hors des murs")
	eq(Formulas.streetSectionAt(Street.Sections * Street.SectionLength + 1, 0, Street), 0, "après la fin")
end)

test("butin du patron : chances respectées", function()
	local got = Formulas.rollDrops(Street.PatronDrops, { 0.99, 0.2, 0.9, 0.9 })
	eq(#got, 2, "cristal garanti + minerai (0,2 < 0,5)")
	eq(#Formulas.rollDrops(Street.PatronDrops, { 0.5, 0.9, 0.9, 0.9 }), 1)
	local ids = {}
	for _, def in Pets.List do
		ids[def.Id] = true
	end
	for _, drop in Street.PatronDrops do
		assert(drop.Chance > 0 and drop.Chance <= 1, "chance invalide")
		if drop.Kind == "Pet" then
			assert(ids[drop.Id], "compagnon inconnu " .. drop.Id)
		end
	end
end)

test("rue et champ : salles fermées sous la carte, invisibles depuis la surface", function()
	for _, cfg in { Street, Farm } do
		local top = cfg.Origin[2] + cfg.Hall.Height + 2
		assert(top < -20, "plafond de la salle sous le sol de la carte")
		assert(cfg.Origin[2] + cfg.Hall.Floor > -480, "au-dessus de la limite de destruction")
	end
	local streetBottom = Street.Origin[2] + Street.Hall.Floor - 2
	local farmTop = Farm.Origin[2] + Farm.Hall.Height + 2
	assert(farmTop < streetBottom, "les deux salles ne se chevauchent pas")
	local portal = math.sqrt(Street.Portal[1] ^ 2 + Street.Portal[2] ^ 2)
	assert(portal < Game.CourtyardApothem - 10, "portail de la rue dans la cour royale")
	for _, boss in Bosses do
		local dx, dz = Street.Portal[1] - boss.Portal[1], Street.Portal[2] - boss.Portal[2]
		assert(math.sqrt(dx * dx + dz * dz) >= 10, "portails trop proches")
	end
end)

----------------------------------------------------------------------------------------
print("Champ des champions")

local function noPass()
	return false
end

test("zones : multiplicateurs croissants avec les renaissances, plafond respecté", function()
	local last = { Mult = 0, Rebirths = -1 }
	for _, zone in Farm.Zones do
		if not zone.PassKey then
			assert(zone.Mult > last.Mult and zone.Rebirths > last.Rebirths, "progression des zones")
			assert(zone.Rebirths <= Rebirth.MaxRebirths, "zone inaccessible (renaissances > maximum)")
			last = zone
		end
	end
	eq(Formulas.bestZoneMult(Farm, 0, noPass), 1)
	eq(Formulas.bestZoneMult(Farm, 3, noPass), 4)
	eq(Formulas.bestZoneMult(Farm, 999, noPass), 30)
end)

test("zone royale : uniquement avec le pass", function()
	local royal
	for _, zone in Farm.Zones do
		if zone.PassKey == "RoyalTraining" then
			royal = zone
		end
	end
	assert(royal, "zone royale définie")
	assert(not Formulas.zoneUnlocked(royal, 999, noPass), "sans pass : verrouillée")
	assert(
		Formulas.zoneUnlocked(royal, 0, function()
			return true
		end),
		"avec pass : ouverte"
	)
	local found = false
	for _, item in Products do
		if item.Key == royal.PassKey then
			found = true
		end
	end
	assert(found, "pass présent dans le catalogue")
end)

test("rendement d'une zone : base x zone x Concentration x personnel", function()
	local r = Formulas.zoneRates(4, 2, 0.1, Training, 1.5)
	near(r.Xp, Training.BaseXpPerSecond * 4 * 1.2 * 1.5)
	near(r.Gold, Training.BaseGoldPerSecond * 4 * 1.2 * 1.5)
end)

test("zones sans chevauchement et lieux séparés (île, rue, arènes, hub)", function()
	local half = Farm.ZoneSize / 2
	for i = 1, #Farm.Zones do
		local xi, zi = Formulas.zoneCenter(Farm, i)
		for j = i + 1, #Farm.Zones do
			local xj, zj = Formulas.zoneCenter(Farm, j)
			assert(math.abs(xi - xj) >= Farm.ZoneSize or math.abs(zi - zj) >= Farm.ZoneSize, "zones " .. i .. "/" .. j)
		end
		-- Plateau de l'île : Columns x (ZoneSize + Gap) + 16 de large (Models.farmIsland).
		assert(math.abs(xi) + half < (Farm.Columns * (Farm.ZoneSize + Farm.Gap) + 16) / 2, "zone hors de l'île")
		assert(zi < 56, "au plus 2 rangées (les classements sont derrière)")
	end
	assert(math.abs(Farm.Origin[2] - Street.Origin[2]) > 60, "île et rue à des hauteurs différentes")
	assert(math.sqrt(Farm.Portal[1] ^ 2 + Farm.Portal[2] ^ 2) < Game.CourtyardApothem - 10, "portail dans la cour")
	for _, egg in Pets.Eggs do
		local dx, dz = Farm.Portal[1] - egg.Position[1], Farm.Portal[2] - egg.Position[2]
		assert(math.sqrt(dx * dx + dz * dz) >= 7, "portail trop proche de " .. egg.Id)
	end
end)

----------------------------------------------------------------------------------------
print("Arbre d'améliorations")

test("arbre : Id uniques, stats connues, coûts positifs, chaque branche existe", function()
	local seen, branches = {}, {}
	for _, b in Tree.Branches do
		branches[b.Id] = true
	end
	for _, node in Tree.Nodes do
		assert(not seen[node.Id], "Id en double " .. node.Id)
		seen[node.Id] = true
		assert(branches[node.Branch], node.Id .. " : branche inconnue")
		assert(Tree.StatText[node.Stat], node.Id .. " : stat inconnue")
		for _, amount in node.Cost do
			assert(amount > 0, node.Id .. " : coût")
		end
	end
end)

test("arbre : ordre de déblocage dans une branche", function()
	local owned = {}
	local wallet = { Gold = 1e9, Trophies = 1e9 }
	eq(Formulas.treePrevious(Tree, "Focus1"), nil)
	eq(Formulas.treePrevious(Tree, "Focus2"), "Focus1")
	eq(select(2, Formulas.canBuyNode(Tree, owned, "Focus2", wallet)), "Requires")
	assert(Formulas.canBuyNode(Tree, owned, "Focus1", wallet), "premier nœud")
	owned.Focus1 = true
	eq(select(2, Formulas.canBuyNode(Tree, owned, "Focus1", wallet)), "Owned")
	assert(Formulas.canBuyNode(Tree, owned, "Focus2", wallet), "suivant débloqué")
	eq(select(2, Formulas.canBuyNode(Tree, {}, "Str1", { Gold = 1e9, Trophies = 0 })), "Cost", "trophées requis")
end)

test("arbre : statistiques cumulées et effets hors ligne", function()
	local owned = { Focus1 = true, Focus2 = true, Off1 = true, Off2 = true }
	near(Formulas.treeStat(Tree, owned, "TrainingMult"), 0.20)
	local offline = Formulas.offlineConfig(Economy.Offline, Tree, owned)
	eq(offline.MaxSeconds, Economy.Offline.MaxSeconds + 3600)
	near(offline.Rate, Economy.Offline.Rate + 0.05)
	eq(Formulas.treeStat(Tree, nil, "Damage"), 0)
end)

test("migration v2 -> v3 : anciennes améliorations converties en nœuds", function()
	local p = ProfileSchema.load({ Version = 2, Upgrades = { Focus = 7, Toughness = 2 } })
	eq(p.Version, ProfileSchema.VERSION)
	assert(p.Tree.Focus5 and not p.Tree.Focus6, "Concentration plafonnée à 5 nœuds")
	assert(p.Tree.Tough2 and not p.Tree.Tough3, "Robustesse 2 nœuds")
	eq(p.Upgrades, nil)
	eq(p.Trophies, 0)
end)

test("chance : favorise Rare et plus, probabilités toujours = 100 %", function()
	local egg
	for _, e in Pets.Eggs do
		if e.Id == "ForestEgg" then
			egg = e
		end
	end
	local base, lucky = Formulas.eggOdds(egg), Formulas.eggOdds(Formulas.luckyEgg(egg, Pets, 0.5))
	local function chanceOf(list, id)
		for _, e in list do
			if e.Id == id then
				return e.Chance
			end
		end
		return 0
	end
	assert(chanceOf(lucky, "FrostWolf") > chanceOf(base, "FrostWolf"), "Rare favorisé")
	assert(chanceOf(lucky, "BarnCat") < chanceOf(base, "BarnCat"), "Commun moins fréquent")
	local total = 0
	for _, e in lucky do
		total += e.Chance
	end
	near(total, 1)
	eq(Formulas.trophies(10, 0.25), 13)
end)

----------------------------------------------------------------------------------------
print("Cour royale")

test("cour royale : portails espacés, devant le donjon ; œufs dans la cour ; portes alignées", function()
	local portals = { Street.Portal, Farm.Portal }
	for _, boss in Bosses do
		table.insert(portals, boss.Portal)
	end
	for i = 1, #portals do
		for j = i + 1, #portals do
			local dx, dz = portals[i][1] - portals[j][1], portals[i][2] - portals[j][2]
			assert(math.sqrt(dx * dx + dz * dz) >= 12.5, "portails qui se chevauchent")
		end
		assert(portals[i][2] + 2.8 < Game.CourtyardApothem - 7 - 7 - 3, "portail contre les marches du donjon")
	end
	for _, egg in Pets.Eggs do
		assert(
			math.sqrt(egg.Position[1] ^ 2 + egg.Position[2] ^ 2) < Game.CourtyardApothem - 8,
			egg.Id .. " hors de la cour"
		)
	end
	-- Les portes donnent sur les allées des parcelles (angles multiples de 360 / PlotCount).
	for _, g in Game.GateAngles do
		eq(g % (360 / Game.PlotCount), 0, "porte alignée sur une allée de parcelle")
	end
	assert(
		Game.RingRoadRadius - Game.RingRoadWidth / 2 > Game.CourtyardApothem + Game.WallThickness + 5,
		"route hors des remparts"
	)
	assert(Game.RingRoadRadius + Game.RingRoadWidth / 2 < Harvest.RingRadius - 12, "route avant les bosquets")
end)

----------------------------------------------------------------------------------------
print("Récompenses quotidiennes et temps de jeu")

test("quotidien : une fois par jour UTC, jours cumulés sans perte", function()
	local daily = { Day = 0, Cycle = 1, LastClaimDay = -1 }
	local day1 = Formulas.utcDay(1000 * 86400 + 5, Rewards.DayLength)
	assert(Formulas.dailyClaimable(daily, day1), "premier jour")
	daily = Formulas.dailyAdvance(daily, day1, #Rewards.Daily)
	assert(not Formulas.dailyClaimable(daily, day1), "pas deux fois le même jour")
	-- Absence de 5 jours : on reprend simplement au jour 2.
	assert(Formulas.dailyClaimable(daily, day1 + 5), "après une absence")
	eq(Formulas.dailyNext(Rewards, daily).Day, 2)
end)

test("quotidien : cycle de 7 jours puis récompenses répétables, compagnon une seule fois", function()
	local daily = { Day = 0, Cycle = 1, LastClaimDay = -1 }
	local pets = 0
	for d = 1, 14 do
		local nextReward = Formulas.dailyNext(Rewards, daily)
		if nextReward.Reward.Pet then
			pets += 1
		end
		eq(nextReward.OpId, string.format("daily:%d:%d", daily.Cycle, daily.Day + 1))
		daily = Formulas.dailyAdvance(daily, d, #Rewards.Daily)
	end
	eq(daily.Cycle, 3)
	eq(daily.Day, 0)
	eq(pets, 1, "le compagnon n'est donné qu'au premier cycle")
	for _, reward in Rewards.Repeat do
		eq(reward.Pet, nil, "aucun objet unique dans les cycles répétés")
	end
end)

test("temps de jeu : paliers franchis une seule fois, sessions additionnées", function()
	local tiers = Rewards.Playtime
	eq(#Formulas.playtimeReached(tiers, 0, 299), 0)
	local first = Formulas.playtimeReached(tiers, 295, 300)
	eq(#first, 1)
	eq(first[1], 1)
	eq(#Formulas.playtimeReached(tiers, 300, 305), 0, "pas de second crédit")
	-- Une longue avance d'un coup franchit plusieurs paliers.
	eq(#Formulas.playtimeReached(tiers, 0, tiers[#tiers].Minutes * 60 + 1), #tiers)
	local last = 0
	for _, tier in tiers do
		assert(tier.Minutes > last, "paliers croissants")
		last = tier.Minutes
	end
end)

test("récompenses : compagnons existants, valeurs positives", function()
	local ids = {}
	for _, def in Pets.List do
		ids[def.Id] = true
	end
	local function check(reward)
		for key, value in reward do
			if key == "Pet" then
				assert(ids[value], "compagnon inconnu " .. tostring(value))
			elseif key == "Egg" then
				local known = false
				for _, egg in Pets.Eggs do
					known = known or egg.Id == value
				end
				assert(known, "œuf inconnu " .. tostring(value))
			else
				assert(value > 0, key .. " doit être positif")
			end
		end
	end
	for _, list in { Rewards.Daily, Rewards.Repeat } do
		eq(#list, 7, "7 jours")
		for _, reward in list do
			check(reward)
		end
	end
	for _, tier in Rewards.Playtime do
		check(tier.Reward)
	end
end)

----------------------------------------------------------------------------------------
print("Titres")

local function baseStats()
	return {
		Rebirths = 0,
		BestLevel = 1,
		Harvests = 0,
		StreetBest = 0,
		TrophiesEarned = 0,
		ForestKills = 0,
		GolemKills = 0,
		Passes = {},
	}
end

test("titres : Recrue au départ, déblocages par le travail, ordre de prestige", function()
	local list = Formulas.unlockedTitles(Titles, baseStats())
	eq(#list, 1)
	eq(list[1].Id, "Recruit")
	local stats = baseStats()
	stats.Rebirths = 3
	stats.Harvests = 60
	local unlocked = Formulas.unlockedTitles(Titles, stats)
	eq(unlocked[1].Id, "Champion", "le plus prestigieux en premier")
	for i = 2, #unlocked do
		assert(unlocked[i - 1].Order >= unlocked[i].Order, "tri par prestige")
	end
end)

test("titres : le titre du pass n'est débloqué qu'avec le pass", function()
	local warden
	for _, t in Titles do
		if t.Stat == "Pass" then
			warden = t
		end
	end
	assert(not Formulas.titleUnlocked(warden, baseStats()), "sans pass")
	local stats = baseStats()
	stats.Passes = { [warden.Value] = true }
	assert(Formulas.titleUnlocked(warden, stats), "avec pass")
	local found = false
	for _, item in Products do
		if item.Key == warden.Value then
			found = true
		end
	end
	assert(found, "pass présent dans le catalogue")
end)

test("titres : tous atteignables (renaissances, étapes, boss existants), Id uniques", function()
	local ids = {}
	for _, t in Titles do
		assert(not ids[t.Id], "Id en double " .. t.Id)
		ids[t.Id] = true
		assert(t.Hint and t.Hint ~= "", t.Id .. " : condition non expliquée")
		if t.Stat == "Rebirths" then
			assert(t.Value <= Rebirth.MaxRebirths, t.Id .. " : renaissances inaccessibles")
		elseif t.Stat == "BestLevel" then
			assert(t.Value <= Training.MaxLevel, t.Id .. " : niveau inaccessible")
		end
	end
	assert(Bosses[1].Id == "ForestGuardian" and Bosses[2].Id == "MineGolem", "boss des titres présents")
end)

----------------------------------------------------------------------------------------
print("Missions")

test("missions : progression bornée, condition de construction", function()
	local q = { Stat = "Harvests", Target = 10 }
	local cur, done = Formulas.questProgress(q, { Harvests = 4 })
	eq(cur, 4)
	eq(done, false)
	cur, done = Formulas.questProgress(q, { Harvests = 25 })
	eq(cur, 10, "borné à l'objectif")
	eq(done, true)
	local b = { Stat = "Structure", Value = "TrainingGround", Target = 1 }
	eq(select(2, Formulas.questProgress(b, { Structures = {} })), false)
	eq(select(2, Formulas.questProgress(b, { Structures = { TrainingGround = true } })), true)
end)

test("missions : Id uniques, stats connues, constructions existantes, récompenses positives", function()
	local personalStats = {
		Harvests = true,
		Structure = true,
		TrainSeconds = true,
		TreeNodes = true,
		PetsOwned = true,
		PetsEquipped = true,
		StreetKills = true,
		StreetBest = true,
		BestLevel = true,
		Rebirths = true,
		BossKills = true,
	}
	local groupStats = { BastionLevel = true, Members = true, Structure = true }
	local structures, matIds = {}, {}
	for _, def in Structures do
		structures[def.Id] = true
	end
	for _, m in Materials do
		matIds[m.Id] = true
	end
	local ids = {}
	for _, list in { { Quests.Personal, personalStats }, { Quests.Group, groupStats } } do
		for _, quest in list[1] do
			assert(not ids[quest.Id], "Id en double " .. quest.Id)
			ids[quest.Id] = true
			assert(list[2][quest.Stat], quest.Id .. " : stat inconnue")
			if quest.Stat == "Structure" then
				assert(structures[quest.Value], quest.Id .. " : construction inconnue")
			end
			assert(quest.Target >= 1, quest.Id .. " : objectif")
			for key, value in quest.Reward do
				assert(value > 0, quest.Id .. " : récompense")
				if list[1] == Quests.Group then
					assert(matIds[key], quest.Id .. " : matériau inconnu " .. key)
				end
			end
		end
	end
	eq(#Quests.Personal >= 6, true, "au moins 6 missions de découverte")
end)

test("Défense : étape et taille des vagues", function()
	eq(Formulas.defenseStage(Defense, 1, 1), 1, "bastion niv. 1, vague 1")
	eq(Formulas.defenseStage(Defense, 1, 3), 3, "la difficulté monte à chaque vague")
	eq(
		Formulas.defenseStage(Defense, 3, 1),
		1 + 2 * Defense.StagePerBastionLevel,
		"un bastion plus grand attire plus fort"
	)
	eq(Formulas.defenseWaveSize(Defense, 1, 1), Defense.WaveBase + 1, "un défenseur")
	eq(Formulas.defenseWaveSize(Defense, 1, 4), Defense.WaveBase + 4, "+1 ennemi par défenseur supplémentaire")
	eq(Formulas.defenseWaveSize(Defense, 2, 0), Defense.WaveBase + 2, "jamais négatif")
end)

test("Défense : configuration cohérente", function()
	local matIds = {}
	for _, mat in Materials do
		matIds[mat.Id] = true
	end
	for matId, amount in Defense.Rewards.Group do
		assert(matIds[matId], "matériau inconnu " .. matId)
		assert(amount > 0, "récompense positive")
	end
	assert(Defense.Waves >= 1 and Defense.PrepSeconds >= 5, "vagues et préavis")
	assert(Defense.CooldownSeconds > 0 and Defense.AbandonSeconds > 0, "délais")
	assert(Defense.CoreHealthPerLevel > 0 and Defense.Rewards.TrophiesPerLevel > 0, "noyau et trophées")
end)

test("Œufs : gratuits jusqu'à Légendaire, royaux liés à un produit prêt", function()
	local rarityOf = {}
	for _, def in Pets.List do
		rarityOf[def.Id] = def.Rarity
	end
	local productByKey = {}
	for _, item in Products do
		productByKey[item.Key] = item
	end
	local paid = 0
	for _, egg in Pets.Eggs do
		if egg.Cost then
			assert(egg.Product == nil, egg.Id .. " : or ET Robux")
			for id in egg.Weights do
				assert(
					Pets.Rarities[rarityOf[id]].Order <= Pets.FreeMaxOrder,
					egg.Id .. " : " .. id .. " trop rare pour un œuf gratuit"
				)
			end
		else
			paid += 1
			local item = productByKey[egg.Product]
			assert(item and item.Kind == "Product" and item.Ready, egg.Id .. " : produit manquant")
			eq(item.Delivery.Type, "Egg")
			eq(item.Delivery.Egg, egg.Id)
		end
		for id in egg.Weights do
			assert(rarityOf[id], egg.Id .. " : compagnon inconnu " .. id)
		end
	end
	assert(paid >= 1, "au moins un œuf royal")
	local found = false
	for _, tier in Rewards.Playtime do
		if tier.Minutes == 60 and tier.Reward.Egg then
			found = true
			local egg
			for _, e in Pets.Eggs do
				if e.Id == tier.Reward.Egg then
					egg = e
				end
			end
			assert(egg and egg.Product, "l'œuf d'1 h est un œuf royal")
		end
	end
	assert(found, "œuf offert après 1 h de jeu")
end)

test("Parcours : paliers, récupérations, nouvelle saison", function()
	eq(Formulas.passTier(Pass, 0), 0)
	eq(Formulas.passTier(Pass, Pass.XpPerTier - 1), 0)
	eq(Formulas.passTier(Pass, Pass.XpPerTier * 3 + 5), 3)
	eq(Formulas.passTier(Pass, 1e9), #Pass.Tiers, "plafonné au dernier palier")
	local state = Formulas.passState(Pass, nil)
	eq(state.Season, Pass.Season)
	state.Xp = Pass.XpPerTier * 2
	eq(#Formulas.passClaimable(Pass, state, false), 2, "piste gratuite seule")
	eq(#Formulas.passClaimable(Pass, state, true), 4, "premium : paliers déjà atteints inclus")
	state.Free["1"] = true
	state.Premium["1"] = true
	eq(#Formulas.passClaimable(Pass, state, true), 2, "jamais deux fois")
	local old = { Season = Pass.Season - 1, Xp = 999999, Free = { ["1"] = true }, Premium = {} }
	local fresh = Formulas.passState(Pass, old)
	eq(fresh.Xp, 0, "nouvelle saison : XP remise à zéro")
	eq(next(fresh.Free), nil)
end)

test("Parcours : récompenses valides, premium plus fort, tapis x500 au dernier palier", function()
	local eggs, pets, entitlements = {}, {}, {}
	for _, egg in Pets.Eggs do
		eggs[egg.Id] = true
	end
	for _, def in Pets.List do
		pets[def.Id] = true
	end
	local function check(reward, where)
		assert(next(reward) ~= nil, where .. " : vide")
		for key, value in reward do
			if key == "Egg" then
				assert(eggs[value], where .. " : œuf inconnu " .. tostring(value))
			elseif key == "Pet" then
				assert(pets[value], where .. " : compagnon inconnu")
			elseif key == "Entitlement" then
				assert(value.Key and value.Name, where .. " : droit incomplet")
				entitlements[value.Key] = true
			else
				assert(type(value) == "number" and value > 0, where .. " : " .. key)
			end
		end
	end
	local freeGold, premiumGold = 0, 0
	for i, tier in Pass.Tiers do
		check(tier.Free, "palier " .. i .. " gratuit")
		check(tier.Premium, "palier " .. i .. " premium")
		freeGold += tier.Free.Gold or 0
		premiumGold += tier.Premium.Gold or 0
	end
	assert(premiumGold >= freeGold * 5, "la piste premium doit être nettement plus forte")
	local last = Pass.Tiers[#Pass.Tiers].Premium.Entitlement
	assert(last and last.Key == "ChampionMat500", "dernier palier premium : tapis x500")
	-- Chaque droit débloque bien une zone du Champ des champions.
	for key in entitlements do
		local zone
		for _, z in Farm.Zones do
			if z.PassKey == key then
				zone = z
			end
		end
		assert(zone, "aucune zone pour " .. key)
	end
	local found500 = false
	for _, z in Farm.Zones do
		found500 = found500 or (z.PassKey == "ChampionMat500" and z.Mult == 500)
	end
	assert(found500, "zone x500")
	local premiumItem
	for _, item in Products do
		if item.Key == Pass.PremiumPass then
			premiumItem = item
		end
	end
	assert(premiumItem and premiumItem.Kind == "Pass" and premiumItem.Ready, "pass premium vendable")
	for key, value in Pass.Xp do
		assert(value > 0, "XP " .. key)
	end
end)

test("Terrain : extensions dans l'espace libre (voisins, arènes, collines)", function()
	local function world(index: number, x: number, z: number)
		local a = (index - 1) / Game.PlotCount * math.pi * 2
		local cx, cz = math.cos(a) * Game.PlotRingRadius, math.sin(a) * Game.PlotRingRadius
		-- Repère de la parcelle : +Z local vers l'extérieur, X local = (sin a, -cos a).
		return cx + z * math.cos(a) + x * math.sin(a), cz + z * math.sin(a) - x * math.cos(a), a
	end
	local half = math.pi / Game.PlotCount
	for index = 1, Game.PlotCount do
		for _, area in Land.Areas do
			local r = area.Rect
			for _, corner in { { r[1], r[3] }, { r[1], r[4] }, { r[2], r[3] }, { r[2], r[4] } } do
				local wx, wz, a = world(index, corner[1], corner[2])
				local dist = math.sqrt(wx * wx + wz * wz)
				assert(dist <= 415, area.Id .. " : trop loin du centre")
				local diff = math.abs((math.atan2(wz, wx) - a + math.pi) % (2 * math.pi) - math.pi)
				assert(diff < half - math.rad(1.5), area.Id .. " : déborde vers la parcelle voisine")
				for _, boss in Bosses do
					local dx, dz = wx - boss.Arena[1], wz - boss.Arena[2]
					assert(math.sqrt(dx * dx + dz * dz) > boss.ArenaRadius + 15, area.Id .. " : touche une arène")
				end
			end
		end
	end
end)

test("Terrain : murs, passages et emplacements cohérents", function()
	local areas = { Base = true }
	for i, area in Land.Areas do
		areas[area.Id] = true
		eq(Land.Openings[Land.SignOpening[area.Id]].B, area.Id, "panneau devant un passage menant à " .. area.Id)
		for matId, amount in area.Cost do
			assert(amount > 0, area.Id .. " : coût")
			local known = false
			for _, mat in Materials do
				known = known or mat.Id == matId
			end
			assert(known, area.Id .. " : matériau inconnu")
		end
		if i > 1 then
			local prev = 0
			for _, amount in Land.Areas[i - 1].Cost do
				prev += amount
			end
			local cur = 0
			for _, amount in area.Cost do
				cur += amount
			end
			assert(cur > prev, area.Id .. " : coût croissant")
		end
		for _, slot in area.Slots do
			local def
			for _, m in Machines.List do
				if m.Id == slot.Machine then
					def = m
				end
			end
			assert(def, slot.Id .. " : machine inconnue")
			-- Emprise : socle 11 x 11 et tapis + caisse jusqu'à 17 studs devant.
			local r = area.Rect
			assert(slot.X - 5.5 >= r[1] and slot.X + 5.5 <= r[2], slot.Id .. " : hors de l'extension (x)")
			assert(slot.Z - 17 >= r[3] and slot.Z + 5.5 <= r[4], slot.Id .. " : hors de l'extension (z)")
		end
	end
	for _, o in Land.Openings do
		assert(areas[o.A] and areas[o.B], "passage vers une zone inconnue")
	end
	local walls = Formulas.landWalls(Land)
	assert(#walls >= 8, "murs des extensions")
	for _, w in walls do
		for _, o in Land.Openings do
			if o.Along == "X" and w.Z1 == w.Z2 and math.abs(w.Z1 - o.Z) < 0.01 then
				assert(w.X2 <= o.X - 5 or w.X1 >= o.X + 5, "mur sur un passage")
			elseif o.Along == "Z" and w.X1 == w.X2 and math.abs(w.X1 - o.X) < 0.01 then
				assert(w.Z2 <= o.Z - 5 or w.Z1 >= o.Z + 5, "mur sur un passage")
			end
		end
	end
	eq(Formulas.landAreaAt(Land, 0, 0), "Base")
	eq(Formulas.landAreaAt(Land, 0, 60), "Back1")
	eq(Formulas.landAreaAt(Land, 60, 0), "WingL")
	eq(Formulas.landAreaAt(Land, 0, 300), nil)
	local owned = Formulas.landOwned(Land, 2)
	assert(owned.Base and owned.Back1 and owned.WingL and not owned.WingR, "extensions dans l'ordre")
	eq(Formulas.landNext(Land, #Land.Areas), nil, "tout acheté")
end)

test("Machines : production, part d'or, amélioration, hors ligne", function()
	local lumber
	for _, def in Machines.List do
		if def.Id == "LumberMill" then
			lumber = def
		end
	end
	near(Formulas.machineRate(Machines, lumber, 1), lumber.Rate)
	near(Formulas.machineRate(Machines, lumber, 3), lumber.Rate * Machines.LevelRateMult ^ 2)
	local c1 = Formulas.machineUpgradeCost(Machines, lumber, 1)
	local c2 = Formulas.machineUpgradeCost(Machines, lumber, 2)
	assert(c2.Wood > c1.Wood and c1.Wood > lumber.Cost.Wood, "amélioration de plus en plus chère")
	-- Seules les machines d'extensions possédées produisent.
	local machines = { Back1_1 = 2, WingL_1 = 1 }
	local rates = Formulas.machineRates(Machines, Land, 1, machines)
	near(rates.Materials.Wood, Formulas.machineRate(Machines, lumber, 2))
	near(rates.PersonalGold, Formulas.machineGold(Machines, lumber, 2) * Machines.PersonalGoldShare)
	assert(Machines.PersonalGoldShare > 0 and Machines.PersonalGoldShare <= 0.2, "or personnel : faible part")
	local all = Formulas.machineRates(Machines, Land, 2, machines)
	near(all.Materials.Wood, Formulas.machineRate(Machines, lumber, 2) + lumber.Rate)
	-- Hors ligne : 25 %, plafonné.
	local off = Formulas.machineOffline(rates, 3600, Economy.Offline)
	near(off.Wood, rates.Materials.Wood * 3600 * Economy.Offline.Rate)
	local capped = Formulas.machineOffline(rates, 1e7, Economy.Offline)
	near(capped.Wood, rates.Materials.Wood * Economy.Offline.MaxSeconds * Economy.Offline.Rate)
	eq(next(Formulas.machineOffline(Formulas.machineRates(Machines, Land, 0, {}), 3600, Economy.Offline)), nil)
end)

test("Groupe : champs de terrain et de machines par défaut", function()
	local g = GroupSchema.load({ Id = "x", Name = "y", Members = {}, Materials = { Wood = 1 } })
	eq(g.Land, 0)
	eq(next(g.Machines), nil)
	eq(g.MachineAt, 0)
end)

test("Compagnons : 5 par rareté (Commun à Mythique), fiche de modèle pour chacun", function()
	-- PetModels utilise les types Roblox : chargé avec la bibliothèque @lune/roblox.
	local roblox = require("@lune/roblox")
	local luau = require("@lune/luau")
	local fs = require("@lune/fs")
	local env = setmetatable({
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Instance = roblox.Instance,
		Enum = roblox.Enum,
	}, { __index = _G })
	local PetModels = luau.load(fs.readFile("src/shared/PetModels.luau"), { environment = env })()
	local count = {}
	local ids = {}
	for _, def in Pets.List do
		assert(not ids[def.Id], "Id en double " .. def.Id)
		ids[def.Id] = true
		assert(Pets.Rarities[def.Rarity], def.Id .. " : rareté inconnue")
		count[def.Rarity] = (count[def.Rarity] or 0) + 1
		assert(PetModels.Species[def.Id], def.Id .. " : pas de fiche de modèle")
		local model = PetModels.build(def, roblox.Color3.new(1, 1, 1))
		assert(#model:GetChildren() >= 15, def.Id .. " : modèle trop pauvre")
	end
	for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		eq(count[r], 5, "5 compagnons " .. r)
	end
	-- Les bonus croissent avec la rareté.
	local maxOf, minOf = {}, {}
	for _, def in Pets.List do
		local o = Pets.Rarities[def.Rarity].Order
		maxOf[o] = math.max(maxOf[o] or 0, def.Bonus)
		minOf[o] = math.min(minOf[o] or math.huge, def.Bonus)
	end
	for o = 2, 7 do
		if minOf[o] and maxOf[o - 1] then
			assert(minOf[o] > maxOf[o - 1], "bonus croissants avec la rareté (" .. o .. ")")
		end
	end
	-- Anciens compagnons : conversion vers un compagnon existant, identique dans le schéma.
	for old, new in Pets.Renamed do
		assert(ids[new], old .. " -> " .. new .. " inconnu")
		local migrated = ProfileSchema.load({ Version = 3, Pets = { { Uid = 1, PetId = old } }, EquippedPets = { 1 } })
		eq(migrated.Pets[1].PetId, new, "migration " .. old)
	end
end)

test("Arbres : rares plus précieux, moins nombreux, matériaux connus", function()
	local Harvest = require("../src/shared/Config/Harvest")
	local mats = {}
	for _, mat in Materials do
		mats[mat.Id] = true
	end
	local common = Harvest.Nodes.Tree
	for _, special in Harvest.Specials do
		local node = Harvest.Nodes[special[1]]
		assert(node and node.Model, special[1] .. " : nœud ou modèle manquant")
		if node.Material == common.Material then
			assert(node.Amount > common.Amount, special[1] .. " : doit rapporter plus qu'un arbre commun")
		end
		assert(node.RespawnSeconds > common.RespawnSeconds, special[1] .. " : doit repousser plus lentement")
		assert(#special[2] < Game.PlotCount, special[1] .. " : doit être plus rare qu'un bosquet sur deux")
		for _, grove in special[2] do
			assert(grove >= 1 and grove <= Game.PlotCount, "bosquet inexistant")
		end
		for matId, amount in node.Bonus or {} do
			assert(mats[matId] and amount > 0, special[1] .. " : bonus invalide")
		end
	end
end)

test("Rue des boss : régions, patrons et 15 ennemis des planches", function()
	local ids = {}
	for _, def in Street.Kinds do
		ids[def.Id] = def
	end
	for _, def in Street.Bosses do
		ids[def.Id] = def
		assert(def.Boss and def.SlamRadius, def.Id .. " : boss incomplet")
	end
	local count = 0
	for _ in ids do
		count += 1
	end
	eq(count, 15, "15 ennemis (9 + 6 boss)")
	local used = {}
	for _, region in Street.Regions do
		for _, id in region.Pool do
			assert(ids[id] and not ids[id].Boss, region.Name .. " : " .. id .. " inconnu ou boss")
			used[id] = true
		end
		eq(#region.Patrons, 2)
		for _, id in region.Patrons do
			assert(ids[id], region.Name .. " : patron " .. id .. " inconnu")
			used[id] = true
		end
	end
	for id in ids do
		assert(used[id], id .. " n'apparaît jamais dans la rue")
	end
	eq(Formulas.streetKindId(10, 1, Street), "GoblinKing")
	eq(Formulas.streetKindId(5, 1, Street), "ShieldbreakerOrc")
	eq(Formulas.streetKindId(60, 1, Street), "VoidColossus", "boss final à l'étape 60")
	eq(Formulas.streetRegion(61, Street), 1, "retour à la première région")
	local a, b = Formulas.streetKindId(1, 1, Street), Formulas.streetKindId(1, 2, Street)
	assert(a ~= b, "vague variée")
	-- Les boss sont bien plus résistants qu'un ennemi de la même étape.
	local boss = Formulas.streetEnemyOf(10, Street, ids.GoblinKing)
	local grunt = Formulas.streetEnemyOf(9, Street, ids.ScrapGoblin)
	assert(boss.Health > grunt.Health * 6, "boss résistant")
	-- Modèles : chaque ennemi se construit et tient dans la rue.
	local roblox = require("@lune/roblox")
	local luau = require("@lune/luau")
	local fs = require("@lune/fs")
	local fakeGame = {
		GetService = function()
			return {
				FindFirstChild = function()
					return nil
				end,
			}
		end,
	}
	local env = setmetatable({
		Instance = roblox.Instance,
		CFrame = roblox.CFrame,
		Vector3 = roblox.Vector3,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		game = fakeGame,
	}, { __index = _G })
	local Models = luau.load(fs.readFile("src/server/Art/Models.luau"), { environment = env })()
	for id, def in ids do
		local model, root = Models.enemy(def, roblox.CFrame.new(), def.Scale or 1, false)
		assert(#model:GetChildren() >= 15, id .. " : modèle trop pauvre")
		assert(root.Size.Y <= 22, id .. " : trop grand pour la rue")
		assert(root.Size.X <= Street.Width - 6, id .. " : trop large pour la rue")
	end
end)

test("Rue des boss : comportements et attaques spéciales configurés", function()
	local known = { Melee = true }
	for name in Street.Behaviors do
		known[name] = true
	end
	known.Unblockable = true
	for _, def in Street.Kinds do
		assert(def.Behavior and known[def.Behavior], def.Id .. " : comportement inconnu " .. tostring(def.Behavior))
	end
	for _, def in Street.Bosses do
		assert(def.Special and Street.Specials[def.Special], def.Id .. " : attaque spéciale inconnue")
	end
	assert(Street.Specials.Every > Street.Patron.SlamTelegraph, "pas d'attaques simultanées en continu")
	-- Toutes les attaques à zone laissent le temps de réagir.
	for name, cfg in Street.Specials do
		if type(cfg) == "table" and cfg.Telegraph then
			assert(cfg.Telegraph >= 1, name .. " : annonce trop courte")
		end
	end
	assert(Street.Behaviors.Leap.Windup + Street.Behaviors.Leap.Time >= 0.9, "bond annoncé assez tôt")
end)

test("Projet Rojo : pas de propriété Position (ignorée par Rojo, cause de sols qui clignotent)", function()
	local fs = require("@lune/fs")
	local serde = require("@lune/serde")
	local project = serde.decode("json", fs.readFile("default.project.json"))
	local function walk(node, path: string)
		if type(node) ~= "table" then
			return
		end
		local props = node["$properties"]
		if props then
			assert(props.Position == nil, path .. " : utiliser CFrame, pas Position")
		end
		for key, child in node do
			if type(key) == "string" and key:sub(1, 1) ~= "$" then
				walk(child, path .. "/" .. key)
			end
		end
	end
	walk(project.tree, "")
	-- Le sol de la carte : dessus à y = 0, sous les sols de la cour et des bastions (y = 1).
	local ground = project.tree.Workspace.Ground["$properties"]
	local y = ground.CFrame.CFrame.position[2] + ground.Size[2] / 2
	eq(y, 0, "dessus du sol à y = 0")
end)

test("Pack de décors : dimensions du manifeste, collisions, battants du portail", function()
	local Decors = require("../src/shared/Config/Decors")
	local expected = {
		["01_Mur_pierre"] = { 12, 7, 2 },
		["02_Sol_pave"] = { 8, 0.5, 8 },
		["03_Rocher"] = { 5, 4, 4 },
		["04_Palissade"] = { 8, 6, 1 },
		["05_Portail"] = { 10, 9, 2 },
		["06_Caisse"] = { 3, 3, 3 },
		["07_Tonneau"] = { 3, 4, 3 },
		["08_Torche"] = { 2, 6, 2 },
		["09_Buisson"] = { 4, 3, 3 },
		["10_Minerai_cristal"] = { 4, 4, 3 },
	}
	eq(#Decors.List, 10)
	for _, def in Decors.List do
		local e = expected[def.Id]
		assert(e, def.Id .. " : absent du manifeste")
		eq(def.Size[1], e[1], def.Id .. " largeur")
		eq(def.Size[2], e[2], def.Id .. " hauteur")
		eq(def.Size[3], e[3], def.Id .. " profondeur")
		assert(def.Collision and (def.Collision.None or #def.Collision.Boxes > 0), def.Id .. " : collision")
		for _, box in (def.Collision.Boxes or {}) do
			for axis = 1, 3 do
				assert(box.Size[axis] <= e[axis] + 0.01, def.Id .. " : boîte plus grande que le décor")
			end
		end
	end
	-- Mur et pavés : modules entiers (alignement sans décalage) ; battants séparés du portail.
	for _, def in Decors.List do
		if def.Id == "05_Portail" then
			eq(#def.Doors, 2)
			eq(def.Doors[1].Part, "Porte_gauche")
			eq(def.Doors[2].Part, "Porte_droite")
			assert(def.Doors[1].OpenAngle * def.Doors[2].OpenAngle < 0, "battants opposés")
		end
	end
end)

print(string.format("\n%d réussi(s), %d échec(s)", passed, failed))
if failed > 0 then
	error("Des tests ont échoué")
end
