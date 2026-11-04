--[[
	RebirthService : renaissance FACULTATIVE (voir Config/Rebirth.luau).
	Remet à zéro niveau, XP (et or) personnels ; conserve améliorations, compagnons, groupe
	et bastion ; augmente le multiplicateur permanent et débloque tapis et emplacements.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Rebirth = require(Shared.Config.Rebirth)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)
local TrainingService = require(script.Parent.TrainingService)
local Notifier = require(script.Parent.Notifier)

local RebirthService = {}

function RebirthService.rebirth(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return { ok = false, msg = Texts.Loading }
	end
	if not ProfileService.canMutate(player) then
		return { ok = false, msg = Texts.ReadOnly }
	end
	local ok, reason = Formulas.canRebirth(profile.Level, profile.Rebirths, Rebirth)
	if not ok then
		if reason == "Max" then
			return { ok = false, msg = "Nombre maximal de renaissances atteint." }
		end
		return {
			ok = false,
			msg = string.format(
				"Niveau %d requis (tu es niveau %d).",
				Formulas.rebirthRequiredLevel(profile.Rebirths, Rebirth),
				profile.Level
			),
		}
	end

	TrainingService.stop(player)
	profile.Rebirths += 1
	profile.Level = 1
	profile.TrainXp = 0
	if Rebirth.ResetGold then
		profile.Gold = 0
	end
	ProfileService.sync(player)
	task.spawn(ProfileService.saveNow, player)

	local mult = Formulas.rebirthMultiplier(profile.Rebirths, Rebirth)
	Notifier.broadcast(
		string.format("🔁 %s a fait sa renaissance n°%d !", player.DisplayName, profile.Rebirths),
		"reward"
	)
	Notifier.send(
		player,
		string.format("Renaissance %d ! Multiplicateur permanent x%.2f", profile.Rebirths, mult),
		"reward"
	)
	return { ok = true }
end

return RebirthService
