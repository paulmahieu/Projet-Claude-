--[[
	Formules du jeu. Fonctions PURES : pas d'API Roblox, configuration passée en paramètre.
	Testées avec Lune (tests/shared.spec.luau).
]]

local Formulas = {}

-- Entraînement --------------------------------------------------------------------------

function Formulas.xpToNext(level: number, cfg): number
	return math.max(1, math.floor(cfg.BaseXp * level ^ cfg.Exponent))
end

-- Ajoute de l'XP ; gère plusieurs montées de niveau. Retourne niveau, xp, niveaux gagnés.
function Formulas.addXp(level: number, xp: number, amount: number, cfg): (number, number, number)
	local gained = 0
	xp += math.max(0, amount)
	while level < cfg.MaxLevel do
		local needed = Formulas.xpToNext(level, cfg)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1
		gained += 1
	end
	if level >= cfg.MaxLevel then
		level = cfg.MaxLevel
		xp = 0
	end
	return level, xp, gained
end

-- Puissance : dérivée du niveau, augmentée par les renaissances (rebirthCfg optionnel).
function Formulas.power(level: number, cfg, rebirths: number?, rebirthCfg): number
	local base = cfg.PowerBase + cfg.PowerPerLevel * (level - 1)
	if rebirths and rebirthCfg then
		base *= 1 + math.min(rebirths, rebirthCfg.MaxRebirths) * rebirthCfg.PowerPerRebirth
	end
	return math.floor(base)
end

-- Renaissance ------------------------------------------------------------------------

function Formulas.rebirthRequiredLevel(rebirths: number, cfg): number
	return cfg.RequiredLevelBase + cfg.RequiredLevelPerRebirth * rebirths
end

function Formulas.canRebirth(level: number, rebirths: number, cfg): (boolean, string?)
	if rebirths >= cfg.MaxRebirths then
		return false, "Max"
	end
	if level < Formulas.rebirthRequiredLevel(rebirths, cfg) then
		return false, "Level"
	end
	return true, nil
end

function Formulas.rebirthMultiplier(rebirths: number, cfg): number
	return 1 + math.min(rebirths, cfg.MaxRebirths) * cfg.MultiplierPerRebirth
end

function Formulas.petSlots(rebirths: number, cfg): number
	local slots = 1
	for _, step in cfg.PetSlots do
		if rebirths >= step.Rebirths then
			slots = math.max(slots, step.Slots)
		end
	end
	return slots
end

-- Compagnons ---------------------------------------------------------------------------

