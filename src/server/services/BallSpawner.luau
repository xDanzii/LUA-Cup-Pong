local Debris = game:GetService("Debris")
local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

local BallSpawner = {}

local ballAssetId = 0
local ballLifetime = 20
local throwSpeed = 78
local throwVerticalBoost = 12
local ballDiameter = 0.8
local ballDensity = 0.7
local ballFriction = 0.2
local ballElasticity = 0.85
local debugLog = function(_message)
end

local cachedTemplate = nil

local function sanitizeInstance(instance)
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
            descendant:Destroy()
        end
    end
end

local function fallbackBall()
    local ball = Instance.new("Part")
    ball.Name = "PingPongBall"
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.new(ballDiameter, ballDiameter, ballDiameter)
    ball.Material = Enum.Material.SmoothPlastic
    ball.Color = Color3.fromRGB(255, 255, 255)
    return ball
end

local function isLikelyBallShape(basePart)
    if basePart:IsA("Part") and basePart.Shape == Enum.PartType.Ball then
        return true
    end

    local size = basePart.Size
    local minAxis = math.min(size.X, size.Y, size.Z)
    local maxAxis = math.max(size.X, size.Y, size.Z)
    if minAxis <= 0 then
        return false
    end

    local ratio = maxAxis / minAxis
    -- Keep this tolerant for mesh spheres while rejecting cup/tube-like shapes.
    return ratio <= 1.35
end

local function findBasePart(root)
    if root:IsA("BasePart") then
        return root
    end

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("BasePart") then
            return descendant
        end
    end

    return nil
end

local function buildTemplate()
    if cachedTemplate then
        return cachedTemplate
    end

    local template = nil
    if ballAssetId > 0 then
        local ok, container = pcall(function()
            return InsertService:LoadAsset(ballAssetId)
        end)

        if ok and container then
            sanitizeInstance(container)
            local basePart = findBasePart(container)
            if basePart then
                if isLikelyBallShape(basePart) then
                    template = basePart:Clone()
                    template.Name = "PingPongBall"
                else
                    debugLog(string.format("Asset %d base part is not ball-shaped (size=%s), using fallback sphere", ballAssetId, tostring(basePart.Size)))
                end
            end
            container:Destroy()
        else
            debugLog(string.format("InsertService load failed for assetId=%d, using fallback", ballAssetId))
        end
    end

    if not template then
        template = fallbackBall()
    end

    if template:IsA("BasePart") then
        template.Size = Vector3.new(ballDiameter, ballDiameter, ballDiameter)
        template.Massless = false
        template.CanCollide = true
        template.CanTouch = true
        template.CanQuery = true
        template.CustomPhysicalProperties = PhysicalProperties.new(ballDensity, ballFriction, ballElasticity, 1, 1)
    end

    cachedTemplate = template
    return cachedTemplate
end

local function parseVector3(value, fallback)
    if typeof(value) == "Vector3" then
        return value
    end

    if typeof(value) == "table" and value.x and value.y and value.z then
        return Vector3.new(value.x, value.y, value.z)
    end

    return fallback
end

local function getBallsFolder()
    local folder = Workspace:FindFirstChild("ThrownBalls")
    if folder and folder:IsA("Folder") then
        return folder
    end

    folder = Instance.new("Folder")
    folder.Name = "ThrownBalls"
    folder.Parent = Workspace
    return folder
end

function BallSpawner.Start(options)
    options = options or {}
    ballAssetId = options.ballAssetId or ballAssetId
    ballLifetime = options.ballLifetime or ballLifetime
    throwSpeed = options.throwSpeed or throwSpeed
    throwVerticalBoost = options.throwVerticalBoost or throwVerticalBoost
    ballDiameter = options.ballDiameter or ballDiameter
    ballDensity = options.ballDensity or ballDensity
    ballFriction = options.ballFriction or ballFriction
    ballElasticity = options.ballElasticity or ballElasticity
    debugLog = options.debugLog or debugLog

    -- Config changes should rebuild template so size/physics updates apply.
    cachedTemplate = nil

    local template = buildTemplate()
    debugLog(string.format("BallSpawner started (assetId=%d, templateClass=%s)", ballAssetId, template.ClassName))
end

function BallSpawner.SpawnForThrow(player, payload)
    payload = payload or {}

    local character = player.Character
    if not character then
        return nil, "missing-character"
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil, "missing-humanoid-root-part"
    end

    local startPosition = parseVector3(payload.origin, root.Position + (root.CFrame.LookVector * 2) + Vector3.new(0, 2, 0))
    local direction = parseVector3(payload.direction, root.CFrame.LookVector)
    if direction.Magnitude < 0.01 then
        direction = root.CFrame.LookVector
    end
    direction = direction.Unit

    local speed = tonumber(payload.speed) or throwSpeed
    local verticalBoost = tonumber(payload.verticalBoost) or throwVerticalBoost
    local tableId = payload.tableId

    local ball = buildTemplate():Clone()
    if ball:IsA("BasePart") then
        ball.Massless = false
    end
    ball.CFrame = CFrame.new(startPosition)
    ball:SetAttribute("ThrowerUserId", player.UserId)
    if tableId then
        ball:SetAttribute("TableId", tableId)
    end
    ball.Parent = getBallsFolder()

    if ball:IsA("BasePart") then
        ball.AssemblyLinearVelocity = (direction * speed) + Vector3.new(0, verticalBoost, 0)
        pcall(function()
            ball:SetNetworkOwner(nil)
        end)
    end

    Debris:AddItem(ball, ballLifetime)
    debugLog(string.format("Spawned throw ball for %s (%d)", player.Name, player.UserId))
    return ball
end

return BallSpawner
