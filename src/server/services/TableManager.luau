local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TableController = require(script.Parent:WaitForChild("TableController"))
local CupDetector = require(script.Parent:WaitForChild("CupDetector"))

local TableManager = {}

local started = false
local controllersByTableId = {}
local cupDetectorsByTableId = {}

local function normalizeTableId(tableId)
    return tostring(tableId)
end

local function normalizeCupPart(cupPart)
    -- Cups are used as trigger volumes for scoring.
    cupPart.CanCollide = true
    cupPart.CanTouch = true
    cupPart.CanQuery = true

    if cupPart:IsA("MeshPart") then
        pcall(function()
            cupPart.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
        end)
    end
end

local function getCupPartsForTable(tableModel)
    local cupParts = {}
    local cupsFolder = tableModel:FindFirstChild("Cups")

    if cupsFolder then
        for _, descendant in ipairs(cupsFolder:GetDescendants()) do
            if descendant:IsA("BasePart") then
                normalizeCupPart(descendant)
                table.insert(cupParts, descendant)
            end
        end
    else
        for _, descendant in ipairs(tableModel:GetDescendants()) do
            if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "cup") then
                normalizeCupPart(descendant)
                table.insert(cupParts, descendant)
            end
        end
    end

    return cupParts
end

local function getTables()
    local tables = {}
    local root = Workspace:FindFirstChild("GameTables")
    if root then
        for _, child in ipairs(root:GetChildren()) do
            if child:IsA("Model") then
                table.insert(tables, child)
            end
        end
        return tables
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("IsGameTable") == true then
            table.insert(tables, child)
        end
    end

    return tables
end

function TableManager.Start(options)
    if started then
        return
    end
    started = true

    local scoreService = options.scoreService
    local roundLength = options.roundLength
    local roundIntermission = options.roundIntermission or 5
    local roundStateRemote = options.roundStateRemote
    local winnerRemote = options.winnerRemote
    local debugLog = options.debugLog or function(_message)
    end

    local tableModels = getTables()
    if #tableModels == 0 then
        debugLog("No table models found. Add models under Workspace/GameTables or set IsGameTable=true on table models.")
        return
    end

    for index, tableModel in ipairs(tableModels) do
        local tableId = tableModel:GetAttribute("TableId") or tableModel.Name or tostring(index)
        local cupParts = getCupPartsForTable(tableModel)

        local controller = TableController.new(tableId, {
            scoreService = scoreService,
            roundLength = roundLength,
            roundIntermission = roundIntermission,
            roundStateRemote = roundStateRemote,
            winnerRemote = winnerRemote,
            debugLog = function(message)
                debugLog("[TableController] " .. message)
            end,
        })

        local detector = CupDetector.new(tableId, cupParts, function(_detectedTableId, throwerUserId, ball, cupId)
            local player = Players:GetPlayerByUserId(throwerUserId)
            if not player then
                return
            end

            local didScore, reason = controller:HandleCupScore(player, ball, cupId)
            if not didScore then
                debugLog(string.format("Score rejected table=%s player=%s reason=%s", tostring(tableId), player.Name, tostring(reason)))
            end
        end, function(message)
            debugLog("[CupDetector] " .. message)
        end)

        detector:Start()
        controller:Start()

        controllersByTableId[normalizeTableId(tableId)] = controller
        cupDetectorsByTableId[tableId] = detector
        debugLog(string.format("Table registered tableId=%s cups=%d", tostring(tableId), #cupParts))
    end
end

function TableManager.SetSeatedPlayerCount(tableId, seatedPlayerCount)
    local controller = controllersByTableId[normalizeTableId(tableId)]
    if not controller then
        return
    end

    controller:SetSeatedPlayerCount(seatedPlayerCount)
end

function TableManager.Stop()
    for _, detector in pairs(cupDetectorsByTableId) do
        detector:Stop()
    end
    for _, controller in pairs(controllersByTableId) do
        controller:Stop()
    end

    controllersByTableId = {}
    cupDetectorsByTableId = {}
    started = false
end

return TableManager
