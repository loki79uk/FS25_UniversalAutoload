-- ============================================================= --
-- Universal Autoload MOD - MANAGER
-- ============================================================= --

-- manager
UniversalAutoloadManager = {}
addModEventListener(UniversalAutoloadManager)

UniversalAutoloadManager.DEBUG_STEPS = nil

-- specialisation
g_specializationManager:addSpecialization('universalAutoload', 'UniversalAutoload', Utils.getFilename('UniversalAutoload.lua', g_currentModDirectory), "")

TypeManager.validateTypes = Utils.appendedFunction(TypeManager.validateTypes, function(self)
	if self.typeName == "vehicle" then
		print("UAL - VALIDATE TYPES")
		UniversalAutoloadManager.injectSpecialisation()
	end
end)

local ROOT = getmetatable(_G).__index
-- DETECT SOLD LOGS/OBJECTS
ROOT.delete = Utils.appendedFunction(ROOT.delete, function(nodeId)
	if UniversalAutoload.OBJECTS_LOOKUP[nodeId] then
		local object = UniversalAutoload.OBJECTS_LOOKUP[nodeId] 
		UniversalAutoload.clearPalletFromAllVehicles(nil, object)
		UniversalAutoload.OBJECTS_LOOKUP[nodeId] = nil
	elseif UniversalAutoload.SPLITSHAPES_LOOKUP[nodeId] then
		local object = UniversalAutoload.SPLITSHAPES_LOOKUP[nodeId] 
		UniversalAutoload.clearPalletFromAllVehicles(nil, object)
		UniversalAutoload.SPLITSHAPES_LOOKUP[nodeId] = nil
	end
end)
-- DETECT SPAWNED LOGS
ROOT.addToPhysics = Utils.appendedFunction(ROOT.addToPhysics, function(nodeId)
	if nodeId ~= 0 and nodeId ~= nil then
		if getHasClassId(nodeId, ClassIds.MESH_SPLIT_SHAPE) and getSplitType(nodeId) ~= 0 and getRigidBodyType(nodeId) == RigidBodyType.DYNAMIC then
			if not UniversalAutoload.createdLogId and UniversalAutoload.createdTreeId and nodeId > UniversalAutoload.createdTreeId then
				UniversalAutoload.createdLogId = nodeId
			end
		end
	end
end)
-- DETECT CUT LOGS
SplitShapeUtil.splitShape = Utils.appendedFunction(SplitShapeUtil.splitShape, function(nodeId)
	if UniversalAutoload.SPLITSHAPES_LOOKUP[nodeId] then
		local object = UniversalAutoload.SPLITSHAPES_LOOKUP[nodeId] 
		UniversalAutoload.clearPalletFromAllVehicles(nil, object)
		UniversalAutoload.SPLITSHAPES_LOOKUP[nodeId] = nil
	end
end)

-- Create a new store pack to group all UAL supported vehicles
g_storeManager:addModStorePack("UNIVERSALAUTOLOAD", g_i18n:getText("configuration_universalAutoload", g_currentModName), "icons/storePack_ual.dds", g_currentModDirectory)

-- external classes
source(UniversalAutoload.path .. "scripts/BoundingBox.lua")
source(UniversalAutoload.path .. "scripts/LoadingVolume.lua")
source(UniversalAutoload.path .. "gui/ModSettingsMenu.lua")
source(UniversalAutoload.path .. "gui/ShopConfigMenuUALSettings.lua")
source(UniversalAutoload.path .. "gui/GlobalSettingsMenuUALSettings.lua")

-- class variables
UniversalAutoload.userSettingsFile = "modSettings/UniversalAutoload.xml"
UniversalAutoload.SHOP_ICON = UniversalAutoload.path .. "icons/shop_icon.dds"

-- class tables
UniversalAutoload.ACTIONS = {
	["GLOBAL_MENU"]          = "UNIVERSALAUTOLOAD_GLOBAL_MENU",
	["TOGGLE_LOADING"]		 = "UNIVERSALAUTOLOAD_TOGGLE_LOADING",
	["UNLOAD_ALL"]			 = "UNIVERSALAUTOLOAD_UNLOAD_ALL",
	["TOGGLE_TIPSIDE"]		 = "UNIVERSALAUTOLOAD_TOGGLE_TIPSIDE",
	["TOGGLE_FILTER"]		  = "UNIVERSALAUTOLOAD_TOGGLE_FILTER",
	["TOGGLE_HORIZONTAL"]	  = "UNIVERSALAUTOLOAD_TOGGLE_HORIZONTAL",
	["CYCLE_MATERIAL_FW"]	  = "UNIVERSALAUTOLOAD_CYCLE_MATERIAL_FW",
	["CYCLE_MATERIAL_BW"]	  = "UNIVERSALAUTOLOAD_CYCLE_MATERIAL_BW",
	["SELECT_ALL_MATERIALS"]   = "UNIVERSALAUTOLOAD_SELECT_ALL_MATERIALS",
	["CYCLE_CONTAINER_FW"]	 = "UNIVERSALAUTOLOAD_CYCLE_CONTAINER_FW",
	["CYCLE_CONTAINER_BW"]	 = "UNIVERSALAUTOLOAD_CYCLE_CONTAINER_BW",
	["SELECT_ALL_CONTAINERS"]  = "UNIVERSALAUTOLOAD_SELECT_ALL_CONTAINERS",
	-- ["TOGGLE_BELTS"]		   = "UNIVERSALAUTOLOAD_TOGGLE_BELTS",
	-- ["TOGGLE_DOOR"]			= "UNIVERSALAUTOLOAD_TOGGLE_DOOR",
	-- ["TOGGLE_CURTAIN"]		   = "UNIVERSALAUTOLOAD_TOGGLE_CURTAIN",
	["TOGGLE_SHOW_DEBUG"]	   = "UNIVERSALAUTOLOAD_TOGGLE_SHOW_DEBUG",
	["TOGGLE_SHOW_LOADING"]	   = "UNIVERSALAUTOLOAD_TOGGLE_SHOW_LOADING",
	["TOGGLE_COLLECTION"]	   = "UNIVERSALAUTOLOAD_TOGGLE_COLLECTION",
}

UniversalAutoload.WARNINGS = {
	[1] = "warning_UNIVERSALAUTOLOAD_CLEAR_UNLOADING_AREA",
	[2] = "warning_UNIVERSALAUTOLOAD_NO_OBJECTS_FOUND",
	[3] = "warning_UNIVERSALAUTOLOAD_UNABLE_TO_LOAD_OBJECT_FULL",
	[4] = "warning_UNIVERSALAUTOLOAD_UNABLE_TO_LOAD_OBJECT_EMPTY",
	[5] = "warning_UNIVERSALAUTOLOAD_NO_LOADING_UNLESS_STATIONARY",
}
UniversalAutoload.WARNINGS_BY_NAME = {
	["CLEAR_UNLOADING_AREA"] = 1,
	["NO_OBJECTS_FOUND"] = 2,
	["UNABLE_TO_LOAD_FULL"] = 3,
	["UNABLE_TO_LOAD_EMPTY"] = 4,
	["NO_LOADING_UNLESS_STATIONARY"] = 5,
}

UniversalAutoload.CONTAINERS = {
	[1] = "ALL",
	[2] = "EURO_PALLET",
	[3] = "BIGBAG_PALLET",
	[4] = "LIQUID_TANK",
	[5] = "BIGBAG",
	[6] = "BALE",
	[7] = "LOGS",
}

UniversalAutoload.VEHICLES = {} -- actual vehicles currently in game
UniversalAutoload.VEHICLE_TYPES = {} -- vehicleTypes with autoload spec
UniversalAutoload.LOADING_TYPES = {} -- known container object types

UniversalAutoload.GLOBAL_DEFAULTS = {
	{id="showDebug", default=false, valueType="BOOL", key="#showDebug"}, --Show the full graphical debugging display for all vehicles in game
	{id="highPriority", default=true, valueType="BOOL", key="#highPriority"}, --Apply high priority to all UAL key bindings in the F1 menu
	{id="disableAutoStrap", default=false, valueType="BOOL", key="#disableAutoStrap"}, --Disable the automatic application of tension belts
	{id="pricePerLog", default=0, valueType="FLOAT", key="#pricePerLog"}, --The price charged for each auto-loaded log (default is zero)
	{id="pricePerBale", default=0, valueType="FLOAT", key="#pricePerBale"}, --The price charged for each auto-loaded bale (default is zero)
	{id="pricePerPallet", default=0, valueType="FLOAT", key="#pricePerPallet"}, --The price charged for each auto-loaded pallet (default is zero)
	{id="minLogLength", default=0, valueType="FLOAT", key="#minLogLength"}, --The global minimum length for logs that will be autoloaded (default is zero)
}

UniversalAutoload.OPTIONS_DEFAULTS = {
	{id="autoloadDisabled", default=false, valueType="BOOL", key="#autoloadDisabled"}, --If autoload features are disabled for this trailer
	{id="isBoxTrailer", default=false, valueType="BOOL", key="#isBoxTrailer"}, --If trailer is enclosed with a rear door
	{id="isLogTrailer", default=false, valueType="BOOL", key="#isLogTrailer"}, --If trailer is a logging trailer - will load only logs, dropped from above
	{id="isBaleTrailer", default=false, valueType="BOOL", key="#isBaleTrailer"}, --If trailer should use an automatic bale collection mode
	{id="isBaleProcessor", default=false, valueType="BOOL", key="#isBaleProcessor"}, --If trailer should consume bales (e.g. TMR Mixer or Straw Blower)
	{id="isCurtainTrailer", default=false, valueType="BOOL", key="#isCurtainTrailer"}, --Automatically detect the available load side (if the trailer has curtain sides)
	{id="enableRearLoading", default=false, valueType="BOOL", key="#enableRearLoading"}, --Use the automatic rear loading trigger
	{id="enableSideLoading", default=false, valueType="BOOL", key="#enableSideLoading"}, --Use the automatic side loading triggers
	{id="noLoadingIfFolded", default=false, valueType="BOOL", key="#noLoadingIfFolded"}, --Prevent loading when folded
	{id="noLoadingIfUnfolded", default=false, valueType="BOOL", key="#noLoadingIfUnfolded"}, --Prevent loading when unfolded
	{id="noLoadingIfCovered", default=false, valueType="BOOL", key="#noLoadingIfCovered"}, --Prevent loading when covered
	{id="noLoadingIfUncovered", default=false, valueType="BOOL", key="#noLoadingIfUncovered"}, --Prevent loading when uncovered
	{id="rearUnloadingOnly", default=false, valueType="BOOL", key="#rearUnloadingOnly"}, --Use rear unloading zone only (not side zones)
	{id="frontUnloadingOnly", default=false, valueType="BOOL", key="#frontUnloadingOnly"}, --Use front unloading zone only (not side zones)
	{id="horizontalLoading", default=false, valueType="BOOL", key="#horizontalLoading"}, --Start with horizontal loading enabled (can be toggled if key is bound)
	{id="disableAutoStrap", default=false, valueType="BOOL", key="#disableAutoStrap"}, --Disable the automatic application of tension belts
	{id="disableHeightLimit", default=false, valueType="BOOL", key="#disableHeightLimit"}, --Disable the density based stacking height limit
	{id="zonesOverlap", default=false, valueType="BOOL", key="#zonesOverlap"}, --Flag to identify when the loading areas overlap each other
	{id="offsetRoot", default=nil, valueType="STRING", key="#offsetRoot"}, --Vehicle i3d node that area offsets are relative to
	{id="minLogLength", default=0, valueType="FLOAT", key="#minLogLength"}, --The minimum length for logs that will be autoloaded (default is zero)
}

UniversalAutoload.LOADING_AREA_DEFAULTS = {
	{id="offset", default="0 0 0", valueType="VECTOR_TRANS", key="#offset"}, --Offset to the centre of the loading area
	{id="offsetRoot", default=nil, valueType="STRING", key="#offsetRoot"}, --Vehicle i3d node that this area offset is relative to
	{id="width", default=0, valueType="FLOAT", key="#width"}, --Width of the loading area
	{id="length", default=0, valueType="FLOAT", key="#length"}, --Length of the loading area
	{id="height", default=0, valueType="FLOAT", key="#height"}, --Height of the loading area
	{id="baleHeight", default=nil, valueType="FLOAT", key="#baleHeight"}, --Height of the loading area for BALES only
	{id="widthAxis", default=nil, valueType="STRING", key="#widthAxis"}, --Axis name to extend width of the loading area
	{id="lengthAxis", default=nil, valueType="STRING", key="#lengthAxis"}, --Axis name to extend length of the loading area
	{id="heightAxis", default=nil, valueType="STRING", key="#heightAxis"}, --Axis name to extend height of the loading area
	{id="offsetFrontAxis", default=nil, valueType="STRING", key="#offsetFrontAxis"}, --Axis name to adjust the front position of the loading area
	{id="offsetRearAxis", default=nil, valueType="STRING", key="#offsetRearAxis"}, --Axis name to adjust the rear position of the loading area
	{id="reverseWidthAxis", default=false, valueType="BOOL", key="#reverseWidthAxis"}, --Reverses direction of width extension if true
	{id="reverseLengthAxis", default=false, valueType="BOOL", key="#reverseLengthAxis"}, --Reverses direction of length extension if true
	{id="reverseHeightAxis", default=false, valueType="BOOL", key="#reverseHeightAxis"}, --Reverses direction of height extension if true
	{id="noLoadingIfFolded", default=false, valueType="BOOL", key="#noLoadingIfFolded"}, --Prevent loading when folded (for this area only)
	{id="noLoadingIfUnfolded", default=false, valueType="BOOL", key="#noLoadingIfUnfolded"}, --Prevent loading when unfolded (for this area only)
	{id="noLoadingIfCovered", default=false, valueType="BOOL", key="#noLoadingIfCovered"}, --Prevent loading when covered (for this area only)
	{id="noLoadingIfUncovered", default=false, valueType="BOOL", key="#noLoadingIfUncovered"}, --Prevent loading when uncovered (for this area only)
}

