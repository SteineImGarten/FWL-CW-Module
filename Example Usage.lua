local HL = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/ModuleLoader.lua"))()

----------------------------------------------------------------------------

            -- Settings --

HL.Debug(false)
HL.Global(getgenv())

----------------------------------------------------------------------------

            -- Load Modules --

HL.Folders({
    game.ReplicatedStorage.Client.Source,
    game.ReplicatedStorage.Shared.Source,
    game.ReplicatedStorage.Shared.Vendor
})

HL.Load()


----------------------------------------------------------------------------

            -- Call Game Function

HL.Call("@ToastNotificationActionsClient", "add", "success", "Hook Finished", 5, true, {BypassHook = false})(getgenv()["@RoduxStore"].store)
HL.Call("@SoundHandler", "playSound", {
    soundObject = game:GetService("ReplicatedStorage").Shared.Assets.Sounds.Success2,
    parent = Workspace.Sounds
})


----------------------------------------------------------------------------


            -- Example hook --

HL.Hook("@ToastNotificationActionsClient", "add", "ConfigOne", function(Original, Type, Text, Duration, ShouldToast)
        print(Type)
        print(Text)
    return Original(Type, Text, Duration, ShouldToast)
end)


----------------------------------------------------------------------------

            -- Example --

--HL.ViewHookIDs("@ExampleModule", "FunctionName")

--HL.Unhook("@ExampleModule", "FunctionName")

--HL.Call("@ExampleModule", "FunctionName")

----------------------------------------------------------------------------


            -- Example: search function --

HL.ShowFunc("spendStamina")


----------------------------------------------------------------------------

            -- Example: modifications  --

getgenv()["@JumpConstants"]["JUMP_DELAY_ADD"] = 0

HL.Hook("@DefaultStaminaHandlerClient", "spendStamina", "ConfigMaxed", function(Original, Stamina)
        Stamina = 1
    return Original(Stamina)
end)


----------------------------------------------------------------------------

            -- Stamina Mods --

local DefaultStamina = HL.Call("@DefaultStaminaHandlerClient", "getDefaultStamina")

HL.Call("@Stamina", "setBaseMaxStamina", DefaultStamina, 200)
HL.Call("@Stamina", "setStamina", DefaultStamina, 1)

DefaultStamina.gainDelay = 0.1
DefaultStamina.gainPerSecond = 150

----------------------------------------------------------------------------
