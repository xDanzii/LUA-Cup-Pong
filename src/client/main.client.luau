print("Hello world, from client (main)!")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Client may `require` shared modules for constants/types.
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local throwRequestRemote = Shared:WaitForChild(Remotes.Names.ThrowRequest)
local winnerAnnouncementRemote = Shared:WaitForChild(Remotes.Names.WinnerAnnouncement)
local CHARGE_MAX_SECONDS = Config.CHARGE_MAX_SECONDS or 1.0
local UI_ENABLE_CHARGE_BAR = Config.UI_ENABLE_CHARGE_BAR ~= false
local UI_ENABLE_WINNER_ANNOUNCEMENT = Config.UI_ENABLE_WINNER_ANNOUNCEMENT ~= false

local toolStates = {}

local function createChargeUi()
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ChargeBarGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "ChargeContainer"
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.fromScale(0.5, 0.92)
	container.Size = UDim2.fromScale(0.26, 0.035)
	container.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	container.BackgroundTransparency = 0.2
	container.Visible = false
	container.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 8)
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Color3.fromRGB(167, 176, 196)
	containerStroke.Thickness = 1
	containerStroke.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "ChargeFill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0.01, 0.5)
	fill.Size = UDim2.fromScale(0, 0.76)
	fill.BackgroundColor3 = Color3.fromRGB(88, 196, 102)
	fill.BorderSizePixel = 0
	fill.Parent = container

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill

	return container, fill
end

local chargeContainer, chargeFill = nil, nil
if UI_ENABLE_CHARGE_BAR then
	chargeContainer, chargeFill = createChargeUi()
end

local function setChargeUiVisible(isVisible)
	if not UI_ENABLE_CHARGE_BAR or not chargeContainer or not chargeFill then
		return
	end

	chargeContainer.Visible = isVisible
	if not isVisible then
		chargeFill.Size = UDim2.fromScale(0, 0.76)
		chargeFill.BackgroundColor3 = Color3.fromRGB(88, 196, 102)
	end
end

local function updateChargeUi(chargeAlpha)
	if not UI_ENABLE_CHARGE_BAR or not chargeFill then
		return
	end

	local alpha = math.clamp(chargeAlpha, 0, 1)
	chargeFill.Size = UDim2.fromScale(0.98 * alpha, 0.76)
	chargeFill.BackgroundColor3 = Color3.fromRGB(88, 196, 102):Lerp(Color3.fromRGB(255, 86, 86), alpha)
end

local function createWinnerAnnouncementUi()
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WinnerAnnouncementGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "WinnerLabel"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.06)
	label.Size = UDim2.fromScale(0.62, 0.1)
	label.BackgroundColor3 = Color3.fromRGB(19, 25, 40)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(255, 239, 174)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.Visible = false
	label.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 219, 121)
	stroke.Thickness = 2
	stroke.Parent = label

	return label
end

local winnerLabel = nil
if UI_ENABLE_WINNER_ANNOUNCEMENT then
	winnerLabel = createWinnerAnnouncementUi()
end

local function showWinnerAnnouncement(text)
	if not UI_ENABLE_WINNER_ANNOUNCEMENT or not winnerLabel then
		return
	end

	winnerLabel.TextTransparency = 1
	winnerLabel.BackgroundTransparency = 1
	winnerLabel.Text = text
	winnerLabel.Visible = true

	local fadeIn = TweenService:Create(winnerLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		BackgroundTransparency = 0.2,
	})
	fadeIn:Play()

	task.delay(3.5, function()
		local fadeOut = TweenService:Create(winnerLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			winnerLabel.Visible = false
		end)
	end)
end

local function getAimRay()
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end

	local mousePosition = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

	return ray, camera
end

local function getAimDirection(origin, character)
	local ray, camera = getAimRay()
	if not ray or not camera then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local rayDistance = 500
	local result = workspace:Raycast(ray.Origin, ray.Direction * rayDistance, raycastParams)
	local targetPosition = result and result.Position or (ray.Origin + (ray.Direction * rayDistance))

	local direction = targetPosition - origin
	if direction.Magnitude < 0.01 then
		return camera.CFrame.LookVector
	end

	return direction.Unit
end

local function getThrowOrigin(root, character)
	local camera = workspace.CurrentCamera
	if not camera then
		return root.Position + (root.CFrame.LookVector * 2) + Vector3.new(0, 2, 0)
	end

	local head = character:FindFirstChild("Head")
	local isFirstPerson = head and ((camera.CFrame.Position - head.Position).Magnitude <= 1.2)
	if isFirstPerson then
		return camera.CFrame.Position + (camera.CFrame.LookVector * 1.4)
	end

	return root.Position + (root.CFrame.LookVector * 2) + Vector3.new(0, 2, 0)
end

local function buildThrowPayloadForSpeed(speed, verticalBoost)
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local origin = getThrowOrigin(root, character)
	local direction = getAimDirection(origin, character) or root.CFrame.LookVector
	local tableId = player:GetAttribute("CurrentTableId")

	return {
		origin = origin,
		direction = direction,
		speed = speed,
		verticalBoost = verticalBoost,
		tableId = tableId,
	}
end

