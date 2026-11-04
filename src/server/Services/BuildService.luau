--[[
	BuildService : achats prédéfinis du bastion avec les matériaux COMMUNS (cahier §5).

	Cohérence : la vérification (prérequis, coût) et la modification (débit + construction)
	se font sans aucune attente entre les deux. Le serveur Luau exécutant un seul fil à la
	fois, deux membres qui achètent « en même temps » sont traités l'un après l'autre :
	le second voit « déjà construit » ou un solde insuffisant. Une commande répétée n'est
	donc jamais facturée deux fois. Débit et construction sont dans le même enregistrement
	de groupe : ils sont sauvegardés ensemble.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Structures = require(Shared.Config.Structures)
local Materials = require(Shared.Config.Materials)
local Texts = require(Shared.Config.Texts)

local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local Notifier = require(script.Parent.Notifier)

local BuildService = {}

local structureById = {}
for _, def in Structures do
	structureById[def.Id] = def
end

local lastAttempt: { [Player]: number } = {}

function BuildService.tryBuild(player: Player, structureId: string)
	local now = os.clock()
	if (lastAttempt[player] or 0) + 0.5 > now then
		return
	end
	lastAttempt[player] = now

	local def = structureById[structureId]
	if not def then
		return
	end
	local group, err = GroupService.authorize(player, "Build")
	if not group then
		Notifier.send(player, err or Texts.NoPermission, "error")
		return
	end
	-- La construction doit être sur la parcelle du groupe du joueur (pas celle d'un autre groupe).
	local plot = PlotService.get(group.Id)
	if not plot then
		Notifier.send(player, Texts.NoPlot, "error")
		return
	end
	local pedestal = plot.Pedestals[structureId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pedestal or not root or (root.Position - pedestal.Part.Position).Magnitude > 14 then
		Notifier.send(player, Texts.TooFar, "error")
		return
	end

	local data = group.Data
	local ok, reason = Formulas.canBuild(def, data.Structures, data.Materials)
	if not ok then
		if reason == "Cost" then
			local parts = {}
			for _, m in Formulas.missingMaterials(Materials, data.Materials, def.Cost) do
				table.insert(parts, string.format("%d %s", m.Missing, m.Name))
			end
			Notifier.send(player, string.format(Texts.NotEnough, table.concat(parts, ", ")), "error")
		end
		return
	end

	-- Débit + construction, sans attente entre la vérification et l'écriture.
	for id, amount in def.Cost do
		data.Materials[id] -= amount
	end
	data.Structures[def.Id] = true

	GroupService.markChanged(group, true)
	for member in group.Online do
		Notifier.send(member, string.format(Texts.Built, def.Name), "success")
	end
end

-- Portail du bastion : un membre autorisé à construire l'ouvre ou le ferme.
function BuildService.toggleGate(player: Player, plot)
	local now = os.clock()
	if (lastAttempt[player] or 0) + 0.5 > now then
		return
	end
	lastAttempt[player] = now
	local group, err = GroupService.authorize(player, "Build")
	if not group or plot.GroupId ~= group.Id then
		Notifier.send(player, err or "Seuls les membres du bastion peuvent ouvrir ou fermer ce portail.", "error")
		return
	end
	PlotService.setGate(plot, not plot.DoorsOpen)
end

function BuildService.init()
	PlotService.setGateHandler(BuildService.toggleGate)
	PlotService.setBuildHandler(BuildService.tryBuild)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAttempt[player] = nil
	end)
end

return BuildService
