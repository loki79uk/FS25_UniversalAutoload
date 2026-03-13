local UpdateGlobalSettingsEvent = {}
UniversalAutoload.UpdateGlobalSettingsEvent = UpdateGlobalSettingsEvent

local UpdateGlobalSettingsEvent_mt = Class(UpdateGlobalSettingsEvent, Event)
InitEventClass(UpdateGlobalSettingsEvent, "UpdateGlobalSettingsEvent")
-- print("  UniversalAutoload - UpdateGlobalSettingsEvent")

function UpdateGlobalSettingsEvent.emptyNew()
	local self = Event.new(UpdateGlobalSettingsEvent_mt)
	return self
end

function UpdateGlobalSettingsEvent.new()
	local self = UpdateGlobalSettingsEvent.emptyNew()
	return self
end

function UpdateGlobalSettingsEvent:readStream(streamId, connection)
	UniversalAutoload.debugPrint("Update Default Settings Event - readStream")

	UniversalAutoload.debugPrint("RECEIVE GLOBAL SETTINGS")
	iterateDefaultsTable(UniversalAutoload.GLOBAL_DEFAULTS, UniversalAutoload.globalKey, "", UniversalAutoload,
	function(k, v, parentKey, currentKey, currentValue, finalValue)	
		if currentKey then
			local newValue = nil
			if streamReadBool(streamId) == true then
				if v.valueType == "BOOL" then
					newValue = streamReadBool(streamId)
				elseif v.valueType == "INT" then
					newValue = streamReadInt16(streamId)
				elseif v.valueType == "FLOAT" then
					newValue = streamReadFloat32(streamId)
					newValue = tonumber(string.format("%.3f", newValue))
				elseif v.valueType == "STRING" then
					newValue = streamReadString(streamId)
				elseif v.valueType == "VECTOR_TRANS" then
					local x = streamReadFloat32(streamId)
					local y = streamReadFloat32(streamId)
					local z = streamReadFloat32(streamId)
					newValue = {x, y, z} 
				end
				currentValue[v.id] = newValue
				UniversalAutoload.debugPrint("  << " .. tostring(currentKey) .. " = " .. tostring(newValue))
			else
				if currentValue[v.id] ~= v.default then
					currentValue[v.id] = v.default
					UniversalAutoload.debugPrint("  << " .. tostring(currentKey) .. " = " .. tostring(v.default))
				end
			end
		end
	end)
	
	if g_currentMission:getIsServer() then
		
		if UniversalAutoload.showDebug then
			print("GLOBAL SETTINGS RECIEVED ON SERVER:")
			iterateDefaultsTable(UniversalAutoload.GLOBAL_DEFAULTS, UniversalAutoload.globalKey, "", UniversalAutoload)
		end
		
		UniversalAutoloadManager.exportGlobalSettings()
	end
	
end

function UpdateGlobalSettingsEvent:writeStream(streamId, connection)
	UniversalAutoload.debugPrint("Update Default Settings Event - writeStream")

	UniversalAutoload.debugPrint("SEND GLOBAL SETTINGS")
	iterateDefaultsTable(UniversalAutoload.GLOBAL_DEFAULTS, UniversalAutoload.globalKey, "", UniversalAutoload,
	function(k, v, parentKey, currentKey, currentValue, finalValue)
		if currentKey then
			if finalValue == nil or finalValue == v.default then
				streamWriteBool(streamId, false)
			else
				streamWriteBool(streamId, true)
				if v.valueType == "BOOL" then
					streamWriteBool(streamId, finalValue)
				elseif v.valueType == "INT" then
					streamWriteInt16(streamId, finalValue)
				elseif v.valueType == "FLOAT" then
					streamWriteFloat32(streamId, finalValue)
				elseif v.valueType == "STRING" then
					streamWriteString(streamId, finalValue)
				elseif v.valueType == "VECTOR_TRANS" then
					local x, y, z = unpack(finalValue)
					streamWriteFloat32(streamId, x)
					streamWriteFloat32(streamId, y)
					streamWriteFloat32(streamId, z)
				end
				UniversalAutoload.debugPrint("  >> " .. tostring(currentKey) .. " = " .. tostring(finalValue))
			end
		end
	end)

end

function UpdateGlobalSettingsEvent.sendEvent(noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server then
			print("server: Change Global Settings Event")
			g_server:broadcastEvent(UpdateGlobalSettingsEvent.new())
		else
			print("client: Change Global Settings Event")
			g_client:getServerConnection():sendEvent(UpdateGlobalSettingsEvent.new())
		end
	end
end