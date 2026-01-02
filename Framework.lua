local HL = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/ModuleLoader.lua"))()
local Kalman = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/Kalman.lua"))()

local Modules = { Name = {}, Id = {} }
local UtilityIds = {}
local WeaponIds = {}

local WeaponOrder = {}
local AllItemsDefault = {}

local function ItemData(ItemName, ItemId)
    local Key = ItemName and ItemName:lower():gsub("%s+", "")
    if Key and not WeaponIds[Key] and not UtilityIds[Key] then return end

    if Key and WeaponIds[Key] then
        return HL.Get("@WeaponMetadata")[WeaponIds[Key]]
    elseif Key and UtilityIds[Key] then
        return HL.Get("@UtilityMetadata")[UtilityIds[Key]]
    else
        return HL.Get("@WeaponMetadata")[ItemId] or HL.Get("@UtilityMetadata")[ItemId]
    end
end

spawn(function()
    repeat task.wait(0.05) until getgenv().LOAD_FINISHED

    for Key, Value in HL.Get("@UtilityIds") do
        UtilityIds[Key:lower()] = Value
    end

    for Key, Value in HL.Get("@WeaponIds") do
        WeaponIds[Key:lower()] = Value
    end

    for i, v in HL.Get("@WeaponsInOrder") do
        WeaponOrder[v.id] = v
    end

    for Key, Id in pairs(WeaponIds) do
        local Meta = HL.Get("@WeaponMetadata")[Id]
        if Meta then
            table.insert(AllItemsDefault, {Name = Key, OG = table.clone(Meta)})
        end
    end

    for Key, Id in pairs(UtilityIds) do
        local Meta = HL.Get("@UtilityMetadata")[Id]
        if Meta then
            table.insert(AllItemsDefault, {Name = Key, OG = table.clone(Meta)})
        end
    end
end)

local function NormalizeKey(str)
    return str:lower():gsub("%s+", "")
end

local function WaitForItems()
    repeat task.wait(0.05) until #AllItemsDefault > 0
end

local function MeleeWeapon(Player)
    local Players = game:GetService("Players")
    local Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    for _, Tool in Character:GetChildren() do
        if Tool:IsA("Tool") and Tool:GetAttribute("ItemType") == "weapon" then
            local meta = HL.Get("@WeaponMetadata")[Tool:GetAttribute("ItemId")]
            if meta and meta.class:lower():match("melee") then
                return Tool, HL.Get("@MeleeWeaponClient").getObj(Tool)
            end
        end
    end
end

local function RangedWeapon(Player)
    local Players = game:GetService("Players")
    local Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    for _, Tool in Character:GetChildren() do
        if Tool:IsA("Tool") and Tool:GetAttribute("ItemType") == "weapon" then
            local Meta = HL.Get("@WeaponMetadata")[Tool:GetAttribute("ItemId")]
            if Meta and Meta.class:lower():match("ranged") then
                return Tool, HL.Get("@RangedWeaponClient").getObj(Tool)
            end
        end
    end
end

local function ModRanged(Name, Value)
    for _, v in AllItemsDefault do
        local Meta = ItemData(v.Name)
        if Meta and Meta[Name] then
            Meta[Name] = Value
        end
    end
end

local function PrintTable(tbl, indent)
    indent = indent or ""
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            print(indent .. key .. " :")
            PrintTable(value, indent .. "  ")
        else
            print(indent .. key .. " : " .. tostring(value))
        end
    end
end

local function PrintWepStats(Player)
    WaitForItems()

    local Players = game:GetService("Players")
    local Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    local Tool
    for _, item in Character:GetChildren() do
        if item:IsA("Tool") and item:GetAttribute("ItemType") == "weapon" then
            Tool = item
            break
        end
    end

    if not Tool then
        warn("No weapon equipped!")
        return
    end

    local WeaponKey = NormalizeKey(Tool.Name)
    print("Stats for currently held weapon: " .. Tool.Name)

    for _, item in ipairs(AllItemsDefault) do
        if NormalizeKey(item.Name) == WeaponKey then
            PrintTable(item.OG, "  ")
            return
        end
    end

    warn("Weapon stats not found in AllItemsDefault: " .. Tool.Name)
