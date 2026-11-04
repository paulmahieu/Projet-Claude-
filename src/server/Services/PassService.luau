--[[
	PassService : Parcours du champion (pass de saison, piste gratuite + piste premium).

	- XP gagnée en jouant : minute active, missions, boss, Rue des boss, défense, quotidien.
	- Récupération : « Tout récupérer » crédite chaque palier atteint non récupéré. Le crédit
	  et la marque « récupéré » sont écrits dans la même modification du profil, puis le profil
	  est sauvegardé : impossible de récupérer deux fois, même en changeant de serveur.
	- Piste premium : possession du pass Robux vérifiée côté serveur à chaque récupération.
	  Achat en cours de saison : les paliers déjà atteints deviennent récupérables.
	- Nouvelle saison (Config/Pass.Season) : XP et récupérations remises à zéro, droits gardés.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Pass = require(Shared.Config.Pass)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)
local RewardService = require(script.Parent.RewardService)
local MonetizationService = require(script.Parent.MonetizationService)
local Notifier = require(script.Parent.Notifier)

local PassService = {}

local function premium(player: Player): boolean
	return MonetizationService.ownsPass(player, Pass.PremiumPass)
end

local function stateOf(profile)
	profile.Pass = Formulas.passState(Pass, profile.Pass)
	return profile.Pass
end

local function keys(set): string
	local list = {}
	for k in set do
		table.insert(list, k)
	end
	return table.concat(list, ",")
end

-- Attributs lus par l'onglet Parcours (aucune donnée sensible).
function PassService.publish(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	local state = stateOf(profile)
	local isPremium = premium(player)
	player:SetAttribute("PassXp", state.Xp)
	player:SetAttribute("PassTier", Formulas.passTier(Pass, state.Xp))
	player:SetAttribute("PassPremium", isPremium)
	player:SetAttribute("PassFree", keys(state.Free))
	player:SetAttribute("PassPremiumClaimed", keys(state.Premium))
	player:SetAttribute("PassClaimable", #Formulas.passClaimable(Pass, state, isPremium))
end

function PassService.addXp(player: Player, amount: number)
	local profile = ProfileService.get(player)
	if not profile or amount <= 0 or not ProfileService.canMutate(player) then
		return
	end
	local state = stateOf(profile)
	local before = Formulas.passTier(Pass, state.Xp)
	state.Xp = math.min(state.Xp + amount, Pass.XpPerTier * #Pass.Tiers)
	local after = Formulas.passTier(Pass, state.Xp)
	if after > before then
		Notifier.send(
			player,
			string.format("🏅 Parcours : palier %d atteint ! Récompenses dans le menu Parcours.", after),
			"reward"
		)
	end
	PassService.publish(player)
end

function PassService.claimAll(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return { ok = false, msg = Texts.Loading }
	end
	if not ProfileService.canMutate(player) then
		return { ok = false, msg = Texts.ReadOnly }
	end
	local state = stateOf(profile)
	local list = Formulas.passClaimable(Pass, state, premium(player))
	if #list == 0 then
		return { ok = false, msg = "Rien à récupérer pour l'instant : continue à jouer !" }
	end
	local texts = {}
	for _, entry in list do
		local tier = Pass.Tiers[entry.Tier]
		local reward = tier[entry.Track]
		-- Marque et crédit ensemble (aucune attente entre les deux).
		state[entry.Track][tostring(entry.Tier)] = true
		RewardService.grant(player, profile, reward)
		table.insert(texts, RewardService.describe(reward))
		if reward.Entitlement then
			Notifier.broadcast(
				string.format("👑 %s a débloqué le %s !", player.DisplayName, reward.Entitlement.Name),
				"reward"
			)
		end
	end
	ProfileService.sync(player)
	PassService.publish(player)
	task.spawn(ProfileService.saveNow, player)
	return { ok = true, msg = "Parcours : " .. table.concat(texts, " · ") }
end

-- Studio uniquement (vérifié par Net).
function PassService.devXp(player: Player)
	PassService.addXp(player, Pass.XpPerTier * 3)
	return { ok = true, msg = "Test Studio : +3 paliers de parcours." }
end

function PassService.start()
	ProfileService.onLoaded(function(player)
		PassService.publish(player)
	end)
	MonetizationService.onPassChanged(function(player, key)
		if key == Pass.PremiumPass then
			PassService.publish(player)
			Notifier.send(
				player,
				"Piste premium débloquée ! Les paliers déjà atteints sont récupérables (menu Parcours).",
				"reward"
			)
		end
	end)
	-- Une minute de jeu actif = XP de parcours (le temps hors ligne ne compte pas).
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if RewardService.isActive(player) then
					local ok, err = pcall(PassService.addXp, player, Pass.Xp.ActiveMinute)
					if not ok then
						warn("[PassService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return PassService
