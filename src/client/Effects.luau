--[[
	Effets de retour visuel côté client (affichage uniquement, aucune logique de jeu) :
	- chiffres flottants au-dessus du personnage quand l'XP et l'or augmentent ;
	- annonce « NIVEAU X ! » à chaque montée de niveau.
	Les valeurs viennent des attributs envoyés par le serveur : le client ne calcule rien.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)

local Effects = {}

local player = Players.LocalPlayer
local MAX_ACTIVE = 8 -- limite le nombre d'étiquettes simultanées (performances mobiles)
local active = 0

local COLORS = {
	Xp = Color3.fromRGB(110, 190, 255),
	Gold = Color3.fromRGB(255, 212, 70),
	Level = Color3.fromRGB(255, 240, 150),
}

local function head(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Head") :: BasePart?
end

-- Texte qui monte et s'efface au-dessus de la tête.
function Effects.float(text: string, color: Color3, big: boolean?)
	local adornee = head()
	if not adornee or active >= MAX_ACTIVE then
		return
	end
	active += 1
	local gui = Instance.new("BillboardGui")
	gui.Size = if big then UDim2.fromOffset(320, 70) else UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui

	local rise = if big then 3.5 else 2.5
	local duration = if big then 1.8 else 1.1
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, rise, 0) }):Play()
	local fade = TweenService:Create(
		label,
		TweenInfo.new(duration * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, duration * 0.5),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	fade:Play()
	fade.Completed:Connect(function()
		gui:Destroy()
		active -= 1
	end)
end

-- Texte flottant à une position du monde (ex. dégâts infligés au boss).
function Effects.floatAt(position: Vector3, text: string, color: Color3)
	if active >= MAX_ACTIVE * 2 then
		return
	end
	active += 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain -- parent d'abord : WorldPosition est relative au parent
	attachment.WorldPosition = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = attachment
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	local fade = TweenService:Create(
		label,
		TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.5),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	fade:Play()
	fade.Completed:Connect(function()
		gui:Destroy()
		attachment:Destroy()
		active -= 1
	end)
end

function Effects.start()
	local lastXp = player:GetAttribute("TrainXp")
	local lastGold = player:GetAttribute("Gold")
	local lastLevel = player:GetAttribute("Level")
	local xpCarry = 0

	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = player:GetAttribute("Level") or 1
		if lastLevel and level > lastLevel then
			Effects.float(string.format("NIVEAU %d !", level), COLORS.Level, true)
		end
		lastLevel = level
	end)

	-- Pendant l'entraînement : « +4 XP » et « +1 or » à chaque gain.
	player:GetAttributeChangedSignal("TrainXp"):Connect(function()
		local xp = player:GetAttribute("TrainXp") or 0
		if lastXp and player:GetAttribute("Training") then
			local delta = xp - lastXp
			if delta > 0 then
				xpCarry += delta
				if xpCarry >= 1 then
					Effects.float("+" .. Formulas.formatNumber(xpCarry) .. " XP", COLORS.Xp)
					xpCarry = 0
				end
			end
		end
		lastXp = xp
	end)

	player:GetAttributeChangedSignal("Gold"):Connect(function()
		local gold = player:GetAttribute("Gold") or 0
		if lastGold and gold > lastGold and player:GetAttribute("Training") then
			Effects.float("+" .. Formulas.formatNumber(gold - lastGold) .. " or", COLORS.Gold)
		end
		lastGold = gold
	end)
end

return Effects
