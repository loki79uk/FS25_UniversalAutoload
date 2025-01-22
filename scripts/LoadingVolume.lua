LoadingVolume = {
	STATE = {
		ERROR = -1,
		UNDEFINED = 0,
		FOUND_BELTS = 1,
		FOUND_SURFACE = 2,
		EXPANDED = 3,
		SHOP_CONFIG = 4,
		COMPLETE = 5,
	},
	HEIGHT_TOLERANCE = 0.25,
	NORMAL_TOLERANCE = 0.10,
}

local LoadingVolume_mt = Class(LoadingVolume)

function LoadingVolume.new(vehicle)
	assert(vehicle ~= nil, "LoadingVolume: vehicle is required")
	
	local self = {}
	setmetatable(self, LoadingVolume_mt)
	
	self.bbs = {}
	self.debug = {
		raycasts = {},
		points = {},
	}
	self:setNewVehicle(vehicle)
	self.boundingBox = BoundingBox.new(vehicle)
	self.state = LoadingVolume.STATE.UNDEFINED
	
	return self
end


function LoadingVolume:setNewVehicle(vehicle)
	self.vehicle = vehicle
	self.rootNode = vehicle.rootNode
	self.tensionBeltNode = vehicle.spec_tensionBelts and vehicle.spec_tensionBelts.rootNode
	if self.boundingBox then
		self.boundingBox:setObject(vehicle)
	end
	for _, bb in ipairs(self.bbs) do
		bb:setObject(vehicle)
	end
end

function LoadingVolume:getVerticalAxis()
	if self.boundingBox then

		local _, p = self.boundingBox:getCubeFaces()
		local ux, uy, uz, length = LoadingVolume.getNormalisedVector(p[3], p[4])
		
		return {ux, uy, uz}, length
	end
end

function LoadingVolume:clearDebug()
	if #self.debug.raycasts > 0 then
		-- print("CLEARING RAYCASTS")
		for _, r in pairs(self.debug.raycasts) do
			r = nil
		end
		self.debug.raycasts = {}
	end
	if #self.debug.points then
		-- print("CLEARING POINTS")
		for _, p in pairs(self.debug.points) do
			p = nil
		end
		self.debug.points = {}
	end
end

function LoadingVolume:draw(drawAll)
	
	if drawAll then
	
		local spec = self.vehicle.spec_universalAutoload
		if not spec.isInsideShop then
			self:clearDebug()
		end
		
		if self.debug.points then
			for _, p in pairs(self.debug.points) do
				drawDebugPoint(p[1], p[2], p[3], 0, 1, 0, 1, true)
			end
		end
		
		for _, r in pairs(self.debug.raycasts) do
			if r.foundSurface then
				if not r.surfacesIsNormal then
					drawDebugLine(r.x, r.y, r.z, 1, 0, 0, r.x+r.nx, r.y+r.ny, r.z+r.nz, 1, 0, 0)
				end
				drawDebugLine(r.a[1], r.a[2], r.a[3], 0, 1, 0, r.x, r.y, r.z, 0, 1, 0)
				drawDebugLine(r.b[1], r.b[2], r.b[3], 1, 0, 0, r.x, r.y, r.z, 1, 0, 0)
				Utils.renderTextAtWorldPosition(r.x, r.y, r.z, ".", getCorrectTextSize(0.015), 0, {0,1,1})
			else
				drawDebugLine(r.a[1], r.a[2], r.a[3], 1, 0, 0, r.b[1], r.b[2], r.b[3], 1, 0, 0)
			end
			Utils.renderTextAtWorldPosition(r.a[1], r.a[2], r.a[3], ".", getCorrectTextSize(0.0125), 0, {0,1,0})
			Utils.renderTextAtWorldPosition(r.b[1], r.b[2], r.b[3], ".", getCorrectTextSize(0.0125), 0, {1,0,0})
		end
		
		if self.state <= LoadingVolume.STATE.FOUND_SURFACE then
			
			self.boundingBox:draw(1, 1, 1)
			
			local unitVector = self:getVerticalAxis()
			local x, y, z = getTranslation(self.rootNode)
			drawDebugLine(x, y, z, 1, 1, 1, x+unitVector[1], y+unitVector[2], z+unitVector[3], 1, 1, 1)
			
			if self.beltPairs then
				for _, pair in ipairs(self.beltPairs) do
					r, g, b = 1, 1, 1
					a, solid = 1, true
					for _, p in ipairs(pair) do
						drawDebugPoint(p[1], p[2], p[3], r, g, b, a, solid)
					end
					local p1, p2 = pair[1], pair[2]
					drawDebugLine(p1[1], p1[2], p1[3], 1, 0, 0, p2[1], p2[2], p2[3], 1, 0, 0)
				end
			end
		end
	end
	
	if self.bbs then
		for _, bb in ipairs(self.bbs) do
			if bb:isEmpty(0, false) then
				bb:draw(0, 1, 0)
			else
				bb:draw(1, 0, 0)
			end
		end
	end

	if self.state == LoadingVolume.STATE.SHOP_CONFIG then
		
		local shopConfig = UniversalAutoloadManager.shopConfig
		if shopConfig and shopConfig.enableEditing then
	
			local hovered = shopConfig.hovered
			local selected = shopConfig.selected	
			for n, bb in pairs(self.bbs) do
				local centre, points, names = bb:getCubeFaces()
				for i, p in pairs(points or {}) do
					local r, g, b, a, solid = 1, 0, 1, 0.5, false
					if selected and n==selected[1] and i==selected[2] then
						r, g, b = 1, 1, 1
						a, solid = 1, true
					elseif hovered and n==hovered[1] and i==hovered[2] then
						r, g, b = 1, 0.025, 1
						a, solid = 1, true
					end
					
					drawDebugPoint(p[1], p[2], p[3], r, g, b, a, solid)
				end
				
				local size = bb:getSize()
				renderText(0.4, 0.92-(n*0.035), 0.025, string.format("[%d] W, H, L = %.3f, %.3f, %.3f", n, size.x, size.y, size.z))
			end
		end
	end
