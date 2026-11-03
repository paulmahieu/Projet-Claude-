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
local Upgrades = require("../src/shared/Config/Upgrades")
local Products = require("../src/shared/Config/Products")
local Groups = require("../src/shared/Config/Groups")
local Game = require("../src/shared/Config/Game")
local Harvest = require("../src/shared/Config/Harvest")

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

test("coût des améliorations croissant et plafonné", function()
	local focus = Upgrades[1]
	eq(Formulas.upgradeCost(focus, 0), focus.BaseCost)
	assert(
		Formulas.upgradeCost(focus, 1) > Formulas.upgradeCost(focus, 0),
		"Formulas.upgradeCost(focus, 1) > Formulas.upgradeCost(focus, 0)"
	)
	eq(Formulas.upgradeCost(focus, focus.MaxLevel), nil)
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
	eq(p.Version, 2)
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
			eq(item.Delivery.Type, "Gold", item.Key .. " : seule la livraison d'or est implémentée")
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

print(string.format("\n%d réussi(s), %d échec(s)", passed, failed))
if failed > 0 then
	error("Des tests ont échoué")
end
