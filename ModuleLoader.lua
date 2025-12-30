setthreadidentity(2)

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

local Loader = {}

local Folders = {}

for _, CacheEntry in ipairs(GlobalTable._LoaderCache) do
    if CompareFolderLists(CacheEntry.Folders, Folders) then
        return CacheEntry.Loader
    end
end

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

    return Result
end

local function Format(Value, Depth, Seen)
    Depth = Depth or 0
    Seen = Seen or {}
    local Indent = string.rep("  ", Depth)
    local t = typeof(Value)
    if t == "string" then
        return ("\"%s\""):format(Value:gsub("\n","\\n"))
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(Value)
    elseif t == "table" then
        if Seen[Value] then
            return "<cycle>"
        end
        Seen[Value] = true
        local Parts = {}
        local IsArray = true
        local MaxIndex = 0
        for k, _ in pairs(Value) do
            if type(k) ~= "number" then
                IsArray = false
                break
            else
                if k > MaxIndex then MaxIndex = k end
            end
        end
        if IsArray and MaxIndex > 0 then
            
            table.insert(Parts, "[")
            
            for i = 1, MaxIndex do
                local v = Value[i]
                table.insert(Parts, ("\n%s  %s,"):format(Indent, Format(v, Depth+1, Seen)))
            end
            
            table.insert(Parts, ("\n%s]"):format(Indent))
            
            return table.concat(Parts, "")
        else
            table.insert(Parts, "{")
            for k, v in pairs(Value) do
                local KeySTR = tostring(k)
                local ValSTR = Format(v, Depth+1, Seen)
                table.insert(Parts, ("\n%s  %s = %s,"):format(Indent, KeySTR, ValSTR))
            end
            
            table.insert(Parts, ("\n%s}"):format(Indent))
            
            return table.concat(Parts, "")
        end
    else
        return tostring(Value)
    end
end

local function PrintArgs(Args)
    for i = 1, #Args do
        local v = Args[i]
        local t = typeof(v)
        if t == "table" then
            print(("Arg%d: %s = %s"):format(i, "table", Format(v, 0, {})))
        else
            if t == "string" then
                print(("Arg%d: %s = %s"):format(i, t, Format(v)))
            else
                print(("Arg%d: %s = %s"):format(i, t, Format(v)))
            end
        end
    end
end

local function PrintReturn(Ret)
    if type(Ret) == "table" or typeof(Ret) == "table" then
        print(("return: %s"):format(Format(Ret, 0, {})))
    else
        print(("return: %s"):format(Format(Ret)))
    end
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

    getgenv().LOAD_FINISHED = true
    
    return Mods
end

Loader.Call = function(ModuleKey, FunctionName, ...)
    

    local Args = {...}
    local BypassHook = false

    if #Args > 0 and type(Args[#Args]) == "table" and Args[#Args].BypassHook then
        BypassHook = true
        table.remove(Args, #Args)
        
        if Debug or true then
            PrintArgs(Args)
        end
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

----

Loader.Hook = function(ModuleKey, FunctionName, HookID, HookFunc, Config)
    if type(HookFunc) ~= "function" and type(HookID) == "function" then
        HookFunc, Config = HookID, HookFunc
        HookID = "Default"
    end

    Config = Config or {}

    local Module = GlobalTable[ModuleKey]
    if not Module then
        warn(("Module %s not found"):format(ModuleKey))
        return nil
    end

    local OrigFunc = Module[FunctionName]
    if not OrigFunc or type(OrigFunc) ~= "function" then
        warn(("Function %s not found in module %s"):format(FunctionName, ModuleKey))
        return nil
    end

    Module._OriginalFunctions = Module._OriginalFunctions or {}
    if not Module._OriginalFunctions[FunctionName] then
        Module._OriginalFunctions[FunctionName] = OrigFunc
    end

    GlobalTable._HookRegistry = GlobalTable._HookRegistry or {}
    GlobalTable._HookRegistry[ModuleKey] = GlobalTable._HookRegistry[ModuleKey] or {}
    GlobalTable._HookRegistry[ModuleKey][FunctionName] = GlobalTable._HookRegistry[ModuleKey][FunctionName] or {}

    GlobalTable._HookRegistry[ModuleKey][FunctionName][HookID] = {
        Func = HookFunc,
        Active = true,
        Config = Config,
        Priority = Config.Priority or 0
    }

    local function SafeCall(Func, ...)
        if type(Func) ~= "function" then
            warn("Attempted to call a nil or non-function value")
            return nil
        end
        local success, result = pcall(Func, ...)
        if not success then
            warn(("Error calling function: %s"):format(tostring(result)))
            return nil
        end
        return result
    end

    if not Module._IsHookWrapped then
        Module._IsHookWrapped = {}
    end

    if not Module._IsHookWrapped[FunctionName] then
        Module._IsHookWrapped[FunctionName] = true

        Module[FunctionName] = function(...)
            local Hooks = GlobalTable._HookRegistry[ModuleKey][FunctionName]
            local Args = {...}

            local ActiveHooks = {}
            for _, Hook in pairs(Hooks) do
                if Hook.Active then
                    table.insert(ActiveHooks, Hook)
                end
            end

            table.sort(ActiveHooks, function(A, B)
                return (A.Priority or 0) > (B.Priority or 0)
            end)

            for _, Hook in ipairs(ActiveHooks) do
                local HookConfig = Hook.Config or {}
                local HookReturn = SafeCall(Hook.Func, OrigFunc, table.unpack(Args))

                if HookConfig.Spy then
                    print(("--- Spy Hook: %s -> %s [ID=%s] ---"):format(ModuleKey, FunctionName, HookID))
                    PrintArgs(Args)
                    PrintReturn(HookReturn or SafeCall(OrigFunc, table.unpack(Args)))
                    
                    if HookReturn ~= nil and HookConfig.OverrideReturn then
                        return HookReturn
                    end
                else
                    if HookReturn ~= nil then
                        return HookReturn
                    end
                end
            end

            return SafeCall(OrigFunc, table.unpack(Args))
        end
    end

    if Debug then
        print(("Hook applied: %s -> %s [ID=%s, Active]"):format(ModuleKey, FunctionName, HookID))
    end

    return OrigFunc
end


Loader.UnHook = function(ModuleKey, FunctionName, HookID)
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
        local Status = Data.Active and "ACTIVE" or "INACTIVE"
        local ConfigSTR = ""
        if Data.Config and next(Data.Config) then
            local Parts = {}
            for k, v in pairs(Data.Config) do
                table.insert(Parts, ("%s -> %s"):format(k, tostring(v)))
            end
            ConfigSTR = " | Modifies: " .. table.concat(Parts, ", ")
        end
        print(("  ID: %s [%s]%s"):format(HookID, Status, ConfigSTR))
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

Loader.Get = function(Name)
    if type(Name) ~= "string" then
        warn("Loader.Get requires a string module key or name")
        return nil
    end

    local GlobalTable = getgenv()
    local Mod = GlobalTable[Name] or GlobalTable["@" .. Name]

    if not Mod then
        warn(("Module not found: %s"):format(Name))
        return nil
    end

    return Mod
end

GlobalTable.HookLoader = Loader

table.insert(GlobalTable._LoaderCache, {Folders = Folders, Loader = Loader})

return Loader
