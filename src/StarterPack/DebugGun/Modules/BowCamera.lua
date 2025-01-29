local BowCamera = {}

-- Constants
local DEFAULT_FOV = 70
local AIM_FOV = 50
local MIN_FOV = 45
local SHOULDER_OFFSET = Vector3.new(-2, 2, 1)
local CAMERA_DISTANCE = 3
local TRANSITION_SPEED = 0.1
local DEFAULT_CAMERA_PITCH = -0.3

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Private variables
local Camera = workspace.CurrentCamera
local currentFOV = DEFAULT_FOV
local targetFOV = DEFAULT_FOV
local currentYaw = 0
local currentPitch = 0
local cameraShakeOffset = Vector3.new(0, 0, 0)
local previousCameraType
local previousCameraSubject
local previousCameraCFrame

function BowCamera.new()
    local self = setmetatable({}, {__index = BowCamera})
    self.enabled = false
    return self
end

function BowCamera:SaveState()
    previousCameraType = Camera.CameraType
    previousCameraSubject = Camera.CameraSubject
    previousCameraCFrame = Camera.CFrame
    local _, yaw, pitch = Camera.CFrame:ToOrientation()
    currentYaw = yaw
    currentPitch = -pitch
end

function BowCamera:RestoreState()
    if previousCameraType then
        Camera.CameraType = previousCameraType
        Camera.CameraSubject = previousCameraSubject
        Camera.CFrame = Camera.CFrame:Lerp(previousCameraCFrame, 0.2)
    end
end

function BowCamera:UpdateAim(delta, sensitivity)
    if not self.enabled then return end
    currentYaw = currentYaw - delta.X * 0.002 * sensitivity
    currentPitch = math.clamp(currentPitch + delta.Y * 0.002 * sensitivity, -1.3, 1.3)
end

function BowCamera:Update(humanoidRootPart, shakeOffset)
    if not self.enabled or not humanoidRootPart then return end

    Camera.CameraType = Enum.CameraType.Scriptable

    local lookVector = CFrame.fromEulerAnglesYXZ(-currentPitch, currentYaw, 0).LookVector
    if not lookVector then return end

    local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
    local rightVector = Vector3.new(flatLookVector.Z, 0, -flatLookVector.X)
    
    -- Rotate character
    local targetCharacterCF = CFrame.new(humanoidRootPart.Position, 
        humanoidRootPart.Position + flatLookVector)
    humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCharacterCF, 0.2)

    -- Position camera
    local shoulderPos = humanoidRootPart.Position 
        + rightVector * SHOULDER_OFFSET.X 
        + Vector3.new(0, SHOULDER_OFFSET.Y, 0)
        + flatLookVector * SHOULDER_OFFSET.Z

    local targetPosition = shoulderPos - lookVector * CAMERA_DISTANCE + (shakeOffset or Vector3.new())
    Camera.CFrame = CFrame.new(targetPosition) * CFrame.fromEulerAnglesYXZ(-currentPitch, currentYaw, 0)
end

function BowCamera:SetEnabled(enabled)
    self.enabled = enabled
    if enabled then
        self:SaveState()
    else
        self:RestoreState()
    end
end

function BowCamera:GetLookVector()
    return CFrame.fromEulerAnglesYXZ(-currentPitch, currentYaw, 0).LookVector
end

return BowCamera 