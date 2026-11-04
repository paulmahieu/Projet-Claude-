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
local Diagnostics = require(script.Parent.Diagnostics)
local PassService = require(script.Parent.PassService)
local Pass = require(Shared.Config.Pass)
local Models = require(script.Parent.Parent.Art.Models)

local CombatFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx") :: RemoteEvent

local StreetService = {}

local TICK = 0.05 -- 20 images/s : animations fluides des ennemis
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
	Speed: number,
	SlamRadius: number,
	Def: any,
	Mini: boolean,
	NextAbility: number,
	NextSpecial: number,
	Busy: number, -- immobile jusqu'à cet instant (préparation d'une attaque)
	Anim: string?,
	AnimStart: number,
	AnimDur: number,
	Phase: number,
	PendingLeap: { To: Vector3, At: number }?,
	Leap: { From: Vector3, To: Vector3, Start: number }?,
	PendingCharge: { Dir: Vector3, At: number }?,
	Charge: { Dir: Vector3, Until: number, Hit: boolean }?,
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

-- Fiches d'ennemis (ordinaires et boss) par Id.
local kindById = {}
for _, def in Street.Kinds do
	kindById[def.Id] = def
end
for _, def in Street.Bosses do
	kindById[def.Id] = def
end

local function play(enemy: Enemy, anim: string, duration: number)
	enemy.Anim = anim
	enemy.AnimStart = os.clock()
	enemy.AnimDur = duration
end

-- Crée un ennemi (vague, division d'une gelée, renfort du roi gobelin).
-- opts : { Mini, HealthMult, RewardMult, Scale, Patron }
local function spawnEnemy(player: Player, run: Run, def, stage: number, base: CFrame, opts): Enemy
	local patron = opts.Patron == true
	local stats = Formulas.streetEnemyOf(stage, Street, def)
	local model, root = Models.enemy(def, base, (def.Scale or 1) * (opts.Scale or 1), false)
	model:SetAttribute("Owner", player.UserId)
	model.Parent = enemiesFolder
	local label = PlotService.makeBillboard(root, "", root.Size.Y / 2 + 1.5, Vector2.new(8, 2))
	label.TextColor3 = if patron then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
	local hp = math.max(1, math.floor(stats.Health * (opts.HealthMult or 1)))
	local now = os.clock()
	local enemy: Enemy = {
		Model = model,
		Root = root,
		Label = label,
		Name = if opts.Mini and def.Id == "ThornJelly" then "Petite gelée" else def.Name,
		Hp = hp,
		MaxHp = hp,
		Damage = stats.Damage,
		Gold = math.floor(stats.Gold * (opts.RewardMult or 1)),
		Xp = math.floor(stats.Xp * (opts.RewardMult or 1)),
		Patron = patron,
		LastAttack = now + 1, -- court délai avant la première attaque
		NextSlam = now + 3,
		Speed = stats.Speed,
		SlamRadius = def.SlamRadius or Street.Patron.SlamRadius,
		Def = def,
		Mini = opts.Mini == true,
		NextAbility = now + 2 + rng:NextNumber() * 1.5,
		NextSpecial = now + 6,
		Busy = 0,
		Anim = nil,
		AnimStart = 0,
		AnimDur = 0,
		Phase = rng:NextNumber() * 6,
		PendingLeap = nil,
		Leap = nil,
		PendingCharge = nil,
		Charge = nil,
	}
	updateLabel(enemy)
	table.insert(run.Enemies, enemy)
	return enemy
end

local function spawnWave(player: Player, stage: number, section: number)
	local run = getRun(player)
	run.Stage = stage
	local patron = Formulas.streetIsPatron(stage, Street)
	local count = Formulas.streetWaveSize(stage, Street)
	local name = ""

	for i = 1, count do
		local def = kindById[Formulas.streetKindId(stage, i, Street)] or Street.Kinds[1]
		name = def.Name
		local z = -(section - 1) * Street.SectionLength - Street.SectionLength * 0.65 + rng:NextNumber(-5, 5)
		local x = if count == 1 then 0 else (i - (count + 1) / 2) * (Street.Width - 8) / math.max(count - 1, 1)
		local base = origin * CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi, 0) -- face au joueur
		local enemy = spawnEnemy(player, run, def, stage, base, { Patron = patron })
		if patron then
			-- Butin annoncé (chances affichées).
			local lines = { "Butin :" }
			for _, drop in Street.PatronDrops do
				local dropName = if drop.Kind == "Material"
					then string.format("%d %s", drop.Amount, materialName[drop.Id] or drop.Id)
					else (petById[drop.Id] and petById[drop.Id].Name or drop.Id)
				table.insert(lines, string.format("%s (%s %%)", dropName, tostring(drop.Chance * 100):gsub("%.", ",")))
			end
			local loot = PlotService.makeBillboard(
				enemy.Root,
				table.concat(lines, "\n"),
				enemy.Root.Size.Y / 2 + 6,
				Vector2.new(9, 4.5)
			)
			loot.TextColor3 = Color3.fromRGB(255, 220, 120)
		end
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

