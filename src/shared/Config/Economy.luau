--[[
	Économie et sauvegarde. Module pur.
]]

return {
	StartingGold = 0,
	GoldCap = 1e15,
	MaterialCap = 1e9,

	-- Gains hors ligne (cahier §8) :
	--   durée = min(max(maintenant - dernier_instant_comptabilisé, 0), 8 h)
	--   gain  = durée x rendement_AFK_sauvegardé x 0.25
	Offline = {
		MaxSeconds = 8 * 3600,
		Rate = 0.25,
		RecapMinSeconds = 60, -- en dessous, le crédit est appliqué sans afficher de récapitulatif
	},

	Save = {
		-- Sauvegarde périodique, étalée par un délai aléatoire pour répartir les requêtes.
		AutosaveSeconds = 90,
		AutosaveJitter = 30,
		-- Durée de validité d'un verrou ; renouvelé à chaque sauvegarde.
		LockSeconds = 300,
		-- Marge : on arrête les modifications avant l'expiration si le renouvellement échoue.
		LockSafetyMargin = 60,
		MaxOps = 100, -- identifiants d'opérations mémorisés par enregistrement (anti-doublon)
	},
}
