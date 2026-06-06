local Workspace = game:GetService("Workspace")

local TableBuilder = {}

local function createCup(cupsFolder, position, cupId)
    local cup = Instance.new("Part")
    cup.Name = cupId
    cup.CanCollide = false
    cup.CanQuery = true
    cup.CanTouch = true
    cup.Material = Enum.Material.SmoothPlastic
    cup.Color = Color3.fromRGB(222, 241, 255)
    cup.Transparency = 0.35
    cup.Size = Vector3.new(2.5, 2.5, 2.5)
    cup.Position = position
    cup:SetAttribute("CupId", cupId)
    cup.Parent = cupsFolder
end

local function createTableModel(index, origin)
    local model = Instance.new("Model")
    model.Name = string.format("Table_%d", index)
    model:SetAttribute("IsGameTable", true)
    model:SetAttribute("TableId", model.Name)

    local surface = Instance.new("Part")
    surface.Name = "Surface"
    surface.Material = Enum.Material.WoodPlanks
    surface.Color = Color3.fromRGB(110, 78, 50)
    surface.Size = Vector3.new(30, 1, 14)
    surface.Position = origin
    surface.Parent = model

    local cupsFolder = Instance.new("Folder")
    cupsFolder.Name = "Cups"
    cupsFolder.Parent = model

    local cupXs = { -8, 0, 8 }
    for i, xOffset in ipairs(cupXs) do
        createCup(cupsFolder, origin + Vector3.new(xOffset, 2.0, -4.0), string.format("LeftCup_%d", i))
        createCup(cupsFolder, origin + Vector3.new(xOffset, 2.0, 4.0), string.format("RightCup_%d", i))
    end

    return model
end

function TableBuilder.EnsureGameTables(options)
    options = options or {}

    local tableCount = options.tableCount or 2
    local spacing = options.spacing or 44
    local startX = options.startX or -((tableCount - 1) * spacing) / 2
    local y = options.y or 5
    local z = options.z or 0
    local debugLog = options.debugLog or function(_message)
    end

    local root = Workspace:FindFirstChild("GameTables")
    if not root then
        root = Instance.new("Folder")
        root.Name = "GameTables"
        root.Parent = Workspace
    end

    local existingCount = 0
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("Model") then
            existingCount += 1
        end
    end

    if existingCount > 0 then
        debugLog(string.format("Using existing GameTables folder with %d table model(s)", existingCount))
        return root
    end

    for index = 1, tableCount do
        local x = startX + ((index - 1) * spacing)
        local tableModel = createTableModel(index, Vector3.new(x, y, z))
        tableModel.Parent = root
    end

    debugLog(string.format("Created %d default game table(s)", tableCount))
    return root
end

return TableBuilder