-- Mort animée : l'ennemi bascule et s'enfonce, puis disparaît (il ne compte déjà plus).
local function deathAnimation(enemy: Enemy)
	local gui = enemy.Label.Parent
	if gui then
		gui:Destroy()
	end
	local root = enemy.Root
	local h = root.Size.Y
	TweenService:Create(root, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = root.CFrame * CFrame.new(0, -h * 0.3, h * 0.15) * CFrame.Angles(math.rad(75), 0, 0),
	}):Play()
	task.delay(0.9, function()
		enemy.Model:Destroy()
	end)
end

local function damageEnemy(player: Player, run: Run, enemy: Enemy, amount: number)
	if enemy.Hp <= 0 then
		return
	end
	enemy.Hp -= amount
	CombatFx:FireClient(player, enemy.Root.Position + Vector3.new(0, 3, 0), amount)
	updateLabel(enemy)
	if enemy.Hp > 0 then
		if enemy.Anim == nil or os.clock() > enemy.AnimStart + enemy.AnimDur then
			play(enemy, "Hurt", 0.2)
		end
		return
	end
	-- Ennemi vaincu : récompenses personnelles.
	local index = table.find(run.Enemies, enemy)
	if index then
		table.remove(run.Enemies, index)
	end
	local deathCf = enemy.Root.CFrame
	deathAnimation(enemy)
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
		-- Gelée épineuse : se divise en petites gelées (une seule fois).
		if enemy.Def.Behavior == "Split" and not enemy.Mini then
			local cfg = Street.Behaviors.Split
			for i = 1, cfg.Count do
				local offset = (i - (cfg.Count + 1) / 2) * 2.5
				local base = CFrame.new(deathCf.Position.X, origin.Position.Y, deathCf.Position.Z)
					* CFrame.new(offset, 0, 0)
					* (deathCf - deathCf.Position)
				local mini = spawnEnemy(player, run, enemy.Def, stage, base, {
					Mini = true,
					HealthMult = cfg.Health,
					RewardMult = cfg.Reward,
					Scale = cfg.Scale,
				})
				mini.LastAttack = os.clock() + 0.8
			end
		end
	end
	publish(player)
	if #run.Enemies == 0 then
		clearStage(player, run)
	end
end

-- Attaque d'un ennemi / coup de zone du patron ---------------------------------------------

local function enemyHits(player: Player, damage: number, unblockable: boolean?)
	if not unblockable and isInvulnerable(player) then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
	end
end

local function groundSpot(position: Vector3): Vector3
	-- Reste dans la rue (une attaque ne vise jamais le vide).
	local along, lateral = streetCoords(position)
	lateral = math.clamp(lateral, -Street.Width / 2 + 1, Street.Width / 2 - 1)
	local p = origin.Position + forward * along + right * lateral
	return Vector3.new(p.X, origin.Position.Y + 0.15, p.Z)
end

-- Zone circulaire annoncée au sol ; dégâts après `delay` si le joueur est dedans.
local function discAttack(player: Player, spot: Vector3, radius: number, delay: number, damage: number, onHit)
	local disc = Models.telegraph(enemiesFolder, spot, radius)
	disc.Transparency = 0.75
	TweenService:Create(disc, TweenInfo.new(delay), { Transparency = 0.15 }):Play()
	task.delay(delay, function()
		disc:Destroy()
		local root = aliveRoot(player)
		if root and flat(root.Position, spot) <= radius then
			enemyHits(player, damage)
			if onHit then
				onHit(root)
			end
		end
	end)
