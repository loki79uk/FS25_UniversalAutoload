local StopLoadingEvent = {}
UniversalAutoload.StopLoadingEvent = StopLoadingEvent

local StopLoadingEvent_mt = Class(StopLoadingEvent, Event)
InitEventClass(StopLoadingEvent, "StopLoadingEvent")
-- print("  UniversalAutoload - StopLoadingEvent")

function StopLoadingEvent.emptyNew()
	local self = Event.new(StopLoadingEvent_mt)
	return self
end

function StopLoadingEvent.new(vehicle, force)
	local self = StopLoadingEvent.emptyNew()
	self.vehicle = vehicle
	self.force = force or false
	return self
end

function StopLoadingEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.force = streamReadBool(streamId)
	self:run(connection)
end

function StopLoadingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.force)
end

function StopLoadingEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.stopLoading(self.vehicle, self.force, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function StopLoadingEvent.sendEvent(vehicle, force, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Stop Loading Event")
			g_server:broadcastEvent(StopLoadingEvent.new(vehicle, force), nil, nil, vehicle)
		else
			--print("client: Stop Loading Event")
			g_client:getServerConnection():sendEvent(StopLoadingEvent.new(vehicle, force))
		end
	end
end
