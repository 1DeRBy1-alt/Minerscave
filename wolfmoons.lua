if _G.meteorLoaded then return end
_G.meteorLoaded = true

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Anti-Kick
if hookmetamethod then
    local oldhmmi
    local oldhmmnc
    oldhmmi = hookmetamethod(game, "__index", function(self, method)
        if self == LocalPlayer and typeof(method) == "string" and method:lower() == "kick" then
            return error("Expected ':' not '.' calling member function Kick", 2)
        end
        return oldhmmi(self, method)
    end)
    oldhmmnc = hookmetamethod(game, "__namecall", function(self, ...)
        if self == LocalPlayer and getnamecallmethod():lower() == "kick" then
            return
        end
        return oldhmmnc(self, ...)
    end)
end

local Library = loadstring(game:HttpGet("https://gist.githubusercontent.com/1DeRBy1-alt/2fa6f5c2a7b61467130591d43ba9a6bd/raw/meteorUI.lua"))()

local CombatWindow = Library:CreateWindow("Combat", UDim2.new(0.05, 0, 0.1, 0))
local MovementWindow = Library:CreateWindow("Movement", UDim2.new(0.22, 0, 0.1, 0))
local WorldWindow = Library:CreateWindow("World", UDim2.new(0.39, 0, 0.1, 0))

local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local MainScript = PlayerScripts:WaitForChild("MainLocalScript")

local env = getsenv(MainScript)

local blocksFolder = Workspace:WaitForChild("Blocks")
local fluidFolder = Workspace:WaitForChild("Fluid")

local AssetsMod = ReplicatedStorage:WaitForChild("AssetsMod")
local Globals = require(MainScript:WaitForChild("CGlobals"))
local M_World = require(MainScript:WaitForChild("CWorld"))
local M_ItemInfo = require(ReplicatedStorage:WaitForChild("AssetsMod"):WaitForChild("ItemInfo"))
local M_IDs = require(ReplicatedStorage:WaitForChild("AssetsMod"):WaitForChild("IDs"))

local BlocksByName = M_IDs.ByName.Blocks
local GameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local AttackRemote = GameRemotes:WaitForChild("Attack")
local PlaceBlockRemote = GameRemotes:WaitForChild("PlaceBlock")
local BreakBlockRemote = GameRemotes:WaitForChild("BreakBlock")
local AcceptBreakBlockRemote = GameRemotes:WaitForChild("AcceptBreakBlock")

local BLOCKSIZE = 3

local Config = {
    KillAura = { Enabled = false, Delay = 10, Range = 16.5 },
    MobAura = { Enabled = false, Delay = 10, Range = 16.5 },
    Triggerbot = { Enabled = false, Delay = 0.25 },
    Scaffold = { Enabled = false, Range = 1 },
    Nuker = { Enabled = false, Range = 3 },
    FastBreak = { Enabled = false },
    NoFall = { Enabled = false },
    Jesus = { Enabled = false },
    AirPlace = { Enabled = false, Range = 6 }
}

-- No Fall
local oldReqDamage
local function hookDamageSystem()
    if MainScript and typeof(env.reqDamage) == "function" then
        oldReqDamage = hookfunction(env.reqDamage, function(amount, damageType)
            if Config.NoFall.Enabled and damageType == "fall" then
                return
            end
            return oldReqDamage(amount, damageType)
        end)
    else
        warn("reqDamage not found. NoFall will not work")
    end
end
task.spawn(hookDamageSystem)

local function worldToBlock(x, y, z)
    return math.floor(x / BLOCKSIZE + 0.5), math.floor(y / BLOCKSIZE + 0.5), math.floor(z / BLOCKSIZE + 0.5)
end

local function getEquippedBlockSlot()
    local activeSlotId = Globals.getSelSlot()
    if not activeSlotId then return nil end
    
    local inventory = Globals.getInventory()
    if not inventory then return nil end
    
    local slotData = inventory[tostring(activeSlotId)]
    if slotData and slotData.count and slotData.count > 0 and slotData.name then
        local itemData = M_ItemInfo[slotData.name]
        if itemData then
            local blockName = itemData.block or (type(itemData.placeable) == "string" and itemData.placeable or itemData.placeable and slotData.name)
            if blockName then
                local blockData = BlocksByName[blockName]
                if blockData then
                    return activeSlotId, blockData.id
                end
            end
        end
    end
    return nil
