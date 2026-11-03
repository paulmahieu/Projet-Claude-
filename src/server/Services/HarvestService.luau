--[[
	HarvestService : bosquets de récolte (bois, pierre) entre les parcelles.
	Les matériaux vont directement dans la réserve du groupe du récolteur (cahier §3).
	Validation serveur : membre actif, autorité d'écriture, distance, délai par joueur,
	ressource disponible. Les ressources réapparaissent après un délai.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Harvest = require(Shared.Config.Harvest)
local Game = require(Shared.Config.Game)
local Economy = require(Shared.Config.Economy)
local Materials = require(Shared.Config.Materials)
local Structures = require(Shared.Config.Structures)
local Texts = require(Shared.Config.Texts)

local GroupService = require(script.Parent.GroupService)
local ProfileService = require(script.Parent.ProfileService)
local PlotService = require(script.Parent.PlotService)
local Notifier = require(script.Parent.Notifier)

local HarvestService = {}

local lastHarvest: { [Player]: number } = {}
local beforeHarvestCallbacks = {}

local materialName = {}
for _, mat in Materials do
	materialName[mat.Id] = mat.Name
end

-- fn(player) : appelé avant une récolte (ex. arrêter l'entraînement, action incompatible).
function HarvestService.beforeHarvest(fn)
	table.insert(beforeHarvestCallbacks, fn)
end

local function setAvailable(node: Model, available: boolean)
	node:SetAttribute("Available", available)
	for _, part in node:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if available then 0 else 0.75
		elseif part:IsA("ProximityPrompt") then
			part.Enabled = available
		end
	end
end

local function onHarvest(player: Player, node: Model, kind)
	if not node:GetAttribute("Available") then
		Notifier.send(player, Texts.NodeDepleted, "info")
		return
	end
	local now = os.clock()
	if (lastHarvest[player] or 0) + Harvest.PlayerCooldown > now then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - node:GetPivot().Position).Magnitude > Harvest.MaxDistance then
		return
	end
	local profile = ProfileService.get(player)
	local group, err = GroupService.authorize(player, "Build")
	if not profile or not group then
		Notifier.send(player, err or Texts.Loading, "error")
		return
	end
	lastHarvest[player] = now

	for _, fn in beforeHarvestCallbacks do
		fn(player)
	end

	local amount = kind.Amount + Formulas.harvestBonus(Structures, group.Data.Structures, kind.Material)
	local materials = group.Data.Materials
	materials[kind.Material] = Formulas.clamp((materials[kind.Material] or 0) + amount, Economy.MaterialCap)
	profile.Stats.Harvests += 1

	setAvailable(node, false)
	task.delay(kind.RespawnSeconds, setAvailable, node, true)

	GroupService.markChanged(group)
	Notifier.send(player, string.format(Texts.Harvested, amount, materialName[kind.Material]), "success")
end

local function buildNode(kindName: string, cf: CFrame, parent: Instance)
	local kind = Harvest.Nodes[kindName]
	local node = Instance.new("Model")
	node.Name = kindName

	if kindName == "Tree" then
		PlotService.makePart({
			Name = "Trunk",
			Size = Vector3.new(1.6, 8, 1.6),
			CFrame = cf * CFrame.new(0, 4, 0),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(105, 70, 40),
			Parent = node,
		})
		PlotService.makePart({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 7, 7),
			CFrame = cf * CFrame.new(0, 9.5, 0),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(60, 130, 60),
			Parent = node,
		})
	else
		PlotService.makePart({
			Name = "Stone",
			Size = Vector3.new(5, 3.5, 4.5),
			CFrame = cf * CFrame.new(0, 1.75, 0) * CFrame.Angles(0, math.rad(25), math.rad(8)),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(130, 130, 135),
			Parent = node,
		})
	end
	node.PrimaryPart = node:FindFirstChildWhichIsA("BasePart")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Récolter"
	prompt.ObjectText = kind.Label
	prompt.HoldDuration = kind.HoldDuration
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = node.PrimaryPart
	prompt.Triggered:Connect(function(player)
		onHarvest(player, node, kind)
	end)

	node.Parent = parent
	setAvailable(node, true)
end

function HarvestService.init()
	local folder = Instance.new("Folder")
	folder.Name = "HarvestNodes"
	folder.Parent = PlotService.world()

	-- Un bosquet entre chaque paire de parcelles.
	for i = 1, Game.PlotCount do
		local angle = (i - 0.5) / Game.PlotCount * math.pi * 2
		local center = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Harvest.RingRadius
		local base = CFrame.lookAt(center, Vector3.zero)
		for _, entry in Harvest.Grove do
			buildNode(entry[1], base * CFrame.new(entry[2], 0, -entry[3]), folder)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastHarvest[player] = nil
	end)
end

return HarvestService
