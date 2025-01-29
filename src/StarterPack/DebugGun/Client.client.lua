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
	DEFAULT = "",  -- Empty string means default system cursor
	IDLE = "rbxassetid://140530585218698",  -- Normal dot cursor
	COOLDOWN = "rbxassetid://135877679054660",  -- Gray dot curso
	DRAWING = "rbxassetid://140530585218698",  -- Same as idle dot cursor
	READY = "rbxassetid://140530585218698"  -- Same as idle dot cursor
}

-- Initialize components
local bowCamera = BowCamera.new()
local bowUI = BowUI.new()
local bowState = BowState.new()
local mouse = nil

-- Update mouse icon based on state
local function UpdateMouseIcon()
	if not mouse then return end
	
	-- If tool is in backpack or unequipped, use system default
	if Tool.Parent:IsA("Backpack") or not bowState:IsToolEquipped() then
		mouse.Icon = CURSOR_STATES.DEFAULT
		UserInputService.MouseIconEnabled = true
		return
	end

	-- Handle different states
	if bowState.currentState == BowState.States.COOLDOWN then
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

	bowState.isMouseDown = true  -- Set mouse state before transition
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
	
	-- Update cursor state
	UpdateMouseIcon()

	-- Update camera whenever it's enabled
	if bowCamera.enabled then
		local delta = UserInputService:GetMouseDelta()
		bowCamera:UpdateAim(delta, UserInputService.MouseDeltaSensitivity)
		bowCamera:Update(humanoidRootPart, Vector3.new())
	end

	-- Show UI elements when mouse is down and not in cooldown
	if mouse and bowState.isMouseDown and bowState.currentState ~= BowState.States.COOLDOWN then
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
	bowState:ForceReset()
	bowState.isToolEquipped = true
	bowCamera:Reset()
	bowCamera:SaveState()
	
	-- Set initial cursor state
	if bowState.currentState == BowState.States.COOLDOWN then
		mouse.Icon = CURSOR_STATES.COOLDOWN
	else
		mouse.Icon = CURSOR_STATES.IDLE
	end
	UserInputService.MouseIconEnabled = true
end

local function CleanupComponents()
	UserInputService.MouseIconEnabled = true
	mouse.Icon = CURSOR_STATES.DEFAULT  -- Reset to system default
	bowState:Reset()
	bowState.isToolEquipped = false
	bowCamera:Cleanup()
	bowUI:Reset()
	bowUI:Cleanup()
end

-- Connect input handlers
local inputBeganConnection
local inputEndedConnection
local renderStepConnection

Tool.Equipped:Connect(function()
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