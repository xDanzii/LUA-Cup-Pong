local Players = game:GetService("Players")

local TableController = {}
TableController.__index = TableController

local function defaultDebugLog(_message)
end

function TableController.new(tableId, options)
    local self = setmetatable({}, TableController)

    self.tableId = tableId
    self.roundLength = options.roundLength
    self.roundIntermission = options.roundIntermission or 5
    self.roundStateRemote = options.roundStateRemote
    self.winnerRemote = options.winnerRemote
    self.scoreService = options.scoreService
    self.debugLog = options.debugLog or defaultDebugLog

    self.localScores = {}
    self.roundActive = false
    self._running = false
    self._seatedPlayerCount = 0

    return self
end

function TableController:_emitRoundState(state, timeRemaining)
    if not self.roundStateRemote then
        return
    end

    self.roundStateRemote:FireAllClients({
        tableId = self.tableId,
        state = state,
        timeRemaining = timeRemaining,
    })
end

function TableController:_resetLocalScores()
    self.localScores = {}
end

function TableController:_finishRound()
    self.roundActive = false
    self:_emitRoundState("Ended", 0)

    local winnerUserId = nil
    local winnerScore = -1
    for userId, score in pairs(self.localScores) do
        if score > winnerScore then
            winnerUserId = userId
            winnerScore = score
        end
    end

    local winnerName = "No Winner"
    if winnerUserId then
        local player = Players:GetPlayerByUserId(winnerUserId)
        winnerName = player and player.Name or tostring(winnerUserId)
    end

    self.debugLog(string.format("Round ended table=%s winner=%s score=%d", self.tableId, winnerName, math.max(winnerScore, 0)))

    if self.winnerRemote then
        self.winnerRemote:FireAllClients({
            tableId = self.tableId,
            winnerUserId = winnerUserId,
            winnerName = winnerName,
            winnerScore = math.max(winnerScore, 0),
        })
    end

    if self.scoreService and self.scoreService.ResetRound then
        self.scoreService.ResetRound(self.tableId)
    end

    self:_resetLocalScores()
end

function TableController:Start()
    if self._running then
        return
    end

    self._running = true
    task.spawn(function()
        while self._running do
            while self._running and self._seatedPlayerCount <= 0 do
                self.roundActive = false
                self:_emitRoundState("WaitingForPlayers", 0)
                task.wait(0.5)
            end

            if not self._running then
                break
            end

            self.roundActive = true
            self:_emitRoundState("Running", self.roundLength)
            self.debugLog(string.format("Round started table=%s length=%d", self.tableId, self.roundLength))

            local timeRemaining = self.roundLength
            while timeRemaining > 0 and self._running do
                task.wait(1)
                timeRemaining -= 1
                self:_emitRoundState("Running", timeRemaining)
            end

            if not self._running then
                break
            end

            self:_finishRound()

            if self.roundIntermission > 0 then
                self:_emitRoundState("Intermission", self.roundIntermission)
                task.wait(self.roundIntermission)
            end
        end
    end)
end

function TableController:SetSeatedPlayerCount(count)
    local numericCount = tonumber(count) or 0
    self._seatedPlayerCount = math.max(0, math.floor(numericCount))
end

function TableController:Stop()
    self._running = false
    self.roundActive = false
end

function TableController:HandleCupScore(player, ball, cupId)
    if not self.roundActive then
        return false, "round-not-active"
    end

    local success, result = self.scoreService.AwardCupShot(player, ball, cupId, self.tableId)
    if not success then
        return false, result
    end

    self.localScores[player.UserId] = (self.localScores[player.UserId] or 0) + 1
    self.debugLog(string.format("Cup score table=%s player=%s cup=%s", self.tableId, player.Name, tostring(cupId)))
    return true, result
end

return TableController
