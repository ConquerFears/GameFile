-- Path: src/StarterPack/DebugGun/Client.client.lua

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- References
local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle1")
local Camera = workspace.CurrentCamera
local MouseEvent = Tool:WaitForChild("MouseEvent")
local DrawSound = Handle:WaitForChild("Draw")
local FirePointObject = Handle:WaitForChild("Bow"):WaitForChild("GunFirePoint")

-- Constants
local MIN_DRAW_TIME = 1.5 -- Time to fully draw
local MAX_DRAW_TIME = 7.0 -- Maximum charge time
local BRACKET_SPREAD = 75 -- Increased initial spread distance
local BRACKET_MIN_SPREAD = 12 -- Slightly increased minimum spread
local BRACKET_IMAGE = "rbxassetid://132698696496946"
local BRACKET_SIZE_X = 30 -- Increased X size for thicker brackets
local BRACKET_SIZE_Y = 20 -- Original Y size
local BRACKET_TRANSPARENCY = 0.4 -- Reduced transparency for more visibility
local BASE_SPREAD_MULTIPLIER = 0.75 -- Match server's spread reduction
local BRACKET_LERP_SPEED = 0.1 -- Faster movement
local ZOOM_SPEED = 0.1 -- Faster aiming
local SENSITIVITY_SPEED = 0.15 -- Faster sensitivity adjustment
local CHARGE_BAR_MOVE_SPEED = 0.2 -- Speed of bar movement

-- Over-shoulder camera settings
local SHOULDER_OFFSET = Vector3.new(-2, 2, 1)
local CAMERA_DISTANCE = 3
local TRANSITION_SPEED = 0.1

-- Visual feedback settings
local SCREEN_EFFECT_INTENSITY = 0.2  -- Max vignette darkness
local CHARGE_SHAKE_INTENSITY = 0.02  -- Max camera shake at full charge

-- Different cursor states
local CURSOR_STATES = {
	DEFAULT = "",  -- Default Roblox cursor
	DRAWING = "rbxassetid://140530585218698",  -- Drawing crosshair
	READY = "rbxassetid://140530585218698"  -- Ready to shoot crosshair
}

-- State machine states
local BowState = {
	IDLE = "idle",           -- Normal third person camera
	DRAWING = "drawing",     -- Drawing the bow, camera transitioning
	AIMED = "aimed",         -- Fully drawn, waiting for release
	RELEASING = "releasing", -- Just released, following shot
	COOLDOWN = "cooldown"    -- Brief cooldown before next shot
}

-- Camera settings
local DEFAULT_SENSITIVITY = UserInputService.MouseDeltaSensitivity
local AIM_SENSITIVITY = 0.5
local DEFAULT_FOV = 70
local AIM_FOV = 50
local MIN_FOV = 45
local SHOT_FOLLOW_TIME = 0.8
local DEFAULT_CAMERA_PITCH = -0.3
local CAMERA_STATE_CHECK_INTERVAL = 0.1
local SHOT_COOLDOWN = 0.3

-- State tracking
local Mouse = nil
local ExpectingInput = false
local IsMouseDown = false
local DrawStartTime = 0
local IsReadyToShoot = false
local CurrentState = BowState.IDLE
local StateStartTime = 0
local PreviousCameraType
local PreviousCameraSubject
local PreviousCameraCFrame
local CurrentFOV = DEFAULT_FOV
local TargetFOV = DEFAULT_FOV
local CurrentSensitivity = DEFAULT_SENSITIVITY
local CurrentYaw = 0
local CurrentPitch = 0
local CameraShakeOffset = Vector3.new(0, 0, 0)
local LastShotTime = 0  -- Track last shot time for cooldown
local IsCameraLocked = false  -- Track if camera is in a locked state
local IsAiming = false
local IsTransitioningOut = false
local LastCharacterPosition = Vector3.new(0, 0, 0)
local ShotTime = 0

-- Track current spread for smooth lerping
local CurrentBracketSpread = BRACKET_SPREAD

-- Create UI elements
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BowChargeUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = PlayerGui

