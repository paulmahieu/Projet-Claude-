--[[
	PetFollowers : affiche les compagnons équipés de TOUS les joueurs (attribut « EquippedPets »
	répliqué par le serveur). Pur affichage local : le bonus est calculé par le serveur.
	Optimisation mobile : pas de mise à jour au-delà de 160 studs de la caméra.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pets = require(Shared.Config.Pets)
local PetModels = require(Shared.PetModels)

local PetFollowers = {}

local petById = {}
for _, def in Pets.List do
	petById[def.Id] = def
end

local followers: { [Player]: { Model } } = {}
local folder = Instance.new("Folder")
folder.Name = "PetFollowers"
folder.Parent = workspace

local function clear(player: Player)
	for _, model in followers[player] or {} do
		model:Destroy()
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local list = {}
	local ids = tostring(player:GetAttribute("EquippedPets") or "")
	for id in string.gmatch(ids, "[^,]+") do
		local def = petById[id]
		if def then
			local rarity = Pets.Rarities[def.Rarity]
			local model = PetModels.build(def, Color3.fromRGB(rarity.Color[1], rarity.Color[2], rarity.Color[3]))
			model.Parent = folder
			table.insert(list, model)
		end
	end
	followers[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

-- Emplacements derrière le joueur : arrière gauche, arrière droite, arrière centre.
local SLOTS = { Vector3.new(-3, 0, 3), Vector3.new(3, 0, 3), Vector3.new(0, 0, 5) }

function PetFollowers.start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local t = os.clock()
		for player, list in followers do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - camera.CFrame.Position).Magnitude < 160 then
				for i, model in list do
					local offset = SLOTS[i] or SLOTS[#SLOTS]
					local bob = math.sin(t * 3 + i) * 0.3
					local target = root.CFrame * CFrame.new(offset + Vector3.new(0, bob - 0.5, 0))
					local current = model:GetPivot()
					local alpha = math.clamp(dt * 8, 0, 1)
					local pos = current.Position:Lerp(target.Position, alpha)
					model:PivotTo(CFrame.lookAt(pos, pos + root.CFrame.LookVector))
				end
			end
		end
	end)
end

return PetFollowers
