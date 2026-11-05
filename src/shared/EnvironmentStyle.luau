--[[
	EnvironmentStyle : applique Config/VisualStyle aux pièces d'environnement.

	- applyPart(part) : matériau lisse, réflexion nulle, MaterialVariant retiré, néon réservé aux
	  petits accents, cristaux en facettes turquoise, flammes translucides, lumières et feux
	  plafonnés, SurfaceAppearance à carte de relief retirée (la couleur est gardée).
	- applyTree(root) : toute une arborescence (une fois, à la génération).
	- watch(root) : traite les objets ajoutés plus tard sous `root` (clonés, chargés, régénérés),
	  par l'événement DescendantAdded, regroupés et différés : aucun balayage par image.

	Idempotent : une pièce traitée porte l'attribut StyleVersion ; un second passage ne change
	rien (pas d'effet cumulé, aucune lumière dupliquée, couleurs non dérivées).
	Hors champ : personnages (Humanoid), ennemis, indicateurs d'attaque, portes locales, UI,
	compagnons, et tout objet portant PreserveOriginalStyle = true (lui ou un ancêtre).
	Les textures, décalques et symboles (bannières, panneaux) sont conservés.
]]

local Style = require(script.Parent.Config.VisualStyle)

local EnvironmentStyle = {}

local KEEP = {}
for _, name in Style.KeepMaterials do
	KEEP[name] = true
end

-- Dossiers et modèles hors champ (gameplay et personnages).
local SKIP_NAMES = {
	Enemies = true,
	DefenseEnemies = true,
	Projectile = true,
	PetFollowers = true,
	LocalStreetGates = true,
	Telegraph = true,
	Boss = true,
}

local function hasPrefix(name: string, list: { string }): boolean
	for _, prefix in list do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

-- Hors champ : exemption explicite, personnage, ou dossier de gameplay parmi les ancêtres.
local function excluded(inst: Instance): boolean
	local node: Instance? = inst
	while node and node ~= workspace and node ~= game do
		if node:GetAttribute("PreserveOriginalStyle") == true or SKIP_NAMES[node.Name] then
			return true
		end
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function rgb(c): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function styleNeon(p: BasePart)
	local cfg = Style.Neon
	local isCrystal = hasPrefix(p.Name, cfg.CrystalNames)
	local isFlame = hasPrefix(p.Name, cfg.FlameNames)
	if not isCrystal and not isFlame then
		return -- accent ou repère de jeu : le néon reste
	end
	p.Material = Enum.Material.SmoothPlastic
	if isFlame then
		p.Transparency = math.max(p.Transparency, cfg.FlameTransparency)
	elseif isCrystal and luminance(p.Color) > cfg.CrystalPaleThreshold then
		-- Cristal quasi blanc : facettes turquoise lisibles (fait une seule fois grâce au marqueur).
		p.Color = p.Color:Lerp(rgb(cfg.CrystalTint), 0.45)
	end
end

local function styleBasePart(p: BasePart)
	if p:GetAttribute("StyleVersion") == Style.Version then
		return
	end
	local material = p.Material
	if material == Enum.Material.Neon then
		styleNeon(p)
	elseif not KEEP[material.Name] then
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Reflectance = Style.Reflectance
	if p.MaterialVariant ~= "" then
		p.MaterialVariant = ""
	end
	-- SurfaceAppearance à carte de relief (texture réaliste) : retirée, couleur conservée.
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		local ok, normal = pcall(function()
			return (sa :: any).NormalMap
		end)
		if ok and normal ~= "" then
			local okColor, colorMap = pcall(function()
				return (sa :: any).ColorMap
			end)
			if okColor and colorMap ~= "" and p:IsA("MeshPart") then
				pcall(function()
					(p :: any).TextureID = colorMap
				end)
			end
			sa:Destroy()
		end
	end
	p:SetAttribute("StyleVersion", Style.Version)
end

local function styleEffect(inst: Instance)
	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		local l = inst :: any
		l.Brightness = math.min(l.Brightness, Style.Lights.MaxBrightness)
		l.Range = math.min(l.Range, Style.Lights.MaxRange)
	elseif inst:IsA("Fire") then
		inst.Size = math.min(inst.Size, Style.Fire.MaxSize)
		inst.Heat = math.min(inst.Heat, Style.Fire.MaxHeat)
	end
end

-- Une instance (pièce, lumière, feu). Sans effet hors champ ; idempotent.
function EnvironmentStyle.apply(inst: Instance)
	if inst:IsA("BasePart") then
		if not excluded(inst) then
			styleBasePart(inst)
		end
	elseif inst:IsA("Light") or inst:IsA("Fire") then
		if not excluded(inst) then
			styleEffect(inst)
		end
	end
end

-- Version rapide pour les générateurs : la pièce vient d'être créée (pas encore parentée), on
-- ne vérifie que son propre attribut d'exemption.
function EnvironmentStyle.applyPart(p: BasePart)
	if p:GetAttribute("PreserveOriginalStyle") ~= true then
		styleBasePart(p)
	end
	return p
end

function EnvironmentStyle.applyTree(root: Instance)
	if excluded(root) then
		return
	end
	EnvironmentStyle.apply(root)
	for _, inst in root:GetDescendants() do
		EnvironmentStyle.apply(inst)
	end
end

-- Surveille `root` : les objets ajoutés plus tard (clones, imports, régénérations) sont stylés
-- par lots, à l'image suivante. Retourne la connexion.
function EnvironmentStyle.watch(root: Instance)
	local pending: { Instance } = {}
	local scheduled = false
	return root.DescendantAdded:Connect(function(inst)
		if not (inst:IsA("BasePart") or inst:IsA("Light") or inst:IsA("Fire")) then
			return
		end
		if inst:IsA("BasePart") and inst:GetAttribute("StyleVersion") == Style.Version then
			return
		end
		table.insert(pending, inst)
		if not scheduled then
			scheduled = true
			task.defer(function()
				scheduled = false
				local batch = pending
				pending = {}
				for _, item in batch do
					if item.Parent then
						EnvironmentStyle.apply(item)
					end
				end
			end)
		end
	end)
end

return EnvironmentStyle
