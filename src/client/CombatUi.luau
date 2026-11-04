--[[
	CombatUi : interface de combat, visible seulement dans une arène (attribut « InArena »).
	- Barre de vie du boss, phase, compte à rebours de réapparition.
	- Compétences : Frappe runique (F / R1 / bouton) et Esquive (Q / L1 / bouton).
	- Chiffres de dégâts envoyés par le serveur (CombatFx).
	Le client ne décide d'aucun dégât : il demande, le serveur valide (recharges, portée).
	L'esquive anticipe le déplacement côté client pour la réactivité (le serveur gère
	l'invulnérabilité).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Combat = require(Shared.Config.Combat)
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request") :: RemoteFunction
local CombatFx = Remotes:WaitForChild("CombatFx") :: RemoteEvent

local CombatUi = {}

local player = Players.LocalPlayer
local C = Ui.Colors

function CombatUi.start(gui: ScreenGui, toast: (string, string?) -> ())
	-- Barre du boss (haut centre, sous le bandeau d'état)
	local bossFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0.6, 0, 0, 54),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(), Ui.create("UISizeConstraint", { MaxSize = Vector2.new(520, 54) }) })
	local bossName = Ui.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 20),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = bossFrame,
	})
	local barBack = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundColor3 = Color3.fromRGB(20, 15, 15),
		Parent = bossFrame,
	}, { Ui.corner(6) })
	local barFill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(210, 50, 50),
		Parent = barBack,
	}, { Ui.corner(6) })
	local barText = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = barBack,
	})

	-- Minuteur des boss (visible hors arène et hors rue), comme « Prochaine bataille dans 9:00 ».
	local bossTimer = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.new(0.6, 0, 0, 24),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 235, 200),
		TextStrokeTransparency = 0.2,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(520, 24) }).Parent = bossTimer

	local function formatTime(seconds: number): string
		seconds = math.max(0, math.floor(seconds))
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end

	-- Boutons de compétences (bas droite, au-dessus du bouton Menu ; grands pour le tactile)
	local skillFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -88),
		Size = UDim2.fromOffset(196, 90),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local readyAt = { Strike = 0, Dodge = 0 }
	local buttons = {}

	local function hint(key: string, pad: string): string
		local last = game:GetService("UserInputService"):GetLastInputType()
		if last.Name:sub(1, 7) == "Gamepad" then
			return pad
		elseif last == Enum.UserInputType.Touch then
			return ""
		end
		return key
	end

	local function dash()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local dir = humanoid.MoveDirection
			if dir.Magnitude < 0.1 then
				dir = root.CFrame.LookVector
			end
			root.AssemblyLinearVelocity = dir.Unit * 70 + Vector3.new(0, 12, 0)
		end
	end

	local function use(skillId: string)
		if os.clock() < readyAt[skillId] then
			return
		end
		if skillId == "Dodge" then
			dash() -- anticipation locale ; l'invulnérabilité est décidée par le serveur
		end
		local ok, res = pcall(function()
			return Request:InvokeServer("UseSkill", { Id = skillId })
		end)
		if ok and type(res) == "table" then
			if res.cooldown then
				readyAt[skillId] = os.clock() + res.cooldown
			end
			if res.msg and not res.ok then
				toast(res.msg, "error")
			end
		end
	end

	for i, id in { "Strike", "Dodge" } do
		local skill = Combat.Skills[id]
		buttons[id] = Ui.button({
			Position = UDim2.fromOffset((i - 1) * 100, 0),
			Size = UDim2.fromOffset(92, 86),
			BackgroundColor3 = if id == "Strike" then C.Robux else C.Free,
			TextSize = 14,
			TextWrapped = true,
			Text = skill.Name,
			Parent = skillFrame,
		}, function()
			use(id)
		end)
		Ui.stroke().Parent = buttons[id]
	end

	local function bind(enabled: boolean)
		if enabled then
			ContextActionService:BindAction("SkillStrike", function(_, state)
				if state == Enum.UserInputState.Begin then
					use("Strike")
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
			ContextActionService:BindAction("SkillDodge", function(_, state)
				if state == Enum.UserInputState.Begin then
					use("Dodge")
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
		else
			ContextActionService:UnbindAction("SkillStrike")
			ContextActionService:UnbindAction("SkillDodge")
		end
	end

	local function arenaFolder(): Instance?
		local id = player:GetAttribute("InArena")
		if not id or id == "" then
			return nil
		end
		local world = workspace:FindFirstChild("World")
		local arenas = world and world:FindFirstChild("Arenas")
		return arenas and arenas:FindFirstChild(id)
	end

	local inArena = false
	local skillsShown = false
	local function refreshMode()
		inArena = arenaFolder() ~= nil
		bossFrame.Visible = inArena
		-- Compétences visibles en arène ET dans la Rue des boss.
		local show = inArena or player:GetAttribute("InStreet") == true
		if show ~= skillsShown then
			skillsShown = show
			skillFrame.Visible = show
			bind(show)
		end
	end
	player:GetAttributeChangedSignal("InArena"):Connect(refreshMode)
	player:GetAttributeChangedSignal("InStreet"):Connect(refreshMode)

	local lastTimerUpdate = 0
	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		if clock - lastTimerUpdate > 0.5 then
			lastTimerUpdate = clock
			local text = ""
			local world = workspace:FindFirstChild("World")
			local arenas = world and world:FindFirstChild("Arenas")
			if arenas and not skillsShown then
				for _, folder in arenas:GetChildren() do
					local state = folder:GetAttribute("State")
					local name = tostring(folder:GetAttribute("BossName") or "Boss")
					if state == "Fighting" then
						text = "Combat contre le boss en cours : " .. name
						break
					elseif state == "Idle" then
						text = name .. " attend des combattants ! (portails du point d'accueil)"
					elseif state == "Dead" and text == "" then
						text = "Prochaine bataille contre le boss dans "
							.. formatTime(folder:GetAttribute("RespawnIn") or 0)
							.. " · "
							.. name
					end
				end
			end
			bossTimer.Text = text
			bossTimer.Visible = text ~= ""
		end
		if not skillsShown then
			return
		end
		local now = os.clock()
		for id, button in buttons do
			local remaining = readyAt[id] - now
			local label = Combat.Skills[id].Name
			local key = if id == "Strike" then hint("[F]", "(R1)") else hint("[Q]", "(L1)")
			button.Text = if remaining > 0 then string.format("%s\n%.1f s", label, remaining) else label .. "\n" .. key
			button.BackgroundTransparency = if remaining > 0 then 0.5 else 0
		end
		if not inArena then
			return
		end
		local folder = arenaFolder()
		if not folder then
			return
		end
		local state = folder:GetAttribute("State")
		local hp = folder:GetAttribute("Hp") or 0
		local maxHp = math.max(folder:GetAttribute("MaxHp") or 1, 1)
		local name = tostring(folder:GetAttribute("BossName") or "Boss")
		local power = player:GetAttribute("Power") or 0
		local recommended = folder:GetAttribute("RecommendedPower") or 0
		local powerText = string.format("Ta Puissance %d / conseillée %d", power, recommended)
		if state == "Dead" then
			bossName.Text = name .. " · vaincu"
			barFill.Size = UDim2.fromScale(0, 1)
			barText.Text = "Réapparition dans " .. tostring(folder:GetAttribute("RespawnIn") or 0) .. " s"
		else
			local phase = if (folder:GetAttribute("Phase") or 1) >= 2 then " · ENRAGÉ" else ""
			bossName.Text = name .. phase .. " · " .. powerText
			barFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
			barText.Text = Formulas.formatNumber(hp) .. " / " .. Formulas.formatNumber(maxHp)
		end
	end)

	CombatFx.OnClientEvent:Connect(function(position: Vector3, amount: number, label: string?)
		if label then
			Effects.floatAt(position, label, Color3.fromRGB(255, 212, 70))
		else
			Effects.floatAt(position, "-" .. Formulas.formatNumber(amount), Color3.fromRGB(255, 90, 70))
		end
	end)
end

return CombatUi
