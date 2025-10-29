local Kalman = {}
Kalman.__index = Kalman

local RunService = game:GetService("RunService")

local Filter = {}
Filter.__index = Filter

function Filter.New()
    local self = setmetatable({}, Filter)
    self.Pos = Vector3.new(0,0,0)
    self.Vel = Vector3.new(0,0,0)
    self.PPos = Vector3.new(1,1,1)
    self.PVel = Vector3.new(1,1,1)
    self.QPos = Vector3.new(0.1,0.1,0.1)
    self.QVel = Vector3.new(0.1,0.1,0.1)
    self.R = Vector3.new(1,1,1)
    return self
end

function Filter:Update(MeasPos, MeasVel, Dt)
    self.Pos = self.Pos + self.Vel * Dt
    self.PPos = self.PPos + self.QPos
    self.PVel = self.PVel + self.QVel

    local KPos = self.PPos / (self.PPos + self.R)
    local KVel = self.PVel / (self.PVel + self.R)

    self.Pos = self.Pos + KPos * (MeasPos - self.Pos)
    self.Vel = self.Vel + KVel * (MeasVel - self.Vel)

    self.PPos = (Vector3.new(1,1,1) - KPos) * self.PPos
    self.PVel = (Vector3.new(1,1,1) - KVel) * self.PVel

    return self.Pos, self.Vel
end

local Filters = {}

function Kalman.Predict(Origin, Target, Speed, Gravity, Dt)
    local F = Filters[Target] or Filter.New()
    Filters[Target] = F

    local MeasPos = Target.Position
    local MeasVel = Target.AssemblyLinearVelocity or Vector3.new(0,0,0)

    local Pos, Vel = F:Update(MeasPos, MeasVel, Dt)

    local T = (Pos - Origin).Magnitude / Speed
    local Fut = Pos + Vel * T + Vector3.new(0, -0.5 * Gravity * T^2, 0)

    return CFrame.new(Origin, Fut)
end


return Kalman
