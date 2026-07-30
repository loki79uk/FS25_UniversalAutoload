local SetContainerTypeEvent = {}
UniversalAutoload.SetContainerTypeEvent = SetContainerTypeEvent

local SetContainerTypeEvent_mt = Class(SetContainerTypeEvent, Event)
InitEventClass(SetContainerTypeEvent, "SetContainerTypeEvent")
-- print("  UniversalAutoload - SetContainerTypeEvent")

function SetContainerTypeEvent.emptyNew()
	local self = Event.new(SetContainerTypeEvent_mt)
	return self
end

function SetContainerTypeEvent.new(vehicle, typeIndex)
	local self = SetContainerTypeEvent.emptyNew()
	self.vehicle = vehicle
	self.typeIndex = typeIndex
	return self
end

function SetContainerTypeEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.typeIndex = streamReadUInt8(streamId)
	self:run(connection)
end

function SetContainerTypeEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteUInt8(streamId, self.typeIndex)
end

function SetContainerTypeEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.setContainerTypeIndex(self.vehicle, self.typeIndex, true) 
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function SetContainerTypeEvent.sendEvent(vehicle, typeIndex, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Set Container Type Event")
			g_server:broadcastEvent(SetContainerTypeEvent.new(vehicle, typeIndex), nil, nil, vehicle)
		else
			--print("client: Set Container Type Event")
			g_client:getServerConnection():sendEvent(SetContainerTypeEvent.new(vehicle, typeIndex))
		end
	end
end
