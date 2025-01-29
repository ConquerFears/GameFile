-- Path: src/StarterPack/DebugGun/Server.server.lua

-- Constants
local DEBUG = false                               -- Whether or not to use debugging features of FastCast
local BASE_BULLET_SPEED = 150                     -- Base speed - will be multiplied by power
local MAX_BULLET_SPEED = 300                      -- Maximum bullet speed at full charge
local BULLET_MAXDIST = 1000                       -- The furthest distance the bullet can travel 
local BASE_BULLET_GRAVITY = workspace.Gravity      -- Base gravity - will be reduced with power
local MIN_BULLET_SPREAD_ANGLE = 0.2               -- Minimum spread at max charge (small but not zero)
local MAX_BULLET_SPREAD_ANGLE = 2                 -- Reduced maximum spread for more precision
local BASE_SPREAD_MULTIPLIER = 0.75               -- Base spread is reduced by 25%
local FIRE_DELAY = 0                              -- The amount of time that must pass after firing
local BULLETS_PER_SHOT = 1                        -- Number of bullets per shot
local BASE_DAMAGE = 20                            -- Base damage - will be multiplied by power
local MAX_DAMAGE = 40                             -- Maximum damage at full charge

---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
-- Local Variables

local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle1")
local MouseEvent = Tool:WaitForChild("MouseEvent")
local FirePointObject = Handle:WaitForChild("Bow"):WaitForChild("GunFirePoint")
local FastCast = require(Tool.FastCastRedux)
local FireSound = Handle:WaitForChild("Fire")
local ImpactParticle = Handle:WaitForChild("Arrow"):WaitForChild("ImpactParticle")
local Debris = game:GetService("Debris")
local table = require(Tool.FastCastRedux.Table)
local PartCacheModule = require(Tool.PartCache)

-- State
local CanFire = true

-- Setup FastCast
local Caster = FastCast.new()
FastCast.DebugLogging = DEBUG
FastCast.VisualizeCasts = DEBUG

-- Create container for cosmetic bullets
local CosmeticBulletsFolder = workspace:FindFirstChild("CosmeticBulletsFolder") or Instance.new("Folder")
CosmeticBulletsFolder.Name = "CosmeticBulletsFolder"
CosmeticBulletsFolder.Parent = workspace

-- Create bullet template
local CosmeticBullet = Instance.new("Part")
CosmeticBullet.Material = Enum.Material.Neon
CosmeticBullet.Color = Color3.fromRGB(255, 200, 100)
CosmeticBullet.CanCollide = false
CosmeticBullet.Anchored = true
CosmeticBullet.Size = Vector3.new(0.2, 0.2, 2)

-- Setup PartCache for bullets
local CosmeticPartProvider = PartCacheModule.new(CosmeticBullet, 100, CosmeticBulletsFolder)

-- Setup raycast parameters
local CastParams = RaycastParams.new()
CastParams.IgnoreWater = true
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.FilterDescendantsInstances = {CosmeticBulletsFolder}

-- Create cast behavior
local CastBehavior = FastCast.newBehavior()
CastBehavior.RaycastParams = CastParams
CastBehavior.MaxDistance = BULLET_MAXDIST
CastBehavior.CosmeticBulletProvider = CosmeticPartProvider
CastBehavior.CosmeticBulletContainer = CosmeticBulletsFolder
CastBehavior.AutoIgnoreContainer = true

-- Helper Functions
local function PlayFireSound()
	local NewSound = FireSound:Clone()
	NewSound.Parent = Handle
	NewSound:Play()
	Debris:AddItem(NewSound, NewSound.TimeLength)
end

local function MakeParticleFX(position, normal)
	local attachment = Instance.new("Attachment")
	attachment.CFrame = CFrame.new(position, position + normal)
	attachment.Parent = workspace.Terrain

	local particle = ImpactParticle:Clone()
	particle.Parent = attachment
	particle.Enabled = true

	Debris:AddItem(attachment, particle.Lifetime.Max)
	task.delay(0.05, function()
		particle.Enabled = false
	end)
