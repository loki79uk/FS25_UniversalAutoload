
-- Point Class
local Point = {}
Point.__index = Point

function Point:new(x, y, z)
	return setmetatable({x = x, y = y, z = z}, Point)
end

-- Simple Box Class
local Box = {}
Box.__index = Box

function Box:new(size, offset)
	-- Initialize the 3D box with min and max points
	local self = {
		_size = size or {x=0, y=0, z=0},
		_offset = offset or {x=0, y=0, z=0},
	}
	setmetatable(self, Box)
	return self
end

function Box:getSize()
	return self._size
end

function Box:getOffset()
	return self._offset
end

function Box:draw(rootNode, r, g, b)
	
	if not rootNode then
		print("ERROR: rootNode is required to draw box")
		return
	end
	local size = self:getSize()
	local offset = self:getOffset()
	DebugUtil.drawDebugCube(rootNode, size.x, size.y, size.z, r or 1, b or 1, g or 1, offset.x, offset.y, offset.z)
	
end


-- BoundingBox Class
BoundingBox = {}

local BoundingBox_mt = Class(BoundingBox)

function BoundingBox.new(object, size, offset)
	local self = {}
	setmetatable(self, BoundingBox_mt)
	self.box = Box:new(size, offset)
	self.limits = {
		min_x = (size and size.x and -size.x/2) or math.huge,
		min_y = (size and size.y and -size.y/2) or math.huge,
		min_z = (size and size.z and -size.z/2) or math.huge,
		max_x = (size and size.x and size.x/2) or -math.huge,
		max_y = (size and size.y and size.y/2) or -math.huge,
		max_z = (size and size.z and size.z/2) or -math.huge,
	}
	self.debug = {
		wheels = {},
		raycasts = {},
		components = {},
	}
	
	if object then
		if type(object)=="number" and entityExists(object) then
			self.rootNode = object
		elseif type(object)=="table" then
			self:addObject(object)
		end
	end
	return self
end

function BoundingBox:getBox()
	return self.box
end

function BoundingBox:getSize()
	return self.box:getSize()
end

function BoundingBox:getOffset()
	return self.box:getOffset()
end

function BoundingBox:getRootNode()
	return self.rootNode
end

function BoundingBox:setObject(object)
	self.object = object
	if object then
		self.rootNode = object.rootNode or object.nodeId
	end
end

function BoundingBox:resetLimits()
	self.limits = {
		min_x = math.huge,
		min_y = math.huge,
		min_z = math.huge,
		max_x = -math.huge,
		max_y = -math.huge,
		max_z = -math.huge,
	}
end

function BoundingBox:update()
	self:getCubeFaces(true)
	self:isEmpty(0)
end

