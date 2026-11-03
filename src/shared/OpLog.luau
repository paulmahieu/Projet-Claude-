--[[
	Journal d'opérations déjà traitées (anti-doublon). Module pur.

	Toute opération unique (reçu d'achat, cadeau quotidien, palier, adhésion...) reçoit un
	identifiant stable, par ex. "receipt:<PurchaseId>" ou "daily:<cycle>:<jour>".
	Il est enregistré DANS LE MÊME enregistrement que le bénéfice accordé : une seule écriture
	rend le crédit et la preuve cohérents. Taille bornée (les plus anciens sont oubliés).

	Pour les opérations qui ne doivent JAMAIS être oubliées (cadeau unique d'un pass),
	utiliser un drapeau dédié dans le profil plutôt que ce journal borné.
]]

local OpLog = {}

function OpLog.has(list, opId: string): boolean
	return table.find(list, opId) ~= nil
end

function OpLog.add(list, opId: string, maxSize: number)
	if OpLog.has(list, opId) then
		return
	end
	table.insert(list, opId)
	while #list > maxSize do
		table.remove(list, 1)
	end
end

return OpLog
