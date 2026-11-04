--[[
	Machines de production du bastion. Module pur.

	- Achetées et améliorées avec les matériaux COMMUNS du groupe, sur les emplacements des
	  extensions (Config/Land).
	- Produisent en continu des matériaux pour le GROUPE.
	- Or personnel : chaque membre du groupe EN LIGNE sur le serveur reçoit un faible
	  pourcentage (PersonalGoldShare) de la valeur en or de chaque machine (décision du
	  porteur du projet). L'or n'est pas produit hors ligne.
	- Hors ligne : les matériaux sont produits au même taux et plafond que l'entraînement
	  (Economy.Offline : 25 %, 8 h), crédités au chargement du bastion.
	- Niveaux 1 à MaxLevel : production x LevelRateMult par niveau ; coût d'amélioration =
	  coût d'achat x UpgradeCostMult ^ (niveau actuel).

	Rate : matériaux par seconde au niveau 1 ; Gold : valeur en or par seconde au niveau 1.
]]

return {
	MaxLevel = 5,
	LevelRateMult = 1.5,
	UpgradeCostMult = 2,
	PersonalGoldShare = 0.10, -- 10 % de la valeur en or de chaque machine, par membre en ligne

	List = {
		{
			Id = "LumberMill",
			Name = "Scierie automatique",
			Material = "Wood",
			Rate = 0.25,
			Gold = 4,
			Cost = { Wood = 120, Stone = 60 },
		},
		{
			Id = "StoneCrusher",
			Name = "Concasseur de pierre",
			Material = "Stone",
			Rate = 0.2,
			Gold = 5,
			Cost = { Wood = 160, Stone = 100 },
		},
		{
			Id = "OreDrill",
			Name = "Foreuse de minerai",
			Material = "Ore",
			Rate = 0.05,
			Gold = 8,
			Cost = { Wood = 400, Stone = 350 },
		},
		{
			Id = "EtherCondenser",
			Name = "Condenseur d'Éther",
			Material = "Crystal",
			Rate = 0.01,
			Gold = 15,
			Cost = { Stone = 900, Ore = 150 },
		},
		{
			Id = "RoyalForge",
			Name = "Forge royale",
			Material = "Ore",
			Rate = 0.08,
			Gold = 40,
			Cost = { Ore = 500, Crystal = 40 },
		},
	},
}
