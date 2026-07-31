local SetTipsideEvent = {}
UniversalAutoload.SetTipsideEvent = SetTipsideEvent

local SetTipsideEvent_mt = Class(SetTipsideEvent, Event)
InitEventClass(SetTipsideEvent, "SetTipsideEvent")
-- print("  UniversalAutoload - SetTipsideEvent")

function SetTipsideEvent.emptyNew()
	local self = Event.new(SetTipsideEvent_mt)
	return self
end

function SetTipsideEvent.new(vehicle, tipside)
	local self = SetTipsideEvent.emptyNew()
	self.vehicle = vehicle
	self.tipside = tipside
	return self
end

function SetTipsideEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.tipside = streamReadString(streamId)
	self:run(connection)
end

function SetTipsideEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteString(streamId, self.tipside)
end

function SetTipsideEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		UniversalAutoload.setCurrentTipside(self.vehicle, self.tipside, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function SetTipsideEvent.sendEvent(vehicle, tipside, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Set Tipside Event")
			g_server:broadcastEvent(SetTipsideEvent.new(vehicle, tipside), nil, nil, vehicle)
		else
			--print("client: Set Tipside Event")
			g_client:getServerConnection():sendEvent(SetTipsideEvent.new(vehicle, tipside))
		end
	end
end
