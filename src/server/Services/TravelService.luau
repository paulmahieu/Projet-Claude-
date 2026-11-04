--[[
	TravelService : se rejoindre entre amis et rejoindre le serveur de son bastion (R2).

	Principe : un bastion n'est ouvert que sur UN serveur à la fois (verrou de session). Le hub,
	les œufs, la Rue des boss, les arènes et le Champ des champions sont communs à tous les
	joueurs du serveur.
	- Ami sur ce serveur : « Visiter » amène devant son bastion (on ne peut pas y construire).
	- Ami sur un autre serveur de l'expérience : « Rejoindre » téléporte sur son serveur, puis
	  devant son bastion à l'arrivée.
	- Bastion de son groupe ouvert ailleurs (état « Remote ») : « Rejoindre mon bastion »
	  téléporte sur le serveur qui détient le verrou du bastion.
	La liste des amis en ligne est lue par le client (Player:GetFriendsOnline) ; le serveur
	revérifie l'amitié (IsFriendsWith) avant toute téléportation. Indisponible dans Studio.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local Notifier = require(script.Parent.Notifier)

local TravelService = {}

local VISIT_WAIT = 40 -- secondes d'attente maximale de l'ami/du bastion après l'arrivée

local function teleport(player: Player, jobId: string, data): (boolean, string?)
	if RunService:IsStudio() then
		return false, "Téléportation entre serveurs : uniquement dans le jeu publié (pas dans Studio)."
	end
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = jobId
	options:SetTeleportData(data)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("[TravelService] " .. tostring(err))
		return false, "Téléportation impossible pour l'instant (serveur plein ou fermé). Réessaie."
	end
	return true, nil
end

local function isFriend(player: Player, userId: number): boolean
	local ok, result = pcall(function()
		return player:IsFriendsWith(userId)
	end)
	return ok and result == true
end

-- Amène le joueur devant le bastion d'un autre joueur présent sur ce serveur.
local function visit(player: Player, other: Player): (boolean, string)
	local group = GroupService.groupOf(other)
	if not group or not PlotService.get(group.Id) then
		return false, other.DisplayName .. " n'a pas encore de bastion chargé ici."
	end
	PlotService.teleportToPlot(player, group.Id)
	return true, "Bienvenue au « " .. group.Data.Name .. " » !"
end

function TravelService.joinFriend(player: Player, userId: number, jobId: string?)
	if userId == player.UserId then
		return { ok = false }
	end
	local here = Players:GetPlayerByUserId(userId)
	local mate = GroupService.groupOf(player)
	local sameGroup = here ~= nil and mate ~= nil and GroupService.groupOf(here) == mate
	if not sameGroup and not isFriend(player, userId) then
		return { ok = false, msg = "Tu peux rejoindre seulement tes amis Roblox ou ton groupe." }
	end
	if here then
		local ok, msg = visit(player, here)
		return { ok = ok, msg = msg }
	end
	if not jobId or jobId == game.JobId then
		return { ok = false, msg = "Ton ami n'est plus en jeu." }
	end
	local ok, msg = teleport(player, jobId, { VisitUserId = userId })
	return { ok = ok, msg = msg or "Téléportation vers le serveur de ton ami..." }
end

function TravelService.joinBastionServer(player: Player)
	local jobId = GroupService.remoteJobOf(player)
	if not jobId then
		return { ok = false, msg = "Ton bastion n'est pas ouvert sur un autre serveur." }
	end
	local ok, msg = teleport(player, jobId, { VisitOwnBastion = true })
	return { ok = ok, msg = msg or "Téléportation vers le serveur de ton bastion..." }
end

-- À l'arrivée d'une téléportation : on amène le joueur devant le bastion visé.
local function onArrival(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data = ok and joinData and joinData.TeleportData
	if type(data) ~= "table" then
		return
	end
	local deadline = os.clock() + VISIT_WAIT
	while player.Parent and os.clock() < deadline do
		task.wait(1)
		if player.Character then
			if data.VisitOwnBastion then
				local group = GroupService.groupOf(player)
				if group and PlotService.get(group.Id) then
					PlotService.teleportToPlot(player, group.Id)
					return
				end
			elseif type(data.VisitUserId) == "number" then
				local friend = Players:GetPlayerByUserId(data.VisitUserId)
				if friend and visit(player, friend) then
					Notifier.send(player, "Tu as rejoint " .. friend.DisplayName .. " !", "success")
					return
				end
			else
				return
			end
		end
	end
end

function TravelService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onArrival, player)
	end)
	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		Notifier.send(player, "Téléportation échouée : " .. tostring(message), "error")
	end)
end

return TravelService