-- Create bracket cursors
local BracketContainer = Instance.new("Frame")
BracketContainer.Name = "BracketContainer"
BracketContainer.BackgroundTransparency = 1
BracketContainer.Size = UDim2.fromScale(1, 1)
BracketContainer.Position = UDim2.fromScale(0, 0)
BracketContainer.Parent = ScreenGui

-- Create a bracket UI element
local function CreateBracket()
	local bracket = Instance.new("ImageLabel")
	bracket.BackgroundTransparency = 1
	bracket.ImageTransparency = BRACKET_TRANSPARENCY
	bracket.Image = BRACKET_IMAGE
	bracket.Size = UDim2.new(0, BRACKET_SIZE_X, 0, BRACKET_SIZE_Y)
	bracket.AnchorPoint = Vector2.new(0.5, 0.5)
	bracket.Visible = false
	return bracket
end

local brackets = {}
local bracketAngles = {90, 180, 270, 0} -- Rotated 90 degrees clockwise

for i, angle in ipairs(bracketAngles) do
	local bracket = CreateBracket()
	bracket.Name = "Bracket" .. i
	bracket.Parent = BracketContainer
	brackets[i] = bracket
end

-- Variables
local ChargeBarContainer
local ChargeBar
local IsChargeBarInitialized = false

-- Initialize the charge bar
local function InitializeChargeBar()
	if IsChargeBarInitialized then return ChargeBarContainer, ChargeBar end

	ChargeBarContainer = Instance.new("Frame")
	ChargeBarContainer.Name = "ChargeBarContainer"
	ChargeBarContainer.Size = UDim2.new(0, 50, 0, 6)
	ChargeBarContainer.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	ChargeBarContainer.BorderSizePixel = 0
	ChargeBarContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	ChargeBarContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	ChargeBarContainer.ZIndex = 100
	ChargeBarContainer.Parent = ScreenGui

	local chargeBarStroke = Instance.new("UIStroke")
	chargeBarStroke.Color = Color3.new(0, 0, 0)
	chargeBarStroke.Thickness = 2
	chargeBarStroke.Parent = ChargeBarContainer

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(1, 0)
	UICorner.Parent = ChargeBarContainer

	ChargeBar = Instance.new("Frame")
	ChargeBar.Name = "ChargeBar"
	ChargeBar.Size = UDim2.new(0, 0, 1, 0)
	ChargeBar.Position = UDim2.new(0, 0, 0, 0)
	ChargeBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	ChargeBar.BorderSizePixel = 0
	ChargeBar.ZIndex = 101
	ChargeBar.Parent = ChargeBarContainer

	local UICornerProgress = Instance.new("UICorner")
	UICornerProgress.CornerRadius = UDim.new(1, 0)
	UICornerProgress.Parent = ChargeBar

	IsChargeBarInitialized = true
	print("Charge bar initialized")
	return ChargeBarContainer, ChargeBar
end

-- Create vignette effect
local VignetteFrame = Instance.new("Frame")
VignetteFrame.Name = "Vignette"
VignetteFrame.BackgroundTransparency = 1
VignetteFrame.Size = UDim2.fromScale(1, 1)
VignetteFrame.ZIndex = 99
VignetteFrame.Parent = ScreenGui

local VignetteGradient = Instance.new("UIGradient")
VignetteGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.7, 1),
	NumberSequenceKeypoint.new(1, 0)
})
VignetteGradient.Color = ColorSequence.new(Color3.new(0, 0, 0))
VignetteGradient.Parent = VignetteFrame

-- Initialize state
local function InitializeState()
	CurrentState = BowState.IDLE
	StateStartTime = time()
	CurrentFOV = DEFAULT_FOV
	TargetFOV = DEFAULT_FOV
	CurrentSensitivity = DEFAULT_SENSITIVITY
	CameraShakeOffset = Vector3.new(0, 0, 0)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	ChargeBarContainer.Visible = false
	VignetteFrame.BackgroundTransparency = 1
end