end

-- Calculate final bullet properties based on power
local function CalculateBulletProperties(power)
	-- Adjust power scale to be more balanced
	local scaledPower = power

	-- Speed scales more aggressively
	local speed = BASE_BULLET_SPEED + (MAX_BULLET_SPEED - BASE_BULLET_SPEED) * scaledPower

	-- Gravity reduces less with power for better arcs
	local gravityMultiplier = 1 - (scaledPower * 0.4)  -- At max power, gravity is reduced by 60%
	local gravity = Vector3.new(0, -BASE_BULLET_GRAVITY * gravityMultiplier, 0)

	-- Calculate overcharge progress (matching client logic)
	local overchargeProgress = math.clamp((power - 0.5) / 1, 0, 1)

	-- Calculate spread that matches bracket visualization
	-- At min power (0.5), spread = MAX_BULLET_SPREAD_ANGLE * BASE_SPREAD_MULTIPLIER
	-- At max power (1.5), spread = MIN_BULLET_SPREAD_ANGLE (0 for perfect accuracy)
	local currentSpread = MIN_BULLET_SPREAD_ANGLE + 
		(MAX_BULLET_SPREAD_ANGLE * BASE_SPREAD_MULTIPLIER - MIN_BULLET_SPREAD_ANGLE) * 
		(1 - overchargeProgress)

	-- Apply spread to both min and max with reduced variance for more precision
	local spreadVariance = currentSpread * 0.1 -- Reduced from 0.2 to 0.1 for tighter spread
	local minSpread = currentSpread - spreadVariance
	local maxSpread = currentSpread + spreadVariance

	-- Damage scales more gradually
	local damage = BASE_DAMAGE + (MAX_DAMAGE - BASE_DAMAGE) * scaledPower

	return {
		Speed = speed,
		Gravity = gravity,
		MinSpread = minSpread,
		MaxSpread = maxSpread,
		Damage = damage
	}
end

-- Event handlers
local function OnRayHit(cast, result)
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
		MakeParticleFX(hitPoint, normal)
	end
end

local function OnRayUpdated(cast, origin, direction, length)
	local bullet = cast.RayInfo.CosmeticBulletObject
	if not bullet then return end

	local bulletLength = bullet.Size.Z / 2
	local bulletCF = CFrame.lookAt(origin, origin + direction)
	bullet.CFrame = bulletCF * CFrame.new(0, 0, -(length - bulletLength))
end

local function OnRayTerminated(cast)
	-- Let FastCast handle the cleanup
	-- The bullet will be returned to PartCache automatically
end

-- Fire function
function Fire(direction, power)
	if Tool.Parent:IsA("Backpack") then return end
	if not CanFire then return end

	CanFire = false

	local props = CalculateBulletProperties(power or 1)
	CastBehavior.Acceleration = props.Gravity

	-- Create spread
	local directionCF = CFrame.lookAt(Vector3.new(), direction)
	local spreadXAngle = math.rad(math.random(-props.MaxSpread, props.MaxSpread))
	local spreadYAngle = math.rad(math.random(-props.MaxSpread, props.MaxSpread))
	local finalDirection = (directionCF * CFrame.Angles(spreadXAngle, spreadYAngle, 0)).LookVector

	-- Fire the cast
	local cast = Caster:Fire(FirePointObject.WorldPosition, finalDirection, finalDirection * props.Speed, CastBehavior)
	if cast then
		cast.UserData = {
			Damage = props.Damage
		}
	end

	PlayFireSound()

	if FIRE_DELAY > 0 then
		task.wait(FIRE_DELAY)
	end
	CanFire = true
end

-- Connect events
Caster.RayHit:Connect(OnRayHit)
Caster.LengthChanged:Connect(OnRayUpdated)
Caster.CastTerminating:Connect(OnRayTerminated)

