local SetLoadsideEvent = {}
UniversalAutoload.SetLoadsideEvent = SetLoadsideEvent

local SetLoadsideEvent_mt = Class(SetLoadsideEvent, Event)
InitEventClass(SetLoadsideEvent, "SetLoadsideEvent")
-- print("  UniversalAutoload - SetLoadsideEvent")

function SetLoadsideEvent.emptyNew()
	local self = Event.new(SetLoadsideEvent_mt)
	return self
end

function SetLoadsideEvent.new(vehicle, loadside)
	local self = SetLoadsideEvent.emptyNew()
	self.vehicle = vehicle
	self.loadside = loadside
	return self
end

function SetLoadsideEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.loadside = streamReadString(streamId)
	self:run(connection)
end

function SetLoadsideEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteString(streamId, self.loadside)
end

function SetLoadsideEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.setCurrentLoadside(self.vehicle, self.loadside, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function SetLoadsideEvent.sendEvent(vehicle, loadside, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Set Loadside Event")
			g_server:broadcastEvent(SetLoadsideEvent.new(vehicle, loadside), nil, nil, vehicle)
		else
			--print("client: Set Loadside Event")
			g_client:getServerConnection():sendEvent(SetLoadsideEvent.new(vehicle, loadside))
		end
	end
end
