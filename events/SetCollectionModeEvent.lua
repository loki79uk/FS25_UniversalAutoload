local SetCollectionModeEvent = {}
UniversalAutoload.SetCollectionModeEvent = SetCollectionModeEvent

local SetCollectionModeEvent_mt = Class(SetCollectionModeEvent, Event)
InitEventClass(SetCollectionModeEvent, "SetCollectionModeEvent")
-- print("  UniversalAutoload - SetCollectionModeEvent")

function SetCollectionModeEvent.emptyNew()
	local self = Event.new(SetCollectionModeEvent_mt)
	return self
end

function SetCollectionModeEvent.new(vehicle, autoCollectionMode)
	local self = SetCollectionModeEvent.emptyNew()
	self.vehicle = vehicle
	self.autoCollectionMode = autoCollectionMode
	return self
end

function SetCollectionModeEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.autoCollectionMode = streamReadBool(streamId)
	self:run(connection)
end

function SetCollectionModeEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.autoCollectionMode)
end

function SetCollectionModeEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.setAutoCollectionMode(self.vehicle, self.autoCollectionMode, true)
	end
end

function SetCollectionModeEvent.sendEvent(vehicle, autoCollectionMode, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Set CollectionMode Event")
			g_server:broadcastEvent(SetCollectionModeEvent.new(vehicle, autoCollectionMode), nil, nil, vehicle)
		else
			--print("client: Set CollectionMode Event")
			g_client:getServerConnection():sendEvent(SetCollectionModeEvent.new(vehicle, autoCollectionMode))
		end
	end
end