UniversalAutoload.CONFIG_DEFAULTS = {
	{id="selectedConfigs", default="ALL", valueType="STRING", key="#selectedConfigs"}, --Selected Configuration Names
	{id="useConfigName", default=nil, valueType="STRING", key="#useConfigName"}, --Specific configuration to be used for selected configs
	{
		key = ".loadingArea(?)",
		name = "loadingArea",
		data = UniversalAutoload.LOADING_AREA_DEFAULTS,
	},
	{
		key = ".options",
		name = "options",
		data = UniversalAutoload.OPTIONS_DEFAULTS,
	},
}
	
UniversalAutoload.VEHICLE_DEFAULTS = {
	{id="configFileName", default=nil, valueType="STRING", key="#configFileName"}, --Vehicle config file xml full path - used to identify supported vehicles
	{
		key = ".configuration(?)",
		name = "spec",
		data = UniversalAutoload.CONFIG_DEFAULTS,
	},
}

UniversalAutoload.SAVEGAME_STATE_DEFAULTS = {
	{id="tipside", default="none", valueType="STRING", key="#tipside"}, --Last used tip side
	{id="loadside", default="both", valueType="STRING", key="#loadside"}, --Last used load side
	{id="loadWidth", default=0, valueType="FLOAT", key="#loadWidth"}, --Last used load width
	{id="loadLength", default=0, valueType="FLOAT", key="#loadLength"}, --Last used load length
	{id="loadHeight", default=0, valueType="FLOAT", key="#loadHeight"}, --Last used load height
	{id="actualWidth", default=0, valueType="FLOAT", key="#actualWidth"}, --Last used expected load width
	{id="actualLength", default=0, valueType="FLOAT", key="#actualLength"}, --Last used complete load length
	{id="layerCount", default=0, valueType="INT", key="#layerCount"}, --Number of layers that are currently loaded
	{id="layerHeight", default=0, valueType="FLOAT", key="#layerHeight"}, --Total height of the currently loaded layers
	{id="nextLayerHeight", default=0, valueType="FLOAT", key="#nextLayerHeight"}, --Height for the next layer (highest point in previous layer)
	{id="lastLoadLength", default=0, valueType="FLOAT", key="#lastLoadLength"}, --Length of the last loaded object
	{id="loadAreaIndex", default=1, valueType="INT", key="#loadAreaIndex"}, --Last used load area
	{id="materialIndex", default=1, valueType="INT", key="#materialIndex"}, --Last used material type
	{id="containerIndex", default=1, valueType="INT", key="#containerIndex"}, --Last used container type
	{id="loadingFilter", default=false, valueType="BOOL", key="#loadingFilter"}, --TRUE=Load full pallets only; FALSE=Load any pallets
	{id="useHorizontalLoading", default=false, valueType="BOOL", key="#useHorizontalLoading"}, --Last used horizontal loading state
	{id="autoCollectionMode", default=false, valueType="BOOL", key="#autoCollectionMode"}, --Enable manual toggling of the automatic collection mode
}

function iterateDefaultsTable(tbl, parentKey, currentKey, currentValue, action)
    parentKey = parentKey or ""
    currentKey = currentKey or ""
    action = action or function(k, v, parentKey, currentKey, currentValue, finalValue) 
        if debugSchema then print("  " .. currentKey .. ": " .. tostring(finalValue)) end
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            local newCurrentKey = currentKey
            if v.key then
                newCurrentKey = newCurrentKey .. v.key
            end
            local newCurrentValue = currentValue
            if v.id ~= nil then
                local finalValue = newCurrentValue and newCurrentValue[v.id] or v.default
                action(k, v, parentKey, newCurrentKey, newCurrentValue, finalValue)
            end
            if v.data then
                iterateDefaultsTable(v.data, parentKey, newCurrentKey, newCurrentValue, action)
            end
        end
    end
end
print("GLOBAL_DEFAULTS") iterateDefaultsTable(UniversalAutoload.GLOBAL_DEFAULTS)
print("VEHICLE_DEFAULTS") iterateDefaultsTable(UniversalAutoload.VEHICLE_DEFAULTS)
print("SAVEGAME_STATE_DEFAULTS") iterateDefaultsTable(UniversalAutoload.SAVEGAME_STATE_DEFAULTS)

function UniversalAutoloadManager.openUserSettingsXMLFile(xmlFilename)
	
	local xmlFilename = xmlFilename or Utils.getFilename(UniversalAutoload.userSettingsFile, getUserProfileAppPath())
	local xmlFile = XMLFile.loadIfExists("settings", xmlFilename, UniversalAutoload.xmlSchema)
	if not xmlFile then
		print("Creating NEW settings file " .. xmlFilename)
		xmlFile = XMLFile.create("settings", xmlFilename, "universalAutoload", UniversalAutoload.xmlSchema)
	end
	
	return xmlFile
end
--
function UniversalAutoloadManager.getVehicleConfigFromSettingsXML(configKey, xmlFile)
	
	if not configKey then
		print("configuration key required for getVehicleConfigFromSettingsXML")
		return
	end

	local shouldCloseFile = not xmlFile and true
	local xmlFile = xmlFile or UniversalAutoloadManager.openUserSettingsXMLFile()
	
	if xmlFile then
		
		local function readSettingFromFile(k, v, parentKey, currentKey, currentValue, finalValue)
			if currentKey and currentValue and v.id then
				if v.valueType == "VECTOR_TRANS" then
					currentValue[v.id] = xmlFile:getValue(currentKey, v.default, true)
				else
					currentValue[v.id] = xmlFile:getValue(currentKey, v.default)
				end
				-- print("  << " .. tostring(currentKey) .. " = " .. tostring(currentValue[v.id]))
			end
		end

		local config = {}
		config.selectedConfigs = xmlFile:getValue(configKey.."#selectedConfigs", UniversalAutoload.ALL)
		config.useConfigName = xmlFile:getValue(configKey.."#useConfigName", nil)
		iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, "", configKey..".options", config, readSettingFromFile)

		local j = 1
		local hasBaleHeight = false
		local loadingArea = {}
		while true do
			local loadAreaKey = string.format("%s.loadingArea(%d)", configKey, j-1)
			if not xmlFile:hasProperty(loadAreaKey) then
				break
			end
			loadingArea[j] = {}
			iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, "", loadAreaKey, loadingArea[j], readSettingFromFile)
			hasBaleHeight = hasBaleHeight or type(loadingArea[j].baleHeight) == 'number'
			j = j + 1
		end
		config['loadArea'] = loadingArea

		local isBaleTrailer = config.isBaleTrailer
		local isBaleProcessor = config.isBaleProcessor
		local horizontalLoading = config.horizontalLoading
		config.horizontalLoading = horizontalLoading or isBaleTrailer or isBaleProcessor or false
		config.isBaleTrailer = isBaleTrailer or hasBaleHeight

		if shouldCloseFile then
			xmlFile:delete()
		end
		
		return config
	else
		print("ERROR: no settings file " .. tostring(xmlFile))
	end
end
--
function UniversalAutoloadManager.countConfigsInSettingsXML(xmlFile)

	local shouldCloseFile = not xmlFile and true
	local xmlFile = xmlFile or UniversalAutoloadManager.openUserSettingsXMLFile()
	
	if xmlFile then
		local i = 0
		local counts = {}
		while true do
			local vehicleKey = string.format(UniversalAutoload.vehicleKey, i)
			if not xmlFile:hasProperty(vehicleKey) then
				break
			end
			local j = 0
			while true do
				local configKey = string.format(UniversalAutoload.vehicleConfigKey, i, j)
				if not xmlFile:hasProperty(configKey) then
					break
				end
				j = j + 1
			end
			i = i + 1
			counts[i] = j
		end	
		
		if shouldCloseFile then
			xmlFile:delete()
		end
		
		return i, counts
	end
end
--
function UniversalAutoloadManager.getConfigSettingsPosition(targetFileName, targetConfigId, xmlFile)

	local targetConfigId = targetConfigId or UniversalAutoload.ALL
	local shouldCloseFile = not xmlFile and true
	local xmlFile = xmlFile or UniversalAutoloadManager.openUserSettingsXMLFile()
	
	if xmlFile then
		local i = 0
		while true do
			local vehicleKey = string.format(UniversalAutoload.vehicleKey, i)
			if not xmlFile:hasProperty(vehicleKey) then
				break
			end
			local configFileName = xmlFile:getValue(vehicleKey .. "#configFileName", "MISSING")
			configFileName = UniversalAutoloadManager.cleanConfigFileName(configFileName)
			targetFileName = UniversalAutoloadManager.cleanConfigFileName(targetFileName)
			if tostring(configFileName):lower() == tostring(targetFileName):lower() then
				
				print("targetConfigId: " .. tostring(targetConfigId))
				local j = 0
				while true do
					local configKey = string.format(UniversalAutoload.vehicleConfigKey, i, j)
					if not xmlFile:hasProperty(configKey) then
						break
					end
					local selectedConfigs = xmlFile:getValue(configKey .. "#selectedConfigs", "MISSING")
					print("selectedConfigs: " .. selectedConfigs)
					local isMatchAny = selectedConfigs == UniversalAutoload.ALL
					-- local hasPipeChar = tostring(targetConfigId):find("|")
					-- local isMatchFull = hasPipeChar and targetConfigId == selectedConfigs
					-- local isMatchPart = not hasPipeChar and tostring(targetConfigId):find(selectedConfigs)
					if isMatchAny then
						print("FOUND 'ALL' CONFIG AT #" .. j+1)
						break
					elseif selectedConfigs:find(tostring(targetConfigId)) then
						print("FOUND SELECTED CONFIG AT #" .. j+1)
						break
					end
					j = j + 1
				end
	
				return i, j
			end
			i = i + 1
		end	
		
		if shouldCloseFile then
			xmlFile:delete()
		end
		
		return nil, nil, i
	end
end
--
function UniversalAutoloadManager.getVehicleConfigIndexesForSaving(exportSpec, xmlFile)

	local configFileName = exportSpec.configFileName
	local selectedConfigs = exportSpec.selectedConfigs
	local configId = selectedConfigs or exportSpec.configId
	
	local index, subIndex, size = UniversalAutoloadManager.getConfigSettingsPosition(configFileName, configId, xmlFile)

	if index then
		local key = string.format(UniversalAutoload.vehicleKey, index)
		local configKey = string.format(UniversalAutoload.vehicleConfigKey, index, subIndex)
		
		local fileSelectedConfigs = xmlFile:getValue(configKey .. "#selectedConfigs")
		if fileSelectedConfigs == UniversalAutoload.ALL and exportSpec.useConfigName then
			print("SETTINGS FILE using: " .. fileSelectedConfigs)
			print(" configId: " .. configId)
			print(" useConfigName: " .. exportSpec.useConfigName)
		end

		print("UPDATE CONFIG #" .. index + 1 .. " == " .. configId .. " (#" ..subIndex + 1 .. ")")
		while true do
			local loadAreaKey = string.format("%s.loadingArea(%d)", configKey, 0)
			if not xmlFile:hasProperty(loadAreaKey) then
				break
			end
			xmlFile:removeProperty(loadAreaKey)
		end
	else
		index = size or 0
		subIndex = 0
		print("INSERT CONFIG INDEX #" .. index)
		local key = string.format(UniversalAutoload.vehicleKey, index)
		xmlFile:setValue(key.."#configFileName", configFileName)
	end
	
	if exportSpec.useConfigName then
		local key = string.format(UniversalAutoload.vehicleConfigKey, index, subIndex)
		xmlFile:setValue(key.."#useConfigName", exportSpec.useConfigName)
	end

	print("USING CONFIG SUB-INDEX: #" .. subIndex .. " (" .. configId .. ")")
	local key = string.format(UniversalAutoload.vehicleConfigKey, index, subIndex)
	xmlFile:setValue(key.."#selectedConfigs", tostring(configId))
	if exportSpec.useConfigName then
		print("useConfigName: " .. tostring(exportSpec.useConfigName))
		xmlFile:setValue(key.."#useConfigName", tostring(exportSpec.useConfigName))
	end
	
	if not UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] then
		UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] = {}
	end
	if not UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName][configId] then
		UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName][configId] = {}
	end
	
	return index, subIndex
