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
	READY = "rbxassetid://140530585218698"
}

-- Initialize components
local bowCamera = BowCamera.new()
local bowUI = BowUI.new()
local bowState = BowState.new()
local mouse = nil

-- Update mouse icon based on state
local function UpdateMouseIcon()
	if not mouse or Tool.Parent:IsA("Backpack") then return end

	if bowState.isMouseDown then
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

	bowState.isMouseDown = true
	bowState:TransitionTo(BowState.States.DRAWING)
	DrawSound:Play()
	UpdateMouseIcon()
end

local function OnInputEnded(input, gameHandled)
	if gameHandled then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not mouse then return end

	if bowState.isReadyToShoot and bowState.currentState == BowState.States.AIMED then
		local power = bowState:CalculateChargePower()
		MouseEvent:FireServer(mouse.Hit.Position, power)
		bowState:TransitionTo(BowState.States.RELEASING)
	else
		bowState:TransitionTo(BowState.States.IDLE)
	end

	bowState.isMouseDown = false
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

	-- Update camera if aiming
	if bowState.isAiming then
		local delta = UserInputService:GetMouseDelta()
		bowCamera:UpdateAim(delta, UserInputService.MouseDeltaSensitivity)
	end

	-- Update camera position and effects
	local chargeTime = bowState:GetChargeTime()
	local constants = bowState:GetConstants()
	
	bowCamera:Update(humanoidRootPart, Vector3.new())
	
	if mouse then
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
			0.75  -- BASE_SPREAD_MULTIPLIER
		)
		
		bowUI:UpdateVignette(
			chargeTime,
			constants.MIN_DRAW_TIME,
			constants.MAX_DRAW_TIME
		)
	end
end

-- Equipment handlers
Tool.Equipped:Connect(function()
	mouse = Players.LocalPlayer:GetMouse()
	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.InputEnded:Connect(OnInputEnded)
	RunService:BindToRenderStep("BowUpdate", Enum.RenderPriority.Camera.Value + 1, Update)
	UpdateMouseIcon()
end)

Tool.Unequipped:Connect(function()
	UserInputService.MouseIconEnabled = true
	bowState:TransitionTo(BowState.States.IDLE)
	bowCamera:SetEnabled(false)
	bowUI:Cleanup()
	RunService:UnbindFromRenderStep("BowUpdate")
	UpdateMouseIcon()
end)