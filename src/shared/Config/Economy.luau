--[[
	Économie globale. Tous les chiffres sont des valeurs de prototype, à équilibrer.
	Module pur (aucune API Roblox) : testable avec Lune.
]]

return {
	StartingGold = 50,

	-- Plafond de sécurité : évite les débordements et les valeurs absurdes en cas de bug.
	GoldCap = 1e15,

	-- Bonus de production par niveau d'entraînement (0.01 = +1 % par niveau).
	-- Relie l'entraînement AFK à la progression du tycoon.
	IncomeBonusPerLevel = 0.01,

	Offline = {
		-- Durée maximale prise en compte (8 h). Incite à revenir sans punir les absences.
		MaxSeconds = 8 * 3600,
		-- Fraction de la production en ligne accordée hors ligne.
		Rate = 0.5,
		-- En dessous de cette absence, on ne verse rien (évite le farm par reconnexion).
		MinSeconds = 60,
	},

	Save = {
		AutosaveSeconds = 120,
		-- Un verrou de session plus vieux que ça est considéré comme abandonné (serveur planté).
		LockTimeoutSeconds = 600,
	},
}
