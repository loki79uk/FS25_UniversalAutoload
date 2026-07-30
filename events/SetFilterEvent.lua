local SetFilterEvent = {}
UniversalAutoload.SetFilterEvent = SetFilterEvent

local SetFilterEvent_mt = Class(SetFilterEvent, Event)
InitEventClass(SetFilterEvent, "SetFilterEvent")
-- print("  UniversalAutoload - SetFilterEvent")

function SetFilterEvent.emptyNew()
	local self = Event.new(SetFilterEvent_mt)
	return self
end

function SetFilterEvent.new(vehicle, state)
	local self = SetFilterEvent.emptyNew()
	self.vehicle = vehicle
	self.state = state
	return self
end

function SetFilterEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadBool(streamId)
	self:run(connection)
end

function SetFilterEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.state)
end

function SetFilterEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.setLoadingFilter(self.vehicle, self.state, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function SetFilterEvent.sendEvent(vehicle, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Set state Event")
			g_server:broadcastEvent(SetFilterEvent.new(vehicle, state), nil, nil, vehicle)
		else
			--print("client: Set state Event")
			g_client:getServerConnection():sendEvent(SetFilterEvent.new(vehicle, state))
		end
	end
end
