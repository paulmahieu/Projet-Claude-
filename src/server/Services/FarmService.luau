--[[
	FarmService : Champ des champions (zones de farm à multiplicateur, inspirées des simulateurs).
	- Dans une zone accessible, le joueur frappe automatiquement les mannequins : XP et or
	  chaque seconde = base x multiplicateur de zone x Concentration x renaissances x compagnons.
	- Accès : nombre de renaissances requis ; zone royale : pass (vérifié côté serveur).
	- Incompatible avec les tapis du bastion (le joueur est ailleurs) ; aucune entrée simulée.
	- Hors ligne : le meilleur rendement durable (zone ou tapis) sert de base au calcul.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Farm = require(Shared.Config.Farm)
local Training = require(Shared.Config.Training)
local Economy = require(Shared.Config.Economy)

local ProfileService = require(script.Parent.ProfileService)
local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local MonetizationService = require(script.Parent.MonetizationService)
local Notifier = require(script.Parent.Notifier)
local Models = require(script.Parent.Parent.Art.Models)

local FarmService = {}

local origin = CFrame.new(Farm.Origin[1], Farm.Origin[2], Farm.Origin[3])
local zones = {}
local lockedNotified: { [Player]: number } = {}

local function ownsPassFor(player: Player)
	return function(key: string): boolean
		return MonetizationService.ownsPass(player, key)
	end
end

local function rates(player: Player, zoneMult: number)
	local profile = ProfileService.get(player)
	if not profile then
		return { Xp = 0, Gold = 0 }
	end
	return Formulas.zoneRates(
		zoneMult,
		ProfileService.treeStat(player, "TrainingMult"),
		1,
		Training,
		ProfileService.personalMultiplier(player)
	)
end

-- Zone (index) contenant une position, ou 0.
local function zoneAt(position: Vector3): number
	local rel = origin:PointToObjectSpace(position)
	if math.abs(rel.Y) > 12 then
		return 0
	end
	for i in Farm.Zones do
		local x, z = Formulas.zoneCenter(Farm, i)
		if math.abs(rel.X - x) <= Farm.ZoneSize / 2 and math.abs(rel.Z + z) <= Farm.ZoneSize / 2 then
			return i
		end
	end
	return 0
end

local function shake(part: BasePart)
	local rest = part:GetAttribute("Rest") :: CFrame?
	if not rest then
		rest = part.CFrame
		part:SetAttribute("Rest", rest)
	end
	part.CFrame = (rest :: CFrame) * CFrame.Angles(math.rad(math.random(-14, 14)), 0, math.rad(math.random(-14, 14)))
	TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), { CFrame = rest }):Play()
end

local function tick(player: Player, dt: number)
	local profile = ProfileService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local index = if root and humanoid and humanoid.Health > 0 then zoneAt(root.Position) else 0
	local zone = Farm.Zones[index]
	local unlocked = zone ~= nil
		and profile ~= nil
		and Formulas.zoneUnlocked(zone, profile.Rebirths, ownsPassFor(player))

	local shown = if unlocked then zone.Mult else 0
	if player:GetAttribute("FarmZone") ~= shown then
		player:SetAttribute("FarmZone", shown)
	end
	if zone and not unlocked then
		local now = os.clock()
		if (lockedNotified[player] or 0) + 6 < now then
			lockedNotified[player] = now
			Notifier.send(
				player,
				if zone.PassKey
					then "Zone royale : réservée au pass « Zone royale d'entraînement »."
					else string.format(
						"Zone x%s : %d renaissance(s) requise(s).",
						tostring(zone.Mult),
						zone.Rebirths
					),
				"error"
			)
		end
		return
	end
	if not unlocked or not profile or not ProfileService.canMutate(player) then
		return
	end

	local r = rates(player, zone.Mult)
	local level, xp, gained = Formulas.addXp(profile.Level, profile.TrainXp, r.Xp * dt, Training)
	profile.Level, profile.TrainXp = level, xp
	profile.Gold = Formulas.clamp(profile.Gold + r.Gold * dt, Economy.GoldCap)
	if gained > 0 then
		Notifier.send(player, string.format("Niveau %d ! Puissance %d", level, ProfileService.power(player)), "success")
	end
	ProfileService.sync(player)
	local dummies = zones[index] and zones[index].Dummies
	if dummies then
		shake(dummies[math.random(1, #dummies)])
	end
end

function FarmService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Farm"
	folder.Parent = PlotService.world()
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = folder
	zones = Models.farmIsland(origin, Farm, Formulas.zoneCenter, geometry)
	for i, zone in Farm.Zones do
		local label = PlotService.makeBillboard(
			zones[i].Dummies[2],
			if zone.Royal
				then "ZONE ROYALE\nx" .. tostring(zone.Mult)
				else string.format("x%s\nRenaissance %d", tostring(zone.Mult), zone.Rebirths),
			5,
			Vector2.new(8, 2.6)
		)
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = if zone.Royal then Color3.fromRGB(255, 215, 90) else Color3.fromRGB(150, 230, 255)
	end

	-- Portail au hub et portail de retour sur l'île.
	local portalPos = Vector3.new(Farm.Portal[1], 1, Farm.Portal[2])
	local portalModel, veil =
		Models.portal(CFrame.lookAt(portalPos, Vector3.new(0, 1, 0)), Color3.fromRGB(110, 210, 255))
	portalModel.Name = "Portal_Farm"
	portalModel.Parent = folder
	PlotService.makeBillboard(veil, "Champ des champions\nZones de farm x1 à x30", 8, Vector2.new(12, 3))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Aller au Champ"
	prompt.ObjectText = "Champ des champions"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.Parent = veil
	prompt.Triggered:Connect(function(player)
		if player.Character then
			player.Character:PivotTo(origin * CFrame.new(0, 4, 14) * CFrame.Angles(0, 0, 0))
		end
	end)

	local backModel, backVeil =
		Models.portal(origin * CFrame.new(0, 0, 18) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(110, 210, 255))
	backModel.Name = "ReturnPortal"
	backModel.Parent = folder
	PlotService.makeBillboard(backVeil, "Retour au bastion", 7, Vector2.new(10, 1.6))
	local backPrompt = Instance.new("ProximityPrompt")
	backPrompt.ActionText = "Retour au bastion"
	backPrompt.HoldDuration = 0.3
	backPrompt.RequiresLineOfSight = false
	backPrompt.Parent = backVeil
	backPrompt.Triggered:Connect(function(player)
		local group = GroupService.groupOf(player)
		if group and PlotService.get(group.Id) then
			PlotService.teleportToPlot(player, group.Id)
		elseif player.Character then
			player.Character:PivotTo(CFrame.new(0, 5, 0))
		end
	end)

	-- Hors ligne : le meilleur rendement durable entre tapis du bastion et zones accessibles.
	-- (Enregistré après celui de TrainingService : Main initialise FarmService ensuite.)
	ProfileService.beforeSave(function(player, profile)
		local best = Formulas.bestZoneMult(Farm, profile.Rebirths, ownsPassFor(player))
		if best > 0 then
			local zoneRate = rates(player, best)
			if zoneRate.Xp > (profile.AfkRate.Xp or 0) then
				profile.AfkRate = zoneRate
			end
		end
	end)
end

function FarmService.start()
	Players.PlayerRemoving:Connect(function(player)
		lockedNotified[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = math.min(now - last, 5)
			last = now
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tick, player, dt)
				if not ok then
					warn("[FarmService] " .. tostring(err))
				end
			end
		end
	end)
end

return FarmService
