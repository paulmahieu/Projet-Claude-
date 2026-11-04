--[[
	DiagnosticsUi (Studio uniquement) : affiche à l'écran les erreurs du serveur (attribut
	ReplicatedStorage « ServerErrors ») et du client, pour qu'elles soient faciles à signaler
	par une simple capture d'écran. Invisible dans le jeu publié.
]]

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent.Ui)

local DiagnosticsUi = {}

function DiagnosticsUi.start(gui: ScreenGui)
	if not RunService:IsStudio() then
		return
	end
	local clientErrors: { string } = {}

	local panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(0.55, 0, 0, 170),
		BackgroundColor3 = Color3.fromRGB(70, 10, 10),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 50,
		Parent = gui,
	}, { Ui.corner(8), Ui.padding(8) })
	local text = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(255, 225, 220),
		RichText = false,
		ZIndex = 51,
		Parent = panel,
	})

	local function refresh()
		local server = tostring(ReplicatedStorage:GetAttribute("ServerErrors") or "")
		local lines = {}
		if server ~= "" then
			table.insert(lines, "ERREURS SERVEUR (capture d'écran à envoyer) :")
			table.insert(lines, server)
		end
		if #clientErrors > 0 then
			table.insert(lines, "ERREURS CLIENT :")
			table.insert(lines, table.concat(clientErrors, "\n"))
		end
		text.Text = table.concat(lines, "\n")
		panel.Visible = #lines > 0
	end

	ReplicatedStorage:GetAttributeChangedSignal("ServerErrors"):Connect(refresh)
	LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageError then
			table.insert(clientErrors, string.sub(message, 1, 200))
			while #clientErrors > 4 do
				table.remove(clientErrors, 1)
			end
			refresh()
		end
	end)
	refresh()
end

return DiagnosticsUi
