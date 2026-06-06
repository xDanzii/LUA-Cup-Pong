local ThrowService = {}

local throwRequestRemote = nil
local ballSpawner = nil
local throwCooldown = 0.5
local throwMinSpeed = 40
local throwMaxSpeed = 85
local throwMinVerticalBoost = 0
local throwMaxVerticalBoost = 10
local debugLog = function(_message)
end

local lastThrowAt = {}
local connection = nil

local function canThrow(player)
    local now = os.clock()
    local previous = lastThrowAt[player.UserId] or 0
    if now - previous < throwCooldown then
        return false
    end

    lastThrowAt[player.UserId] = now
    return true
end

function ThrowService.Start(options)
    options = options or {}
    throwRequestRemote = options.throwRequestRemote
    ballSpawner = options.ballSpawner
    throwCooldown = options.throwCooldown or throwCooldown
    throwMinSpeed = options.throwMinSpeed or throwMinSpeed
    throwMaxSpeed = options.throwMaxSpeed or throwMaxSpeed
    throwMinVerticalBoost = options.throwMinVerticalBoost or throwMinVerticalBoost
    throwMaxVerticalBoost = options.throwMaxVerticalBoost or throwMaxVerticalBoost
    debugLog = options.debugLog or debugLog

    if not throwRequestRemote then
        error("ThrowService requires throwRequestRemote")
    end

    if not ballSpawner then
        error("ThrowService requires ballSpawner")
    end

    if connection then
        connection:Disconnect()
    end

    connection = throwRequestRemote.OnServerEvent:Connect(function(player, payload)
        if not canThrow(player) then
            debugLog(string.format("Throw rejected (cooldown) for %s (%d)", player.Name, player.UserId))
            return
        end

        if typeof(payload) ~= "table" then
            payload = {}
        end

        local requestedSpeed = tonumber(payload.speed)
        if requestedSpeed then
            payload.speed = math.clamp(requestedSpeed, throwMinSpeed, throwMaxSpeed)
        end

        local requestedVerticalBoost = tonumber(payload.verticalBoost)
        if requestedVerticalBoost then
            payload.verticalBoost = math.clamp(requestedVerticalBoost, throwMinVerticalBoost, throwMaxVerticalBoost)
        end

        local ball, reason = ballSpawner.SpawnForThrow(player, payload)
        if not ball then
            debugLog(string.format("Throw rejected for %s (%d): %s", player.Name, player.UserId, tostring(reason)))
            return
        end

        debugLog(string.format("Throw accepted for %s (%d)", player.Name, player.UserId))
    end)

    debugLog(string.format("ThrowService started (cooldown=%.2f, speed=[%d,%d], vBoost=[%.1f,%.1f])", throwCooldown, throwMinSpeed, throwMaxSpeed, throwMinVerticalBoost, throwMaxVerticalBoost))
end

function ThrowService.Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

return ThrowService
