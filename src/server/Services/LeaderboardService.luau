--[[
	LeaderboardService : classements affichés sur des panneaux (Champ des champions).
	- Trophées gagnés (total), Puissance, Meilleure étape de la Rue des boss.
	- Globaux via OrderedDataStore (mis à jour toutes les 2 min, requêtes étalées) ;
	  repli sur les joueurs du serveur si les API ne sont pas disponibles (Studio).
	- Les noms sont résolus côté serveur et mis en cache.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Farm = require(Shared.Config.Farm)

local ProfileService = require(script.Parent.ProfileService)
local PlotService = require(script.Parent.PlotService)
local Store = require(script.Parent.Store)
local Models = require(script.Parent.Parent.Art.Models)

local LeaderboardService = {}

local REFRESH_SECONDS = 120

local boards = {
	{
		Id = "Trophies",
		Title = "TROPHÉES",
		Color = Color3.fromRGB(230, 170, 30),
		Value = function(player)
			local p = ProfileService.get(player)
			return p and p.Stats.TrophiesEarned or 0
		end,
	},
	{
		Id = "Power",
		Title = "PUISSANCE",
		Color = Color3.fromRGB(220, 70, 60),
		Value = function(player)
			return ProfileService.power(player)
		end,
	},
	{
		Id = "Street",
		Title = "RUE DES BOSS",
		Color = Color3.fromRGB(120, 90, 220),
		Value = function(player)
			local p = ProfileService.get(player)
			return p and p.Street.Best or 0
		end,
	},
}

local names: { [number]: string } = {}
local lastPushed: { [string]: { [number]: number } } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else "Joueur"
	return names[userId]
end

local function render(board, entries)
	for i, row in board.Rows do
		local entry = entries[i]
		row.Text = if entry
			then string.format("%d. %s — %s", i, nameOf(entry.UserId), Formulas.formatNumber(entry.Value))
			else ""
	end
end

-- Repli : joueurs présents sur ce serveur.
local function localEntries(board)
	local list = {}
	for _, player in Players:GetPlayers() do
		if ProfileService.get(player) then
			table.insert(list, { UserId = player.UserId, Value = math.floor(board.Value(player)) })
		end
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	return list
end

local function refreshBoard(board)
	if Store.isMemoryMode() or not board.Store then
		render(board, localEntries(board))
		return
	end
	-- Publication des scores des joueurs présents (seulement s'ils ont changé).
	local pushed = lastPushed[board.Id]
	for _, player in Players:GetPlayers() do
		local value = math.floor(board.Value(player))
		if ProfileService.get(player) and value > 0 and pushed[player.UserId] ~= value then
			local ok = pcall(function()
				board.Store:SetAsync(tostring(player.UserId), value)
			end)
			if ok then
				pushed[player.UserId] = value
			end
			task.wait(0.5) -- étale les écritures
		end
	end
	local ok, page = pcall(function()
		return board.Store:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		render(board, localEntries(board))
		return
	end
	local entries = {}
	for _, item in page do
		table.insert(entries, { UserId = tonumber(item.key) or 0, Value = item.value })
	end
	render(board, entries)
end

function LeaderboardService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = PlotService.world()
	local origin = CFrame.new(Farm.Origin[1], Farm.Origin[2], Farm.Origin[3])
	for i, board in boards do
		local pos = origin * CFrame.new((i - 2) * 40, 0, -60)
		local base = CFrame.lookAt(pos.Position, pos.Position + Vector3.new(0, 0, 1)) -- face au parvis
		local _, rows = Models.leaderboard(base, board.Title, board.Color, folder)
		board.Rows = rows
		lastPushed[board.Id] = {}
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("LB_" .. board.Id .. "_v1")
		end)
		board.Store = if ok then store else nil
	end
end

function LeaderboardService.start()
	task.spawn(function()
		task.wait(10) -- laisse les profils se charger
		while true do
			for _, board in boards do
				local ok, err = pcall(refreshBoard, board)
				if not ok then
					warn("[LeaderboardService] " .. tostring(err))
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		names[player.UserId] = nil
	end)
end

return LeaderboardService