end
--
function UniversalAutoloadManager.getVehicleConfigNames(vehicle)
	local spec = vehicle and vehicle.spec_universalAutoload
	if not spec or not vehicle.configFileName then
		print("Invalid vehicle supplied: " .. tostring(vehicle))
		return
	end
	
	if not spec.configFileName then
		print("warning: config file name was missing..")
	end
	spec.configFileName = UniversalAutoloadManager.cleanConfigFileName(vehicle.configFileName)
	
	if not spec.selectedConfigs then
		print("FIND CORRECT SETTINGS FILE POSITION:")
		spec.selectedConfigs = UniversalAutoloadManager.getValidConfigurationId(vehicle)
	end
	
	return spec.configFileName, spec.selectedConfigs
end
--
function UniversalAutoloadManager.saveVehicleConfigToSettingsXML(exportSpec)
	if not exportSpec or not exportSpec.configFileName or not exportSpec.selectedConfigs then
		print("Invalid vehicle spec supplied: " .. tostring(exportSpec.configFileName))
		return
	end

	local xmlFile = UniversalAutoloadManager.openUserSettingsXMLFile()
	
	if xmlFile then

		local function writeSettingToFile(k, v, parentKey, currentKey, currentValue, finalValue)
			if currentKey and finalValue ~= nil then
				if v.valueType == "VECTOR_TRANS" then
					if type(finalValue) == "string" then
						local vector = {}
						for num in finalValue:gmatch("%S+") do
							table.insert(vector, tonumber(num))
						end
						finalValue = vector
					elseif type(finalValue) ~= "table" then
						error("Unexpected type for VECTOR_TRANS: " .. tostring(finalValue))
					end
				end
				
				if finalValue == v.default then
					xmlFile:removeProperty(parentKey..currentKey)
				else
					print("  >> " .. tostring(currentKey) .. " = " .. tostring(finalValue))
					if type(finalValue) == "table" and v.valueType == "VECTOR_TRANS" then
						xmlFile:setValue(parentKey..currentKey, unpack(finalValue))
					else
						xmlFile:setValue(parentKey..currentKey, finalValue)
					end
				end
			end
		end

		if exportSpec.loadArea and #exportSpec.loadArea > 0 then

			print("SAVE TO SETTINGS FILE")
			print("configFileName: " .. tostring(exportSpec.configFileName))
			print("selectedConfigs: " .. tostring(exportSpec.selectedConfigs))
			print("useConfigName: " .. tostring(exportSpec.useConfigName))
			print("configId: " .. tostring(exportSpec.configId))
			local index, subIndex = UniversalAutoloadManager.getVehicleConfigIndexesForSaving(exportSpec, xmlFile)

			print("options:")
			local configKey = string.format(UniversalAutoload.vehicleConfigKey, index, subIndex)
			iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, configKey, ".options", exportSpec, writeSettingToFile)
			print("loadingAreas:")
			for j, loadArea in pairs(exportSpec.loadArea or {}) do
				local loadAreaKey = string.format(".loadingArea(%d)", j-1)
				iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, configKey, loadAreaKey, loadArea, writeSettingToFile)
			end
			xmlFile:save()
			
			print("UPDATE CONFIG IN MEMORY - " .. exportSpec.selectedConfigs)
			local configFileName = exportSpec.configFileName
			local selectedConfigs = exportSpec.selectedConfigs
			local useConfigName = exportSpec.useConfigName
			local CONFIGS = UniversalAutoload.VEHICLE_CONFIGURATIONS
			CONFIGS[configFileName] = CONFIGS[configFileName] or {}
			CONFIGS[configFileName][selectedConfigs] = CONFIGS[configFileName][selectedConfigs] or {}
			local config = CONFIGS[configFileName][selectedConfigs]
			for k, v in pairs(UniversalAutoload.OPTIONS_DEFAULTS) do
				local id = v.id
				config[id] = exportSpec[id] or v.default
				print(" " .. tostring(id) .. " = " .. tostring(config[id]))
			end
			config.loadArea = {}
			for i, loadArea in (exportSpec.loadArea) do
				config.loadArea[i] = deepCopy(exportSpec.loadArea[i])
				print(" [" .. i .. "]")
				DebugUtil.printTableRecursively(config.loadArea[i] or {}, "--", 0, 1)
			end
			config.configFileName = configFileName
			config.selectedConfigs = selectedConfigs
			config.useConfigName = useConfigName
			
		else
			print("DID NOT SAVE SETTINGS - loading area was missing")
		end
		
		xmlFile:delete()
	end
end

function UniversalAutoloadManager.importLocalConfigurations(forceOverwrite)
	-- print("UAL - IMPORT CONFIGS")
	local forceOverwrite = forceOverwrite or false
	local userSettingsFile = Utils.getFilename(UniversalAutoload.userSettingsFile, getUserProfileAppPath())

	if not fileExists(userSettingsFile) or forceOverwrite then
		print("CREATING default settings file")
		local defaultSettingsFile = Utils.getFilename("xml/UniversalAutoloadDefaults.xml", UniversalAutoload.path)
		copyFile(defaultSettingsFile, userSettingsFile, forceOverwrite)
	end

	UniversalAutoloadManager.importGlobalSettings(userSettingsFile)
	UniversalAutoloadManager.importVehicleConfigurations(userSettingsFile)
	
end

function UniversalAutoloadManager.consoleResetConfigurations()
	-- print("UAL - RESET CONFIGS")
	UniversalAutoloadManager.importLocalConfigurations(true)
	print("UNIVERSAL AUTOLOAD: Configurations were RESET to defaults")
	print("New configurations will be used for new vehicles, please restart game to apply to all vehicles")
end
--
function UniversalAutoloadManager.importGlobalSettings(xmlFilename)
	-- print("UAL - IMPORT GLOBAL SETTINGS")

	if g_currentMission:getIsServer() then

		local xmlFile = UniversalAutoloadManager.openUserSettingsXMLFile(xmlFilename)
		
		if xmlFile ~= 0 and xmlFile ~= nil then
		
			print("IMPORT Universal Autoload global settings")

			iterateDefaultsTable(UniversalAutoload.GLOBAL_DEFAULTS, UniversalAutoload.globalKey, "", UniversalAutoload,
			function(k, v, parentKey, currentKey, currentValue, finalValue)
				UniversalAutoload[v.id] = xmlFile:getValue(parentKey..currentKey, v.default)
				print("  >> " .. tostring(v.id) .. ": " .. tostring(v.default))
			end)

			xmlFile:delete()
		else
			print("Universal Autoload - could not open global settings file")
		end
	else
		print("Universal Autoload - global settings are only loaded for the server")
	end
end
--
function UniversalAutoloadManager.importVehicleConfigurations(xmlFilename)
	print("UAL - IMPORT VEHICLE CONFIGS")
	-- TODO: could clean incompatible settings here..

	UniversalAutoload.VEHICLE_CONFIGURATIONS = {}
	local xmlFile = UniversalAutoloadManager.openUserSettingsXMLFile(xmlFilename)
	
	if xmlFile then
		local xmlWasCleaned = false
		local i = 0
		while true do
			local vehicleKey = string.format(UniversalAutoload.vehicleKey, i)
			if not xmlFile:hasProperty(vehicleKey) then
				break
			end
			
			local configFileName = xmlFile:getValue(vehicleKey .. "#configFileName")
			configFileName, removedPart = UniversalAutoloadManager.cleanConfigFileName(configFileName)
			if removedPart ~= nil then
				print("CLEANING CONFIG FILE NAME: " .. configFileName .. removedPart)
				xmlFile:setValue(vehicleKey .. "#configFileName", configFileName)
				print("... replaced with: " .. configFileName)
				xmlWasCleaned = true
			end
			
			if UniversalAutoloadManager.getValidXmlName(configFileName) then
				print(" [" .. i + 1 .. "] " .. configFileName)

				local j = 0
				while true do
					local configKey = vehicleKey .. string.format(".configuration(%d)", j)
					if not xmlFile:hasProperty(configKey) then
						break
					end
					
					local configuration = UniversalAutoloadManager.getVehicleConfigFromSettingsXML(configKey, xmlFile)
					if not configuration then
						print("could not load UAL configuration for: " .. configKey)
					end

					if not UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] then
						-- print("ADDING SHOP ITEM " .. configFileName)
						UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] = {}
						table.addElement(g_storeManager:getPackItems("UNIVERSALAUTOLOAD"), configFileName)
					end
					
					local configGroup = UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName]
					local selectedConfigs = xmlFile:getValue(configKey.."#selectedConfigs", UniversalAutoload.ALL)
					local useConfigName = xmlFile:getValue(configKey.."#useConfigName", nil)
					
					if useConfigName == nil and tostring(selectedConfigs):find("|") then
						configuration.originalSelectedConfigs = selectedConfigs
						selectedConfigs = tostring(selectedConfigs):match("^(.-)|")
						print(" *** SUGGEST REPAIRING CONFIG: '" .. configuration.originalSelectedConfigs
							.. "' - using '" .. selectedConfigs .. "' OR specify useConfigName='design' ***")
					end

					if not configGroup[selectedConfigs] then
						configuration.useConfigName = useConfigName
						configuration.configFileName = configFileName
						configuration.selectedConfigs = selectedConfigs
						configGroup[selectedConfigs] = configuration
					else
						if UniversalAutoload.showDebug then print("  ALREADY EXISTS: ["..selectedConfigs.."]") end
					end

					print("  >> ["..selectedConfigs.."] ".. (useConfigName and ("(" .. useConfigName .. ")") or ""))

					j = j + 1
				end
				
			else
				if UniversalAutoload.showDebug then print("  NOT FOUND: " .. tostring(configFileName)) end
			end

			i = i + 1
		end
		
		if xmlWasCleaned then
			xmlFile:save()
		end
		
		xmlFile:delete()
		
		return i
	end

end

function UniversalAutoloadManager.getValidConfigurationId(vehicle)
	-- returns: configId, description
	local spec = vehicle and vehicle.spec_universalAutoload
    if not spec then return end
	
	local item = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
	if not item then
		print("could not get store item for " .. tostring(vehicle.configFileName))
		return
	end
	
    local useConfigName = spec.useConfigName
    local configName = useConfigName and vehicle.configurations[useConfigName] and tostring(vehicle.configurations[useConfigName]) or nil
    local configurationSets = item.configurationSets or {}

    if #configurationSets == 0 then
        local fullConfigId = UniversalAutoload.ALL .. (configName and ("|" .. configName) or "")
        return fullConfigId, UniversalAutoload.ALL, "UNIQUE" .. (useConfigName and ("|" .. useConfigName) or "")
    end

    local bestMatch = { index = nil, count = 0, name = nil }
    for i, config in ipairs(configurationSets) do
        local count, match = 0, true

        for k, v in pairs(config.configurations or {}) do
            if vehicle.configurations[k] == v then
                count = count + 1
            else
                match = false
            end
        end

        if match then
            local fullConfigId = i .. (configName and ("|" .. configName) or "")
            return fullConfigId, i, config.name
        elseif count > bestMatch.count then
            bestMatch = { index = i, count = count, name = config.name }
        end
    end

    if bestMatch.index then
        local fullConfigId = bestMatch.index .. (configName and ("|" .. configName) or "")
        return fullConfigId, bestMatch.index, bestMatch.name
    end
end

function UniversalAutoloadManager.saveConfigurationToSettings(exportSpec, noEventSend)
	local serverOrClient = g_currentMission:getIsServer() and "SERVER" or "CLIENT"
	print(serverOrClient .. ": SAVE UAL CONFIGURATION for " .. tostring(exportSpec.configFileName))
	
	if not exportSpec or not exportSpec.configFileName then
		print("valid UAL spec is required to save settings")
		return
	end
	
	UniversalAutoloadManager.saveVehicleConfigToSettingsXML(exportSpec)

	if g_currentMission:getIsClient() and not g_currentMission:getIsServer() then
		UniversalAutoload.UpdateDefaultSettingsEvent.sendEvent(exportSpec, noEventSend)
	end

end

