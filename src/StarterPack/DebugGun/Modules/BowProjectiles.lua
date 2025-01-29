local BowProjectiles = {}

-- Constants
local BASE_BULLET_SPEED = 150
local MAX_BULLET_SPEED = 300
local BULLET_MAXDIST = 1000
local BASE_BULLET_GRAVITY = workspace.Gravity
local MIN_BULLET_SPREAD_ANGLE = 0.2
local MAX_BULLET_SPREAD_ANGLE = 2
local BASE_SPREAD_MULTIPLIER = 0.75
local BASE_DAMAGE = 20
local MAX_DAMAGE = 40

-- Services
local Debris = game:GetService("Debris")

function BowProjectiles.new(tool)
    local self = setmetatable({}, {__index = BowProjectiles})
    self.tool = tool
    self:Initialize()
    return self
end

function BowProjectiles:Initialize()
    -- Get references
    self.handle = self.tool:WaitForChild("Handle1")
    self.firePointObject = self.handle:WaitForChild("Bow"):WaitForChild("GunFirePoint")
    self.fireSound = self.handle:WaitForChild("Fire")
    self.impactParticle = self.handle:WaitForChild("Arrow"):WaitForChild("ImpactParticle")
    
    -- Setup FastCast
    self.fastCast = require(self.tool.FastCastRedux)
    self.partCache = require(self.tool.PartCache)
    self.caster = self.fastCast.new()
    
    -- Debug settings
    self.fastCast.DebugLogging = false
    self.fastCast.VisualizeCasts = false
    
    self:SetupBulletContainer()
    self:SetupBulletTemplate()
    self:SetupCastBehavior()
    self:ConnectEvents()
end

function BowProjectiles:SetupBulletContainer()
    self.cosmeticBulletsFolder = workspace:FindFirstChild("CosmeticBulletsFolder") 
        or Instance.new("Folder")
    self.cosmeticBulletsFolder.Name = "CosmeticBulletsFolder"
    self.cosmeticBulletsFolder.Parent = workspace
end

function BowProjectiles:SetupBulletTemplate()
    local bullet = Instance.new("Part")
    bullet.Material = Enum.Material.Neon
    bullet.Color = Color3.fromRGB(255, 200, 100)
    bullet.CanCollide = false
    bullet.Anchored = true
    bullet.Size = Vector3.new(0.2, 0.2, 2)
    
    self.cosmeticPartProvider = self.partCache.new(bullet, 100, self.cosmeticBulletsFolder)
end

function BowProjectiles:SetupCastBehavior()
    self.castParams = RaycastParams.new()
    self.castParams.IgnoreWater = true
    self.castParams.FilterType = Enum.RaycastFilterType.Exclude
    self.castParams.FilterDescendantsInstances = {self.cosmeticBulletsFolder}
    
    self.castBehavior = self.fastCast.newBehavior()
    self.castBehavior.RaycastParams = self.castParams
    self.castBehavior.MaxDistance = BULLET_MAXDIST
    self.castBehavior.CosmeticBulletProvider = self.cosmeticPartProvider
    self.castBehavior.CosmeticBulletContainer = self.cosmeticBulletsFolder
    self.castBehavior.AutoIgnoreContainer = true
end

function BowProjectiles:ConnectEvents()
    self.caster.RayHit:Connect(function(...)
        self:OnRayHit(...)
    end)
    
    self.caster.LengthChanged:Connect(function(...)
        self:OnRayUpdated(...)
    end)
    
    self.caster.CastTerminating:Connect(function(...)
        self:OnRayTerminated(...)
    end)
end

function BowProjectiles:PlayFireSound()
    local newSound = self.fireSound:Clone()
    newSound.Parent = self.handle
    newSound:Play()
    Debris:AddItem(newSound, newSound.TimeLength)
end

