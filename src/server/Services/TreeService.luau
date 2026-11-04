--[[
	TreeService : achat des nœuds de l'arbre d'améliorations et application des effets
	physiques (points de vie, vitesse). Les autres effets sont lus par les services concernés
	via ProfileService (entraînement, dégâts, hors ligne, compagnons, chance, trophées).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Tree = require(Shared.Config.Tree)
local Combat = require(Shared.Config.Combat)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)

local TreeService = {}

local nodeById = {}
for _, node in Tree.Nodes do
	nodeById[node.Id] = node
end

local function applyCharacter(player: Player)
	local profile = ProfileService.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if profile and humanoid then
		humanoid.MaxHealth = Combat.PlayerMaxHealth + Formulas.treeStat(Tree, profile.Tree, "MaxHealth")
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed = 16 + Formulas.treeStat(Tree, profile.Tree, "WalkSpeed")
	end
end

function TreeService.buy(player: Player, nodeId: string)
	local profile = ProfileService.get(player)
	if not profile then
		return { ok = false, msg = Texts.Loading }
	end
	if not ProfileService.canMutate(player) then
		return { ok = false, msg = Texts.ReadOnly }
	end
	local ok, reason =
		Formulas.canBuyNode(Tree, profile.Tree, nodeId, { Gold = profile.Gold, Trophies = profile.Trophies })
	if not ok then
		local messages = {
			Unknown = "Amélioration inconnue.",
			Owned = "Déjà acquise.",
			Requires = "Achète d'abord l'amélioration précédente de cette branche.",
			Cost = "Pas assez d'or ou de trophées.",
		}
		return { ok = false, msg = messages[reason] or reason }
	end
	local node = nodeById[nodeId]
	-- Débit et acquisition dans la même modification du profil.
	profile.Gold -= node.Cost.Gold or 0
	profile.Trophies -= node.Cost.Trophies or 0
	profile.Tree[nodeId] = true
	if node.Stat == "MaxHealth" or node.Stat == "WalkSpeed" then
		applyCharacter(player)
	end
	ProfileService.sync(player)
	return { ok = true, msg = node.Name .. " acquis !" }
end

function TreeService.start()
	ProfileService.onLoaded(function(player)
		applyCharacter(player)
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			applyCharacter(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return TreeService