end

-- Zone en ligne (souffle, charge) annoncée au sol.
local function lineAttack(
	player: Player,
	from: Vector3,
	dir: Vector3,
	len: number,
	width: number,
	delay: number,
	damage: number?
)
	local start = Vector3.new(from.X, origin.Position.Y + 0.15, from.Z)
	local center = start + dir * len / 2
	local strip = Instance.new("Part")
	strip.Name = "Telegraph"
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CastShadow = false
	strip.Material = Enum.Material.Neon
	strip.Color = Color3.fromRGB(255, 80, 40)
	strip.Transparency = 0.75
	strip.Size = Vector3.new(width, 0.2, len)
	strip.CFrame = CFrame.lookAt(center, center + dir)
	strip.Parent = enemiesFolder
	TweenService:Create(strip, TweenInfo.new(delay), { Transparency = 0.2 }):Play()
	task.delay(delay + (if damage then 0 else 0.4), function()
		strip:Destroy()
		if not damage then
			return
		end
		local root = aliveRoot(player)
		if root then
			local rel = Vector3.new(root.Position.X - start.X, 0, root.Position.Z - start.Z)
			local along = rel:Dot(dir)
			local lateral = (rel - dir * along).Magnitude
			if along >= 0 and along <= len and lateral <= width / 2 then
				enemyHits(player, damage)
			end
		end
	end)
end

-- Projectile lumineux vers un point (zone d'impact affichée) ; dégâts à l'arrivée.
local function projectile(
	player: Player,
	from: Vector3,
	target: Vector3,
	speed: number,
	radius: number,
	damage: number,
	color: Color3
)
	local spot = groundSpot(target)
	local flight = math.max(0.4, (spot - from).Magnitude / speed)
	local ball = Instance.new("Part")
	ball.Name = "Projectile"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.new(1.4, 1.4, 1.4)
	ball.CFrame = CFrame.new(from)
	ball.Parent = enemiesFolder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Parent = ball
	TweenService:Create(
		ball,
		TweenInfo.new(flight, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(spot + Vector3.new(0, 0.6, 0)) }
	):Play()
	discAttack(player, spot, radius, flight, damage)
	task.delay(flight, function()
		ball:Destroy()
	end)
end

local function patronSlam(player: Player, run: Run, enemy: Enemy, target: Vector3)
	local spot = groundSpot(target)
	play(enemy, "Cast", Street.Patron.SlamTelegraph)
	local disc = Models.telegraph(enemiesFolder, spot, enemy.SlamRadius)
	TweenService:Create(disc, TweenInfo.new(Street.Patron.SlamTelegraph), { Transparency = 0.15 }):Play()
	task.delay(Street.Patron.SlamTelegraph, function()
		disc:Destroy()
		if not table.find(run.Enemies, enemy) then
			return
		end
		play(enemy, "Attack", 0.4)
		local root = aliveRoot(player)
		if root and flat(root.Position, spot) <= enemy.SlamRadius then
			enemyHits(player, enemy.Damage * 2)
		end
	end)
end

-- Ralentit le joueur (ronces) ; la vitesse d'origine est rétablie ensuite.
local function slowPlayer(player: Player, factor: number, seconds: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if humanoid:GetAttribute("BaseSpeed") == nil then
		humanoid:SetAttribute("BaseSpeed", humanoid.WalkSpeed)
	end
	local base = humanoid:GetAttribute("BaseSpeed") :: number
	local token = os.clock()
	humanoid:SetAttribute("SlowToken", token)
	humanoid.WalkSpeed = base * factor
	task.delay(seconds, function()
		if humanoid.Parent and humanoid:GetAttribute("SlowToken") == token then
			humanoid.WalkSpeed = base
		end
	end)
end

-- Repousse le joueur loin de l'ennemi (golem), sans le faire sortir de la rue.
local function knockback(player: Player, from: Vector3, distance: number)
	local root = aliveRoot(player)
	if not root or not player.Character then
		return
	end
	local dir = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else -forward
	local spot = groundSpot(root.Position + dir * distance)
	player.Character:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)) * (root.CFrame - root.Position))
