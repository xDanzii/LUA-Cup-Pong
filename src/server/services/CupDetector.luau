local CupDetector = {}
CupDetector.__index = CupDetector

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local nextCupDetectorId = 0
local INSIDE_DWELL_SECONDS = 0.05
local RECENT_SCORE_COOLDOWN_SECONDS = 0.2
local FAST_PASS_THROUGH_SPEED_Y = -18
local SCAN_INTERVAL_SECONDS = 0.05

local function ensureStableId(part, attributeName, prefix)
    local existing = part:GetAttribute(attributeName)
    if existing then
        return tostring(existing)
    end

    nextCupDetectorId += 1
    local generated = string.format("%s_%d", prefix, nextCupDetectorId)
    part:SetAttribute(attributeName, generated)
    return generated
end

local function getUserIdFromBall(hit)
    local current = hit
    while current do
        local throwerUserId = current:GetAttribute("ThrowerUserId")
        if throwerUserId then
            return tonumber(throwerUserId), current
        end
        current = current.Parent
    end

    return nil, hit
end

function CupDetector.new(tableId, cupParts, onCupTouched, debugLog)
    local self = setmetatable({}, CupDetector)
    self.tableId = tableId
    self.cupParts = cupParts
    self.onCupTouched = onCupTouched
    self.debugLog = debugLog or function(_message)
    end
    self.connections = {}
    self.overlapConnection = nil
    self.scanCooldownByBall = {}
    self.insideSinceByBall = {}
    return self
end

local function isBallInsideCupZone(cup, ball)
    local cupExtentsCFrame = cup.ExtentsCFrame
    local cupExtentsSize = cup.ExtentsSize

    local cupTopY = cupExtentsCFrame.Position.Y + (cupExtentsSize.Y * 0.5)
    local ballRadius = math.max(ball.Size.X, ball.Size.Y, ball.Size.Z) * 0.5

    -- Ball center must be below cup rim plane (with a small margin).
    if ball.Position.Y > (cupTopY - (ballRadius * 0.2)) then
        return false
    end

    -- Ball should be near cup center in local XZ, not just grazing outer rim/collider.
    local localPos = cup.CFrame:PointToObjectSpace(ball.Position)
    local radialDistance = math.sqrt((localPos.X * localPos.X) + (localPos.Z * localPos.Z))
    local innerRadiusEstimate = math.max(0.1, math.min(cupExtentsSize.X, cupExtentsSize.Z) * 0.35)
    if radialDistance > innerRadiusEstimate then
        return false
    end

    -- Prefer downward/settling motion when scoring.
    if ball.AssemblyLinearVelocity.Y > 1.5 then
        return false
    end

    return true
end

local function processCupHit(self, cup, hit)
    if not hit or not hit:IsA("BasePart") then
        return
    end

    local throwerUserId, ball = getUserIdFromBall(hit)
    if not throwerUserId then
        return
    end

    local ballTableId = ball:GetAttribute("TableId")
    if ballTableId and tostring(ballTableId) ~= tostring(self.tableId) then
        return
    end

    -- Soft debounce for overlap scan path; score service still provides hard dedupe.
    local ballId = ensureStableId(ball, "DetectedBallId", "ball")
    local cupStableId = ensureStableId(cup, "DetectedCupId", "cup")
    local ballKey = ballId .. ":" .. cupStableId
    local now = os.clock()
    local last = self.scanCooldownByBall[ballKey]
    if last and (now - last) < RECENT_SCORE_COOLDOWN_SECONDS then
        return
    end

    if not isBallInsideCupZone(cup, ball) then
        self.insideSinceByBall[ballKey] = nil
        return
    end

    local insideSince = self.insideSinceByBall[ballKey]
    if not insideSince then
        if ball.AssemblyLinearVelocity.Y <= FAST_PASS_THROUGH_SPEED_Y then
            -- Fast downward pass-through can miss dwell windows; allow immediate score validation.
            insideSince = now - INSIDE_DWELL_SECONDS
            self.insideSinceByBall[ballKey] = insideSince
        else
            self.insideSinceByBall[ballKey] = now
            return
        end
    end

    if (now - insideSince) < INSIDE_DWELL_SECONDS then
        return
    end

    self.scanCooldownByBall[ballKey] = now
    self.insideSinceByBall[ballKey] = nil

    local cupId = cup:GetAttribute("CupId") or cup.Name
    self.onCupTouched(self.tableId, throwerUserId, ball, cupId)
end

function CupDetector:_startOverlapScan()
    local overlapParams = OverlapParams.new()
    local scanAccumulator = 0

    self.overlapConnection = RunService.Heartbeat:Connect(function(deltaTime)
        scanAccumulator += deltaTime
        if scanAccumulator < SCAN_INTERVAL_SECONDS then
            return
        end
        scanAccumulator = 0

        local ballsFolder = Workspace:FindFirstChild("ThrownBalls")
        if not ballsFolder then
            return
        end

        overlapParams.FilterType = Enum.RaycastFilterType.Include
        overlapParams.FilterDescendantsInstances = { ballsFolder }
        overlapParams.MaxParts = 30

        for _, cup in ipairs(self.cupParts) do
            local overlapping = Workspace:GetPartsInPart(cup, overlapParams)
            for _, hit in ipairs(overlapping) do
                processCupHit(self, cup, hit)
            end
        end

        -- Extra direct pass checks each active ball against each cup zone.
        -- This catches cases where fast balls tunnel through thin cup geometry between overlap frames.
        local thrownBalls = ballsFolder:GetChildren()
        for _, ball in ipairs(thrownBalls) do
            local ballTableId = ball:GetAttribute("TableId")
            local belongsToThisTable = (not ballTableId) or tostring(ballTableId) == tostring(self.tableId)
            if ball:IsA("BasePart") and ball:GetAttribute("ThrowerUserId") and belongsToThisTable then
                for _, cup in ipairs(self.cupParts) do
                    processCupHit(self, cup, ball)
                end
            end
        end
    end)
end

function CupDetector:Start()
    for _, cup in ipairs(self.cupParts) do
        local connection = cup.Touched:Connect(function(hit)
            processCupHit(self, cup, hit)
        end)

        table.insert(self.connections, connection)
    end

    self:_startOverlapScan()

    self.debugLog(string.format("CupDetector started for table=%s with %d cups", self.tableId, #self.cupParts))
end

function CupDetector:Stop()
    if self.overlapConnection then
        self.overlapConnection:Disconnect()
        self.overlapConnection = nil
    end

    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end
    self.connections = {}
    self.scanCooldownByBall = {}
    self.insideSinceByBall = {}
end

return CupDetector
