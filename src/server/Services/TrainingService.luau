--[[
	TrainingService : entraînement AFK sur le mannequin de sa base.

	- Le joueur active l'entraînement via un ProximityPrompt (touche E).
	- Tant qu'il reste à portée du mannequin, il gagne de l'XP chaque seconde.
	- S'il s'éloigne ou meurt, l'entraînement s'arrête.
	- Chaque niveau augmente la production d'or (Economy.IncomeBonusPerLevel).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Training = require(Shared.Config.Training)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local Notifier = require(script.Parent.Notifier)

local TrainingService = {}

type Session = {
	Dummy: Model,
	Prompt: ProximityPrompt,
	Torso: BasePart,
	Rest: CFrame, -- position de repos du mannequin
	Active: boolean,
}

local sessions: { [Player]: Session } = {}

local function setActive(player: Player, active: boolean, reason: string?)
	local session = sessions[player]
	if not session or session.Active == active then
		return
	end
	session.Active = active
	session.Prompt.ActionText = if active then "Arrêter" else "S'entraîner"
	player:SetAttribute("Training", active)
	if active then
		Notifier.send(player, "Entraînement commencé. Restez près du mannequin.", "info")
	elseif reason then
		Notifier.send(player, reason, "info")
	end
end

local function buildDummy(plotCFrame: CFrame, parent: Instance): (Model, ProximityPrompt, BasePart)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local base = CFrame.new(Training.DummyOffset[1], 0, Training.DummyOffset[2])
	local function part(name, size, offsetY, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = plotCFrame * base * CFrame.new(0, offsetY, 0)
		p.Material = Enum.Material.Fabric
		p.Color = color
		p.Parent = model
		return p
	end
	part("Pole", Vector3.new(0.6, 6, 0.6), 3, Color3.fromRGB(100, 70, 40))
	local torso = part("Torso", Vector3.new(3, 3, 1.5), 4.5, Color3.fromRGB(200, 170, 120))
	part("Head", Vector3.new(1.6, 1.6, 1.6), 6.8, Color3.fromRGB(200, 170, 120))
	model.PrimaryPart = torso

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "S'entraîner"
	prompt.ObjectText = "Mannequin d'entraînement"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	model.Parent = parent
	return model, prompt, torso
end

-- Petite secousse du mannequin à chaque « coup ».
local function hitFeedback(torso: BasePart, rest: CFrame)
	torso.CFrame = rest * CFrame.Angles(math.rad(math.random(-12, 12)), 0, math.rad(math.random(-12, 12)))
	TweenService:Create(torso, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), { CFrame = rest }):Play()
end

-- Appelé par Main une fois la parcelle attribuée.
function TrainingService.setup(player: Player, plot)
	local dummy, prompt, torso = buildDummy(plot.CFrame, plot.Model)
	sessions[player] = { Dummy = dummy, Prompt = prompt, Torso = torso, Rest = torso.CFrame, Active = false }
	player:SetAttribute("Training", false)

	prompt.Triggered:Connect(function(by: Player)
		if by ~= player then
			-- La coopération (s'entraîner chez un allié) est une décision en attente : docs/CONCEPTION.md
			Notifier.send(by, "Ce mannequin appartient à " .. player.DisplayName .. ".", "error")
			return
		end
		local session = sessions[player]
		if session then
			setActive(player, not session.Active, "Entraînement arrêté.")
		end
	end)
end

local function tick(player: Player, session: Session, dt: number)
	local data = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not root or not humanoid or humanoid.Health <= 0 then
		setActive(player, false, "Entraînement interrompu.")
		return
	end
	local distance = (root.Position - session.Torso.Position).Magnitude
	if distance > Training.MaxRange then
		setActive(player, false, "Vous vous êtes éloigné : entraînement arrêté.")
		return
	end

	local amount = Training.XpPerSecond * dt * MonetizationService.passMultiplier(player, "FastTraining")
	local level, xp, gained = Formulas.addXp(data.Level, data.Xp, amount, Training)
	data.Level, data.Xp = level, xp
	hitFeedback(session.Torso, session.Rest)
	if gained > 0 then
		Notifier.send(
			player,
			string.format(
				"Niveau %d ! Bonus de production : +%d %%",
				level,
				math.floor((Formulas.levelMultiplier(level, Economy.IncomeBonusPerLevel) - 1) * 100 + 0.5)
			),
			"success"
		)
	end
	EconomyService.sync(player)
end

function TrainingService.start()
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, session in sessions do
				if session.Active then
					tick(player, session, dt)
				end
			end
		end
	end)
end

return TrainingService