local function getHandPart(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function createHeldBallVisual(character)
	local hand = getHandPart(character)
	if not hand then
		return nil
	end

	local visual = Instance.new("Part")
	visual.Name = "HeldPingPongBall"
	visual.Shape = Enum.PartType.Ball
	visual.Size = Vector3.new(Config.BALL_DIAMETER, Config.BALL_DIAMETER, Config.BALL_DIAMETER)
	visual.Material = Enum.Material.SmoothPlastic
	visual.Color = Color3.fromRGB(255, 255, 255)
	visual.CanCollide = false
	visual.CanTouch = false
	visual.CanQuery = false
	visual.Massless = true
	visual.Parent = character

	local offset = CFrame.new(0, -0.25, -0.45)
	visual.CFrame = hand.CFrame * offset

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = visual
	weld.Parent = visual

	return visual
end

local function removeHeldBallVisual(toolState)
	if toolState.heldBallVisual and toolState.heldBallVisual.Parent then
		toolState.heldBallVisual:Destroy()
	end
	toolState.heldBallVisual = nil
end

local function sendChargedThrow(toolState)
	if not toolState.chargeStart then
		return
	end

	local heldFor = math.max(0, os.clock() - toolState.chargeStart)
	toolState.chargeStart = nil

	local chargeAlphaLinear = math.clamp(heldFor / CHARGE_MAX_SECONDS, 0, 1)
	local chargeAlpha = chargeAlphaLinear ^ 1.65
	local minSpeed = Config.THROW_MIN_SPEED or Config.THROW_SPEED
	local maxSpeed = Config.THROW_MAX_SPEED or Config.THROW_SPEED
	local speed = minSpeed + ((maxSpeed - minSpeed) * chargeAlpha)
	local minVerticalBoost = Config.THROW_MIN_VERTICAL_BOOST or 0
	local maxVerticalBoost = Config.THROW_MAX_VERTICAL_BOOST or Config.THROW_VERTICAL_BOOST
	local verticalBoost = minVerticalBoost + ((maxVerticalBoost - minVerticalBoost) * chargeAlpha)

	local payload = buildThrowPayloadForSpeed(speed, verticalBoost)
	if not payload then
		return
	end

	throwRequestRemote:FireServer(payload)
end

local function bindTool(tool)
	if toolStates[tool] then
		return
	end

	local toolState = {
		chargeStart = nil,
		isEquipped = false,
		heldBallVisual = nil,
		chargeUpdateConnection = nil,
		connections = {},
	}
	toolStates[tool] = toolState

	local endCharge

	local function beginCharge()
		if not toolState.isEquipped or toolState.chargeStart then
			return
		end

		toolState.chargeStart = os.clock()
		setChargeUiVisible(true)

		if toolState.chargeUpdateConnection then
			toolState.chargeUpdateConnection:Disconnect()
		end

		toolState.chargeUpdateConnection = RunService.RenderStepped:Connect(function()
			if not toolState.chargeStart then
				return
			end

			local heldFor = math.max(0, os.clock() - toolState.chargeStart)
			local alpha = math.clamp(heldFor / CHARGE_MAX_SECONDS, 0, 1)
			updateChargeUi(alpha)
		end)
	end

	endCharge = function(shouldThrow)
		if not toolState.chargeStart then
			return
		end

		if toolState.chargeUpdateConnection then
			toolState.chargeUpdateConnection:Disconnect()
			toolState.chargeUpdateConnection = nil
		end

		setChargeUiVisible(false)

		if shouldThrow then
			sendChargedThrow(toolState)
		else
			toolState.chargeStart = nil
		end
	end

	toolState.connections.inputBegan = UserInputService.InputBegan:Connect(function(input)
		if not toolState.isEquipped then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			beginCharge()
		end
	end)

	toolState.connections.inputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			endCharge(toolState.isEquipped)
		end
	end)

	toolState.connections.equipped = tool.Equipped:Connect(function()
		toolState.isEquipped = true
		if not toolState.heldBallVisual then
			toolState.heldBallVisual = createHeldBallVisual(player.Character)
		end
	end)

	toolState.connections.unequipped = tool.Unequipped:Connect(function()
		toolState.isEquipped = false
		endCharge(false)
		removeHeldBallVisual(toolState)
	end)

	tool.Destroying:Connect(function()
		endCharge(false)
		removeHeldBallVisual(toolState)
		for _, connection in pairs(toolState.connections) do
			connection:Disconnect()
		end
		if toolState.chargeUpdateConnection then
			toolState.chargeUpdateConnection:Disconnect()
			toolState.chargeUpdateConnection = nil
		end
		toolStates[tool] = nil
	end)

	if tool.Parent == player.Character then
		toolState.isEquipped = true
	end

	if tool.Parent == player.Character and not toolState.heldBallVisual then
		toolState.heldBallVisual = createHeldBallVisual(player.Character)
	end
end

local function maybeBind(inst)
	if inst:IsA("Tool") and inst.Name == Config.TOOL_NAME then
		bindTool(inst)
	end
end

if player:FindFirstChildOfClass("Backpack") then
	for _, inst in ipairs(player.Backpack:GetChildren()) do
		maybeBind(inst)
	end

	player.Backpack.ChildAdded:Connect(maybeBind)
end

player.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(maybeBind)
end)

if player.Character then
	for _, inst in ipairs(player.Character:GetChildren()) do
		maybeBind(inst)
	end
	player.Character.ChildAdded:Connect(maybeBind)
end

winnerAnnouncementRemote.OnClientEvent:Connect(function(payload)
	if not UI_ENABLE_WINNER_ANNOUNCEMENT then
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	local winnerName = payload.winnerName or "No Winner"
	local winnerScore = payload.winnerScore or 0
	if not payload.winnerUserId then
		showWinnerAnnouncement("No player won this round. Get seated and try again!")
		return
	end

	showWinnerAnnouncement(string.format("%s wins on Cup Pong with %d point(s)!", winnerName, winnerScore))
end)

