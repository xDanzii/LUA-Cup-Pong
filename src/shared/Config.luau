-- Shared configuration values for the game.
-- Change these values to tune rounds, assets, and feature flags.

local Config = {}

-- Round length in seconds (default 60 seconds).
Config.ROUND_LENGTH = 60

-- Creator Store asset id for the Ping Pong Ball. Replace if you want a different model.
Config.BALL_ASSET_ID = 166283220

-- Use Roblox `leaderstats` for the scoreboard when true. If false, UI-based scoreboard will be used.
-- Change this flag and implement the alternative UI when switching.
Config.USE_LEADERSTATS = true

-- Set true to enable server debug traces while developing.
Config.DEBUG_LOGS = true

-- Other tuning
Config.BALL_LIFETIME = 20 -- seconds before auto-cleanup
Config.SCORE_PER_SHOT = 1
Config.THROW_COOLDOWN = 0.5
Config.THROW_SPEED = 62
Config.THROW_MIN_SPEED = 14
Config.THROW_MAX_SPEED = 100
Config.CHARGE_MAX_SECONDS = 1.0
Config.THROW_VERTICAL_BOOST = 6
Config.THROW_MIN_VERTICAL_BOOST = 0.8
Config.THROW_MAX_VERTICAL_BOOST = 9.2
Config.BALL_DIAMETER = 0.5
Config.BALL_DENSITY = 0.35
Config.BALL_FRICTION = 0.35
Config.BALL_ELASTICITY = 0.15
Config.SCORE_BALL_REMOVE_DELAY = 0.35
Config.TOOL_NAME = "PingPongBallTool"

return Config
