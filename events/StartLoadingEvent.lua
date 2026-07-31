local StartLoadingEvent = {}
UniversalAutoload.StartLoadingEvent = StartLoadingEvent

local StartLoadingEvent_mt = Class(StartLoadingEvent, Event)
InitEventClass(StartLoadingEvent, "StartLoadingEvent")
-- print("  UniversalAutoload - StartLoadingEvent")

function StartLoadingEvent.emptyNew()
	local self = Event.new(StartLoadingEvent_mt)
	return self
end

function StartLoadingEvent.new(vehicle, force)
	local self = StartLoadingEvent.emptyNew()
	self.vehicle = vehicle
	self.force = force or false
	return self
end

function StartLoadingEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.force = streamReadBool(streamId)
	self:run(connection)
end

function StartLoadingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.force)
end

function StartLoadingEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.startLoading(self.vehicle, self.force, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function StartLoadingEvent.sendEvent(vehicle, force, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Start Loading Event")
			g_server:broadcastEvent(StartLoadingEvent.new(vehicle, force), nil, nil, vehicle)
		else
			--print("client: Start Loading Event")
			g_client:getServerConnection():sendEvent(StartLoadingEvent.new(vehicle, force))
		end
	end
end