end

function LoadingVolume.getNormalisedVector(a, b)
	local dx, dy, dz = a[1]-b[1], a[2]-b[2], a[3]-b[3]
	local length = math.sqrt(dx*dx + dy*dy + dz*dz)
	if length == 0 then
		return 0, 0, 0, 0
	end
	return dx/length, dy/length, dz/length, length
end

function LoadingVolume.offsetPoint(point, delta, uv)
	-- Move nodes by delta in the direction of a unit vector
	local x, y, z = point[1] + delta*uv[1], point[2] + delta*uv[2], point[3] + delta*uv[3]
	return {x, y, z}
end

function LoadingVolume.offsetPoints(ax, ay, az, bx, by, bz, delta)
	-- Move pair of points by delta on shared axis 
	local dx, dy, dz, length = LoadingVolume.getNormalisedVector({bx, by, bz}, {ax, ay, az})
	ax, ay, az = ax - delta * dx, ay - delta * dy, az - delta * dz
	bx, by, bz = bx + delta * dx, by + delta * dy, bz + delta * dz
	
	return {ax, ay, az}, {bx, by, bz}
end

function LoadingVolume.offsetNodes(a, b, delta)
	-- Move nodes by delta on shared axis 
	local ax, ay, az = getWorldTranslation(a)
	local bx, by, bz = getWorldTranslation(b)
	return LoadingVolume.offsetPoints(ax, ay, az, bx, by, bz, delta)
end

