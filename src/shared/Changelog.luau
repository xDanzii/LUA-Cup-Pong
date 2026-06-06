-- Changelog for the ping-pong cup game
-- Replace or append entries as you make changes.

local Changelog = {}
Changelog.entries = {
    [1] = "2026-06-06: Renamed entry scripts to main.client/main.server; added shared Config and Remotes scaffolding.",
}

function Changelog.add(entry)
    table.insert(Changelog.entries, 1, entry)
end

return Changelog