-- Handle equipped state
Tool.Equipped:Connect(function()
	local char = Tool.Parent
	if char then
		CastParams.FilterDescendantsInstances = {char, CosmeticBulletsFolder}
	end
end)

-- Handle remote event
MouseEvent.OnServerEvent:Connect(function(player, targetPos, power)
	if not player.Character then return end
	if Tool.Parent ~= player.Character then return end

	local direction = (targetPos - FirePointObject.WorldPosition).Unit
	Fire(direction, power)
end)

---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
-- Main Logic

local function Reflect(surfaceNormal, bulletNormal)
	return bulletNormal - (2 * bulletNormal:Dot(surfaceNormal) * surfaceNormal)
end

-- The pierce function can also be used for things like bouncing.
-- In reality, it's more of a function that the module uses to ask "Do I end the cast now, or do I keep going?"
-- Because of this, you can use it for logic such as ray reflection or other redirection methods.
-- A great example might be to pierce or bounce based on something like velocity or angle.
-- You can see this implementation further down in the OnRayPierced function.
function CanRayPierce(cast, rayResult, segmentVelocity)

	-- Let's keep track of how many times we've hit something.
	local hits = cast.UserData.Hits
	if (hits == nil) then
		-- If the hit data isn't registered, set it to 1 (because this is our first hit)
		cast.UserData.Hits = 1
	else
		-- If the hit data is registered, add 1.
		cast.UserData.Hits += 1
	end

	-- And if the hit count is over 3, don't allow piercing and instead stop the ray.
	if (cast.UserData.Hits > 3) then
		return false
	end

	-- Now if we make it here, we want our ray to continue.
	-- This is extra important! If a bullet bounces off of something, maybe we want it to do damage too!
	-- So let's implement that.
	local hitPart = rayResult.Instance
	if hitPart ~= nil and hitPart.Parent ~= nil then
		local humanoid = hitPart.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(10) -- Damage.
		end
	end

	-- And then lastly, return true to tell FC to continue simulating.
	return true

    --[[ 
    -- This function shows off the piercing feature literally. Pass this function as the last argument (after bulletAcceleration) and it will run this every time the ray runs into an object.
    
    -- Do note that if you want this to work properly, you will need to edit the OnRayPierced event handler below so that it doesn't bounce.
    
    if material == Enum.Material.Plastic or material == Enum.Material.Ice or material == Enum.Material.Glass or material == Enum.Material.SmoothPlastic then
        -- Hit glass, plastic, or ice...
        if hitPart.Transparency >= 0.5 then
            -- And it's >= half transparent...
            return true -- Yes! We can pierce.
        end
    end
    return false
    --]]
end

---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
-- Event Handlers

function OnRayHit(cast, raycastResult, segmentVelocity, cosmeticBulletObject)
	-- This function will be connected to the Caster's "RayHit" event.
	local hitPart = raycastResult.Instance
	local hitPoint = raycastResult.Position
	local normal = raycastResult.Normal
	if hitPart ~= nil and hitPart.Parent ~= nil then -- Test if we hit something
		local humanoid = hitPart.Parent:FindFirstChildOfClass("Humanoid") -- Is there a humanoid?
		if humanoid then
			humanoid:TakeDamage(10) -- Damage.
		end
		MakeParticleFX(hitPoint, normal) -- Particle FX
	end
end

function OnRayPierced(cast, raycastResult, segmentVelocity, cosmeticBulletObject)
	-- You can do some really unique stuff with pierce behavior - In reality, pierce is just the module's way of asking "Do I keep the bullet going, or do I stop it here?"
	-- You can make use of this unique behavior in a manner like this, for instance, which causes bullets to be bouncy.
	local position = raycastResult.Position
	local normal = raycastResult.Normal

	local newNormal = Reflect(normal, segmentVelocity.Unit)
	cast:SetVelocity(newNormal * segmentVelocity.Magnitude)

	-- It's super important that we set the cast's position to the ray hit position. Remember: When a pierce is successful, it increments the ray forward by one increment.
	-- If we don't do this, it'll actually start the bounce effect one segment *after* it continues through the object, which for thin walls, can cause the bullet to almost get stuck in the wall.
	cast:SetPosition(position)

	-- Generally speaking, if you plan to do any velocity modifications to the bullet at all, you should use the line above to reset the position to where it was when the pierce was registered.