-- Cast ray from a towards b
function LoadingVolume:findSurface(a, b, showAll)
	
	table.insert(self.debug.points, a)

	local raycastResult = {
		raycastCallback = function (self, hitObjectId, x,y,z, distance, nx,ny,nz, subShapeIndex, shapeId, isLast)
			if hitObjectId == self.target then  --and isLast
				self.foundSurface = true 
				self.x, self.y, self.z = x, y, z
				self.nx, self.ny, self.nz = nx, ny, nz

				local CCT = getCCTCollisionFlags(hitObjectId)
				local mask = getCollisionFilterMask(hitObjectId)
				local group = getCollisionFilterGroup(hitObjectId)
				-- print("--- findSurface ---")
				-- print("CCT: " .. tostring(CCT))
				-- print("mask: " .. tostring(mask))
				-- print("group: " .. tostring(group))
				-- DebugUtil.printTableRecursively(CollisionFlag.getFlagsFromMask(group), "--", 0, 1)
			end
		end
	}

	local dx, dy, dz, length = LoadingVolume.getNormalisedVector(b, a)
	local collisionMask = CollisionFlag.VEHICLE
	
	raycastResult.a = a
	raycastResult.b = b
	raycastResult.foundSurface = nil
	raycastResult.target = self.rootNode
	raycastClosest(a[1], a[2], a[3], dx, dy, dz, length, "raycastCallback", raycastResult, collisionMask) --raycastClosest --raycastAll

	if raycastResult.foundSurface then

		local v1 = {raycastResult.nx, raycastResult.ny, raycastResult.nz}
		local v2 = {a[1]-raycastResult.x, a[2]-raycastResult.y, a[3]-raycastResult.z}
		local cpx, cpy, cpz = MathUtil.crossProduct(v1[1], v1[2], v1[3], v2[1], v2[2], v2[3])
		
		local tolerance = LoadingVolume.NORMAL_TOLERANCE
		local surfacesIsNormal = true
		if math.abs(cpx) > tolerance or math.abs(cpy) > tolerance or math.abs(cpz) > tolerance then
			drawDebugLine(raycastResult.x, raycastResult.y, raycastResult.z, 1, 0, 0, raycastResult.x+raycastResult.nx, raycastResult.y+raycastResult.ny, raycastResult.z+raycastResult.nz, 1, 0, 0)
			surfacesIsNormal = false
		end

		raycastResult.point = {raycastResult.x, raycastResult.y, raycastResult.z}
		raycastResult.surfacesIsNormal = surfacesIsNormal
		
		table.insert(self.debug.raycasts, raycastResult)
		return raycastResult

	else
		-- print("NO SURFACE FOUND")
		if showAll then
			table.insert(self.debug.raycasts, raycastResult)
		end
	end

	return false
end

function LoadingVolume:findTensionBelts()
	
	if self.vehicle.spec_tensionBelts and self.vehicle.spec_tensionBelts.hasTensionBelts then
	
		-- DebugUtil.printTableRecursively(self.vehicle, "--", 0, 1)
	
		local normal = self:getVerticalAxis()

		local hitPairs = {}
		local originalPairs = {}
		for _, belt in pairs(self.vehicle.spec_tensionBelts.sortedBelts) do
			local offsetFromEdge = -0.055
			local rayCastDistance = -1.000 --(negative y == up)
			local s0, e0 = LoadingVolume.offsetNodes(belt.startNode, belt.endNode, offsetFromEdge)
			local s1 = LoadingVolume.offsetPoint(s0, -rayCastDistance/2, normal)
			local s2 = LoadingVolume.offsetPoint(s0, rayCastDistance/2, normal)
			local e1 = LoadingVolume.offsetPoint(e0, -rayCastDistance/2, normal)
			local e2 = LoadingVolume.offsetPoint(e0, rayCastDistance/2, normal)
			local result1 = self:findSurface(s1, s2, true)
			local result2 = self:findSurface(e1, e2, true)
			if result1 and result2 then
				table.insert(hitPairs, {result1.point, result2.point})
			end
			table.insert(originalPairs, {s0, e0})
		end
		
		local candidatePairs = hitPairs
		if #hitPairs < #originalPairs then
			print("USING ORIGNAL PAIRS")
			candidatePairs = originalPairs
		end
		
		local function projectOntoVector(point, uv)
			return point[1] * uv[1] + point[2] * uv[2] + point[3] * uv[3]
		end

		local function isWithinTolerance(value1, value2, tolerance)
			return math.abs(value1 - value2) < tolerance
		end

		local function averageHeight(point1, point2)
			return (point1[2] + point2[2]) / 2
		end

		local tolerance = LoadingVolume.HEIGHT_TOLERANCE
		local used_pairs = {}
		self.beltPairs = {}
		self.beltGroups = {}
		
		for i = 1, #candidatePairs - 1 do
			for j = i + 1, #candidatePairs do
				if not used_pairs[i] and not used_pairs[j] then
					local p1, p2 = candidatePairs[i][1], candidatePairs[i][2]
					local p3, p4 = candidatePairs[j][1], candidatePairs[j][2]

					local h1 = projectOntoVector(p1, normal)
					local h2 = projectOntoVector(p2, normal)
					local h3 = projectOntoVector(p3, normal)
					local h4 = projectOntoVector(p4, normal)

					if isWithinTolerance(h2, h1, tolerance) and isWithinTolerance(h4, h3, tolerance) then
						local avg1 = (h1 + h2) / 2
						local avg2 = (h3 + h4) / 2

						if isWithinTolerance(avg1, avg2, tolerance) then
							local group = {p1, p2, p3, p4}
							local added_pairs = {i, j}

							for k = 1, #candidatePairs do
								if k ~= i and k ~= j and not used_pairs[k] then
									local pp1 = candidatePairs[k][1]
									local pp2 = candidatePairs[k][2]

									local hh1 = projectOntoVector(pp1, normal)
									local hh2 = projectOntoVector(pp2, normal)
									local avg = (hh1 + hh2) / 2

									if isWithinTolerance(avg, avg1, tolerance) then
										table.insert(group, pp1)
										table.insert(group, pp2)
										table.insert(added_pairs, k)
									end
								end
							end

							table.insert(self.beltGroups, group)
							for _, index in pairs(added_pairs) do
								used_pairs[index] = true
								table.insert(self.beltPairs, candidatePairs[index])
							end
						end
					end
				end
			end
		end
		
		if #self.beltGroups == 0 then
			print("NO BELT GORUPS")
			self.state = LoadingVolume.STATE.ERROR
			return
		end
		
		self.state = LoadingVolume.STATE.FOUND_BELTS
	end
