local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local root = process.args[1]
local src = fs.readFile(root .. "/src/server/Art/Models.luau")
local env = setmetatable({
	Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3,
	Color3 = roblox.Color3, Enum = roblox.Enum,
}, { __index = _G })
local Models = luau.load(src, { environment = env, debugName = "Models" })()

local out = {}
local function dump(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			local rx, ry, rz = cf:ToEulerAnglesXYZ()
			local shape = "Block"
			if p.ClassName == "WedgePart" then shape = "Wedge"
			elseif p.ClassName == "Part" then shape = p.Shape.Name end
			if not (p:GetAttribute("Depletable") and false) then
				table.insert(out, {
					s = { p.Size.X, p.Size.Y, p.Size.Z },
					p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
					r = { rx, ry, rz },
					c = { p.Color.R, p.Color.G, p.Color.B },
					shape = shape,
					neon = p.Material.Name == "Neon",
					t = p.Transparency,
				})
			end
		end
	end
end

-- Scène : rangée d'arbres et rochers, tapis, constructions, noyau, socle
local function at(x, z) return roblox.CFrame.new(x, 0, z) end
dump(Models.tree(at(-30, -40), 1, 1))
dump(Models.tree(at(-20, -40), 2, 2))
dump(Models.tree(at(-10, -40), 3, 3))
dump((Models.rock(at(0, -40), 4)))
dump((Models.trainingMat(at(12, -40), 1)))
dump((Models.trainingMat(at(22, -40), 2)))
dump((Models.pedestal(at(32, -40))))
dump((Models.etherCore(at(0, -20))))
local V = roblox.Vector3.new
dump(Models.structure("TrainingGround", at(-22, 0), V(26, 0.4, 14)))
dump(Models.structure("RuneMats", at(22, 0), V(26, 0.4, 14)))
dump(Models.structure("Sawmill", at(-28, 25), V(14, 8, 12)))
dump(Models.structure("Quarry", at(28, 25), V(14, 8, 12)))
dump(Models.structure("Watchtower", at(0, 30), V(8, 22, 8)))
dump(Models.structure("Palisade", at(0, 48), V(86, 8, 2)))
fs.writeFile("parts.json", serde.encode("json", out))
print(#out .. " pièces")
