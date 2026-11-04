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
local Models = require(script.Parent.Parent.Art.Models)

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

-- Une ressource récoltée ne garde que sa souche / ses gravats ; elle repousse ensuite.
local function setAvailable(node: Model, available: boolean)
	node:SetAttribute("Available", available)
	for _, inst in node:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Depletable") then
			inst.Transparency = if available then 0 else 1
			inst.CanCollide = available
		elseif inst:IsA("ProximityPrompt") then
			inst.Enabled = available
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

local nodeCount = 0

local function buildNode(kindName: string, cf: CFrame, parent: Instance)
	local kind = Harvest.Nodes[kindName]
	nodeCount += 1
	local node = if kindName == "Tree"
		then Models.tree(cf, (nodeCount % 3) + 1, nodeCount) -- chêne, sapin, bouleau en alternance
		else Models.rock(cf, nodeCount)
	node.Name = kindName

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
