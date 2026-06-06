local ToolService = {}

local toolName = "PingPongBallTool"
local toolGrantRemote = nil
local debugLog = function(_message)
end

local function createTool()
    local tool = Instance.new("Tool")
    tool.Name = toolName
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.ToolTip = "Click or tap to throw the ping pong ball"
    return tool
end

local function findOwnedTool(container)
    if not container then
        return nil
    end

    local existing = container:FindFirstChild(toolName)
    if existing and existing:IsA("Tool") then
        return existing
    end

    return nil
end

function ToolService.Start(options)
    options = options or {}
    toolName = options.toolName or toolName
    toolGrantRemote = options.toolGrantRemote
    debugLog = options.debugLog or debugLog
end

function ToolService.Grant(player, tableId)
    if not player then
        return
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        debugLog(string.format("Grant skipped for %s: missing Backpack", player.Name))
        return
    end

    local existing = findOwnedTool(backpack) or findOwnedTool(player.Character)
    if not existing then
        local tool = createTool()
        tool.Parent = backpack
    end

    player:SetAttribute("CurrentTableId", tableId)

    if toolGrantRemote then
        toolGrantRemote:FireClient(player, {
            granted = true,
            tableId = tableId,
            toolName = toolName,
        })
    end

    debugLog(string.format("Granted tool to %s for table=%s", player.Name, tostring(tableId)))
end

function ToolService.Revoke(player)
    if not player then
        return
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    local character = player.Character

    local backpackTool = findOwnedTool(backpack)
    if backpackTool then
        backpackTool:Destroy()
    end

    local characterTool = findOwnedTool(character)
    if characterTool then
        characterTool:Destroy()
    end

    player:SetAttribute("CurrentTableId", nil)

    if toolGrantRemote then
        toolGrantRemote:FireClient(player, {
            granted = false,
            toolName = toolName,
        })
    end

    debugLog(string.format("Revoked tool from %s", player.Name))
end

return ToolService