end

local function PlayerState()
    return HL.Get("@RoduxStore").store:getState()
end

local function SessionData(Player)
    local Players = game:GetService("Players")
    return HL.Get("@DataHandler").getSessionDataRoduxStoreForPlayer(Player or Players.LocalPlayer)
end

local function ClosestPlayer(Distance, Priority, CheckFunction)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local function DefaultCheck(Player)
        local Char = Player.Character
        return Char and Char:FindFirstChild("HumanoidRootPart") and Char:FindFirstChild("Humanoid") and Char.Humanoid.Health > 0
    end

    local Distance = Distance or math.huge
    local CheckFunction = CheckFunction or DefaultCheck
    local PlayersTable = {}

    for _, Player in Players:GetPlayers() do
        if Player == LocalPlayer then continue end
        if not CheckFunction(Player) then continue end

        local HRP = Player.Character.HumanoidRootPart
        local Magnitude = (HRP.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude

        if Magnitude < Distance then
            Distance = Magnitude
            PlayersTable[Player.Name] = Player.Character.Humanoid.Health
        end
    end

    if Priority then
        table.sort(PlayersTable)
    end
    return PlayersTable
end

local function HealthTarget(Distance, Priority, CheckFunction)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local function DefaultCheck(Player)
        local Char = Player.Character
        return Char and Char:FindFirstChild("HumanoidRootPart") and Char:FindFirstChild("Humanoid") and Char.Humanoid.Health > 0 and not Char:FindFirstChildOfClass("ForceField")
    end

    local Distance = Distance or math.huge
    local Health = 115
    local CheckFunction = CheckFunction or DefaultCheck
    local ClosestPlayer

    for _, Player in Players:GetPlayers() do
        if Player == LocalPlayer then continue end
        if not CheckFunction(Player) then continue end

        local HRP = Player.Character.HumanoidRootPart
        local Magnitude = (HRP.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
        local CurrHealth = Player.Character.Humanoid.Health

        if Magnitude <= Distance and (Priority == "Health" and CurrHealth <= Health or true) then
            Distance = Magnitude
            Health = CurrHealth
            ClosestPlayer = Player
        end
    end

    return ClosestPlayer and { [ClosestPlayer.Name] = true } or nil
end

local function MouseTarget(Distance, FOV, CheckFunction)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    local Camera = workspace.CurrentCamera

    local VisPart = "Torso"

    local function DefaultCheck(Player)
        local Char = Player.Character
        return Char 
            and Char:FindFirstChild("HumanoidRootPart") 
            and Char:FindFirstChild("Humanoid") 
            and Char.Humanoid.Health > 0
    end

    Distance = Distance or math.huge
    FOV = FOV or math.huge
    CheckFunction = CheckFunction or DefaultCheck

    local ClosestPlayer = nil
    local ClosestDistance = Distance

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if not CheckFunction(Player) then continue end

        local Char = Player.Character
        if not Char then continue end

        local TargetPart = Char:FindFirstChild(VisPart)
            or Char:FindFirstChild("UpperTorso")
            or Char:FindFirstChild("HumanoidRootPart")

        if not TargetPart then continue end

        local ScreenPos, OnScreen = Camera:WorldToScreenPoint(TargetPart.Position)
        if not OnScreen then continue end

        local ScreenDistance = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(ScreenPos.X, ScreenPos.Y)).Magnitude
        if ScreenDistance < ClosestDistance and ScreenDistance <= FOV then
            ClosestDistance = ScreenDistance
            ClosestPlayer = Player
        end
    end

    return ClosestPlayer
end

return {
    Kalman = Kalman,
    HL = HL,
    ItemData = ItemData,
    ModRanged = ModRanged,
    PrintWepStats = PrintWepStats,
    MeleeWeapon = MeleeWeapon,
    RangedWeapon = RangedWeapon,
    PlayerState = PlayerState,
    SessionData = SessionData,
    ClosestPlayer = ClosestPlayer,
    HealthTarget = HealthTarget,
    MouseTarget = MouseTarget,
}
