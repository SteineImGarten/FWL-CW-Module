
local FrameWork = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/Framework.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

getgenv().RecentParryPlayers = getgenv().RecentParryPlayers or {}

getgenv().EXECUTED = getgenv().EXECUTED or false
getgenv().Loaded_FIN = getgenv().Loaded_FIN or false

FrameWork.HL.Debug(true)
FrameWork.HL.Global(getgenv())
FrameWork.HL.Folders({
    ReplicatedStorage.Client.Source,
    ReplicatedStorage.Shared.Source,
    ReplicatedStorage.Shared.Vendor
})
FrameWork.HL.Load()

if not getgenv().EXECUTED then
    local FovCircle = Drawing.new("Circle")
    FovCircle.Radius = getgenv().FOV
    FovCircle.Color = Color3.fromRGB(255, 0, 0)
    FovCircle.Filled = false
    FovCircle.NumSides = 32
    FovCircle.Transparency = 0.4
    FovCircle.Visible = false

    RunService.RenderStepped:Connect(function()
        local MousePos = UserInputService:GetMouseLocation()
        FovCircle.Position = Vector2.new(MousePos.X, MousePos.Y)
    end)
end

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

FrameWork.HL.Call("@ToastNotificationActionsClient", "add", "success", "Hook Finished", 5, true, {BypassHook = false})(FrameWork.HL.Get("@RoduxStore").store)
FrameWork.HL.Call("@SoundHandler", "playSound", {
    soundObject = game:GetService("ReplicatedStorage").Shared.Assets.Sounds.Success2,
    parent = Workspace.Sounds
})

FrameWork.HL.Hook("@ToastNotificationActionsClient", "add", "ConfigOne", function(Original, Type, Text, Duration, ShouldToast)
    return Original(Type, Text, Duration, ShouldToast)
end)

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
            Args[1] = FrameWork.Kalman.Predict(Target.Character:FindFirstChild(getgenv().HitPart), Origin, Speed, false, Gravity)
        end
    end
    return Original(table.unpack(Args))
end, { Spy = false })

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

FrameWork.HL.Hook("@RagdollHandler", "toggleRagdoll", function(Original, ...)
    if getgenv().AntiRagdoll then return end
    return Original(...)
end)

FrameWork.HL.Hook("@RagdollHandlerClient", "toggleRagdoll", function(Original, ...)
    if getgenv().AntiRagdoll then return end
    return Original(...)
end)

FrameWork.HL.Hook("@Network", "FireServer", "RangeExpander", function(Original, ...)
    local Args = {...}

    if Args[2] == "MeleeDamage" then
        local target = Args[4]

        if target and target.Parent then
            local playerModel = target.Parent

            if getgenv().RecentParryPlayers and getgenv().RecentParryPlayers[playerModel] then
                print("Blocked melee damage to recently parried player:", playerModel.Name)
                return
            end
        end
    end

    return Original(table.unpack(Args))
end, { Spy = false })

FrameWork.HL.Hook("@SoundHandler", "playSound", "Anti-Parry", function(Original, ...)
    local Args = {...}
    local data = Args[1]

    if data.soundObject.Name == "Parry" then
        local sound = data.soundObject
        local playerModel = data.parent and data.parent.Parent and data.parent.Parent.Parent

        if sound and sound.Name == "Parry" and playerModel then
            local localPlayer = game.Players.LocalPlayer

            if playerModel ~= localPlayer.Character then
                getgenv().RecentParryPlayers[playerModel] = true

                task.delay(0.2, function()
                    getgenv().RecentParryPlayers[playerModel] = nil
                end)
            end
        end
    end

    return Original(...)
end, { Spy = false })

local DefaultStamina = FrameWork.HL.Call("@DefaultStaminaHandlerClient", "getDefaultStamina")
FrameWork.HL.Call("@Stamina", "setBaseMaxStamina", DefaultStamina, 150)
FrameWork.HL.Call("@Stamina", "setStamina", DefaultStamina, 1)

DefaultStamina.gainDelay = 0.5
DefaultStamina.gainPerSecond = 50

--FrameWork.HL.Hook("@DefaultStaminaHandlerClient", "spendStamina", "ConfigMaxed", function(Original, Stamina)
--    Stamina = 110
--    return Original(Stamina)
--end)

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

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if not GameProcessed and Input.KeyCode == getgenv().Keybinds.SilentAim then
        getgenv().SilentAim = not getgenv().SilentAim
        print("SilentAim:", getgenv().SilentAim)
    end
end)

if not getgenv().Loaded_FIN then
    RunService.RenderStepped:Connect(function()
        if getgenv().FastSpawn and LocalPlayer.PlayerGui.RoactUI:FindFirstChild("MainMenu") then
            FrameWork.HL.Call("@SpawnHandlerClient", "spawnCharacter", true)
        end
    end)
end

getgenv().EXECUTED = true
getgenv().Loaded_FIN = true