end

-- Attaque spéciale d'un boss.
local function bossSpecial(player: Player, run: Run, enemy: Enemy, root: BasePart, stage: number)
	local sp = Street.Specials
	local special = enemy.Def.Special
	local pos = enemy.Root.Position
	local target = root.Position
	play(enemy, "Cast", 0.9)
	if special == "Summon" then
		local alive = 0
		for _, e in run.Enemies do
			if e.Mini then
				alive += 1
			end
		end
		local def = kindById.ScrapGoblin
		for i = 1, math.min(sp.Summon.Count, sp.Summon.MaxAlive - alive) do
			local base = CFrame.lookAt(
				groundSpot(pos + right * (i * 2 - 3) * 5) - Vector3.new(0, 0.15, 0),
				Vector3.new(target.X, origin.Position.Y, target.Z)
			)
			spawnEnemy(player, run, def, stage, base, { Mini = true, HealthMult = 0.5, RewardMult = 0.25 })
		end
		publish(player)
		Notifier.send(player, enemy.Name .. " appelle des renforts !", "error")
	elseif special == "RootField" or special == "Icefall" then
		local cfg = sp[special]
		for i = 1, cfg.Count do
			local spot = if i == 1
				then groundSpot(target)
				else groundSpot(
					target
						+ Vector3.new(
							rng:NextNumber(-cfg.Spread, cfg.Spread),
							0,
							rng:NextNumber(-cfg.Spread, cfg.Spread)
						)
				)
			discAttack(player, spot, cfg.Radius, cfg.Telegraph + (i - 1) * 0.12, enemy.Damage * cfg.Damage)
		end
	elseif special == "Spit" then
		local cfg = sp.Spit
		for i = 1, cfg.Count do
			local offset = right * (i - (cfg.Count + 1) / 2) * cfg.Spread
			projectile(
				player,
				pos + Vector3.new(0, enemy.Root.Size.Y * 0.4, 0),
				target + offset,
				24,
				cfg.Radius,
				enemy.Damage * cfg.Damage,
				Color3.fromRGB(170, 240, 60)
			)
		end
	elseif special == "Breath" then
		local cfg = sp.Breath
		local dir = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		dir = if dir.Magnitude > 0.1 then dir.Unit else -forward
		lineAttack(player, pos, dir, cfg.Length, cfg.Width, cfg.Telegraph, enemy.Damage * cfg.Damage)
		enemy.Busy = os.clock() + cfg.Telegraph
	elseif special == "Nova" then
		local cfg = sp.Nova
		discAttack(player, groundSpot(pos), cfg.Radius, cfg.Telegraph, enemy.Damage * cfg.Damage)
		enemy.Busy = os.clock() + cfg.Telegraph
		for i = 1, cfg.Rocks do
			task.delay(0.3 * i, function()
				local r = aliveRoot(player)
				if r and table.find(run.Enemies, enemy) then
					projectile(
						player,
						pos + Vector3.new(0, enemy.Root.Size.Y * 0.8, 0),
						r.Position,
						26,
						3.5,
						enemy.Damage,
						Color3.fromRGB(190, 100, 255)
					)
				end
			end)
		end
		Notifier.send(player, "Le Colosse concentre le néant : éloigne-toi !", "error")
	end
end

