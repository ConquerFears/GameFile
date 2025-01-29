local Signal = require(script.Parent.Parent.FastCastRedux.Signal)
local BowState = {}

-- State machine states
BowState.States = {
    IDLE = "idle",
    NOCKING = "nocking",
    IDLE_WITH_ARROW = "idleWithArrow",
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
local NOCKING_TIME = 0.5

-- Debug settings
local DEBUG_MODE = false

function BowState.new()
    local self = setmetatable({}, {__index = BowState})
    
    -- Core state
    self.currentState = BowState.States.IDLE
    self.stateStartTime = 0
    self.drawStartTime = 0
    self.lastShotTime = 0
    self.nockStartTime = 0
    
    -- State flags
    self.isMouseDown = false
    self.isReadyToShoot = false
    self.isCameraLocked = false
    self.isAiming = false
    self.isTransitioningOut = false
    self.isToolEquipped = false
    
    -- New state management features
    self.stateChanged = Signal.new("StateChanged")
    self.stateHistory = {}
    self.maxHistoryLength = 10
    self.debugMode = DEBUG_MODE
    
    return self
end

function BowState:ValidateState(state)
    for _, validState in pairs(BowState.States) do
        if state == validState then
            return true
        end
    end
    return false
end

function BowState:LogStateChange(from, to, duration)
    if not self.debugMode then return end
    print(string.format("[BowState] %s -> %s (Duration: %.2fs)", from, to, duration))
end

function BowState:AddToHistory(transitionData)
    table.insert(self.stateHistory, 1, transitionData)
    if #self.stateHistory > self.maxHistoryLength then
        table.remove(self.stateHistory)
    end
end

function BowState:ApplyStateChanges(newState)
    local stateChanges = {
        [BowState.States.NOCKING] = function()
            self.nockStartTime = time()
            self.isAiming = false
            self.isCameraLocked = false
            self.isMouseDown = true
        end,
        [BowState.States.IDLE_WITH_ARROW] = function()
            self.isAiming = false
            self.isCameraLocked = false
            self.isMouseDown = true
        end,
        [BowState.States.DRAWING] = function()
            self.isAiming = true
            self.isCameraLocked = false
            self.drawStartTime = time()
            self.isMouseDown = true
        end,
        [BowState.States.AIMED] = function()
            self.isAiming = true
            self.isCameraLocked = false
            self.isMouseDown = true
        end,
        [BowState.States.RELEASING] = function()
            self.isAiming = false
            self.isTransitioningOut = true
            self.isCameraLocked = true
            self.lastShotTime = time()
            self.isReadyToShoot = false
            self.isMouseDown = false
        end,
        [BowState.States.COOLDOWN] = function()
            self.isAiming = false
            self.isTransitioningOut = false
            self.isCameraLocked = false
            self.isMouseDown = false
        end,
        [BowState.States.IDLE] = function()
            self.isAiming = false
            self.isTransitioningOut = false
            self.isCameraLocked = false
            self.isReadyToShoot = false
            self.drawStartTime = 0
            self.nockStartTime = 0
            self.isMouseDown = false
        end
    }

    if stateChanges[newState] then
        local success, err = pcall(stateChanges[newState])
        if not success and self.debugMode then
            warn(string.format("[BowState] Error applying state changes: %s", err))
        end
    end
end

function BowState:CanTransitionTo(newState)
    if not self:ValidateState(newState) then
        if self.debugMode then
            warn(string.format("[BowState] Invalid state: %s", tostring(newState)))
        end
        return false
    end
    
    local currentTime = time()
    
    -- Basic validity checks
    if not self:IsToolEquipped() then return false end
    
    -- Always check cooldown, even if transitioning from IDLE
    if newState == BowState.States.DRAWING and currentTime - self.lastShotTime < SHOT_COOLDOWN then
        if self.debugMode then
            warn("[BowState] Cannot draw while in cooldown")
        end
        return false
    end
    
    -- State-specific checks
    if newState == BowState.States.NOCKING then
        return self.currentState == BowState.States.IDLE
    elseif newState == BowState.States.IDLE_WITH_ARROW then
        return self.currentState == BowState.States.NOCKING and 
               (currentTime - self.nockStartTime >= NOCKING_TIME)
    elseif newState == BowState.States.DRAWING then
        return self.currentState == BowState.States.IDLE_WITH_ARROW and not self.isCameraLocked
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

function BowState:TransitionTo(newState)
    if not self:CanTransitionTo(newState) then return false end
    
    local previousState = self.currentState
    local transitionTime = time()
    local stateDuration = transitionTime - self.stateStartTime
    
    -- Create transition data
    local transitionData = {
        from = tostring(previousState),  -- Ensure string
        to = tostring(newState),         -- Ensure string
        timestamp = transitionTime,
        duration = stateDuration
    }
    
    -- Update state
    self.currentState = newState
    self.stateStartTime = transitionTime
    
    -- Apply state-specific changes
    self:ApplyStateChanges(newState)
    
    -- Add to history and log
    self:AddToHistory(transitionData)
    self:LogStateChange(previousState, newState, stateDuration)
    
    -- Fire state change event
    self.stateChanged:Fire(transitionData)
    
    return true
end

-- Keep existing methods for compatibility
function BowState:ForceReset()
    local previousState = self.currentState
    self.currentState = BowState.States.IDLE
    self.stateStartTime = 0
    self.drawStartTime = 0
    self.lastShotTime = 0
    self.isMouseDown = false
    self.isReadyToShoot = false
    self.isCameraLocked = false
    self.isAiming = false
    self.isTransitioningOut = false
    
    if self.debugMode then
        print("[BowState] Force reset from", previousState)
    end
end

function BowState:Reset()
    if self.currentState == BowState.States.COOLDOWN then
        local previousLastShotTime = self.lastShotTime
        self.stateStartTime = time() - (time() - previousLastShotTime)
        self.lastShotTime = previousLastShotTime
    else
        self:ForceReset()
    end
end

function BowState:Update()
    local currentTime = time()
    local stateDuration = currentTime - self.stateStartTime
    
    if self.currentState == BowState.States.NOCKING then
        if stateDuration >= NOCKING_TIME then
            self:TransitionTo(BowState.States.IDLE_WITH_ARROW)
        end
    elseif self.currentState == BowState.States.IDLE_WITH_ARROW then
        -- Only transition to drawing if mouse is still held down
        if self.isMouseDown then
            self:TransitionTo(BowState.States.DRAWING)
            self.drawStartTime = currentTime
        end
    elseif self.currentState == BowState.States.DRAWING then
        if not self.isMouseDown then
            -- If mouse released during draw, cancel back to idle
            self:TransitionTo(BowState.States.IDLE)
            return
        end
        
        local drawDuration = currentTime - self.drawStartTime
        self.isReadyToShoot = drawDuration >= MIN_DRAW_TIME
        
        if self.isReadyToShoot then
            self:TransitionTo(BowState.States.AIMED)
        end
    elseif self.currentState == BowState.States.AIMED then
        if not self.isMouseDown then
            -- Only release if we're fully drawn
            self:TransitionTo(BowState.States.RELEASING)
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

-- Keep existing utility methods
function BowState:GetChargeTime()
    -- Only return charge time during drawing or aimed states
    if self.currentState == BowState.States.DRAWING or 
       self.currentState == BowState.States.AIMED then
        if self.drawStartTime == 0 then return 0 end
        return time() - self.drawStartTime
    end
    return 0
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

-- New debug and monitoring methods
function BowState:EnableDebugMode(enabled)
    self.debugMode = enabled
end

function BowState:GetStateHistory()
    return table.clone(self.stateHistory)
end

function BowState:GetStateMetrics()
    local metrics = {}
    for _, transition in ipairs(self.stateHistory) do
        metrics[transition.from] = metrics[transition.from] or {
            totalTransitions = 0,
            averageDuration = 0,
            totalDuration = 0
        }
        
        local stat = metrics[transition.from]
        stat.totalTransitions += 1
        stat.totalDuration += transition.duration
        stat.averageDuration = stat.totalDuration / stat.totalTransitions
    end
    return metrics
end

return BowState 