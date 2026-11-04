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

-- Multiplicateur d'un compagnon seul (bonus additif +x => ×(1 + x)), format français :
-- 0.1 -> "×1,1" ; 1 -> "×2" ; 0.25 -> "×1,25".
function Formulas.petMultiplierText(bonus: number): string
	local value = math.floor((1 + bonus) * 100 + 0.5) / 100
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	return "×" .. text:gsub("%.", ",")
end

-- Probabilité d'éclosion lisible : 0.125 -> "12,5 %" ; 0.004 -> "0,40 %" ; 1 -> "100 %".
function Formulas.chanceText(chance: number): string
	local pct = chance * 100
	local text
	if pct >= 99.95 then
		text = "100"
	elseif pct < 1 then
		text = string.format("%.2f", pct)
	else
		text = string.format("%.1f", pct)
	end
	return (text:gsub("%.", ",")) .. " %"
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

-- Arbre d'améliorations ----------------------------------------------------------------

-- Somme d'une statistique sur les nœuds possédés. owned : { [NodeId] = true }.
function Formulas.treeStat(treeCfg, owned, stat: string): number
	local total = 0
	if not owned then
		return 0
	end
	for _, node in treeCfg.Nodes do
		if owned[node.Id] and node.Stat == stat then
			total += node.Value
		end
	end
	return total
end

-- Nœud précédent dans la branche (nil = premier nœud, accessible directement).
function Formulas.treePrevious(treeCfg, nodeId: string): string?
	local previous = nil
	for _, node in treeCfg.Nodes do
		if node.Id == nodeId then
			for _, other in treeCfg.Nodes do
				if other.Branch == node.Branch and other.Id == nodeId then
					return previous
				elseif other.Branch == node.Branch then
					previous = other.Id
				end
			end
		end
	end
	return nil
end

-- Peut-on acheter ce nœud ? wallet : { Gold, Trophies }. Retourne ok, raison.
function Formulas.canBuyNode(treeCfg, owned, nodeId: string, wallet): (boolean, string?)
	local node = nil
	for _, n in treeCfg.Nodes do
		if n.Id == nodeId then
			node = n
		end
	end
	if not node then
		return false, "Unknown"
	end
	if owned[nodeId] then
		return false, "Owned"
	end
	local previous = Formulas.treePrevious(treeCfg, nodeId)
	if previous and not owned[previous] then
		return false, "Requires"
	end
	for currency, amount in node.Cost do
		if (wallet[currency] or 0) < amount then
			return false, "Cost"
		end
	end
	return true, nil
end

