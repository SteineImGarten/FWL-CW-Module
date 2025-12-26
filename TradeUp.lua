local FrameWork = loadstring(game:HttpGet("https://raw.githubusercontent.com/SteineImGarten/FWL-CW-Module/refs/heads/main/Framework.lua"))()

FrameWork.HL.Debug(false)
FrameWork.HL.Global(getgenv())

FrameWork.HL.Folders({
    game.ReplicatedStorage.Client.Source,
    game.ReplicatedStorage.Shared.Source,
    game.ReplicatedStorage.Shared.Vendor
})

FrameWork.HL.Load()

wait(1)

local function SafeCall(Action, Payload, CaseName)
    local ok, err = pcall(function()
        FrameWork.HL.Call("@Network", "InvokeServer", FrameWork.HL.Get("@Network"), Action, Payload, CaseName)
    end)
    if not ok then
        warn("Network call failed:", err)
    end
end

local function DoTrade(Action, CaseName, Spec, Times, Delay)
    Delay = Delay or 0
    for i = 1, Times do
        local payload = { [1] = { amount = Spec.amount, cosmeticType = Spec.cosmeticType, cosmeticId = Spec.cosmeticId } }
        SafeCall(Action, payload, CaseName)
        if Delay > 0 then
            task.wait(Delay)
        end
    end
end

local Batches = {
    { Action = "DoTradeDown", Case = "case4", Spec = { amount = 100, cosmeticType = "bundles", cosmeticId = "bundle37" }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "case4", Spec = { amount = 10,  cosmeticType = "bundles", cosmeticId = "bundle39" }, Times = getgenv().TradeUps },

    { Action = "DoTradeDown", Case = "case5", Spec = { amount = 100, cosmeticType = "characterAura", cosmeticId = "characterAura15" }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "case5", Spec = { amount = 10,  cosmeticType = "characterAura", cosmeticId = "characterAura4"  }, Times = getgenv().TradeUps },

    { Action = "DoTradeDown", Case = "killEffectsCase", Spec = { amount = 100, cosmeticType = "killEffects", cosmeticId = "killEffect81" }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "killEffectsCase", Spec = { amount = 10,  cosmeticType = "killEffects", cosmeticId = "killEffect32" }, Times = getgenv().TradeUps },

    { Action = "DoTradeDown", Case = "enchantsCase", Spec = { amount = 100, cosmeticType = "enchants", cosmeticId = "enchant6"  }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "enchantsCase", Spec = { amount = 10,  cosmeticType = "enchants", cosmeticId = "enchant51" }, Times = getgenv().TradeUps },

    { Action = "DoTradeDown", Case = "skinsCase", Spec = { amount = 100, cosmeticType = "skins", cosmeticId = "skin58" }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "skinsCase", Spec = { amount = 10,  cosmeticType = "skins", cosmeticId = "skin28" }, Times = getgenv().TradeUps },

    { Action = "DoTradeDown", Case = "case6", Spec = { amount = 100, cosmeticType = "parryShield", cosmeticId = "parryShield72" }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "case6", Spec = { amount = 10,  cosmeticType = "parryShield", cosmeticId = "parryShield68" }, Times = getgenv().TradeUps },

    { Action = "DoTradeDown", Case = "case7", Spec = { amount = 100, cosmeticType = "emote", cosmeticId = "emote24" }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "case7", Spec = { amount = 10,  cosmeticType = "emote", cosmeticId = "emote63" }, Times = getgenv().TradeUps },

    { Action = "DoTradeDown", Case = "case8", Spec = { amount = 100, cosmeticType = "emoteIcon", cosmeticId = "emoteIcon38" }, Times = getgenv().TradeDowns },
    { Action = "DoTradeUp",   Case = "case8", Spec = { amount = 10,  cosmeticType = "emoteIcon", cosmeticId = "emoteIcon53" }, Times = getgenv().TradeUps },
}

local GlobalDelay = 0

for _, Batch in ipairs(Batches) do
    DoTrade(Batch.Action, Batch.Case, Batch.Spec, Batch.Times, GlobalDelay)
end