-- Save camera state
local function SaveCameraState()
	PreviousCameraType = Camera.CameraType
	PreviousCameraSubject = Camera.CameraSubject
	PreviousCameraCFrame = Camera.CFrame
	local _, yaw, pitch = Camera.CFrame:ToOrientation()
	CurrentYaw = yaw
	CurrentPitch = -pitch
end

-- Restore camera state
local function RestoreCameraState()
	if PreviousCameraType then
		Camera.CameraType = PreviousCameraType
		Camera.CameraSubject = PreviousCameraSubject
		-- Smoothly interpolate back to previous position
		Camera.CFrame = Camera.CFrame:Lerp(PreviousCameraCFrame, 0.2)
	end
end

-- Check if we can transition to a new state
local function CanTransitionTo(newState)
	local currentTime = time()
	local player = Players.LocalPlayer

	-- Basic validity checks
	if not player or not player.Character then return false end
	if not player.Character:FindFirstChild("HumanoidRootPart") then return false end
	if Tool.Parent:IsA("Backpack") then return false end

	-- State-specific checks
	if newState == BowState.DRAWING then
		return CurrentState == BowState.IDLE or CurrentState == BowState.COOLDOWN
	elseif newState == BowState.AIMED then
		return CurrentState == BowState.DRAWING
	elseif newState == BowState.RELEASING then
		return CurrentState == BowState.AIMED
	elseif newState == BowState.COOLDOWN then
		return CurrentState == BowState.RELEASING
	elseif newState == BowState.IDLE then
		return true -- Can always return to idle
	end

	return false
end

-- Transition to new state
local function TransitionState(newState)
	if not CanTransitionTo(newState) then return false end

	-- Exit current state
	if CurrentState == BowState.AIMED or CurrentState == BowState.DRAWING then
		-- Only unlock mouse if we're not going into another aiming state
		if newState ~= BowState.RELEASING and newState ~= BowState.AIMED then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

	-- Enter new state
	CurrentState = newState
	StateStartTime = time()

	if newState == BowState.DRAWING then
		SaveCameraState()
		IsAiming = true
		IsCameraLocked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		DrawSound:Play()
	elseif newState == BowState.AIMED then
		IsAiming = true
		IsCameraLocked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter  -- Keep cursor locked while aimed
	elseif newState == BowState.RELEASING then
		IsAiming = false
		IsTransitioningOut = false
		IsCameraLocked = true  -- Lock camera during release
		ShotTime = time()
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter  -- Keep locked during release
	elseif newState == BowState.COOLDOWN then
		IsAiming = false
		IsTransitioningOut = true
		IsCameraLocked = true
	elseif newState == BowState.IDLE then
		IsAiming = false
		IsTransitioningOut = false
		IsCameraLocked = false
		RestoreCameraState()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		DrawSound:Stop()
	end

	return true
end