-- Paramètres hors ligne effectifs (plafond et taux augmentés par l'arbre).
function Formulas.offlineConfig(baseCfg, treeCfg, owned)
	return {
		MaxSeconds = baseCfg.MaxSeconds + Formulas.treeStat(treeCfg, owned, "OfflineHours") * 3600,
		Rate = baseCfg.Rate + Formulas.treeStat(treeCfg, owned, "OfflineRate"),
		RecapMinSeconds = baseCfg.RecapMinSeconds,
	}
end

-- Œuf avec la chance appliquée : poids des raretés Rare et plus multipliés par (1 + luck).
function Formulas.luckyEgg(egg, petsCfg, luck: number)
	if luck <= 0 then
		return egg
	end
	local rarityOf = {}
	for _, def in petsCfg.List do
		rarityOf[def.Id] = def.Rarity
	end
	local weights = {}
	for id, w in egg.Weights do
		local order = petsCfg.Rarities[rarityOf[id]].Order
		weights[id] = if order >= 2 then w * (1 + luck) else w
	end
	local copy = table.clone(egg)
	copy.Weights = weights
	return copy
end

-- Trophées gagnés (arrondis vers le haut) avec le bonus de l'arbre.
function Formulas.trophies(base: number, trophyMult: number): number
	return math.ceil(base * (1 + trophyMult))
end

-- Récompenses quotidiennes et de temps de jeu ------------------------------------------

-- Numéro du jour UTC (00:00 UTC = changement de jour).
function Formulas.utcDay(t: number, dayLength: number): number
	return t // dayLength
end

-- Peut-on récupérer la récompense du jour ? (une par jour UTC, jours cumulés)
function Formulas.dailyClaimable(daily, today: number): boolean
	return today > daily.LastClaimDay
end

-- Prochaine récompense quotidienne : retourne { Day, Cycle, Reward, OpId }.
function Formulas.dailyNext(rewardsCfg, daily)
	local day = daily.Day + 1 -- 1..7
	local list = if daily.Cycle <= 1 then rewardsCfg.Daily else rewardsCfg.Repeat
	return {
		Day = day,
		Cycle = daily.Cycle,
		Reward = list[day],
		OpId = string.format("daily:%d:%d", daily.Cycle, day),
	}
end

-- État après récupération (pur) : avance le jour, boucle sur un nouveau cycle après le 7e.
function Formulas.dailyAdvance(daily, today: number, cycleLength: number)
	local nextState = { Day = daily.Day + 1, Cycle = daily.Cycle, LastClaimDay = today }
	if nextState.Day >= cycleLength then
		nextState.Day = 0
		nextState.Cycle += 1
	end
	return nextState
end

-- Paliers de temps de jeu franchis entre deux durées (secondes). Retourne leurs index.
function Formulas.playtimeReached(tiers, before: number, after: number)
	local reached = {}
	for i, tier in tiers do
		local s = tier.Minutes * 60
		if before < s and after >= s then
			table.insert(reached, i)
		end
	end
	return reached
end

-- Missions -----------------------------------------------------------------------------

-- Progression d'une mission : current (borné à Target), done.
-- stats : table des compteurs ; stats.Structures : { [Id] = true } pour Stat = "Structure".
function Formulas.questProgress(quest, stats): (number, boolean)
	local value
	if quest.Stat == "Structure" then
		value = if stats.Structures and stats.Structures[quest.Value] then 1 else 0
	else
		value = stats[quest.Stat] or 0
	end
	local current = math.min(value, quest.Target)
	return current, current >= quest.Target
end

-- Défense du bastion ----------------------------------------------------------------------

function Formulas.defenseStage(defenseCfg, bastionLevel: number, wave: number): number
	return 1 + (bastionLevel - 1) * defenseCfg.StagePerBastionLevel + (wave - 1)
end

function Formulas.defenseWaveSize(defenseCfg, wave: number, defenders: number): number
	return defenseCfg.WaveBase + wave + math.max(0, defenders - 1)
end

-- Titres -------------------------------------------------------------------------------

-- stats : { Rebirths, BestLevel, Harvests, StreetBest, TrophiesEarned, ForestKills, GolemKills,
--           Passes = { [Key] = true } }
function Formulas.titleUnlocked(title, stats): boolean
	if title.Stat == nil then
		return true
	elseif title.Stat == "Pass" then
		return stats.Passes ~= nil and stats.Passes[title.Value] == true
	end
	return (stats[title.Stat] or 0) >= title.Value
end

-- Titres débloqués, du plus prestigieux au moins prestigieux.
function Formulas.unlockedTitles(titlesCfg, stats)
	local list = {}
	for _, title in titlesCfg do
		if Formulas.titleUnlocked(title, stats) then
			table.insert(list, title)
		end
	end
	table.sort(list, function(a, b)
		return a.Order > b.Order
	end)
	return list
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

-- Région (1..#Regions) d'une étape ; les régions recommencent après la dernière.
function Formulas.streetRegion(stage: number, cfg): number
	return (math.ceil(stage / cfg.RegionLength) - 1) % #cfg.Regions + 1
end

-- Id de l'ennemi n° `index` de la vague de l'étape (patron : élite à l'étape 5, boss à 10).
function Formulas.streetKindId(stage: number, index: number, cfg): string
	local region = cfg.Regions[Formulas.streetRegion(stage, cfg)]
	if Formulas.streetIsPatron(stage, cfg) then
		local inRegion = (stage - 1) % cfg.RegionLength + 1
		return region.Patrons[if inRegion == cfg.RegionLength then 2 else 1]
	end
	return region.Pool[(stage + index - 2) % #region.Pool + 1]
end

-- Statistiques d'un ennemi d'un type donné (multiplicateurs du type appliqués à l'étape).
function Formulas.streetEnemyOf(stage: number, cfg, def)
	local base = Formulas.streetEnemy(stage, cfg)
	local reward = def.Reward or 1
	return {
		Health = math.max(1, math.floor(base.Health * (def.Health or 1))),
		Damage = math.max(1, math.floor(base.Damage * (def.Damage or 1))),
		Gold = math.floor(base.Gold * reward),
		Xp = math.floor(base.Xp * reward),
		Speed = cfg.Enemy.Speed * (def.Speed or 1),
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

-- Parcours du champion -----------------------------------------------------------------

-- Palier atteint (0 = aucun) pour une XP de parcours.
function Formulas.passTier(passCfg, xp: number): number
	return math.clamp(math.floor(xp / passCfg.XpPerTier), 0, #passCfg.Tiers)
end

-- État du parcours remis à zéro si la saison a changé (les droits du profil sont conservés).
function Formulas.passState(passCfg, state)
	if not state or state.Season ~= passCfg.Season then
		return { Season = passCfg.Season, Xp = 0, Free = {}, Premium = {} }
	end
	return state
end

-- Récompenses récupérables : liste de { Tier, Track ("Free" | "Premium") }.
function Formulas.passClaimable(passCfg, state, premium: boolean)
	local list = {}
	for tier = 1, Formulas.passTier(passCfg, state.Xp) do
		if not state.Free[tostring(tier)] then
			table.insert(list, { Tier = tier, Track = "Free" })
		end
		if premium and not state.Premium[tostring(tier)] then
			table.insert(list, { Tier = tier, Track = "Premium" })
		end
	end
	return list
end

-- Terrain du bastion et machines ---------------------------------------------------------

-- Zones possédées pour un niveau de terrain (nombre d'extensions achetées, dans l'ordre).
function Formulas.landOwned(landCfg, landLevel: number): { [string]: boolean }
	local owned = { Base = true }
	for i, area in landCfg.Areas do
		if i <= landLevel then
			owned[area.Id] = true
		end
	end
	return owned
end

-- Prochaine extension achetable (nil = tout est acheté).
function Formulas.landNext(landCfg, landLevel: number)
	return landCfg.Areas[landLevel + 1]
end

local BASE_RECT = { -45, 45, -45, 45 }

local function inRect(r, x: number, z: number): boolean
	return x > r[1] and x < r[2] and z > r[3] and z < r[4]
end

-- Zone contenant un point local ("Base", Id d'extension, ou nil hors terrain).
function Formulas.landAreaAt(landCfg, x: number, z: number): string?
	if inRect(BASE_RECT, x, z) then
		return "Base"
	end
	for _, area in landCfg.Areas do
		if inRect(area.Rect, x, z) then
			return area.Id
		end
	end
	return nil
end

-- Murs des extensions : segments { X1, Z1, X2, Z2 } sur les limites entre zones différentes
-- (ou vers l'extérieur), hors limites du terrain de base (murets existants) et hors passages.
function Formulas.landWalls(landCfg)
	local g = landCfg.Grid
	local xMin, xMax, zMin, zMax = BASE_RECT[1], BASE_RECT[2], BASE_RECT[3], BASE_RECT[4]
	for _, area in landCfg.Areas do
		xMin, xMax = math.min(xMin, area.Rect[1]), math.max(xMax, area.Rect[2])
		zMin, zMax = math.min(zMin, area.Rect[3]), math.max(zMax, area.Rect[4])
	end
	local half = landCfg.OpeningWidth / 2
	local function isOpening(along: string, fixed: number, pos: number): boolean
		for _, o in landCfg.Openings do
			if o.Along == along then
				local oFixed = if along == "X" then o.Z else o.X
				local oPos = if along == "X" then o.X else o.Z
				if math.abs(oFixed - fixed) < 0.01 and math.abs(pos - oPos) < half then
					return true
				end
			end
		end
		return false
	end
	local function wallBetween(a: string?, b: string?): boolean
		return a ~= b and a ~= "Base" and b ~= "Base"
	end
	local segments = {}
	-- Murs parallèles à X (z fixe)
	for z = zMin, zMax + 0.01, g do
		local start = nil
		for x = xMin, xMax + 0.01, g do
			local mid = x + g / 2
			local wall = x < xMax - 0.01
				and wallBetween(
					Formulas.landAreaAt(landCfg, mid, z - g / 2),
					Formulas.landAreaAt(landCfg, mid, z + g / 2)
				)
				and not isOpening("X", z, mid)
			if wall and not start then
				start = x
			elseif not wall and start then
				table.insert(segments, { X1 = start, Z1 = z, X2 = x, Z2 = z })
				start = nil
			end
		end
	end
	-- Murs parallèles à Z (x fixe)
	for x = xMin, xMax + 0.01, g do
		local start = nil
		for z = zMin, zMax + 0.01, g do
			local mid = z + g / 2
			local wall = z < zMax - 0.01
				and wallBetween(
					Formulas.landAreaAt(landCfg, x - g / 2, mid),
					Formulas.landAreaAt(landCfg, x + g / 2, mid)
				)
				and not isOpening("Z", x, mid)
			if wall and not start then
				start = z
			elseif not wall and start then
				table.insert(segments, { X1 = x, Z1 = start, X2 = x, Z2 = z })
				start = nil
			end
		end
	end
	return segments
end

-- Production d'une machine par seconde à un niveau.
function Formulas.machineRate(machinesCfg, def, level: number): number
	return def.Rate * machinesCfg.LevelRateMult ^ (level - 1)
end

-- Valeur en or par seconde d'une machine à un niveau (avant la part personnelle).
function Formulas.machineGold(machinesCfg, def, level: number): number
	return def.Gold * machinesCfg.LevelRateMult ^ (level - 1)
end

-- Coût pour passer du niveau `level` au suivant.
function Formulas.machineUpgradeCost(machinesCfg, def, level: number)
	local cost = {}
	for id, amount in def.Cost do
		cost[id] = math.ceil(amount * machinesCfg.UpgradeCostMult ^ level)
	end
	return cost
end

-- Production totale d'un bastion : { Materials = { [Id] = /s }, PersonalGold = or/s par membre }.
-- machines : { [SlotId] = niveau } ; seules les machines d'extensions possédées comptent.
function Formulas.machineRates(machinesCfg, landCfg, landLevel: number, machines)
	local defs = {}
	for _, def in machinesCfg.List do
		defs[def.Id] = def
	end
	local owned = Formulas.landOwned(landCfg, landLevel)
	local result = { Materials = {}, PersonalGold = 0 }
	for _, area in landCfg.Areas do
		if owned[area.Id] then
			for _, slot in area.Slots do
				local level = machines[slot.Id]
				local def = defs[slot.Machine]
				if level and level > 0 and def then
					result.Materials[def.Material] = (result.Materials[def.Material] or 0)
						+ Formulas.machineRate(machinesCfg, def, level)
					result.PersonalGold += Formulas.machineGold(machinesCfg, def, level) * machinesCfg.PersonalGoldShare
				end
			end
		end
	end
	return result
end

-- Production hors ligne : taux réduit, durée plafonnée. Retourne { [Id] = quantité }.
function Formulas.machineOffline(rates, seconds: number, offlineCfg)
	local credited = math.clamp(seconds, 0, offlineCfg.MaxSeconds)
	local out = {}
	for id, perSecond in rates.Materials do
		out[id] = perSecond * credited * offlineCfg.Rate
	end
	return out
end

return Formulas
