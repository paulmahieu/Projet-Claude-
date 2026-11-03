--[[
	Verrou de session persistant (cahier §10). Module pur, testé.

	Format d'un enregistrement DataStore : { Data = ..., Lock = { JobId, Expires } | nil }

	- acquire : un serveur prend l'autorité si la clé est libre, si le verrou lui appartient
	  déjà ou si le verrou a expiré. `steal` force la prise (profils uniquement : un compte
	  Roblox ne peut pas jouer sur deux serveurs à la fois).
	- canWrite : avant CHAQUE écriture, on vérifie que le verrou nous appartient toujours.
	  Un serveur qui a perdu l'autorité ne peut plus écrire, même après une longue pause.
]]

local SessionLock = {}

function SessionLock.isHeldByOther(old, jobId: string, now: number): boolean
	local lock = type(old) == "table" and old.Lock
	return lock ~= nil and lock ~= false and lock.JobId ~= jobId and (lock.Expires or 0) > now
end

-- Retourne le nouveau verrou, ou nil si un autre serveur détient un verrou valide.
function SessionLock.acquire(old, jobId: string, now: number, lockSeconds: number, steal: boolean?)
	if SessionLock.isHeldByOther(old, jobId, now) and not steal then
		return nil
	end
	return { JobId = jobId, Expires = now + lockSeconds }
end

-- Peut-on écrire ? Oui si personne d'autre n'a pris le verrou depuis.
-- (Si notre verrou a expiré sans que personne ne le prenne, aucune autre copie n'existe :
-- l'écriture est sûre et renouvelle le verrou.)
function SessionLock.canWrite(old, jobId: string): boolean
	local lock = type(old) == "table" and old.Lock
	return not lock or lock.JobId == jobId
end

return SessionLock
