
local Originals = {
    require = getrenv().require,
    debug_info = debug.info,
    getrawmt = getrawmetatable,
    setreadonly = setreadonly,
    checkcaller = checkcaller,
    islclosure = islclosure,
    newcclosure = newcclosure,
    hookfunc = hookfunction or replaceclosure
}


local _InternalRegistry = setmetatable({}, {__mode = "k"})
local Registry = {
    Modules = {},
    Hooks = {},
    Proxies = {}
}

-- 

local function IsOurCall()
    return Originals.checkcaller()
end

-- Spoofing debug.info to hide the C-stack detour
local SpoofedDebugInfo
SpoofedDebugInfo = Originals.hookfunc(debug.info, Originals.newcclosure(function(f, ...)
    if not IsOurCall() then
        -- If the game asks about one of our hooks, point to the original function
        local original = Registry.Hooks[f]
        if original then
            return Originals.debug_info(original, ...)
        end
    end
    return Originals.debug_info(f, ...)
end))

-- Improved SilentRequire without the Identity 2 suicide pact
local function SilentRequire(Module)
    if typeof(Module) ~= "Instance" or not Module:IsA("ModuleScript") then return nil end
    
    -- We use a pcall but without forcing identity 2 unless absolutely needed by the module
    local success, result = pcall(Originals.require, Module)
    
    if success then
        -- Clean up the environment so the module doesn't know it was required by an executor
        if type(result) == "table" then
            local env = getfenv(0)
            setfenv(0, getrenv()) 
        end
        return result
    end
    return nil
end

local Wrapper = {}

-- Ghost Load: Modules are stored in a local table, never getgenv()
function Wrapper.Load(Folder)
    if not Folder then return end
    for _, mod in ipairs(Folder:GetDescendants()) do
        if mod:IsA("ModuleScript") then
            local data = SilentRequire(mod)
            if data then
                Registry.Modules[mod.Name] = data
            end
        end
    end
end

-- Hooking with C-closure wrapping to bypass L-closure checks
function Wrapper.Hook(ModuleName, FuncName, HookFunc)
    local Mod = Registry.Modules[ModuleName]
    if not Mod or type(Mod[FuncName]) ~= "function" then return end

    local OriginalFunc = Mod[FuncName]
    
    -- We wrap your hook in a NewCCloseure to fool 'islclosure' checks
    local ProtectedHook = Originals.newcclosure(function(...)
        if not IsOurCall() then
            return OriginalFunc(...)
        end
        return HookFunc(OriginalFunc, ...)
    end)

    local NewDetour = Originals.hookfunc(OriginalFunc, ProtectedHook)
    
    Registry.Hooks[ProtectedHook] = OriginalFunc
    Registry.Hooks[NewDetour] = OriginalFunc
    
    return NewDetour
end

function Wrapper.Get(Name)
    return Registry.Modules[Name] or Registry.Modules["@" .. Name]
end

-- Clean up any traces of Janus/Loader in the global table
getgenv().MySecretLoader = nil
getgenv()._HookRegistry = nil

return Wrapper
