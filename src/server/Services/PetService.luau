--[[
	PetService : œufs (achetés en OR), inventaire et compagnons équipés.

	- Tirage côté serveur (Random), probabilités issues de Config/Pets (affichées au joueur).
	- Débit de l'or et ajout du compagnon dans la même modification du profil.
	- Emplacements équipés selon les renaissances ; bonus total plafonné.
	- Le client ne voit l'inventaire que via le RemoteEvent PetsUpdate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Pets = require(Shared.Config.Pets)
local Texts = require(Shared.Config.Texts)

local ProfileService = require(script.Parent.ProfileService)
local PlotService = require(script.Parent.PlotService)
local Models = require(script.Parent.Parent.Art.Models)

local PetsUpdate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PetsUpdate") :: RemoteEvent

local PetService = {}

local rng = Random.new()
local HATCH_DISTANCE = 16

local eggById, petById = {}, {}
for _, egg in Pets.Eggs do
	eggById[egg.Id] = egg
end
for _, def in Pets.List do
	petById[def.Id] = def
end

local function toColor(rgb): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function PetService.snapshot(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return nil
	end
	return {
		Pets = profile.Pets,
		Equipped = profile.EquippedPets,
		Slots = ProfileService.petSlots(player),
		Size = Pets.InventorySize,
	}
end

local function push(player: Player)
	ProfileService.sync(player) -- multiplicateur et suiveurs
	local snap = PetService.snapshot(player)
	if snap then
		PetsUpdate:FireClient(player, snap)
	end
end

local function guard(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return nil, { ok = false, msg = Texts.Loading }
	end
	if not ProfileService.canMutate(player) then
		return nil, { ok = false, msg = Texts.ReadOnly }
	end
	return profile, nil
end

local function findPet(profile, uid: number)
	for index, pet in profile.Pets do
		if pet.Uid == uid then
			return pet, index
		end
	end
	return nil, nil
end

function PetService.hatch(player: Player, eggId: string)
	local profile, err = guard(player)
	if not profile then
		return err
	end
	local egg = eggById[eggId]
	if not egg then
		return { ok = false, msg = "Œuf inconnu." }
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local eggPos = Vector3.new(egg.Position[1], root and root.Position.Y or 0, egg.Position[2])
	if not root or (root.Position - eggPos).Magnitude > HATCH_DISTANCE then
		return { ok = false, msg = Texts.TooFar }
	end
	if #profile.Pets >= Pets.InventorySize then
		return { ok = false, msg = "Inventaire plein : libère de la place dans Compagnons." }
	end
	if profile.Gold < egg.Cost then
		return { ok = false, msg = string.format(Texts.NotEnoughGold, Formulas.formatNumber(egg.Cost - profile.Gold)) }
	end

	-- Débit et ajout dans la même modification du profil (aucune attente entre les deux).
	profile.Gold -= egg.Cost
	-- Chance de l'arbre : favorise les raretés Rare et plus (probabilités affichées en conséquence).
	local luck = ProfileService.treeStat(player, "Luck")
	local petId = Formulas.rollEgg(Formulas.luckyEgg(egg, Pets, luck), rng:NextNumber())
	local uid = profile.NextPetUid
	profile.NextPetUid += 1
	table.insert(profile.Pets, { Uid = uid, PetId = petId })
	if #profile.EquippedPets < ProfileService.petSlots(player) then
		table.insert(profile.EquippedPets, uid)
	end
	push(player)

	local def = petById[petId]
	local rarity = Pets.Rarities[def.Rarity]
	return {
		ok = true,
		pet = { Uid = uid, PetId = petId },
		msg = string.format("%s (%s) : +%d %%", def.Name, rarity.Name, math.floor(def.Bonus * 100 + 0.5)),
	}
end

-- Donne un compagnon gratuitement (butin de patron). Retourne false si l'inventaire est plein.
function PetService.grant(player: Player, petId: string): boolean
	local profile = ProfileService.get(player)
	if not profile or not ProfileService.canMutate(player) or not petById[petId] then
		return false
	end
	if #profile.Pets >= Pets.InventorySize then
		return false
	end
	local uid = profile.NextPetUid
	profile.NextPetUid += 1
	table.insert(profile.Pets, { Uid = uid, PetId = petId })
	if #profile.EquippedPets < ProfileService.petSlots(player) then
		table.insert(profile.EquippedPets, uid)
	end
	push(player)
	return true
end

function PetService.toggleEquip(player: Player, uid: number)
	local profile, err = guard(player)
	if not profile then
		return err
	end
	if not findPet(profile, uid) then
		return { ok = false, msg = "Compagnon introuvable." }
	end
	local index = table.find(profile.EquippedPets, uid)
	if index then
		table.remove(profile.EquippedPets, index)
	else
		if #profile.EquippedPets >= ProfileService.petSlots(player) then
			return { ok = false, msg = "Tous les emplacements sont pris (la renaissance en débloque)." }
		end
		table.insert(profile.EquippedPets, uid)
	end
	push(player)
	return { ok = true }
end

function PetService.unequipAll(player: Player)
	local profile, err = guard(player)
	if not profile then
		return err
	end
	table.clear(profile.EquippedPets)
	push(player)
	return { ok = true, msg = "Compagnons retirés." }
end

function PetService.equipBest(player: Player)
	local profile, err = guard(player)
	if not profile then
		return err
	end
	profile.EquippedPets = Formulas.bestPets(Pets, profile.Pets, ProfileService.petSlots(player))
	push(player)
	return { ok = true, msg = "Meilleurs compagnons équipés." }
end

function PetService.release(player: Player, uid: number)
	local profile, err = guard(player)
	if not profile then
		return err
	end
	local _, index = findPet(profile, uid)
	if not index then
		return { ok = false, msg = "Compagnon introuvable." }
	end
	table.remove(profile.Pets, index)
	local equippedIndex = table.find(profile.EquippedPets, uid)
	if equippedIndex then
		table.remove(profile.EquippedPets, equippedIndex)
	end
	push(player)
	return { ok = true, msg = "Compagnon relâché." }
end

function PetService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Eggs"
	folder.Parent = PlotService.world()
	for _, egg in Pets.Eggs do
		local pos = Vector3.new(egg.Position[1], 1, egg.Position[2])
		local base = CFrame.lookAt(pos, Vector3.new(0, 1, 0)) -- face au centre du hub
		local model, plinth = Models.eggStand(base, toColor(egg.Color))
		model.Name = egg.Id
		model.Parent = folder
		PlotService.makeBillboard(
			plinth,
			string.format("%s\n%s or", egg.Name, Formulas.formatNumber(egg.Cost)),
			7,
			Vector2.new(9, 2.4)
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Voir l'œuf"
		prompt.ObjectText = egg.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("EggId", egg.Id) -- le client ouvre la fenêtre (probabilités + achat)
		prompt.Parent = plinth
	end
end

function PetService.start()
	ProfileService.onLoaded(function(player)
		push(player)
	end)
end

return PetService