-- Update camera based on current state
local function UpdateCamera()
	local player = Players.LocalPlayer
	if not player or not player.Character then
		TransitionState(BowState.IDLE)
		return
	end

	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		TransitionState(BowState.IDLE)
		return
	end

	local currentTime = time()
	local stateDuration = currentTime - StateStartTime

	-- Update FOV and sensitivity
	local targetFOV = (CurrentState == BowState.DRAWING or CurrentState == BowState.AIMED or CurrentState == BowState.RELEASING) 
		and AIM_FOV or DEFAULT_FOV
	local targetSensitivity = (CurrentState == BowState.DRAWING or CurrentState == BowState.AIMED) 
		and AIM_SENSITIVITY or DEFAULT_SENSITIVITY

	CurrentFOV = CurrentFOV + (targetFOV - CurrentFOV) * ZOOM_SPEED
	CurrentSensitivity = CurrentSensitivity + (targetSensitivity - CurrentSensitivity) * SENSITIVITY_SPEED

	Camera.FieldOfView = CurrentFOV
	UserInputService.MouseDeltaSensitivity = CurrentSensitivity

	-- State-specific camera updates
	if (CurrentState == BowState.DRAWING or CurrentState == BowState.AIMED) and humanoidRootPart then
		Camera.CameraType = Enum.CameraType.Scriptable

		-- Calculate look vectors
		local lookVector = CFrame.fromEulerAnglesYXZ(-CurrentPitch, CurrentYaw, 0).LookVector
		if not lookVector then return end

		local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

		-- Rotate character
		local targetCharacterCF = CFrame.new(humanoidRootPart.Position, 
			humanoidRootPart.Position + flatLookVector)
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCharacterCF, 0.2)

		-- Set camera position
		local rightVector = Vector3.new(flatLookVector.Z, 0, -flatLookVector.X)
		local shoulderPos = humanoidRootPart.Position 
			+ rightVector * SHOULDER_OFFSET.X 
			+ Vector3.new(0, SHOULDER_OFFSET.Y, 0)
			+ flatLookVector * SHOULDER_OFFSET.Z

		local targetPosition = shoulderPos - lookVector * CAMERA_DISTANCE + CameraShakeOffset
		Camera.CFrame = CFrame.new(targetPosition) * CFrame.fromEulerAnglesYXZ(-CurrentPitch, CurrentYaw, 0)

	elseif CurrentState == BowState.RELEASING then
		if stateDuration >= SHOT_FOLLOW_TIME then
			TransitionState(BowState.COOLDOWN)
		end
	elseif CurrentState == BowState.COOLDOWN then
		if stateDuration >= SHOT_COOLDOWN then
			TransitionState(BowState.IDLE)
		end
	end
end

-- Handle mouse movement
local function HandleMouseMovement()
	if CurrentState ~= BowState.DRAWING and CurrentState ~= BowState.AIMED then return end

	local delta = UserInputService:GetMouseDelta() * CurrentSensitivity
	CurrentYaw = CurrentYaw - delta.X * 0.002
	CurrentPitch = math.clamp(CurrentPitch + delta.Y * 0.002, -1.3, 1.3)
end

-- Update charge bar
local function UpdateChargeBar(chargeTime)
	if not IsChargeBarInitialized then
		ChargeBarContainer, ChargeBar = InitializeChargeBar()
	end

	if not IsMouseDown then
		ChargeBarContainer.Visible = false
		return
	end

	-- Show and position the charge bar
	ChargeBarContainer.Visible = true

	-- Calculate charge progress
	local normalizedCharge = math.clamp(chargeTime / MIN_DRAW_TIME, 0, 1)
	local overchargeProgress = math.clamp((chargeTime - MIN_DRAW_TIME) / (MAX_DRAW_TIME - MIN_DRAW_TIME), 0, 1)

	-- Simple positioning first - follow mouse
	if Mouse then
		local targetY = chargeTime >= MIN_DRAW_TIME and 20 or 0
		ChargeBarContainer.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y + targetY)
	end

	-- Update progress
	ChargeBar.Size = UDim2.new(normalizedCharge, 0, 1, 0)

	-- Update color based on charge state
	if chargeTime <= MIN_DRAW_TIME then
		local intensity = 200 + (55 * normalizedCharge)
		ChargeBar.BackgroundColor3 = Color3.fromRGB(intensity, intensity, intensity)
	else
		local r = 255
		local g = math.floor(255 * (1 - overchargeProgress * 0.7))
		local b = math.floor(255 * (1 - overchargeProgress))
		ChargeBar.BackgroundColor3 = Color3.fromRGB(r, g, b)
	end
end