-- Animation : décalage de pose appliqué au repère de l'ennemi.
local function pose(enemy: Enemy, now: number, moving: boolean): CFrame
	local h = enemy.Root.Size.Y
	local cf = CFrame.identity
	if moving then
		local f = now * (5 + 8 / math.max(1, h / 3)) + enemy.Phase
		cf *= CFrame.new(0, math.abs(math.sin(f)) * math.min(0.6, h * 0.05), 0) * CFrame.Angles(
			0,
			0,
			math.sin(f) * 0.05
		)
	else
		cf *= CFrame.new(0, math.sin(now * 2 + enemy.Phase) * h * 0.012, 0)
	end
	if enemy.Anim and now < enemy.AnimStart + enemy.AnimDur then
		local t = (now - enemy.AnimStart) / enemy.AnimDur
		local k = math.sin(t * math.pi)
		if enemy.Anim == "Attack" then
			cf *= CFrame.new(0, 0, -k * math.min(1.6, h * 0.14)) * CFrame.Angles(-0.3 * k, 0, 0)
		elseif enemy.Anim == "Hurt" then
			cf *= CFrame.Angles(0.16 * k, 0, 0)
		elseif enemy.Anim == "Windup" then
			cf *= CFrame.new(0, -k * h * 0.1, 0.2 * k) * CFrame.Angles(0.22 * k, 0, 0)
		elseif enemy.Anim == "Cast" then
			cf *= CFrame.new(0, k * h * 0.05, 0) * CFrame.Angles(0.18 * k, 0, 0)
		elseif enemy.Anim == "Land" then
			cf *= CFrame.new(0, -k * h * 0.08, 0)
		end
	end
	return cf
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

	-- Ennemis : comportements propres à chaque type, attaques annoncées, animations.
	local B = Street.Behaviors
	local nearest, nearestDist = nil, math.huge
	for _, enemy in table.clone(run.Enemies) do
		if not table.find(run.Enemies, enemy) then
			continue
		end
		local def = enemy.Def
		local pos = enemy.Root.Position
		local h = enemy.Root.Size.Y
		local dist = flat(pos, root.Position)
		local reach = enemy.Root.Size.X * 0.45
		-- Portée : distance de contact + demi-largeur du modèle (les grands boss frappent de loin).
		local range = Street.Enemy.AttackRange + reach
		local groundY = origin.Position.Y
		local from = Vector3.new(pos.X, groundY, pos.Z)
		local target = Vector3.new(root.Position.X, groundY, root.Position.Z)
		local face = target
		local moving = false
		local lift = 0

		local function approach(goal: Vector3, speed: number, stopAt: number)
			local d = flat(from, goal)
			if d > stopAt then
				from += (goal - from).Unit * math.min(speed * dt, d - stopAt)
				moving = true
			end
		end

		local function melee()
			if dist > range then
				approach(target, enemy.Speed, range * 0.9)
			elseif now - enemy.LastAttack >= Street.Enemy.AttackCooldown then
				enemy.LastAttack = now
				play(enemy, "Attack", 0.35)
				enemyHits(player, enemy.Damage, def.Behavior == "Unblockable")
				if def.Behavior == "Knockback" then
					knockback(player, pos, B.Knockback.Distance)
				end
			end
		end

		if enemy.Leap then
			-- Bond en arc vers la zone visée (araignée).
			local t = math.clamp((now - enemy.Leap.Start) / B.Leap.Time, 0, 1)
			from = enemy.Leap.From:Lerp(enemy.Leap.To, t)
			lift = math.sin(t * math.pi) * 4
			face = enemy.Leap.To + (enemy.Leap.To - enemy.Leap.From)
			if t >= 1 then
				local landing = enemy.Leap.To
				enemy.Leap = nil
				play(enemy, "Land", 0.25)
				if flat(root.Position, landing) <= B.Leap.Radius then
					enemyHits(player, enemy.Damage * B.Leap.Damage)
				end
			end
		elseif enemy.Charge then
			-- Charge en ligne droite (loup).
			from += enemy.Charge.Dir * enemy.Speed * B.Charge.SpeedMult * dt
			from = groundSpot(from) - Vector3.new(0, 0.15, 0)
			face = from + enemy.Charge.Dir
			moving = true
			if not enemy.Charge.Hit and flat(root.Position, from) <= reach + 2.5 then
				enemy.Charge.Hit = true
				enemyHits(player, enemy.Damage * B.Charge.Damage)
			end
			if now >= enemy.Charge.Until then
				enemy.Charge = nil
			end
		elseif enemy.PendingLeap and now >= enemy.PendingLeap.At then
			enemy.Leap = { From = from, To = enemy.PendingLeap.To, Start = now }
			enemy.PendingLeap = nil
		elseif enemy.PendingCharge and now >= enemy.PendingCharge.At then
			local dist0 = B.Charge.MaxRange + 4
			enemy.Charge =
				{ Dir = enemy.PendingCharge.Dir, Until = now + dist0 / (enemy.Speed * B.Charge.SpeedMult), Hit = false }
			enemy.PendingCharge = nil
		elseif now < enemy.Busy then
			face = if enemy.PendingCharge then from + enemy.PendingCharge.Dir else target
		elseif def.Behavior == "Ranged" then
			-- Garde ses distances et lance des boules de braise.
			local cfg = B.Ranged
			if dist < cfg.Near then
				local away = from + (from - target).Unit * 4
				approach(groundSpot(away) - Vector3.new(0, 0.15, 0), enemy.Speed, 0.5)
			elseif dist > cfg.Far then
				approach(target, enemy.Speed, cfg.Far * 0.9)
			elseif now >= enemy.NextAbility then
				enemy.NextAbility = now + cfg.Cooldown
				play(enemy, "Cast", 0.5)
				projectile(
					player,
					pos + Vector3.new(0, h * 0.35, 0),
					root.Position,
					cfg.ProjectileSpeed,
					cfg.Radius,
					enemy.Damage * cfg.Damage,
					Color3.fromRGB(255, 140, 40)
				)
			end
		elseif
			def.Behavior == "Leap"
			and dist >= B.Leap.MinRange
			and dist <= B.Leap.MaxRange
			and now >= enemy.NextAbility
		then
			enemy.NextAbility = now + B.Leap.Cooldown
			local spot = groundSpot(root.Position)
			enemy.PendingLeap = { To = spot - Vector3.new(0, 0.15, 0), At = now + B.Leap.Windup }
			enemy.Busy = now + B.Leap.Windup
			play(enemy, "Windup", B.Leap.Windup)
			discAttack(player, spot, B.Leap.Radius, B.Leap.Windup + B.Leap.Time, 0)
		elseif
			def.Behavior == "Charge"
			and dist >= B.Charge.MinRange
			and dist <= B.Charge.MaxRange
			and now >= enemy.NextAbility
		then
			enemy.NextAbility = now + B.Charge.Cooldown
			local dir = (target - from).Unit
			enemy.PendingCharge = { Dir = dir, At = now + B.Charge.Windup }
			enemy.Busy = now + B.Charge.Windup
			play(enemy, "Windup", B.Charge.Windup)
			lineAttack(player, from, dir, B.Charge.MaxRange + 4, B.Charge.Width, B.Charge.Windup, nil)
		else
			if def.Behavior == "Roots" and now >= enemy.NextAbility then
				enemy.NextAbility = now + B.Roots.Cooldown
				play(enemy, "Cast", 0.5)
				discAttack(
					player,
					groundSpot(root.Position),
					B.Roots.Radius,
					B.Roots.Telegraph,
					enemy.Damage * B.Roots.Damage,
					function()
						slowPlayer(player, B.Roots.Slow, B.Roots.SlowSeconds)
						Notifier.send(player, "Pris dans les ronces : ralenti !", "error")
					end
				)
			end
			melee()
		end

		local look = Vector3.new(face.X, from.Y, face.Z)
		local base = if (look - from).Magnitude > 0.1
			then CFrame.lookAt(from, look)
			else (enemy.Root.CFrame - enemy.Root.Position) + from
		enemy.Model:PivotTo(base * CFrame.new(0, h / 2 + lift, 0) * pose(enemy, now, moving))

		if enemy.Patron and not enemy.Leap and not enemy.Charge then
			if now >= enemy.NextSlam then
				enemy.NextSlam = now + Street.Patron.SlamEvery + Street.Patron.SlamTelegraph
				patronSlam(player, run, enemy, root.Position)
			elseif def.Special and now >= enemy.NextSpecial then
				enemy.NextSpecial = now + Street.Specials.Every
				enemy.NextSlam = math.max(enemy.NextSlam, now + 2.5)
				bossSpecial(player, run, enemy, root, stage)
			end
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
	-- Salle mystique fermée (sous la carte) : murs et plafond en faux ciel étoilé.
	Models.mysticHall(origin, Street.Hall, Color3.fromRGB(255, 110, 90), geometry, 7)
	local hall = Street.Hall
	Diagnostics.addSafeZone(
		origin * CFrame.new(0, (hall.Floor + hall.Height) / 2, (hall.Front + hall.Back) / 2),
		Vector3.new(hall.HalfWidth * 2 + 8, hall.Height - hall.Floor + 8, hall.Front - hall.Back + 8)
	)
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
