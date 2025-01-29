local BowCamera = {}

-- Constants
local DEFAULT_FOV = 70
local AIM_FOV = 50
local MIN_FOV = 45
local SHOULDER_OFFSET = Vector3.new(-2, 2, 1)
local CAMERA_DISTANCE = 3
local TRANSITION_SPEED = 0.1
local DEFAULT_CAMERA_PITCH = -0.3
local MOUSE_SENSITIVITY = 0.002
local MAX_PITCH = 1.3
local MIN_PITCH = -1.3
local FOV_TRANSITION_SPEED = 0.1

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

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
local previousMouseBehavior
local previousMouseIcon
local previousSensitivity

-- Helper function for linear interpolation
local function lerp(a, b, t)
    return a + (b - a) * t
end

function BowCamera.new()
    local self = setmetatable({}, {__index = BowCamera})
    self.enabled = false
    self.transitioning = false
    self.transitionStart = 0
    return self
end

function BowCamera:SaveState()
    previousCameraType = Camera.CameraType
    previousCameraSubject = Camera.CameraSubject
    previousCameraCFrame = Camera.CFrame
    previousMouseBehavior = UserInputService.MouseBehavior
    previousMouseIcon = UserInputService.MouseIcon
    previousSensitivity = UserInputService.MouseDeltaSensitivity
    currentFOV = Camera.FieldOfView
    
    -- Get initial angles from current camera
    local _, yaw, pitch = Camera.CFrame:ToOrientation()
    currentYaw = yaw
    currentPitch = -pitch
end

function BowCamera:RestoreState()
    if previousCameraType then
        self.transitioning = true
        self.transitionStart = time()
        targetFOV = DEFAULT_FOV
        
        -- Restore mouse state immediately
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseDeltaSensitivity = previousSensitivity
        
        -- Reset camera state
        Camera.CameraType = previousCameraType
        Camera.CameraSubject = previousCameraSubject
    end
end

function BowCamera:UpdateTransition()
    if not self.transitioning then return end
    
    local alpha = math.min((time() - self.transitionStart) / TRANSITION_SPEED, 1)
    
    if alpha >= 1 then
        self.transitioning = false
        Camera.FieldOfView = DEFAULT_FOV
        return
    end
    
    -- Smoothly transition camera and FOV
    if previousCameraCFrame then
        Camera.CFrame = Camera.CFrame:Lerp(previousCameraCFrame, alpha)
        Camera.FieldOfView = lerp(currentFOV, DEFAULT_FOV, alpha)
    end
end

function BowCamera:UpdateAim(delta, sensitivity)
    if not self.enabled or self.transitioning then return end
    
    -- Update rotation based on mouse movement
    currentYaw = currentYaw - delta.X * MOUSE_SENSITIVITY * sensitivity
    currentPitch = math.clamp(
        currentPitch + delta.Y * MOUSE_SENSITIVITY * sensitivity,
        MIN_PITCH,
        MAX_PITCH
    )
end

function BowCamera:Update(humanoidRootPart, shakeOffset)
    if self.transitioning then
        self:UpdateTransition()
        return
    end
    
    if not self.enabled or not humanoidRootPart then return end

    -- Set camera mode
    Camera.CameraType = Enum.CameraType.Scriptable

    -- Lock mouse to center when aiming
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    -- Calculate look vectors
    local lookCFrame = CFrame.fromEulerAnglesYXZ(-currentPitch, currentYaw, 0)
    local lookVector = lookCFrame.LookVector
    
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
    Camera.CFrame = CFrame.new(targetPosition) * lookCFrame
    
    -- Update FOV with smooth transition
    currentFOV = lerp(currentFOV, AIM_FOV, FOV_TRANSITION_SPEED)
    Camera.FieldOfView = currentFOV
end

function BowCamera:SetEnabled(enabled)
    if self.enabled == enabled then return end
    
    self.enabled = enabled
    if enabled then
        self:SaveState()
        targetFOV = AIM_FOV
    else
        self:RestoreState()
        targetFOV = DEFAULT_FOV
    end
end

function BowCamera:GetLookVector()
    return CFrame.fromEulerAnglesYXZ(-currentPitch, currentYaw, 0).LookVector
end

function BowCamera:Reset()
    self:SetEnabled(false)
    self.transitioning = false
    currentYaw = 0
    currentPitch = 0
    currentFOV = DEFAULT_FOV
    targetFOV = DEFAULT_FOV
    Camera.FieldOfView = DEFAULT_FOV
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    
    if previousCameraType then
        Camera.CameraType = previousCameraType
        Camera.CameraSubject = previousCameraSubject
    end
end

function BowCamera:Cleanup()
    self:Reset()
end

return BowCamera 