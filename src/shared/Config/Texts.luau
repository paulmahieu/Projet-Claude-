--[[
	Textes affichés aux joueurs, centralisés pour une traduction ultérieure (cahier §2).
	Les messages à paramètres utilisent string.format.
]]

return {
	Welcome = "Bienvenue ! Bouton « Mon bastion » pour rejoindre ta base, puis récolte du bois pour construire le terrain d'entraînement.",
	Loading = "Chargement de ta progression...",
	LoadError = "Impossible de charger ta progression pour l'instant. Nouvel essai automatique...",
	GroupRemote = "Ton bastion est ouvert sur un autre serveur. Nouvel essai automatique... (Menu > Groupe > « Rejoindre mon bastion » pour aller sur ce serveur)",
	GroupError = "Le bastion n'a pas pu être chargé. Nouvel essai automatique...",
	NoPlot = "Aucune parcelle libre sur ce serveur : ton bastion n'est pas affiché ici.",
	ReadOnly = "Connexion aux sauvegardes perdue : modifications suspendues.",
	StudioMemory = "Mode test Studio : rien n'est sauvegardé.",

	NotMember = "Tu n'es pas membre de ce bastion.",
	NoPermission = "Ton rôle ne permet pas cette action.",
	NotEnough = "Il manque : %s.",
	Built = "%s construit !",
	Harvested = "+%d %s pour le bastion",
	NodeDepleted = "Déjà récolté, repousse bientôt.",

	TrainingStart = "Entraînement commencé.",
	TrainingStop = "Entraînement arrêté.",
	TrainingBusy = "Ce tapis est occupé.",
	LevelUp = "Niveau %d ! Puissance %d",

	UpgradeBought = "%s niveau %d !",
	UpgradeMax = "Niveau maximum atteint.",
	NotEnoughGold = "Il te manque %s or.",

	OfflineRecap = "Pendant ton absence (%s) : +%s XP et +%s or (25 %% du rendement des tapis).",

	InviteSent = "Invitation envoyée à %s.",
	InviteReceived = "%s t'invite dans « %s ». Ouvre le menu Groupe pour répondre.",
	InviteExpired = "Invitation expirée.",
	GroupFull = "Le groupe est complet.",
	JoinedGroup = "Tu as rejoint « %s » !",
	MemberJoined = "%s a rejoint le bastion.",
	LeftGroup = "Tu as quitté le groupe. Un nouveau bastion t'a été attribué.",
	Kicked = "Tu as été retiré du groupe « %s ».",
	AdminFirst = "Transfère d'abord le rôle d'administrateur à un autre membre.",
	AdminTransferred = "%s est maintenant administrateur.",
	ConfirmNeeded = "Confirmation requise.",

	ShopDisabled = "Article indisponible pour le moment.",
	PurchaseThanks = "Merci ! %s : livré.",
	TooFast = "Doucement !",
	TooFar = "Approche-toi davantage.",
	NotYourBase = "Ce n'est pas ton bastion.",
}
