local Originals = {
    require          = getrenv().require,
    debug_info       = debug.info,
    debug_traceback  = debug.traceback,
    debug_getupvalue = debug.getupvalue,
    debug_setupvalue = debug.setupvalue,
    checkcaller      = checkcaller,
    newcclosure      = newcclosure,
    hookfunc         = hookfunction or replaceclosure,
    pcall            = pcall,
    pack             = table.pack,
    unpack           = table.unpack or unpack,
    type             = type,
    typeof           = typeof,
    pairs            = pairs,
    ipairs           = ipairs
}

local Registry = {
    Modules = {},
    Hooks = {},
    Lookup = {}
}

local function IsOurCall()
    return Originals.checkcaller()
end

local SpoofedDebugInfo
SpoofedDebugInfo = Originals.hookfunc(debug.info, Originals.newcclosure(function(f, ...)
    if not IsOurCall() then
        local original = Registry.Lookup[f]
        if original then return Originals.debug_info(original, ...) end
    end
    return Originals.debug_info(f, ...)
end))
Registry.Lookup[SpoofedDebugInfo] = Originals.debug_info

local SpoofedGetUpvalue
SpoofedGetUpvalue = Originals.hookfunc(debug.getupvalue, Originals.newcclosure(function(f, idx)
    if not IsOurCall() then
        local original = Registry.Lookup[f]
        if original then return Originals.debug_getupvalue(original, idx) end
    end
    return Originals.debug_getupvalue(f, idx)
end))
Registry.Lookup[SpoofedGetUpvalue] = Originals.debug_getupvalue

local SpoofedSetUpvalue
SpoofedSetUpvalue = Originals.hookfunc(debug.setupvalue, Originals.newcclosure(function(f, idx, val)
    if not IsOurCall() then
        local original = Registry.Lookup[f]
        if original then return Originals.debug_setupvalue(original, idx, val) end
    end
    return Originals.debug_setupvalue(f, idx, val)
end))
Registry.Lookup[SpoofedSetUpvalue] = Originals.debug_setupvalue

local SpoofedTraceback
SpoofedTraceback = Originals.hookfunc(debug.traceback, Originals.newcclosure(function(...)
    local result = Originals.debug_traceback(...)
    if not IsOurCall() and Originals.type(result) == "string" then
        result = result:gsub("\n.*%-1.*", ""):gsub("\n.*Anonymously.*", "")
    end
    return result
end))
Registry.Lookup[SpoofedTraceback] = Originals.debug_traceback

local function SilentRequire(Module)
    if Originals.typeof(Module) ~= "Instance" or not Module:IsA("ModuleScript") then return nil end
    local success, result = Originals.pcall(Originals.require, Module)
    return success and result or nil
end

local Wrapper = {}

function Wrapper.Load(Folders)
    local TargetFolders = Originals.type(Folders) == "table" and Folders or {Folders}
    
    for _, Folder in Originals.ipairs(TargetFolders) do
        if Folder and Folder.GetDescendants then
            for _, mod in Originals.ipairs(Folder:GetDescendants()) do
                if mod:IsA("ModuleScript") then
                    local data = SilentRequire(mod)
                    if data then
                        Registry.Modules[mod.Name] = data
                    end
                end
            end
        end
    end
end

function Wrapper.Hook(ModuleName, FuncName, HookID, HookFunc, Config)
    if Originals.type(HookID) == "function" then
        Config = HookFunc
        HookFunc = HookID
        HookID = "Default"
    end

    Config = Config or {}
    HookID = HookID or "Default"
    
    local Mod = Registry.Modules[ModuleName] or Registry.Modules["@" .. ModuleName]
    if not Mod or Originals.type(Mod[FuncName]) ~= "function" then return nil end

    local OriginalFunc = Mod[FuncName]

    if not Registry.Hooks[OriginalFunc] then
        Registry.Hooks[OriginalFunc] = {
            Chain = {},
            Original = OriginalFunc
        }

        local HookData = Registry.Hooks[OriginalFunc]

        local ProtectedHook = Originals.newcclosure(function(...)
            if IsOurCall() then
                return OriginalFunc(...)
            end

            local BestHook = nil
            for _, hook in Originals.pairs(HookData.Chain) do
                if hook.Active then
                    if not BestHook or hook.Priority > BestHook.Priority then
                        BestHook = hook
                    end
                end
            end

            if BestHook then
                local results = Originals.pack(Originals.pcall(BestHook.Func, OriginalFunc, ...))
                if not results[1] then
                    return OriginalFunc(...)
                end
                return Originals.unpack(results, 2, results.n)
            end

            return OriginalFunc(...)
        end)

        local Detour = Originals.hookfunc(OriginalFunc, ProtectedHook)
        HookData.Detour = Detour

        Registry.Lookup[ProtectedHook] = OriginalFunc
        Registry.Lookup[Detour] = OriginalFunc
    end

    Registry.Hooks[OriginalFunc].Chain[HookID] = {
        Func = HookFunc,
        Priority = Config.Priority or 0,
        Active = true
    }

    return Registry.Hooks[OriginalFunc].Original
end

function Wrapper.UnHook(ModuleName, FuncName, HookID)
    local Mod = Registry.Modules[ModuleName] or Registry.Modules["@" .. ModuleName]
    if not Mod or Originals.type(Mod[FuncName]) ~= "function" then return end

    local CurrentFunc = Mod[FuncName]
    local OriginalFunc = Registry.Lookup[CurrentFunc] or CurrentFunc
    local HookData = Registry.Hooks[OriginalFunc]

    if HookData then
        if HookID then
            HookData.Chain[HookID] = nil
        else
            HookData.Chain = {}
        end
    end
end

function Wrapper.Call(ModuleName, FuncName, ...)
    local Mod = Registry.Modules[ModuleName] or Registry.Modules["@" .. ModuleName]
    if not Mod then return nil end

    local Func = Mod[FuncName]
    if Originals.type(Func) ~= "function" then return nil end

    local Args = Originals.pack(...)
    
    if Args.n > 0 and Originals.type(Args[Args.n]) == "table" and Args[Args.n].BypassHook then
        local OriginalFunc = Registry.Lookup[Func] or Func
        if OriginalFunc then
            return OriginalFunc(Originals.unpack(Args, 1, Args.n - 1))
        end
    end

    return Func(...)
end

function Wrapper.Get(Name)
    return Registry.Modules[Name] or Registry.Modules["@" .. Name]
end

getgenv().MySecretLoader = nil
getgenv()._HookRegistry = nil
getgenv()._LoaderCache = nil

return Wrapper
