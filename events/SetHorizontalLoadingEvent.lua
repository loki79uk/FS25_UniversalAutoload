local SetHorizontalLoadingEvent = {}
UniversalAutoload.SetHorizontalLoadingEvent = SetHorizontalLoadingEvent

local SetHorizontalLoadingEvent_mt = Class(SetHorizontalLoadingEvent, Event)
InitEventClass(SetHorizontalLoadingEvent, "SetHorizontalLoadingEvent")
-- print("  UniversalAutoload - SetHorizontalLoadingEvent")

function SetHorizontalLoadingEvent.emptyNew()
	local self = Event.new(SetHorizontalLoadingEvent_mt)
	return self
end

function SetHorizontalLoadingEvent.new(vehicle, state)
	local self = SetHorizontalLoadingEvent.emptyNew()
	self.vehicle = vehicle
	self.state = state
	return self
end

function SetHorizontalLoadingEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadBool(streamId)
	self:run(connection)
end

function SetHorizontalLoadingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.state)
end

function SetHorizontalLoadingEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.setHorizontalLoading(self.vehicle, self.state, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function SetHorizontalLoadingEvent.sendEvent(vehicle, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Set state Event")
			g_server:broadcastEvent(SetHorizontalLoadingEvent.new(vehicle, state), nil, nil, vehicle)
		else
			--print("client: Set state Event")
			g_client:getServerConnection():sendEvent(SetHorizontalLoadingEvent.new(vehicle, state))
		end
	end
end
