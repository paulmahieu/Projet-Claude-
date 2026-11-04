--[[
	MonetizationService : traitement des achats (cahier §9.6).

	- Seuls les articles avec un identifiant configuré ET une livraison prête (Ready) sont vendus.
	- ProcessReceipt : vérifie joueur, produit, identifiant unique d'achat ; accorde le bénéfice
	  et enregistre la preuve ("receipt:<PurchaseId>") dans le MÊME profil ; répond
	  PurchaseGranted uniquement après une sauvegarde réussie, sinon NotProcessedYet.
	- Un reçu déjà traité est confirmé sans nouveau crédit (après s'être assuré qu'il est sauvegardé).
	- Simulation (Studio uniquement) : même chemin de livraison avec un faux identifiant d'achat.
	- Les passes (cosmétiques, parcours premium...) arrivent aux étapes suivantes.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Game = require(Shared.Config.Game)
local Economy = require(Shared.Config.Economy)
local Texts = require(Shared.Config.Texts)
local OpLog = require(Shared.OpLog)
local Formulas = require(Shared.Formulas)

local ProfileService = require(script.Parent.ProfileService)
local Notifier = require(script.Parent.Notifier)

local MonetizationService = {}

local productById = {}
local productByKey = {}
for _, item in Products do
	productByKey[item.Key] = item
	if item.Kind == "Product" and item.Id ~= 0 and item.Ready then
		productById[item.Id] = item
	end
end

-- Applique la livraison au profil (sans sauvegarder). Retourne true si livré.
local function deliver(profile, item): boolean
	local delivery = item.Delivery
	if delivery.Type == "Gold" then
		profile.Gold = Formulas.clamp(profile.Gold + delivery.Amount, Economy.GoldCap)
		return true
	end
	return false
end

-- Logique commune aux reçus réels et simulés. Retourne une Enum.ProductPurchaseDecision.
local function processPurchase(player: Player, item, purchaseId: string)
	local profile = ProfileService.get(player)
	if not profile or not ProfileService.canMutate(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local opId = "receipt:" .. purchaseId
	if OpLog.has(profile.Ops, opId) then
		-- Déjà livré : on confirme seulement si cette livraison est bien sauvegardée.
		return if ProfileService.saveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not deliver(profile, item) then
		warn("[Monetization] Livraison non implémentée : " .. item.Key)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	OpLog.add(profile.Ops, opId, Economy.Save.MaxOps)
	ProfileService.sync(player)
	if not ProfileService.saveNow(player) then
		-- Bénéfice et preuve restent liés en mémoire : un nouvel envoi du reçu ne recréditera pas.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Notifier.send(player, string.format(Texts.PurchaseThanks, item.Name), "reward")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local item = productById[info.ProductId]
	if not item then
		warn("[Monetization] Produit inconnu ou non prêt : " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return processPurchase(player, item, tostring(info.PurchaseId))
end

-- Possession d'un pass, vérifiée côté serveur et mise en cache par joueur.
local passCache: { [Player]: { [string]: boolean } } = {}

function MonetizationService.ownsPass(player: Player, key: string): boolean
	local item = productByKey[key]
	if not item or item.Kind ~= "Pass" or item.Id == 0 or not item.Ready then
		return false
	end
	local cache = passCache[player]
	if not cache then
		cache = {}
		passCache[player] = cache
	end
	if cache[key] == nil then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.Id)
		end)
		if not ok then
			return false -- erreur réseau : on réessaiera plus tard
		end
		cache[key] = owns
	end
	return cache[key]
end

function MonetizationService.devToolsEnabled(): boolean
	return RunService:IsStudio() and Game.DevToolsInStudio
end

-- Simulation d'achat (Studio uniquement), via le même chemin de livraison.
function MonetizationService.simulate(player: Player, key: string)
	if not MonetizationService.devToolsEnabled() then
		return { ok = false, msg = Texts.ShopDisabled }
	end
	local item = productByKey[key]
	if not item or item.Kind ~= "Product" or not item.Ready then
		return { ok = false, msg = Texts.ShopDisabled }
	end
	local decision = processPurchase(player, item, "sim-" .. HttpService:GenerateGUID(false))
	return { ok = decision == Enum.ProductPurchaseDecision.PurchaseGranted, msg = "Simulation : " .. decision.Name }
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	-- La fermeture de la fenêtre ne prouve rien : on revérifie la possession côté serveur.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
		if purchased then
			passCache[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
	end)
end

return MonetizationService