function UniversalAutoloadManager.exportVehicleConfigToServer()
	
	if g_localPlayer and g_localPlayer.isClient then

		print("SAVE SETTINGS FROM SHOP VEHICLE")
		local shopVolume = UniversalAutoloadManager.shopConfig and UniversalAutoloadManager.shopConfig.loadingVolume
		if not shopVolume or not shopVolume.bbs then
			print("NOTHING TO SAVE: shopVolume or shopVolume.bbs is nil")
			return
		end
		
		local exportVehicle = nil
		if UniversalAutoloadManager.shopVehicle then
			exportVehicle = UniversalAutoloadManager.shopVehicle
		end

		if exportVehicle and exportVehicle.configFileName then
			
			if exportVehicle.spec_universalAutoload.autoloadDisabled then
				print("Autoload is DISABLED for this vehicle")
			end

			print("..convert shop volume to loading area")
			local exportSpec = exportVehicle.spec_universalAutoload
			exportSpec.loadArea = exportSpec.loadArea or {}
			for i, boundingBox in (shopVolume.bbs) do
				local s = boundingBox:getSize()
				local o = boundingBox:getOffset()
				exportSpec.loadArea[i] = exportSpec.loadArea[i] or {}
				exportSpec.loadArea[i].width = s.x
				exportSpec.loadArea[i].height = s.y
				exportSpec.loadArea[i].length = s.z
				exportSpec.loadArea[i].offset = {o.x, o.y-s.y/2, o.z}
			end

			local configFileName, configId = UniversalAutoloadManager.getVehicleConfigNames(exportVehicle)
			
			UniversalAutoloadManager.saveConfigurationToSettings(exportSpec)

		end
	end
end

function UniversalAutoloadManager:onVehicleBuyEvent(errorCode, leaseVehicle, price)
	if errorCode == BuyVehicleEvent.STATE_SUCCESS then
		print("UAL - ON VEHICLE BUY EVENT " .. (leaseVehicle and "(leased)" or "(owned)"))
		-- do nothing here for now..
		-- UniversalAutoloadManager.saveShopConfiguration()
	end
end

function UniversalAutoloadManager.getValidXmlName(ualConfigName)

	if ualConfigName == nil then
		return
	end
	
	local xmlFilename = ualConfigName
	if g_storeManager:getItemByXMLFilename(xmlFilename) then
		return xmlFilename
	end
	
	xmlFilename = g_modsDirectory .. ualConfigName
	if g_storeManager:getItemByXMLFilename(xmlFilename) then
		return xmlFilename
	end
	
	for i = 1, #g_dlcsDirectories do
		local dlcsDir = g_dlcsDirectories[i].path
		xmlFilename = dlcsDir .. ualConfigName
		if g_storeManager:getItemByXMLFilename(xmlFilename) then
			return xmlFilename
		end
	end

end

