local BowState = {}

-- State machine states
BowState.States = {
    IDLE = "idle",
    DRAWING = "drawing",
    AIMED = "aimed",
    RELEASING = "releasing",
    COOLDOWN = "cooldown"
}

-- Constants
local MIN_DRAW_TIME = 1.5
local MAX_DRAW_TIME = 7.0
local SHOT_COOLDOWN = 5.0
local SHOT_FOLLOW_TIME = 0.8

function BowState.new()
    local self = setmetatable({}, {__index = BowState})
    self.currentState = BowState.States.IDLE
    self.stateStartTime = 0
    self.drawStartTime = 0
    self.lastShotTime = 0
    self.isMouseDown = false
    self.isReadyToShoot = false
    self.isCameraLocked = false
    self.isAiming = false
    self.isTransitioningOut = false
    self.isToolEquipped = false
    return self
end

function BowState:CanTransitionTo(newState)
    local currentTime = time()
    
    -- Basic validity checks
    if not self:IsToolEquipped() then return false end
    
    -- Always check cooldown, even if transitioning from IDLE
    if newState == BowState.States.DRAWING and currentTime - self.lastShotTime < SHOT_COOLDOWN then
        return false
    end
    
    -- State-specific checks
    if newState == BowState.States.DRAWING then
        return (self.currentState == BowState.States.IDLE or self.currentState == BowState.States.COOLDOWN) 
            and not self.isCameraLocked
    elseif newState == BowState.States.AIMED then
        return self.currentState == BowState.States.DRAWING
    elseif newState == BowState.States.RELEASING then
        return self.currentState == BowState.States.AIMED
    elseif newState == BowState.States.COOLDOWN then
        return self.currentState == BowState.States.RELEASING
    elseif newState == BowState.States.IDLE then
        -- Only allow transition to IDLE if not in cooldown or cooldown is complete
        return self.currentState ~= BowState.States.COOLDOWN or 
               (currentTime - self.lastShotTime >= SHOT_COOLDOWN)
    end
    
    return false
end

function BowState:ForceReset()
    -- Complete reset of all states, ignoring cooldown
    self.currentState = BowState.States.IDLE
    self.stateStartTime = 0
    self.drawStartTime = 0
    self.lastShotTime = 0
    self.isMouseDown = false
    self.isReadyToShoot = false
    self.isCameraLocked = false
    self.isAiming = false
    self.isTransitioningOut = false
end

function BowState:Reset()
    -- Don't reset cooldown-related variables if we're in cooldown
    if self.currentState == BowState.States.COOLDOWN then
        local previousLastShotTime = self.lastShotTime
        self.stateStartTime = time() - (time() - previousLastShotTime)
        self.lastShotTime = previousLastShotTime
    else
        self:ForceReset()
    end
end

function BowState:TransitionTo(newState)
    if not self:CanTransitionTo(newState) then return false end
    
    local previousState = self.currentState
    self.currentState = newState
    self.stateStartTime = time()
    
    if newState == BowState.States.DRAWING then
        self.isAiming = true
        self.isCameraLocked = false
        self.drawStartTime = time()
        -- Don't set isMouseDown here, it's managed by input handlers
    elseif newState == BowState.States.AIMED then
        self.isAiming = true
        self.isCameraLocked = false
    elseif newState == BowState.States.RELEASING then
        self.isAiming = false
        self.isTransitioningOut = true
        self.isCameraLocked = true
        self.lastShotTime = time()
        self.isReadyToShoot = false
        self.isMouseDown = false
    elseif newState == BowState.States.COOLDOWN then
        self.isAiming = false
        self.isTransitioningOut = false
        self.isCameraLocked = false
        self.isMouseDown = false
    elseif newState == BowState.States.IDLE then
        self.isAiming = false
        self.isTransitioningOut = false
        self.isCameraLocked = false
        self.isReadyToShoot = false
        self.drawStartTime = 0
        -- Don't set isMouseDown here, it's managed by input handlers
    end
    
    return true
end

function BowState:Update()
    local currentTime = time()
    local stateDuration = currentTime - self.stateStartTime
    
    if self.currentState == BowState.States.DRAWING then
        local drawDuration = currentTime - self.drawStartTime
        self.isReadyToShoot = drawDuration >= MIN_DRAW_TIME
        
        if self.isReadyToShoot then
            self:TransitionTo(BowState.States.AIMED)
        end
    elseif self.currentState == BowState.States.RELEASING then
        if stateDuration >= SHOT_FOLLOW_TIME then
            self:TransitionTo(BowState.States.COOLDOWN)
        end
    elseif self.currentState == BowState.States.COOLDOWN then
        if stateDuration >= SHOT_COOLDOWN then
            self:TransitionTo(BowState.States.IDLE)
        end
    end
end

function BowState:GetChargeTime()
    if self.currentState ~= BowState.States.DRAWING and 
       self.currentState ~= BowState.States.AIMED then 
        return 0 
    end
    return time() - self.drawStartTime
end

function BowState:CalculateChargePower()
    local chargeTime = self:GetChargeTime()
    
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

function BowState:IsToolEquipped()
    return self.isToolEquipped
end

function BowState:GetConstants()
    return {
        MIN_DRAW_TIME = MIN_DRAW_TIME,
        MAX_DRAW_TIME = MAX_DRAW_TIME,
        SHOT_COOLDOWN = SHOT_COOLDOWN,
        SHOT_FOLLOW_TIME = SHOT_FOLLOW_TIME
    }
end

return BowState 