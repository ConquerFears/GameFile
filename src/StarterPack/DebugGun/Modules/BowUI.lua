local BowUI = {}

-- Constants
local BRACKET_SPREAD = 75
local BRACKET_MIN_SPREAD = 12
local BRACKET_IMAGE = "rbxassetid://132698696496946"
local BRACKET_SIZE_X = 30
local BRACKET_SIZE_Y = 20
local BRACKET_TRANSPARENCY = 0.4
local BRACKET_LERP_SPEED = 0.1
local SCREEN_EFFECT_INTENSITY = 0.2

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

function BowUI.new()
    local self = setmetatable({}, {__index = BowUI})
    self.initialized = false
    return self
end

function BowUI:Initialize()
    if self.initialized then return end
    
    self.initialized = true
    self.currentBracketSpread = BRACKET_SPREAD
    self:CreateScreenGui()
    self:CreateBrackets()
    self:CreateChargeBar()
    self:CreateVignette()
    
    -- Hide UI elements initially
    self.chargeBarContainer.Visible = false
    for _, bracket in ipairs(self.brackets) do
        bracket.Visible = false
    end
    self.vignette.BackgroundTransparency = 1
end

function BowUI:CreateScreenGui()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "BowUI"
    self.screenGui.ResetOnSpawn = false
    self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.screenGui.DisplayOrder = 100
    self.screenGui.Parent = playerGui
end

function BowUI:CreateBrackets()
    self.bracketContainer = Instance.new("Frame")
    self.bracketContainer.Name = "BracketContainer"
    self.bracketContainer.BackgroundTransparency = 1
    self.bracketContainer.Size = UDim2.fromScale(1, 1)
    self.bracketContainer.Position = UDim2.fromScale(0, 0)
    self.bracketContainer.Parent = self.screenGui

    self.brackets = {}
    local bracketAngles = {90, 180, 270, 0}

    for i, angle in ipairs(bracketAngles) do
        local bracket = Instance.new("ImageLabel")
        bracket.Name = "Bracket" .. i
        bracket.BackgroundTransparency = 1
        bracket.ImageTransparency = BRACKET_TRANSPARENCY
        bracket.Image = BRACKET_IMAGE
        bracket.Size = UDim2.new(0, BRACKET_SIZE_X, 0, BRACKET_SIZE_Y)
        bracket.AnchorPoint = Vector2.new(0.5, 0.5)
        bracket.Visible = false
        bracket.Parent = self.bracketContainer
        self.brackets[i] = bracket
    end
end

function BowUI:CreateChargeBar()
    self.chargeBarContainer = Instance.new("Frame")
    self.chargeBarContainer.Name = "ChargeBarContainer"
    self.chargeBarContainer.Size = UDim2.new(0, 50, 0, 6)
    self.chargeBarContainer.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    self.chargeBarContainer.BorderSizePixel = 0
    self.chargeBarContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    self.chargeBarContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.chargeBarContainer.ZIndex = 100
    self.chargeBarContainer.Parent = self.screenGui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 2
    stroke.Parent = self.chargeBarContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = self.chargeBarContainer

    self.chargeBar = Instance.new("Frame")
    self.chargeBar.Name = "ChargeBar"
    self.chargeBar.Size = UDim2.new(0, 0, 1, 0)
    self.chargeBar.Position = UDim2.new(0, 0, 0, 0)
    self.chargeBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    self.chargeBar.BorderSizePixel = 0
    self.chargeBar.ZIndex = 101
    self.chargeBar.Parent = self.chargeBarContainer

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = self.chargeBar
end

function BowUI:CreateVignette()
    self.vignette = Instance.new("Frame")
    self.vignette.Name = "Vignette"
    self.vignette.BackgroundTransparency = 1
    self.vignette.Size = UDim2.fromScale(1, 1)
    self.vignette.ZIndex = 99
    self.vignette.Parent = self.screenGui

    local gradient = Instance.new("UIGradient")
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.7, 1),
        NumberSequenceKeypoint.new(1, 0)
    })
    gradient.Color = ColorSequence.new(Color3.new(0, 0, 0))
    gradient.Parent = self.vignette
end

