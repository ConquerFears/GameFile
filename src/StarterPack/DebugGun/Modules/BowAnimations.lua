local BowAnimations = {}

-- Animation IDs
local ANIMATION_IDS = {
    IDLE = "74772536397822",
    IDLE_WITH_ARROW = "114465249543883",
    DRAWING = "137840324119416",
    RELEASE = "102619029915670",
    NOCK = "101306611205893"
}

-- Constants
local DRAW_BLEND_TIME = 0.3
local RELEASE_BLEND_TIME = 0.1
local NOCK_BLEND_TIME = 0.3

function BowAnimations.new(tool)
    local self = setmetatable({}, {__index = BowAnimations})
    self.tool = tool
    self.animations = {}
    self.currentState = "idle"
    self.initialized = false
    return self
end

function BowAnimations:Initialize()
    if self.initialized then return end
    
    -- Get necessary parts
    self.bowPart = self.tool.Handle1.Bow
    self.arrowPart = self.tool.Handle1.Arrow
    self.topBeam = self.bowPart.TopBeam
    self.bottomBeam = self.bowPart.BottomBeam
    self.middleAttachment = self.bowPart.Middle
    
    -- Setup initial states
    self.arrowPart.Transparency = 1
    self:LoadAnimations()
    
    self.initialized = true
end

function BowAnimations:LoadAnimations()
    local character = self.tool.Parent
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local animator = humanoid:FindFirstChild("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    
    self.animator = animator
    
    -- Load all animations
    self.animations = {
        idle = self:CreateAnimation(ANIMATION_IDS.IDLE),
        idleWithArrow = self:CreateAnimation(ANIMATION_IDS.IDLE_WITH_ARROW),
        drawing = self:CreateAnimation(ANIMATION_IDS.DRAWING),
        release = self:CreateAnimation(ANIMATION_IDS.RELEASE),
        nock = self:CreateAnimation(ANIMATION_IDS.NOCK)
    }
end

function BowAnimations:CreateAnimation(id)
    local animation = Instance.new("Animation")
    animation.AnimationId = id
    local track = self.animator:LoadAnimation(animation)
    return {
        track = track,
        weight = 0
    }
end

function BowAnimations:SetupLeftGrip(character)
    if self.leftGrip then
        self.leftGrip:Destroy()
    end
    
    local leftHand = character:FindFirstChild("LeftHand")
    if not leftHand then return end
    
    self.leftGrip = Instance.new("Motor6D")
    self.leftGrip.Name = "LeftGrip"
    self.leftGrip.Part0 = leftHand
    self.leftGrip.Part1 = self.bowPart
    self.leftGrip.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)
    self.leftGrip.C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
    self.leftGrip.Parent = leftHand
end

function BowAnimations:UpdateBowString(drawProgress)
    if not self.initialized then return end
    
    local middleOffset = Vector3.new(0, 0, -drawProgress * 2)
    self.middleAttachment.Position = middleOffset
end

function BowAnimations:SetArrowVisibility(visible)
    if not self.initialized then return end
    self.arrowPart.Transparency = visible and 0 or 1
end

function BowAnimations:PlayAnimation(name, fadeTime)
    if not self.initialized then return end
    if not self.animations[name] then return end
    
    -- Stop other animations
    for animName, animData in pairs(self.animations) do
        if animName ~= name then
            animData.track:Stop(fadeTime or 0.1)
        end
    end
    
    local anim = self.animations[name]
    if not anim.track.IsPlaying then
        anim.track:Play(fadeTime or 0.1)
    end
end

function BowAnimations:StopAllAnimations(fadeTime)
    if not self.initialized then return end
    
    for _, animData in pairs(self.animations) do
        animData.track:Stop(fadeTime or 0.1)
    end
end

function BowAnimations:UpdateDrawing(drawTime, minDrawTime)
    if not self.initialized then return end
    
    local drawProgress = math.clamp(drawTime / minDrawTime, 0, 1)
    self:UpdateBowString(drawProgress)
    
    -- Update drawing animation weight if needed
    if self.animations.drawing and self.animations.drawing.track.IsPlaying then
        self.animations.drawing.track:AdjustWeight(drawProgress)
    end
end

function BowAnimations:HandleStateChange(newState, bowState)
    if not self.initialized then return end
    
    if newState == bowState.States.IDLE then
        self:SetArrowVisibility(false)
        self:PlayAnimation("idle", DRAW_BLEND_TIME)
    elseif newState == bowState.States.DRAWING then
        self:SetArrowVisibility(true)
        self:PlayAnimation("drawing", DRAW_BLEND_TIME)
    elseif newState == bowState.States.AIMED then
        self:SetArrowVisibility(true)
        -- Keep the drawing animation playing but fully weighted
        if self.animations.drawing then
            self.animations.drawing.track:AdjustWeight(1)
        end
    elseif newState == bowState.States.RELEASING then
        self:SetArrowVisibility(false)
        self:PlayAnimation("release", RELEASE_BLEND_TIME)
    elseif newState == bowState.States.NOCKING then
        self:PlayAnimation("nock", NOCK_BLEND_TIME)
    elseif newState == bowState.States.IDLE_WITH_ARROW then
        self:SetArrowVisibility(true)
        self:PlayAnimation("idleWithArrow", NOCK_BLEND_TIME)
    end
    
    self.currentState = newState
end

function BowAnimations:Cleanup()
    if not self.initialized then return end
    
    self:StopAllAnimations()
    
    if self.leftGrip then
        self.leftGrip:Destroy()
        self.leftGrip = nil
    end
    
    -- Reset parts
    if self.arrowPart then
        self.arrowPart.Transparency = 1
    end
    
    if self.middleAttachment then
        self.middleAttachment.Position = Vector3.new(0, 0, 0)
    end
    
    self.initialized = false
end

return BowAnimations 