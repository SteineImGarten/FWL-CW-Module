---=========================---#
--     ROBLOX FRAMEWORK    --
--=========================--

local FrameWork = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/Framework.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--=========================--
--      GLOBAL FLAGS       --
--=========================--

getgenv().EXECUTED = getgenv().EXECUTED or false
getgenv().Loaded_FIN = getgenv().Loaded_FIN or false

--=========================--
--     FRAMEWORK INIT      --
--=========================--

FrameWork.HL.Debug(true)
FrameWork.HL.Global(getgenv())
FrameWork.HL.Folders({
    ReplicatedStorage.Client.Source,
    ReplicatedStorage.Shared.Source,
    ReplicatedStorage.Shared.Vendor
})
FrameWork.HL.Load()

--=========================--
--       MISC FEATURES     --
--=========================--

if not getgenv().EXECUTED then
    local FovCircle = Drawing.new("Circle")
    FovCircle.Radius = getgenv().FOV
    FovCircle.Color = Color3.fromRGB(255, 0, 0)
    FovCircle.Filled = false
    FovCircle.NumSides = 32
    FovCircle.Transparency = 0.4
    FovCircle.Visible = true

    RunService.RenderStepped:Connect(function()
        local MousePos = UserInputService:GetMouseLocation()
        FovCircle.Position = Vector2.new(MousePos.X, MousePos.Y)
    end)
end

--=========================--
--      HELPER FUNCTIONS   --
--=========================--

local function GetHitParts(HitPosition)
    local Targets = {}
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        local Head = Player.Character and Player.Character:FindFirstChild("Head")
        if Head and (Head.Position - HitPosition).Magnitude <= getgenv().HitReach then
            table.insert(Targets, Head)
        end
    end
    return Targets
end

--=========================--
--       HOOKS & MODS      --
--=========================--

-- Toast Notification Hook

FrameWork.HL.Call("@ToastNotificationActionsClient", "add", "success", "Hook Finished", 5, true, {BypassHook = false})(FrameWork.HL.Get("@RoduxStore").store)
FrameWork.HL.Call("@SoundHandler", "playSound", {
    soundObject = game:GetService("ReplicatedStorage").Shared.Assets.Sounds.Success2,
    parent = Workspace.Sounds
})

FrameWork.HL.Hook("@ToastNotificationActionsClient", "add", "ConfigOne", function(Original, Type, Text, Duration, ShouldToast)
    return Original(Type, Text, Duration, ShouldToast)
end)

-- Silent Aim

FrameWork.HL.Hook("@RangedWeaponClient", "cancelReload", "SilentAimCancel", function(Original, ...)
    if getgenv().NoReloadCancel == true then
        return
    end
end, { Spy = false })

FrameWork.HL.Hook("@RangedWeaponHandler", "calculateFireDirection", "SilentAim", function(Original, ...)
    local Ranged, MetaData = FrameWork.RangedWeapon()
    local Args = {...}
    if typeof(Args[1]) == "CFrame" and getgenv().SilentAim == true then
        local Speed = MetaData._itemConfig.speed
        local Gravity = MetaData._itemConfig.gravity
        local Origin = LocalPlayer.Character.HumanoidRootPart.Position
        local Target = FrameWork.MouseTarget(nil, getgenv().FOV)
        if Target then
            Args[1] = FrameWork.Kalman.Predict(Target.Character:FindFirstChild(getgenv().HitPart), Origin, Speed, true, Gravity)
        end
    end
    return Original(table.unpack(Args))
end, { Spy = false })

-- Range Expander
FrameWork.HL.Hook("@MeleeWeaponClient", "onSlashRayHit", "RangeExpander", function(Original, ...)
    local Args = {...}
    local HitPosition = Args[6]
    if not getgenv().RangeExpander or not HitPosition then return Original(table.unpack(Args)) end

    local Targets = GetHitParts(HitPosition)
    if Targets and #Targets > 0 then
        for _, Target in ipairs(Targets) do
            Args[3] = Target
            Args[4] = { Position = Target.Position }
            Args[5] = Target.Position
            Original(table.unpack(Args))
        end
    else
        return Original(table.unpack(Args))
    end
end, { Spy = false })

-- Anti-Ragdoll
FrameWork.HL.Hook("@RagdollHandler", "toggleRagdoll", function(Original, ...)
    if getgenv().AntiRagdoll then return end
    return Original(...)
end)
FrameWork.HL.Hook("@RagdollHandlerClient", "toggleRagdoll", function(Original, ...)
    if getgenv().AntiRagdoll then return end
    return Original(...)
end)

-- Anti-Parry

