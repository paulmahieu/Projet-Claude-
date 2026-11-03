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

function Formulas.power(level: number, cfg): number
	return cfg.PowerBase + cfg.PowerPerLevel * (level - 1)
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
function Formulas.bestStationTier(structureDefs, owned): number
	local best = 0
	for _, def in structureDefs do
		if owned[def.Id] and def.Effects.StationTier then
			best = math.max(best, def.Effects.StationTier)
		end
	end
	return best
end

-- Rendement d'un tapis par seconde, SANS bonus temporaire.
-- focusLevel/focusPerLevel : amélioration personnelle « Concentration ».
function Formulas.trainingRates(tier: number, groupMult: number, focusLevel: number, focusPerLevel: number, cfg)
	if tier <= 0 then
		return { Xp = 0, Gold = 0 }
	end
	local mult = (cfg.TierMultiplier[tier] or 1) * groupMult * (1 + focusLevel * focusPerLevel)
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
