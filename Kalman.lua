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
    Gravity = Gravity or Vector3.new(0, -196.2, 0)

    local FlatTarget = Vector3.new(Part.Position.X, 0, Part.Position.Z)
    local FlatOrigin = Vector3.new(Origin.X, 0, Origin.Z)
    local HorizontalDistance = (FlatTarget - FlatOrigin).Magnitude
    local TimeToHit = HorizontalDistance / Speed
    local PredictedFlat = FlatTarget + Vector3.new(Velocity.X, 0, Velocity.Z) * TimeToHit

    local GravityOffset = Gravity * 0.5 * TimeToHit^2

    local AimPosition = Vector3.new(
        PredictedFlat.X,
        Part.Position.Y + Velocity.Y * TimeToHit,
        PredictedFlat.Z
    ) + GravityOffset

    if DrawLine then
        DrawPredictionLine(Origin, AimPosition, Color3.new(0,1,0), TimeToHit)
    end

    return CFrame.lookAt(Origin, AimPosition)
end


return Kalman
