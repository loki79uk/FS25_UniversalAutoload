local RaiseActiveEvent = {}
UniversalAutoload.RaiseActiveEvent = RaiseActiveEvent

local RaiseActiveEvent_mt = Class(RaiseActiveEvent, Event)
InitEventClass(RaiseActiveEvent, "RaiseActiveEvent")
-- print("  UniversalAutoload - RaiseActiveEvent")

function RaiseActiveEvent.emptyNew()
	local self = Event.new(RaiseActiveEvent_mt)
	return self
end

function RaiseActiveEvent.new(vehicle, state)
	local self = RaiseActiveEvent.emptyNew()
	self.vehicle = vehicle
	self.state = state
	return self
end

function RaiseActiveEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	if streamReadBool(streamId) then
		self.state = streamReadBool(streamId)
	end
	self:run(connection)
end

function RaiseActiveEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	if self.state ~= nil then
		streamWriteBool(streamId, true)
		streamWriteBool(streamId, self.state)
	else
		streamWriteBool(streamId, false)
	end
end

function RaiseActiveEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		--print("RAISE ACTIVE "..tostring(self.inTrigger))
		UniversalAutoload.forceRaiseActive(self.vehicle, self.state, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function RaiseActiveEvent.sendEvent(vehicle, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Raise Active Event")
			g_server:broadcastEvent(RaiseActiveEvent.new(vehicle, state), nil, nil, vehicle)
		else
			--print("client: Raise Active Event")
			g_client:getServerConnection():sendEvent(RaiseActiveEvent.new(vehicle, state))
		end
	end
end
