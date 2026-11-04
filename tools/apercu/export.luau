local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local root = process.args[1]
local src = fs.readFile(root .. "/src/server/Art/Models.luau")
-- Simulacre minimal de `game` : aucun asset importé dans l'aperçu.
local fakeGame = { GetService = function() return { FindFirstChild = function() return nil end } end }
local env = setmetatable({
	Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3,
	Color3 = roblox.Color3, Enum = roblox.Enum, game = fakeGame,
}, { __index = _G })
local Models = luau.load(src, { environment = env, debugName = "Models" })()
local function loadModule(path, name)
	return luau.load(fs.readFile(root .. path), { environment = env, debugName = name })()
end
local function loadData(path, name)
	return luau.load(fs.readFile(root .. path), { debugName = name })()
end
local PetModels = loadModule("/src/shared/PetModels.luau", "PetModels")
local PetsCfg = loadData("/src/shared/Config/Pets.luau", "Pets")
local BossesCfg = loadData("/src/shared/Config/Bosses.luau", "Bosses")

local out = {}
local function dump(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			local rx, ry, rz = cf:ToEulerAnglesXYZ()
			local shape = "Block"
			if p:FindFirstChildOfClass("SpecialMesh") then shape = "Ball" -- ellipsoïde
			elseif p.ClassName == "WedgePart" then shape = "Wedge"
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

-- Scène : choisie par l'argument 2 ("base" ou "v2")
local scene = process.args[2] or "base"
local function at(x, z) return roblox.CFrame.new(x, 0, z) end
local V = roblox.Vector3.new
if scene == "street" then
	local StreetCfg = loadData("/src/shared/Config/Street.luau", "Street")
	local cfg = table.clone(StreetCfg)
	cfg.Sections = 3
	local origin = roblox.CFrame.lookAt(V(0, 0, 0), V(0, 0, -1)) -- la rue part vers -Z
	local holder = roblox.Instance.new("Model")
	Models.street(origin, cfg, holder)
	dump(holder)
	for i, kind in StreetCfg.Kinds do
		dump((Models.enemy(kind, origin * roblox.CFrame.new(-9 + i * 4, 0, -24) * roblox.CFrame.Angles(0, math.pi, 0), kind.Scale, false)))
	end
	dump((Models.enemy(StreetCfg.Kinds[2], origin * roblox.CFrame.new(0, 0, -40) * roblox.CFrame.Angles(0, math.pi, 0), 1, true)))
	-- Porte locale (rendue côté client dans le jeu)
	local gate = roblox.Instance.new("Part")
	gate.Size = V(cfg.Width - 2, 12, 1)
	gate.CFrame = origin * roblox.CFrame.new(0, 6, -cfg.SectionLength * 2)
	gate.Color = roblox.Color3.fromRGB(255, 70, 70)
	gate.Transparency = 0.5
	local g = roblox.Instance.new("Model")
	gate.Parent = g
	dump(g)
elseif scene == "base" then
	dump(Models.tree(at(-30, -40), 1, 1))
	dump(Models.tree(at(-20, -40), 2, 2))
	dump(Models.tree(at(-10, -40), 3, 3))
	dump((Models.rock(at(0, -40), 4)))
	dump((Models.trainingMat(at(12, -40), 1)))
	dump((Models.trainingMat(at(22, -40), 2)))
	dump((Models.pedestal(at(32, -40))))
	dump((Models.etherCore(at(0, -20))))
	dump(Models.structure("TrainingGround", at(-22, 0), V(26, 0.4, 14)))
	dump(Models.structure("RuneMats", at(22, 0), V(26, 0.4, 14)))
	dump(Models.structure("Sawmill", at(-28, 25), V(14, 8, 12)))
	dump(Models.structure("Quarry", at(28, 25), V(14, 8, 12)))
	dump(Models.structure("Watchtower", at(0, 30), V(8, 22, 8)))
	dump(Models.structure("Palisade", at(0, 48), V(86, 8, 2)))
else
	dump((Models.boss(BossesCfg[1], at(-14, 10))))
	dump((Models.boss(BossesCfg[2], at(14, 10))))
	dump((Models.portal(at(0, -6), roblox.Color3.fromRGB(90, 170, 70))))
	dump(Models.structure("EtherMats", at(-26, -14), V(16, 0.4, 12)))
	dump(Models.structure("CelestialMats", at(26, -14), V(18, 0.4, 10)))
	dump((Models.trainingMat(at(-30, -14), 3)))
	dump((Models.trainingMat(at(22, -14), 4)))
	for i, egg in PetsCfg.Eggs do
		local c = egg.Color
		dump((Models.eggStand(at(-12 + i * 6, -26), roblox.Color3.fromRGB(c[1], c[2], c[3]))))
	end
	for i, def in PetsCfg.List do
		local r = PetsCfg.Rarities[def.Rarity].Color
		local m = PetModels.build(def, roblox.Color3.fromRGB(r[1], r[2], r[3]))
		local offset = roblox.CFrame.new(-16 + i * 3.6, 2, -34) -- PivotTo n'existe pas dans Lune
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame = offset * p.CFrame
			end
		end
		dump(m)
	end
end
fs.writeFile("parts.json", serde.encode("json", out))
print(#out .. " pièces")
