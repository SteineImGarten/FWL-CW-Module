local Kalman = {}
Kalman.__index = Kalman

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

    self.LastPos = nil
    self.LastVelocity = Vector3.new(0,0,0)

    -- Noise State (smooth movement)
    self.NoiseOffset = Vector3.new(0,0,0)
    self.NoiseTarget = Vector3.new(0,0,0)
    self.NoiseTimer = 0

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

local function UpdateNoise(Filter, dt)
    Filter.NoiseTimer -= dt

    if Filter.NoiseTimer <= 0 then
        -- neue Zielabweichung (klein!)
        Filter.NoiseTarget = Vector3.new(
            math.random(-100,100)/100,
            math.random(-100,100)/100,
            math.random(-100,100)/100
        )
        Filter.NoiseTimer = math.random(20,60)/100 -- 0.2–0.6s
    end

    -- smooth interpolation
    Filter.NoiseOffset = Filter.NoiseOffset:Lerp(Filter.NoiseTarget, dt * 5)

    return Filter.NoiseOffset
end

function Kalman.Predict(Part, Origin, Speed, DrawLine, Gravity)
    Speed = Speed or 300
    Gravity = Gravity or Vector3.new(0, -196.2, 0)

    if not KalmanFilters[Part] then
        KalmanFilters[Part] = KalmanFilter.new()
    end

    local Filter = KalmanFilters[Part]

    -- Kalman smoothing
    Filter:predict()
    Filter:update(Part.Position)

    local SmoothedPosition = Filter.X

    -- bessere Velocity (nicht Roblox)
    local dt = RunService.Heartbeat:Wait()

    local LastPos = Filter.LastPos or SmoothedPosition
    local Velocity = (SmoothedPosition - LastPos) / dt
    Filter.LastPos = SmoothedPosition

    local Distance = (SmoothedPosition - Origin).Magnitude
    local TimeToHit = Distance / Speed 

    local Predicted = SmoothedPosition + Velocity * TimeToHit
    local GravityOffset = 0.5 * Gravity * TimeToHit^2

    local AimPosition = Vector3.new(
        Predicted.X,
        Part.Position.Y - GravityOffset.Y,
        Predicted.Z
    )

    local Noise = UpdateNoise(Filter, dt)

    local DistanceFactor = math.clamp(Distance / 100, 0.5, 3)

    AimPosition += Vector3.new(
        Noise.X * DistanceFactor,
        Noise.Y * DistanceFactor,
        Noise.Z * DistanceFactor
    )

    if DrawLine then
        local Camera = Workspace.CurrentCamera
        local Line = Drawing.new("Line")
        Line.Thickness = 1.5
        Line.Color = Color3.new(0, 1, 0)
        Line.Transparency = 1

        coroutine.wrap(function()
            local Start = tick()
            while tick() - Start < TimeToHit do
                local o = Camera:WorldToViewportPoint(Origin)
                local t = Camera:WorldToViewportPoint(AimPosition)

                Line.From = Vector2.new(o.X, o.Y)
                Line.To = Vector2.new(t.X, t.Y)
                Line.Visible = true

                task.wait()
            end
            Line:Remove()
        end)()
    end

    return CFrame.lookAt(Origin, AimPosition)
end

return Kalman