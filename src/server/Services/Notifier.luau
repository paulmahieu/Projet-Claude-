--[[
	Notifications (toasts) vers le client. kind : "info" | "success" | "error" | "reward"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Notifier = {}

function Notifier.send(player: Player, text: string, kind: string?)
	if player.Parent then
		NotifyRemote:FireClient(player, text, kind or "info")
	end
end

return Notifier
