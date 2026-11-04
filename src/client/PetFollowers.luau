--[[
	PetFollowers : affiche les compagnons équipés de TOUS les joueurs (attribut « EquippedPets »
	répliqué par le serveur). Pur affichage local : le bonus est calculé par le serveur.

	Les compagnons MARCHENT au sol à côté de leur joueur (pas de vol) :
	- position au sol trouvée par un rayon vers le bas (sols, escaliers, pentes) ;
	- emplacements à gauche et à droite du joueur, puis derrière ;
	- petits pas quand ils avancent, immobiles quand le joueur s'arrête ;
	- ils regardent dans leur direction de marche, puis dans celle du joueur à l'arrêt.
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

type Follower = {
	Model: Model,
	Bottom: number, -- distance entre le pivot et le dessous du modèle
	Position: Vector3, -- position au sol courante (dessous du compagnon)
	Facing: Vector3,
	Stride: number, -- phase de la marche
}

local followers: { [Player]: { Follower } } = {}
local folder = Instance.new("Folder")
folder.Name = "PetFollowers"
folder.Parent = workspace

-- Emplacements autour du joueur (repère du joueur : X à droite, Z vers l'arrière).
local SLOTS = {
	Vector3.new(-3.4, 0, 0.6), -- à gauche
	Vector3.new(3.4, 0, 0.6), -- à droite
	Vector3.new(-2.4, 0, 4.2), -- derrière à gauche
	Vector3.new(2.4, 0, 4.2), -- derrière à droite
	Vector3.new(0, 0, 5.4), -- derrière
	Vector3.new(-4.6, 0, 3.6),
	Vector3.new(4.6, 0, 3.6),
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function refreshFilter()
	local ignore = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function clear(player: Player)
	for _, f in followers[player] or {} do
		f.Model:Destroy()
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
			-- Dessous du modèle (construit autour de l'origine) : sert à le poser au sol.
			local box, size = model:GetBoundingBox()
			local bottom = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
			model.Parent = folder
			table.insert(list, {
				Model = model,
				Bottom = bottom,
				Position = Vector3.zero,
				Facing = Vector3.new(0, 0, -1),
				Stride = math.random() * 6,
			})
		end
	end
	followers[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	player.CharacterAdded:Connect(function()
		task.defer(refreshFilter)
	end)
	rebuild(player)
end

-- Hauteur du sol sous un point (nil si aucun sol proche).
local function groundAt(position: Vector3): Vector3?
	local result = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -16, 0), rayParams)
	return result and result.Position or nil
end

function PetFollowers.start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		task.defer(refreshFilter)
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	refreshFilter()

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		for player, list in followers do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and (root.Position - camera.CFrame.Position).Magnitude < 160 then
				-- Pieds du joueur : repère pour le sol si aucun rayon ne touche.
				local feetY = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
				local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
				flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
				local basis = CFrame.lookAt(Vector3.zero, flatLook)
				for i, f in list do
					local offset = basis:VectorToWorldSpace(SLOTS[i] or SLOTS[#SLOTS])
					local goal = Vector3.new(root.Position.X, feetY, root.Position.Z) + offset
					local hit = groundAt(goal)
					local goalY = if hit and math.abs(hit.Y - feetY) < 6 then hit.Y else feetY
					goal = Vector3.new(goal.X, goalY, goal.Z)

					-- Téléportation du joueur : le compagnon suit immédiatement.
					if (f.Position - goal).Magnitude > 40 then
						f.Position = goal
					end
					local flat = Vector3.new(goal.X - f.Position.X, 0, goal.Z - f.Position.Z)
					local distance = flat.Magnitude
					local moving = distance > 0.35
					local speed = math.max(humanoid.WalkSpeed, 12) * (if distance > 6 then 1.6 else 1)
					if moving then
						local step = math.min(distance, speed * dt)
						local nextPos = f.Position + flat.Unit * step
						f.Facing = f.Facing:Lerp(flat.Unit, math.clamp(dt * 10, 0, 1))
						f.Position = Vector3.new(nextPos.X, f.Position.Y, nextPos.Z)
						f.Stride += dt * 14
					else
						f.Facing = f.Facing:Lerp(flatLook, math.clamp(dt * 4, 0, 1))
					end
					-- Hauteur : suit le sol en douceur (marches, pentes).
					local floorHere = groundAt(f.Position)
					local targetY = if floorHere and math.abs(floorHere.Y - goalY) < 6 then floorHere.Y else goalY
					f.Position = Vector3.new(
						f.Position.X,
						f.Position.Y + (targetY - f.Position.Y) * math.clamp(dt * 12, 0, 1),
						f.Position.Z
					)

					-- Petits pas : léger rebond et balancement seulement en marchant.
					local hop = if moving then math.abs(math.sin(f.Stride)) * 0.22 else 0
					local sway = if moving then math.sin(f.Stride) * 0.06 else 0
					local facing = if f.Facing.Magnitude > 0.01 then f.Facing.Unit else flatLook
					local base = Vector3.new(f.Position.X, f.Position.Y + f.Bottom + hop, f.Position.Z)
					f.Model:PivotTo(CFrame.lookAt(base, base + facing) * CFrame.Angles(0, 0, sway))
				end
			end
		end
	end)
end

return PetFollowers
