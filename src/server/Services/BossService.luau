--[[
	BossService : arènes de boss accessibles par des portails au hub (cahier §6).

	- Le serveur décide de tout : PV, dégâts, recharges, invulnérabilité d'esquive, récompenses.
	- Attaque automatique : à portée du boss, le personnage frappe à cadence limitée.
	- Compétences : Frappe runique (dégâts x5, recharge) et Esquive (invulnérabilité brève).
	- Le boss annonce ses attaques par un disque rouge au sol avant l'impact ; 2 phases
	  (plus rapide et nouvelle attaque sous 50 % de PV).
	- PV figés au début du combat selon le nombre de participants présents (règle stable).
	- Récompenses : personnelles pour chaque participation validée (dégâts >= seuil),
	  matériaux du groupe UNE fois par groupe et par victoire (pas de multiplication par membre).
	- Arène vide pendant 8 s : le boss se remet à zéro. Victoire : réapparition après un délai.
	- Après une défaite, le joueur réapparaît dans son bastion (zone sûre) sans rien perdre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Bosses = require(Shared.Config.Bosses)
local Combat = require(Shared.Config.Combat)
local Pets = require(Shared.Config.Pets)
local Training = require(Shared.Config.Training)
local Economy = require(Shared.Config.Economy)
local Materials = require(Shared.Config.Materials)

local ProfileService = require(script.Parent.ProfileService)
local GroupService = require(script.Parent.GroupService)
local PlotService = require(script.Parent.PlotService)
local Notifier = require(script.Parent.Notifier)
local Models = require(script.Parent.Parent.Art.Models)

local CombatFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx") :: RemoteEvent

local BossService = {}

local FLOOR_Y = 1.2
local EMPTY_RESET_SECONDS = 8
local TICK = 0.1

type Arena = {
	Def: any,
	Center: Vector3,
	Folder: Folder,
	Model: Model?,
	Root: BasePart?,
	HpLabel: TextLabel?,
	PortalLabel: TextLabel,
	State: string, -- "Dead" | "Idle" | "Fighting"
	Hp: number,
	MaxHp: number,
	Phase: number,
	FightId: number,
	RespawnAt: number,
	NextAttackAt: number,
	EmptySince: number?,
	Damage: { [number]: number },
	Entrance: CFrame,
}

local arenas: { Arena } = {}
local lastAuto: { [Player]: number } = {}
local skillReady: { [Player]: { [string]: number } } = {}
local invulnerableUntil: { [Player]: number } = {}

local materialName = {}
for _, mat in Materials do
	materialName[mat.Id] = mat.Name
end

local function color(rgb): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
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

local function playersInside(arena: Arena): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if
			root
			and flatDistance(root.Position, arena.Center) <= arena.Def.ArenaRadius + 4
			and math.abs(root.Position.Y - arena.Center.Y) < 60
		then
			table.insert(list, player)
		end
	end
	return list
end

local function arenaOf(player: Player): Arena?
	local root = aliveRoot(player)
	if not root then
		return nil
	end
	for _, arena in arenas do
		if flatDistance(root.Position, arena.Center) <= arena.Def.ArenaRadius + 4 then
			return arena
		end
	end
	return nil
end

local function petMult(player: Player): number
	return Formulas.petMultiplier(Pets, ProfileService.equippedPetIds(player))
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Boss : apparition, combat, remise à zéro -------------------------------------------------

local function updateHpLabel(arena: Arena)
	if arena.HpLabel then
		arena.HpLabel.Text = string.format(
			"%s\n%s / %s PV",
			arena.Def.Name,
			Formulas.formatNumber(math.max(arena.Hp, 0)),
			Formulas.formatNumber(arena.MaxHp)
		)
	end
end

local function spawnBoss(arena: Arena)
	local base = CFrame.new(arena.Center + Vector3.new(0, FLOOR_Y, 0))
	local model, root = Models.boss(arena.Def, base)
	model.Parent = arena.Folder
	arena.Model, arena.Root = model, root
	arena.HpLabel = PlotService.makeBillboard(root, "", 11, Vector2.new(14, 3))
	arena.State = "Idle"
	arena.MaxHp = Formulas.bossHealth(arena.Def, 1)
	arena.Hp = arena.MaxHp
	arena.Phase = 1
	arena.Damage = {}
	arena.FightId += 1
	updateHpLabel(arena)
end

local function resetFight(arena: Arena)
	arena.State = "Idle"
	arena.FightId += 1 -- annule les attaques en attente
	arena.MaxHp = Formulas.bossHealth(arena.Def, 1)
	arena.Hp = arena.MaxHp
	arena.Phase = 1
	arena.Damage = {}
	arena.EmptySince = nil
	updateHpLabel(arena)
end

local function startFight(arena: Arena, inside: { Player })
	arena.State = "Fighting"
	arena.FightId += 1
	arena.MaxHp = Formulas.bossHealth(arena.Def, #inside) -- figé pour tout le combat
	arena.Hp = arena.MaxHp
	arena.Phase = 1
	arena.Damage = {}
	arena.NextAttackAt = os.clock() + 2.5
	updateHpLabel(arena)
	for _, player in inside do
		Notifier.send(
			player,
			string.format(
				"Combat : %s ! Puissance conseillée %d. Évite les zones rouges (esquive : Q).",
				arena.Def.Name,
				arena.Def.RecommendedPower
			),
			"info"
		)
	end
end

local function grantRewards(arena: Arena)
	local def = arena.Def
	local valid = Formulas.validParticipants(arena.Damage, arena.MaxHp, def.ParticipationRatio)
	local rewardedGroups = {}
	for _, userId in valid do
		local player = Players:GetPlayerByUserId(userId)
		local profile = player and ProfileService.get(player)
		if player and profile and ProfileService.canMutate(player) then
			profile.Gold = Formulas.clamp(profile.Gold + def.Rewards.Personal.Gold, Economy.GoldCap)
			profile.Level, profile.TrainXp =
				Formulas.addXp(profile.Level, profile.TrainXp, def.Rewards.Personal.Xp, Training)
			profile.BossKills[def.Id] = (profile.BossKills[def.Id] or 0) + 1
			ProfileService.sync(player)
			Notifier.send(
				player,
				string.format(
					"Victoire contre %s ! +%s or, +%s XP",
					def.Name,
					Formulas.formatNumber(def.Rewards.Personal.Gold),
					Formulas.formatNumber(def.Rewards.Personal.Xp)
				),
				"reward"
			)
			-- Butin commun : une seule fois par groupe et par victoire.
			local group = GroupService.groupOf(player)
			if group and not rewardedGroups[group.Id] and GroupService.canMutate(group) then
				rewardedGroups[group.Id] = true
				local parts = {}
				for matId, amount in def.Rewards.Group do
					local mats = group.Data.Materials
					mats[matId] = Formulas.clamp((mats[matId] or 0) + amount, Economy.MaterialCap)
					table.insert(parts, string.format("+%d %s", amount, materialName[matId] or matId))
				end
				GroupService.markChanged(group)
				for member in group.Online do
					Notifier.send(member, "Butin du bastion : " .. table.concat(parts, ", "), "reward")
				end
			end
		end
	end
	for userId in arena.Damage do
		if not table.find(valid, userId) then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				Notifier.send(player, "Participation trop faible pour une récompense : frappe davantage !", "info")
			end
		end
	end
end

local function defeat(arena: Arena)
	arena.State = "Dead"
	arena.FightId += 1
	arena.RespawnAt = os.clock() + arena.Def.RespawnSeconds
	grantRewards(arena)
	if arena.Model then
		arena.Model:Destroy()
		arena.Model, arena.Root, arena.HpLabel = nil, nil, nil
	end
end

local function applyDamage(arena: Arena, player: Player, amount: number)
	if arena.State ~= "Fighting" or not arena.Root then
		return
	end
	local dealt = math.min(amount, arena.Hp)
	arena.Hp -= dealt
	arena.Damage[player.UserId] = (arena.Damage[player.UserId] or 0) + dealt
	CombatFx:FireClient(player, arena.Root.Position + Vector3.new(math.random(-3, 3), 6, math.random(-3, 3)), amount)
	if arena.Phase == 1 and arena.Hp <= arena.MaxHp / 2 then
		arena.Phase = 2
		for _, p in playersInside(arena) do
			Notifier.send(p, arena.Def.Name .. " s'enrage !", "error")
		end
	end
	updateHpLabel(arena)
	if arena.Hp <= 0 then
		defeat(arena)
	end
end

-- Attaques du boss (annoncées) ---------------------------------------------------------

local function bossAttack(arena: Arena, inside: { Player })
	local eligible = {}
	for _, attack in arena.Def.Attacks do
		if (attack.Phase or 1) <= arena.Phase then
			table.insert(eligible, attack)
		end
	end
	local attack = eligible[math.random(1, #eligible)]
	local groundY = arena.Center.Y + FLOOR_Y + 0.2
	local spots: { Vector3 } = {}
	local function onGround(v: Vector3): Vector3
		return Vector3.new(v.X, groundY, v.Z)
	end
	if attack.Shape == "Around" and arena.Root then
		table.insert(spots, onGround(arena.Root.Position))
	elseif attack.Shape == "Target" then
		local target = aliveRoot(inside[math.random(1, #inside)])
		if target then
			table.insert(spots, onGround(target.Position))
		end
	else
		for i = 1, attack.Count do
			local target = aliveRoot(inside[((i - 1) % #inside) + 1])
			local origin = if target and i <= #inside then target.Position else arena.Center
			local spread = if target and i <= #inside then 0 else arena.Def.ArenaRadius * 0.6
			local angle = math.random() * math.pi * 2
			table.insert(
				spots,
				onGround(origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * spread * math.random())
			)
		end
	end

	local parts = {}
	for _, spot in spots do
		local disc = Models.telegraph(arena.Folder, spot, attack.Radius)
		TweenService:Create(disc, TweenInfo.new(attack.Telegraph), { Transparency = 0.15 }):Play()
		table.insert(parts, disc)
	end

	local fightId = arena.FightId
	task.delay(attack.Telegraph, function()
		for _, disc in parts do
			disc:Destroy()
		end
		if arena.FightId ~= fightId or arena.State ~= "Fighting" then
			return
		end
		local now = os.clock()
		for _, player in playersInside(arena) do
			local root = aliveRoot(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and (invulnerableUntil[player] or 0) < now then
				for _, spot in spots do
					if flatDistance(root.Position, spot) <= attack.Radius then
						humanoid:TakeDamage(attack.Damage)
						break
					end
				end
			end
		end
	end)
	arena.NextAttackAt = os.clock() + attack.Telegraph + arena.Def.AttackInterval[arena.Phase]
end

-- Boucle -----------------------------------------------------------------------------------

local function tickArena(arena: Arena, now: number)
	if arena.State == "Dead" then
		if now >= arena.RespawnAt then
			spawnBoss(arena)
		end
		return
	end
	local inside = playersInside(arena)
	if arena.State == "Idle" then
		if #inside > 0 then
			startFight(arena, inside)
		end
		return
	end

	-- Combat en cours
	if #inside == 0 then
		arena.EmptySince = arena.EmptySince or now
		if now - (arena.EmptySince :: number) > EMPTY_RESET_SECONDS then
			resetFight(arena)
		end
		return
	end
	arena.EmptySince = nil

	local root = arena.Root :: BasePart
	-- Le boss se tourne vers le joueur le plus proche.
	local nearest, nearestDist = nil, math.huge
	for _, player in inside do
		local pr = aliveRoot(player)
		if pr then
			local d = flatDistance(pr.Position, root.Position)
			if d < nearestDist then
				nearest, nearestDist = pr, d
			end
		end
	end
	if nearest and arena.Model then
		local from = root.Position
		local look = Vector3.new(nearest.Position.X, from.Y, nearest.Position.Z)
		if (look - from).Magnitude > 0.5 then
			arena.Model:PivotTo(CFrame.lookAt(from, look))
		end
	end

	-- Attaques automatiques des joueurs à portée.
	for _, player in inside do
		local pr = aliveRoot(player)
		if
			pr
			and flatDistance(pr.Position, root.Position) <= Combat.AutoAttack.Range
			and (lastAuto[player] or 0) + Combat.AutoAttack.Cooldown <= now
		then
			lastAuto[player] = now
			applyDamage(
				arena,
				player,
				Formulas.hitDamage(ProfileService.power(player), Combat.AutoAttack.DamageMult, petMult(player))
			)
			if arena.State ~= "Fighting" then
				return
			end
		end
	end

	if now >= arena.NextAttackAt then
		bossAttack(arena, inside)
	end
end

local function publish(arena: Arena, now: number)
	local folder = arena.Folder
	folder:SetAttribute("State", arena.State)
	folder:SetAttribute("Hp", math.max(0, math.floor(arena.Hp)))
	folder:SetAttribute("MaxHp", arena.MaxHp)
	folder:SetAttribute("Phase", arena.Phase)
	local respawnIn = if arena.State == "Dead" then math.max(0, arena.RespawnAt - now) else 0
	folder:SetAttribute("RespawnIn", math.ceil(respawnIn))
	local status = if arena.State == "Fighting"
		then "Combat en cours !"
		elseif arena.State == "Dead" then "Prochain combat dans " .. formatTime(respawnIn)
		else "Le boss attend !"
	arena.PortalLabel.Text =
		string.format("%s\nPuissance conseillée %d\n%s", arena.Def.Name, arena.Def.RecommendedPower, status)
end

-- Compétences (demandées par le client, décidées par le serveur) ---------------------------

function BossService.useSkill(player: Player, skillId: string)
	local skill = Combat.Skills[skillId]
	if not skill then
		return { ok = false }
	end
	local now = os.clock()
	local ready = skillReady[player]
	if not ready then
		ready = {}
		skillReady[player] = ready
	end
	if (ready[skillId] or 0) > now then
		return { ok = false, cooldown = ready[skillId] - now }
	end
	if skillId == "Dodge" then
		if not aliveRoot(player) then
			return { ok = false }
		end
		ready[skillId] = now + skill.Cooldown
		invulnerableUntil[player] = now + skill.Invulnerable
		return { ok = true, cooldown = skill.Cooldown }
	end

	-- Frappe runique : seulement en combat, à portée du boss.
	local arena = arenaOf(player)
	local root = aliveRoot(player)
	if not arena or arena.State ~= "Fighting" or not arena.Root or not root then
		return { ok = false, msg = "Aucun boss à portée." }
	end
	if flatDistance(root.Position, arena.Root.Position) > skill.Range then
		return { ok = false, msg = "Trop loin du boss." }
	end
	ready[skillId] = now + skill.Cooldown
	applyDamage(arena, player, Formulas.hitDamage(ProfileService.power(player), skill.DamageMult, petMult(player)))
	return { ok = true, cooldown = skill.Cooldown }
end

-- Construction des arènes et portails -------------------------------------------------------

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character and aliveRoot(player) then
		character:PivotTo(cf)
	end
end

function BossService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Arenas"
	folder.Parent = PlotService.world()

	for _, def in Bosses do
		local center = Vector3.new(def.Arena[1], 0, def.Arena[2])
		local accent = color(def.Colors.Accent)
		local arenaFolder = Instance.new("Folder")
		arenaFolder.Name = def.Id
		arenaFolder:SetAttribute("BossName", def.Name)
		arenaFolder:SetAttribute("RecommendedPower", def.RecommendedPower)
		arenaFolder:SetAttribute("CenterX", center.X)
		arenaFolder:SetAttribute("CenterZ", center.Z)
		arenaFolder:SetAttribute("Radius", def.ArenaRadius)
		arenaFolder.Parent = folder
		Models.arena(CFrame.new(center), def.ArenaRadius, accent, arenaFolder)

		-- Portail de retour, au bord de l'arène.
		local backPos = center + Vector3.new(0, FLOOR_Y, def.ArenaRadius - 6)
		local backModel, backVeil = Models.portal(CFrame.lookAt(backPos, center + Vector3.new(0, FLOOR_Y, 0)), accent)
		backModel.Name = "ReturnPortal"
		backModel.Parent = arenaFolder
		PlotService.makeBillboard(backVeil, "Retour au bastion", 7, Vector2.new(10, 1.6))
		local backPrompt = Instance.new("ProximityPrompt")
		backPrompt.ActionText = "Retour au bastion"
		backPrompt.ObjectText = "Portail"
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

		-- Portail d'entrée, au hub.
		local portalPos = Vector3.new(def.Portal[1], 1, def.Portal[2])
		local portalModel, veil = Models.portal(CFrame.lookAt(portalPos, Vector3.new(0, 1, 0)), accent)
		portalModel.Name = "Portal_" .. def.Id
		portalModel.Parent = arenaFolder
		local label = PlotService.makeBillboard(veil, def.Name, 8, Vector2.new(12, 3.6))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Entrer dans l'arène"
		prompt.ObjectText = def.Name
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.Parent = veil

		local entrance = CFrame.lookAt(
			center + Vector3.new(0, FLOOR_Y + 3, def.ArenaRadius - 16),
			center + Vector3.new(0, FLOOR_Y + 3, 0)
		)
		local arena: Arena = {
			Def = def,
			Center = center,
			Folder = arenaFolder,
			Model = nil,
			Root = nil,
			HpLabel = nil,
			PortalLabel = label,
			State = "Dead",
			Hp = 0,
			MaxHp = Formulas.bossHealth(def, 1),
			Phase = 1,
			FightId = 0,
			RespawnAt = 0, -- apparaît dès le démarrage
			NextAttackAt = 0,
			EmptySince = nil,
			Damage = {},
			Entrance = entrance,
		}
		prompt.Triggered:Connect(function(player)
			teleport(player, arena.Entrance)
		end)
		table.insert(arenas, arena)
	end
end

function BossService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastAuto[player] = nil
		skillReady[player] = nil
		invulnerableUntil[player] = nil
	end)

	task.spawn(function()
		local lastPublish = 0
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, arena in arenas do
				local ok, err = pcall(tickArena, arena, now)
				if not ok then
					warn("[BossService] " .. tostring(err))
				end
			end
			if now - lastPublish >= 0.25 then
				lastPublish = now
				for _, arena in arenas do
					publish(arena, now)
				end
				-- Indique au client dans quelle arène se trouve chaque joueur (interface de combat).
				for _, player in Players:GetPlayers() do
					local arena = arenaOf(player)
					local id = if arena then arena.Def.Id else ""
					if player:GetAttribute("InArena") ~= id then
						player:SetAttribute("InArena", id)
					end
				end
			end
		end
	end)
end

return BossService
