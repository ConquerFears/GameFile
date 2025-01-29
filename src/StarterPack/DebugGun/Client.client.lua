-- Path: src/StarterPack/DebugGun/Client.client.lua

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Modules
local BowCamera = require(script.Parent.Modules.BowCamera)
local BowUI = require(script.Parent.Modules.BowUI)
local BowState = require(script.Parent.Modules.BowState)

-- References
local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle1")
local MouseEvent = Tool:WaitForChild("MouseEvent")
local DrawSound = Handle:WaitForChild("Draw")

-- Different cursor states
local CURSOR_STATES = {
	DEFAULT = "",
	DRAWING = "rbxassetid://140530585218698",
	READY = "rbxassetid://140530585218698",
	COOLDOWN = "rbxassetid://140530585218698"  -- Added cooldown cursor state
}

-- Initialize components
local bowCamera = BowCamera.new()
local bowUI = BowUI.new()
local bowState = BowState.new()
local mouse = nil

-- Update mouse icon based on state
local function UpdateMouseIcon()
	if not mouse or Tool.Parent:IsA("Backpack") then return end

	if bowState.currentState == BowState.States.COOLDOWN then
		mouse.Icon = CURSOR_STATES.COOLDOWN
	elseif bowState.isMouseDown then
		if bowState.isReadyToShoot then
			mouse.Icon = CURSOR_STATES.READY
		else
			mouse.Icon = CURSOR_STATES.DRAWING
		end
	else
		mouse.Icon = CURSOR_STATES.DEFAULT
	end
end

-- Input handlers
local function OnInputBegan(input, gameHandled)
	if gameHandled then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not mouse then return end
	if not bowState:IsToolEquipped() then return end
	
	-- Check if we're in cooldown
	if bowState.currentState == BowState.States.COOLDOWN then
		local timeLeft = bowState:GetConstants().SHOT_COOLDOWN - (time() - bowState.lastShotTime)
		if timeLeft > 0 then
			return
		end
	end
	
	-- Reset state if we're not in a valid state
	if bowState.currentState ~= BowState.States.IDLE and bowState.currentState ~= BowState.States.COOLDOWN then
		bowState:ForceReset()
	end

	if bowState:TransitionTo(BowState.States.DRAWING) then
		bowCamera:SetEnabled(true)
		DrawSound:Play()
		UpdateMouseIcon()
	end
end

local function OnInputEnded(input, gameHandled)
	if gameHandled then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not mouse then return end

	if bowState.isReadyToShoot and bowState.currentState == BowState.States.AIMED then
		local power = bowState:CalculateChargePower()
		MouseEvent:FireServer(mouse.Hit.Position, power)
		bowState:TransitionTo(BowState.States.RELEASING)
		bowUI:Reset()
		bowCamera:SetEnabled(false)
	else
		bowState:TransitionTo(BowState.States.IDLE)
		bowCamera:SetEnabled(false)
		bowUI:Reset()
	end

	DrawSound:Stop()
	UpdateMouseIcon()
end

-- Main update loop
local function Update()
	local player = Players.LocalPlayer
	if not player then return end

	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Update state
	bowState:Update()
	UpdateMouseIcon()

	-- Update camera if aiming or transitioning
	if bowState.isAiming or bowState.isTransitioningOut then
		local delta = UserInputService:GetMouseDelta()
		bowCamera:UpdateAim(delta, UserInputService.MouseDeltaSensitivity)
		bowCamera:Update(humanoidRootPart, Vector3.new())
	end

	-- Only show UI elements if actively drawing and not in cooldown
	if mouse and bowState.currentState == BowState.States.DRAWING then
		local chargeTime = bowState:GetChargeTime()
		local constants = bowState:GetConstants()
		
		bowUI:UpdateChargeBar(
			chargeTime,
			constants.MIN_DRAW_TIME,
			constants.MAX_DRAW_TIME,
			Vector2.new(mouse.X, mouse.Y)
		)
		
		bowUI:UpdateBrackets(
			Vector2.new(mouse.X, mouse.Y),
			chargeTime,
			constants.MIN_DRAW_TIME,
			constants.MAX_DRAW_TIME,
			0.75
		)
	end
end

-- Equipment handlers
local function InitializeComponents()
	mouse = Players.LocalPlayer:GetMouse()
	bowUI:Initialize()
	bowState:ForceReset()  -- Use ForceReset instead of Reset
	bowState.isToolEquipped = true
	bowCamera:Reset()
	
	-- Ensure camera is properly initialized
	task.spawn(function()
		task.wait(0.1)  -- Small delay to ensure character is loaded
		if Tool.Parent:IsA("Backpack") then return end
		bowCamera:SaveState()
		bowCamera:SetEnabled(false)  -- Ensure camera starts disabled
	end)
	
	UpdateMouseIcon()
end

local function CleanupComponents()
	UserInputService.MouseIconEnabled = true
	bowState:Reset()
	bowState.isToolEquipped = false
	bowCamera:Cleanup()  -- Changed from Reset to Cleanup
	bowUI:Reset()
	bowUI:Cleanup()
	UpdateMouseIcon()
end

-- Connect input handlers
local inputBeganConnection
local inputEndedConnection
local renderStepConnection

Tool.Equipped:Connect(function()
	task.wait(0.1)  -- Add small delay before initialization
	InitializeComponents()
	
	-- Connect input handlers
	inputBeganConnection = UserInputService.InputBegan:Connect(OnInputBegan)
	inputEndedConnection = UserInputService.InputEnded:Connect(OnInputEnded)
	renderStepConnection = RunService:BindToRenderStep("BowUpdate", Enum.RenderPriority.Camera.Value + 1, Update)
end)

Tool.Unequipped:Connect(function()
	CleanupComponents()
	
	-- Disconnect handlers
	if inputBeganConnection then inputBeganConnection:Disconnect() end
	if inputEndedConnection then inputEndedConnection:Disconnect() end
	if renderStepConnection then RunService:UnbindFromRenderStep("BowUpdate") end
end)