function BoundingBox:isEmpty(delta, drawAll)
	
	local rootNode = self:getRootNode()
	if rootNode == nil or not entityExists(rootNode) then
		print("rootNode unknown:  " .. tostring(rootNode))
		return
	end
	
	local callbackTarget = {
		rootNode = rootNode,
		isVolumeEmpty = true,
	}

	function callbackTarget.testLocationOverlap_Callback(target, nodeId, subShapeIndex)
		if subShapeIndex ~= -1 then
			-- print("nodeId: " .. tostring(nodeId))
			-- print("subShapeIndex: " .. tostring(subShapeIndex))
			local rigidBodyType = getRigidBodyType(nodeId)
			if rigidBodyType == RigidBodyType.DYNAMIC then
				-- print("rigidBodyType DYNAMIC")
			elseif rigidBodyType == RigidBodyType.KINEMATIC then
				-- print("rigidBodyType KINEMATIC")
			end
		end
				
		if nodeId ~= 0 and getHasClassId(nodeId, ClassIds.SHAPE) then
			if nodeId == target.rootNode then

				local CCT = getCCTCollisionFlags(nodeId)
				local mask = getCollisionFilterMask(nodeId)
				local group = getCollisionFilterGroup(nodeId)

				local trigger = CollisionFlag.TRIGGER
				local collision = CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.TREE + CollisionFlag.PLAYER
				if group and bitAND(collision, group) > 0 and bitAND(trigger, group) == 0 then
					target.isVolumeEmpty = false
					-- DebugUtil.printTableRecursively(CollisionFlag.getFlagsFromMask(group), "--", 0, 1)
					-- DebugUtil.drawDebugNode(nodeId, getName(nodeId))
					
					-- if mask ~= 4265606019 or group ~= 65540 then
						-- print("CCT: " .. tostring(CCT))
						-- print("mask: " .. tostring(mask))
						-- print("group: " .. tostring(group))
					-- end
				else
					-- print("--- testLocationOverlap - EMPTY ---")
				end
			else
				local object = g_currentMission:getNodeObject(nodeId)
				if object ~= nil then
					-- print("--- testLocationOverlap - OTHER ---")
					-- DebugUtil.drawDebugNode(nodeId, getName(nodeId))
					target.isVolumeEmpty = false
				end
			end

		end
	end

	local d = delta or 0
	local size = self:getSize()
	local offset = self:getOffset()
	local sizeX, sizeY, sizeZ = size.x/2 - d, size.y/2, size.z/2 - d
	local x, y, z = localToWorld(rootNode, 0, 0, 0)
	local rx, ry, rz = getWorldRotation(rootNode)
	local dx, dy, dz = localDirectionToWorld(rootNode, offset.x, offset.y, offset.z)
	
	--DebugUtil.drawDebugCube(rootNode, size.x, size.y, size.z, r or 1, b or 1, g or 1, offset.x, offset.y, offset.z)

	local collisionMask = CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.TREE + CollisionFlag.PLAYER
	
	overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "testLocationOverlap_Callback", callbackTarget, collisionMask, true, true, true, true)

	if drawAll then
		local node, w, h, l, showCube, showAxis = rootNode, size.x, size.y, size.z, true, true
		
		if node ~= nil and node ~= 0 and entityExists(node) then
			
			DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
	
			-- colour for square
			local colour = callbackTarget.isVolumeEmpty and {0, 1, 0} or {1, 0, 0}
			
			local r, g, b = unpack(colour)
			local w, h, l = (w or 1), (h or 1), (l or 1)
			local dx, dy, dz = offset.x, offset.y, offset.z

			local xx,xy,xz = localDirectionToWorld(node, w,0,0)
			local yx,yy,yz = localDirectionToWorld(node, 0,h,0)
			local zx,zy,zz = localDirectionToWorld(node, 0,0,l)
			
			local x0,y0,z0 = localToWorld(node, -w/2+dx, -h/2+dy, -l/2+dz)
			drawDebugLine(x0,y0,z0,r,g,b,x0+xx,y0+xy,z0+xz,r,g,b)
			drawDebugLine(x0,y0,z0,r,g,b,x0+zx,y0+zy,z0+zz,r,g,b)
			drawDebugLine(x0+xx,y0+xy,z0+xz,r,g,b,x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b)
			drawDebugLine(x0+zx,y0+zy,z0+zz,r,g,b,x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b)

			if showCube then			
				local x1,y1,z1 = localToWorld(node, -w/2+dx, h/2+dy, -l/2+dz)
				drawDebugLine(x1,y1,z1,r,g,b,x1+xx,y1+xy,z1+xz,r,g,b)
				drawDebugLine(x1,y1,z1,r,g,b,x1+zx,y1+zy,z1+zz,r,g,b)
				drawDebugLine(x1+xx,y1+xy,z1+xz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
				drawDebugLine(x1+zx,y1+zy,z1+zz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
				
				drawDebugLine(x0,y0,z0,r,g,b,x1,y1,z1,r,g,b)
				drawDebugLine(x0+zx,y0+zy,z0+zz,r,g,b,x1+zx,y1+zy,z1+zz,r,g,b)
				drawDebugLine(x0+xx,y0+xy,z0+xz,r,g,b,x1+xx,y1+xy,z1+xz,r,g,b)
				drawDebugLine(x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
			end
			
			if showAxis then
				local x,y,z = localToWorld(node, dx, dy, dz)
				Utils.renderTextAtWorldPosition(x-xx/2,y-xy/2,z-xz/2, "-x", getCorrectTextSize(0.012), 0)
				Utils.renderTextAtWorldPosition(x+xx/2,y+xy/2,z+xz/2, "+x", getCorrectTextSize(0.012), 0)
				Utils.renderTextAtWorldPosition(x-yx/2,y-yy/2,z-yz/2, "-y", getCorrectTextSize(0.012), 0)
				Utils.renderTextAtWorldPosition(x+yx/2,y+yy/2,z+yz/2, "+y", getCorrectTextSize(0.012), 0)
				Utils.renderTextAtWorldPosition(x-zx/2,y-zy/2,z-zz/2, "-z", getCorrectTextSize(0.012), 0)
				Utils.renderTextAtWorldPosition(x+zx/2,y+zy/2,z+zz/2, "+z", getCorrectTextSize(0.012), 0)
				drawDebugLine(x-xx/2,y-xy/2,z-xz/2,1,1,1,x+xx/2,y+xy/2,z+xz/2,1,1,1)
				drawDebugLine(x-yx/2,y-yy/2,z-yz/2,1,1,1,x+yx/2,y+yy/2,z+yz/2,1,1,1)
				drawDebugLine(x-zx/2,y-zy/2,z-zz/2,1,1,1,x+zx/2,y+zy/2,z+zz/2,1,1,1)
			end
		end
	end

	return callbackTarget.isVolumeEmpty
end

function BoundingBox:addPoint(p, doEvaluate)
	local limits = self.limits
	local rootNode = self:getRootNode()
	local x0, y0, z0 = worldToLocal(rootNode, p[1], p[2], p[3])
	limits.min_x = math.min(limits.min_x, x0)
	limits.min_y = math.min(limits.min_y, y0)
	limits.min_z = math.min(limits.min_z, z0)
	limits.max_x = math.max(limits.max_x, x0)
	limits.max_y = math.max(limits.max_y, y0)
	limits.max_z = math.max(limits.max_z, z0)
	
	if doEvaluate ~= false then
		self:evaluate()
	end
end

function BoundingBox:addPoints(points, doEvaluate)
	for _, p in pairs(points) do
		self:addPoint(p, false)
	end
		
	if doEvaluate ~= false then
		self:evaluate()
	end
end

function BoundingBox:evaluate(minSize)
	if self.limits.min_x ~= math.huge and self.limits.max_x ~= -math.huge then
		local minSize = minSize or 0
		local size = self:getSize()
		local offset = self:getOffset()
		size.x = math.max(math.abs(self.limits.max_x - self.limits.min_x), minSize)
		size.y = math.max(math.abs(self.limits.max_y - self.limits.min_y), minSize)
		size.z = math.max(math.abs(self.limits.max_z - self.limits.min_z), minSize)
		offset.x = (self.limits.min_x + self.limits.max_x) / 2
		offset.y = (self.limits.min_y + self.limits.max_y) / 2
		offset.z = (self.limits.min_z + self.limits.max_z) / 2
		offset.x = math.abs(offset.x) > UniversalAutoload.DELTA and offset.x or 0
		offset.y = math.abs(offset.y) > UniversalAutoload.DELTA and offset.y or 0
		offset.z = math.abs(offset.z) > UniversalAutoload.DELTA and offset.z or 0
		return true
	end
end

function BoundingBox:draw(r, g, b, drawComponents)
	
	local rootNode = self:getRootNode()
	if not rootNode or not entityExists(rootNode) then
		return
	end
	
	if drawComponents then

		if self.debug then
			for _, bb in pairs(self.debug.components) do
				bb:draw(0, 0, 1, true)
			end
			for _, wheel in pairs(self.debug.wheels) do
				DebugUtil.drawDebugCube(wheel.node, wheel.w, wheel.h, wheel.l, 0, 0, 1, wheel.dx, wheel.dy, wheel.dz)
			end
			for _, r in pairs(self.debug.raycasts) do
				if not r.surfacesIsNormal then
					drawDebugLine(r.x, r.y, r.z, 1, 0, 0, r.x+r.nx, r.y+r.ny, r.z+r.nz, 1, 0, 0)
				end

				drawDebugLine(r.c[1], r.c[2], r.c[3], 0, 1, 0, r.x, r.y, r.z, 0, 1, 0)
				drawDebugLine(r.p[1], r.p[2], r.p[3], 0, 0, 1, r.x, r.y, r.z, 0, 0, 1)
				Utils.renderTextAtWorldPosition(r.x, r.y, r.z, "*", getCorrectTextSize(0.015), 0, {0,0,1})
				Utils.renderTextAtWorldPosition(r.p[1], r.p[2], r.p[3], "*", getCorrectTextSize(0.0125), 0, {0,0,1})
			end
		end
	end

	if not (r==0 and b==0 and g==0) then
		local size = self:getSize()
		local offset = self:getOffset()
		DebugUtil.drawDebugCube(rootNode, size.x, size.y, size.z, r or 1, b or 1, g or 1, offset.x, offset.y, offset.z)
	end
	
end

-- Function to add a new object to the bounding box
function BoundingBox:addObject(object)

	if self.object == nil then
		self:setObject(object)
	end

	local rootNode = self:getRootNode()
	if rootNode == nil or not entityExists(rootNode) then
		return
	end

	self:addWheels()
	self:addComponents()
	self:evaluate()
	
end

function BoundingBox:addWheels(object, doEvaluate)

	if self.object == nil then
		self:setObject(object)
	end

	local rootNode = self:getRootNode()
	if rootNode == nil or not entityExists(rootNode) then
		return
	end
	
	if self.object.spec_wheels then

		for i, wheel in pairs(self.object.spec_wheels.wheels) do
			if entityExists(wheel.node) then
				-- print("WHEEL " .. i)
				-- DebugUtil.printTableRecursively(wheel, "--", 0, 1)
				local w = wheel.physics
				local debugWheel = {
					node = wheel.node,
					w = w.width,
					h = 2*w.radius,
					l = 2*w.radius,
					dx = w.positionX,
					dy = w.positionY,
					dz = w.positionZ,
				}
				table.insert(self.debug.wheels, debugWheel)
			
				DebugUtil.drawDebugCube(debugWheel.node, debugWheel.w, debugWheel.h, debugWheel.l, 0, 0, 1, debugWheel.dx, debugWheel.dy, debugWheel.dz)

				local vertices = BoundingBox.getCubeVertices(wheel.node, w.positionX, w.positionY, w.positionZ, w.width/2, w.radius, w.radius)
				self:addVertices(vertices)
			end
		end
		
		if doEvaluate ~= false then
			self:evaluate()
		end
	end
end

function BoundingBox:addComponents(object, doEvaluate)

	local object = object or self.object
	
	local nodes = {}
	if object.components ~= nil then
		for i = 1, #object.components do
			table.insert(nodes, object.components[i].node)
		end
	else
		table.insert(nodes, object.nodeId)
	end
	
	for i, componentNode in ipairs(nodes) do

		-- bounding box for this COMPONENT
		local bb = BoundingBox.new(componentNode)
		
		local function findCollisions(node, func, N)
			if node == nil or not entityExists(node) then return end
			
			local CCT = getCCTCollisionFlags(node)
			local mask = getCollisionFilterMask(node)
			local group = getCollisionFilterGroup(node)
			if group and mask and mask > 0 then
				-- print("--- findCollisions ---")
				-- print("CCT: " .. tostring(CCT))
				-- print("mask: " .. tostring(mask))
				-- print("group: " .. tostring(group))
			end
			
			local isShape = getHasClassId(node, ClassIds.SHAPE)
			local trigger = CollisionFlag.TRIGGER
			local collision = CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.TREE
			if isShape and group and bitAND(collision, group) > 0 and bitAND(trigger, group) == 0 then
				func(node, N)
			end
			for i = 0, getNumOfChildren(node) - 1 do
				local child = getChildAt(node, i)
				findCollisions(child, func)
			end
		end
			
		local function findCollisionsForNode(node, N)
			local sx, sy, sz, r = getShapeBoundingSphere(node)
			local vertices, origin = BoundingBox.getCubeVertices(node, sx, sy, sz, 1.1*r)
			bb:addVertices(vertices, node, origin, N)
		end
		
		findCollisions(componentNode, findCollisionsForNode)
		
		if bb:evaluate() then

			local size = bb:getSize()
			local offset = bb:getOffset()
		
			-- DebugUtil.drawDebugCube(componentNode, size.x, size.y, size.z, 0, 1, 0, offset.x, offset.y, offset.z)
			
			local vertices = BoundingBox.getCubeVertices(componentNode, offset.x, offset.y, offset.z, size.x/2, size.y/2, size.z/2)
			if self:addVertices(vertices) then
				table.insert(self.debug.components, bb)
			end
		end
	end
	
	if doEvaluate ~= false then
		self:evaluate()
	end
end

function BoundingBox:addVertices(vertices, node, centre, N)

	local function raycastPoints(node, centre, points)

		local c = centre
		local pointAdded = false
		local surfacesIsNormal = true
		for _, p in pairs(points) do
		
			local raycastResult = {
				raycastCallback = function (self, hitObjectId, x,y,z, distance, nx,ny,nz, subShapeIndex, shapeId, isLast)
					if shapeId == self.target then
						self.shapeId = shapeId
						self.x, self.y, self.z = x, y, z
						self.nx, self.ny, self.nz = nx, ny, nz
					end
				end,
				target = 0
			}
			
			local d = 0.1
			local collisionMask = CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.TREE
			local dx, dy, dz = c[1]-p[1], c[2]-p[2], c[3]-p[3]
			local length = MathUtil.vector3Length(dx, dy, dz) + d
			dx, dy, dz = BoundingBox.vector3Normalize(dx, dy, dz)
			
			raycastResult.target = node
			raycastResult.shapeId = false
			raycastAll(p[1]-d*dx, p[2]-d*dy, p[3]-d*dz, dx, dy, dz, length, "raycastCallback", raycastResult, collisionMask)

			if raycastResult.shapeId == node then
			
				if #points == 1 then
					local tolerance = 0.1
					local v1 = {raycastResult.nx, raycastResult.ny, raycastResult.nz}
					local v2 = {c[1]-raycastResult.x, c[2]-raycastResult.y, c[3]-raycastResult.z}
					local cpx, cpy, cpz = MathUtil.crossProduct(v1[1], v1[2], v1[3], v2[1], v2[2], v2[3])
					if math.abs(cpx) > tolerance or math.abs(cpy) > tolerance or math.abs(cpz) > tolerance then
						surfacesIsNormal = false
						raycastResult.surfacesIsNormal = false
					else
						raycastResult.surfacesIsNormal = true
					end
				end

				raycastResult.c = c
				raycastResult.p = p
				self:addPoint({raycastResult.x, raycastResult.y, raycastResult.z})
				table.insert(self.debug.raycasts, raycastResult)
				pointAdded = true
			end
		end
		return pointAdded, surfacesIsNormal
	end

	local v = vertices
	local anyPointsAdded = false
	local allNodePointsInsideBB = true
	
	-- Calculate and store the points on each face
	local cornerPointGroup = {
		{v[1], v[2], v[3], v[4]},
		{v[5], v[6], v[7], v[8]},
		{v[1], v[2], v[5], v[6]},
		{v[3], v[4], v[7], v[8]},
		{v[1], v[3], v[5], v[7]},
		{v[2], v[4], v[6], v[8]},
	}
	local rootNode = self:getRootNode()
	for _, cornerPoints in pairs(cornerPointGroup) do
		points = BoundingBox.getPointsOnFace(cornerPoints, N)
		
		if node then
			local allFacePointsInsideBB = true
			for _, p in pairs(points) do
				local x0, y0, z0 = worldToLocal(rootNode, p[1], p[2], p[3])
				if x0 < self.limits.min_x or x0 > self.limits.max_x or
				   y0 < self.limits.min_y or y0 > self.limits.max_y or
				   z0 < self.limits.min_z or z0 > self.limits.max_z then
					allFacePointsInsideBB = false
					allNodePointsInsideBB = false
				end
			end
			if not allFacePointsInsideBB then
				local pointAdded, surfacesIsNormal = raycastPoints(node, centre, points)
				anyPointsAdded = anyPointsAdded and pointAdded
				if surfacesIsNormal == false then
					points = BoundingBox.getPointsOnFace(cornerPoints, 2)
					local pointAdded, surfacesIsNormal = raycastPoints(node, centre, points)
					anyPointsAdded = anyPointsAdded and pointAdded
				end
			end
		else
			self:addPoints(points)
			anyPointsAdded = true
		end
	end
	return anyPointsAdded
end

function BoundingBox.drawCube(v, r, g, b)
	-- Define the edges of the cube
	local edges = {
		{v[1], v[2]}, -- Edge 1
		{v[3], v[4]}, -- Edge 2
		{v[1], v[3]}, -- Edge 3
		{v[2], v[4]}, -- Edge 4
		{v[5], v[6]}, -- Edge 5
		{v[7], v[8]}, -- Edge 6
		{v[5], v[7]}, -- Edge 7
		{v[6], v[8]}, -- Edge 8
		{v[1], v[5]}, -- Edge 9
		{v[2], v[6]}, -- Edge 10
		{v[3], v[7]}, -- Edge 11
		{v[4], v[8]}, -- Edge 12
	}
	-- Draw the rest of the owl
	for i, e in ipairs(edges) do
		local x = (e[1][1] + e[2][1]) / 2
		local y = (e[1][2] + e[2][2]) / 2
		local z = (e[1][3] + e[2][3]) / 2
		drawDebugLine(e[1][1], e[1][2], e[1][3], r, g, b, e[2][1], e[2][2], e[2][3], r, g, b)
		-- Utils.renderTextAtWorldPosition(x, y, z, "-"..i.."-", getCorrectTextSize(0.0125), 0, {1,1,0})
	end
end

function BoundingBox.drawFace(v, r, g, b)
	-- Define the edges of the cube
	local edges = {
		{v[1], v[2]}, -- Edge 1
		{v[3], v[4]}, -- Edge 2
		{v[1], v[3]}, -- Edge 3
		{v[2], v[4]}, -- Edge 4
	}
	-- Draw the rest of the owl
	for i, e in ipairs(edges) do
		local x = (e[1][1] + e[2][1]) / 2
		local y = (e[1][2] + e[2][2]) / 2
		local z = (e[1][3] + e[2][3]) / 2
		drawDebugLine(e[1][1], e[1][2], e[1][3], r, g, b, e[2][1], e[2][2], e[2][3], r, g, b)
		-- Utils.renderTextAtWorldPosition(x, y, z, "-"..i.."-", getCorrectTextSize(0.0125), 0, {1,1,0})
	end
end


-- Function to calculate points on a face using the vertices and face definition
function BoundingBox.getPointsOnFace(v, N)
	local points = {}
	local origin = v[1]
	local u = {v[2][1] - v[1][1], v[2][2] - v[1][2], v[2][3] - v[1][3]}
	local v = {v[3][1] - v[1][1], v[3][2] - v[1][2], v[3][3] - v[1][3]}
	
	if N == nil or N == 1 then
		-- Only one point created in the centre
		local x = origin[1] + (u[1]/2) + (v[1]/2)
		local y = origin[2] + (u[2]/2) + (v[2]/2)
		local z = origin[3] + (u[3]/2) + (v[3]/2)
		table.insert(points, {x, y, z})
	elseif N == 2 then
		-- Points created halfway towards each corner
		for i = 1, 4 do
			local sign1 = (i == 1 or i == 4) and 1 or -1
			local sign2 = (i == 1 or i == 2) and 1 or -1
			local corner_x = origin[1] + (u[1]/2) + (v[1]/2) + sign1 * (u[1]/4) + sign2 * (v[1]/4)
			local corner_y = origin[2] + (u[2]/2) + (v[2]/2) + sign1 * (u[2]/4) + sign2 * (v[2]/4)
			local corner_z = origin[3] + (u[3]/2) + (v[3]/2) + sign1 * (u[3]/4) + sign2 * (v[3]/4)
			table.insert(points, {corner_x, corner_y, corner_z})
		end
	else
		-- Evenly distributed points over the face
		for i = 0, N-1 do
			local I = (2*i+1)/(2*N)
			for j = 0, N-1 do
				local J = (2*j+1)/(2*N)
				local x = origin[1] + (u[1]*I) + (v[1]*J)
				local y = origin[2] + (u[2]*I) + (v[2]*J)
				local z = origin[3] + (u[3]*I) + (v[3]*J)
				table.insert(points, {x, y, z})
			end
		end
	end

	return points
end

-- Function to calculate corner points of a shape
function BoundingBox.getCubeVertices(node, sx, sy, sz, rx, ry, rz)

	local x, y, z = localToWorld(node, sx, sy, sz)
	local xx, xy, xz = localDirectionToWorld(node, rx, 0, 0)
	local yx, yy, yz = localDirectionToWorld(node, 0, ry or rx, 0)
	local zx, zy, zz = localDirectionToWorld(node, 0, 0, rz or rx)
	
	-- Define the vertices of the cube
	local vertices = {
		{x - xx - yx - zx, y - xy - yy - zy, z - xz - yz - zz},
		{x - xx - yx + zx, y - xy - yy + zy, z - xz - yz + zz},
		{x - xx + yx - zx, y - xy + yy - zy, z - xz + yz - zz},
		{x - xx + yx + zx, y - xy + yy + zy, z - xz + yz + zz},
		{x + xx - yx - zx, y + xy - yy - zy, z + xz - yz - zz},
		{x + xx - yx + zx, y + xy - yy + zy, z + xz - yz + zz},
		{x + xx + yx - zx, y + xy + yy - zy, z + xz + yz - zz},
		{x + xx + yx + zx, y + xy + yy + zy, z + xz + yz + zz},
	}
	
	return vertices, {x, y, z}
end

function BoundingBox.getNormalisedVector(a, b)
	local dx, dy, dz = a[1]-b[1], a[2]-b[2], a[3]-b[3]
	return BoundingBox.vector3Normalize(dx, dy, dz)
end

function BoundingBox.vector3Normalize(dx, dy, dz)
	local length = math.sqrt(dx*dx + dy*dy + dz*dz)
	if length == 0 then
		return 0, 0, 0, 0
	end
	return dx/length, dy/length, dz/length, length
end

function BoundingBox:getWorldPosition()
	
	local rootNode = self:getRootNode()
	if rootNode then
		local s = self:getOffset()
		local x, y, z = localToWorld(rootNode, s.x, s.y, s.z)
	
		return {x, y, z}
	end
end

function BoundingBox:getNormalVectors()
	
	local rootNode = self:getRootNode()
	if rootNode then
		local size = self:getSize()
		local offset = self:getOffset()
		
		local sx, sy, sz = offset.x, offset.y, offset.z
		local x, y, z = localToWorld(rootNode, sx, sy, sz)
		
		local rx, ry, rz = size.x, size.y, size.z
		local xx, xy, xz = localDirectionToWorld(rootNode, rx, 0, 0)
		local yx, yy, yz = localDirectionToWorld(rootNode, 0, ry, 0)
		local zx, zy, zz = localDirectionToWorld(rootNode, 0, 0, rz)
		
		local uxx, uxy, uxz = BoundingBox.vector3Normalize(xx, xy, xz)
		local uyx, uyy, uyz = BoundingBox.vector3Normalize(yx, yy, yz)
		local uzx, uzy, uzz = BoundingBox.vector3Normalize(zx, zy, zz)
	
		return {uxx, uxy, uxz}, {uyx, uyy, uyz}, {uzx, uzy, uzz}, {x, y, z}
	end
end

function BoundingBox:getCubeFaces(doUpdate)
	
	local rootNode = self:getRootNode()
	if rootNode then
		if doUpdate or not self.centre then
			local size = self:getSize()
			local offset = self:getOffset()
			local sx, sy, sz = offset.x, offset.y, offset.z
			local rx, ry, rz = size.x/2, size.y/2, size.z/2
		
			local x, y, z = localToWorld(rootNode, sx, sy, sz)
			local xx, xy, xz = localDirectionToWorld(rootNode, rx, 0, 0)
			local yx, yy, yz = localDirectionToWorld(rootNode, 0, ry, 0)
			local zx, zy, zz = localDirectionToWorld(rootNode, 0, 0, rz)
			-- Define the faces of the cube
			self.points = {
				{ x + xx, y + xy, z + xz }, --left
				{ x - xx, y - xy, z - xz }, --right
				{ x + yx, y + yy, z + yz }, --top
				{ x - yx, y - yy, z - yz }, --bottom
				{ x + zx, y + zy, z + zz }, --front
				{ x - zx, y - zy, z - zz }, --back
			}
			self.names = {
				"L", --left
				"R", --right
				"T", --top
				"B", --bottom
				"F", --front
				"A", --back
			}
			self.centre = {x, y, z}
		end
		
		return self.centre, self.points, self.names
	else
		-- print("NO ROOT NODE..")
	end
end

function BoundingBox:drawCubeFaces()

	local rootNode = self:getRootNode()
	if rootNode then
		local centre, points, names = self:getCubeFaces()
		local i = 0
		for _, p in pairs(points) do
			i = i + 1
			drawDebugLine(centre[1], centre[2], centre[3], 0, 1, 0, p[1], p[2], p[3], 0, 1, 0)
			Utils.renderTextAtWorldPosition(p[1], p[2], p[3], "["..names[i].."]", getCorrectTextSize(0.0125), 0, {1,1,0})
		end
	end
end

function BoundingBox:moveFace(pointIndex, delta)

	local axisLookup = {
		"x", --left
		"x", --right
		"y", --top
		"y", --bottom
		"z", --front
		"z", --back
	}

	local delta = delta or 0
	local axis = axisLookup[pointIndex]
	local sign = (pointIndex % 2 == 0) and -1 or 1
	local size = self:getSize()
	local offset = self:getOffset()
	
	if sign*delta > 0 or size[axis] + sign*delta > 0.25 then
		
		size[axis] = size[axis] + sign*delta
		offset[axis] = offset[axis] + delta/2
		
		local rootNode = self:getRootNode()
		local sx, sy, sz = offset.x, offset.y, offset.z
		local x, y, z = localToWorld(rootNode, sx, sy, sz)
		self.centre = {x, y, z}

		if self.points then
			local pointLookup = {
				x = 1,
				y = 2,
				z = 3,
			}
			local axisIndex = pointLookup[axis]
			self.points[pointIndex][axisIndex] = self.points[pointIndex][axisIndex] + delta

			local shiftLookup = {
				x = {3,4,5,6},
				y = {1,2,5,6},
				z = {1,2,3,4},
			}
			local otherPointIndexes = shiftLookup[axis]
			for _, otherPointIndex in pairs(otherPointIndexes) do
				self.points[otherPointIndex][axisIndex] = self.points[otherPointIndex][axisIndex] + delta/2
			end
		end
	end
end

function BoundingBox:adjustBoundingBox(original, range, sign, updateFn, delta, sigma)
	local delta = delta or 0.005
	local sigma = sigma or 0.001
	for i = 1, range/delta do
		local value = sign*i*delta
		-- print(value)
		updateFn(original, value)
		if self:isEmpty() then
			updateFn(original, value - sigma)
			-- print(" ADJUSTED BY " .. value - sigma)
			break
		else
			updateFn(original, 0)
		end
	end
end