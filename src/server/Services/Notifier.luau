--[[
	Envoi de notifications (toasts) au client.
	kind : "info" | "success" | "error" | "reward"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Notifier = {}

function Notifier.send(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

return Notifier
