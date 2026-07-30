local PlayerTriggerEvent = {}
UniversalAutoload.PlayerTriggerEvent = PlayerTriggerEvent

local PlayerTriggerEvent_mt = Class(PlayerTriggerEvent, Event)
InitEventClass(PlayerTriggerEvent, "PlayerTriggerEvent")
-- print("  UniversalAutoload - PlayerTriggerEvent")

function PlayerTriggerEvent.emptyNew()
	local self = Event.new(PlayerTriggerEvent_mt)
	return self
end

function PlayerTriggerEvent.new(vehicle, player, inTrigger)
	local self = PlayerTriggerEvent.emptyNew()
	self.vehicle = vehicle
	self.player = player
	self.inTrigger = inTrigger
	return self
end

function PlayerTriggerEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	if streamReadBool(streamId) then
		self.player = streamReadInt32(streamId)
	end
	if streamReadBool(streamId) then
		self.inTrigger = streamReadBool(streamId)
	end
	self:run(connection)
end

function PlayerTriggerEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	if self.player ~= nil then
		streamWriteBool(streamId, true)
		streamWriteInt32(streamId, self.player)
	else
		streamWriteBool(streamId, false)
	end
	if self.inTrigger ~= nil then
		streamWriteBool(streamId, true)
		streamWriteBool(streamId, self.inTrigger)
	else
		streamWriteBool(streamId, false)
	end
end

function PlayerTriggerEvent:run(connection)
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		--print("PLAYER IN TRIGGER: "..tostring(self.inTrigger))
		UniversalAutoload.updatePlayerTriggerState(self.vehicle, self.player, self.inTrigger, true)
		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false, connection, self.vehicle)
		end
	end
end

function PlayerTriggerEvent.sendEvent(vehicle, player, inTrigger, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("server: Player Trigger Event")
			g_server:broadcastEvent(PlayerTriggerEvent.new(vehicle, player, inTrigger), nil, nil, vehicle)
		else
			--print("client: Player Trigger Event")
			g_client:getServerConnection():sendEvent(PlayerTriggerEvent.new(vehicle, player, inTrigger))
		end
	end
end
