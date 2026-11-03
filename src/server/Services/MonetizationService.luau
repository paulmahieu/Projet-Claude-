--[[
	MonetizationService : passes permanents et produits consommables.

	ProcessReceipt est idempotent : chaque PurchaseId est mémorisé dans les données du joueur
	et la sauvegarde est forcée AVANT de confirmer l'achat à Roblox. Si la sauvegarde échoue,
	on répond NotProcessedYet et Roblox renverra le reçu plus tard (sans double crédit).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local DataSchema = require(Shared.DataSchema)

local DataService = require(script.Parent.DataService)
local Notifier = require(script.Parent.Notifier)

local MonetizationService = {}

local passCache: { [Player]: { [string]: boolean } } = {}

local productById = {}
for _, product in Products.DevProducts do
	if product.ProductId ~= 0 then
		productById[product.ProductId] = product
	end
end

local passKeyById = {}
for key, pass in Products.GamePasses do
	if pass.GamePassId ~= 0 then
		passKeyById[pass.GamePassId] = key
	end
end

function MonetizationService.hasPass(player: Player, key: string): boolean
	local pass = Products.GamePasses[key]
	if not pass or pass.GamePassId == 0 then
		return false
	end
	local cache = passCache[player]
	if not cache then
		cache = {}
		passCache[player] = cache
	end
	if cache[key] == nil then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
		end)
		if not ok then
			-- En cas d'erreur réseau, on ne met pas en cache pour réessayer plus tard.
			return false
		end
		cache[key] = owns
	end
	return cache[key]
end

function MonetizationService.passMultiplier(player: Player, key: string): number
	if MonetizationService.hasPass(player, key) then
		return Products.GamePasses[key].Multiplier
	end
	return 1
end

local function grantProduct(player: Player, product)
	local reward = product.Reward
	if reward.Type == "IncomeMinutes" then
		-- Require tardif : EconomyService dépend lui-même de ce module.
		local EconomyService = require(script.Parent.EconomyService)
		local Formulas = require(Shared.Formulas)
		local amount =
			Formulas.incomeMinutesReward(EconomyService.incomePerSecond(player), reward.Minutes, reward.MinGold)
		EconomyService.addGold(player, amount)
		Notifier.send(player, string.format("%s : +%s or !", product.Name, Formulas.formatNumber(amount)), "reward")
		return true
	end
	warn("[Monetization] Type de récompense inconnu : " .. tostring(reward.Type))
	return false
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DataSchema.hasReceipt(data, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productById[info.ProductId]
	if not product then
		warn("[Monetization] Produit inconnu : " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grantProduct(player, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataSchema.addReceipt(data, info.PurchaseId)
	if not DataService.saveNow(player) then
		-- Le reçu est noté en mémoire : s'il revient dans cette session, pas de double crédit.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		local key = passKeyById[gamePassId]
		if purchased and key then
			passCache[player] = passCache[player] or {}
			passCache[player][key] = true
			Notifier.send(player, "Merci ! " .. Products.GamePasses[key].Name .. " est actif.", "reward")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
	end)
end

return MonetizationService
