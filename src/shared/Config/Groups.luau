--[[
	Rôles et permissions des groupes (cahier §4). Module pur.

	Build   : acheter des constructions prédéfinies, placer des objets
	Spend   : dépenser les matériaux communs
	Invite  : inviter un joueur
	Manage  : exclure un membre, transférer l'administration, supprimer des éléments importants
	Move    : déplacer des objets placés (placement libre, étape 2)
]]

return {
	Roles = {
		Admin = { Build = true, Spend = true, Invite = true, Manage = true, Move = true },
		Member = { Build = true, Spend = true, Invite = false, Manage = false, Move = false },
	},
	DefaultRole = "Member",
}
