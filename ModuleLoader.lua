local Logger

pcall(function()
    setthreadidentity(2)
    local Console = require(game.ReplicatedStorage.Packages.Console)
    Logger = Console.New("HookLoader")
    setthreadidentity(7)
end)

local Loader = {}


local Folders = {}
local Debug = false
local GlobalTable = getgenv()

Loader.Debug = function(State)
    Debug = State and true or false
end

Loader.Folders = function(List)
    Folders = List or {}
end

Loader.Global = function(Table)
    if type(Table) == "table" then
        GlobalTable = Table
    end
end

local function Safe(Module)
    setthreadidentity(2)
    local Ok, Result = pcall(require, Module)
    if not Ok then
        if Debug then
            if Logger then
                Logger:Warn(("Fail require %s: %s"):format(Module:GetFullName(), Result))
            else
                warn(("Fail require %s: %s"):format(Module:GetFullName(), Result))
            end
        end
        return nil
    end
    if typeof(Result) ~= "table" then
        return {}
    end

    setthreadidentity(7)
    return Result
end

Loader.Load = function()
    local Mods = {}
    for _, Folder in ipairs(Folders) do
        for _, Module in ipairs(Folder:GetDescendants()) do
            if Module:IsA("ModuleScript") then
                local Tbl = Safe(Module)
                if Tbl then
                    local Key = "@" .. Module.Name
                    Mods[Key] = Tbl
                    if Debug then
                        print(("Load module: %s"):format(Module:GetFullName()))
                    end
                end
            end
        end
    end

    for Key, Val in pairs(Mods) do
        GlobalTable[Key] = Val
    end

    if Debug then
        local Count = 0
        for _ in pairs(Mods) do Count = Count + 1 end
        print("Total modules loaded:", Count)
    end

    return Mods
end

Loader.Call = function(ModuleKey, FunctionName, ...)
    local Args = {...}
    local BypassHook = false

    if #Args > 0 and type(Args[#Args]) == "table" and Args[#Args].BypassHook then
        BypassHook = true
        table.remove(Args, #Args)
    end

    local Mod = GlobalTable[ModuleKey]
    if not Mod then
        warn(("Module %s not found"):format(ModuleKey))
        return nil
    end

    local Func
    if BypassHook and Mod._OriginalFunctions and Mod._OriginalFunctions[FunctionName] then
        Func = Mod._OriginalFunctions[FunctionName]
    else
        Func = Mod[FunctionName]
    end

    if typeof(Func) ~= "function" then
        warn(("Function %s not found in module %s"):format(FunctionName, ModuleKey))
        return nil
    end

    return Func(table.unpack(Args))
end

Loader.Hook = function(ModuleKey, FunctionName, HookFunc)
    local Mod = GlobalTable[ModuleKey]
    if not Mod then
        warn(("Module %s not found"):format(ModuleKey))
        return nil
    end

    local OrigFunc = Mod[FunctionName]
    if typeof(OrigFunc) ~= "function" then
        warn(("Function %s not found in module %s"):format(FunctionName, ModuleKey))
        return nil
    end

    Mod._OriginalFunctions = Mod._OriginalFunctions or {}
    Mod._OriginalFunctions[FunctionName] = OrigFunc

    local Success, Hooked = pcall(function()
        return hookfunction(OrigFunc, HookFunc)
    end)

    if not Success then
        warn(("Failed to hook %s in module %s: %s"):format(FunctionName, ModuleKey, tostring(Hooked)))
        return nil
    end

    if Debug then
        print(("Hooked %s in module %s"):format(FunctionName, ModuleKey))
    end

    return Hooked
end

GlobalTable.HookLoader = Loader

return Loader
