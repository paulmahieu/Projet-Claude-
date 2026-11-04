--[[
	Défense du bastion (cahier §7). Module pur.
	Déclenchée volontairement par un membre autorisé (permission Build) depuis le Noyau.
	Les ennemis réutilisent les types et la croissance de la Rue des boss (Config/Street).
	Défaite : la défense s'arrête, le Noyau se répare ; aucune construction n'est détruite.
]]

return {
	Waves = 3,
	PrepSeconds = 10, -- avertissement avant la première vague
	BetweenWaves = 6,
	CooldownSeconds = 240, -- après une victoire ou une défaite
	AbandonSeconds = 20, -- plus aucun membre dans le bastion : défense annulée sans pénalité
	CoreHealthPerLevel = 500, -- PV du Noyau = valeur x niveau du bastion
	CoreDamageMult = 1, -- dégâts d'un ennemi sur le Noyau = dégâts normaux x ce facteur
	-- Étape « équivalente » de la Rue pour la difficulté : 1 + (niveau du bastion - 1) x 2 + (vague - 1)
	StagePerBastionLevel = 2,
	WaveBase = 3, -- ennemis par vague : WaveBase + vague, + 1 par membre présent au-delà du premier
	Rewards = {
		Group = { Wood = 30, Stone = 20 }, -- x niveau du bastion
		TrophiesPerLevel = 5, -- par participant, x niveau du bastion
		GoldEnemyMult = 10, -- or par participant = or d'un ennemi x ce facteur
	},
}
