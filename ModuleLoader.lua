local GlobalTable = getgenv()
GlobalTable._LoaderCache = GlobalTable._LoaderCache or {}

local function CompareFolderLists(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

for _, CacheEntry in ipairs(GlobalTable._LoaderCache) do
    if CompareFolderLists(CacheEntry.Folders, script.Parent and CacheEntry.Folders or {}) then
        return CacheEntry.Loader
    end
end

local Loader = {}

local Folders = {}
local Debug = false
GlobalTable = getgenv()
GlobalTable._HookRegistry = GlobalTable._HookRegistry or {}

Loader.Debug = function(State)
    Debug = State and true or false
end

Loader.Folders = function(List)
    Folders = List or {}
end

Loader.Global = function(Table)
    if type(Table) == "table" then
        GlobalTable = Table
        GlobalTable._HookRegistry = GlobalTable._HookRegistry or {}
    end
end

local function Safe(Module)
    setthreadidentity(2)

    local Ok, Result = pcall(require, Module)
    if not Ok then
        if Debug then
            warn(("Fail require %s: %s"):format(Module:GetFullName(), Result))
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

    if #Args > 0 and type(Args[1]) == "table" then
        return Func(table.unpack(Args))
    else
        return Func(Mod, table.unpack(Args))
    end
end

Loader.Hook = function(ModuleKey, FunctionName, HookID, HookFunc, Config)
    if type(HookFunc) ~= "function" and type(HookID) == "function" then
        HookFunc, Config = HookID, HookFunc
        HookID = "Default"
    end

    Config = Config or {}

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
    if not Mod._OriginalFunctions[FunctionName] then
        Mod._OriginalFunctions[FunctionName] = OrigFunc
    end

    GlobalTable._HookRegistry[ModuleKey] = GlobalTable._HookRegistry[ModuleKey] or {}
    GlobalTable._HookRegistry[ModuleKey][FunctionName] = GlobalTable._HookRegistry[ModuleKey][FunctionName] or {}

    for ID, Data in pairs(GlobalTable._HookRegistry[ModuleKey][FunctionName]) do
        Data.Active = false
    end

    GlobalTable._HookRegistry[ModuleKey][FunctionName][HookID] = {
        Func = HookFunc,
        Active = true,
        Config = Config
    }

    local function Wrapper(...)
        local ActiveHookData
        for _, HookData in pairs(GlobalTable._HookRegistry[ModuleKey][FunctionName]) do
            if HookData.Active then
                ActiveHookData = HookData
                break
            end
        end
        local Original = Mod._OriginalFunctions[FunctionName]
        if ActiveHookData then
            return ActiveHookData.Func(Original, ...)
        else
            return Original(...)
        end
    end

    Mod[FunctionName] = Wrapper

    if Debug then
        print(("Hook applied: %s -> %s [ID=%s, Active]"):format(ModuleKey, FunctionName, HookID))
    end

    setthreadidentity(7)
    return OrigFunc
end

Loader.Unhook = function(ModuleKey, FunctionName, HookID)
    local Mod = GlobalTable[ModuleKey]
    if not Mod or not GlobalTable._HookRegistry[ModuleKey] or not GlobalTable._HookRegistry[ModuleKey][FunctionName] then
        return
    end

    if HookID then
        GlobalTable._HookRegistry[ModuleKey][FunctionName][HookID] = nil
    else
        GlobalTable._HookRegistry[ModuleKey][FunctionName] = {}
    end

    local ActiveHook
    for _, HookData in pairs(GlobalTable._HookRegistry[ModuleKey][FunctionName] or {}) do
        if HookData.Active then
            ActiveHook = HookData.Func
            break
        end
    end

    if ActiveHook then
        local Original = Mod._OriginalFunctions[FunctionName]
        Mod[FunctionName] = function(...)

            return ActiveHook(Original, ...)
        end
    else
        Mod[FunctionName] = Mod._OriginalFunctions[FunctionName]
    end

    if Debug then
        print(("Hook removed: %s -> %s [ID=%s]"):format(ModuleKey, FunctionName, HookID or "ALL"))
    end
end

Loader.ViewHookIDs = function(ModuleKey, FunctionName)
    if not GlobalTable._HookRegistry[ModuleKey] or not GlobalTable._HookRegistry[ModuleKey][FunctionName] then
        print(("No hooks found for %s -> %s"):format(ModuleKey, FunctionName))
        return
    end

    print(("Hooks for %s -> %s:"):format(ModuleKey, FunctionName))
    for HookID, Data in pairs(GlobalTable._HookRegistry[ModuleKey][FunctionName]) do
        local status = Data.Active and "ACTIVE" or "INACTIVE"
        local configStr = ""
        if Data.Config and next(Data.Config) then
            local parts = {}
            for k, v in pairs(Data.Config) do
                table.insert(parts, ("%s -> %s"):format(k, tostring(v)))
            end
            configStr = " | Modifies: " .. table.concat(parts, ", ")
        end
        print(("  ID: %s [%s]%s"):format(HookID, status, configStr))
    end
end

Loader.ShowFunc = function(FuncName)
    if type(FuncName) ~= "string" then
        warn("ShowFunc requires a string argument")
        return {}
    end

    local Results = {}
    local Searched = 0

    for Key, Mod in pairs(GlobalTable) do
        if type(Key) == "string" and Key:sub(1, 1) == "@" then
            Searched += 1

            local Ok, HasFunc = pcall(function()
                return type(Mod) == "table" and typeof(Mod[FuncName]) == "function"
            end)

            if Ok and HasFunc then
                table.insert(Results, Key)
            end
        end
    end

    if #Results == 0 then
        print(("[Loader] No modules contain a function named '%s' (searched %d modules)"):format(FuncName, Searched))
    else
        print(("[Loader] Found function '%s' in %d module(s):"):format(FuncName, #Results))
        for _, ModKey in ipairs(Results) do
            print("  →", ModKey)
        end
    end

    return Results
end

GlobalTable.HookLoader = Loader

table.insert(GlobalTable._LoaderCache, {Folders = Folders, Loader = Loader})

return Loader
