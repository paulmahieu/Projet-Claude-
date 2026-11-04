--[[
	MachineFx : blocs de matériaux qui avancent sur le tapis roulant des machines.
	Purement visuel et local (aucune donnée envoyée) : le serveur étiquette chaque machine
	« MachineBelt » avec les attributs BlockColor et Interval. Seules les machines proches de
	la caméra sont animées.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local MachineFx = {}

local RANGE = 140
local TRAVEL = 2.4

local function spawnBlock(machine: Model)
	local startPart = machine:FindFirstChild("BeltStart") :: BasePart?
	local endPart = machine:FindFirstChild("BeltEnd") :: BasePart?
	if not startPart or not endPart then
		return
	end
	local block = Instance.new("Part")
	block.Name = "MachineBlock"
	block.Anchored = true
	block.CanCollide = false
	block.CanQuery = false
	block.CastShadow = false
	block.Size = Vector3.new(1, 0.8, 1)
	block.Color = machine:GetAttribute("BlockColor") or Color3.fromRGB(200, 200, 200)
	block.Material = Enum.Material.SmoothPlastic
	block.CFrame = startPart.CFrame
	block.Parent = workspace.CurrentCamera
	local tween =
		TweenService:Create(block, TweenInfo.new(TRAVEL, Enum.EasingStyle.Linear), { CFrame = endPart.CFrame })
	tween.Completed:Connect(function()
		block:Destroy()
	end)
	tween:Play()
end

function MachineFx.start()
	local nextAt: { [Model]: number } = {}
	task.spawn(function()
		while true do
			task.wait(0.2)
			local camera = workspace.CurrentCamera
			local now = os.clock()
			for _, machine in CollectionService:GetTagged("MachineBelt") do
				if machine:IsA("Model") and machine.Parent and machine.PrimaryPart then
					local close = camera and (machine.PrimaryPart.Position - camera.CFrame.Position).Magnitude < RANGE
					if close and (nextAt[machine] or 0) <= now then
						nextAt[machine] = now + (machine:GetAttribute("Interval") or 2)
						spawnBlock(machine)
					end
				end
			end
			for machine in nextAt do
				if not machine.Parent then
					nextAt[machine] = nil
				end
			end
		end
	end)
end

return MachineFx
