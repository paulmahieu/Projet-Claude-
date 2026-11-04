--[[
	DefenseService : défense du bastion (cahier §7).

	- Lancée VOLONTAIREMENT par un membre autorisé (permission Build), depuis le Noyau d'Éther.
	- Avertissement de quelques secondes au groupe, puis plusieurs vagues qui entrent par le
	  portail et visent le Noyau ; elles s'en prennent aux défenseurs proches.
	- Les membres présents frappent automatiquement l'ennemi le plus proche (et peuvent
	  utiliser Frappe runique / Esquive, partagées avec les arènes et la Rue des boss).
	- Victoire : matériaux pour le groupe, or et trophées pour chaque participant.
	- Défaite (Noyau épuisé) : la défense s'arrête, le Noyau se répare ; AUCUNE construction
	  n'est détruite, aucune ressource n'est perdue.
	- Aucune attaque sans défenseur : si plus aucun membre n'est dans le bastion, la défense
	  est annulée sans pénalité.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Defense = require(Shared.Config.Defense)
local Pass = require(Shared.Config.Pass)
local Street = require(Shared.Config.Street)
local Structures = require(Shared.Config.Structures)
local Combat = require(Shared.Config.Combat)
local Game = require(Shared.Config.Game)
local Groups = require(Shared.Config.Groups)
local Economy = require(Shared.Config.Economy)
local Materials = require(Shared.Config.Materials)
local Membership = require(Shared.Membership)

local ProfileService = require(script.Parent.ProfileService)
local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local Notifier = require(script.Parent.Notifier)
local PassService = require(script.Parent.PassService)
local Models = require(script.Parent.Parent.Art.Models)

local CombatFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx") :: RemoteEvent

local DefenseService = {}

local TICK = 0.1
local HALF = Game.PlotSize / 2

type Enemy = {
	Model: Model,
	Root: BasePart,
	Label: TextLabel,
	Name: string,
	Hp: number,
	MaxHp: number,
	Damage: number,
	LastAttack: number,
}

type Run = {
	Group: any,
	Plot: any,
	Phase: string, -- "Prep" | "Wave" | "Between"
	Wave: number,
	CoreHp: number,
	CoreMax: number,
	Enemies: { Enemy },
	Participants: { [number]: boolean },
	NextAt: number,
	EmptySince: number?,
	Label: TextLabel,
	Anchor: BasePart,
}

local runs: { [string]: Run } = {}
local cooldownUntil: { [string]: number } = {}
local lastAuto: { [Player]: number } = {}
local enemiesFolder: Folder
local isInvulnerable: (Player) -> boolean = function(_player)
	return false
end

local materialName = {}
for _, mat in Materials do
	materialName[mat.Id] = mat.Name
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 and root then
		return root
	end
	return nil
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Membres du groupe présents dans le bastion (vivants).
local function defenders(run: Run): { Player }
	local list = {}
	for player in run.Group.Online do
		local root = aliveRoot(player)
		if root then
			local rel = run.Plot.CFrame:PointToObjectSpace(root.Position)
			if math.abs(rel.X) <= HALF + 4 and math.abs(rel.Z) <= HALF + 12 and math.abs(rel.Y) < 30 then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function corePosition(run: Run): Vector3
	return (run.Plot.CFrame * CFrame.new(0, 0, 8)).Position
end

local function enemyStats(stage: number, patron: boolean)
	local hp = Street.Enemy.Health * Street.HealthGrowth ^ (stage - 1)
	local dmg = Street.Enemy.Damage * Street.DamageGrowth ^ (stage - 1)
	return {
		Health = math.floor(hp * (if patron then Street.Patron.HealthMult else 1)),
		Damage = math.floor(dmg * (if patron then Street.Patron.DamageMult else 1)),
	}
end

local function updateLabel(run: Run)
	local text
	if run.Phase == "Prep" then
		text = string.format("⚔ Assaut dans %d s !", math.max(0, math.ceil(run.NextAt - os.clock())))
	elseif run.Phase == "Between" then
		text = string.format("Vague %d dans %d s", run.Wave, math.max(0, math.ceil(run.NextAt - os.clock())))
	else
		text = string.format("⚔ Vague %d/%d · %d ennemi(s)", run.Wave, Defense.Waves, #run.Enemies)
	end
	run.Label.Text = string.format(
		"%s\nNoyau : %s / %s",
		text,
		Formulas.formatNumber(math.max(0, run.CoreHp)),
		Formulas.formatNumber(run.CoreMax)
	)
end

local function setInDefense(run: Run, value: boolean)
	for player in run.Group.Online do
		if player:GetAttribute("InDefense") ~= value then
			player:SetAttribute("InDefense", value)
		end
	end
end

local function finish(run: Run, outcome: string)
	for _, enemy in run.Enemies do
		enemy.Model:Destroy()
	end
	table.clear(run.Enemies)
	runs[run.Group.Id] = nil
	cooldownUntil[run.Group.Id] = os.clock() + (if outcome == "Cancelled" then 30 else Defense.CooldownSeconds)
	setInDefense(run, false)
	run.Anchor:Destroy()

	local group = run.Group
	if outcome == "Victory" then
		local level = Formulas.bastionLevel(Structures, group.Data.Structures)
		local parts = {}
		if GroupService.canMutate(group) then
			for matId, amount in Defense.Rewards.Group do
				local total = amount * level
				local mats = group.Data.Materials
				mats[matId] = Formulas.clamp((mats[matId] or 0) + total, Economy.MaterialCap)
				table.insert(parts, string.format("+%d %s", total, materialName[matId] or matId))
			end
			GroupService.markChanged(group)
		end
		local gold = math.floor(enemyStats(Formulas.defenseStage(Defense, level, Defense.Waves), false).Health / 10)
			* Defense.Rewards.GoldEnemyMult
		for userId in run.Participants do
			local player = Players:GetPlayerByUserId(userId)
			local profile = player and ProfileService.get(player)
			if player and profile and ProfileService.canMutate(player) then
				profile.Gold = Formulas.clamp(profile.Gold + gold, Economy.GoldCap)
				local trophies = ProfileService.addTrophies(player, Defense.Rewards.TrophiesPerLevel * level)
				PassService.addXp(player, Pass.Xp.DefenseWin)
				ProfileService.sync(player)
				Notifier.send(
					player,
					string.format("Défense réussie ! +%s or, +%d trophées", Formulas.formatNumber(gold), trophies),
					"reward"
				)
			end
		end
		for member in group.Online do
			Notifier.send(member, "Butin de la défense pour le bastion : " .. table.concat(parts, ", "), "reward")
		end
		Notifier.broadcast(string.format("🛡 %s a repoussé l'assaut !", group.Data.Name), "reward")
	elseif outcome == "Defeat" then
		for member in group.Online do
			Notifier.send(
				member,
				"Le Noyau est épuisé : l'assaut s'arrête et il se répare. Rien n'est perdu, retentez plus tard !",
				"error"
			)
		end
	else
		for member in group.Online do
			Notifier.send(
				member,
				"Défense annulée : plus aucun défenseur dans le bastion (sans pénalité).",
				"info"
			)
		end
	end
end

local function spawnWave(run: Run, present: number)
	local level = Formulas.bastionLevel(Structures, run.Group.Data.Structures)
	local stage = Formulas.defenseStage(Defense, level, run.Wave)
	local count = Formulas.defenseWaveSize(Defense, run.Wave, present)
	local kind = Street.Kinds[((run.Wave - 1) % #Street.Kinds) + 1]
	for i = 1, count do
		-- Le dernier ennemi de la dernière vague est un chef (patron).
		local patron = run.Wave == Defense.Waves and i == count
		local stats = enemyStats(stage, patron)
		local x = (i - (count + 1) / 2) * 3
		local base = run.Plot.CFrame * CFrame.new(x, 0, -HALF - 8 - math.random() * 4)
		local model, root = Models.enemy(kind, base, kind.Scale, patron)
		model.Parent = enemiesFolder
		local label = PlotService.makeBillboard(root, "", if patron then 6 else 3.5, Vector2.new(8, 2), 60)
		local enemy: Enemy = {
			Model = model,
			Root = root,
			Label = label,
			Name = if patron then "Chef " .. kind.Name else kind.Name,
			Hp = stats.Health,
			MaxHp = stats.Health,
			Damage = stats.Damage,
			LastAttack = os.clock() + 1,
		}
		label.Text = string.format(
			"%s\n%s / %s",
			enemy.Name,
			Formulas.formatNumber(enemy.Hp),
			Formulas.formatNumber(enemy.MaxHp)
		)
		table.insert(run.Enemies, enemy)
	end
end

local function damageEnemy(run: Run, player: Player, enemy: Enemy, amount: number)
	if enemy.Hp <= 0 then
		return
	end
	enemy.Hp -= amount
	run.Participants[player.UserId] = true
	CombatFx:FireClient(player, enemy.Root.Position + Vector3.new(0, 3, 0), amount)
	enemy.Label.Text = string.format(
		"%s\n%s / %s",
		enemy.Name,
		Formulas.formatNumber(math.max(0, enemy.Hp)),
		Formulas.formatNumber(enemy.MaxHp)
	)
	if enemy.Hp <= 0 then
		local index = table.find(run.Enemies, enemy)
		if index then
			table.remove(run.Enemies, index)
		end
		enemy.Model:Destroy()
	end
end

local function tickRun(run: Run, now: number, dt: number)
	if PlotService.get(run.Group.Id) ~= run.Plot or GroupService.get(run.Group.Id) ~= run.Group then
		finish(run, "Cancelled")
		return
	end
	local present = defenders(run)
	if #present == 0 then
		run.EmptySince = run.EmptySince or now
		if now - (run.EmptySince :: number) > Defense.AbandonSeconds then
			finish(run, "Cancelled")
		end
		return
	end
	run.EmptySince = nil
	updateLabel(run)

	if run.Phase ~= "Wave" then
		if now >= run.NextAt then
			run.Phase = "Wave"
			spawnWave(run, #present)
			for member in run.Group.Online do
				Notifier.send(member, string.format("⚔ Vague %d/%d !", run.Wave, Defense.Waves), "error")
			end
		end
		return
	end

	-- Ennemis : défenseur proche, sinon le Noyau.
	local core = corePosition(run)
	for _, enemy in table.clone(run.Enemies) do
		local pos = enemy.Root.Position
		local target, targetPlayer = core, nil
		for _, player in present do
			local root = aliveRoot(player)
			if root and flat(root.Position, pos) < 10 then
				target, targetPlayer = root.Position, player
				break
			end
		end
		local range = if targetPlayer then Street.Enemy.AttackRange else 6
		local dist = flat(pos, target)
		local groundY = run.Plot.CFrame.Position.Y
		local from = Vector3.new(pos.X, groundY, pos.Z)
		local to = Vector3.new(target.X, groundY, target.Z)
		if dist > range then
			from += (to - from).Unit * math.min(Street.Enemy.Speed * 0.9 * dt, dist - range)
		end
		-- Dans l'enceinte, le sol de la parcelle est surélevé de 1 studs.
		local rel = run.Plot.CFrame:PointToObjectSpace(from)
		local floor = if math.abs(rel.X) <= HALF and math.abs(rel.Z) <= HALF then 1 else 0
		from = Vector3.new(from.X, groundY + floor, from.Z)
		to = Vector3.new(to.X, groundY + floor, to.Z)
		if dist <= range and now - enemy.LastAttack >= Street.Enemy.AttackCooldown then
			enemy.LastAttack = now
			if targetPlayer then
				local humanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and not isInvulnerable(targetPlayer) then
					humanoid:TakeDamage(enemy.Damage)
				end
			else
				run.CoreHp -= enemy.Damage * Defense.CoreDamageMult
			end
		end
		if (to - from).Magnitude > 0.1 then
			enemy.Model:PivotTo(CFrame.lookAt(from, to) * CFrame.new(0, enemy.Root.Size.Y / 2, 0))
		end
	end
	if run.CoreHp <= 0 then
		finish(run, "Defeat")
		return
	end

	-- Attaque automatique des défenseurs sur l'ennemi le plus proche.
	for _, player in present do
		local root = aliveRoot(player)
		if root and (lastAuto[player] or 0) + Combat.AutoAttack.Cooldown <= now then
			local nearest, best = nil, math.huge
			for _, enemy in run.Enemies do
				local d = flat(enemy.Root.Position, root.Position)
				if d < best then
					nearest, best = enemy, d
				end
			end
			if nearest and best <= Combat.AutoAttack.Range then
				lastAuto[player] = now
				damageEnemy(
					run,
					player,
					nearest,
					Formulas.hitDamage(
						ProfileService.power(player),
						Combat.AutoAttack.DamageMult,
						ProfileService.damageMultiplier(player)
					)
				)
			end
		end
	end

	if #run.Enemies == 0 then
		if run.Wave >= Defense.Waves then
			finish(run, "Victory")
		else
			run.Wave += 1
			run.Phase = "Between"
			run.NextAt = now + Defense.BetweenWaves
		end
	end
end

-- API -------------------------------------------------------------------------------------

function DefenseService.start(player: Player, plot)
	local group = GroupService.groupOf(player)
	if not group or plot.GroupId ~= group.Id then
		Notifier.send(player, "Ce Noyau n'appartient pas à ton bastion.", "error")
		return
	end
	if not Membership.can(Groups, group.Data, player.UserId, "Build") or not GroupService.canMutate(group) then
		Notifier.send(player, "Ton rôle ne permet pas de lancer la défense.", "error")
		return
	end
	if runs[group.Id] then
		return
	end
	local now = os.clock()
	if (cooldownUntil[group.Id] or 0) > now then
		Notifier.send(
			player,
			string.format(
				"Le Noyau récupère : nouvelle défense dans %d s.",
				math.ceil(cooldownUntil[group.Id] - now)
			),
			"info"
		)
		return
	end
	local level = Formulas.bastionLevel(Structures, group.Data.Structures)
	local crystal = plot.Core.PrimaryPart :: BasePart
	local holder = Instance.new("Part")
	holder.Name = "DefenseLabelAnchor"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = crystal.CFrame
	holder.Parent = enemiesFolder
	local label = PlotService.makeBillboard(holder, "", 8, Vector2.new(12, 2.6), 120)
	label.TextColor3 = Color3.fromRGB(255, 200, 120)
	local run: Run = {
		Group = group,
		Plot = plot,
		Phase = "Prep",
		Wave = 1,
		CoreHp = Defense.CoreHealthPerLevel * level,
		CoreMax = Defense.CoreHealthPerLevel * level,
		Enemies = {},
		Participants = {},
		NextAt = now + Defense.PrepSeconds,
		EmptySince = nil,
		Label = label,
		Anchor = holder,
	}
	runs[group.Id] = run
	setInDefense(run, true)
	for member in group.Online do
		Notifier.send(
			member,
			string.format(
				"⚔ %s lance la défense du bastion : assaut dans %d s !",
				player.DisplayName,
				Defense.PrepSeconds
			),
			"error"
		)
	end
	updateLabel(run)
end

-- Frappe runique pendant une défense (appelée par BossService si le joueur n'est pas en arène).
function DefenseService.strike(player: Player, damageMult: number, range: number): boolean
	local group = GroupService.groupOf(player)
	local run = group and runs[group.Id]
	local root = aliveRoot(player)
	if not run or not root or run.Phase ~= "Wave" then
		return false
	end
	local target, best = nil, math.huge
	for _, enemy in run.Enemies do
		local d = flat(enemy.Root.Position, root.Position)
		if d < best then
			target, best = enemy, d
		end
	end
	if not target or best > range then
		return false
	end
	damageEnemy(
		run,
		player,
		target,
		Formulas.hitDamage(ProfileService.power(player), damageMult, ProfileService.damageMultiplier(player))
	)
	return true
end

function DefenseService.setInvulnerabilityCheck(fn: (Player) -> boolean)
	isInvulnerable = fn
end

function DefenseService.init()
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "DefenseEnemies"
	enemiesFolder.Parent = PlotService.world()
	-- Une invite « Lancer la défense » sur le Noyau de chaque parcelle.
	for _, plot in PlotService.all() do
		local crystal = plot.Core.PrimaryPart
		if crystal then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Lancer la défense"
			prompt.ObjectText = "Noyau d'Éther"
			prompt.HoldDuration = 1 -- maintien : pas de lancement accidentel
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = crystal
			prompt.Triggered:Connect(function(player)
				DefenseService.start(player, plot)
			end)
		end
	end
end

function DefenseService.begin()
	Players.PlayerRemoving:Connect(function(player)
		lastAuto[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = math.min(now - last, 0.5)
			last = now
			for _, run in runs do
				local ok, err = pcall(tickRun, run, now, dt)
				if not ok then
					warn("[DefenseService] " .. tostring(err))
					pcall(finish, run, "Cancelled")
				end
			end
		end
	end)
end

return DefenseService
