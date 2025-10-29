local Kalman = {}
Kalman.__index = Kalman

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KalmanFilter = {}
KalmanFilter.__index = KalmanFilter

function KalmanFilter.new()
    local self = setmetatable({}, KalmanFilter)
    self.X = Vector3.new(0, 0, 0)
    self.P = Vector3.new(1, 1, 1)
    self.Q = Vector3.new(0.1, 0.1, 0.1)
    self.R = Vector3.new(0.1, 0.1, 0.1)
    self.K = Vector3.new(0, 0, 0)
    return self
end

function KalmanFilter:predict()
    self.P = self.P + self.Q
end

function KalmanFilter:update(Z)
    self.K = Vector3.new(
        self.P.X / (self.P.X + self.R.X),
        self.P.Y / (self.P.Y + self.R.Y),
        self.P.Z / (self.P.Z + self.R.Z)
    )
    self.X = self.X + Vector3.new(
        self.K.X * (Z.X - self.X.X),
        self.K.Y * (Z.Y - self.X.Y),
        self.K.Z * (Z.Z - self.X.Z)
    )
    self.P = Vector3.new(
        (1 - self.K.X) * self.P.X,
        (1 - self.K.Y) * self.P.Y,
        (1 - self.K.Z) * self.P.Z
    )
end

local KalmanFilters = {}

local function DrawPredictionLine(Origin, Target, Color, Duration)
    local Camera = Workspace.CurrentCamera
    local Line = Drawing.new("Line")
    Line.Thickness = 1.5
    Line.Color = Color
    Line.Transparency = 1

    coroutine.wrap(function()
        local Start = tick()
        while tick() - Start < Duration do
            local OriginPos, OriginVisible = Camera:WorldToViewportPoint(Origin)
            local TargetPos, TargetVisible = Camera:WorldToViewportPoint(Target)

            if OriginVisible and TargetVisible then
                Line.From = Vector2.new(OriginPos.X, OriginPos.Y)
                Line.To = Vector2.new(TargetPos.X, TargetPos.Y)
                Line.Visible = true
            else
                Line.Visible = false
            end

            task.wait()
        end
        Line:Remove()
    end)()
end

function Kalman.Predict(Part, Origin, Speed, DrawLine, Gravity)
    local Velocity = Part.AssemblyLinearVelocity
    Speed = Speed or 300
    Gravity = Gravity or 196.2

    local D = (Part.Position - Origin)
    local R = Vector3.new(D.X, 0, D.Z).Magnitude
    local y = D.Y

    if R < 0.01 then
        return CFrame.lookAt(Origin, Part.Position)
    end

    local v2 = Speed * Speed
    local discriminant = v2 * v2 - Gravity * (Gravity * R * R + 2 * y * v2)

    if discriminant < 0 then
        return CFrame.lookAt(Origin, Part.Position)
    end

    local sqrtDisc = math.sqrt(discriminant)
    local theta = math.atan((v2 + sqrtDisc) / (Gravity * R))

    local horizDir = Vector3.new(D.X, 0, D.Z).Unit

    local vx = math.cos(theta) * Speed
    local vy = math.sin(theta) * Speed
    local launchVel = horizDir * vx + Vector3.new(0, vy, 0)

    local lookDistance = math.max(R, 1)
    local AimPoint = Origin + launchVel.Unit * lookDistance * 2

    if DrawLine then
        DrawPredictionLine(Origin, AimPoint, Color3.new(0, 1, 0), lookDistance / Speed)
    end

    return CFrame.lookAt(Origin, AimPoint)
end

return Kalman
