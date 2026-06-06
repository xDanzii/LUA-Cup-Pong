local ScoreService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local leaderboardService = nil
local remoteScoreUpdate = nil
local pointsPerShot = 1
local nextScoreBallId = 0

-- Tracks which ball ids have already scored so one ball cannot score multiple times.
local scoredBallIds = {}

local function debugLog(message)
    if not Config.DEBUG_LOGS then
        return
    end
    print("[ScoreService] " .. message)
end

local function getBallId(ball, tableId)
    if not ball then
        return nil
    end

    local idValue = ball:GetAttribute("ScoreBallId")
    if idValue then
        return tostring(idValue)
    end

    nextScoreBallId += 1
    local generated = string.format("ball_%d", nextScoreBallId)
    if tableId then
        generated = string.format("%s:%s", tostring(tableId), generated)
    end
    ball:SetAttribute("ScoreBallId", generated)
    return generated
end

function ScoreService.Start(options)
    options = options or {}
    leaderboardService = options.leaderboardService
    pointsPerShot = options.pointsPerShot or pointsPerShot
    remoteScoreUpdate = options.scoreUpdateRemote
    debugLog(string.format("Started (pointsPerShot=%d, hasLeaderboard=%s, hasScoreRemote=%s)", pointsPerShot, tostring(leaderboardService ~= nil), tostring(remoteScoreUpdate ~= nil)))
end

function ScoreService.AwardCupShot(player, ball, cupId, tableId)
    if not player then
        debugLog("AwardCupShot rejected: missing player")
        return false, "missing-player"
    end

    local ballId = getBallId(ball, tableId)
    if ballId and scoredBallIds[ballId] then
        debugLog(string.format("AwardCupShot rejected: ball already scored (ballId=%s)", ballId))
        return false, "ball-already-scored"
    end

    if ballId then
        scoredBallIds[ballId] = true
    end

    debugLog(string.format("AwardCupShot accepted: player=%s (%d), cupId=%s, tableId=%s, ballId=%s", player.Name, player.UserId, tostring(cupId), tostring(tableId), tostring(ballId)))

    local newScore = nil
    if leaderboardService and leaderboardService.AddPoints then
        newScore = leaderboardService.AddPoints(player, pointsPerShot)
    end

    if remoteScoreUpdate then
        remoteScoreUpdate:FireAllClients({
            type = "CupScore",
            userId = player.UserId,
            name = player.Name,
            added = pointsPerShot,
            score = newScore,
            cupId = cupId,
            tableId = tableId,
            ballId = ballId,
        })
    end

    -- Remove the scoring ball after a short delay so players can see it land.
    if ball and ball.Parent then
        task.delay(Config.SCORE_BALL_REMOVE_DELAY or 0.35, function()
            if ball.Parent then
                ball:Destroy()
            end
        end)
    end

    return true, newScore
end

function ScoreService.ResetRound(tableId)
    -- Keep this table-scoped for independent timers/matches.
    if tableId then
        debugLog(string.format("ResetRound table scoped: %s", tostring(tableId)))
        local prefix = tostring(tableId) .. ":"
        for ballId in pairs(scoredBallIds) do
            if string.sub(ballId, 1, #prefix) == prefix then
                scoredBallIds[ballId] = nil
            end
        end

        if leaderboardService and leaderboardService.ResetAll then
            leaderboardService.ResetAll()
        end
        return
    end

    debugLog("ResetRound global: clearing all scored ball ids")
    scoredBallIds = {}

    if leaderboardService and leaderboardService.ResetAll then
        leaderboardService.ResetAll()
    end
end

return ScoreService