end

function LoadingVolume:findLoadingSurface()
	
	self:clearDebug()
	
	for n, group in ipairs(self.beltGroups) do
		--print("GROUP " .. n)
		local points = {}
		local averageY = 0
		local pointCount = 0
		for i, point in ipairs(group) do
			--print("point " .. i .. " = " .. point[2])
			averageY = averageY + point[2]
			pointCount = pointCount + 1
		end
		averageY = averageY/pointCount
		
		for i, point in ipairs(group) do
			point[2] = averageY
			table.insert(points, point)
		end

		local bb = BoundingBox.new(self.rootNode)
		bb:addPoints(points, false)

		if bb:evaluate(LoadingVolume.MIN_SIZE) then
			table.insert(self.bbs, bb)
		end
	end

	self.state = LoadingVolume.STATE.FOUND_SURFACE

end


function LoadingVolume:expandLoadingSurface()

	self:clearDebug()
	local unitVector = self:getVerticalAxis()

	local function testRange(bb, point, direction, maxRange, heightOffset)
		local added = false

		local p1 = LoadingVolume.offsetPoint(point, heightOffset, unitVector)
		local p2 = LoadingVolume.offsetPoint(point, heightOffset, unitVector)
		local p2 = LoadingVolume.offsetPoint(p2, maxRange, direction)

		local result1 = self:findSurface(p1, p2, true)
		
		if result1 and result1.point and result1.foundSurface then
			if result1.surfacesIsNormal then
				bb:addPoint(result1.point, false)
			end
			added = true
		end
		
		return added
	end

	local function expandPoint(bb, point, delta, direction, offset)
		local added = false
		
		local p2 = LoadingVolume.offsetPoint(point, delta, direction) -- source
		local p1 = LoadingVolume.offsetPoint(p2, offset, unitVector) -- target

		local result1 = self:findSurface(p1, p2, true)


		local function projectOntoVector(point, uv)
			return point[1] * uv[1] + point[2] * uv[2] + point[3] * uv[3]
		end

		if result1 and result1.surfacesIsNormal then
			local size = bb:getSize()
			local _, uv, _ = bb:getNormalVectors()
			local h0 = projectOntoVector(point, uv)
			local h1 = projectOntoVector(result1.point, uv)
			if size.y >= 0.01 or h1-h0 > 0.05-size.y then
				bb:addPoint(result1.point, false)
				added = true
			end
		end
		
		return added
	end
	
	local function iterateExpandPoint(bb, point, direction, range, offset)
		local step1 = range/5
		local step2 = step1/5
		local step3 = step2/5

		for i = step1, range, step1 do
			--print(i)
			if not expandPoint(bb, point, i, direction, offset) then
				for j = step2-step1, 0, step2 do
					--print(i+j)
					if not expandPoint(bb, point, i+j, direction, offset) then
						for k = step3-step2, 0, step3 do
							--print(i+j+k)
							if not expandPoint(bb, point, i+j+k, direction, offset) then
								break
							end
						end
						break
					end
				end
				break
			end
		end
	end
	
	local size0 = self.boundingBox:getSize()
	local offset0 = self.boundingBox:getOffset()
	for _, bb in ipairs(self.bbs) do
		local d = 0.1
		local size = bb:getSize()
		local offset = bb:getOffset()
		local w, h, l = size.x, size.y, size.z
		local dx, dy, dz = offset.x, offset.y, offset.z
		local UX, UY, UZ, c = bb:getNormalVectors()
		local uxx, uxy, uxz = UX[1], UX[2], UX[3]
		local uyx, uyy, uyz = UY[1], UY[2], UY[3]
		local uzx, uzy, uzz = UZ[1], UZ[2], UZ[3]
		
		local foundLeft, foundRight, foundTop, foundFront, foundRear = false, false, false, false, false
		
		local x, y, z = getTranslation(self.rootNode)
		local cx, cy, cz = c[1]-x, c[2]-y, c[3]-z
		local sx, sy, sz = size0.x, size0.y, size0.z
		local ox, oy, oz = offset0.x, offset0.y, offset0.z
		
		local d_left   = math.abs(sx/2 - ox + cx)
		local d_right  = math.abs(sx/2 + ox - cx)
		local d_top    = math.abs(sy/2 - oy + cy)
		local d_bot    = math.abs(sy/2 + oy - cy)
		local d_back   = math.abs(sz/2 - oz + cz)
		local d_front  = math.abs(sz/2 + oz - cz)

		foundLeft  = testRange(bb, c, {uxx, uxy, uxz}, d_left, d)
		foundRight = testRange(bb, c, {-uxx, -uxy, -uxz}, d_right, d)
		foundTop   = testRange(bb, c, {uyx, uyy, uyz}, d_top, d)
		foundFront = testRange(bb, c, {uzx, uzy, uzz}, d_front, d)
		foundRear  = testRange(bb, c, {-uzx, -uzy, -uzz}, d_back, d)

		local vertices = BoundingBox.getCubeVertices(bb.rootNode, dx-d*uyx, dy-d*uyy, dz-d*uyz, w/2, h/2, l/2)
		local p1 = vertices[8] -- front left corner
		local p2 = vertices[3] -- rear left corner

		if not foundFront then
			local range = 1 --1.2*(size0.x/2 + (offset0.x - offset.x))
			if not testRange(bb, p1, {uzx, uzy, uzz}, range, size.y+0.2) then
				iterateExpandPoint(bb, p1, {uzx, uzy, uzz}, range, size.y+0.2)
			end
		end
		if not foundRear then
			local range = 1 --1.2*(size0.x/2 - (offset0.x - offset.x))
			if not testRange(bb, p2, {-uzx, -uzy, -uzz}, range, size.y+0.2) then
				iterateExpandPoint(bb, p2, {-uzx, -uzy, -uzz}, range, size.y+0.2)
			end
		end

		if not foundTop then
			print("SET HEIGHT")
			local height = size.x
			local point = LoadingVolume.offsetPoint(c, height, UY)
			bb:addPoint(point, false)
		end
		
		bb:evaluate()
		
		if not bb:isEmpty() then
			print("TRY TO RAISE BASE")
			bb:adjustBoundingBox(offset.y, 0.5, 1, function(original, value) offset.y = original + value end)
			original_dy = offset.y
		end

	end
	
	self.state = LoadingVolume.STATE.EXPANDED
end


function LoadingVolume:initShopConfig()

	self:clearDebug()
	
	UniversalAutoloadManager.shopConfig = {}
	UniversalAutoloadManager.shopConfig.loadingVolume = self
	
	self.state = LoadingVolume.STATE.SHOP_CONFIG
	
end