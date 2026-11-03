--[[
	UpgradeService : améliorations personnelles payées en or individuel (cahier §3).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Upgrades = require(Shared.Config.Upgrades)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)

local UpgradeService = {}

local upgradeById = {}
for _, def in Upgrades do
	upgradeById[def.Id] = def
end

local function applyToughness(player: Player)
	local profile = ProfileService.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if profile and humanoid then
		local def = upgradeById.Toughness
		humanoid.MaxHealth = 100 + Formulas.upgradeLevel(profile, "Toughness") * def.PerLevel
		humanoid.Health = humanoid.MaxHealth
	end
end

function UpgradeService.buy(player: Player, upgradeId: string)
	local def = upgradeById[upgradeId]
	local profile = ProfileService.get(player)
	if not def or not profile then
		return { ok = false, msg = Texts.Loading }
	end
	if not ProfileService.canMutate(player) then
		return { ok = false, msg = Texts.ReadOnly }
	end
	local level = Formulas.upgradeLevel(profile, upgradeId)
	local cost = Formulas.upgradeCost(def, level)
	if not cost then
		return { ok = false, msg = Texts.UpgradeMax }
	end
	if profile.Gold < cost then
		return { ok = false, msg = string.format(Texts.NotEnoughGold, Formulas.formatNumber(cost - profile.Gold)) }
	end
	profile.Gold -= cost
	profile.Upgrades[upgradeId] = level + 1
	if upgradeId == "Toughness" then
		applyToughness(player)
	end
	ProfileService.sync(player)
	return { ok = true, msg = string.format(Texts.UpgradeBought, def.Name, level + 1) }
end

function UpgradeService.start()
	ProfileService.onLoaded(function(player)
		applyToughness(player)
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			applyToughness(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return UpgradeService
