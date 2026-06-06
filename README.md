# Cup Pong script
Originally a commission made for a user named cyq.

# How to setup
MANUAL
1. Copy these folders/files into your project:
main.server.luau is your server entry script. It should be placed under ServerScriptService in Roblox.
main.client.luau is your client entry script. It should be placed under StarterPlayerScripts in Roblox.
src/server -> ServerScriptService
src/client -> StarterPlayerScripts
2. Everything in the shared folder should go to ReplicatedStorage/shared so both server and client can require it.

3. Setup the pong tables
Create Workspace/GameTables.
Put each playable table as a Model inside GameTables.
For each table model:
Set attribute TableId (string, unique per table), or just rely on model name.
Add a Cups folder containing all cup parts.
Add seats (Seat or VehicleSeat) under that table model for player seating logic.

4. Setup Cups
Cups should be BaseParts (or MeshParts) with stable collider geometry.
Keep cup colliders anchored for reliable hit detection (already controlled in config).
Optional but recommended: set CupId attribute on each cup for stable identifiers.

5. 
Test if it all works!
Debug should tell you whether or not the tables are identified.
Plenty of debug if any issues arise.

Please test it out using the 

AUTOMATIC
Use Rojo sync!

Any issues DM me on discord: xDanzii