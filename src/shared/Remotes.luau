-- Shared remote names and a server Setup helper to create RemoteEvents.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")

local Remotes = {}

Remotes.Names = {
    ThrowRequest = "ThrowRequest",
    ScoreUpdate = "ScoreUpdate",
    RoundState = "RoundState",
    WinnerAnnouncement = "WinnerAnnouncement",
    ToolGrant = "ToolGrant",
}

-- Server-only: create RemoteEvents in Shared if missing and return a table of instances.
function Remotes.Setup()
    local instances = {}
    for key, name in pairs(Remotes.Names) do
        local existing = SharedFolder:FindFirstChild(name)
        if existing then
            instances[key] = existing
        else
            local ev = Instance.new("RemoteEvent")
            ev.Name = name
            ev.Parent = SharedFolder
            instances[key] = ev
        end
    end
    return instances
end

return Remotes
