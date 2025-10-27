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
    setthreadidentity(2)
    
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
    
    setthreadidentity(7)
    return Mods
end

Loader.Call = function(ModuleKey, FunctionName, ...)
    setthreadidentity(2)
    
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
    
    setthreadidentity(2)
    return Func(table.unpack(Args))
end

Loader.Hook = function(ModuleKey, FunctionName, HookFunc)
    setthreadidentity(2)

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
    local TrueOriginal = OrigFunc

    local function WrappedHook(...)
        return HookFunc(TrueOriginal, ...)
    end

    local Success, Err = pcall(function()
        hookfunction(TrueOriginal, WrappedHook)
    end)

    if not Success then
        warn(("Failed to hook %s in module %s: %s"):format(FunctionName, ModuleKey, tostring(Err)))
        return nil
    end

    if Debug then
        print(("Hooked %s in module %s"):format(FunctionName, ModuleKey))
    end

    setthreadidentity(7)
    return TrueOriginal
end

GlobalTable.HookLoader = Loader

return Loader
