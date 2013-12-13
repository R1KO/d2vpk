--[[
Ancient Apparition AI
]]

behaviorSystem = {} -- create the global so we can assign to it

function DispatchOnPostSpawn()
	AddThinkToEnt( thisEntity, "AIThink" )
	behaviorSystem = AICore:CreateBehaviorSystem( { BehaviorOrbit, BehaviorLaunchOrb, BehaviorAttackAncient } )--, BehaviorRun }-- } )
end

function AIThink() -- For some reason AddThinkToEnt doesn't accept member functions
	if thisEntity:IsNull() or not thisEntity:IsAlive() then
		return nil -- deactivate this think function
	end
	return behaviorSystem:Think()
end

--------------------------------------------------------------------------------------------------------

BehaviorOrbit =
{
	hasStarted = false,
	cornerInsetMin = 3000,
	cornerInsetMax = 3500
}

function BehaviorOrbit:Evaluate()
	return 1 -- must return a value > 0, so we have a default
end

function BehaviorOrbit:Initialize()
	-- choose -1 or 1
	self.direction = -1 + 2 * RandomInt( 0, 1 )

	self.mapCorners =
	{
		Vec3( GetWorldMinX(), GetWorldMinY(), 0),
		Vec3( GetWorldMinX(), GetWorldMaxY(), 0),
		Vec3( GetWorldMaxX(), GetWorldMaxY(), 0),
		Vec3( GetWorldMaxX(), GetWorldMinY(), 0)
	}

	self.currentCorner = -1
	local closestDistance = 10000000
	local currentPosition = thisEntity:GetOrigin()
	for i=1,4 do
		local thisDistance = ( currentPosition - self.mapCorners[i] ):length()
		if thisDistance < closestDistance then
			self.currentCorner = i
			closestDistance = thisDistance
		end
	end

	self.order =
	{
		UnitIndex = thisEntity:entindex(),
		OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
	}

	-- offset back a corner so GetNextPosition puts us at our corner
	self.currentCorner = self.currentCorner - self.direction
	self:GetNextPosition()

	self.hasStarted = true
end

function BehaviorOrbit:GetNextPosition()
	-- step to the next corner
	self.currentCorner = self.currentCorner + self.direction

	if self.currentCorner < 1 then self.currentCorner = 4 end
	if self.currentCorner > 4 then self.currentCorner = 1 end

	self.order.Position = Vec3( self.mapCorners[self.currentCorner].x, self.mapCorners[self.currentCorner].y, 0 )
	
	local xOffset = RandomInt( self.cornerInsetMin, self.cornerInsetMax )
	local yOffset = RandomInt( self.cornerInsetMin, self.cornerInsetMax )

	if self.currentCorner == 1 or self.currentCorner == 2 then
		self.order.Position.x = self.order.Position.x + xOffset
	else
		self.order.Position.x = self.order.Position.x - xOffset
	end

	if self.currentCorner == 1 or self.currentCorner == 4 then
		self.order.Position.y = self.order.Position.y + yOffset
	else
		self.order.Position.y = self.order.Position.y - yOffset
	end
end

function BehaviorOrbit:Begin()
	if not self.hasStarted then
		self:Initialize()
	end

	self.duration = 1
end

function BehaviorOrbit:Continue()
	self.duration = 1
end

function BehaviorOrbit:Think(dt)
	local currentPos = thisEntity:GetOrigin()
	currentPos.z = 0

	if ( self.order.Position - currentPos ):length() < 500 then
		self:GetNextPosition()
	end
end

--------------------------------------------------------------------------------------------------------

BehaviorLaunchOrb = {}

minDistance = 1000

function BehaviorLaunchOrb:Evaluate()
	self.orbAbility = thisEntity:FindAbilityByName("holdout_ancient_apparition_ice_blast")
	local target
	local desire = 0

	if self.orbAbility and self.orbAbility:IsFullyCastable() then
		local allEnemies = FindUnitsInRadius( DOTA_TEAM_BADGUYS, thisEntity:GetOrigin(), nil, -1, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, 0, 0, false )
		if #allEnemies > 0 then
			local distantEnemies = {}
			for _,enemy in pairs(allEnemies) do
				local distance = ( thisEntity:GetOrigin() - enemy:GetOrigin() ):length()
				if distance > minDistance then
					distantEnemies[#distantEnemies + 1] = enemy
				end
			end
			if #distantEnemies > 0 then
				local index = RandomInt( 1, #distantEnemies )
				target = distantEnemies[index]
			end
		end
	end

	if target then
		desire = 5
		self.order =
		{
			OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
			UnitIndex = thisEntity:entindex(),
			Position = target:GetOrigin(),
			AbilityIndex = self.orbAbility:entindex()
		}
	end

	return desire
end

function BehaviorLaunchOrb:Begin()
	self.duration = 5
end

BehaviorLaunchOrb.Continue = BehaviorLaunchOrb.Begin --if we re-enter this ability, we might have a different target; might as well do a full reset

function BehaviorLaunchOrb:Think(dt)
	if not self.orbAbility:IsFullyCastable() and not self.orbAbility:IsInAbilityPhase() then
		self.duration = 0
	end
end

--------------------------------------------------------------------------------------------------------

BehaviorAttackAncient = {}

function BehaviorAttackAncient:Evaluate()
	local desire = 0
	
	local nonAAFriendCount = 0
	local allFriends = FindUnitsInRadius( DOTA_TEAM_BADGUYS, thisEntity:GetOrigin(), nil, -1, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_BASIC, 0, 0, false )
	for _,friend in pairs(allFriends) do
		if not friend:IsNull() and friend:IsAlive() and friend:GetUnitName() ~= "npc_dota_creature_ancient_apparition" then
			nonAAFriendCount = nonAAFriendCount + 1
		end
	end

	if nonAAFriendCount < 3 then
		desire = 3
	end

	return desire
end

function BehaviorAttackAncient:Begin()
	self.duration = 5
	local hAncient = Entities:FindByName( nil, "dota_goodguys_fort" )
	self.order =
	{
		OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
		UnitIndex = thisEntity:entindex(),
		Position = hAncient:GetOrigin()
	}
end

BehaviorAttackAncient.Continue = BehaviorAttackAncient.Begin

function BehaviorAttackAncient:Think(dt)
end
