local StartUnloadingEvent = {}
UniversalAutoload.StartUnloadingEvent = StartUnloadingEvent

local StartUnloadingEvent_mt = Class(StartUnloadingEvent, Event)
InitEventClass(StartUnloadingEvent, "StartUnloadingEvent")
-- print("  UniversalAutoload - StartUnloadingEvent")

function StartUnloadingEvent.emptyNew()
	local self = Event.new(StartUnloadingEvent_mt)
	return self
end

function StartUnloadingEvent.new(vehicle, force)
	local self = StartUnloadingEvent.emptyNew()
	self.vehicle = vehicle
	self.force = force or false
	return self
end

function StartUnloadingEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.force = streamReadBool(streamId)
	self:run(connection)
end

function StartUnloadingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.force)
end

function StartUnloadingEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.startUnloading(self.vehicle, self.force, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function StartUnloadingEvent.sendEvent(vehicle, force, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Start Unloading Event")
			g_server:broadcastEvent(StartUnloadingEvent.new(vehicle, force), nil, nil, vehicle)
		else
			--print("client: Start Unloading Event")
			g_client:getServerConnection():sendEvent(StartUnloadingEvent.new(vehicle, force))
		end
	end
end
