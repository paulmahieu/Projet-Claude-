--[[
	FarmUi : colore localement les bordures des zones du Champ des champions selon tes
	renaissances (vert = accessible, rouge = verrouillée ; zone royale en or). Affichage seul :
	l'accès réel est vérifié par le serveur.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Farm = require(Shared.Config.Farm)

local FarmUi = {}

local player = Players.LocalPlayer
local OPEN = Color3.fromRGB(90, 230, 120)
local LOCKED = Color3.fromRGB(230, 70, 60)
local ROYAL = Color3.fromRGB(255, 205, 80)

function FarmUi.start()
	local function geometry(): Instance?
		local world = workspace:FindFirstChild("World")
		local farm = world and world:FindFirstChild("Farm")
		return farm and farm:FindFirstChild("Geometry")
	end

	local function refresh()
		local folder = geometry()
		if not folder then
			return
		end
		local rebirths = player:GetAttribute("Rebirths") or 0
		for _, part in folder:GetChildren() do
			local index = part:GetAttribute("ZoneIndex")
			local zone = index and Farm.Zones[index]
			if zone and part:IsA("BasePart") then
				part.Color = if zone.PassKey then ROYAL elseif rebirths >= zone.Rebirths then OPEN else LOCKED
			end
		end
	end

	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	task.spawn(function()
		local world = workspace:WaitForChild("World", 30)
		if world then
			world:WaitForChild("Farm", 30)
			task.wait(1) -- laisse le temps à la géométrie de se répliquer
		end
		refresh()
	end)
end

return FarmUi