end

local function setCollision(state)
    if not fluidFolder then return end
    for _, obj in ipairs(fluidFolder:GetDescendants()) do
        if obj.Name == "Water" or obj.Name == "Lava" then
            obj.CanCollide = state
        end
    end
end

local function getRay()
    local camera = workspace.CurrentCamera
    return LocalPlayer:GetMouse().UnitRay
end

local function getAirPlaceTarget(range)
    local ray = getRay()
    local pos = ray.Origin + (ray.Direction * (range * BLOCKSIZE))
    if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then return end
    return worldToBlock(pos.X, pos.Y, pos.Z)
end

local function isBlockOccupied(x, y, z)
    if not x or not y or not z then return true end
    local block = M_World.getBlock(x, y, z)
    if not block then return false end
    if type(block) == "table" then
        for _, v in pairs(block) do
            if v ~= 0 and v ~= nil then return true end
        end
        return false
    end
    return block and block.id ~= nil
end

local KillAuraMod = CombatWindow:AddModule("Kill Aura", "Attacks players inside your range.", function(state)
    Config.KillAura.Enabled = state
end)
KillAuraMod:AddCategory("Settings")
KillAuraMod:AddSlider("Delay (Ticks)", 1, 60, 13, 1, function(val)
    Config.KillAura.Delay = math.round(val)
end)
KillAuraMod:AddSlider("Range (Studs)", 5, 20, 16.5, 0.5, function(val)
    Config.KillAura.Range = val
end)

local MobAuraMod = CombatWindow:AddModule("Mob Aura", "Attacks mobs/entities inside your range.", function(state)
    Config.MobAura.Enabled = state
end)
MobAuraMod:AddCategory("Settings")
MobAuraMod:AddSlider("Delay (Ticks)", 1, 60, 13, 1, function(val)
    Config.MobAura.Delay = math.round(val)
end)
MobAuraMod:AddSlider("Range (Studs)", 5, 20, 16.5, 0.5, function(val)
    Config.MobAura.Range = val
end)

local TriggerbotMod = CombatWindow:AddModule("Triggerbot", "Attacks the player you are hovering over", function(state)
    Config.Triggerbot.Enabled = state
end)

local NoFallMod = MovementWindow:AddModule("No Fall", "Toggles fall damage.", function(state)
    Config.NoFall.Enabled = state
end)

local JesusMod = MovementWindow:AddModule("Jesus", "Walk on water/lava", function(state)
    Config.Jesus.Enabled = state
end)

local ScaffoldMod = WorldWindow:AddModule("Scaffold", "Places blocks underneath your position", function(state)
    Config.Scaffold.Enabled = state
end)
ScaffoldMod:AddCategory("Settings")
ScaffoldMod:AddSlider("Fill Range", 1, 5, 1, 1, function(val)
    Config.Scaffold.Range = math.round(val)
end)

local FastBreakMod = WorldWindow:AddModule("Fast Break", "Break blocks faster.", function(state)
    Config.FastBreak.Enabled = state
end)

local NukerMod = WorldWindow:AddModule("Nuker", "Breaks blocks around you", function(state)
    Config.Nuker.Enabled = state
end)
NukerMod:AddCategory("Settings")
NukerMod:AddSlider("Range", 1, 5, 3, 1, function(val)
    Config.Nuker.Range = math.round(val)
end)

local AirPlaceMod = WorldWindow:AddModule("Air Place", "Place blocks in air with range", function(state)
    Config.AirPlace.Enabled = state
end)
AirPlaceMod:AddCategory("Settings")
AirPlaceMod:AddSlider("Range", 1, 20, 6, function(val)
    Config.AirPlace.Range = math.round(val)
end)

