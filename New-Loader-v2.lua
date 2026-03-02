local MT_Registry = {}
local Global = getgenv()
local Registry = {}

local function CreateInvisibilityShield(TargetInstance)
    local RealMT = getrawmetatable(TargetInstance)
    local FakeMT = {}

    for key, value in pairs(RealMT) do
        FakeMT[key] = value
    end

    MT_Registry[RealMT] = FakeMT

    hookfunction(getrawmetatable, function(obj)
        local mt = getrawmetatable(obj)
        if not checkcaller() and MT_Registry[mt] then
            return MT_Registry[mt]
        end
        return mt
    end)

    hookfunction(rawget, function(t, k)
        if not checkcaller() and MT_Registry[t] then
            return FakeMT[k]
        end
        return rawget(t, k)
    end)
    
    local oldSetRO = setreadonly
    hookfunction(setreadonly, function(t, state)
        if not checkcaller() and MT_Registry[t] then
            return
        end
        return oldSetRO(t, state)
    end)

    print("[Loader] Metatable Shield ACTIVE for: " .. tostring(TargetInstance))
end

local Originals = {
    require = getrenv().require,
    debug_info = debug.info,
    getrawmt = getrawmetatable,
    rawget = rawget
}

local function IsOurCall()
    return checkcaller()
end

local function SilentRequire(Module)
    if typeof(Module) ~= "Instance" or not Module:IsA("ModuleScript") then return nil end
    
    local oldIdentity = getthreadidentity()
    setthreadidentity(2) -- Tarne dich als CoreScript (Level 2)
    
    local success, result = pcall(Originals.require, Module)
    
    setthreadidentity(oldIdentity)
    
    if success then
        if type(result) == "table" then
            setfenv(0, getrenv()) 
        end
        return result
    else
        warn("[Loader] Failed to silently require: " .. Module:GetFullName())
        return nil
    end
end

hookfunction(debug.info, function(f, ...)
    if not IsOurCall() then
        for hook, orig in pairs(Registry.Hooks or {}) do
            if f == hook then
                return Originals.debug_info(orig, ...)
            end
        end
    end
    return Originals.debug_info(f, ...)
end)

local Wrapper = {}
Registry.Modules = {}
Registry.Hooks = {}

function Wrapper.Load(Folder)
    for _, mod in ipairs(Folder:GetDescendants()) do
        if mod:IsA("ModuleScript") then
            local data = SilentRequire(mod)
            if data then
                Registry.Modules[mod.Name] = data
                print("[Loader] Ghost-Loaded: " .. mod.Name)
            end
        end
    end
end

function Wrapper.Hook(ModuleName, FuncName, HookFunc)
    local Mod = Registry.Modules[ModuleName]
    if not Mod or type(Mod[FuncName]) ~= "function" then return end
    
    local OriginalFunc = Mod[FuncName]
    
    local NewHook = hookfunction(OriginalFunc, function(...)
        if not IsOurCall() then
            return OriginalFunc(...)
        end
        return HookFunc(OriginalFunc, ...)
    end)
    
    Registry.Hooks[NewHook] = OriginalFunc
    return NewHook
end

function Wrapper.Get(Name)
    return Registry.Modules[Name]
end

Global.MySecretLoader = nil 

print("Packet intercepted!") return orig(...) end)

return Wrapper