-- Update bracket positions and rotation
local function UpdateBrackets(chargeTime)
	if not Mouse or not IsMouseDown then
		for _, bracket in ipairs(brackets) do
			bracket.Visible = false
		end
		CurrentBracketSpread = BRACKET_SPREAD -- Reset spread when not charging
		UserInputService.MouseIconEnabled = true -- Show cursor when not charging
		return
	end

	-- Hide cursor as soon as mouse is held down
	UserInputService.MouseIconEnabled = false

	-- Only show brackets after minimum draw time
	if chargeTime < MIN_DRAW_TIME then
		for _, bracket in ipairs(brackets) do
			bracket.Visible = false
		end
		CurrentBracketSpread = BRACKET_SPREAD -- Reset spread when not fully charged
		return
	end

	local viewportSize = Camera.ViewportSize
	local scale = math.min(viewportSize.X/1920, viewportSize.Y/1080)

	-- Calculate power and spread reduction (matching server logic)
	local overchargeTime = math.max(0, chargeTime - MIN_DRAW_TIME)
	local overchargeProgress = math.clamp(overchargeTime / (MAX_DRAW_TIME - MIN_DRAW_TIME), 0, 1)

	-- Calculate target spread
	local targetSpread = BRACKET_MIN_SPREAD + (BRACKET_SPREAD * BASE_SPREAD_MULTIPLIER - BRACKET_MIN_SPREAD) * (1 - overchargeProgress)

	-- Stop bracket movement at max charge
	if overchargeProgress >= 1 then
		CurrentBracketSpread = BRACKET_MIN_SPREAD
	else
		-- Smoothly lerp current spread to target
		CurrentBracketSpread = CurrentBracketSpread + (targetSpread - CurrentBracketSpread) * BRACKET_LERP_SPEED
	end

	-- Apply scaling
	local scaledSpread = CurrentBracketSpread * scale

	-- Update each bracket
	for i, bracket in ipairs(brackets) do
		local angle = math.rad(bracketAngles[i])

		-- Calculate position offset from cursor
		local offsetX = math.cos(angle) * scaledSpread
		local offsetY = math.sin(angle) * scaledSpread

		-- Position bracket relative to mouse position
		bracket.Position = UDim2.new(0, Mouse.X + offsetX, 0, Mouse.Y + offsetY)

		-- Rotate bracket
		bracket.Rotation = math.deg(angle) + 180

		-- Show bracket after minimum draw time
		bracket.Visible = true
	end
end

-- Calculate charge-based effects
local function UpdateChargeEffects(chargeTime)
	if not IsMouseDown then
		VignetteFrame.BackgroundTransparency = 1
		CameraShakeOffset = Vector3.new(0, 0, 0)
		return
	end

	-- Calculate charge progress
	local normalCharge = math.clamp(chargeTime / MIN_DRAW_TIME, 0, 1)
	local overcharge = math.clamp((chargeTime - MIN_DRAW_TIME) / (MAX_DRAW_TIME - MIN_DRAW_TIME), 0, 1)

	-- Update vignette
	local vignetteAlpha = overcharge * SCREEN_EFFECT_INTENSITY
	VignetteFrame.BackgroundTransparency = 1 - vignetteAlpha

	-- Calculate FOV based on charge
	local fovRange = AIM_FOV - MIN_FOV
	TargetFOV = AIM_FOV - (fovRange * overcharge)

	-- Add subtle camera shake at high charge
	if overcharge > 0.7 then
		local shakeIntensity = CHARGE_SHAKE_INTENSITY * (overcharge - 0.7) / 0.3
		CameraShakeOffset = Vector3.new(
			(math.random() - 0.5) * shakeIntensity,
			(math.random() - 0.5) * shakeIntensity,
			0
		)
	else
		CameraShakeOffset = Vector3.new(0, 0, 0)
	end
end

-- Calculate power based on charge time
local function CalculateChargePower()
	local currentTime = time()
	local chargeTime = currentTime - DrawStartTime

	-- Normal charge (0 to 1)
	local normalCharge = math.clamp(chargeTime / MIN_DRAW_TIME, 0, 1)

	-- Overcharge (0 to 1, only after MIN_DRAW_TIME)
	local overcharge = math.clamp((chargeTime - MIN_DRAW_TIME) / (MAX_DRAW_TIME - MIN_DRAW_TIME), 0, 1)

	-- Base power starts at 0.5 (50%) and goes up to 1.0 (100%)
	local basePower = 0.5 + (normalCharge * 0.5)

	-- Overcharge adds additional 50% power
	local overchargePower = overcharge * 0.5

	-- Final power is base + overcharge, maximum of 1.5 (150%)
	return math.min(basePower + overchargePower, 1.5)
end

