--[[
	Renaissance FACULTATIVE (demandée par le créateur le 04/11/2026 ; le cahier §2 excluait
	une renaissance « imposée » : elle reste un choix du joueur).

	Effets : remet à zéro niveau, XP et or personnels ; conserve améliorations, compagnons,
	groupe et bastion. Donne un multiplicateur permanent (entraînement et Puissance) et débloque
	les tapis supérieurs et des emplacements de compagnon. Plafonnée (pas de croissance infinie).
	Module pur.
]]

return {
	-- Niveau requis pour la renaissance n°(r+1) : Base + PerRebirth x r
	RequiredLevelBase = 15,
	RequiredLevelPerRebirth = 10,

	-- Multiplicateur d'entraînement : 1 + PerRebirth x r  (r = renaissances effectuées)
	MultiplierPerRebirth = 0.25,
	-- Bonus de Puissance : 1 + PowerPerRebirth x r
	PowerPerRebirth = 0.20,
	MaxRebirths = 25, -- plafond : x7,25 au maximum

	ResetGold = true,

	-- Emplacements de compagnons équipés selon le nombre de renaissances (cahier : 1 au départ).
	PetSlots = { { Rebirths = 0, Slots = 1 }, { Rebirths = 1, Slots = 2 }, { Rebirths = 3, Slots = 3 } },
}