function UniversalAutoloadManager.cleanConfigFileName(configFileName)

	if configFileName == nil then
		return
	end

	if configFileName:find(g_modsDirectory, 1, true) then
		-- print("CLEANED MOD FILE NAME")
		return configFileName:sub(#g_modsDirectory + 1), g_modsDirectory
	end
	
	for i = 1, #g_dlcsDirectories do
		local dlcsDir = g_dlcsDirectories[i].path
		
		if configFileName:find(dlcsDir, 1, true) then
			-- print("CLEANED DLC FILE NAME")
			return configFileName:sub(#dlcsDir + 1), dlcsDir
		end
	end
	
	return configFileName
end

function UniversalAutoloadManager.injectSpecialisation()
	-- print("UAL - injectSpecialisation")
	for typeName, vehicleType in pairs(g_vehicleTypeManager.types) do
		if SpecializationUtil.hasSpecialization(TensionBelts, vehicleType.specializations)
		and not SpecializationUtil.hasSpecialization(UniversalAutoload, vehicleType.specializations) then
			g_vehicleTypeManager:addSpecialization(typeName, UniversalAutoload.name .. '.universalAutoload')
			UniversalAutoload.VEHICLE_TYPES[typeName] = true
		end
	end
end

function UniversalAutoloadManager:ualInputCallback(target)
	print("UAL SHOP INPUT CALLBACK")
	UniversalAutoloadManager:onOpenSettingsEvent('UNIVERSALAUTOLOAD_SHOP_CONFIG', 1)
end
ShopConfigScreen.ualInputCallback = UniversalAutoloadManager.ualInputCallback

function UniversalAutoloadManager:onOpenSettingsEvent(actionName, inputValue, callbackState, isAnalog)
	-- print("onOpenSettingsEvent")
	if UniversalAutoloadManager.shopCongfigMenu then
		g_gui:showDialog("ShopConfigMenuUALSettings")
	end
end

function UniversalAutoloadManager:onOpenGlobalSettingsEvent(actionName, inputValue, callbackState, isAnalog)
	-- print("onOpenGlobalSettingsEvent")
	if UniversalAutoloadManager.globalSettingsMenu then
		g_gui:showDialog("GlobalSettingsMenuUALSettings")
	end
end

function UniversalAutoloadManager:onEditLoadingAreaEvent(actionName, inputValue, callbackState, isAnalog)
	-- print("onEditLoadingAreaEvent")
	if UniversalAutoloadManager.shopVehicle then
		local spec = UniversalAutoloadManager.shopVehicle.spec_universalAutoload
		if spec and spec.isInsideShop then
			local shopConfig = UniversalAutoloadManager.shopConfig or {}

			UniversalAutoloadManager.pauseOnNextStep = nil
			local ctrl = UniversalAutoloadManager.ctrlHeld
			local shift = UniversalAutoloadManager.shiftHeld
			if shift and ctrl then
				spec.resetToDefault = true
			else
				shopConfig.enableEditing = shopConfig.enableEditing or false
				shopConfig.enableEditing = not shopConfig.enableEditing
			end

		end
	end
end

function UniversalAutoloadManager.onSetStoreItem()
	
	local buyButton = g_shopConfigScreen.buyButton
	local buyButtonCloned = buyButton and buyButton == UniversalAutoloadManager.buyButton
	if not UniversalAutoloadManager.configButton or not buyButtonCloned then
		print("INJECT UAL configButton")
		local function cloneButton(original, title, callback)
			local button = original:clone(original.parent)
			button:setText(title)
			button:setVisible(false)
			button:setCallback("onClickCallback", callback)
			button:setInputAction(InputAction.UNIVERSALAUTOLOAD_SHOP_CONFIG)
			button.parent:invalidateLayout()
			return button
		end
		local button = cloneButton(buyButton, g_i18n:getText("shop_configuration_text"), "ualInputCallback");
		UniversalAutoloadManager.configButton = button
		UniversalAutoloadManager.buyButton = buyButton
	end
	if UniversalAutoloadManager.configButton then
		UniversalAutoloadManager.configButton:setVisible(false)
	end
	if UniversalAutoloadManager.shopCongfigMenu then
		UniversalAutoloadManager.shopCongfigMenu:setNewVehicle(nil)
	end
end
ShopConfigScreen.setStoreItem = Utils.prependedFunction(ShopConfigScreen.setStoreItem, UniversalAutoloadManager.onSetStoreItem)

function UniversalAutoloadManager.onInputEvent(self, superFunc, action, value, eventUsed)
	if not eventUsed and action == InputAction.UNIVERSALAUTOLOAD_SHOP_CONFIG then
		UniversalAutoloadManager:ualInputCallback(target)
		eventUsed = true
	end
	return superFunc(self, action, value, eventUsed)
end
ShopConfigScreen.inputEvent = Utils.overwrittenFunction(ShopConfigScreen.inputEvent, UniversalAutoloadManager.onInputEvent)

function UniversalAutoloadManager.onBuyEvent(self, yes)
	if yes == true then
		UniversalAutoloadManager.exportVehicleConfigToServer()
	end
end
ShopConfigScreen.onYesNoBuy = Utils.prependedFunction(ShopConfigScreen.onYesNoBuy, UniversalAutoloadManager.onBuyEvent)
ShopConfigScreen.onYesNoLease = Utils.prependedFunction(ShopConfigScreen.onYesNoLease, UniversalAutoloadManager.onBuyEvent)

-- ENABLE WORKSHOP CONFIG BUTTON FOR AUTOLOAD VEHICLES
-- ShopConfigScreen.getConfigurationCostsAndChanges = Utils.overwrittenFunction(ShopConfigScreen.getConfigurationCostsAndChanges,
-- function(self, superFunc, storeItem, vehicle, saleItem)
	-- local basePrice, upgradePrice, hasChanges = superFunc(self, storeItem, vehicle, saleItem)
	
	-- if hasChanges == false then
		-- local spec = vehicle and vehicle.spec_universalAutoload
		-- if spec and spec.isAutoloadAvailable then
			-- hasChanges = true
			-- UniversalAutoloadManager.resetNewVehicle = vehicle
		-- end
	-- end
	-- return basePrice, upgradePrice, hasChanges
-- end)

-- InGameMenuSettingsFrame.initializeSubCategoryPages = Utils.prependedFunction(InGameMenuSettingsFrame.initializeSubCategoryPages,
-- function(self)
	-- if not InGameMenuSettingsFrame.SUB_CATEGORY["MOD_SETTINGS"] then
		-- print("initializeSubCategoryPages")
		-- print("g_inGameMenu: " .. tostring(g_inGameMenu))
		-- local N = 1
		-- for _ in pairs(InGameMenuSettingsFrame.SUB_CATEGORY) do
			-- N = N + 1
		-- end
		-- InGameMenuSettingsFrame.SUB_CATEGORY["MOD_SETTINGS"] = N
		-- InGameMenuSettingsFrame.HEADER_TITLES[N] = "MOD SETTINGS"
		-- InGameMenuSettingsFrame.HEADER_SLICES[N] = "gui.icon_options_device"
		-- local other = g_inGameMenu.subCategoryBox.elements[2]
		-- local modSettingsMenu = other:clone(other.parent)
		-- modSettingsMenu.id = string.format("subCategoryTabs[%d]", N)
		-- modSettingsMenu.text = InGameMenuSettingsFrame.HEADER_TITLES[N]
		-- modSettingsMenu.sourceText = InGameMenuSettingsFrame.HEADER_TITLES[N]
		-- modSettingsMenu.focusId = FocusManager:serveAutoFocusId()
		-- g_inGameMenu.subCategoryBox.elements[N] = modSettingsMenu
		-- g_inGameMenu.subCategoryBox:invalidateLayout()
		-- -- print("*******subCategoryBox.elements[2]*******")
		-- -- DebugUtil.printTableRecursively(g_inGameMenu.subCategoryBox.elements[2], "--", 0, 1)
		-- -- print("*******subCategoryBox.elements[N]*******")
		-- -- DebugUtil.printTableRecursively(g_inGameMenu.subCategoryBox.elements[N], "--", 0, 1)
		-- -- print("******* g_inGameMenu *******")
		-- -- DebugUtil.printTableRecursively(g_inGameMenu, "--", 0, 2)
	-- end
-- end)


function UniversalAutoloadManager:mouseEvent(posX, posY, isDown, isUp, button)
	
	if UniversalAutoloadManager.shopVehicle then

		local spec = UniversalAutoloadManager.shopVehicle.spec_universalAutoload
		if spec and spec.isInsideShop and not spec.autoloadDisabled then
			local shopConfig = UniversalAutoloadManager.shopConfig or {}
			
			if button == 3 and isUp then
				shopConfig.selected = nil
			end
			
			if spec.loadingVolume and spec.loadingVolume.state == LoadingVolume.STATE.SHOP_CONFIG then
				
				local function isPointSelected(point)
					local sx, sy, _ = project(point[1], point[2], point[3])		
					if math.abs(posX - sx) < 0.005 and math.abs(posY - sy) < 0.005 then
						return true
					end
				end
				
				for n, bb in pairs(spec.loadingVolume.bbs) do
					local centre, points, names = bb:getCubeFaces()
					for i, point in pairs(points or {}) do

						if isPointSelected(point) then
							if button == 3 and isDown then
								shopConfig.selected = {n, i}
								shopConfig.control = UniversalAutoloadManager.ctrlHeld or false
								shopConfig.shift = UniversalAutoloadManager.shiftHeld or false
								shopConfig.alt = UniversalAutoloadManager.altHeld or false
							else
								if not shopConfig.grabbedPoint then
									shopConfig.hovered = {n, i}
								end
							end
						else
							local hovered = shopConfig.hovered
							if hovered and n==hovered[1] and i==hovered[2] then
								shopConfig.hovered = {0, 0}
							end
						end
					end
				end

				shopConfig.mousePos = {posX, posY}

			end
		end
	end
	
end

function UniversalAutoloadManager:keyEvent(unicode, sym, modifier, isDown)

	if UniversalAutoloadManager.shopVehicle and UniversalAutoloadManager.shopConfig then
		
		local spec = UniversalAutoloadManager.shopVehicle.spec_universalAutoload
		if spec and spec.isInsideShop then

			if sym == Input['KEY_lalt'] then
				UniversalAutoloadManager.altHeld = isDown
				return
			end
			if sym == Input['KEY_lctrl'] then
				UniversalAutoloadManager.ctrlHeld = isDown
				return
			end
			if sym == Input['KEY_lshift'] then
				UniversalAutoloadManager.shiftHeld = isDown
				return
			end
			
		end
	end

end

function UniversalAutoloadManager.createGlobalGui()
	-- print("UAL - createGlobalGui")
	if not UniversalAutoloadManager.globalSettingsMenu then
		UniversalAutoloadManager.globalSettingsMenu = GlobalSettingsMenuUALSettings.register()
	end
end
function UniversalAutoloadManager.deleteGlobalGui()
	-- print("UAL - deleteGlobalGui")
	if UniversalAutoloadManager.globalSettingsMenu then
		-- print("UAL - DELETE GLOBAL MENU")
		UniversalAutoloadManager.globalSettingsMenu:delete()
		UniversalAutoloadManager.globalSettingsMenu = nil
	end
end

function UniversalAutoloadManager.createShopGui()
	-- print("UAL - createShopGui")
	if not UniversalAutoloadManager.shopCongfigMenu then
		UniversalAutoloadManager.shopCongfigMenu = ShopConfigMenuUALSettings.register()
	end
end
function UniversalAutoloadManager.deleteShopGui()
	-- print("UAL - deleteShopGui")
	if UniversalAutoloadManager.configButton then
		-- print("UAL - DELETE BUTTON")
		UniversalAutoloadManager.configButton:delete()
		UniversalAutoloadManager.configButton = nil
	end
	if UniversalAutoloadManager.shopCongfigMenu then
		-- print("UAL - DELETE CONFIG MENU")
		UniversalAutoloadManager.shopCongfigMenu:delete()
		UniversalAutoloadManager.shopCongfigMenu = nil
	end
end

function UniversalAutoloadManager:registerShopActionEvents()
	-- print("UAL - registerShopActionEvents")
	local function registerShopActionEvent(id, callback)
		local id = id or 'UNIVERSALAUTOLOAD_SHOP_CONFIG'
		local callback = callback or 'ualInputCallback'
		local triggerUp = false
		local triggerDown = true
		local triggerAlways = false
		local startActive = true
		local valid, actionId = g_inputBinding:registerActionEvent(InputAction[id],
			self, self[callback], triggerUp, triggerDown, triggerAlways, startActive)
		local nameAction = g_inputBinding.nameActions[id]
		UniversalAutoloadManager.actionIds = UniversalAutoloadManager.actionIds or {}
		table.insert(UniversalAutoloadManager.actionIds, actionId)
	end
	
	registerShopActionEvent('UNIVERSALAUTOLOAD_SHOP_CONFIG', 'onOpenSettingsEvent')
	registerShopActionEvent('UNIVERSALAUTOLOAD_SHOP_ADJUST', 'onEditLoadingAreaEvent')
end
function UniversalAutoloadManager:removeShopActionEvents()
	-- print("UAL - removeShopActionEvents")
	UniversalAutoloadManager.actionIds = UniversalAutoloadManager.actionIds or {}
	for _, actionId in pairs(UniversalAutoloadManager.actionIds) do
		g_inputBinding:removeActionEvent(actionId)
		UniversalAutoloadManager.actionIds[actionId] = nil
	end
end

function UniversalAutoloadManager.onValidUalShopVehicle(vehicle)
	if vehicle.propertyState == VehiclePropertyState.SHOP_CONFIG then
		UniversalAutoloadManager:registerShopActionEvents()
		if UniversalAutoloadManager.configButton then
			UniversalAutoloadManager.configButton:setVisible(true)
			if UniversalAutoloadManager.configButton.parent then
				UniversalAutoloadManager.configButton.parent:invalidateLayout()
			end
		end
		if UniversalAutoloadManager.shopCongfigMenu then
			UniversalAutoloadManager.shopCongfigMenu:setNewVehicle(vehicle)
		end
	end
end

function UniversalAutoloadManager.onInvalidUalShopVehicle(vehicle)
	if vehicle.propertyState == VehiclePropertyState.SHOP_CONFIG then
		UniversalAutoloadManager:removeShopActionEvents()
		if UniversalAutoloadManager.configButton then
			UniversalAutoloadManager.configButton:setVisible(false)
		end
		if UniversalAutoloadManager.shopCongfigMenu then
			UniversalAutoloadManager.shopCongfigMenu:setNewVehicle(nil)
		end
	end
end

-- AUTO CREATE LOADING VOLUMES
function UniversalAutoloadManager.editLoadingVolumeInsideShop(vehicle)
	local spec = vehicle.spec_universalAutoload
	
	if spec.loadingVolume.state == LoadingVolume.STATE.SHOP_CONFIG then

		local shopConfig = UniversalAutoloadManager.shopConfig
		if not shopConfig or not shopConfig.enableEditing then
			return
		end
		
		local selected = shopConfig.selected
		local mousePos = shopConfig.mousePos
		local ctrlHeld = shopConfig.control
		local shiftHeld = shopConfig.shift
		local altHeld = shopConfig.alt

		if selected and mousePos and selected[1] > 0 and selected[2] > 0 then
			local n = selected[1]
			local i = selected[2]
			local X = mousePos[1]
			local Y = mousePos[2]
			
			local bb = spec.loadingVolume.bbs[n]
			local centre, points, names = bb:getCubeFaces()
			
			if UniversalAutoloadManager.shopConfig.grabbedPoint == nil then
				UniversalAutoloadManager.shopConfig.grabbedPoint = points[i]
				UniversalAutoloadManager.shopConfig.originalPoint = {points[i][1], points[i][2], points[i][3]}
				UniversalAutoloadManager.shopConfig.clickOffset = nil
			end

			local function expandAxis(p1, p2, showAxis)
				-- Get camera position and points in world space
				local camX, camY, camZ = getWorldTranslation(getCamera())
				local grabbedPoint = UniversalAutoloadManager.shopConfig.grabbedPoint
				local pX, pY, pZ = unpack(grabbedPoint)
				local lx1, ly1, lz1 = unpack(p1)
				local lx2, ly2, lz2 = unpack(p2)
				
				if lx2-lx1 == 0 and ly2-ly1 == 0 and lz2-lz1 == 0 then
					print("don't divide by zero")
					return 0, 0, 0
				end
				
				-- Calculate normalized direction and distance
				local lineDx, lineDy, lineDz = MathUtil.vector3Normalize(lx2-lx1, ly2-ly1, lz2-lz1)
				local distance = MathUtil.vector3Length(pX-camX, pY-camY, pZ-camZ)

				-- Adjust mouse position based on ctrlHeld for finer control
				local mouseX, mouseY, mouseZ = unProject(X, Y, distance / 10)
				if ctrlHeld then
					local scale = 0.35
					local pX0, pY0, pZ0 = unpack(UniversalAutoloadManager.shopConfig.originalPoint)
					mouseX = pX0 + (mouseX - pX0) * scale
					mouseY = pY0 + (mouseY - pY0) * scale
					mouseZ = pZ0 + (mouseZ - pZ0) * scale
				end
				
				-- Calculate normalized mouse direction and camera-to-line vector
				local mouseDx, mouseDy, mouseDz = MathUtil.vector3Normalize(mouseX - camX, mouseY - camY, mouseZ - camZ)
				local camToLineX, camToLineY, camToLineZ = pX - camX, pY - camY, pZ - camZ

				-- Calculate s and t parameters for closest points
				local dotMouseRayLine = mouseDx * lineDx + mouseDy * lineDy + mouseDz * lineDz
				local denom = 1 - dotMouseRayLine ^ 2
				local s = (dotMouseRayLine * (camToLineX * lineDx + camToLineY * lineDy + camToLineZ * lineDz) 
						   - (camToLineX * mouseDx + camToLineY * mouseDy + camToLineZ * mouseDz)) / denom
				local t = dotMouseRayLine * s + (camToLineX * lineDx + camToLineY * lineDy + camToLineZ * lineDz)

				-- Determine new points based on s and t values
				local mouseRayX, mouseRayY, mouseRayZ = camX - s * mouseDx, camY - s * mouseDy, camZ - s * mouseDz
				local newPointX, newPointY, newPointZ = pX - t * lineDx, pY - t * lineDy, pZ - t * lineDz

				-- Visualize axis and debug lines if required
				if showAxis then
					drawDebugLine(p1[1], p1[2], p1[3], 1, 0.5, 1, p2[1], p2[2], p2[3], 1, 0.5, 1)
				end
				if showDebug then
					drawDebugLine(camX, camY-0.02, camZ, 1, 0, 0, p1[1], p1[2], p1[3], 1, 0, 0)
					drawDebugLine(camX, camY-0.02, camZ, 0, 1, 0, newPointX, newPointY, newPointZ, 0, 1, 0)
					drawDebugLine(newPointX, newPointY, newPointZ, 1, 1, 1, mouseRayX, mouseRayY, mouseRayZ, 1, 1, 1)
				end
				
				-- Offset calculation with existing click offset
				if not UniversalAutoloadManager.shopConfig.clickOffset then
					UniversalAutoloadManager.shopConfig.clickOffset = {newPointX-pX, newPointY-pY, newPointZ-pZ}
				end
				local cX, cY, cZ = unpack(UniversalAutoloadManager.shopConfig.clickOffset)
				return newPointX-pX-cX, newPointY-pY-cY, newPointZ-pZ-cZ

			end
			
			local function handleAxisMovement(i, bb, points, altHeld, shiftHeld)
				local axisPairs = {
					{1, 2}, -- left/right
					{2, 1}, -- right/left
					{3, 4}, -- top/bottom
					{4, 3}, -- bottom/top
					{5, 6}, -- front/back
					{6, 5}  -- back/front
				}

				local dx, dy, dz = expandAxis(points[axisPairs[i][1]], points[axisPairs[i][2]], altHeld or shiftHeld)
				local delta = (i <= 2 and dx) or (i <= 4 and dy) or dz
				
				if delta and delta ~= 0 then
					if not shiftHeld and not altHeld then
						bb:moveFace(i, delta)
					elseif shiftHeld and not altHeld then
						bb:moveFace(axisPairs[i][1], delta/2)
						bb:moveFace(axisPairs[i][2], delta/2)
					elseif altHeld and not shiftHeld then
						bb:moveFace(axisPairs[i][1], delta/2)
						bb:moveFace(axisPairs[i][2], -delta/2)
					end
				end
			end
			
			handleAxisMovement(i, bb, points, altHeld, shiftHeld)
			
		else
			if UniversalAutoloadManager.shopConfig.grabbedPoint then
				UniversalAutoloadManager.shopConfig.grabbedPoint = nil
				for n, bb in pairs(spec.loadingVolume.bbs) do
					bb:update()
				end
			end
		end
	end
end

function UniversalAutoloadManager.createLoadingVolumeInsideShop(vehicle)
	local spec = vehicle.spec_universalAutoload
	
	if not spec.skipFirstUpdate then
		spec.skipFirstUpdate = true
		return
	end
	
	if UniversalAutoloadManager.pauseOnNextStep then
		return
	end
	
	if not spec.loadingVolume then
		print("findTensionBelts")
		spec.loadingVolume = LoadingVolume.new(vehicle)
		spec.loadingVolume:findTensionBelts()
		UniversalAutoloadManager.pauseOnNextStep = UniversalAutoloadManager.DEBUG_STEPS
	elseif spec.loadingVolume.state == LoadingVolume.STATE.FOUND_BELTS then
		print("findLoadingSurface")
		spec.loadingVolume:findLoadingSurface()
		UniversalAutoloadManager.pauseOnNextStep = UniversalAutoloadManager.DEBUG_STEPS
	elseif spec.loadingVolume.state == LoadingVolume.STATE.FOUND_SURFACE then
		print("expandLoadingSurface")
		spec.loadingVolume:expandLoadingSurface()
		UniversalAutoloadManager.pauseOnNextStep = UniversalAutoloadManager.DEBUG_STEPS
	elseif spec.loadingVolume.state == LoadingVolume.STATE.EXPANDED then
		print("INIT SHOP CONFIG")
		spec.loadingVolume:initShopConfig()
		UniversalAutoloadManager.pauseOnNextStep = nil
	end
	
end

function UniversalAutoloadManager.resetLoadingVolumeForShopEdit(vehicle)
	local spec = vehicle.spec_universalAutoload
	
	if not spec.skipFirstUpdate then
		spec.skipFirstUpdate = true
		return
	end
	
	if not vehicle.rootNode then
		print("*** Vehicle Root Node is UNDEFINED ***")
		return
	end
	
	if not spec.loadArea or #spec.loadArea == 0 then
		if not spec.printInvalidLocalConfig then
			spec.printInvalidLocalConfig = true
			print("INVALID LOCAL CONFIG - load areas missing")
		end
	end

	if spec.loadArea and #spec.loadArea > 0 and not spec.loadingVolume then
		print("CONVERT CURRENT LOCAL CONFIG TO LOADING VOLUME")
		spec.loadingVolume = LoadingVolume.new(vehicle)
		
		for i, loadArea in ipairs(spec.loadArea) do
			local width = loadArea.width
			local height = loadArea.height
			local length = loadArea.length
			local offset = loadArea.offset

			local boundingBox = BoundingBox.new(vehicle.rootNode,
				{x=width, y=height, z=length},
				{x=offset[1], y=offset[2] + height/2, z=offset[3]}
			)
			spec.loadingVolume.bbs[i] = boundingBox
		end

		spec.loadingVolume:initShopConfig()
		UniversalAutoloadManager.pauseOnNextStep = nil
	end
	
end

function UniversalAutoloadManager.getIsTrainCarriage(vehicle)
	if not vehicle then
		return false
	end

	if vehicle:getFullName():find("Timber Wagon")
	or vehicle:getFullName():find("Flatbed Wagon")
	or vehicle:getFullName():find("Vehicle Wagon") then
		return true
	end
end

function UniversalAutoloadManager.getIsValidForAutoload(vehicle)
	local spec = vehicle and vehicle.spec_universalAutoload
	if not spec then
		print("UAL - new vehicle should have SPEC here " .. tostring(vehicle and vehicle.rootNode))
		return
	end
	
	if UniversalAutoloadManager.getIsTrainCarriage(vehicle) then
		print(vehicle:getFullName() .. " - TRAIN CARRIAGE")
		return true
	end
	
	local isValidForAutoload = nil
	if vehicle.spec_tensionBelts and vehicle.spec_tensionBelts.hasTensionBelts then
		local nBelts = #vehicle.spec_tensionBelts.sortedBelts
		if nBelts >= 2 then
			print(vehicle:getFullName() .. ": UAL - tension belts (" .. nBelts .. ")")
			spec.hasTensionBelts = true
			isValidForAutoload = true
		else
			print("Not enough tension belts for UAL (" .. nBelts .. ")")
		end
	end
	
	if vehicle.spec_fillVolume and #vehicle.spec_fillVolume.volumes > 0 then
		local nFillVol = #vehicle.spec_fillVolume.volumes
		print(vehicle:getFullName() .. ": UAL - fill volumes (" .. nFillVol .. ")")
		for i, fillVolume in ipairs(vehicle.spec_fillVolume.volumes) do
			local capacity = vehicle:getFillUnitCapacity(fillVolume.fillUnitIndex)
			print("  [" .. i .. "] = " .. capacity)
		end
		spec.hasFillVolume = true
		-- isValidForAutoload = false
	end
	
	return isValidForAutoload
end

function UniversalAutoloadManager.addLocalConfigIfAvailable(vehicle)
	local spec = vehicle and vehicle.spec_universalAutoload
	
	local configurationAdded = nil
	
	local configFileName = UniversalAutoloadManager.cleanConfigFileName(vehicle.configFileName)
	local availableConfigs = UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName]
	
	if availableConfigs then
		print("AVAILABLE selectedConfigs: ")
		local i = 1
		for selectedConfigs, config in pairs(availableConfigs) do
			print(" [".. i .. "] " .. selectedConfigs)
			local j = 1
			local selectedConfigsList = tostring(selectedConfigs):split(",")
			for _, configListItem in pairs(selectedConfigsList) do
				if configListItem ~= selectedConfigs then
					print("  #".. j .. " " .. configListItem)
				end
				
				local isMatchAny = tostring(configListItem):find(UniversalAutoload.ALL)
				local hasPipeChar = tostring(configListItem):find("|")
				
				if hasPipeChar then
					print("  useConfigName: " .. tostring(config.useConfigName))
					if not spec.useConfigName then
						spec.useConfigName = config.useConfigName
					end
				end
				j = j + 1
			end
			i = i + 1
		end
	end
	
	if spec.useConfigName then
		print("SET useConfigName: " .. tostring(spec.useConfigName))
	end

	local fullConfigId, rootConfigId, description = UniversalAutoloadManager.getValidConfigurationId(vehicle)
	if fullConfigId then
		
		print("UniversalAutoload - supported vehicle: "..vehicle:getFullName().." #"..fullConfigId.." ("..description..")" )
		spec.configId = rootConfigId  -- used for shop config setting

		if configFileName == "data/vehicles/krone/profiLiner/profiLiner.xml" then
			spec.isCurtainTrailer = true
		end
	
		local target = vehicle and vehicle.loadCallbackFunctionTarget
		local storeItem = target and target.storeItem
		local category = storeItem and storeItem.categoryName
		local isBaleLoader = category and category == 'BALELOADERS'
		local isWoodTransport = category and category == 'WOODTRANSPORT'
		local isForestryForwarder = category and category == 'FORESTRYFORWARDERS'
		local isBaleWagon = description and description == g_i18n:getText("configuration_valueLoadingWagon")
		
		if isBaleLoader or isBaleWagon then
			print("IDENTIFIED BALE TRAILER")
			spec.isBaleTrailer = true
			spec.horizontalLoading = true
		end
		
		if isWoodTransport or isForestryForwarder then
			print("IDENTIFIED LOG TRAILER")
			spec.isLogTrailer = true
		end

		if availableConfigs then
			print("DETECTED fullConfigId: " .. fullConfigId)
			local firstPart, secondPart = string.match(fullConfigId, "([^|]+)|([^|]+)")
			if not firstPart then
				firstPart = fullConfigId
				secondPart = nil
			end
			if not firstPart == rootConfigId then
				print("WARNING: rootConfigId = " .. rootConfigId)
			end
			
			for selectedConfigs, config in pairs(availableConfigs) do
				print("TRY selectedConfigs: " .. selectedConfigs)
				local selectedConfigsList = tostring(selectedConfigs):split(",")
				for _, configListItem in pairs(selectedConfigsList) do
					if configListItem ~= selectedConfigs then
						print(" configListItem: " .. configListItem)
					end
					local otherFirstPart, otherSecondPart = string.match(configListItem, "([^|]+)|([^|]+)")
					if not otherFirstPart then
						otherFirstPart = configListItem
						otherSecondPart = nil
					end

					local isMatchFirst = otherFirstPart == firstPart or otherFirstPart == UniversalAutoload.ALL
					local isMatchSecond = secondPart and otherSecondPart and secondPart == otherSecondPart
					local ignoreSecondParts = secondPart == nil and otherSecondPart == nil
					
					if isMatchFirst and (isMatchSecond or ignoreSecondParts) then
						if config and config.loadArea and #config.loadArea > 0 then
							print("*** USING CONFIG FROM SETTINGS - "..selectedConfigs.." for #"..fullConfigId.." ("..description..") ***")
							spec.configId = otherFirstPart  -- used for shop config setting
							
							for id, value in pairs(deepCopy(config)) do
								print(" >> " .. tostring(id) .. " = " .. tostring(value))
								spec[id] = value
							end
							configurationAdded = true
							break
						else
							print("*** LOAD AREA MISSING FROM CONFIG - please check mod settings file ***")
							DebugUtil.printTableRecursively(config, "  --", 0, 2)
						end
					end
				end
				if configurationAdded == true then
					break
				end
			end
			
			if not configurationAdded then
				print("*** NO MATCHING LOCAL CONFIG - #"..fullConfigId.." ("..description..") ***")
			end
		else
			print("*** NO LOCAL CONFIGS AVAILABLE - #"..fullConfigId.." ("..description..") ***")
		end
	else
		print("*** UNSUPPORTED CONFIG - #"..tostring(fullConfigId).." ("..tostring(description)..") ***")
	end
	return configurationAdded
end

function UniversalAutoloadManager.handleNewVehicleCreation(vehicle)
	local spec = vehicle and vehicle.spec_universalAutoload
	if not spec then
		print("UAL - new vehicle should have SPEC here " .. tostring(vehicle and vehicle.rootNode))
		return
	end
	print("handleNewVehicleCreation: " .. tostring(netGetTime()))

	local configurationAdded = UniversalAutoloadManager.addLocalConfigIfAvailable(vehicle)
		
	if vehicle.propertyState == VehiclePropertyState.SHOP_CONFIG then
		print("CREATE SHOP VEHICLE: " .. vehicle:getFullName())
		spec.isInsideShop = true
		UniversalAutoloadManager.shopVehicle = vehicle
		return configurationAdded
		
	elseif vehicle.propertyState == VehiclePropertyState.OWNED
		or vehicle.propertyState == VehiclePropertyState.LEASED
		or vehicle.propertyState == VehiclePropertyState.MISSION then
		print("CREATE REAL VEHICLE: " .. vehicle:getFullName())
		spec.isInsideShop = false
		return configurationAdded
	end
end

-- DETECT CONFLICTS/ISSUES
function UniversalAutoloadManager.detectKeybindingConflicts()
	--DETECT 'T' KEYS CONFLICT
	if g_currentMission.missionDynamicInfo.isMultiplayer and not g_dedicatedServer then

		local chatKey = ""
		local containerKey = "KEY_t"
		local xmlFile = loadXMLFile('TempXML', g_inputBinding.settingsPath)	
		local actionBindingCounter = 0
		if xmlFile ~= 0 then
			while true do
				local key = string.format('inputBinding.actionBinding(%d)', actionBindingCounter)
				local actionString = getXMLString(xmlFile, key .. '#action')
				if actionString == nil then
					break
				end
				if actionString == 'CHAT' then
					local i = 0
					while true do
						local bindingKey = key .. string.format('.binding(%d)',i)
						local bindingInput = getXMLString(xmlFile, bindingKey .. '#input')
						if bindingInput == "KEY_t" then
							print("  Using 'KEY_t' for 'CHAT'")
							chatKey = bindingInput
						elseif bindingInput == nil then
							break
						end

						i = i + 1
					end
				end
				
				if actionString == 'UNIVERSALAUTOLOAD_CYCLE_CONTAINER_FW' then
					local i = 0
					while true do
						local bindingKey = key .. string.format('.binding(%d)',i)
						local bindingInput = getXMLString(xmlFile, bindingKey .. '#input')
						if bindingInput ~= nil then
							print("  Using '"..bindingInput.."' for 'CYCLE_CONTAINER'")
							containerKey = bindingInput
						elseif bindingInput == nil then
							break
						end

						i = i + 1
					end
				end
				
				actionBindingCounter = actionBindingCounter + 1
			end
		end
		delete(xmlFile)
		
		if chatKey == containerKey then
			print("**CHAT KEY CONFLICT DETECTED** - Disabling CYCLE_CONTAINER for Multiplayer")
			print("(Please reassign 'CHAT' or 'CYCLE_CONTAINER' to a different key and RESTART the game)")
			UniversalAutoload.chatKeyConflict = true
		end
		
	end
end

-- CONSOLE FUNCTIONS
function UniversalAutoloadManager:consoleResetVehicles()

	if g_gui.currentGuiName == "ShopMenu" or g_gui.currentGuiName == "ShopConfigScreen" then
		return "Reset vehicles is not supported while in shop!"
	end
	
	UniversalAutoloadManager.resetList = {}
	UniversalAutoloadManager.resetCount = 1
	g_currentMission.isReloadingVehicles = true
	
	for _, vehicle in pairs(UniversalAutoload.VEHICLES) do
		table.insert(UniversalAutoloadManager.resetList, vehicle)
	end
	UniversalAutoload.VEHICLES = {}
	print(string.format("Resetting %d vehicles now..", #UniversalAutoloadManager.resetList))
	
	UniversalAutoloadManager.resetNextVehicle()
	
end
--
function UniversalAutoloadManager:consoleAddPallets(palletType)
	
    local pallets = {}
    for _, fillType in pairs(g_fillTypeManager:getFillTypes()) do
		local xmlName = fillType.palletFilename
		if xmlName ~= nil and not xmlName:find("fillablePallet") then
            pallets[fillType.name] = xmlName
        end
    end

 	if palletType then
		palletType = string.upper(palletType or "")
		local xmlFilename = pallets[palletType]
		if xmlFilename == nil then
			return "Error: Invalid pallet type. Valid types are " .. table.concatKeys(pallets, ", ")
		end

		pallets = {}
		pallets[palletType] = xmlFilename
	end

	local currentVehicle = g_localPlayer and g_localPlayer.getCurrentVehicle()
	if currentVehicle then

		local vehicles = UniversalAutoloadManager.getAttachedVehicles(currentVehicle)
		local count = 0
		
		if next(vehicles) ~= nil then
			for vehicle, hasAutoload in pairs(vehicles) do
				if hasAutoload and vehicle:getIsActiveForInput() then
					if UniversalAutoload.createPallets(vehicle, pallets) then
						count = count + 1
					end
				end
			end
		end
	
		if count>0 then return "Begin adding pallets now.." end
	end
	return "Please enter a vehicle with a UAL trailer attached to use this command"
end
--
function UniversalAutoloadManager:consoleAddLogs(arg1, arg2)

	local length = nil
	local treeTypeName = "LODGEPOLEPINE"
	
	if tonumber(arg1) then
		length = tonumber(arg1)
		treeTypeName = arg2 or treeTypeName
	elseif tonumber(arg2) then
		length = tonumber(arg2)
		treeTypeName = arg1 or treeTypeName
	else
		treeTypeName = arg1 or treeTypeName
	end
	
	local availableLogTypes = {
		OAK = 3.2,
		ASPEN= 10,
		BEECH = 10,
		RAVAGED = 8,
		DEADWOOD = 16,
		TRANSPORT = 8,
		LODGEPOLEPINE = 30,
		SHAGBARKHICKORY = 4,
		PINUSTABULIFORMIS = 10,
	}

	treeTypeName = string.upper(treeTypeName or "")
	if availableLogTypes[treeTypeName]==nil then
		return "Error: Invalid lumber type. Valid types are " .. table.concatKeys(availableLogTypes, ", ")
	end
	
	local maxLength = availableLogTypes[treeTypeName]
	if treeTypeName == 'PINE' then treeTypeName = 'LODGEPOLEPINE' end
	if treeTypeName == 'HICKORY' then treeTypeName = 'SHAGBARKHICKORY' end
	if treeTypeName == 'PINUS' then treeTypeName = 'PINUSTABULIFORMIS' end
	if length == nil then length = maxLength end
	if length > maxLength then
		print("using maximum length " .. maxLength .. "m")
		length = maxLength
	end
	
	local controlledVehicle = g_localPlayer and g_localPlayer.getCurrentVehicle()
	if controlledVehicle then

		local vehicles = UniversalAutoloadManager.getAttachedVehicles(controlledVehicle)
		local count = 0
		
		if next(vehicles) ~= nil then
			for vehicle, hasAutoload in pairs(vehicles) do
				if hasAutoload and vehicle:getIsActiveForInput() then
					local maxSingleLength = UniversalAutoload.getMaxSingleLength(vehicle)
					maxSingleLength = math.floor(10*maxSingleLength)/10
					if length > maxSingleLength then
						length = maxSingleLength - 0.1
						print("resizing to fit trailer " .. length .. "m")
					end
					if UniversalAutoload.createLogs(vehicle, length, treeTypeName) then
						count = count + 1
					end
				end
			end
		end
	
		if count>0 then return "Begin adding logs now.." end
	end
	return "Please enter a vehicle with a UAL trailer attached to use this command"
end
--
function UniversalAutoloadManager:consoleAddBales(fillTypeName, isRoundbale, width, height, length, wrapState, modName)
	local usage = "ualAddBales fillTypeName isRoundBale [width] [height/diameter] [length] [wrapState] [modName]"

	fillTypeName = Utils.getNoNil(fillTypeName, "STRAW")
	isRoundbale = Utils.stringToBoolean(isRoundbale)
	width = width ~= nil and tonumber(width) or nil
	height = height ~= nil and tonumber(height) or nil
	length = length ~= nil and tonumber(length) or nil

	if wrapState ~= nil and tonumber(wrapState) == nil then
		Logging.error("Invalid wrapState '%s'. Number expected", wrapState, usage)

		return
	end

	wrapState = tonumber(wrapState or 0)
	local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)

	if fillTypeIndex == nil then
		Logging.error("Invalid fillTypeName '%s' (e.g. STRAW). Use %s", fillTypeName, usage)

		return
	end

	local xmlFilename, _ = g_baleManager:getBaleXMLFilename(fillTypeIndex, isRoundbale, width, height, length, height, modName)

	if xmlFilename == nil then
		Logging.error("Could not find bale for given size attributes! (%s)", usage)
		g_baleManager:consoleCommandListBales()

		return
	end
	
	bale = {}
	bale.xmlFile = xmlFilename
	bale.fillTypeIndex = fillTypeIndex
	bale.wrapState = wrapState
	
	local controlledVehicle = g_localPlayer and g_localPlayer.getCurrentVehicle()
	if controlledVehicle then

		local vehicles = UniversalAutoloadManager.getAttachedVehicles(controlledVehicle)
		local count = 0
		
		if next(vehicles) ~= nil then
			for vehicle, hasAutoload in pairs(vehicles) do
				if hasAutoload and vehicle:getIsActiveForInput() then
					if UniversalAutoload.createBales(vehicle, bale) then
						count = count + 1
					end
				end
			end
		end

		if count>0 then return "Begin adding bales now.." end
	end
	return "Please enter a vehicle with a UAL trailer attached to use this command"
end
-- --
function UniversalAutoloadManager:consoleAddRoundBales_125(fillTypeName)
	return UniversalAutoloadManager:consoleAddBales(fillTypeName or "DRYGRASS_WINDROW", "true", "1.2", "1.25")
end
--
function UniversalAutoloadManager:consoleAddRoundBales_150(fillTypeName)
	return UniversalAutoloadManager:consoleAddBales(fillTypeName or "DRYGRASS_WINDROW", "true", "1.2", "1.5")
end
--
function UniversalAutoloadManager:consoleAddRoundBales_180(fillTypeName)
	return UniversalAutoloadManager:consoleAddBales(fillTypeName or "DRYGRASS_WINDROW", "true", "1.2", "1.8")
end
--
function UniversalAutoloadManager:consoleAddSquareBales_180(fillTypeName)
	return UniversalAutoloadManager:consoleAddBales(fillTypeName or "STRAW", "false", "1.2", "0.9", "1.8")
end
--
function UniversalAutoloadManager:consoleAddSquareBales_220(fillTypeName)
	return UniversalAutoloadManager:consoleAddBales(fillTypeName or "STRAW", "false", "1.2", "0.9", "2.2")
end
--
function UniversalAutoloadManager:consoleAddSquareBales_240(fillTypeName)
	return UniversalAutoloadManager:consoleAddBales(fillTypeName or "STRAW", "false", "1.2", "0.9", "2.4")
end
-- --
function UniversalAutoloadManager:consoleClearLoadedObjects()
	
	local palletCount, balesCount, logCount = 0, 0, 0
	local controlledVehicle = g_localPlayer and g_localPlayer.getCurrentVehicle()
	if controlledVehicle then
		local vehicles = UniversalAutoloadManager.getAttachedVehicles(controlledVehicle)
		if next(vehicles) ~= nil then
			for vehicle, hasAutoload in pairs(vehicles) do
				if hasAutoload and vehicle:getIsActiveForInput() then
					P, B, L = UniversalAutoload.clearLoadedObjects(vehicle)
					palletCount = palletCount + P
					balesCount = balesCount + B
					logCount = logCount + L
				end
			end
		end
	end

	if palletCount > 0 and balesCount == 0 and logCount == 0 then
		return string.format("REMOVED: %d pallets", palletCount)
	end
	if balesCount > 0 and palletCount == 0 and logCount == 0 then
		return string.format("REMOVED: %d bales", balesCount)
	end
	if logCount > 0 and palletCount == 0 and balesCount == 0 then
		return string.format("REMOVED: %d logs", logCount)
	end
	return string.format("REMOVED: %d pallets, %d bales, %d logs", palletCount, balesCount, logCount)
end
--
-- function UniversalAutoloadManager:consoleSpawnTestPallets()
	-- local usage = "Usage: consoleSpawnTestPallets"
	
	-- local controlledVehicle = g_localPlayer and g_localPlayer.getCurrentVehicle()
	-- if controlledVehicle then
	
		-- local vehicles = UniversalAutoloadManager.getAttachedVehicles(controlledVehicle)
		
		-- if next(vehicles) ~= nil then
			-- for vehicle, hasAutoload in pairs(vehicles) do
				-- if hasAutoload and vehicle:getIsActiveForInput() then

					-- UniversalAutoload.testPallets = {}
					-- UniversalAutoload.testPalletsCount = 0;
					-- for _, fillType in pairs(g_fillTypeManager:getFillTypes()) do
						-- local xmlName = fillType.palletFilename
						-- if xmlName ~= nil and not xmlName:find("fillablePallet") then
							-- print(string.format("%s - %s", fillType, xmlName))
							-- UniversalAutoload.createPallet(vehicle, xmlName)
						-- end
					-- end
					-- return "Test pallets created successfully"
				-- end
			-- end
		-- end
		
		-- -- if next(UniversalAutoload.testPallets) and isActiveForInputIgnoreSelection then
			-- -- if #UniversalAutoload.testPallets == UniversalAutoload.testPalletsCount then
				-- -- print("TEST PALLETS SPAWNED")
				-- -- print(string.format("%s, %s, %s, %s", "name", "volume", "mass", "density"))
				-- -- for _, pallet in pairs(UniversalAutoload.testPallets) do
					-- -- local config = UniversalAutoload.getContainerType(pallet)
					-- -- local mass = UniversalAutoload.getContainerMass(pallet)
					-- -- local volume = config.sizeX * config.sizeY * config.sizeZ
					-- -- print(string.format("%s, %f, %f, %f", config.name, volume, mass, mass/volume))
					-- -- g_currentMission.vehicleSystem:removeVehicle(pallet, true)
				-- -- end
				-- -- UniversalAutoload.testPallets = {}
			-- -- end
		-- -- end
	-- end
	-- return "Please enter a vehicle with a UAL trailer attached to use this command"
	
-- end
--
function UniversalAutoloadManager.addAttachedVehicles(vehicle, vehicles)

	if vehicle.getAttachedImplements ~= nil then
		local attachedImplements = vehicle:getAttachedImplements()
		for _, implement in pairs(attachedImplements) do
			local spec = implement.object.spec_universalAutoload
			vehicles[implement.object] = spec ~= nil
			UniversalAutoloadManager.addAttachedVehicles(implement.object, vehicles)
		end
	end
	return vehicles
end
--
function UniversalAutoloadManager.getAttachedVehicles(vehicle)
	local vehicles = {}
	local rootVehicle = vehicle:getRootVehicle()
	local spec = rootVehicle.spec_universalAutoload
	vehicles[rootVehicle] = spec ~= nil
	UniversalAutoloadManager.addAttachedVehicles(rootVehicle, vehicles)
	return vehicles
end

-- 
function UniversalAutoloadManager.resetNextVehicle()

	local resetList = UniversalAutoloadManager.resetList
	if resetList ~= nil and next(resetList) ~= nil then
		local vehicle = resetList[#resetList]
		table.remove(resetList, #resetList)
		if not UniversalAutoloadManager.resetVehicle(vehicle) then
			UniversalAutoloadManager.resetCount = UniversalAutoloadManager.resetCount + 1
			UniversalAutoloadManager.resetControlledVehicle = true
			UniversalAutoloadManager.resetNextVehicle()
		end
	else
		if UniversalAutoloadManager.resetControlledVehicle then
			UniversalAutoloadManager.resetControlledVehicle = false
			g_currentMission:consoleCommandReloadVehicle()
			g_currentMission.isReloadingVehicles = true
		else
			g_currentMission.isReloadingVehicles = false
		end
		UniversalAutoloadManager.resetCount = nil
	end
end
--
function UniversalAutoloadManager.resetVehicle(vehicle)
	print("UAL - RESET vehicle")
	if UniversalAutoloadManager.resetCount then
		print(string.format("RESETTING #%d: %s", UniversalAutoloadManager.resetCount, vehicle:getFullName()))
	else
		print(string.format("RESETTING: %s", vehicle:getFullName()))
	end

	local rootVehicle = vehicle:getRootVehicle()
	if rootVehicle then
		if UniversalAutoloadManager.getIsTrainCarriage(vehicle) then
			print("*** CANNOT RESET TRAIN - terrible things will happen ***")
			if UniversalAutoloadManager.resetCount then
				UniversalAutoloadManager.resetNextVehicle()
			end
			return true
		end
		local controlledVehicle = g_localPlayer and g_localPlayer.getCurrentVehicle()
		if controlledVehicle and rootVehicle == controlledVehicle then
			print("*** Resetting with standard console command ***")
			UniversalAutoload.clearLoadedObjects(vehicle)
			return false
		end
	end
	
	UniversalAutoload.clearLoadedObjects(vehicle)

	local xmlFile = Vehicle.getReloadXML(vehicle)

	if xmlFile ~= nil and xmlFile ~= 0 then
		local function asyncCallbackFunction(_, newVehicle, vehicleLoadState, arguments)
			if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_OK then
				g_messageCenter:publish(MessageType.VEHICLE_RESET, vehicle, newVehicle)
				g_currentMission.vehicleSystem:removeVehicle(vehicle)
				if UniversalAutoloadManager.resetCount then
					UniversalAutoloadManager.resetCount = UniversalAutoloadManager.resetCount + 1
				end
			else
				if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_ERROR then
					print(" >> VEHICLE_LOAD_ERROR")
				end
				if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_DELAYED then
					print(" >> VEHICLE_LOAD_DELAYED")
				end
				if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_NO_SPACE then
					print(" >> There was no space available at the shop")
				end
				if vehicle ~= nil then
					print("ERROR RESETTING OLD VEHICLE: " .. vehicle:getFullName())
					--g_currentMission.vehicleSystem:removeVehicle(vehicle)
				end
				if newVehicle ~= nil then
					print("ERROR RESETTING NEW VEHICLE: " .. newVehicle:getFullName())
					--g_currentMission.vehicleSystem:removeVehicle(newVehicle)
				end
			end
			
			xmlFile:delete()
			UniversalAutoloadManager.resetNextVehicle()
		end
		
		local vehicleSystem = g_currentMission.vehicleSystem
		vehicleSystem:loadFromXMLFile(xmlFile, asyncCallbackFunction, nil, {}, true, true)

	end
	return true
end
--

function UniversalAutoloadManager.consoleFullTest()

	UniversalAutoloadManager.runFullTest = true

end

-- MAIN LOAD MAP FUNCTION
function UniversalAutoloadManager:loadMap(name)
	-- print("UAL - LOADMAP")
	UniversalAutoloadManager.createShopGui()
	UniversalAutoloadManager.createGlobalGui()
	UniversalAutoloadManager.injectSpecialisation()
	
	g_messageCenter:subscribe(BuyVehicleEvent, UniversalAutoloadManager.onVehicleBuyEvent, UniversalAutoloadManager)

	UniversalAutoload.CONTAINERS_LOOKUP = {}
	for i, key in ipairs(UniversalAutoload.CONTAINERS) do
		UniversalAutoload.CONTAINERS_LOOKUP[key] = i
	end
	
	UniversalAutoload.MATERIALS = {}
	table.insert(UniversalAutoload.MATERIALS, UniversalAutoload.ALL )
	UniversalAutoload.MATERIALS_FILLTYPE = {}
	table.insert( UniversalAutoload.MATERIALS_FILLTYPE, {["title"]= g_i18n:getText("universalAutoload_ALL")} )
	for index, fillType in ipairs(g_fillTypeManager.fillTypes) do
		if fillType.name ~= "UNKNOWN" then
			table.insert(UniversalAutoload.MATERIALS, fillType.name )
			table.insert(UniversalAutoload.MATERIALS_FILLTYPE, fillType )
		end
	end
	
	UniversalAutoload.MATERIALS_INDEX = {}
	for i, key in ipairs(UniversalAutoload.MATERIALS) do
		-- print("  - "..i..": "..key.." = "..UniversalAutoload.MATERIALS_FILLTYPE[i].title)
		UniversalAutoload.MATERIALS_INDEX[key] = i
	end

	-- USER SETTINGS FIRST
	UniversalAutoloadManager.importLocalConfigurations()
	UniversalAutoloadManager.detectKeybindingConflicts()
	
	if g_currentMission:getIsServer() and not g_currentMission.missionDynamicInfo.isMultiplayer then
		print("ADD console commands:")
		addConsoleCommand("ualResetConfigurations", "Reset the mod settings file to defaults (requires restart to apply)", "consoleResetConfigurations", UniversalAutoloadManager)
		addConsoleCommand("ualAddBales", "Fill current vehicle with specified bales", "consoleAddBales", UniversalAutoloadManager)
		addConsoleCommand("ualAddRoundBales_125", "Fill current vehicle with small round bales", "consoleAddRoundBales_125", UniversalAutoloadManager)
		addConsoleCommand("ualAddRoundBales_150", "Fill current vehicle with medium round bales", "consoleAddRoundBales_150", UniversalAutoloadManager)
		addConsoleCommand("ualAddRoundBales_180", "Fill current vehicle with large round bales", "consoleAddRoundBales_180", UniversalAutoloadManager)
		addConsoleCommand("ualAddSquareBales_180", "Fill current vehicle with small square bales", "consoleAddSquareBales_180", UniversalAutoloadManager)
		addConsoleCommand("ualAddSquareBales_220", "Fill current vehicle with medium square bales", "consoleAddSquareBales_220", UniversalAutoloadManager)
		addConsoleCommand("ualAddSquareBales_240", "Fill current vehicle with large square bales", "consoleAddSquareBales_240", UniversalAutoloadManager)
		addConsoleCommand("ualAddPallets", "Fill current vehicle with specified pallets (fill type)", "consoleAddPallets", UniversalAutoloadManager)
		addConsoleCommand("ualAddLogs", "Fill current vehicle with specified logs (length / fill type)", "consoleAddLogs", UniversalAutoloadManager)
		addConsoleCommand("ualClearLoadedObjects", "Remove all loaded objects from current vehicle", "consoleClearLoadedObjects", UniversalAutoloadManager)
		-- addConsoleCommand("ualResetVehicles", "Reset all vehicles with autoload (and any attached) to the shop", "consoleResetVehicles", UniversalAutoloadManager)
		-- addConsoleCommand("ualSpawnTestPallets", "Create one of each pallet type (not loaded)", "consoleSpawnTestPallets", UniversalAutoloadManager)
		-- addConsoleCommand("ualFullTest", "Test all the different loading types", "consoleFullTest", UniversalAutoloadManager)
	end
	
	if tostring(UniversalAutoload.name):find("fs25planet") or tostring(UniversalAutoload.name):find("_0_") then
		InfoDialog.show("PLEASE DON'T USE SCUMMY THIRD-PARTY MOD SITES")
	end
end

function UniversalAutoloadManager:deleteMap()
	print("UNIVERSAL AUTOLOAD: CLEAN UP")
	removeConsoleCommand("ualAddBales")
	removeConsoleCommand("ualAddRoundBales_125")
	removeConsoleCommand("ualAddRoundBales_150")
	removeConsoleCommand("ualAddRoundBales_180")
	removeConsoleCommand("ualAddSquareBales_180")
	removeConsoleCommand("ualAddSquareBales_220")
	removeConsoleCommand("ualAddSquareBales_240")
	removeConsoleCommand("ualAddPallets")
	removeConsoleCommand("ualAddLogs")
	removeConsoleCommand("ualClearLoadedObjects")
	-- removeConsoleCommand("ualResetVehicles")
	-- removeConsoleCommand("ualSpawnTestPallets")
	-- removeConsoleCommand("ualFullTest")
	
	UniversalAutoloadManager.deleteShopGui()
	UniversalAutoloadManager.deleteGlobalGui()
end

-- SYNC SETTINGS:
Player.readStream = Utils.overwrittenFunction(Player.readStream,
	function(self, superFunc, streamId, connection, objectId)
		superFunc(self, streamId, connection, objectId)
		print("UAL Player.readStream")
		UniversalAutoload.disableAutoStrap = streamReadBool(streamId)
		UniversalAutoload.pricePerLog = streamReadInt32(streamId)
		UniversalAutoload.pricePerBale = streamReadInt32(streamId)
		UniversalAutoload.pricePerPallet = streamReadInt32(streamId)
	end
)
Player.writeStream = Utils.overwrittenFunction(Player.writeStream,
	function(self, superFunc, streamId, connection)
		superFunc(self, streamId, connection)
		print("UAL Player.writeStream")
		streamWriteBool(streamId, UniversalAutoload.disableAutoStrap or false)
		streamWriteInt32(streamId, UniversalAutoload.pricePerLog or 0)
		streamWriteInt32(streamId, UniversalAutoload.pricePerBale or 0)
		streamWriteInt32(streamId, UniversalAutoload.pricePerPallet or 0)
	end
)

-- SEND SETTINGS TO CLIENT:
FSBaseMission.sendInitialClientState = Utils.overwrittenFunction(FSBaseMission.sendInitialClientState,
	function(self, superFunc, connection, user, farm)
		superFunc(self, connection, user, farm)
		
		if debugMultiplayer then print("  user: " .. tostring(user.nickname) .. " " .. tostring(farm.name)) end
		print("connectedToDedicatedServer: " .. tostring(g_currentMission.connectedToDedicatedServer))

		-- UniversalAutoload.disableAutoStrap = UniversalAutoload.disableAutoStrap or false
		-- UniversalAutoload.pricePerLog = UniversalAutoload.pricePerLog or 0
		-- UniversalAutoload.pricePerBale = UniversalAutoload.pricePerBale or 0
		-- UniversalAutoload.pricePerPallet = UniversalAutoload.pricePerPallet or 0
		
		-- streamWriteBool(streamId, UniversalAutoload.disableAutoStrap)
		-- streamWriteInt32(streamId, spec.pricePerLog)
		-- streamWriteInt32(streamId, spec.pricePerBale)
		-- streamWriteInt32(streamId, spec.pricePerPallet)
		-- streamWriteInt32(streamId, spec.minLogLength)

		-- UniversalAutoload.disableAutoStrap = streamReadBool(streamId)
		-- spec.pricePerLog = streamReadInt32(streamId)
		-- spec.pricePerBale = streamReadInt32(streamId)
		-- spec.pricePerPallet = streamReadInt32(streamId)
		-- spec.minLogLength = streamReadInt32(streamId)
	end
)

function tableContainsValue(container, value)
	for k, v in pairs(container) do
		if v == value then
			return true
		end
	end
	return false
end

function deepCopy(original, copies)
	copies = copies or {}
	if copies[original] then
		return copies[original]
	end
	
	local copy = {}
	copies[original] = copy
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v, copies)
		end
		copy[k] = v
	end
	return copy
end

function deepCompare(tbl1, tbl2)
	if tbl1==nil or tbl2==nil then
		return false
	end
	if tbl1 == tbl2 then
		return true
	elseif type(tbl1) == "table" and type(tbl2) == "table" then
		for key1, value1 in pairs(tbl1) do
			local value2 = tbl2[key1]
			if value2 == nil then
				return false
			elseif value1 ~= value2 then
				if type(value1) == "table" and type(value2) == "table" then
					if not deepCompare(value1, value2) then
						return false
					end
				else
					return false
				end
			end
		end
		for key2, _ in pairs(tbl2) do
			if tbl1[key2] == nil then
				return false
			end
		end
		return true
	end
	return false
end

ShopConfigScreen.processAttributeData = Utils.overwrittenFunction(ShopConfigScreen.processAttributeData,
	function(self, superFunc, storeItem, vehicle, saleItem)

		superFunc(self, storeItem, vehicle, saleItem)
		
		if vehicle.spec_universalAutoload ~= nil and vehicle.spec_universalAutoload.isAutoloadAvailable then
			
			local itemElement = self.attributeItem:clone(self.attributesLayout)
			local iconElement = itemElement:getDescendantByName("icon")
			local textElement = itemElement:getDescendantByName("text")

			itemElement:reloadFocusHandling(true)
			iconElement:applyProfile(ShopConfigScreen.GUI_PROFILE.CAPACITY)
			iconElement:setImageFilename(UniversalAutoload.SHOP_ICON)
			iconElement:setImageUVs(nil, 0, 0, 0, 1, 1, 0, 1, 1)
			iconElement:setVisible(true)
			textElement:setText(g_i18n:getText("shop_configuration_text"))
			
			if vehicle.spec_universalAutoload.isLogTrailer then
				local maxSingleLengthString
				local maxSingleLength = UniversalAutoload.getMaxSingleLength(vehicle)
				maxSingleLength = math.floor(10*maxSingleLength)/10
				local nearestHalfValue = math.floor(2*maxSingleLength)/2
				if nearestHalfValue % 1 < 0.1 then
					maxSingleLengthString = string.format("  %dm", nearestHalfValue)
				else
					maxSingleLengthString = string.format("  %.1fm", nearestHalfValue)
				end

				local itemElement2 = self.attributeItem:clone(self.attributesLayout)
				local iconElement2 = itemElement2:getDescendantByName("icon")
				local textElement2 = itemElement2:getDescendantByName("text")

				itemElement2:reloadFocusHandling(true)
				iconElement2:applyProfile(ShopConfigScreen.GUI_PROFILE.WORKING_WIDTH)
				textElement2:setText(g_i18n:getText("infohud_length") .. maxSingleLengthString)
			end
			
			self.attributesLayout:invalidateLayout()

		end

	end
)

-- Add valid store items to the 'UNIVERSALAUTOLOAD' store pack if it exists.
-- StoreManager.loadItem = Utils.overwrittenFunction(StoreManager.loadItem, function(self, superFunc, ...)
	-- local storeItem = superFunc(self, ...)

	-- if storeItem and storeItem.species == 1 then
		-- local xmlFile = XMLFile.load("loadItemXml", storeItem.xmlFilename, storeItem.xmlSchema)
		-- local typeName = xmlFile:getString("vehicle#type")
		
		-- local tensionBeltKey = "vehicle.tensionBelts.tensionBeltsConfigurations"
		-- local firstConfigKey = tensionBeltKey .. ".tensionBeltsConfiguration(0).tensionBelts"
		-- local hasTensionBelts = xmlFile:hasProperty(firstConfigKey)

		-- if typeName and UniversalAutoload.VEHICLE_TYPES[typeName] and hasTensionBelts then
			-- table.addElement(g_storeManager:getPackItems("UNIVERSALAUTOLOAD"), storeItem.xmlFilename)
		-- end
	-- end

	-- return storeItem
-- end)