-- Update draw state
local function UpdateDrawState()
	if IsMouseDown then
		local currentTime = time()
		local drawDuration = currentTime - DrawStartTime
		local wasReady = IsReadyToShoot
		IsReadyToShoot = drawDuration >= MIN_DRAW_TIME

		if IsReadyToShoot ~= wasReady then
			UpdateMouseIcon()
		end

		if IsReadyToShoot then
			TransitionState(BowState.AIMED)
		end
	end
end

-- Update mouse icon
function UpdateMouseIcon()
	if not Mouse or Tool.Parent:IsA("Backpack") then
		return
	end

	if IsMouseDown then
		if IsReadyToShoot then
			Mouse.Icon = CURSOR_STATES.READY
		else
			Mouse.Icon = CURSOR_STATES.DRAWING
		end
	else
		Mouse.Icon = CURSOR_STATES.DEFAULT
	end
end

-- Check if we can start aiming
local function CanStartAiming()
	if time() - LastShotTime < SHOT_COOLDOWN then
		return false
	end
	if IsCameraLocked then
		return false
	end
	if not Players.LocalPlayer.Character then
		return false
	end
	if Tool.Parent:IsA("Backpack") then
		return false
	end
	return true
end

-- Input handlers
UserInputService.InputBegan:Connect(function(input, gameHandledEvent)
	if gameHandledEvent or not ExpectingInput then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and Mouse then
		if not CanStartAiming() then return end

		IsMouseDown = true
		DrawStartTime = time()
		IsReadyToShoot = false
		IsTransitioningOut = false
		IsCameraLocked = false

		TransitionState(BowState.DRAWING)
		UpdateMouseIcon()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameHandledEvent)
	if gameHandledEvent or not ExpectingInput then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and Mouse then
		-- Hide brackets immediately on release
		for _, bracket in ipairs(brackets) do
			bracket.Visible = false
		end

		if IsReadyToShoot and CurrentState == BowState.AIMED then
			local power = CalculateChargePower()
			MouseEvent:FireServer(Mouse.Hit.Position, power)  -- Send power to server
			LastShotTime = time()
			TransitionState(BowState.RELEASING)
		else
			TransitionState(BowState.IDLE)
		end

		IsMouseDown = false
		DrawStartTime = 0
		IsReadyToShoot = false

		DrawSound:Stop()
		UpdateMouseIcon()
	end
end)

-- Main update loop
RunService.RenderStepped:Connect(function(deltaTime)
	local currentTime = time()
	local chargeTime = IsMouseDown and (currentTime - DrawStartTime) or 0

	if IsMouseDown then
		print("Updating charge bar, time:", chargeTime)
	end

	UpdateCamera()
	UpdateChargeBar(chargeTime)
	UpdateChargeEffects(chargeTime)
	UpdateBrackets(chargeTime)

	-- Handle shot follow-through
	if CurrentState == BowState.RELEASING and currentTime - StateStartTime >= SHOT_FOLLOW_TIME then
		TransitionState(BowState.COOLDOWN)
	elseif CurrentState == BowState.COOLDOWN and currentTime - StateStartTime >= SHOT_COOLDOWN then
		TransitionState(BowState.IDLE)
	end

	if IsMouseDown then
		UpdateDrawState()
		HandleMouseMovement()

		-- Check for transition to AIMED state
		if CurrentState == BowState.DRAWING and IsReadyToShoot then
			TransitionState(BowState.AIMED)
		end
	end
end)

-- Equipment handlers
Tool.Equipped:Connect(function()
	Mouse = Players.LocalPlayer:GetMouse()
	ExpectingInput = true
	InitializeState()
	UpdateMouseIcon()
	-- Ensure charge bar is initialized
	if not IsChargeBarInitialized then
		ChargeBarContainer, ChargeBar = InitializeChargeBar()
	end
	print("Tool equipped, charge bar ready")
end)

Tool.Unequipped:Connect(function()
	UserInputService.MouseIconEnabled = true
	ExpectingInput = false
	TransitionState(BowState.IDLE)
	InitializeState()
	UpdateMouseIcon()
end)