--[[
	Règles d'appartenance aux groupes (cahier §4). Module pur, testé.

	Invariant : un joueur est membre du groupe G si et seulement si
	  profil.GroupId == G  ET  G.Members[userId].Status == "Active".
	Le profil est la référence en cas de désaccord : une entrée dans un groupe que le profil
	ne désigne pas est un « fantôme » nettoyé dès que possible (voir docs/ARCHITECTURE.md).

	Adhésion (A -> B), toutes deux chargées sur ce serveur :
	  1. B.Members[u] = Pending ; sauvegarde de B         (échec -> abandon, rien n'a changé)
	  2. profil.GroupId = B ; sauvegarde du profil         (échec -> retrait de B, abandon)
	  3. B.Members[u] = Active ; A.Members[u] = nil ; sauvegardes
	Une interruption après 2 laisse « Pending » dans B : au prochain chargement, le profil
	désigne B, donc l'entrée est promue Active. Une interruption entre 1 et 2 laisse un
	Pending que le profil ne confirme pas : il ne donne aucun droit et peut être retiré.
]]

local Membership = {}

function Membership.key(userId: number): string
	return tostring(userId)
end

function Membership.entry(group, userId: number)
	return group.Members[Membership.key(userId)]
end

function Membership.isActive(group, userId: number): boolean
	local e = Membership.entry(group, userId)
	return e ~= nil and e.Status == "Active"
end

function Membership.role(group, userId: number): string?
	local e = Membership.entry(group, userId)
	return if e and e.Status == "Active" then e.Role else nil
end

function Membership.can(groupsCfg, group, userId: number, permission: string): boolean
	local role = Membership.role(group, userId)
	local perms = role and groupsCfg.Roles[role]
	return perms ~= nil and perms[permission] == true
end

-- Nombre de places occupées (Pending compris, pour ne jamais dépasser la taille max).
function Membership.count(group): number
	local n = 0
	for _ in group.Members do
		n += 1
	end
	return n
end

function Membership.activeCount(group): number
	local n = 0
	for _, e in group.Members do
		if e.Status == "Active" then
			n += 1
		end
	end
	return n
end

-- Résout l'état d'un joueur à son chargement (profil -> groupe).
-- Retourne "member" | "promote" (Pending confirmé par le profil) | "notMember".
function Membership.resolveOnLoad(group, userId: number): string
	if not group or group.Abandoned then
		return "notMember"
	end
	local e = Membership.entry(group, userId)
	if not e then
		return "notMember"
	end
	if e.Status == "Pending" then
		return "promote"
	end
	return "member"
end

-- Un joueur peut-il quitter son groupe ? Retourne ok, raison.
-- Un administrateur doit transférer son rôle si d'autres membres actifs restent.
function Membership.canLeave(group, userId: number): (boolean, string?)
	if not Membership.isActive(group, userId) then
		return false, "NotMember"
	end
	if Membership.role(group, userId) == "Admin" and Membership.activeCount(group) > 1 then
		return false, "AdminFirst"
	end
	return true, nil
end

-- Retire un membre. Si plus aucun membre actif : le groupe est abandonné (règle déterministe
-- du dernier membre : constructions et matériaux restent dans l'enregistrement, inactif).
function Membership.remove(group, userId: number)
	group.Members[Membership.key(userId)] = nil
	if Membership.activeCount(group) == 0 then
		group.Abandoned = true
	end
end

function Membership.canInvite(
	groupsCfg,
	group,
	inviterId: number,
	targetId: number,
	maxSize: number
): (boolean, string?)
	if not Membership.can(groupsCfg, group, inviterId, "Invite") then
		return false, "NoPermission"
	end
	if Membership.entry(group, targetId) then
		return false, "AlreadyMember"
	end
	if Membership.count(group) >= maxSize then
		return false, "Full"
	end
	return true, nil
end

-- Transfert d'administration : la cible devient Admin, l'ancien admin devient Member.
function Membership.transferAdmin(groupsCfg, group, fromId: number, toId: number): (boolean, string?)
	if Membership.role(group, fromId) ~= "Admin" then
		return false, "NoPermission"
	end
	if not Membership.isActive(group, toId) or fromId == toId then
		return false, "NotMember"
	end
	Membership.entry(group, toId).Role = "Admin"
	Membership.entry(group, fromId).Role = groupsCfg.DefaultRole
	return true, nil
end

return Membership
