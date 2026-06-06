print("Hello world, from server (main)!")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent

-- Initialize shared remotes (server-side)
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = require(Shared:WaitForChild("Config"))
local remoteInstances = Remotes.Setup()

local ServicesFolder = Server:WaitForChild("services")

local function requireService(serviceName)
	local candidate = ServicesFolder:FindFirstChild(serviceName) or ServicesFolder:FindFirstChild(serviceName .. ".luau")

	if (not candidate) or (not candidate:IsA("ModuleScript")) then
		for _, descendant in ipairs(ServicesFolder:GetDescendants()) do
			if descendant:IsA("ModuleScript") and (descendant.Name == serviceName or descendant.Name == (serviceName .. ".luau")) then
				candidate = descendant
				break
			end
		end
	end

	if not candidate then
		error(string.format("Missing service ModuleScript '%s' under services folder", serviceName))
	end

	if not candidate:IsA("ModuleScript") then
		error(string.format("Service '%s' exists but is not a ModuleScript (class=%s)", serviceName, candidate.ClassName))
	end

	return require(candidate)
end

local LeaderboardService = requireService("LeaderboardService")
local ScoreService = requireService("ScoreService")
local TableManager = requireService("TableManager")
local BallSpawner = requireService("BallSpawner")
local ThrowService = requireService("ThrowService")
local ToolService = requireService("ToolService")
local SeatService = requireService("SeatService")

local function debugLog(message)
	if not Config.DEBUG_LOGS then
		return
	end
	print("[MainServer] " .. message)
end

-- Server bootstrap placeholder. This is the central entrypoint that will
-- require and start the smaller services under `src/server/services/`.
if Config.USE_LEADERSTATS then
	LeaderboardService.Start(remoteInstances)
	debugLog("LeaderboardService started with leaderstats enabled")
else
	debugLog("LeaderboardService skipped because USE_LEADERSTATS is false")
end

ScoreService.Start({
	leaderboardService = LeaderboardService,
	pointsPerShot = Config.SCORE_PER_SHOT,
	scoreUpdateRemote = remoteInstances.ScoreUpdate,
})
debugLog("ScoreService started")

ToolService.Start({
	toolName = Config.TOOL_NAME,
	toolGrantRemote = remoteInstances.ToolGrant,
	debugLog = function(message)
		debugLog("[ToolService] " .. message)
	end,
})
debugLog("ToolService started")

BallSpawner.Start({
	ballAssetId = Config.BALL_ASSET_ID,
	ballLifetime = Config.BALL_LIFETIME,
	throwSpeed = Config.THROW_SPEED,
	throwVerticalBoost = Config.THROW_VERTICAL_BOOST,
	ballDiameter = Config.BALL_DIAMETER,
	ballDensity = Config.BALL_DENSITY,
	ballFriction = Config.BALL_FRICTION,
	ballElasticity = Config.BALL_ELASTICITY,
	debugLog = function(message)
		debugLog("[BallSpawner] " .. message)
	end,
})

ThrowService.Start({
	throwRequestRemote = remoteInstances.ThrowRequest,
	ballSpawner = BallSpawner,
	throwCooldown = Config.THROW_COOLDOWN,
	throwMinSpeed = Config.THROW_MIN_SPEED,
	throwMaxSpeed = Config.THROW_MAX_SPEED,
	throwMinVerticalBoost = Config.THROW_MIN_VERTICAL_BOOST,
	throwMaxVerticalBoost = Config.THROW_MAX_VERTICAL_BOOST,
	debugLog = function(message)
		debugLog("[ThrowService] " .. message)
	end,
})
debugLog("ThrowService started")

TableManager.Start({
	scoreService = ScoreService,
	roundLength = Config.ROUND_LENGTH,
	roundIntermission = 5,
	roundStateRemote = remoteInstances.RoundState,
	winnerRemote = remoteInstances.WinnerAnnouncement,
	debugLog = function(message)
		debugLog("[TableManager] " .. message)
	end,
})

SeatService.Start({
	toolService = ToolService,
	onTableSeatCountChanged = function(tableId, seatedPlayerCount)
		TableManager.SetSeatedPlayerCount(tableId, seatedPlayerCount)
	end,
	debugLog = function(message)
		debugLog("[SeatService] " .. message)
	end,
})
debugLog("SeatService started")

