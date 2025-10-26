local Logger
pcall(function()
    local Console = require(game.ReplicatedStorage.Packages.Console)
    Logger = Console.New("HookLoader")
end)

local Loader = {}

local Folders = {}
local Debug = false

Loader.Debug = function(State)
    Debug = State and true or false
end

Loader.Folders = function(List)
    Folders = List or {}
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
                    Mods["@"..Module.Name] = Tbl
                    if Debug then
                        print(("Load module: %s"):format(Module:GetFullName()))
                    end
                end
            end
        end
    end

    if Debug then
        local Count = 0
        for _ in pairs(Mods) do Count = Count + 1 end
        print("Total modules loaded:", Count)
    end

    return Mods
end

return Loader
