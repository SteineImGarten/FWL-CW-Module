local Logger

pcall(function()
    local Console = require(game.ReplicatedStorage.Packages.Console)
    Logger = Console.New("HookLoader")
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
    local Mod = GlobalTable[ModuleKey]
    if not Mod then
        warn(("Module %s not found"):format(ModuleKey))
        return nil
    end

    local Func = Mod[FunctionName]
    if typeof(Func) ~= "function" then
        warn(("Function %s not found in module %s"):format(FunctionName, ModuleKey))
        return nil
    end

    return Func(...)
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

