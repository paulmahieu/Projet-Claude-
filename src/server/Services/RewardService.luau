--[[
	RewardService : cadeaux GRATUITS (cahier §9.3, §9.4, §9.6).

	Quotidien : 7 jours de présence cumulés, 00:00 UTC, aucune perte en cas d'absence ; un clic
	« Récupérer gratuitement ». Le crédit, l'identifiant d'opération ("daily:<cycle>:<jour>")
	et le nouvel état sont écrits dans le même profil : une réclamation répétée ou un
	changement de serveur ne peut pas dupliquer un cadeau.

	Temps de jeu : secondes de jeu ACTIF (le joueur a bougé récemment) cumulées par jour UTC,
	sessions additionnées ; chaque palier est crédité automatiquement une seule fois
	("play:<jour>:<palier>"), même si le joueur se déconnecte juste après.

	Studio : « jour suivant » simulé pour tester (DevNextDay).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Rewards = require(Shared.Config.Rewards)
local Training = require(Shared.Config.Training)
local Economy = require(Shared.Config.Economy)
local Pets = require(Shared.Config.Pets)
local OpLog = require(Shared.OpLog)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)
local PetService = require(script.Parent.PetService)
local Notifier = require(script.Parent.Notifier)

local RewardService = {}

local TICK = 5
local lastPosition: { [Player]: Vector3 } = {}
local lastActivity: { [Player]: number } = {}

local petName = {}
for _, def in Pets.List do
	petName[def.Id] = def.Name
end

local function today(): number
	return Formulas.utcDay(os.time(), Rewards.DayLength)
end

-- Texte d'une récompense (« +150 or, +15 trophées »).
function RewardService.describe(reward): string
	local parts = {}
	if reward.Gold then
		table.insert(parts, "+" .. Formulas.formatNumber(reward.Gold) .. " or")
	end
	if reward.Trophies then
		table.insert(parts, "+" .. reward.Trophies .. " trophées")
	end
	if reward.Xp then
		table.insert(parts, "+" .. reward.Xp .. " XP")
	end
	if reward.Pet then
		table.insert(parts, "compagnon " .. (petName[reward.Pet] or reward.Pet))
	end
	return table.concat(parts, ", ")
end

-- Applique une récompense au profil (sans sauvegarder). Utilisée aussi par les missions.
local function grant(player: Player, profile, reward)
	if reward.Gold then
		profile.Gold = Formulas.clamp(profile.Gold + reward.Gold, Economy.GoldCap)
	end
	if reward.Trophies then
		profile.Trophies += reward.Trophies
		profile.Stats.TrophiesEarned += reward.Trophies
	end
	if reward.Xp then
		profile.Level, profile.TrainXp = Formulas.addXp(profile.Level, profile.TrainXp, reward.Xp, Training)
	end
	if reward.Pet then
		PetService.grant(player, reward.Pet)
	end
end

local function publish(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	local day = today()
	player:SetAttribute("DailyDay", profile.Daily.Day)
	player:SetAttribute("DailyCycle", profile.Daily.Cycle)
	player:SetAttribute("DailyClaimable", Formulas.dailyClaimable(profile.Daily, day))
	player:SetAttribute("DailyResetAt", (day + 1) * Rewards.DayLength) -- heure UTC du prochain jour
	local seconds = if profile.Playtime.Day == day then profile.Playtime.Seconds else 0
	player:SetAttribute("PlaySeconds", math.floor(seconds))
end

RewardService.grant = function(player: Player, profile, reward)
	grant(player, profile, reward)
end

function RewardService.claimDaily(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return { ok = false, msg = Texts.Loading }
	end
	if not ProfileService.canMutate(player) then
		return { ok = false, msg = Texts.ReadOnly }
	end
	local day = today()
	if not Formulas.dailyClaimable(profile.Daily, day) then
		return { ok = false, msg = "Déjà récupéré aujourd'hui : reviens après 00:00 UTC." }
	end
	local nextReward = Formulas.dailyNext(Rewards, profile.Daily)
	-- Crédit + preuve + nouvel état : une seule modification du profil.
	if not OpLog.has(profile.Ops, nextReward.OpId) then
		grant(player, profile, nextReward.Reward)
		OpLog.add(profile.Ops, nextReward.OpId, Economy.Save.MaxOps)
	end
	local state = Formulas.dailyAdvance(profile.Daily, day, #Rewards.Daily)
	profile.Daily.Day, profile.Daily.Cycle, profile.Daily.LastClaimDay = state.Day, state.Cycle, state.LastClaimDay
	ProfileService.sync(player)
	publish(player)
	task.spawn(ProfileService.saveNow, player)
	return {
		ok = true,
		msg = string.format("Jour %d : %s", nextReward.Day, RewardService.describe(nextReward.Reward)),
	}
end

-- Studio uniquement (vérifié par Net) : simule le passage au jour suivant.
function RewardService.devNextDay(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return { ok = false }
	end
	profile.Daily.LastClaimDay = math.min(profile.Daily.LastClaimDay, today() - 1)
	profile.Playtime = { Day = -1, Seconds = 0, Claimed = {} }
	publish(player)
	return { ok = true, msg = "Test Studio : nouveau jour simulé." }
end

local function tickPlaytime(player: Player, now: number)
	local profile = ProfileService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	-- Activité : le personnage a bougé depuis la dernière vérification.
	local previous = lastPosition[player]
	if not previous or (root.Position - previous).Magnitude > 1 then
		lastActivity[player] = now
	end
	lastPosition[player] = root.Position
	if now - (lastActivity[player] or 0) > Rewards.ActivityWindow or not ProfileService.canMutate(player) then
		return
	end

	local day = today()
	if profile.Playtime.Day ~= day then
		profile.Playtime = { Day = day, Seconds = 0, Claimed = {} }
	end
	local before = profile.Playtime.Seconds
	profile.Playtime.Seconds = before + TICK
	for _, index in Formulas.playtimeReached(Rewards.Playtime, before, profile.Playtime.Seconds) do
		local opId = string.format("play:%d:%d", day, index)
		if not OpLog.has(profile.Ops, opId) then
			local tier = Rewards.Playtime[index]
			grant(player, profile, tier.Reward)
			OpLog.add(profile.Ops, opId, Economy.Save.MaxOps)
			profile.Playtime.Claimed[tostring(index)] = true
			ProfileService.sync(player)
			Notifier.send(
				player,
				string.format("Cadeau de temps de jeu (%d min) : %s", tier.Minutes, RewardService.describe(tier.Reward)),
				"reward"
			)
			if index == #Rewards.Playtime then
				Notifier.send(player, "Tous les cadeaux de temps de jeu du jour sont récupérés !", "info")
			end
		end
	end
	player:SetAttribute("PlaySeconds", math.floor(profile.Playtime.Seconds))
end

function RewardService.start()
	ProfileService.onLoaded(function(player, profile)
		publish(player)
		if Formulas.dailyClaimable(profile.Daily, today()) then
			Notifier.send(player, "Ta récompense quotidienne t'attend : Menu > Cadeaux.", "reward")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPosition[player] = nil
		lastActivity[player] = nil
	end)
	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tickPlaytime, player, now)
				if not ok then
					warn("[RewardService] " .. tostring(err))
				end
			end
			-- Changement de jour UTC : le bouton du quotidien se réactive sans reconnexion.
			if today() ~= lastDay then
				lastDay = today()
				for _, player in Players:GetPlayers() do
					publish(player)
				end
			end
		end
	end)
end

return RewardService
