local SetMaterialTypeEvent = {}
UniversalAutoload.SetMaterialTypeEvent = SetMaterialTypeEvent

local SetMaterialTypeEvent_mt = Class(SetMaterialTypeEvent, Event)
InitEventClass(SetMaterialTypeEvent, "SetMaterialTypeEvent")
-- print("  UniversalAutoload - SetMaterialTypeEvent")

function SetMaterialTypeEvent.emptyNew()
	local self = Event.new(SetMaterialTypeEvent_mt)
	return self
end

function SetMaterialTypeEvent.new(vehicle, typeIndex)
	local self = SetMaterialTypeEvent.emptyNew()
	self.vehicle = vehicle
	self.typeIndex = typeIndex
	return self
end

function SetMaterialTypeEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.typeIndex = streamReadUInt8(streamId)
	self:run(connection)
end

function SetMaterialTypeEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteUInt8(streamId, self.typeIndex)
end

function SetMaterialTypeEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.setMaterialTypeIndex(self.vehicle, self.typeIndex, true) 
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function SetMaterialTypeEvent.sendEvent(vehicle, typeIndex, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Set Material Type Event")
			g_server:broadcastEvent(SetMaterialTypeEvent.new(vehicle, typeIndex), nil, nil, vehicle)
		else
			--print("client: Set Material Type Event")
			g_client:getServerConnection():sendEvent(SetMaterialTypeEvent.new(vehicle, typeIndex))
		end
	end
end
