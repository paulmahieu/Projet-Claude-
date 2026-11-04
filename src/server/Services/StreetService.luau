--[[
	StreetService : la Rue des boss (inspirée des couloirs à étapes : vagues, portes, patrons).

	- Rue suspendue, accessible par un portail au point d'accueil, découpée en sections.
	- Chaque joueur a SA vague : en entrant dans la section de son étape, ses ennemis
	  apparaissent ; seuls ses coups les touchent, seules leurs attaques le visent.
	- Les portes sont gérées par le client (barrières locales) ; le serveur reste l'autorité :
	  il ne fait apparaître les ennemis que dans la section de l'étape en cours.
	- Étape terminée -> étape suivante sauvegardée dans le profil (Street.Stage / Best / Kills).
	- Toutes les 5 étapes : un Patron (plus fort, coup de zone annoncé) et un butin affiché
	  (matériaux pour le groupe, petite chance de compagnon).
	- Après la dernière section : retour au début, la numérotation continue (ennemis plus forts).
	- Mort ou sortie de la rue : la vague disparaît, l'étape n'est pas perdue.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Street = require(Shared.Config.Street)
local Combat = require(Shared.Config.Combat)
local Pets = require(Shared.Config.Pets)
local Tree = require(Shared.Config.Tree)
local Training = require(Shared.Config.Training)
local Economy = require(Shared.Config.Economy)
local Materials = require(Shared.Config.Materials)

local ProfileService = require(script.Parent.ProfileService)
local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local PetService = require(script.Parent.PetService)
local Notifier = require(script.Parent.Notifier)
local PassService = require(script.Parent.PassService)
local Pass = require(Shared.Config.Pass)
local Models = require(script.Parent.Parent.Art.Models)

local CombatFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx") :: RemoteEvent

local StreetService = {}

local TICK = 0.1
local LEAVE_GRACE = 3
local rng = Random.new()

type Enemy = {
	Model: Model,
	Root: BasePart,
	Label: TextLabel,
	Name: string,
	Hp: number,
	MaxHp: number,
	Damage: number,
	Gold: number,
	Xp: number,
	Patron: boolean,
	LastAttack: number,
	NextSlam: number,
}

type Run = { Enemies: { Enemy }, Stage: number, LeftAt: number?, Clearing: boolean }

local runs: { [Player]: Run } = {}
local lastAuto: { [Player]: number } = {}
local isInvulnerable: (Player) -> boolean = function(_player)
	return false -- remplacé par la vérification d'esquive de BossService (voir Main)
end

local origin = CFrame.lookAt(
	Vector3.new(Street.Origin[1], Street.Origin[2], Street.Origin[3]),
	Vector3.new(Street.Origin[1] + 1, Street.Origin[2], Street.Origin[3])
)
local forward = origin.LookVector
local right = origin.RightVector
local length = Street.Sections * Street.SectionLength

local enemiesFolder: Folder
local materialName, petById = {}, {}
for _, mat in Materials do
	materialName[mat.Id] = mat.Name
end
for _, def in Pets.List do
	petById[def.Id] = def
end

-- Utilitaires --------------------------------------------------------------------------

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

-- Position relative à la rue : distance le long, écart latéral, hauteur.
local function streetCoords(position: Vector3): (number, number, number)
	local rel = position - origin.Position
	return rel:Dot(forward), rel:Dot(right), rel.Y
end

local function inStreet(position: Vector3): boolean
	local along, lateral, height = streetCoords(position)
	return along >= -26 and along <= length + 4 and math.abs(lateral) <= Street.Width / 2 + 3 and math.abs(height) < 30
end

local function sectionStart(section: number): CFrame
	return origin * CFrame.new(0, 3, -(section - 1) * Street.SectionLength - 3)
end

local function getRun(player: Player): Run
	local run = runs[player]
	if not run then
		run = { Enemies = {}, Stage = 0, LeftAt = nil, Clearing = false }
		runs[player] = run
	end
	return run
end

local function publish(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	local stage = profile.Street.Stage
	player:SetAttribute("StreetStage", stage)
	player:SetAttribute("StreetBest", profile.Street.Best)
	player:SetAttribute("StreetKills", profile.Street.Kills)
	player:SetAttribute("StreetRecPower", Formulas.streetRecommendedPower(stage, Street))
	player:SetAttribute("StreetPatron", Formulas.streetIsPatron(stage, Street))
	local run = runs[player]
	player:SetAttribute("StreetRemaining", if run then #run.Enemies else 0)
end

local function updateLabel(enemy: Enemy)
	enemy.Label.Text = string.format(
		"%s%s\n%s / %s",
		if enemy.Patron then "PATRON · " else "",
		enemy.Name,
		Formulas.formatNumber(math.max(0, enemy.Hp)),
		Formulas.formatNumber(enemy.MaxHp)
	)
end

local function despawnAll(run: Run)
	for _, enemy in run.Enemies do
		enemy.Model:Destroy()
	end
	table.clear(run.Enemies)
end

-- Vagues --------------------------------------------------------------------------------

local function spawnWave(player: Player, stage: number, section: number)
	local run = getRun(player)
	run.Stage = stage
	local patron = Formulas.streetIsPatron(stage, Street)
	local count = Formulas.streetWaveSize(stage, Street)
	local stats = Formulas.streetEnemy(stage, Street)
	local kindIndex = if patron
		then ((stage // Street.PatronEvery - 1) % #Street.Kinds) + 1
		else ((stage - 1) % #Street.Kinds) + 1
	local kind = Street.Kinds[kindIndex]
	local name = if patron then Street.PatronNames[kindIndex] else kind.Name

	for i = 1, count do
		local z = -(section - 1) * Street.SectionLength - Street.SectionLength * 0.65 + rng:NextNumber(-5, 5)
		local x = if count == 1 then 0 else (i - (count + 1) / 2) * (Street.Width - 8) / math.max(count - 1, 1)
		local base = origin * CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi, 0) -- face au joueur
		local model, root = Models.enemy(kind, base, kind.Scale, patron)
		model:SetAttribute("Owner", player.UserId)
		model.Parent = enemiesFolder
		local label = PlotService.makeBillboard(root, "", (if patron then 6 else 3.5), Vector2.new(8, 2))
		label.TextColor3 = if patron then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
		local enemy: Enemy = {
			Model = model,
			Root = root,
			Label = label,
			Name = name,
			Hp = stats.Health,
			MaxHp = stats.Health,
			Damage = stats.Damage,
			Gold = stats.Gold,
			Xp = stats.Xp,
			Patron = patron,
			LastAttack = os.clock() + 1, -- court délai avant la première attaque
			NextSlam = os.clock() + 3,
		}
		updateLabel(enemy)
		if patron then
			-- Butin annoncé (chances affichées).
			local lines = { "Butin :" }
			for _, drop in Street.PatronDrops do
				local dropName = if drop.Kind == "Material"
					then string.format("%d %s", drop.Amount, materialName[drop.Id] or drop.Id)
					else (petById[drop.Id] and petById[drop.Id].Name or drop.Id)
				table.insert(lines, string.format("%s (%s %%)", dropName, tostring(drop.Chance * 100):gsub("%.", ",")))
			end
			local loot = PlotService.makeBillboard(root, table.concat(lines, "\n"), 10, Vector2.new(9, 4.5))
			loot.TextColor3 = Color3.fromRGB(255, 220, 120)
		end
		table.insert(run.Enemies, enemy)
	end
	publish(player)
	if patron then
		Notifier.send(
			player,
			"Un PATRON approche : " .. name .. " ! Évite les zones rouges (Q pour esquiver).",
			"error"
		)
	end
end

local function grantPatronDrops(player: Player)
	local rolls = {}
	for i = 1, #Street.PatronDrops do
		rolls[i] = rng:NextNumber()
	end
	local parts = {}
	local group = GroupService.groupOf(player)
	for _, drop in Formulas.rollDrops(Street.PatronDrops, rolls) do
		if drop.Kind == "Material" and group and GroupService.canMutate(group) then
			local mats = group.Data.Materials
			mats[drop.Id] = Formulas.clamp((mats[drop.Id] or 0) + drop.Amount, Economy.MaterialCap)
			table.insert(parts, string.format("+%d %s (bastion)", drop.Amount, materialName[drop.Id] or drop.Id))
			GroupService.markChanged(group)
		elseif drop.Kind == "Pet" then
			if PetService.grant(player, drop.Id) then
				table.insert(parts, "compagnon " .. petById[drop.Id].Name .. " !")
			end
		end
	end
	if #parts > 0 then
		Notifier.send(player, "Butin du patron : " .. table.concat(parts, ", "), "reward")
	end
end

local function clearStage(player: Player, run: Run)
	local profile = ProfileService.get(player)
	if not profile or not ProfileService.canMutate(player) then
		return
	end
	local stage = profile.Street.Stage
	local stats = Formulas.streetEnemy(stage, Street)
	local bonusGold = stats.Gold * Street.StageClearMultiplier
	local bonusXp = stats.Xp * Street.StageClearMultiplier
	profile.Gold = Formulas.clamp(profile.Gold + bonusGold, Economy.GoldCap)
	profile.Level, profile.TrainXp = Formulas.addXp(profile.Level, profile.TrainXp, bonusXp, Training)
	local trophies = ProfileService.addTrophies(player, stage * Tree.TrophyRewards.StreetStagePerStage)
	profile.Street.Best = math.max(profile.Street.Best, stage)
	profile.Street.Stage = stage + 1
	PassService.addXp(player, Pass.Xp.StreetStage)
	ProfileService.sync(player)
	publish(player)
	Notifier.send(
		player,
		string.format(
			"Étape %d terminée ! +%s or, +%s XP, +%d trophées. Étape %d : Puissance conseillée %d",
			stage,
			Formulas.formatNumber(bonusGold),
			Formulas.formatNumber(bonusXp),
			trophies,
			stage + 1,
			Formulas.streetRecommendedPower(stage + 1, Street)
		),
		"reward"
	)
	-- Fin de la rue : retour au début, la numérotation continue.
	if Formulas.streetSection(stage, Street) == Street.Sections then
		run.Clearing = true
		task.delay(2, function()
			run.Clearing = false
			local root = aliveRoot(player)
			if root and inStreet(root.Position) and player.Character then
				player.Character:PivotTo(sectionStart(1))
				Notifier.send(player, "Fin de la rue ! Retour au départ, ennemis plus forts.", "info")
			end
		end)
	end
end

local function damageEnemy(player: Player, run: Run, enemy: Enemy, amount: number)
	if enemy.Hp <= 0 then
		return
	end
	enemy.Hp -= amount
	CombatFx:FireClient(player, enemy.Root.Position + Vector3.new(0, 3, 0), amount)
	updateLabel(enemy)
	if enemy.Hp > 0 then
		return
	end
	-- Ennemi vaincu : récompenses personnelles.
	local index = table.find(run.Enemies, enemy)
	if index then
		table.remove(run.Enemies, index)
	end
	enemy.Model:Destroy()
	local profile = ProfileService.get(player)
	if profile and ProfileService.canMutate(player) then
		profile.Gold = Formulas.clamp(profile.Gold + enemy.Gold, Economy.GoldCap)
		profile.Level, profile.TrainXp = Formulas.addXp(profile.Level, profile.TrainXp, enemy.Xp, Training)
		profile.Street.Kills += 1
		local stage = profile.Street.Stage
		ProfileService.addTrophies(
			player,
			stage
				* (
					if enemy.Patron
						then Tree.TrophyRewards.StreetPatronPerStage
						else Tree.TrophyRewards.StreetKillPerStage
				)
		)
		ProfileService.sync(player)
		CombatFx:FireClient(
			player,
			enemy.Root.Position + Vector3.new(0, 5, 0),
			0,
			"+" .. Formulas.formatNumber(enemy.Gold) .. " or"
		)
		if enemy.Patron then
			grantPatronDrops(player)
		end
	end
	publish(player)
	if #run.Enemies == 0 then
		clearStage(player, run)
	end
end

-- Attaque d'un ennemi / coup de zone du patron ---------------------------------------------

local function enemyHits(player: Player, damage: number)
	if isInvulnerable(player) then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
	end
end

local function patronSlam(player: Player, run: Run, enemy: Enemy, target: Vector3)
	local spot = Vector3.new(target.X, origin.Position.Y + 0.15, target.Z)
	local disc = Models.telegraph(enemiesFolder, spot, Street.Patron.SlamRadius)
	TweenService:Create(disc, TweenInfo.new(Street.Patron.SlamTelegraph), { Transparency = 0.15 }):Play()
	task.delay(Street.Patron.SlamTelegraph, function()
		disc:Destroy()
		if not table.find(run.Enemies, enemy) then
			return
		end
		local root = aliveRoot(player)
		if root and flat(root.Position, spot) <= Street.Patron.SlamRadius then
			enemyHits(player, enemy.Damage * 2)
		end
	end)
end

-- Boucle --------------------------------------------------------------------------------

local function tickPlayer(player: Player, now: number, dt: number)
	local profile = ProfileService.get(player)
	local root = aliveRoot(player)
	local run = getRun(player)
	local inside = root ~= nil and inStreet(root.Position)
	if player:GetAttribute("InStreet") ~= inside then
		player:SetAttribute("InStreet", inside)
		if inside then
			publish(player)
		end
	end
	if not profile or not root or not inside then
		if #run.Enemies > 0 then
			run.LeftAt = run.LeftAt or now
			if now - run.LeftAt > LEAVE_GRACE or not root then
				despawnAll(run)
				run.LeftAt = nil
				publish(player)
			end
		end
		return
	end
	run.LeftAt = nil

	local stage = profile.Street.Stage
	local section = Formulas.streetSection(stage, Street)
	local along, lateral = streetCoords(root.Position)
	if #run.Enemies == 0 and not run.Clearing and Formulas.streetSectionAt(along, lateral, Street) == section then
		spawnWave(player, stage, section)
	end

	-- Ennemis : avancent vers le joueur et attaquent au contact.
	local nearest, nearestDist = nil, math.huge
	for _, enemy in table.clone(run.Enemies) do
		local pos = enemy.Root.Position
		local dist = flat(pos, root.Position)
		local range = Street.Enemy.AttackRange * (if enemy.Patron then 1.8 else 1)
		local groundY = origin.Position.Y
		local from = Vector3.new(pos.X, groundY, pos.Z)
		local to = Vector3.new(root.Position.X, groundY, root.Position.Z)
		if dist > range then
			local step = math.min(Street.Enemy.Speed * dt, dist - range)
			from += (to - from).Unit * step
		elseif now - enemy.LastAttack >= Street.Enemy.AttackCooldown then
			enemy.LastAttack = now
			enemyHits(player, enemy.Damage)
		end
		if (to - from).Magnitude > 0.1 then
			enemy.Model:PivotTo(CFrame.lookAt(from, to) * CFrame.new(0, enemy.Root.Size.Y / 2, 0))
		end
		if enemy.Patron and now >= enemy.NextSlam then
			enemy.NextSlam = now + Street.Patron.SlamEvery + Street.Patron.SlamTelegraph
			patronSlam(player, run, enemy, root.Position)
		end
		if dist < nearestDist then
			nearest, nearestDist = enemy, dist
		end
	end

	-- Attaque automatique du joueur sur l'ennemi le plus proche (ses ennemis uniquement).
	if
		nearest
		and nearestDist <= Combat.AutoAttack.Range
		and (lastAuto[player] or 0) + Combat.AutoAttack.Cooldown <= now
	then
		lastAuto[player] = now
		local mult = ProfileService.damageMultiplier(player)
		damageEnemy(
			player,
			run,
			nearest,
			Formulas.hitDamage(ProfileService.power(player), Combat.AutoAttack.DamageMult, mult)
		)
	end
end

-- API -----------------------------------------------------------------------------------

-- Frappe runique dans la rue : appelée par BossService quand le joueur n'est pas en arène.
function StreetService.strike(player: Player, damageMult: number, range: number): boolean
	local run = runs[player]
	local root = aliveRoot(player)
	if not run or not root or #run.Enemies == 0 then
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
	local mult = ProfileService.damageMultiplier(player)
	damageEnemy(player, run, target, Formulas.hitDamage(ProfileService.power(player), damageMult, mult))
	return true
end

function StreetService.setInvulnerabilityCheck(fn: (Player) -> boolean)
	isInvulnerable = fn
end

function StreetService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Street"
	folder.Parent = PlotService.world()
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = folder
	Models.street(origin, Street, geometry)
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = folder

	local function teleport(player: Player, cf: CFrame)
		if player.Character and aliveRoot(player) then
			player.Character:PivotTo(cf)
		end
	end

	-- Portail au hub : téléporte au début de la section de l'étape en cours.
	local portalPos = Vector3.new(Street.Portal[1], 1, Street.Portal[2])
	local portalModel, veil = Models.portal(CFrame.lookAt(portalPos, Vector3.new(0, 1, 0)), Color3.fromRGB(220, 70, 70))
	portalModel.Name = "Portal_Street"
	portalModel.Parent = folder
	PlotService.makeBillboard(veil, "Rue des boss\nÉtapes, vagues et patrons", 8, Vector2.new(12, 3))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Entrer dans la rue"
	prompt.ObjectText = "Rue des boss"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.Parent = veil
	prompt.Triggered:Connect(function(player)
		local profile = ProfileService.get(player)
		if profile then
			teleport(player, sectionStart(Formulas.streetSection(profile.Street.Stage, Street)))
			publish(player)
		end
	end)

	-- Portail de retour sur le parvis de départ.
	local backModel, backVeil = Models.portal(
		origin * CFrame.new(-Street.Width / 2 - 1, 0, 16) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(110, 210, 255)
	)
	backModel.Name = "ReturnPortal"
	backModel.Parent = folder
	PlotService.makeBillboard(backVeil, "Retour au bastion", 7, Vector2.new(10, 1.6))
	local backPrompt = Instance.new("ProximityPrompt")
	backPrompt.ActionText = "Retour au bastion"
	backPrompt.HoldDuration = 0.3
	backPrompt.RequiresLineOfSight = false
	backPrompt.Parent = backVeil
	backPrompt.Triggered:Connect(function(player)
		local group = GroupService.groupOf(player)
		if group and PlotService.get(group.Id) then
			PlotService.teleportToPlot(player, group.Id)
		else
			teleport(player, CFrame.new(0, 5, 0))
		end
	end)
end

function StreetService.start()
	ProfileService.onLoaded(function(player)
		publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run then
			despawnAll(run)
		end
		runs[player] = nil
		lastAuto[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = math.min(now - last, 0.5)
			last = now
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tickPlayer, player, now, dt)
				if not ok then
					warn("[StreetService] " .. tostring(err))
				end
			end
		end
	end)
end

return StreetService