function BowUI:UpdateChargeBar(chargeTime, minDrawTime, maxDrawTime, mousePosition)
    if not self.initialized then return end
    if not mousePosition then
        self.chargeBarContainer.Visible = false
        return
    end

    -- Show charge bar during drawing and aimed states
    self.chargeBarContainer.Visible = chargeTime > 0
    local normalizedCharge = math.clamp(chargeTime / minDrawTime, 0, 1)
    local overchargeProgress = math.clamp((chargeTime - minDrawTime) / (maxDrawTime - minDrawTime), 0, 1)

    -- Position
    local targetY = chargeTime >= minDrawTime and 20 or 0
    self.chargeBarContainer.Position = UDim2.new(0, mousePosition.X, 0, mousePosition.Y + targetY)

    -- Progress
    self.chargeBar.Size = UDim2.new(normalizedCharge, 0, 1, 0)

    -- Color
    if chargeTime <= minDrawTime then
        local intensity = 200 + (55 * normalizedCharge)
        self.chargeBar.BackgroundColor3 = Color3.fromRGB(intensity, intensity, intensity)
    else
        local r = 255
        local g = math.floor(255 * (1 - overchargeProgress * 0.7))
        local b = math.floor(255 * (1 - overchargeProgress))
        self.chargeBar.BackgroundColor3 = Color3.fromRGB(r, g, b)
    end
end

function BowUI:UpdateBrackets(mousePosition, chargeTime, minDrawTime, maxDrawTime, baseSpreadMultiplier)
    if not self.initialized then return end
    if not mousePosition then
        for _, bracket in ipairs(self.brackets) do
            bracket.Visible = false
        end
        self.currentBracketSpread = BRACKET_SPREAD
        return
    end

    -- Show brackets during drawing and aimed states
    local shouldShowBrackets = chargeTime > 0
    for _, bracket in ipairs(self.brackets) do
        bracket.Visible = shouldShowBrackets
    end

    if not shouldShowBrackets then
        self.currentBracketSpread = BRACKET_SPREAD
        return
    end

    local viewportSize = workspace.CurrentCamera.ViewportSize
    local scale = math.min(viewportSize.X/1920, viewportSize.Y/1080)

    local overchargeTime = math.max(0, chargeTime - minDrawTime)
    local overchargeProgress = math.clamp(overchargeTime / (maxDrawTime - minDrawTime), 0, 1)

    local targetSpread = BRACKET_MIN_SPREAD + 
        (BRACKET_SPREAD * baseSpreadMultiplier - BRACKET_MIN_SPREAD) * 
        (1 - overchargeProgress)

    if overchargeProgress >= 1 then
        self.currentBracketSpread = BRACKET_MIN_SPREAD
    else
        self.currentBracketSpread = self.currentBracketSpread + 
            (targetSpread - self.currentBracketSpread) * BRACKET_LERP_SPEED
    end

    local scaledSpread = self.currentBracketSpread * scale

    for i, bracket in ipairs(self.brackets) do
        local angle = math.rad(i * 90 - 90)
        local offsetX = math.cos(angle) * scaledSpread
        local offsetY = math.sin(angle) * scaledSpread

        bracket.Position = UDim2.new(0, mousePosition.X + offsetX, 0, mousePosition.Y + offsetY)
        bracket.Rotation = math.deg(angle) + 180
    end
end

function BowUI:UpdateVignette(chargeTime, minDrawTime, maxDrawTime)
    if not self.initialized then return end
    if chargeTime <= 0 then
        self.vignette.BackgroundTransparency = 1
        return
    end

    local overcharge = math.clamp((chargeTime - minDrawTime) / (maxDrawTime - minDrawTime), 0, 1)
    local vignetteAlpha = overcharge * SCREEN_EFFECT_INTENSITY
    self.vignette.BackgroundTransparency = 1 - vignetteAlpha
end

function BowUI:Reset()
    if not self.initialized then return end
    
    -- Hide all UI elements
    self.chargeBarContainer.Visible = false
    for _, bracket in ipairs(self.brackets) do
        bracket.Visible = false
    end
    self.vignette.BackgroundTransparency = 1
    self.currentBracketSpread = BRACKET_SPREAD
end

function BowUI:Cleanup()
    if not self.initialized then return end
    
    if self.screenGui then
        self.screenGui:Destroy()
        self.initialized = false
    end
end

return BowUI 