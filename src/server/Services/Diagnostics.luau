--[[
	Diagnostics : remontée des erreurs et filets de sécurité.
	- report() : journalise une erreur de démarrage ; dans Studio, les erreurs (et toutes les
	  erreurs de script du serveur) sont publiées dans l'attribut ReplicatedStorage
	  « ServerErrors », affiché par le client dans un panneau rouge.
	- Filet anti-vide : un personnage tombé sous le monde est replacé au point d'accueil.
	- Le sol et le point d'apparition de secours (fichier du projet) sont retirés une fois
	  le vrai monde construit.
	N'expose rien dans le jeu publié (Studio uniquement).
]]

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Diagnostics = {}

local errors: { string } = {}
local MAX = 8

local function publish()
	if RunService:IsStudio() then
		ReplicatedStorage:SetAttribute("ServerErrors", table.concat(errors, "\n"))
	end
end

local function push(text: string)
	table.insert(errors, text)
	while #errors > MAX do
		table.remove(errors, 1)
	end
	publish()
end

function Diagnostics.report(label: string, err)
	local text = string.format("[%s] %s", label, tostring(err))
	warn("[Diagnostics] " .. text)
	push(text)
end

function Diagnostics.count(): number
	return #errors
end

function Diagnostics.init()
	-- Toutes les erreurs de scripts serveur ultérieures (boucles, événements) sont aussi remontées.
	LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageError then
			push(string.sub(message, 1, 300))
		end
	end)
end

-- Replace les personnages tombés sous le monde (sécurité contre le vide).
-- Zones situées sous la carte où le joueur a le droit d'être (salles mystiques).
local safeZones: { { CFrame: CFrame, Half: Vector3 } } = {}

function Diagnostics.addSafeZone(cf: CFrame, size: Vector3)
	table.insert(safeZones, { CFrame = cf, Half = size / 2 })
end

local function inSafeZone(position: Vector3): boolean
	for _, zone in safeZones do
		local rel = zone.CFrame:PointToObjectSpace(position)
		if math.abs(rel.X) <= zone.Half.X and math.abs(rel.Y) <= zone.Half.Y and math.abs(rel.Z) <= zone.Half.Z then
			return true
		end
	end
	return false
end

function Diagnostics.startVoidRescue()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and root.Position.Y < -40 and not inSafeZone(root.Position) then
					root.AssemblyLinearVelocity = Vector3.zero
					character:PivotTo(CFrame.new(0, 6, 0))
				end
			end
		end
	end)
end

return Diagnostics
