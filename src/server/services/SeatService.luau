local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SeatService = {}

local toolService = nil
local debugLog = function(_message)
end

local seatConnections = {}
local occupiedPlayerBySeat = {}
local tableIdBySeat = {}
local seatedCountByTableId = {}
local onTableSeatCountChanged = nil

local function notifySeatCountChanged(tableId)
    if not onTableSeatCountChanged then
        return
    end

    onTableSeatCountChanged(tableId, seatedCountByTableId[tableId] or 0)
end

local function updateTableSeatCount(tableId, delta)
    if not tableId then
        return
    end

    seatedCountByTableId[tableId] = math.max(0, (seatedCountByTableId[tableId] or 0) + delta)
    notifySeatCountChanged(tableId)
end

local function getPlayerFromHumanoid(humanoid)
    if not humanoid then
        return nil
    end

    local character = humanoid.Parent
    if not character then
        return nil
    end

    return Players:GetPlayerFromCharacter(character)
end

local function getTableModelFromSeat(seat)
    local current = seat
    local gameTablesRoot = Workspace:FindFirstChild("GameTables")
    while current do
        if current:IsA("Model") then
            if gameTablesRoot and current.Parent == gameTablesRoot then
                return current
            end

            if current:GetAttribute("IsGameTable") == true then
                return current
            end
        end
        current = current.Parent
    end

    return nil
end

local function getSeats()
    local seats = {}
    local root = Workspace:FindFirstChild("GameTables")
    if root then
        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("Seat") or descendant:IsA("VehicleSeat") then
                table.insert(seats, descendant)
            end
        end
    end
    return seats
end

local function handleSeatChanged(seat)
    local previousPlayer = occupiedPlayerBySeat[seat]
    local currentPlayer = getPlayerFromHumanoid(seat.Occupant)
    local tableId = tableIdBySeat[seat]

    if not tableId then
        local tableModel = getTableModelFromSeat(seat)
        if tableModel then
            tableId = tableModel:GetAttribute("TableId") or tableModel.Name
            tableIdBySeat[seat] = tableId
        end
    end

    if previousPlayer and previousPlayer ~= currentPlayer then
        toolService.Revoke(previousPlayer)
    end

    if previousPlayer and (not currentPlayer) and tableId then
        updateTableSeatCount(tableId, -1)
    elseif (not previousPlayer) and currentPlayer and tableId then
        updateTableSeatCount(tableId, 1)
    elseif previousPlayer and currentPlayer and previousPlayer ~= currentPlayer and tableId then
        -- Same seat changed occupant; count remains stable but update downstream listeners.
        notifySeatCountChanged(tableId)
    end

    occupiedPlayerBySeat[seat] = currentPlayer

    if not currentPlayer then
        return
    end

    local tableModel = getTableModelFromSeat(seat)
    if not tableModel then
        debugLog(string.format("Seat occupied but no table model found for seat=%s", seat:GetFullName()))
        return
    end

    local grantTableId = tableModel:GetAttribute("TableId") or tableModel.Name
    toolService.Grant(currentPlayer, grantTableId)
end

function SeatService.Start(options)
    options = options or {}
    toolService = options.toolService
    debugLog = options.debugLog or debugLog
    onTableSeatCountChanged = options.onTableSeatCountChanged

    if not toolService then
        error("SeatService requires toolService")
    end

    for _, seat in ipairs(getSeats()) do
        local connection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            handleSeatChanged(seat)
        end)

        seatConnections[seat] = connection
        handleSeatChanged(seat)
    end

    debugLog(string.format("SeatService started with %d seat(s)", #getSeats()))
end

function SeatService.Stop()
    for seat, connection in pairs(seatConnections) do
        connection:Disconnect()
        if occupiedPlayerBySeat[seat] then
            toolService.Revoke(occupiedPlayerBySeat[seat])
        end
        occupiedPlayerBySeat[seat] = nil
        tableIdBySeat[seat] = nil
    end
    seatConnections = {}
    seatedCountByTableId = {}
    onTableSeatCountChanged = nil
end

return SeatService
