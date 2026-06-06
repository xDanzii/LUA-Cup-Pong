local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local LeaderboardService = {}

local scoreByUserId = {}
local scoreUpdateRemote = nil
local started = false

local function debugLog(message)
    if not Config.DEBUG_LOGS then
        return
    end
    print("[LeaderboardService] " .. message)
end

local function ensureLeaderstats(player)
    local folder = player:FindFirstChild("leaderstats")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "leaderstats"
        folder.Parent = player
    end

    local points = folder:FindFirstChild("Points")
    if not points then
        points = Instance.new("IntValue")
        points.Name = "Points"
        points.Parent = folder
    end

    return points
end

local function setScore(player, score)
    scoreByUserId[player.UserId] = score
    local points = ensureLeaderstats(player)
    points.Value = score
    debugLog(string.format("Set score for %s (%d) = %d", player.Name, player.UserId, score))

    if scoreUpdateRemote then
        scoreUpdateRemote:FireAllClients({
            userId = player.UserId,
            name = player.Name,
            score = score,
        })
    end
end

function LeaderboardService.Start(remotes)
    if started then
        debugLog("Start() called but already started")
        return
    end
    started = true
    debugLog("Starting leaderstats service")

    if remotes then
        scoreUpdateRemote = remotes.ScoreUpdate
    end

    Players.PlayerAdded:Connect(function(player)
        debugLog(string.format("Player added: %s (%d)", player.Name, player.UserId))
        setScore(player, 0)
    end)

    Players.PlayerRemoving:Connect(function(player)
        debugLog(string.format("Player removing: %s (%d)", player.Name, player.UserId))
        scoreByUserId[player.UserId] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        setScore(player, 0)
    end
end

function LeaderboardService.AddPoints(player, amount)
    local current = scoreByUserId[player.UserId] or 0
    debugLog(string.format("Adding %d points to %s (%d), previous=%d", amount, player.Name, player.UserId, current))
    setScore(player, current + amount)
    return current + amount
end

function LeaderboardService.GetScore(player)
    return scoreByUserId[player.UserId] or 0
end

function LeaderboardService.ResetPlayer(player)
    debugLog(string.format("Reset player score: %s (%d)", player.Name, player.UserId))
    setScore(player, 0)
end

function LeaderboardService.ResetAll()
    debugLog("Resetting all player scores")
    for _, player in ipairs(Players:GetPlayers()) do
        setScore(player, 0)
    end
end

return LeaderboardService
