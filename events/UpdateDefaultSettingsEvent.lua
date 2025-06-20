local UpdateDefaultSettingsEvent = {}
UniversalAutoload.UpdateDefaultSettingsEvent = UpdateDefaultSettingsEvent

local UpdateDefaultSettingsEvent_mt = Class(UpdateDefaultSettingsEvent, Event)
InitEventClass(UpdateDefaultSettingsEvent, "UpdateDefaultSettingsEvent")
-- print("  UniversalAutoload - UpdateDefaultSettingsEvent")

function UpdateDefaultSettingsEvent.emptyNew()
	local self = Event.new(UpdateDefaultSettingsEvent_mt)
	return self
end

function UpdateDefaultSettingsEvent.new(exportSpec)
	local self = UpdateDefaultSettingsEvent.emptyNew()
	self.exportSpec = exportSpec
	return self
end

function UpdateDefaultSettingsEvent:readStream(streamId, connection)
	UniversalAutoload.debugPrint("Update Default Settings Event - readStream")

	local function recieveValues(k, v, parentKey, currentKey, currentValue, finalValue)
		if currentKey then
			local newValue = nil
			if streamReadBool(streamId) == true then
				if v.valueType == "BOOL" then
					newValue = streamReadBool(streamId)
				elseif v.valueType == "INT" then
					newValue = streamReadInt16(streamId)
				elseif v.valueType == "FLOAT" then
					newValue = streamReadFloat32(streamId)
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
			end
		end
	end
	
	UniversalAutoload.debugPrint("RECEIVE SETTINGS")
	local configFileName = streamReadString(streamId)
	UniversalAutoload.debugPrint("configFileName: " .. tostring(configFileName))
	local selectedConfigs = streamReadString(streamId)
	UniversalAutoload.debugPrint("selectedConfigs: " .. tostring(selectedConfigs))
	local useConfigName = streamReadString(streamId)
	useConfigName = useConfigName ~= "" and useConfigName or nil
	UniversalAutoload.debugPrint("useConfigName: " .. tostring(useConfigName))

	local config = {}
	config.configFileName = configFileName
	config.selectedConfigs = selectedConfigs
	config.useConfigName = useConfigName
	UniversalAutoload.debugPrint("options:")
	iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, "", ".options", config, recieveValues)

	UniversalAutoload.debugPrint("loadingAreas:")
	config.loadArea = {}
	nAreas = streamReadInt8(streamId) or 0
	for j=1, nAreas do
		config.loadArea[j] = {}
		local loadAreaKey = string.format(".loadingArea(%d)", j-1)
		iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, configKey, loadAreaKey, config.loadArea[j], recieveValues)
	end
	
	if UniversalAutoload.showDebug then
		print("CONFIG RECIEVED ON SERVER:")
		DebugUtil.printTableRecursively(config, "--", 0, 2)
	end
	
	UniversalAutoloadManager.saveConfigurationToSettings(config, noEventSend)
	
end

function UpdateDefaultSettingsEvent:writeStream(streamId, connection)
	UniversalAutoload.debugPrint("Update Default Settings Event - writeStream")

	local function sendValues(k, v, parentKey, currentKey, currentValue, finalValue)
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
	end
	
	UniversalAutoload.debugPrint("SEND VEHICLE CONFIG TO SERVER")
	local spec = self.exportSpec or {}

	UniversalAutoload.debugPrint("configFileName: " .. tostring(spec.configFileName))
	streamWriteString(streamId, spec.configFileName or "")
	UniversalAutoload.debugPrint("selectedConfigs: " .. tostring(spec.selectedConfigs))
	streamWriteString(streamId, spec.selectedConfigs or "")
	UniversalAutoload.debugPrint("useConfigName: " .. tostring(spec.useConfigName))
	streamWriteString(streamId, spec.useConfigName or "")
	
	UniversalAutoload.debugPrint("options:")
	iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, "", ".options", spec, sendValues)

	UniversalAutoload.debugPrint("loadingAreas:")
	local nAreas = #(spec.loadArea or {})
	streamWriteInt8(streamId, nAreas)
	for j, loadArea in pairs(spec.loadArea or {}) do
		local loadAreaKey = string.format(".loadingArea(%d)", j-1)
		iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, configKey, loadAreaKey, spec.loadArea[j], sendValues)
	end

end

function UpdateDefaultSettingsEvent.sendEvent(exportSpec, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server == nil then
			--print("client: Change Settings Event")
			g_client:getServerConnection():sendEvent(UpdateDefaultSettingsEvent.new(exportSpec))
		end
	end
end