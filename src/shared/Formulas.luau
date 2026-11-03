--[[
	Formules du jeu. Fonctions PURES : pas d'API Roblox, pas d'état global.
	Toute la configuration est passée en paramètre, ce qui permet de les tester avec Lune.
]]

local Formulas = {}

-- Production d'or par seconde des bâtiments possédés.
-- ownedSet : { [buildingId] = true }
function Formulas.baseIncome(buildingDefs, ownedSet): number
	local total = 0
	for _, def in buildingDefs do
		if ownedSet[def.Id] then
			total += def.Income
		end
	end
	return total
end

-- Multiplicateur dû au niveau d'entraînement (niveau 1 = aucun bonus).
function Formulas.levelMultiplier(level: number, bonusPerLevel: number): number
	return 1 + math.max(0, level - 1) * bonusPerLevel
end

-- Production totale : base x niveau x passes.
function Formulas.incomePerSecond(
	buildingDefs,
	ownedSet,
	level: number,
	bonusPerLevel: number,
	passMultiplier: number
): number
	return Formulas.baseIncome(buildingDefs, ownedSet) * Formulas.levelMultiplier(level, bonusPerLevel) * passMultiplier
end

-- Peut-on acheter ce bâtiment ? Retourne ok, raison.
function Formulas.canBuy(def, ownedSet, gold: number): (boolean, string?)
	if def == nil then
		return false, "Bâtiment inconnu"
	end
	if ownedSet[def.Id] then
		return false, "Déjà construit"
	end
	if def.Requires and not ownedSet[def.Requires] then
		return false, "Prérequis manquant"
	end
	if gold < def.Cost then
		return false, "Or insuffisant"
	end
	return true, nil
end

-- Bâtiments achetables maintenant (prérequis remplis, non possédés), sans tenir compte de l'or.
function Formulas.availableBuildings(buildingDefs, ownedSet)
	local result = {}
	for _, def in buildingDefs do
		if not ownedSet[def.Id] and (def.Requires == nil or ownedSet[def.Requires]) then
			table.insert(result, def)
		end
	end
	return result
end

-- XP requise pour passer du niveau `level` au suivant.
function Formulas.xpToNext(level: number, cfg): number
	return math.max(1, math.floor(cfg.BaseXp * level ^ cfg.Exponent))
end

-- Ajoute de l'XP et gère les montées de niveau (plusieurs possibles d'un coup).
-- Retourne newLevel, newXp, levelsGained.
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

-- Gains hors ligne. Retourne or, secondes réellement comptées.
-- elapsed peut être négatif (horloge serveur décalée) : on le traite comme 0.
function Formulas.offlineEarnings(incomePerSec: number, elapsed: number, cfg): (number, number)
	if elapsed < cfg.MinSeconds or incomePerSec <= 0 then
		return 0, 0
	end
	local seconds = math.min(elapsed, cfg.MaxSeconds)
	return math.floor(incomePerSec * seconds * cfg.Rate), seconds
end

-- Récompense d'un produit indexé sur la production.
function Formulas.incomeMinutesReward(incomePerSec: number, minutes: number, minGold: number): number
	return math.max(minGold, math.floor(incomePerSec * 60 * minutes))
end

-- Ajout d'or borné.
function Formulas.clampGold(gold: number, cap: number): number
	if gold ~= gold then -- NaN
		return 0
	end
	return math.clamp(gold, 0, cap)
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

return Formulas
