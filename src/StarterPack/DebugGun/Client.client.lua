-- Path: src/StarterPack/DebugGun/Client.client.lua

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Modules
local BowCamera = require(script.Parent.Modules.BowCamera)
local BowUI = require(script.Parent.Modules.BowUI)
local BowState = require(script.Parent.Modules.BowState)
local BowProjectiles = require(script.Parent.Modules.BowProjectiles)
local BowAnimations = require(script.Parent.Modules.BowAnimations)

-- References
local Tool = script.Parent
local Handle1 = Tool:WaitForChild("Handle1")
local Bow = Handle1:WaitForChild("Bow")
local DrawSound = Handle1:WaitForChild("Draw")
local FireSound = Handle1:WaitForChild("Fire")
local MouseEvent = Tool:WaitForChild("MouseEvent")

-- Different cursor states
local CURSOR_STATES = {
	DEFAULT = "",  -- Empty string means default system cursor
	IDLE = "rbxassetid://140530585218698",  -- Normal dot cursor
	COOLDOWN = "rbxassetid://135877679054660",  -- Gray dot cursor
	DRAWING = "rbxassetid://140530585218698",  -- Same as idle dot cursor
	READY = "rbxassetid://140530585218698"  -- Same as idle dot cursor
}

-- Initialize components
local bowCamera = BowCamera.new()
local bowUI = BowUI.new()
local bowState = BowState.new()
local bowProjectiles
local bowAnimations
local mouse = nil

-- Variables
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Mouse = LocalPlayer:GetMouse()

-- Constants
local MOUSE_BUTTON1 = Enum.UserInputType.MouseButton1
local CAMERA_SENSITIVITY = 0.5

-- Update mouse icon based on state
local function UpdateMouseIcon()
	if not mouse then return end
	
	-- If tool is in backpack or unequipped, use system default
	if Tool.Parent:IsA("Backpack") or not bowState:IsToolEquipped() then
		mouse.Icon = CURSOR_STATES.DEFAULT
		UserInputService.MouseIconEnabled = true
		return
	end

	-- Check cooldown first
	if bowState.currentState == BowState.States.COOLDOWN or 
	   (time() - bowState.lastShotTime < bowState:GetConstants().SHOT_COOLDOWN) then
		mouse.Icon = CURSOR_STATES.COOLDOWN
	elseif bowState.isMouseDown then
		if bowState.isReadyToShoot then
			mouse.Icon = CURSOR_STATES.READY
		else
			mouse.Icon = CURSOR_STATES.DRAWING
		end
	else
		mouse.Icon = CURSOR_STATES.IDLE
	end
	UserInputService.MouseIconEnabled = true
end

-- Input handlers
local function handleInput(input, gameProcessed)
	if gameProcessed then return end
	if not bowState:IsToolEquipped() then return end
	
	if input.UserInputType == MOUSE_BUTTON1 then
		if input.UserInputState == Enum.UserInputState.Begin then
			bowState.isMouseDown = true
			
			if bowState.currentState == BowState.States.IDLE then
				bowState:TransitionTo(BowState.States.NOCKING)
				DrawSound:Play()  -- Play draw sound when starting to nock
			end
		elseif input.UserInputState == Enum.UserInputState.End then
			bowState.isMouseDown = false
			
			if bowState.currentState == BowState.States.AIMED then
				bowState:TransitionTo(BowState.States.RELEASING)
				DrawSound:Stop()  -- Stop draw sound
				FireSound:Play()  -- Play fire sound
			else
				DrawSound:Stop()  -- Stop draw sound if released early
			end
		end
	end
end

-- Main update loop
local function onUpdate()
	if not bowState:IsToolEquipped() then return end
	
	-- Update state machine
	bowState:Update()
	
	-- Get current state info
	local currentState = bowState.currentState
	local chargeTime = bowState:GetChargeTime()
	local constants = bowState:GetConstants()
	
	-- Update camera only in appropriate states
	if currentState == BowState.States.DRAWING or 
	   currentState == BowState.States.AIMED then
		local delta = UserInputService:GetMouseDelta() * CAMERA_SENSITIVITY
		bowCamera:UpdateAim(delta, 1)
		
		-- Update camera position
		local rootPart = Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			bowCamera:Update(rootPart)
		end
	end
	
	-- Update UI
	bowUI:UpdateChargeBar(chargeTime, constants.MIN_DRAW_TIME, constants.MAX_DRAW_TIME, Mouse)
	bowUI:UpdateBrackets(Mouse, chargeTime, constants.MIN_DRAW_TIME, constants.MAX_DRAW_TIME, 1)
	bowUI:UpdateVignette(chargeTime, constants.MIN_DRAW_TIME, constants.MAX_DRAW_TIME)
	
	-- Update animations
	if bowAnimations then
		bowAnimations:UpdateDrawing(chargeTime, constants.MIN_DRAW_TIME)
	end
end

-- Equipment handlers
local function onEquipped()
	bowState.isToolEquipped = true
	
	-- Initialize projectiles if needed
	if not bowProjectiles then
		bowProjectiles = BowProjectiles.new(Tool)
	end
	
	-- Initialize animations
	if not bowAnimations then
		bowAnimations = BowAnimations.new(Tool)
	end
	bowAnimations:Initialize()
	bowAnimations:SetupLeftGrip(Character)
	
	-- Connect input handling
	UserInputService.InputBegan:Connect(handleInput)
	UserInputService.InputEnded:Connect(handleInput)
	RunService.RenderStepped:Connect(onUpdate)
end

local function onUnequipped()
	bowState.isToolEquipped = false
	bowState:Reset()
	bowCamera:SetEnabled(false)
	bowUI:Reset()
	
	if bowAnimations then
		bowAnimations:Cleanup()
	end
end

-- State change handling
bowState.stateChanged:Connect(function(transition)
	if bowAnimations then
		bowAnimations:HandleStateChange(transition.to, BowState.States)
	end
	
	-- Handle camera based on state
	if transition.to == BowState.States.DRAWING or 
	   transition.to == BowState.States.AIMED then
		bowCamera:SetEnabled(true)
	elseif transition.to == BowState.States.RELEASING or
		   transition.to == BowState.States.IDLE or
		   transition.to == BowState.States.COOLDOWN then
		bowCamera:SetEnabled(false)
	end
end)

-- Connect tool events
Tool.Equipped:Connect(onEquipped)
Tool.Unequipped:Connect(onUnequipped)

-- Setup character handling
local function onCharacterAdded(newCharacter)
	Character = newCharacter
	Humanoid = Character:WaitForChild("Humanoid")
	
	-- Reset state
	bowState:Reset()
	bowCamera:Reset()
	bowUI:Reset()
	
	if bowAnimations then
		bowAnimations:Cleanup()
	end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)