function BowProjectiles:MakeParticleFX(position, normal)
    local attachment = Instance.new("Attachment")
    attachment.CFrame = CFrame.new(position, position + normal)
    attachment.Parent = workspace.Terrain
    
    local particle = self.impactParticle:Clone()
    particle.Parent = attachment
    particle.Enabled = true
    
    Debris:AddItem(attachment, particle.Lifetime.Max)
    task.delay(0.05, function()
        particle.Enabled = false
    end)
end

function BowProjectiles:CalculateProperties(power)
    local scaledPower = power
    
    -- Speed scales more aggressively
    local speed = BASE_BULLET_SPEED + (MAX_BULLET_SPEED - BASE_BULLET_SPEED) * scaledPower
    
    -- Gravity reduces less with power for better arcs
    local gravityMultiplier = 1 - (scaledPower * 0.4)
    local gravity = Vector3.new(0, -BASE_BULLET_GRAVITY * gravityMultiplier, 0)
    
    -- Calculate spread
    local overchargeProgress = math.clamp((power - 0.5) / 1, 0, 1)
    local currentSpread = MIN_BULLET_SPREAD_ANGLE + 
        (MAX_BULLET_SPREAD_ANGLE * BASE_SPREAD_MULTIPLIER - MIN_BULLET_SPREAD_ANGLE) * 
        (1 - overchargeProgress)
    
    local spreadVariance = currentSpread * 0.1
    local minSpread = currentSpread - spreadVariance
    local maxSpread = currentSpread + spreadVariance
    
    -- Damage scales gradually
    local damage = BASE_DAMAGE + (MAX_DAMAGE - BASE_DAMAGE) * scaledPower
    
    return {
        Speed = speed,
        Gravity = gravity,
        MinSpread = minSpread,
        MaxSpread = maxSpread,
        Damage = damage
    }
end

function BowProjectiles:Fire(direction, power)
    if not power then power = 1 end
    
    local props = self:CalculateProperties(power)
    self.castBehavior.Acceleration = props.Gravity
    
    -- Create spread
    local directionCF = CFrame.lookAt(Vector3.new(), direction)
    local spreadXAngle = math.rad(math.random(-props.MaxSpread, props.MaxSpread))
    local spreadYAngle = math.rad(math.random(-props.MaxSpread, props.MaxSpread))
    local finalDirection = (directionCF * CFrame.Angles(spreadXAngle, spreadYAngle, 0)).LookVector
    
    -- Fire the cast
    local cast = self.caster:Fire(
        self.firePointObject.WorldPosition, 
        finalDirection, 
        finalDirection * props.Speed, 
        self.castBehavior
    )
    
    if cast then
        cast.UserData = {
            Damage = props.Damage
        }
    end
    
    self:PlayFireSound()
end

function BowProjectiles:OnRayHit(cast, result)
    if not result then return end
    
    local hitPart = result.Instance
    local hitPoint = result.Position
    local normal = result.Normal
    
    if hitPart and hitPart.Parent then
        local humanoid = hitPart.Parent:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local damage = cast.UserData.Damage or BASE_DAMAGE
            humanoid:TakeDamage(damage)
        end
        self:MakeParticleFX(hitPoint, normal)
    end
end

function BowProjectiles:OnRayUpdated(cast, origin, direction, length)
    local bullet = cast.RayInfo.CosmeticBulletObject
    if not bullet then return end
    
    local bulletLength = bullet.Size.Z / 2
    local bulletCF = CFrame.lookAt(origin, origin + direction)
    bullet.CFrame = bulletCF * CFrame.new(0, 0, -(length - bulletLength))
end

function BowProjectiles:OnRayTerminated(cast)
    -- Let FastCast handle cleanup
end

function BowProjectiles:UpdateFilterList(character)
    if character then
        self.castParams.FilterDescendantsInstances = {character, self.cosmeticBulletsFolder}
    end
end

function BowProjectiles:GetBaseSpreadMultiplier()
    return BASE_SPREAD_MULTIPLIER
end

function BowProjectiles:Cleanup()
    -- Cleanup if needed
end

return BowProjectiles 