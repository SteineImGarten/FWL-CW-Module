local HL = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/ModuleLoader.lua"))()

local Modules = { Name = {}, Id = {} }
local UtilityIds = {}
local WeaponIds = {}

for Key, Value in HL.Get("@UtilityIds") do
    UtilityIds[Key:lower()] = Value
end

for Key, Value in HL.Get("@WeaponIds") do
    WeaponIds[Key:lower()] = Value
end

local function WeaponData(ItemName, ItemId)
    local Key = ItemName and ItemName:lower():gsub("%s+", "")
    if Key and not WeaponIds[Key] then return end
    return (Key and HL.Get("@WeaponMetadata")[WeaponIds[Key]]) or HL.Get("@WeaponMetadata")[ItemId]
end

local function UtilityData(ItemName, ItemId)
    local Key = ItemName and ItemName:lower():gsub("%s+", "")
    if Key and not UtilityIds[Key] then return end
    return (Key and HL.Get("@UtilityMetadata")[UtilityIds[Key]]) or HL.Get("@UtilityMetadata")[ItemId]
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
            local meta = HL.Get("@WeaponMetadata")[Tool:GetAttribute("ItemId")]
            if meta and meta.class:lower():match("ranged") then
                return Tool, HL.Get("@RangedWeaponClient").getObj(Tool)
            end
        end
    end
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
    local UserInputService = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera

    local function DefaultCheck(Player)
        local Char = Player.Character
        return Char and Char:FindFirstChild("HumanoidRootPart") and Char:FindFirstChild("Humanoid") and Char.Humanoid.Health > 0
    end

    local Distance = Distance or math.huge
    local FOV = FOV or math.huge
    local CheckFunction = CheckFunction or DefaultCheck
    local ClosestPlayer
    local MousePosition = UserInputService:GetMouseLocation()

    for _, Player in Players:GetPlayers() do
        if Player == LocalPlayer then continue end
        if not CheckFunction(Player) then continue end

        local HRP = Player.Character.HumanoidRootPart
        local VectorPos, OnScreen = Camera:WorldToScreenPoint(HRP.Position)

        if OnScreen then
            local ScreenDistance = (MousePosition - Vector2.new(VectorPos.X, VectorPos.Y)).Magnitude
            if ScreenDistance < Distance and ScreenDistance <= FOV then
                Distance = ScreenDistance
                ClosestPlayer = Player
            end
        end
    end

    return ClosestPlayer
end

return {
    HL = HL,
    WeaponData = WeaponData,
    UtilityData = UtilityData,
    MeleeWeapon = MeleeWeapon,
    RangedWeapon = RangedWeapon,
    PlayerState = PlayerState,
    SessionData = SessionData,
    ClosestPlayer = ClosestPlayer,
    HealthTarget = HealthTarget,
    MouseTarget = MouseTarget,
}
