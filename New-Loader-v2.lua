
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

local SpoofedDebugInfo
SpoofedDebugInfo = Originals.hookfunc(debug.info, Originals.newcclosure(function(f, ...)
    if not IsOurCall() then
        local original = Registry.Hooks[f]
        if original then
            return Originals.debug_info(original, ...)
        end
    end
    return Originals.debug_info(f, ...)
end))

local function SilentRequire(Module)
    if typeof(Module) ~= "Instance" or not Module:IsA("ModuleScript") then return nil end
    
    local success, result = pcall(Originals.require, Module)
    
    if success then
        if type(result) == "table" then
            local env = getfenv(0)
            setfenv(0, getrenv()) 
        end
        return result
    end
    return nil
end

local Wrapper = {}

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

function Wrapper.Hook(ModuleName, FuncName, HookFunc)
    local Mod = Registry.Modules[ModuleName]
    if not Mod or type(Mod[FuncName]) ~= "function" then return end

    local OriginalFunc = Mod[FuncName]
    
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

getgenv().MySecretLoader = nil
getgenv()._HookRegistry = nil

return Wrapper
