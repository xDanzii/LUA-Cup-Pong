# Roblox Cup Pong

Commission project built for a reusable, multiplayer Cup Pong system. Commissioned by 'Cyq'

## Features

- Seat-based tool access
- Charged throws (hold and release)
- Server-authoritative scoring
- Shared leaderboard points
- Per-table round flow
- Winner announcements

## Project Structure

See [default.project.json](default.project.json) for Rojo mapping.

```text
src/
	client/
		main.client.luau
	server/
		main.server.luau
		services/
			BallSpawner.luau
			CupDetector.luau
			LeaderboardService.luau
			ScoreService.luau
			SeatService.luau
			TableController.luau
			TableManager.luau
			ThrowService.luau
			ToolService.luau
	shared/
		Config.luau
		Remotes.luau
		Changelog.luau
```

## Quick Setup (Recommended: Rojo)

1. Keep this folder layout intact.
2. Start Rojo sync for this project.
3. Open your place in Studio and connect the Rojo plugin.
4. Verify scripts appear in the mapped services:
	 - `src/server` -> `ServerScriptService`
	 - `src/client` -> `StarterPlayerScripts`
	 - `src/shared` -> `ReplicatedStorage/Shared`

## Manual Setup

If you are not using Rojo sync, place scripts manually:

1. Put [src/server/main.server.luau](src/server/main.server.luau) and [src/server/services](src/server/services) in `ServerScriptService`.
2. Put [src/client/main.client.luau](src/client/main.client.luau) in `StarterPlayerScripts`.
3. Put [src/shared](src/shared) in `ReplicatedStorage` as `Shared`.

## Studio Table Hierarchy

Create the gameplay tables like this:

```text
Workspace
	GameTables (Folder)
		TableA (Model)
			[Attribute] TableId = "TableA"

			Cups (Folder)
				CupA (BasePart or MeshPart)
					[Attribute] CupId = "CupA" (recommended)
				CupB (BasePart or MeshPart)
					[Attribute] CupId = "CupB" (recommended)
				CupC (BasePart or MeshPart)
					[Attribute] CupId = "CupC" (recommended)

			Seats (Folder)
				Seat1 (Seat or VehicleSeat)
				Seat2 (Seat or VehicleSeat)

			TableParts (Folder)
				TableTop (BasePart)
```

## Required/Recommended Attributes

- Required on each table model:
	- `TableId` (String)
- Recommended on each cup:
	- `CupId` (String)

## Notes

- Cups should be `BasePart` or `MeshPart` with good collision geometry.
- If table detection fails, check `Workspace/GameTables` naming and table model structure.
- Debug output is enabled through [src/shared/Config.luau](src/shared/Config.luau).

## Support

If you run into issues, contact: `xDanzii` on Discord.
