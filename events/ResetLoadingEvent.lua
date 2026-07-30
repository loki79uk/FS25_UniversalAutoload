local ResetLoadingEvent = {}
UniversalAutoload.ResetLoadingEvent = ResetLoadingEvent

local ResetLoadingEvent_mt = Class(ResetLoadingEvent, Event)
InitEventClass(ResetLoadingEvent, "ResetLoadingEvent")
-- print("  UniversalAutoload - ResetLoadingEvent")

function ResetLoadingEvent.emptyNew()
	local self = Event.new(ResetLoadingEvent_mt)
	return self
end

function ResetLoadingEvent.new(vehicle)
	local self = ResetLoadingEvent.emptyNew()
	self.vehicle = vehicle
	return self
end

function ResetLoadingEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self:run(connection)
end

function ResetLoadingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
end

function ResetLoadingEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.resetLoadingState(self.vehicle, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function ResetLoadingEvent.sendEvent(vehicle, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Reset Loading Event")
			g_server:broadcastEvent(ResetLoadingEvent.new(vehicle), nil, nil, vehicle)
		else
			--print("client: Reset Loading Event")
			g_client:getServerConnection():sendEvent(ResetLoadingEvent.new(vehicle))
		end
	end
end
