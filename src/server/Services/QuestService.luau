--[[
	QuestService : missions d'introduction.
	- Personnelles : la mission en cours est vérifiée toutes les 2 s ; une fois remplie, elle
	  est créditée UNE fois ("quest:<Id>" dans le journal du profil) et la suivante commence.
	- Collectives : vérifiées pour chaque groupe chargé ; récompense en matériaux du groupe,
	  UNE fois par groupe ("groupquest:<Id>" dans le journal du groupe, sur le serveur qui
	  détient l'autorité : deux validations simultanées sont impossibles).
	L'état est publié en attributs (QuestIndex, QuestProgress, GroupQuestsDone) pour le HUD.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Quests = require(Shared.Config.Quests)
local Structures = require(Shared.Config.Structures)
local Materials = require(Shared.Config.Materials)
local Economy = require(Shared.Config.Economy)
local OpLog = require(Shared.OpLog)

local ProfileService = require(script.Parent.ProfileService)
local GroupService = require(script.Parent.GroupService)
local RewardService = require(script.Parent.RewardService)
local Notifier = require(script.Parent.Notifier)
local Membership = require(Shared.Membership)

local QuestService = {}

local materialName = {}
for _, mat in Materials do
	materialName[mat.Id] = mat.Name
end

local function personalStats(player: Player, profile)
	local group = GroupService.groupOf(player)
	local kills = 0
	for _, n in profile.BossKills do
		kills += n
	end
	local nodes = 0
	for _ in profile.Tree do
		nodes += 1
	end
	return {
		Harvests = profile.Stats.Harvests,
		TrainSeconds = math.floor(profile.Stats.TrainSeconds or 0),
		TreeNodes = nodes,
		PetsOwned = #profile.Pets,
		PetsEquipped = #profile.EquippedPets,
		StreetKills = profile.Street.Kills,
		StreetBest = profile.Street.Best,
		BestLevel = math.max(profile.BestLevel or 1, profile.Level),
		Rebirths = profile.Rebirths,
		BossKills = kills,
		Structures = if group then group.Data.Structures else {},
	}
end

local function groupStats(group)
	return {
		BastionLevel = Formulas.bastionLevel(Structures, group.Data.Structures),
		Members = Membership.activeCount(group.Data),
		Structures = group.Data.Structures,
	}
end

local function tickPlayer(player: Player)
	local profile = ProfileService.get(player)
	if not profile or not ProfileService.canMutate(player) then
		return
	end
	local stats = personalStats(player, profile)
	-- Plusieurs missions peuvent être remplies d'un coup (joueur déjà avancé).
	while profile.Quest <= #Quests.Personal do
		local quest = Quests.Personal[profile.Quest]
		local current, done = Formulas.questProgress(quest, stats)
		if not done then
			player:SetAttribute("QuestIndex", profile.Quest)
			player:SetAttribute("QuestProgress", current)
			return
		end
		local opId = "quest:" .. quest.Id
		if not OpLog.has(profile.Ops, opId) then
			RewardService.grant(player, profile, quest.Reward)
			OpLog.add(profile.Ops, opId, Economy.Save.MaxOps)
			ProfileService.sync(player)
			Notifier.send(player, "Mission accomplie : " .. quest.Text .. " !", "reward")
		end
		profile.Quest += 1
	end
	player:SetAttribute("QuestIndex", profile.Quest) -- > nombre de missions : toutes terminées
	player:SetAttribute("QuestProgress", 0)
end

local function tickGroup(group)
	if not GroupService.canMutate(group) then
		return
	end
	local stats = groupStats(group)
	local done = {}
	for _, quest in Quests.Group do
		local opId = "groupquest:" .. quest.Id
		local _, complete = Formulas.questProgress(quest, stats)
		if complete and not OpLog.has(group.Data.Ops, opId) then
			local parts = {}
			for matId, amount in quest.Reward do
				local mats = group.Data.Materials
				mats[matId] = Formulas.clamp((mats[matId] or 0) + amount, Economy.MaterialCap)
				table.insert(parts, string.format("+%d %s", amount, materialName[matId] or matId))
			end
			OpLog.add(group.Data.Ops, opId, Economy.Save.MaxOps)
			GroupService.markChanged(group)
			for member in group.Online do
				Notifier.send(
					member,
					"Mission de groupe : " .. quest.Text .. " ! " .. table.concat(parts, ", "),
					"reward"
				)
			end
		end
		if OpLog.has(group.Data.Ops, opId) then
			table.insert(done, quest.Id)
		end
	end
	for member in group.Online do
		member:SetAttribute("GroupQuestsDone", table.concat(done, ","))
	end
end

function QuestService.start()
	task.spawn(function()
		while true do
			task.wait(2)
			local seen = {}
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tickPlayer, player)
				if not ok then
					warn("[QuestService] " .. tostring(err))
				end
				local group = GroupService.groupOf(player)
				if group and not seen[group.Id] then
					seen[group.Id] = true
					local okGroup, errGroup = pcall(tickGroup, group)
					if not okGroup then
						warn("[QuestService] " .. tostring(errGroup))
					end
				end
			end
		end
	end)
end

return QuestService
