--[[
	Combat (cahier §6). Valeurs décidées par le SERVEUR. Module pur.
	Dégâts d'un coup = Puissance x multiplicateur x (1 + bonus des compagnons).
]]

return {
	AutoAttack = { Range = 14, Cooldown = 1.0, DamageMult = 1 },
	Skills = {
		Strike = { Name = "Frappe runique", Cooldown = 6, Range = 18, DamageMult = 5 },
		Dodge = { Name = "Esquive", Cooldown = 3, Invulnerable = 0.6 },
	},
	PlayerMaxHealth = 100, -- + Robustesse
}