end

function OnRayUpdated(cast, segmentOrigin, segmentDirection, length, segmentVelocity, cosmeticBulletObject)
	-- Whenever the caster steps forward by one unit, this function is called.
	-- The bullet argument is the same object passed into the fire function.
	if cosmeticBulletObject == nil then return end
	local bulletLength = cosmeticBulletObject.Size.Z / 2 -- This is used to move the bullet to the right spot based on a CFrame offset
	local baseCFrame = CFrame.new(segmentOrigin, segmentOrigin + segmentDirection)
	cosmeticBulletObject.CFrame = baseCFrame * CFrame.new(0, 0, -(length - bulletLength))
end

function OnRayTerminated(cast)
	local cosmeticBullet = cast.RayInfo.CosmeticBulletObject
	if cosmeticBullet ~= nil then
		-- This code here is using an if statement on CastBehavior.CosmeticBulletProvider so that the example gun works out of the box.
		-- In your implementation, you should only handle what you're doing (if you use a PartCache, ALWAYS use ReturnPart. If not, ALWAYS use Destroy.
		if CastBehavior.CosmeticBulletProvider ~= nil then
			CastBehavior.CosmeticBulletProvider:ReturnPart(cosmeticBullet)
		else
			cosmeticBullet:Destroy()
		end
	end
end

MouseEvent.OnServerEvent:Connect(function (clientThatFired, mousePoint, power)
	if not CanFire then
		return
	end
	CanFire = false
	local mouseDirection = (mousePoint - FirePointObject.WorldPosition).Unit
	Fire(mouseDirection, power)
	if FIRE_DELAY > 0.03 then wait(FIRE_DELAY) end
	CanFire = true
end)

Caster.RayHit:Connect(OnRayHit)
Caster.RayPierced:Connect(OnRayPierced)
Caster.LengthChanged:Connect(OnRayUpdated)
Caster.CastTerminating:Connect(OnRayTerminated)

Tool.Equipped:Connect(function ()
	CastParams.FilterDescendantsInstances = {Tool.Parent, CosmeticBulletsFolder}
end)

------------------------------------------------------------------------------------------------------------------------------
-- In production scripts that you are writing that you know you will write properly, you should not do this.
-- This is included exclusively as a result of this being an example script, and users may tweak the values incorrectly.
assert(MAX_BULLET_SPREAD_ANGLE >= MIN_BULLET_SPREAD_ANGLE, "Error: MAX_BULLET_SPREAD_ANGLE cannot be less than MIN_BULLET_SPREAD_ANGLE!")
if (MAX_BULLET_SPREAD_ANGLE > 180) then
	warn("Warning: MAX_BULLET_SPREAD_ANGLE is over 180! This will not pose any extra angular randomization. The value has been changed to 180 as a result of this.")
	MAX_BULLET_SPREAD_ANGLE = 180
end

-- Modules
local BowProjectiles = require(script.Parent.Modules.BowProjectiles)

-- References
local Tool = script.Parent
local MouseEvent = Tool:WaitForChild("MouseEvent")

-- Initialize projectile system
local projectiles = BowProjectiles.new(Tool)

-- Handle equipped state
Tool.Equipped:Connect(function()
    local char = Tool.Parent
    if char then
        projectiles:UpdateFilterList(char)
    end
end)

-- Handle remote event
MouseEvent.OnServerEvent:Connect(function(player, targetPos, power)
    if not player.Character then return end
    if Tool.Parent ~= player.Character then return end

    local direction = (targetPos - projectiles.firePointObject.WorldPosition).Unit
    projectiles:Fire(direction, power)
end)