FrameWork.HL.Hook("@SoundHandler", "playSound", "Anti-Parry", function(Original, ...)
    local Args = {...}
    local Sound = Args[1]

    if Sound.soundObject.Name == "Parry" and getgenv().AntiParry == true then
        local SourceParent = Sound.parent.Parent.Parent
        local Player = game.Players.LocalPlayer
        local Character = Player.Character

        if SourceParent ~= Character then
            local EquippedTools = {}
            for _, Tool in ipairs(Character:GetChildren()) do
                if Tool:IsA("Tool") and Tool:FindFirstChild("Hitboxes") then
                    table.insert(EquippedTools, Tool)
                    Tool.Parent = Player.Backpack
                end
            end

            task.spawn(function()
                for _, Tool in ipairs(EquippedTools) do
                    Tool.Parent = Character
                end
            end)
        end
    end

    return Original(...)

end, { Spy = false })

-- Stamina Mods

local DefaultStamina = FrameWork.HL.Call("@DefaultStaminaHandlerClient", "getDefaultStamina")
FrameWork.HL.Call("@Stamina", "setBaseMaxStamina", DefaultStamina, 1500)
FrameWork.HL.Call("@Stamina", "setStamina", DefaultStamina, 1)

DefaultStamina.gainDelay = 0
DefaultStamina.gainPerSecond = 250

FrameWork.HL.Hook("@DefaultStaminaHandlerClient", "spendStamina", "ConfigMaxed", function(Original, Stamina)
    Stamina = 1
    return Original(Stamina)
end)

-- Emotes Unlock

local EmotesTable = FrameWork.HL.Get("@EmotesInOrder")
local RoduxStore = FrameWork.HL.Get("@RoduxStore")
local RoduxState = RoduxStore.store:getState()
for i, v in EmotesTable do
    if typeof(v) == 'table' and v.id and RoduxState.OwnedEmotes then
        RoduxState.OwnedEmotes[v.id] = 1
    end
end

FrameWork.ModRanged("minSpread", 0)
FrameWork.ModRanged("maxSpread", 0)
FrameWork.ModRanged("gravity", Vector3.new())
FrameWork.ModRanged("maxDistance", 10000)
FrameWork.ModRanged("reloadWalkSpeedMultiplier", 2)
FrameWork.ModRanged("chargeOnDuration", 0.01)
FrameWork.ModRanged("chargeOffDuration", 0.01)
FrameWork.ModRanged("speed", 350)

--=========================--
--       FLY SYSTEM        --
--=========================--

local FlyEnabled = false

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == getgenv().Keybinds.Fly and getgenv().Fly == true then
        FlyEnabled = not FlyEnabled
        local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not HRP then return end

        if FlyEnabled and not HRP:FindFirstChild("flyVel") then
            local Attachment = Instance.new("Attachment", HRP)
            local LinearVelocity = FrameWork.HL.Call("@AntiCheatHandler", "createBodyMover", "LinearVelocity")
            LinearVelocity.Name = "flyVel"
            LinearVelocity.Attachment0 = Attachment
            LinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
            LinearVelocity.MaxForce = 1e8
            LinearVelocity.Parent = HRP
        elseif not FlyEnabled and HRP:FindFirstChild("flyVel") then
            HRP.flyVel:Destroy()
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if FlyEnabled then
        local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if HRP and HRP:FindFirstChild("flyVel") then
            local move = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
            if move.Magnitude > 0 then move = move.Unit * getgenv().FlySpeed end
            HRP.flyVel.VectorVelocity = move
        end
    end
end)

--=========================--
--         DESYNC          --
--=========================--

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if not GameProcessed and Input.KeyCode == getgenv().Keybinds.Desync then
        if getgenv().DesyncEnabled == true then               
            FrameWork.HL.Call("@ToastNotificationActionsClient", "add", "success", "Desynced", 5, true, {BypassHook = false})(getgenv()["@RoduxStore"].store)
            FrameWork.HL.Call("@SoundHandler", "playSound", {
            soundObject = game:GetService("ReplicatedStorage").Shared.Assets.Sounds.Success2,
            parent = Workspace.Sounds
            })
            setfflag("NextGenReplicatorEnabledWrite4", "True")
        end
    end
end)

--=========================--
--      FAST SPAWN LOOP    --
--=========================--

if not getgenv().Loaded_FIN then
    RunService.RenderStepped:Connect(function()
        if getgenv().FastSpawn and LocalPlayer.PlayerGui.RoactUI:FindFirstChild("MainMenu") then
            FrameWork.HL.Call("@SpawnHandlerClient", "spawnCharacter", true)
        end
    end)
end

--=========================--
--       EXECUTION FLAG    --
--=========================--

getgenv().EXECUTED = true
getgenv().Loaded_FIN = true
