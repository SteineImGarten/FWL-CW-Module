local MT_Registry = {}

local function CreateInvisibilityShield(TargetInstance)
    local RealMT = getrawmetatable(TargetInstance)
    local FakeMT = {}

    -- Wir erstellen eine perfekte, saubere Kopie
    for key, value in pairs(RealMT) do
        FakeMT[key] = value
    end

    MT_Registry[RealMT] = FakeMT

    -- 1. Hooke getrawmetatable
    -- Wenn das Spiel nach der MT fragt, geben wir die Fake-MT zurück
    hookfunction(getrawmetatable, function(obj)
        local mt = getrawmetatable(obj) -- Nutze das echte, interne getrawmetatable
        if not checkcaller() and MT_Registry[mt] then
            return MT_Registry[mt]
        end
        return mt
    end)

    -- 2. Hooke rawget
    -- Wenn der AC versucht, __index oder __namecall direkt zu lesen
    hookfunction(rawget, function(t, k)
        if not checkcaller() and MT_Registry[t] then
            -- Wir geben den Wert aus der sauberen Fake-MT zurück
            return FakeMT[k]
        end
        return rawget(t, k)
    end)
    
    -- 3. Hooke setreadonly (Optional aber empfohlen)
    -- Verhindert, dass der AC merkt, dass wir die MT manipuliert haben
    local oldSetRO = setreadonly
    hookfunction(setreadonly, function(t, state)
        if not checkcaller() and MT_Registry[t] then
            -- Ignoriere Versuche des Spiels, unsere Ziel-MT zu sperren/entsperren
            return
        end
        return oldSetRO(t, state)
    end)

    print("[Loader] Metatable Shield ACTIVE for: " .. tostring(TargetInstance))
end

local Global = getgenv()
local Registry = {} -- Unsere private, lokale Registry (unsichtbar für getgenv)

-- Cache für originale Funktionen (Wichtig für Unhooking und Bypassing)
local Originals = {
    require = getrenv().require,
    debug_info = debug.info,
    getrawmt = getrawmetatable,
    rawget = rawget
}

-- Hilfsfunktion: Prüft, ob ein Aufruf von uns oder vom Spiel kommt
local function IsOurCall()
    return checkcaller()
end

-- 1. DER SILENT REQUIRE (Identity & Environment Spoofing)
local function SilentRequire(Module)
    if typeof(Module) ~= "Instance" or not Module:IsA("ModuleScript") then return nil end
    
    local oldIdentity = getthreadidentity()
    setthreadidentity(2) -- Tarne dich als CoreScript (Level 2)
    
    -- Wir nutzen pcall und das originale C-Require aus dem Game-Environment
    local success, result = pcall(Originals.require, Module)
    
    setthreadidentity(oldIdentity)
    
    if success then
        -- Wir setzen die Environment des Rückgabe-Tables auf das Spiel-Environment,
        -- damit das Modul denkt, es liefe in einer normalen Umgebung.
        if type(result) == "table" then
            setfenv(0, getrenv()) 
        end
        return result
    else
        warn("[Loader] Failed to silently require: " .. Module:GetFullName())
        return nil
    end
end

-- 2. DER META-SPOOFER (Versteckt unsere Hooks vor debug.info)
-- Wir hooken debug.info auf C-Ebene
hookfunction(debug.info, function(f, ...)
    if not IsOurCall() then
        -- Wenn das Spiel fragt: Wenn 'f' einer unserer Hooks ist, gib die Info vom Original zurück
        for hook, orig in pairs(Registry.Hooks or {}) do
            if f == hook then
                return Originals.debug_info(orig, ...)
            end
        end
    end
    return Originals.debug_info(f, ...)
end)

-- 3. DER WRAPPER CORE
local Wrapper = {}
Registry.Modules = {}
Registry.Hooks = {}

-- Modul laden ohne Spuren in getgenv zu hinterlassen
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

-- Sicherer Funktions-Hook (C-Level Detour)
function Wrapper.Hook(ModuleName, FuncName, HookFunc)
    local Mod = Registry.Modules[ModuleName]
    if not Mod or type(Mod[FuncName]) ~= "function" then return end
    
    local OriginalFunc = Mod[FuncName]
    
    -- Wir nutzen hookfunction für einen echten C-Pointer-Swap
    local NewHook = hookfunction(OriginalFunc, function(...)
        if not IsOurCall() then
            -- Logik für das Spiel (vielleicht den Hook ignorieren?)
            return OriginalFunc(...)
        end
        -- Unsere Logik
        return HookFunc(OriginalFunc, ...)
    end)
    
    -- Speichere die Beziehung für den debug.info Spoofer
    Registry.Hooks[NewHook] = OriginalFunc
    return NewHook
end

-- Zugriff auf Module nur über diese interne Funktion (Kein @Name in getgenv!)
function Wrapper.Get(Name)
    return Registry.Modules[Name]
end

-- 4. FINALE: DIE SPUREN VERWISCHEN
-- Wir löschen den Loader aus dem Speicher, nachdem er sich initialisiert hat.
Global.MySecretLoader = nil 

-- Beispiel Anwendung:
-- Wrapper.Load(game.ReplicatedStorage.GameModules)
-- Wrapper.Hook("Network", "SendMessage", function(orig, ...) print("Packet intercepted!") return orig(...) end)

return Wrapper
