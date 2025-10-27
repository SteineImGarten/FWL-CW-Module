local HL = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/ModuleLoader.lua"))()

HL.Debug(false)
HL.Global(getgenv())
HL.Folders({
    game.ReplicatedStorage.Client.Source,
    game.ReplicatedStorage.Shared.Source,
    game.ReplicatedStorage.Shared.Vendor
})

HL.Load()

----------------------------------

--Call a function

HL.Call("@ToastNotificationActionsClient", "add", "success", "Ah!", 5, true, {BypassHook = true})(getgenv()["@RoduxStore"].store)


-------------------------------------------

-- Hook a function

HL.Hook("@ToastNotificationActionsClient", "add", function(Original, Type, Text, Duration, ShouldToast)
    Text = "Hooked"
    return Original(Type, Text, Duration, ShouldToast)
end)
