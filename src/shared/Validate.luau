--[[
	Validation des données reçues du client (cahier §11). Module pur.
	Tout ce qui vient d'un RemoteFunction/RemoteEvent est considéré hostile.
]]

local Validate = {}

function Validate.finiteNumber(v): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Validate.positiveInteger(v, max: number): boolean
	return Validate.finiteNumber(v) and v >= 1 and v <= max and math.floor(v) == v
end

-- Identifiant court : lettres, chiffres, tirets et underscores uniquement.
function Validate.id(v, maxLen: number?): boolean
	return type(v) == "string" and #v >= 1 and #v <= (maxLen or 64) and v:match("^[%w_%-]+$") ~= nil
end

function Validate.boolean(v): boolean
	return type(v) == "boolean"
end

return Validate