-- Kill Aura
task.spawn(function()
    local auraTicks = 0
    local lastAuraAttack = 0
    while true do
        task.wait()
        if not Config.KillAura.Enabled then continue end
        
        local aura = Config.KillAura
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        
        auraTicks = auraTicks + 1
        if (auraTicks - lastAuraAttack) < aura.Delay then continue end
        
        local target = nil
        local closestDist = aura.Range
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local enemyHum = player.Character:FindFirstChild("Humanoid")
                if enemyRoot and enemyHum and enemyHum.Health > 0 then
                    local dist = (root.Position - enemyRoot.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        target = player.Character
                    end
                end
            end
        end
        
        if target then
            lastAuraAttack = auraTicks
            task.spawn(function()
                AttackRemote:InvokeServer(target)
            end)
        end
    end
end)

-- Mob Aura
task.spawn(function()
    local mobAuraTicks = 0
    local lastMobAttack = 0
    while true do
        task.wait()
        if not Config.MobAura.Enabled then continue end
        
        local mobAura = Config.MobAura
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        
        mobAuraTicks = mobAuraTicks + 1
        if (mobAuraTicks - lastMobAttack) < mobAura.Delay then continue end
        
        local target = nil
        local closestDist = mobAura.Range
        
        local entities = workspace:FindFirstChild("Entities")
        if entities then
            for _, entity in ipairs(entities:GetChildren()) do
                local enemyRoot = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChildWhichIsA("BasePart")
                local enemyHum = entity:FindFirstChildOfClass("Humanoid")
                if enemyRoot then
                    local isAlive = true
                    if enemyHum and enemyHum.Health <= 0 then
                        isAlive = false
                    end
                    if isAlive then
                        local dist = (root.Position - enemyRoot.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            target = entity
                        end
                    end
                end
            end
        end
        
        if target then
            lastMobAttack = mobAuraTicks
            task.spawn(function()
                AttackRemote:InvokeServer(target)
            end)
        end
    end
end)

-- Triggerbot
task.spawn(function()
    while task.wait(Config.Triggerbot.Delay) do
        if not Config.Triggerbot.Enabled then continue end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        
        local camera = workspace.CurrentCamera
        local ray = Ray.new(camera.CFrame.Position, camera.CFrame.LookVector * Config.KillAura.Range)
        local part = workspace:FindPartOnRay(ray, char)
        if not part or not part.Parent then continue end
        
        local targetModel = part.Parent
        local hum = targetModel:FindFirstChildOfClass("Humanoid")
        local isPlayer = Players:GetPlayerFromCharacter(targetModel)
        local isMob = targetModel:IsDescendantOf(workspace:FindFirstChild("Entities") or workspace)
        
        if hum and hum.Health > 0 and (isPlayer or isMob) then
            task.spawn(function()
                AttackRemote:InvokeServer(targetModel)
            end)
        end
    end
end)

-- Scaffold
task.spawn(function()
    local scaffoldDebounce = false
    local scaffoldConnection
    scaffoldConnection = RunService.PostSimulation:Connect(function()
        if not Config.Scaffold.Enabled or scaffoldDebounce then return end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if not root or not hum then return end
        
        local blockSlot, blockId = getEquippedBlockSlot()
        if not blockSlot or not blockId then return end
        
        local px = math.floor(root.Position.X / BLOCKSIZE + 0.5)
        local py = math.floor((root.Position.Y - 3) / BLOCKSIZE + 0.5) - 1
        local pz = math.floor(root.Position.Z / BLOCKSIZE + 0.5)
        
        local extent = math.floor(Config.Scaffold.Range / 2)
        
        local targets = {}
        for dx = -extent, extent do
            for dz = -extent, extent do
                local tx, ty, tz = px + dx, py, pz + dz
                local block, chunk = M_World.getBlock(tx, ty, tz)
                
                if chunk and (not block or not block.id) then
                    table.insert(targets, {x = tx, y = ty, z = tz, chunk = chunk})
                end
            end
        end
        
        if #targets > 0 then
            scaffoldDebounce = true
            task.spawn(function()
                for _, t in ipairs(targets) do
                    M_World.placeBlock(t.x, t.y, t.z, t.chunk, 5, blockId)
                    local serverPlaced = PlaceBlockRemote:InvokeServer(t.x, t.y, t.z, blockSlot, 5)
                end
                task.wait()
                scaffoldDebounce = false
            end)
        end
    end)
end)

-- Nuker
task.spawn(function()
    local nukerDebounce = false
    local nukerConnection
    nukerConnection = RunService.PostSimulation:Connect(function()
        if not Config.Nuker.Enabled or nukerDebounce then return end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local px, py, pz = worldToBlock(root.Position.X, root.Position.Y - 1, root.Position.Z)
        local range = Config.Nuker.Range
        local targets = {}
        
        for dx = -range, range do
            for dz = -range, range do
                local tx, ty, tz = px + dx, py - 1, pz + dz
                local block, chunk = M_World.getBlock(tx, ty, tz)
                if chunk and block and block.id then
                    table.insert(targets, {x = tx, y = ty, z = tz, chunk = chunk, id = block.id})
                end
            end
        end
        
        if #targets > 0 then
            nukerDebounce = true
            task.spawn(function()
                for _, t in ipairs(targets) do
                    BreakBlockRemote:FireServer(t.x, t.y, t.z)
                    task.spawn(function()
                        AcceptBreakBlockRemote:InvokeServer()
                    end)
                end
                task.wait(0.5)
                nukerDebounce = false
            end)
        end
    end)
end)

-- FastBreak
task.spawn(function()
    while task.wait(0.05) do
        if Config.FastBreak.Enabled then
            AcceptBreakBlockRemote:InvokeServer()
        end
    end
end)

-- Jesus
task.spawn(function()
    while task.wait(0.25) do
        if Config.Jesus.Enabled then
            setCollision(true)
        else
            setCollision(false)
        end
    end
end)

-- Air Place
task.spawn(function()
    local lastPlace = 0
    local COOLDOWN = 0.12
    
    local previewPart = Instance.new("Part")
    previewPart.Name = "AirPlacePreview"
    previewPart.Size = Vector3.new(BLOCKSIZE, BLOCKSIZE, BLOCKSIZE)
    previewPart.Anchored = true
    previewPart.CanCollide = false
    previewPart.Material = Enum.Material.ForceField
    previewPart.Color = Color3.fromRGB(200, 60, 60)
    previewPart.Transparency = 0.6
    
    local box = Instance.new("SelectionBox")
    box.Adornee = previewPart
    box.LineThickness = 0.05
    box.Color3 = Color3.fromRGB(200, 60, 60)
    box.SurfaceTransparency = 1
    box.Parent = previewPart
    
    RunService.RenderStepped:Connect(function()
        if not Config.AirPlace.Enabled then
            previewPart.Parent = nil
            return
        end
        
        local blockSlot, blockId = getEquippedBlockSlot()
        if not blockSlot or not blockId then
            previewPart.Parent = nil
            return
        end
        
        local x, y, z = getAirPlaceTarget(Config.AirPlace.Range)
        if not x or isBlockOccupied(x, y, z) then
            previewPart.Parent = nil
            return
        end
        
        previewPart.Parent = workspace
        previewPart.Position = Vector3.new(x * BLOCKSIZE, y * BLOCKSIZE, z * BLOCKSIZE)
    end)
    
    UIS.InputBegan:Connect(function(input, processed)
        if processed or input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
        if not Config.AirPlace.Enabled then return end
        
        if tick() - lastPlace < COOLDOWN then return end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local blockSlot, blockId = getEquippedBlockSlot()
        if not blockSlot or not blockId then return end
        
        local x, y, z = getAirPlaceTarget(Config.AirPlace.Range)
        if not x or isBlockOccupied(x, y, z) then return end
        
        local block, chunk = M_World.getBlock(x, y, z)
        if not chunk then return end
        
        lastPlace = tick()
        task.spawn(function()
            M_World.placeBlock(x, y, z, chunk, 5, blockId)
            PlaceBlockRemote:InvokeServer(x, y, z, blockSlot, 5)
        end)
    end)
end)
