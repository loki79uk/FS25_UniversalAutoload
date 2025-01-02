local UpdateDefaultSettingsEvent = {}
UniversalAutoload.UpdateDefaultSettingsEvent = UpdateDefaultSettingsEvent

local UpdateDefaultSettingsEvent_mt = Class(UpdateDefaultSettingsEvent, Event)
InitEventClass(UpdateDefaultSettingsEvent, "UpdateDefaultSettingsEvent")
-- print("  UniversalAutoload - UpdateDefaultSettingsEvent")

function UpdateDefaultSettingsEvent.emptyNew()
	local self = Event.new(UpdateDefaultSettingsEvent_mt)
	return self
end

function UpdateDefaultSettingsEvent.new(exportSpec, configFileName, selectedConfigs)
	local self = UpdateDefaultSettingsEvent.emptyNew()
	self.exportSpec = exportSpec
	self.configFileName = configFileName
	self.selectedConfigs = selectedConfigs
	return self
end

function UpdateDefaultSettingsEvent:readStream(streamId, connection)
	print("Update Default Settings Event - readStream")

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
				print("  << " .. tostring(currentKey) .. " = " .. tostring(newValue))
			end
		end
	end
	
	print("RECEIVE SETTINGS")
	local configFileName = streamReadString(streamId)
	print("configFileName: " .. tostring(configFileName))
	local selectedConfigs = streamReadString(streamId)
	print("selectedConfigs: " .. tostring(selectedConfigs))
	local useConfigName = streamReadString(streamId)
	useConfigName = useConfigName ~= "" and useConfigName or nil
	print("useConfigName: " .. tostring(useConfigName))

	local config = {}
	config.useConfigName = useConfigName
	print("options:")
	iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, "", ".options", config, recieveValues)

	print("loadingAreas:")
	config.loadArea = {}
	nAreas = streamReadInt8(streamId) or 0
	for j=1, nAreas do
		config.loadArea[j] = {}
		local loadAreaKey = string.format(".loadingArea(%d)", j-1)
		iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, configKey, loadAreaKey, config.loadArea[j], recieveValues)
	end
	
	print("CONFIG RECIEVED ON SERVER:")
	DebugUtil.printTableRecursively(config, "--", 0, 2)
	
	UniversalAutoloadManager.saveConfigurationToSettings(config, configFileName, selectedConfigs, noEventSend)
	
end

function UpdateDefaultSettingsEvent:writeStream(streamId, connection)
	print("Update Default Settings Event - writeStream")

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
				print("  >> " .. tostring(currentKey) .. " = " .. tostring(finalValue))
			end
		end
	end
	
	print("SEND VEHICLE CONFIG TO SERVER")
	local spec = self.exportSpec or {}

	print("configFileName: " .. tostring(self.configFileName))
	streamWriteString(streamId, self.configFileName)
	print("selectedConfigs: " .. tostring(self.selectedConfigs))
	streamWriteString(streamId, self.selectedConfigs)
	print("useConfigName: " .. tostring(spec.useConfigName))
	streamWriteString(streamId, spec.useConfigName or "")
	
	print("options:")
	iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, "", ".options", spec, sendValues)

	print("loadingAreas:")
	local nAreas = #(spec.loadArea or {})
	streamWriteInt8(streamId, nAreas)
	for j, loadArea in pairs(spec.loadArea or {}) do
		local loadAreaKey = string.format(".loadingArea(%d)", j-1)
		iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, configKey, loadAreaKey, spec.loadArea[j], sendValues)
	end

end

function UpdateDefaultSettingsEvent.sendEvent(exportSpec, configFileName, selectedConfigs, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server == nil then
			print("client: Change Settings Event")
			g_client:getServerConnection():sendEvent(UpdateDefaultSettingsEvent.new(exportSpec, configFileName, selectedConfigs))
		end
	end
end