-- Bonus total des compagnons équipés (liste d'Id), plafonné. Retourne le multiplicateur (>= 1).
function Formulas.petMultiplier(petsCfg, equippedIds): number
	local byId = {}
	for _, def in petsCfg.List do
		byId[def.Id] = def
	end
	local bonus = 0
	for _, id in equippedIds do
		local def = byId[id]
		if def then
			bonus += def.Bonus
		end
	end
	return 1 + math.min(bonus, petsCfg.MaxTotalBonus)
end

-- Probabilités d'un œuf : liste triée { { Id, Chance (0-1) } }.
function Formulas.eggOdds(egg)
	local total = 0
	for _, w in egg.Weights do
		total += w
	end
	local list = {}
	for id, w in egg.Weights do
		table.insert(list, { Id = id, Chance = w / total })
	end
	table.sort(list, function(a, b)
		return a.Chance > b.Chance
	end)
	return list
end

-- Tirage déterministe : r dans [0, 1[ (fourni par le serveur). Retourne l'Id obtenu.
function Formulas.rollEgg(egg, r: number): string
	local odds = Formulas.eggOdds(egg)
	local acc = 0
	for _, entry in odds do
		acc += entry.Chance
		if r < acc then
			return entry.Id
		end
	end
	return odds[#odds].Id
end

-- Les meilleurs compagnons de l'inventaire (Uid) pour remplir `slots` emplacements.
function Formulas.bestPets(petsCfg, inventory, slots: number)
	local byId = {}
	for _, def in petsCfg.List do
		byId[def.Id] = def
	end
	local sorted = table.clone(inventory)
	table.sort(sorted, function(a, b)
		local ba = byId[a.PetId] and byId[a.PetId].Bonus or 0
		local bb = byId[b.PetId] and byId[b.PetId].Bonus or 0
		if ba ~= bb then
			return ba > bb
		end
		return a.Uid < b.Uid
	end)
	local result = {}
	for i = 1, math.min(slots, #sorted) do
		table.insert(result, sorted[i].Uid)
	end
	return result
end

-- Combat -------------------------------------------------------------------------------

-- PV d'un boss figés au début du combat selon le nombre de participants.
function Formulas.bossHealth(boss, participants: number): number
	return math.floor(boss.MaxHealth * (1 + math.max(0, participants - 1) * boss.HealthPerExtraPlayer))
end

function Formulas.hitDamage(power: number, mult: number, petMult: number): number
	return math.max(1, math.floor(power * mult * petMult))
end

-- Participants validés : dégâts >= ratio x PV max.
function Formulas.validParticipants(damageByUser, maxHealth: number, ratio: number)
	local list = {}
	for userId, dmg in damageByUser do
		if dmg >= maxHealth * ratio then
			table.insert(list, userId)
		end
	end
	table.sort(list)
	return list
end

-- Niveau d'une amélioration personnelle (0 si absente).
function Formulas.upgradeLevel(profile, upgradeId: string): number
	return (profile.Upgrades and profile.Upgrades[upgradeId]) or 0
end

function Formulas.upgradeCost(def, currentLevel: number): number?
	if currentLevel >= def.MaxLevel then
		return nil
	end
	return math.floor(def.BaseCost * def.Growth ^ currentLevel)
end

-- Bonus du bastion sur les tapis (somme des TrainingMult des constructions possédées).
function Formulas.groupTrainingMult(structureDefs, owned): number
	local bonus = 0
	for _, def in structureDefs do
		if owned[def.Id] and def.Effects.TrainingMult then
			bonus += def.Effects.TrainingMult
		end
	end
	return 1 + bonus
end

-- Meilleur palier de tapis disponible dans un bastion (0 = aucun tapis).
-- rebirths (optionnel) : ignore les tapis dont la renaissance requise n'est pas atteinte.
function Formulas.bestStationTier(structureDefs, owned, rebirths: number?): number
	local best = 0
	for _, def in structureDefs do
		local usable = (def.Effects.RequiredRebirths or 0) <= (rebirths or math.huge)
		if owned[def.Id] and def.Effects.StationTier and usable then
			best = math.max(best, def.Effects.StationTier)
		end
	end
	return best
end

-- Rendement d'un tapis par seconde, SANS bonus temporaire.
-- focusLevel/focusPerLevel : amélioration personnelle « Concentration ».
-- extraMult : renaissances x compagnons (1 par défaut).
function Formulas.trainingRates(
	tier: number,
	groupMult: number,
	focusLevel: number,
	focusPerLevel: number,
	cfg,
	extraMult: number?
)
	if tier <= 0 then
		return { Xp = 0, Gold = 0 }
	end
	local mult = (cfg.TierMultiplier[tier] or 1) * groupMult * (1 + focusLevel * focusPerLevel) * (extraMult or 1)
	return { Xp = cfg.BaseXpPerSecond * mult, Gold = cfg.BaseGoldPerSecond * mult }
end

-- Gains hors ligne ----------------------------------------------------------------------

--[[
	durée = min(max(maintenant - dernier, 0), MaxSeconds)
	gain  = durée x rendement x Rate, séparément pour l'XP et l'or.
	Les fractions sont reportées (carry) pour ne rien perdre ni inventer.
	Retourne { Seconds, Xp, Gold, Carry = { Xp, Gold } } (Xp et Gold entiers).
]]
function Formulas.offlineCredit(rate, lastAccounted: number, now: number, carry, cfg)
	carry = carry or { Xp = 0, Gold = 0 }
	if lastAccounted <= 0 then
		return { Seconds = 0, Xp = 0, Gold = 0, Carry = { Xp = carry.Xp or 0, Gold = carry.Gold or 0 } }
	end
	local seconds = math.min(math.max(now - lastAccounted, 0), cfg.MaxSeconds)
	local rawXp = seconds * (rate.Xp or 0) * cfg.Rate + (carry.Xp or 0)
	local rawGold = seconds * (rate.Gold or 0) * cfg.Rate + (carry.Gold or 0)
	local xp = math.floor(rawXp)
	local gold = math.floor(rawGold)
	return { Seconds = seconds, Xp = xp, Gold = gold, Carry = { Xp = rawXp - xp, Gold = rawGold - gold } }
end

-- Constructions ------------------------------------------------------------------------

function Formulas.canAfford(materials, cost): boolean
	for id, amount in cost do
		if (materials[id] or 0) < amount then
			return false
		end
	end
	return true
end

-- Liste des matériaux manquants : { { Id, Missing } } dans l'ordre de matérialDefs.
function Formulas.missingMaterials(materialDefs, materials, cost)
	local missing = {}
	for _, mat in materialDefs do
		local need = cost[mat.Id]
		if need and (materials[mat.Id] or 0) < need then
			table.insert(missing, { Id = mat.Id, Name = mat.Name, Missing = need - (materials[mat.Id] or 0) })
		end
	end
	return missing
end

function Formulas.canBuild(def, owned, materials): (boolean, string?)
	if def == nil then
		return false, "Unknown"
	end
	if owned[def.Id] then
		return false, "Owned"
	end
	if def.Requires and not owned[def.Requires] then
		return false, "Requires"
	end
	if not Formulas.canAfford(materials, def.Cost) then
		return false, "Cost"
	end
	return true, nil
end

function Formulas.availableStructures(structureDefs, owned)
	local result = {}
	for _, def in structureDefs do
		if not owned[def.Id] and (def.Requires == nil or owned[def.Requires]) then
			table.insert(result, def)
		end
	end
	return result
end

function Formulas.bastionLevel(structureDefs, owned): number
	local level = 1
	for _, def in structureDefs do
		if owned[def.Id] then
			level += 1
		end
	end
	return level
end

-- Bonus de récolte cumulés des constructions possédées pour un matériau.
function Formulas.harvestBonus(structureDefs, owned, materialId: string): number
	local bonus = 0
	for _, def in structureDefs do
		local hb = def.Effects.HarvestBonus
		if owned[def.Id] and hb and hb[materialId] then
			bonus += hb[materialId]
		end
	end
	return bonus
end

-- Champ des champions ------------------------------------------------------------------

-- Rendement dans une zone de farm (par seconde) : base x zone x Concentration x personnel.
function Formulas.zoneRates(zoneMult: number, focusLevel: number, focusPerLevel: number, cfg, personalMult: number)
	local mult = zoneMult * (1 + focusLevel * focusPerLevel) * personalMult
	return { Xp = cfg.BaseXpPerSecond * mult, Gold = cfg.BaseGoldPerSecond * mult }
end

-- Une zone est-elle accessible ? ownsPass(key) -> boolean.
function Formulas.zoneUnlocked(zone, rebirths: number, ownsPass): boolean
	if zone.PassKey and not ownsPass(zone.PassKey) then
		return false
	end
	return rebirths >= zone.Rebirths
end

-- Meilleur multiplicateur de zone accessible (0 si aucune).
function Formulas.bestZoneMult(farmCfg, rebirths: number, ownsPass): number
	local best = 0
	for _, zone in farmCfg.Zones do
		if Formulas.zoneUnlocked(zone, rebirths, ownsPass) then
			best = math.max(best, zone.Mult)
		end
	end
	return best
end

-- Centre {x, z} (relatif à l'origine de l'île) de la zone n.
function Formulas.zoneCenter(farmCfg, index: number): (number, number)
	local col = (index - 1) % farmCfg.Columns
	local rowIndex = (index - 1) // farmCfg.Columns
	local step = farmCfg.ZoneSize + farmCfg.Gap
	local width = farmCfg.Columns * step - farmCfg.Gap
	return -width / 2 + farmCfg.ZoneSize / 2 + col * step, rowIndex * step
end

-- Rue des boss ------------------------------------------------------------------------

function Formulas.streetIsPatron(stage: number, cfg): boolean
	return stage % cfg.PatronEvery == 0
end

-- Section (1..Sections) où se joue une étape.
function Formulas.streetSection(stage: number, cfg): number
	return ((stage - 1) % cfg.Sections) + 1
end

function Formulas.streetWaveSize(stage: number, cfg): number
	if Formulas.streetIsPatron(stage, cfg) then
		return 1
	end
	return math.min(cfg.WaveBase + math.floor(stage / cfg.WaveExtraPerStages), cfg.WaveMax)
end

-- Statistiques d'un ennemi de l'étape : { Health, Damage, Gold, Xp }.
function Formulas.streetEnemy(stage: number, cfg)
	local patron = Formulas.streetIsPatron(stage, cfg)
	local hp = cfg.Enemy.Health * cfg.HealthGrowth ^ (stage - 1)
	local dmg = cfg.Enemy.Damage * cfg.DamageGrowth ^ (stage - 1)
	local rewardScale = cfg.RewardGrowth ^ (stage - 1)
	local hpMult = if patron then cfg.Patron.HealthMult else 1
	local dmgMult = if patron then cfg.Patron.DamageMult else 1
	local rewardMult = if patron then cfg.Patron.RewardMult else 1
	return {
		Health = math.floor(hp * hpMult),
		Damage = math.floor(dmg * dmgMult),
		Gold = math.floor(cfg.Reward.Gold * rewardScale * rewardMult),
		Xp = math.floor(cfg.Reward.Xp * rewardScale * rewardMult),
	}
end

-- Puissance conseillée : vaincre un ennemi normal en HitsToKill coups.
function Formulas.streetRecommendedPower(stage: number, cfg): number
	return math.max(1, math.ceil(cfg.Enemy.Health * cfg.HealthGrowth ^ (stage - 1) / cfg.HitsToKill))
end

-- Section occupée par une position (distance le long de la rue depuis l'origine) ; 0 = hors rue.
function Formulas.streetSectionAt(distance: number, lateral: number, cfg): number
	if distance < 0 or math.abs(lateral) > cfg.Width / 2 + 2 then
		return 0
	end
	local index = math.floor(distance / cfg.SectionLength) + 1
	return if index <= cfg.Sections then index else 0
end

-- Tirage du butin d'un Patron : liste des entrées obtenues pour des tirages r[i] dans [0, 1[.
function Formulas.rollDrops(drops, rolls: { number })
	local got = {}
	for i, drop in drops do
		if (rolls[i] or 1) < drop.Chance then
			table.insert(got, drop)
		end
	end
	return got
end

-- Utilitaires --------------------------------------------------------------------------

function Formulas.clamp(value: number, cap: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(value, 0, cap)
end

local SUFFIXES = { "", "K", "M", "Md", "T", "Qa" }

-- 1234 -> "1,2K" ; 999 -> "999"
function Formulas.formatNumber(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text
	if n >= 100 then
		text = string.format("%d", math.floor(n))
	else
		text = string.format("%.1f", math.floor(n * 10) / 10):gsub("%.0$", "")
	end
	return (text:gsub("%.", ",")) .. SUFFIXES[index]
end

-- 8130 -> "2 h 15 min"
function Formulas.formatDuration(seconds: number): string
	seconds = math.floor(seconds)
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	if h > 0 then
		return string.format("%d h %02d min", h, m)
	elseif m > 0 then
		return string.format("%d min", m)
	end
	return string.format("%d s", seconds)
end

-- { Wood = 30, Stone = 10 } -> "30 Bois · 10 Pierre"
function Formulas.formatCost(materialDefs, cost): string
	local parts = {}
	for _, mat in materialDefs do
		if cost[mat.Id] then
			table.insert(parts, string.format("%s %s", Formulas.formatNumber(cost[mat.Id]), mat.Name))
		end
	end
	return table.concat(parts, " · ")
end

return Formulas
