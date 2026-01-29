-- ============================================================= --
-- Universal Autoload MOD - SPECIALISATION
-- ============================================================= --
UniversalAutoload = {}

UniversalAutoload.name = g_currentModName
UniversalAutoload.path = g_currentModDirectory
UniversalAutoload.specName = ("spec_%s.universalAutoload"):format(g_currentModName)
UniversalAutoload.globalKey = "universalAutoload"
UniversalAutoload.savegameStateKey = ".currentState"
UniversalAutoload.savegameConfigKey = ".configuration"
UniversalAutoload.postLoadKey = "." .. g_currentModName .. ".universalAutoload.currentState"
UniversalAutoload.savegameStateSchemaKey = "vehicles.vehicle(?)." .. g_currentModName .. ".universalAutoload.currentState"
UniversalAutoload.savegameConfigSchemaKey = "vehicles.vehicle(?)." .. g_currentModName .. ".universalAutoload.configuration"
UniversalAutoload.vehicleKey = "universalAutoload.vehicleConfigurations.vehicle(%d)"
UniversalAutoload.vehicleConfigKey = UniversalAutoload.vehicleKey .. ".configuration(%d)"
UniversalAutoload.vehicleSchemaKey = "universalAutoload.vehicleConfigurations.vehicle(?)"
UniversalAutoload.containerKey = "universalAutoload.containerConfigurations.container(%d)"
UniversalAutoload.containerSchemaKey = "universalAutoload.containerConfigurations.container(?)"

UniversalAutoload.SPLITSHAPES_LOOKUP = {}
UniversalAutoload.OBJECTS_LOOKUP = {}

UniversalAutoload.ALL = "ALL"
UniversalAutoload.DELTA = 0.005
UniversalAutoload.BIGBAG_SPACING = 0.1
UniversalAutoload.MAX_STACK = 5
UniversalAutoload.LOG_SPACE = 0.25
UniversalAutoload.DELAY_TIME = 150
UniversalAutoload.MP_DELAY = 1000
UniversalAutoload.LOG_DELAY = 1000
UniversalAutoload.TRIGGER_DELTA = 0.1
UniversalAutoload.MAX_LAYER_COUNT = 10
UniversalAutoload.ROTATED_BALE_FACTOR = 0.80
UniversalAutoload.MAX_AREAS = 5
-- 0.85355339

UniversalAutoload.showDebug = false
UniversalAutoload.showLoading = false

local debugKeys = false
local debugMenus = false
local debugSchema = false
local debugConsole = false
local debugLoading = false
local debugPallets = false
local debugVehicles = false
local debugMultiplayer = false
local debugSpecial = false

function UniversalAutoload.debugPrint(inputString, flag)
	if UniversalAutoload.showDebug or flag then
		if flag == nil or flag then
			print(inputString)
		end
	end
end

-- local disablePhysicsAfterLoading = true

UniversalAutoload.MASK = {}
UniversalAutoload.MASK.object = CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.TREE
UniversalAutoload.MASK.everything = UniversalAutoload.MASK.object + CollisionFlag.STATIC_OBJECT + CollisionFlag.PLAYER

UniversalAutoload.MAX_NUM_ELEMENTS = InputHelpDisplay.MAX_NUM_ELEMENTS
UniversalAutoload.MAX_NUM_ELEMENTS_HIGH_PRIORITY = InputHelpDisplay.MAX_NUM_ELEMENTS_HIGH_PRIORITY

-- EVENTS
source(g_currentModDirectory.."events/CycleContainerEvent.lua")
source(g_currentModDirectory.."events/CycleMaterialEvent.lua")
source(g_currentModDirectory.."events/PlayerTriggerEvent.lua")
source(g_currentModDirectory.."events/RaiseActiveEvent.lua")
source(g_currentModDirectory.."events/ResetLoadingEvent.lua")
source(g_currentModDirectory.."events/SetCollectionModeEvent.lua")
source(g_currentModDirectory.."events/SetContainerTypeEvent.lua")
source(g_currentModDirectory.."events/SetFilterEvent.lua")
source(g_currentModDirectory.."events/SetHorizontalLoadingEvent.lua")
source(g_currentModDirectory.."events/SetLoadsideEvent.lua")
source(g_currentModDirectory.."events/SetMaterialTypeEvent.lua")
source(g_currentModDirectory.."events/SetTipsideEvent.lua")
source(g_currentModDirectory.."events/StartLoadingEvent.lua")
source(g_currentModDirectory.."events/StopLoadingEvent.lua")
source(g_currentModDirectory.."events/UnloadingEvent.lua")
source(g_currentModDirectory.."events/UpdateActionEvents.lua")
source(g_currentModDirectory.."events/WarningMessageEvent.lua")
source(g_currentModDirectory.."events/UpdateDefaultSettingsEvent.lua")


-- REQUIRED SPECIALISATION FUNCTIONS
function UniversalAutoload.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(TensionBelts, specializations)
end
--
function UniversalAutoload.initSpecialization()
	local globalKey = UniversalAutoload.globalKey

	g_vehicleConfigurationManager:addConfigurationType("universalAutoload", g_i18n:getText("configuration_universalAutoload"), globalKey, "autoload", nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION)
	
	local function registerConfig(schema, rootKey, tbl, parentKey)
		parentKey = parentKey or ""
		for _, v in pairs(tbl) do
			if type(v) == "table" then
				local currentKey = parentKey .. (v.key or "")
				if v.valueType then
					schema:register(XMLValueType[v.valueType], rootKey .. currentKey, v.description or "", v.default)
					UniversalAutoload.debugPrint("  " .. rootKey .. currentKey, debugSchema)
				end
				if v.data then
					registerConfig(schema, rootKey, v.data, currentKey)
				end
			end
		end
	end

	UniversalAutoload.xmlSchema = XMLSchema.new(globalKey)
	UniversalAutoload.debugPrint("*** REGISTER XML SCHEMAS ***", debugSchema)
	UniversalAutoload.debugPrint("GLOBAL_DEFAULTS:", debugSchema)
	registerConfig(UniversalAutoload.xmlSchema, UniversalAutoload.globalKey, UniversalAutoload.GLOBAL_DEFAULTS)
	UniversalAutoload.debugPrint("VEHICLE_DEFAULTS:", debugSchema)
	registerConfig(UniversalAutoload.xmlSchema, UniversalAutoload.vehicleSchemaKey, UniversalAutoload.VEHICLE_DEFAULTS)
	UniversalAutoload.debugPrint("SAVEGAME_STATE_DEFAULTS:", debugSchema)
	registerConfig(Vehicle.xmlSchemaSavegame, UniversalAutoload.savegameStateSchemaKey, UniversalAutoload.SAVEGAME_STATE_DEFAULTS)
	UniversalAutoload.debugPrint("SAVEGAME_CONFIG_DEFAULTS:", debugSchema)
	registerConfig(Vehicle.xmlSchemaSavegame, UniversalAutoload.savegameConfigSchemaKey, UniversalAutoload.CONFIG_DEFAULTS)

end
--
function UniversalAutoload.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsMoving", UniversalAutoload.ualGetIsMoving)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsFilled", UniversalAutoload.ualGetIsFilled)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsCovered", UniversalAutoload.ualGetIsCovered)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsFolding", UniversalAutoload.ualGetIsFolding)
	SpecializationUtil.registerFunction(vehicleType, "ualGetIsAttaching", UniversalAutoload.ualGetIsAttaching)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteVehicle_Callback", UniversalAutoload.ualOnDeleteVehicle_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteLoadedObject_Callback", UniversalAutoload.ualOnDeleteLoadedObject_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteAvailableObject_Callback", UniversalAutoload.ualOnDeleteAvailableObject_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualOnDeleteAutoLoadingObject_Callback", UniversalAutoload.ualOnDeleteAutoLoadingObject_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualTestLocation_Callback", UniversalAutoload.ualTestLocation_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualTestUnloadLocation_Callback", UniversalAutoload.ualTestUnloadLocation_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualTestLocationOverlap_Callback", UniversalAutoload.ualTestLocationOverlap_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualPlayerTrigger_Callback", UniversalAutoload.ualPlayerTrigger_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualLoadingTrigger_Callback", UniversalAutoload.ualLoadingTrigger_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualUnloadingTrigger_Callback", UniversalAutoload.ualUnloadingTrigger_Callback)
	SpecializationUtil.registerFunction(vehicleType, "ualAutoLoadingTrigger_Callback", UniversalAutoload.ualAutoLoadingTrigger_Callback)
	-- --- Courseplay functions
	SpecializationUtil.registerFunction(vehicleType, "ualHasLoadedBales", UniversalAutoload.ualHasLoadedBales)
	SpecializationUtil.registerFunction(vehicleType, "ualIsFull", UniversalAutoload.ualIsFull)
	SpecializationUtil.registerFunction(vehicleType, "ualGetLoadedBales", UniversalAutoload.ualGetLoadedBales)
	SpecializationUtil.registerFunction(vehicleType, "ualIsObjectLoadable", UniversalAutoload.ualIsObjectLoadable)
	-- --- Autodrive functions
	SpecializationUtil.registerFunction(vehicleType, "ualStartLoad", UniversalAutoload.ualStartLoad)
	SpecializationUtil.registerFunction(vehicleType, "ualStopLoad", UniversalAutoload.ualStopLoad)
	SpecializationUtil.registerFunction(vehicleType, "ualUnload", UniversalAutoload.ualUnload)
	SpecializationUtil.registerFunction(vehicleType, "ualSetUnloadPosition", UniversalAutoload.ualSetUnloadPosition)
	SpecializationUtil.registerFunction(vehicleType, "ualGetFillUnitCapacity", UniversalAutoload.ualGetFillUnitCapacity)
	SpecializationUtil.registerFunction(vehicleType, "ualGetFillUnitFillLevel", UniversalAutoload.ualGetFillUnitFillLevel)
	SpecializationUtil.registerFunction(vehicleType, "ualGetFillUnitFreeCapacity", UniversalAutoload.ualGetFillUnitFreeCapacity)
	SpecializationUtil.registerFunction(vehicleType, "ualSetMaterialTypeIndex", UniversalAutoload.ualSetMaterialTypeIndex)
	SpecializationUtil.registerFunction(vehicleType, "ualGetTotalAvailableCount", UniversalAutoload.ualGetTotalAvailableCount)
end
--
function UniversalAutoload.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFullName", UniversalAutoload.ualGetFullName)
	-- SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanStartFieldWork", UniversalAutoload.getCanStartFieldWork)
	-- SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanImplementBeUsedForAI", UniversalAutoload.getCanImplementBeUsedForAI)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDynamicMountTimeToMount", UniversalAutoload.getDynamicMountTimeToMount)
end

-- function UniversalAutoload:getCanStartFieldWork(superFunc)
	-- local spec = self.spec_universalAutoload
	-- if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled and spec.autoCollectionMode then
		-- UniversalAutoload.debugPrint("getCanStartFieldWork...", debugSpecial)
		-- --return true
	-- end
	-- return superFunc(self)
-- end
-- function UniversalAutoload:getCanImplementBeUsedForAI(superFunc)
	-- local spec = self.spec_universalAutoload
	-- if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		-- UniversalAutoload.debugPrint("*** getCanImplementBeUsedForAI ***", debugSpecial)
		-- --DebugUtil.printTableRecursively(self.spec_aiImplement, "--", 0, 1)
		-- --return true
	-- end
	-- return superFunc(self)
-- end
--
function UniversalAutoload.getWorldRotation(node, x, y, z)
	return getWorldRotation(node, x or 0, y or 0, z or 0)
end
--
function UniversalAutoload.getWorldTranslation(node, x, y, z)
	return getWorldTranslation(node, x or 0, y or 0, z or 0)
end
--
function UniversalAutoload.localDirectionToWorld(node, x, y, z)
	return localDirectionToWorld(node, x or 0, y or 0, z or 0)
end
--
function UniversalAutoload.localToWorld(node, x, y, z, velocityCorrection)
	local X, Y, Z = localToWorld(node, x or 0, y or 0, z or 0)
	if velocityCorrection then
		c = velocityCorrection
		X, Y, Z = X+c[1], Y+c[2], Z+c[3]
	end
	return X, Y, Z
end
--
function UniversalAutoload:getDynamicMountTimeToMount(superFunc)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		return superFunc(self)
	end
	return UniversalAutoload.getIsLoadingVehicleAllowed(self) and -1 or math.huge
end
--
function UniversalAutoload:ualGetFullName(superFunc)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or not UniversalAutoload.showDebug then
		return superFunc(self)
	end
	return superFunc(self).." - UAL #"..tostring(self.rootNode)
end

function UniversalAutoload.registerEventListeners(vehicleType)
	UniversalAutoload.debugPrint("  Register vehicle type: " .. tostring(vehicleType.name))
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UniversalAutoload)
	
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateEnd", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", UniversalAutoload)
	
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDelete", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", UniversalAutoload)
	
	SpecializationUtil.registerEventListener(vehicleType, "onActivate", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onDeactivate", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onMovingToolChanged", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onPostAttach", UniversalAutoload)

	--- Courseplay event listeners.
	SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStart", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onAIFieldWorkerStart", UniversalAutoload)
	SpecializationUtil.registerEventListener(vehicleType, "onAIFieldWorkerEnd", UniversalAutoload)
end

function UniversalAutoload.removeEventListeners(vehicleType)
	UniversalAutoload.debugPrint("REMOVE EVENT LISTENERS")
	
	SpecializationUtil.removeEventListener(vehicleType, "onLoad", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onPostLoad", UniversalAutoload)
	
	SpecializationUtil.removeEventListener(vehicleType, "onUpdate", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onUpdateTick", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onUpdateEnd", UniversalAutoload)	
	SpecializationUtil.removeEventListener(vehicleType, "onDraw", UniversalAutoload)
	
	SpecializationUtil.removeEventListener(vehicleType, "onDelete", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onPreDelete", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onRegisterActionEvents", UniversalAutoload)

	SpecializationUtil.removeEventListener(vehicleType, "onActivate", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onDeactivate", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onFoldStateChanged", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onMovingToolChanged", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onPostAttach", UniversalAutoload)
	
	SpecializationUtil.removeEventListener(vehicleType, "onAIImplementStart", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onAIImplementEnd", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onAIFieldWorkerStart", UniversalAutoload)
	SpecializationUtil.removeEventListener(vehicleType, "onAIFieldWorkerEnd", UniversalAutoload)
end

-- ACTION EVENT FUNCTIONS
function UniversalAutoload:clearActionEvents()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and spec.actionEvents then
		self:clearActionEventsTable(spec.actionEvents)
	end
end
--
function UniversalAutoload:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient and g_dedicatedServer==nil then
		local spec = self.spec_universalAutoload
		UniversalAutoload.clearActionEvents(self)

		if isActiveForInput then
			-- UniversalAutoload.debugPrint("onRegisterActionEvents: "..self:getFullName())
			UniversalAutoload.updateActionEventKeys(self)
		end
	end
end
--
function UniversalAutoload:updateActionEventKeys()

	if self.isClient and g_dedicatedServer==nil then
		local spec = self.spec_universalAutoload
		
		local currentVehicle = g_localPlayer and g_localPlayer:getCurrentVehicle()
		if not currentVehicle then
			-- print("ON FOOT - IGNORE UPDATE RECEIVED FOR " .. self:getFullName())
			return
		end

		if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled and spec.actionEvents and next(spec.actionEvents) == nil then
			-- print("updateActionEventKeys: "..self:getFullName())
			local actions = UniversalAutoload.ACTIONS
			local ignoreCollisions = true
			local reportAnyDeviceCollision = true
			local triggerUp = false
			local triggerDown = true
			local triggerAlways = false
			local startActive = true
			
			local topPriority, midPriority, lowPriority
			if UniversalAutoload.highPriority == true then
				topPriority = GS_PRIO_VERY_HIGH
				midPriority = GS_PRIO_HIGH
				lowPriority = GS_PRIO_NORMAL
				InputHelpDisplay.MAX_NUM_ELEMENTS = UniversalAutoload.MAX_NUM_ELEMENTS_HIGH_PRIORITY
			else
				topPriority = GS_PRIO_HIGH
				midPriority = GS_PRIO_NORMAL
				lowPriority = GS_PRIO_VERY_LOW
				InputHelpDisplay.MAX_NUM_ELEMENTS = UniversalAutoload.MAX_NUM_ELEMENTS
			end

			local function registerActionEvent(id, event, callback, priority, visible)
				local valid, actionEventId = self:addActionEvent(spec.actionEvents, actions[id], self, UniversalAutoload[callback],
					triggerUp, triggerDown, triggerAlways, startActive, callbackState, customIconName, ignoreCollisions, reportAnyDeviceCollision)
				UniversalAutoload.debugPrint("  " .. tostring(id) .. ": "..tostring(valid), debugKeys)
				if valid == false then -- and self:getIsSelected()
					local _, _, otherEvents = g_inputBinding:registerActionEvent(actions[id], self, UniversalAutoload[callback],
						triggerUp, triggerDown, triggerAlways, startActive, callbackState, true, reportAnyDeviceCollision)

					if otherEvents ~= nil then
						local removedConflictingEvent = nil
						for _, otherEvent in ipairs(otherEvents) do
							if otherEvent.actionName == 'CRABSTEERING_ALLWHEEL' then
								if otherEvent.parentEventsTable ~= nil then
									g_inputBinding:removeActionEvent(otherEvent.id)
									otherEvent.parentEventsTable[otherEvent.id] = nil
									removedConflictingEvent = otherEvent.actionName
								end
							end
						end
						if removedConflictingEvent then
							local valid, newActionEventId = self:addActionEvent(spec.actionEvents, actions[id], self, UniversalAutoload[callback],
								triggerUp, triggerDown, triggerAlways, startActive, callbackState, customIconName, ignoreCollisions, reportAnyDeviceCollision)
							if valid then
								actionEventId = newActionEventId
							else
								actionEventId = nil
							end
							
							spec.alreadyPrintedConflictingAction = spec.alreadyPrintedConflictingAction or {}
							if not spec.alreadyPrintedConflictingAction[removedConflictingEvent] then
								spec.alreadyPrintedConflictingAction[removedConflictingEvent] = true
								print("UAL - key binding for " .. tostring(id) .. " failed to register")
								if valid then
									print("removed conflicting action: " .. tostring(removedConflictingEvent))
								else
									print("COULD NOT REMOVE conflicting action: " .. tostring(removedConflictingEvent))
								end
								print("*** Please re-bind one of these actions to prevent this message ***")
							end
						end
					end
				end
				if actionEventId then
					-- UniversalAutoload.debugPrint("setting " .. tostring(actionEventId))
					spec[event] = actionEventId
					g_inputBinding:setActionEventTextPriority(actionEventId, priority)
					if visible ~= nil then
						g_inputBinding:setActionEventTextVisibility(actionEventId, visible)
					end
				end
			end

			registerActionEvent('GLOBAL_MENU', 'globalMenuActionEventId', 'actionEventGlobalMenu', lowPriority)
			globalMenuText = "UAL " .. g_i18n:getText("ui_global_settings_ual")
			g_inputBinding:setActionEventText(spec.globalMenuActionEventId, globalMenuText)
			
			spec.updateToggleLoading = true
			registerActionEvent('UNLOAD_ALL', 'unloadAllActionEventId', 'actionEventUnloadAll', topPriority, true)
			registerActionEvent('TOGGLE_LOADING', 'toggleLoadingActionEventId', 'actionEventToggleLoading', topPriority)
			registerActionEvent('TOGGLE_COLLECTION', 'toggleCollectionModeEventId', 'actionEventToggleCollectionMode', topPriority)

			if not spec.isLogTrailer then
				registerActionEvent('TOGGLE_FILTER', 'toggleLoadingFilterActionEventId', 'actionEventToggleFilter', midPriority)
				spec.updateToggleFilter = true
			end
			
			if not spec.isLogTrailer then
				registerActionEvent('TOGGLE_HORIZONTAL', 'toggleHorizontalLoadingActionEventId', 'actionEventToggleHorizontalLoading', midPriority)
				spec.updateHorizontalLoading = true

				registerActionEvent('CYCLE_MATERIAL_FW', 'cycleMaterialActionEventId', 'actionEventCycleMaterial_FW', midPriority)
				registerActionEvent('CYCLE_MATERIAL_BW', 'cycleMaterialBwActionEventId', 'actionEventCycleMaterial_BW', lowPriority, false)
				registerActionEvent('SELECT_ALL_MATERIALS', 'selectAllMaterialsEventId', 'actionEventSelectAllMaterials', lowPriority, false)
				spec.updateCycleMaterial = true
				
				if UniversalAutoload.chatKeyConflict ~= true then
					registerActionEvent('CYCLE_CONTAINER_FW', 'cycleContainerActionEventId', 'actionEventCycleContainer_FW', midPriority)
					registerActionEvent('CYCLE_CONTAINER_BW', 'cycleContainerBwActionEventId', 'actionEventCycleContainer_BW', lowPriority, false)
					registerActionEvent('SELECT_ALL_CONTAINERS', 'selectAllContainersActionEventId', 'actionEventSelectAllContainers', lowPriority, false)
					spec.updateCycleContainer = true
				end
			end

			if not spec.isCurtainTrailer and not spec.rearUnloadingOnly and not spec.frontUnloadingOnly then
				registerActionEvent('TOGGLE_TIPSIDE', 'toggleTipsideActionEventId', 'actionEventToggleTipside', midPriority)
				spec.updateToggleTipside = true
			end
			
			-- if g_localPlayer.isControlled then
			
				-- if not g_currentMission.missionDynamicInfo.isMultiplayer and self.spec_tensionBelts then
					-- registerActionEvent('TOGGLE_BELTS', 'toggleBeltsActionEventId', 'actionEventToggleBelts', midPriority)
					-- spec.updateToggleBelts = true
				-- end
				
				-- if spec.isCurtainTrailer or spec.isBoxTrailer then
					-- registerActionEvent('TOGGLE_DOOR', 'toggleDoorActionEventId', 'actionEventToggleDoor', midPriority)
					-- spec.updateToggleDoor = true
				-- end
					
				-- if spec.isCurtainTrailer then
					-- registerActionEvent('TOGGLE_CURTAIN', 'toggleCurtainActionEventId', 'actionEventToggleCurtain', midPriority)
					-- spec.updateToggleCurtain = true
				-- end
				
			-- end
			
			registerActionEvent('TOGGLE_SHOW_DEBUG', 'toggleShowDebugActionEventId', 'actionEventToggleShowDebug', lowPriority)
			registerActionEvent('TOGGLE_SHOW_LOADING', 'toggleShowLoadingActionEventId', 'actionEventToggleShowLoading', lowPriority)

			UniversalAutoload.debugPrint("*** updateActionEventKeys ***", debugKeys)
		end
	end
end
--
function UniversalAutoload:updateToggleBeltsActionEvent()
	--UniversalAutoload.debugPrint("updateToggleBeltsActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleBeltsActionEventId then

		g_inputBinding:setActionEventActive(spec.toggleBeltsActionEventId, true)
		
		local tensionBeltsText
		if self.spec_tensionBelts.areAllBeltsFastened then
			tensionBeltsText = g_i18n:getText("action_unfastenTensionBelts")
		else
			tensionBeltsText = g_i18n:getText("action_fastenTensionBelts")
		end
		g_inputBinding:setActionEventText(spec.toggleBeltsActionEventId, tensionBeltsText)
		g_inputBinding:setActionEventTextVisibility(spec.toggleBeltsActionEventId, true)

	end
end
--
function UniversalAutoload:updateToggleDoorActionEvent()
	--UniversalAutoload.debugPrint("updateToggleDoorActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	local foldable = self.spec_foldable

	if g_localPlayer.isControlled then
		if spec and spec.isAutoloadAvailable and self.spec_foldable and (spec.isCurtainTrailer or spec.isBoxTrailer) then
			local direction = self:getToggledFoldDirection()

			local toggleDoorText = ""
			if direction == foldable.turnOnFoldDirection then
				toggleDoorText = foldable.negDirectionText
			else
				toggleDoorText = foldable.posDirectionText
			end

			g_inputBinding:setActionEventText(spec.toggleDoorActionEventId, toggleDoorText)
			g_inputBinding:setActionEventTextVisibility(spec.toggleDoorActionEventId, true)
		end
	else
		if spec and spec.isAutoloadAvailable and self.spec_foldable and self.isClient then
			Foldable.updateActionEventFold(self)
		end
	end
end
--
function UniversalAutoload:updateToggleCurtainActionEvent()
	--UniversalAutoload.debugPrint("updateToggleCurtainActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and g_localPlayer.isControlled then
		if self.spec_trailer and spec.isCurtainTrailer then
			local trailer = self.spec_trailer
			local tipSide = trailer.tipSides[trailer.preferedTipSideIndex]
			
			if tipSide then
				local toggleCurtainText = nil
				local tipState = self:getTipState()
				if tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING then
					toggleCurtainText = tipSide.manualTipToggleActionTextPos
				else
					toggleCurtainText = tipSide.manualTipToggleActionTextNeg
				end
				g_inputBinding:setActionEventText(spec.toggleCurtainActionEventId, toggleCurtainText)
				g_inputBinding:setActionEventTextVisibility(spec.toggleCurtainActionEventId, true)
			end
		end
	end
end

--
function UniversalAutoload:updateCycleMaterialActionEvent()
	--UniversalAutoload.debugPrint("updateCycleMaterialActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.cycleMaterialActionEventId then
		-- Material Type: ALL / <MATERIAL>
		if not spec.isLoading then
			local materialTypeText = g_i18n:getText("universalAutoload_materialType")..": "..UniversalAutoload.getSelectedMaterialText(self)
			g_inputBinding:setActionEventText(spec.cycleMaterialActionEventId, materialTypeText)
			g_inputBinding:setActionEventTextVisibility(spec.cycleMaterialActionEventId, true)
		end

	end
end
--
function UniversalAutoload:updateCycleContainerActionEvent()
	--UniversalAutoload.debugPrint("updateCycleContainerActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.cycleContainerActionEventId then
		-- Container Type: ALL / <PALLET_TYPE>
		if not spec.isLoading then
			local containerTypeText = g_i18n:getText("universalAutoload_containerType")..": "..UniversalAutoload.getSelectedContainerText(self)
			g_inputBinding:setActionEventText(spec.cycleContainerActionEventId, containerTypeText)
			g_inputBinding:setActionEventTextVisibility(spec.cycleContainerActionEventId, true)
		end
	end
end
--
function UniversalAutoload:updateToggleFilterActionEvent()
	--UniversalAutoload.debugPrint("updateToggleFilterActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleLoadingFilterActionEventId then
		-- Loading Filter: ANY / FULL ONLY
		local loadingFilterText
		if spec.currentLoadingFilter then
			loadingFilterText = g_i18n:getText("universalAutoload_loadingFilter")..": "..g_i18n:getText("universalAutoload_fullOnly")
		else
			loadingFilterText = g_i18n:getText("universalAutoload_loadingFilter")..": "..g_i18n:getText("universalAutoload_loadAny")
		end
		g_inputBinding:setActionEventText(spec.toggleLoadingFilterActionEventId, loadingFilterText)
		g_inputBinding:setActionEventTextVisibility(spec.toggleLoadingFilterActionEventId, true)
	end
end
--
function UniversalAutoload:updateHorizontalLoadingActionEvent()
	--UniversalAutoload.debugPrint("updateHorizontalLoadingActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleHorizontalLoadingActionEventId then
		-- Loading Filter: ANY / FULL ONLY
		local horizontalLoadingText
		if spec.useHorizontalLoading then
			horizontalLoadingText = g_i18n:getText("universalAutoload_loadingMethod")..": "..g_i18n:getText("universalAutoload_layer")
		else
			horizontalLoadingText = g_i18n:getText("universalAutoload_loadingMethod")..": "..g_i18n:getText("universalAutoload_stack")
		end
		g_inputBinding:setActionEventText(spec.toggleHorizontalLoadingActionEventId, horizontalLoadingText)
		g_inputBinding:setActionEventTextVisibility(spec.toggleHorizontalLoadingActionEventId, true)
	end
end
--
function UniversalAutoload:updateToggleTipsideActionEvent()
	--UniversalAutoload.debugPrint("updateToggleTipsideActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleTipsideActionEventId then
		-- Tipside: NONE/BOTH/LEFT/RIGHT/
		if spec.currentTipside == "none" then
			g_inputBinding:setActionEventActive(spec.toggleTipsideActionEventId, false)
		else
			local tipsideText = g_i18n:getText("universalAutoload_tipside")..": "..g_i18n:getText("universalAutoload_"..(spec.currentTipside or "none"))
			g_inputBinding:setActionEventText(spec.toggleTipsideActionEventId, tipsideText)
			g_inputBinding:setActionEventTextVisibility(spec.toggleTipsideActionEventId, true)
		end
	end
end
--
function UniversalAutoload:updateToggleLoadingActionEvent()
	--UniversalAutoload.debugPrint("updateToggleLoadingActionEvent", debugKeys)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and spec.toggleCollectionModeEventId then
		-- Activate/Deactivate the AUTO-BALE key binding
		if spec.autoCollectionMode or spec.validUnloadCount==0 then
			local autoCollectionModeText = g_i18n:getText("universalAutoload_collectionMode")
			if spec.autoCollectionMode then
				if spec.baleCollectionActive == true then
					autoCollectionModeText = g_i18n:getText("universalAutoload_baleMode")
				elseif spec.baleCollectionActive == false then
					if spec.isLogTrailer then
						autoCollectionModeText = g_i18n:getText("universalAutoload_logMode")
					else
						autoCollectionModeText = g_i18n:getText("universalAutoload_palletMode")
					end
				end
				autoCollectionModeText = autoCollectionModeText..": "..g_i18n:getText("universalAutoload_enabled")
			else
				autoCollectionModeText = autoCollectionModeText..": "..g_i18n:getText("universalAutoload_disabled")
			end
				
			g_inputBinding:setActionEventText(spec.toggleCollectionModeEventId, autoCollectionModeText)
			g_inputBinding:setActionEventActive(spec.toggleCollectionModeEventId, true)
			g_inputBinding:setActionEventTextVisibility(spec.toggleCollectionModeEventId, true)
			UniversalAutoload.debugPrint("   >> " .. tostring(autoCollectionModeText), debugKeys)
		else
			g_inputBinding:setActionEventActive(spec.toggleCollectionModeEventId, false)
		end
	end
	
	if spec and spec.isAutoloadAvailable and spec.toggleLoadingActionEventId then
		-- Activate/Deactivate the LOAD key binding
		if spec.isLoading and not spec.autoCollectionMode then
			local stopLoadingText = g_i18n:getText("universalAutoload_stopLoading")
			g_inputBinding:setActionEventText(spec.toggleLoadingActionEventId, stopLoadingText)
			UniversalAutoload.debugPrint("   >> " .. tostring(stopLoadingText), debugKeys)
		else
			if UniversalAutoload.getIsLoadingKeyAllowed(self) == true then
				local startLoadingText = g_i18n:getText("universalAutoload_startLoading")
				if debugLoading then startLoadingText = startLoadingText.." ("..tostring(spec.validLoadCount)..")" end
				g_inputBinding:setActionEventText(spec.toggleLoadingActionEventId, startLoadingText)
				g_inputBinding:setActionEventActive(spec.toggleLoadingActionEventId, true)
				g_inputBinding:setActionEventTextVisibility(spec.toggleLoadingActionEventId, true)
				UniversalAutoload.debugPrint("   >> " .. tostring(startLoadingText), debugKeys)
			else
				g_inputBinding:setActionEventActive(spec.toggleLoadingActionEventId, false)
			end
		end
	end

	if spec and spec.isAutoloadAvailable and spec.unloadAllActionEventId then
		-- Activate/Deactivate the UNLOAD key binding
		if UniversalAutoload.getIsUnloadingKeyAllowed(self) == true then
			local unloadText = g_i18n:getText("universalAutoload_unloadAll")
			if debugLoading then unloadText = unloadText.." ("..tostring(spec.validUnloadCount)..")" end
			g_inputBinding:setActionEventText(spec.unloadAllActionEventId, unloadText)
			g_inputBinding:setActionEventActive(spec.unloadAllActionEventId, true)
			g_inputBinding:setActionEventTextVisibility(spec.unloadAllActionEventId, true)
			UniversalAutoload.debugPrint("   >> " .. unloadText, debugKeys)
		else
			g_inputBinding:setActionEventActive(spec.unloadAllActionEventId, false)
		end
	end
	
end

-- ACTION EVENTS
function UniversalAutoload.actionEventToggleBelts(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleBelts: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if self.spec_tensionBelts.areAllBeltsFastened then
		self:setAllTensionBeltsActive(false)
	else
		self:setAllTensionBeltsActive(true)
	end
	spec.updateToggleBelts = true
end
--
function UniversalAutoload.actionEventToggleDoor(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleDoor: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local foldable = self.spec_foldable
	if #foldable.foldingParts > 0 then
		local toggleDirection = self:getToggledFoldDirection()
		if toggleDirection == foldable.turnOnFoldDirection then
			self:setFoldState(toggleDirection, true)
		else
			self:setFoldState(toggleDirection, false)
		end
	end
	spec.updateToggleDoor = true
end
--
function UniversalAutoload.actionEventToggleCurtain(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleCurtain: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local tipState = self:getTipState()
	if tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING then
		self:startTipping(nil, false)
		TrailerToggleManualTipEvent.sendEvent(self, true)
	else
		self:stopTipping()
		TrailerToggleManualTipEvent.sendEvent(self, false)
	end
	spec.updateToggleCurtain = true
end
--
function UniversalAutoload.actionEventToggleShowDebug(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleShowDebug: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if self.isClient then
		UniversalAutoload.showDebug = not UniversalAutoload.showDebug
		UniversalAutoload.showLoading = UniversalAutoload.showDebug
	end
end
--
function UniversalAutoload.actionEventToggleShowLoading(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleShowLoading: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if self.isClient then
		UniversalAutoload.showLoading = not UniversalAutoload.showLoading
		if UniversalAutoload.showLoading == false then
			UniversalAutoload.showDebug = false
		end
	end
end
--
function UniversalAutoload.actionEventToggleCollectionMode(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleCollectionMode: "..self:getFullName())
	local spec = self.spec_universalAutoload
	UniversalAutoload.setAutoCollectionMode(self, not spec.autoCollectionMode)
end
--
function UniversalAutoload.actionEventCycleMaterial_FW(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventCycleMaterial_FW: "..self:getFullName())
	UniversalAutoload.cycleMaterialTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventCycleMaterial_BW(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventCycleMaterial_BW: "..self:getFullName())
	UniversalAutoload.cycleMaterialTypeIndex(self, -1)
end
--
function UniversalAutoload.actionEventSelectAllMaterials(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventSelectAllMaterials: "..self:getFullName())
	UniversalAutoload.setMaterialTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventCycleContainer_FW(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventCycleContainer_FW: "..self:getFullName())
	UniversalAutoload.cycleContainerTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventCycleContainer_BW(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventCycleContainer_BW: "..self:getFullName())
	UniversalAutoload.cycleContainerTypeIndex(self, -1)
end
--
function UniversalAutoload.actionEventSelectAllContainers(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventSelectAllContainers: "..self:getFullName())
	UniversalAutoload.setContainerTypeIndex(self, 1)
end
--
function UniversalAutoload.actionEventToggleFilter(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleFilter: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local state = not spec.currentLoadingFilter
	UniversalAutoload.setLoadingFilter(self, state)
end
--
function UniversalAutoload.actionEventToggleHorizontalLoading(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleHorizontalLoading: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local state = not spec.useHorizontalLoading
	UniversalAutoload.setHorizontalLoading(self, state)
end
--
function UniversalAutoload.actionEventToggleTipside(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("actionEventToggleTipside: "..self:getFullName())
	local spec = self.spec_universalAutoload
	local tipside
	if spec.currentTipside == "left" then
		tipside = "right"
	else
		tipside = "left"
	end
	UniversalAutoload.setCurrentTipside(self, tipside)
end
--
function UniversalAutoload.actionEventToggleLoading(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("CALLBACK actionEventToggleLoading: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if not spec.isLoading then
		UniversalAutoload.debugPrint("START Loading: "..self:getFullName() .. " (" .. tostring(spec.totalUnloadCount) .. ")")
		UniversalAutoload.startLoading(self)
	else
		UniversalAutoload.debugPrint("STOP Loading: "..self:getFullName() .. " (" .. tostring(spec.totalUnloadCount) .. ")")
		UniversalAutoload.stopLoading(self)
	end
end
--
function UniversalAutoload.actionEventUnloadAll(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("CALLBACK actionEventUnloadAll: "..self:getFullName())
	local spec = self.spec_universalAutoload
	UniversalAutoload.debugPrint("UNLOAD ALL: "..self:getFullName() .. " (" .. tostring(spec.totalUnloadCount) .. ")")
	UniversalAutoload.startUnloading(self)
end
--
function UniversalAutoload.actionEventGlobalMenu(self, actionName, inputValue, callbackState, isAnalog)
	-- UniversalAutoload.debugPrint("CALLBACK actionEventGlobalMenu: "..self:getFullName())
	local spec = self.spec_universalAutoload
	UniversalAutoload.debugPrint("GLOBAL MENU: " .. self:getFullName())
	UniversalAutoloadManager.globalSettingsMenu:setNewVehicle(self)
	UniversalAutoloadManager:onOpenGlobalSettingsEvent('UNIVERSALAUTOLOAD_GLOBAL_CONFIG', 1)
end

-- EVENT FUNCTIONS
function UniversalAutoload:cycleMaterialTypeIndex(direction, noEventSend)
	local spec = self.spec_universalAutoload
	
	if self.isServer then
		local materialIndex
		if direction == 1 then
			materialIndex = 999
			for object, _ in pairs(spec.availableObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex > spec.currentMaterialIndex and objectMaterialIndex < materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
			for object, _ in pairs(spec.loadedObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex > spec.currentMaterialIndex and objectMaterialIndex < materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
		else
			materialIndex = 0
			local startingValue = (spec.currentMaterialIndex==1) and #UniversalAutoload.MATERIALS+1 or spec.currentMaterialIndex
			for object, _ in pairs(spec.availableObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)	
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex < startingValue and objectMaterialIndex > materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
			for object, _ in pairs(spec.loadedObjects or {}) do
				local objectMaterialName = UniversalAutoload.getMaterialTypeName(object)	
				local objectMaterialIndex = UniversalAutoload.MATERIALS_INDEX[objectMaterialName] or 1
				if objectMaterialIndex < startingValue and objectMaterialIndex > materialIndex then
					materialIndex = objectMaterialIndex
				end
			end
		end
		if materialIndex == nil or materialIndex == 0 or materialIndex == 999 then
			materialIndex = 1
		end
		
		UniversalAutoload.setMaterialTypeIndex(self, materialIndex)
		if materialIndex==1 and spec.totalAvailableCount==0 and spec.totalUnloadCount==0 then
			-- NO_OBJECTS_FOUND
			UniversalAutoload.showWarningMessage(self, "NO_OBJECTS_FOUND")
		end
	end
	
	UniversalAutoload.CycleMaterialEvent.sendEvent(self, direction, noEventSend)
end
--
function UniversalAutoload:setMaterialTypeIndex(typeIndex, noEventSend)
	-- UniversalAutoload.debugPrint("setMaterialTypeIndex: "..self:getFullName().." "..tostring(typeIndex))
	local spec = self.spec_universalAutoload

	spec.currentMaterialIndex = math.min(math.max(typeIndex, 1), table.getn(UniversalAutoload.MATERIALS))

	UniversalAutoload.SetMaterialTypeEvent.sendEvent(self, typeIndex, noEventSend)
	
	spec.updateCycleMaterial = true
	
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
	end
end
--
function UniversalAutoload:cycleContainerTypeIndex(direction, noEventSend)
	local spec = self.spec_universalAutoload
	if self.isServer then
		local containerIndex
		if direction == 1 then
			containerIndex = 999
			for object, _ in pairs(spec.availableObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex > spec.currentContainerIndex and objectContainerIndex < containerIndex then
					containerIndex = objectContainerIndex
				end
			end
			for object, _ in pairs(spec.loadedObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex > spec.currentContainerIndex and objectContainerIndex < containerIndex then
					containerIndex = objectContainerIndex
				end
			end
		else
			containerIndex = 0
			local startingValue = (spec.currentContainerIndex==1) and #UniversalAutoload.CONTAINERS+1 or spec.currentContainerIndex
			for object, _ in pairs(spec.availableObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex < startingValue and objectContainerIndex > containerIndex then
					containerIndex = objectContainerIndex
				end
			end
			for object, _ in pairs(spec.loadedObjects or {}) do
				local objectContainerName = UniversalAutoload.getContainerTypeName(object)
				local objectContainerIndex = UniversalAutoload.CONTAINERS_LOOKUP[objectContainerName] or 1
				if objectContainerIndex < startingValue and objectContainerIndex > containerIndex then
					containerIndex = objectContainerIndex
				end
			end
		end
		if containerIndex == nil or containerIndex == 0 or containerIndex == 999 then
			containerIndex = 1
		end
		
		UniversalAutoload.setContainerTypeIndex(self, containerIndex)
		if containerIndex==1 and spec.totalAvailableCount==0 and spec.totalUnloadCount==0 then
			-- NO_OBJECTS_FOUND
			UniversalAutoload.showWarningMessage(self, "NO_OBJECTS_FOUND")
		end
	end
	
	UniversalAutoload.CycleContainerEvent.sendEvent(self, direction, noEventSend)
end
--
function UniversalAutoload:setContainerTypeIndex(typeIndex, noEventSend)
	-- UniversalAutoload.debugPrint("setContainerTypeIndex: "..self:getFullName().." "..tostring(typeIndex))
	local spec = self.spec_universalAutoload

	spec.currentContainerIndex = math.min(math.max(typeIndex, 1), table.getn(UniversalAutoload.CONTAINERS))

	UniversalAutoload.SetContainerTypeEvent.sendEvent(self, typeIndex, noEventSend)
	spec.updateCycleContainer = true
	
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
	end
end
--
function UniversalAutoload:setLoadingFilter(state, noEventSend)
	-- UniversalAutoload.debugPrint("setLoadingFilter: "..self:getFullName().." "..tostring(state))
	local spec = self.spec_universalAutoload
	
	spec.currentLoadingFilter = state
	
	UniversalAutoload.SetFilterEvent.sendEvent(self, state, noEventSend)
	
	spec.updateToggleFilter = true
	
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
	end
end
--
function UniversalAutoload:setHorizontalLoading(state, noEventSend)
	-- UniversalAutoload.debugPrint("setHorizontalLoading: "..self:getFullName().." "..tostring(state))
	local spec = self.spec_universalAutoload

	spec.useHorizontalLoading = state
	
	UniversalAutoload.SetHorizontalLoadingEvent.sendEvent(self, state, noEventSend)
	
	spec.updateHorizontalLoading = true
	
	if self.isServer then
		if UniversalAutoload.testLoadAreaIsEmpty(self) then
			UniversalAutoload.resetLoadingArea(self)
		end
	end
end
--
function UniversalAutoload:setCurrentTipside(tipside, noEventSend)
	-- UniversalAutoload.debugPrint("setTipside: "..self:getFullName().." - "..tostring(tipside))
	local spec = self.spec_universalAutoload
	
	spec.currentTipside = tipside
	
	UniversalAutoload.SetTipsideEvent.sendEvent(self, tipside, noEventSend)
	spec.updateToggleTipside = true
end
--
function UniversalAutoload:setCurrentLoadside(loadside, noEventSend)
	-- UniversalAutoload.debugPrint("setLoadside: "..self:getFullName().." - "..tostring(loadside))
	local spec = self.spec_universalAutoload
	
	spec.currentLoadside = loadside
	
	UniversalAutoload.SetLoadsideEvent.sendEvent(self, loadside, noEventSend)
	if self.isServer then
		UniversalAutoload.countActivePallets(self)
		UniversalAutoload.updateActionEventText(self)
	end
end
--

function UniversalAutoload:setAutoCollectionMode(autoCollectionMode, noEventSend)
	-- UniversalAutoload.debugPrint("setAutoCollectionMode: "..self:getFullName().." - "..tostring(autoCollectionMode))
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - setAutoCollectionMode", debugVehicles)
		return
	end
		
	if self.isServer and spec.autoCollectionMode ~= autoCollectionMode then
		if autoCollectionMode then
			if not spec.trailerIsFull then
				local balesAvailable = spec.availableBaleCount and spec.availableBaleCount > 0
				local palletsAvailable = spec.totalAvailableCount and spec.totalAvailableCount > 0
				if balesAvailable and not spec.isLogTrailer then
					UniversalAutoload.debugPrint("autoCollectionMode: startLoading (bales)", debugSpecial)
					spec.baleCollectionActive = true
				elseif palletsAvailable then
					UniversalAutoload.debugPrint("autoCollectionMode: startLoading (pallets/logs)", debugSpecial)
					spec.baleCollectionActive = false
				else
					UniversalAutoload.debugPrint("autoCollectionMode: startLoading (unknown)", debugSpecial)
					spec.baleCollectionActive = nil
				end
				UniversalAutoload.startLoading(self)
			end
		else
			UniversalAutoload.debugPrint("autoCollectionMode: stopLoading", debugSpecial)
			UniversalAutoload.stopLoading(self)
			if spec.baleCollectionActive then
				spec.baleCollectionModeDeactivated = true
			end
			spec.baleCollectionActive = nil
		end
	end
	
	spec.autoCollectionMode = autoCollectionMode

	UniversalAutoload.SetCollectionModeEvent.sendEvent(self, autoCollectionMode, noEventSend)
	spec.updateToggleLoading = true
end
--
function UniversalAutoload:startLoading(force, noEventSend)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - startLoading", debugVehicles)
		return
	end

	if force then
		spec.activeLoading = true
	end
	
	if (not spec.isLoading or spec.activeLoading) and UniversalAutoload.getIsLoadingVehicleAllowed(self) then
		-- UniversalAutoload.debugPrint("Start Loading: "..self:getFullName() )
		
		if spec.palletsRemovedFromPhysics then
			-- print("startLoading - add pallets back to Physics")
			if not self:ualGetIsMoving() then
				self:setAllTensionBeltsActive(false)
				UniversalAutoload.togglePhysicsForLoadedObjects(self)
				self.delayStartLoading = true
			end
			return
		end

		spec.isLoading = true
		spec.firstAttemptToLoad = true
		
		if self.isServer then
		
			spec.loadDelayTime = math.huge
			if not spec.autoCollectionMode and UniversalAutoload.testLoadAreaIsEmpty(self) then
				UniversalAutoload.resetLoadingArea(self)
			end
		
			spec.sortedObjectsToLoad = UniversalAutoload.createSortedObjectsToLoad(self, spec.availableObjects)
		end
		
		UniversalAutoload.StartLoadingEvent.sendEvent(self, force, noEventSend)
		spec.updateToggleLoading = true
	end
end
--
function UniversalAutoload:createSortedObjectsToLoad(availableObjects)
	local spec = self.spec_universalAutoload
	
	sortedObjectsToLoad = {}
	if not spec.loadArea or #spec.loadArea == 0 then
		return sortedObjectsToLoad
	end
	
	for object, _ in pairs(availableObjects or {}) do

		local node = UniversalAutoload.getObjectPositionNode(object)
		if node~=nil and UniversalAutoload.isValidForLoading(self, object) then
		
			local containerType = UniversalAutoload.getContainerType(object)
			local x, y, z = localToLocal(node, spec.loadArea[1].startNode, 0, 0, 0)
			object.sort = {}
			object.sort.height = y
			object.sort.distance = math.abs(x) + math.abs(z)
			object.sort.area = (containerType.sizeX * containerType.sizeZ) or 1
			object.sort.material = UniversalAutoload.getMaterialType(object) or 1
			table.insert(sortedObjectsToLoad, object)
		end
	end
	if #sortedObjectsToLoad > 1 then
		if spec.isLogTrailer then
			table.sort(sortedObjectsToLoad, UniversalAutoload.sortLogsForLoading)
		else
			table.sort(sortedObjectsToLoad, UniversalAutoload.sortPalletsForLoading)
		end
	end
	for _, object in pairs(sortedObjectsToLoad or {}) do
		object.sort = nil
	end
	UniversalAutoload.debugPrint(self:getFullName() .. " #sortedObjectsToLoad = " .. tostring(#sortedObjectsToLoad), debugLoading)
	return sortedObjectsToLoad
end
--
function UniversalAutoload.sortPalletsForLoading(w1,w2)
	-- SORT BY:  AREA > MATERIAL > HEIGHT > DISTANCE
	if w1.sort.area == w2.sort.area and w1.sort.material == w2.sort.material and w1.sort.height == w2.sort.height and w1.sort.distance < w2.sort.distance then
		return true
	elseif w1.sort.area == w2.sort.area and w1.sort.material == w2.sort.material and w1.sort.height > w2.sort.height then
		return true
	elseif w1.sort.area == w2.sort.area and w1.sort.material < w2.sort.material then
		return true
	elseif w1.sort.area > w2.sort.area then
		return true
	end
end
--
function UniversalAutoload.sortLogsForLoading(w1,w2)
	-- SORT BY:  LENGTH
	if w1.sizeY > w2.sizeY then
		return true
	end
end
--
function UniversalAutoload:stopLoading(force, noEventSend)
	local spec = self.spec_universalAutoload
	
	if force then
		spec.activeLoading = false
	end
	
	if spec.isLoading and not spec.activeLoading then
		-- UniversalAutoload.debugPrint("Stop Loading: "..self:getFullName() )
		spec.isLoading = false
		spec.doPostLoadDelay = true
		
		if self.isServer then
			spec.loadDelayTime = 0

			if spec.validUnloadCount > 0 and not self.spec_tensionBelts.areAllBeltsFastened and not spec.baleCollectionActive then
				spec.doSetTensionBelts = true
			end
		end
		
		UniversalAutoload.StopLoadingEvent.sendEvent(self, force, noEventSend)
		spec.updateToggleLoading = true
	end
end
--
function UniversalAutoload:startUnloading(force, noEventSend)
	local spec = self.spec_universalAutoload

	if not spec.isUnloading then
		
		if spec.autoCollectionMode then
			UniversalAutoload.setAutoCollectionMode(self, false)
		end
		
		-- UniversalAutoload.debugPrint("Start Unloading: "..self:getFullName() )
		spec.isUnloading = true

		if self.isServer then

			if spec.loadedObjects then
				
				self:setAllTensionBeltsActive(false)
				UniversalAutoload.togglePhysicsForLoadedObjects(self)
				
				if force and spec.forceUnloadPosition then
					UniversalAutoload.debugPrint("USING UNLOADING POSITION: " .. tostring(spec.forceUnloadPosition), debugLoading)
					UniversalAutoload.buildObjectsToUnloadTable(self, spec.forceUnloadPosition)
				else
					UniversalAutoload.buildObjectsToUnloadTable(self)
				end
			end

			if spec.objectsToUnload and (spec.unloadingAreaClear or force) then
				self:setAllTensionBeltsActive(false)
				for object, unloadPlace in pairs(spec.objectsToUnload or {}) do
					if not UniversalAutoload.unloadObject(self, object, unloadPlace) then
						UniversalAutoload.debugPrint("THERE WAS A PROBLEM UNLOADING...", debugLoading)
					end
				end
				spec.objectsToUnload = {}
				spec.currentLoadingPlace = nil
				if spec.totalUnloadCount == 0 then
					UniversalAutoload.debugPrint("FULLY UNLOADED...", debugLoading)
					UniversalAutoload.resetLoadingArea(self)
				else
					UniversalAutoload.debugPrint("PARTIALLY UNLOADED...", debugLoading)
					spec.partiallyUnloaded = true
					
					if UniversalAutoload.isUsingAutoStrap(self) then
						spec.doSetTensionBelts = true
						spec.doPostLoadDelay = true
					end
				end
			else
				-- CLEAR_UNLOADING_AREA
				UniversalAutoload.showWarningMessage(self, "CLEAR_UNLOADING_AREA")
			end
		end
		
		spec.isUnloading = false
		spec.doPostLoadDelay = true

		UniversalAutoload.StartUnloadingEvent.sendEvent(self, force, noEventSend)
		
		spec.updateToggleLoading = true
	end
end
--

function UniversalAutoload:showWarningMessage(message)
	local messageId = UniversalAutoload.WARNINGS_BY_NAME[message] or message
	UniversalAutoload.showWarningMessageById(self, messageId, noEventSend)
end

function UniversalAutoload:showWarningMessageById(messageId, noEventSend)
	-- UniversalAutoload.debugPrint("Show Warning Message: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if self.isClient and g_dedicatedServer==nil then
		-- UniversalAutoload.debugPrint("CLIENT: "..g_i18n:getText(UniversalAutoload.WARNINGS[messageId]))
		local rootVehicle = self:getRootVehicle(self)
		local currentVehicle = g_localPlayer and g_localPlayer:getCurrentVehicle()
		if currentVehicle and rootVehicle and currentVehicle == rootVehicle then
			g_currentMission:showBlinkingWarning(g_i18n:getText(UniversalAutoload.WARNINGS[messageId]), 2000);
		end
		
	elseif self.isServer then
		-- UniversalAutoload.debugPrint("SERVER: "..g_i18n:getText(UniversalAutoload.WARNINGS[messageId]))
		UniversalAutoload.WarningMessageEvent.sendEvent(self, messageId, noEventSend)
	end
end
--
function UniversalAutoload:resetLoadingState(noEventSend)
	-- UniversalAutoload.debugPrint("RESET Loading State: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if self.isServer then
		if spec.doSetTensionBelts and not spec.baleCollectionActive and UniversalAutoload.isUsingAutoStrap(self) then
			if spec.totalUnloadCount > 0 then
				self:setAllTensionBeltsActive(true)
			end
		end
		spec.postLoadDelayTime = 0
	end
	
	spec.doPostLoadDelay = false
	spec.doSetTensionBelts = false
	
	UniversalAutoload.ResetLoadingEvent.sendEvent(self, noEventSend)
	
	spec.updateToggleLoading = true
end
--
function UniversalAutoload:updateActionEventText(loadCount, unloadCount, noEventSend)
	-- UniversalAutoload.debugPrint("updateActionEventText: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if self.isClient then
		if loadCount ~= nil then
			spec.validLoadCount = loadCount
		end
		if unloadCount ~= nil then
			spec.validUnloadCount = unloadCount
		end
		-- UniversalAutoload.debugPrint("Valid Load Count = " .. tostring(spec.validLoadCount) .. " / " .. tostring(spec.validUnloadCount) )
	end
	
	if self.isServer then
		-- UniversalAutoload.debugPrint("updateActionEventText - SEND EVENT")
		UniversalAutoload.UpdateActionEvents.sendEvent(self, spec.validLoadCount, spec.validUnloadCount, noEventSend)
	end
	
	spec.updateToggleLoading = true
end
--
function UniversalAutoload:forceRaiseActive(state, noEventSend)
	-- UniversalAutoload.debugPrint("forceRaiseActive: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	spec.updateToggleLoading = true
	
	if self.isServer then
		-- UniversalAutoload.debugPrint("SERVER RAISE ACTIVE: "..self:getFullName().." ("..tostring(state)..")")
		self:raiseActive()
		
		UniversalAutoload.determineTipside(self)
		UniversalAutoload.countActivePallets(self)
	end
	
	if state then
		-- UniversalAutoload.debugPrint("Activated = "..tostring(state))
		spec.isActivated = state
	end
	
	UniversalAutoload.RaiseActiveEvent.sendEvent(self, state, noEventSend)
end
--
function UniversalAutoload:updatePlayerTriggerState(playerId, inTrigger, noEventSend)
	-- UniversalAutoload.debugPrint("updatePlayerTriggerState: "..self:getFullName() )
	local spec = self.spec_universalAutoload
	
	if playerId then
		spec.playerInTrigger[playerId] = inTrigger
	end
	
	UniversalAutoload.PlayerTriggerEvent.sendEvent(self, playerId, inTrigger, noEventSend)
end

function UniversalAutoload:updateVelocityCorrection()
	local spec = self.spec_universalAutoload
	
	if not self.rootNode then
		return
	end
	
	local dt = g_currentDt * 0.001
	local x0,y0,z0 = UniversalAutoload.localToWorld(self.rootNode)
	local vx, vy, vz = getVelocityAtLocalPos(self.rootNode, 0, 0, 0)
	local dx, dy, dz = (vx or 0)*dt, (vy or 0)*dt, (vz or 0)*dt
	spec.velocityCorrection = { dx, dy, dz }

	if not (spec.autoCollectionMode or spec.palletsRemovedFromPhysics) then
		if not (spec.loadVolume and spec.loadVolume.transformGroup) then
			return
		end
		local nxx, nxy, nxz = UniversalAutoload.localDirectionToWorld(self.rootNode, 1, 0, 0)
		local nyx, nyy, nyz = UniversalAutoload.localDirectionToWorld(self.rootNode, 0, 1, 0)
		local nzx, nzy, nzz = UniversalAutoload.localDirectionToWorld(self.rootNode, 0, 0, 1)
		local dX = dx * nxx + dy * nxy + dz * nxz
		local dY = dx * nyx + dy * nyy + dz * nyz
		local dZ = dx * nzx + dy * nzy + dz * nzz
		setTranslation(spec.loadVolume.transformGroup, dX, dY, dZ)
	end
end

function UniversalAutoload:initialiseTransformGroups(actualRootNode)
	local spec = self.spec_universalAutoload

	local actualRootNode = actualRootNode or self.rootNode
	
	if not actualRootNode then
		UniversalAutoload.debugPrint("*** Root Node is UNDEFINED ***")
		return
	end
	
	if self.spec_tensionBelts and self.spec_tensionBelts.rootNode then
		local tensionBeltNode = self.spec_tensionBelts.rootNode
		local x0, y0, z0 = getTranslation(actualRootNode)
		local x1, y1, z1 = getTranslation(tensionBeltNode)
		if math.abs(x0-x1) > 0.0001 or math.abs(y0-y1) > 0.0001 or math.abs(z0-z1) > 0.0001 then
			UniversalAutoload.debugPrint("COULD USE TENSION BELT ROOT NODE")
			-- actualRootNode = tensionBeltNode
		end
	end
	-- local actualRootNode = (self.spec_tensionBelts and self.spec_tensionBelts.rootNode) or self.rootNode
	-- if spec.offsetRoot then
		-- local otherOffset = self.i3dMappings[spec.offsetRoot]
		-- if otherOffset then
			-- actualRootNode = otherOffset.nodeId or actualRootNode
		-- end
	-- end

	spec.loadVolume = {}
	spec.loadVolume.actualRootNode = actualRootNode
	spec.loadVolume.transformGroup = createTransformGroup("referenceNode")
	link(actualRootNode, spec.loadVolume.transformGroup)
	
	spec.loadVolume.rootNode = createTransformGroup("loadVolumeCentre")
	link(spec.loadVolume.transformGroup, spec.loadVolume.rootNode)

	spec.loadVolume.startNode = createTransformGroup("loadVolumeStart")
	link(spec.loadVolume.transformGroup, spec.loadVolume.startNode)
	
	spec.loadVolume.endNode = createTransformGroup("loadVolumeEnd")
	link(spec.loadVolume.transformGroup, spec.loadVolume.endNode)
	
	
	spec.loadVolume.width = self.size.width
	spec.loadVolume.height = self.size.height
	spec.loadVolume.length = self.size.length
	local offsetX = self.size.widthOffset
	local offsetY = self.size.heightOffset
	local offsetZ = self.size.lengthOffset
	setTranslation(spec.loadVolume.rootNode, offsetX, offsetY, offsetZ)
	setTranslation(spec.loadVolume.startNode, offsetX, offsetY, offsetZ+(spec.loadVolume.length/2))
	setTranslation(spec.loadVolume.endNode, offsetX, offsetY, offsetZ-(spec.loadVolume.length/2))

	-- load trigger i3d file
	local i3dFilename = UniversalAutoload.path .. "triggers/UniversalAutoloadTriggers.i3d"
	local triggersRootNode, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dFilename, false, false)

	-- create triggers
	local function doCreateTrigger(id, callback, width, height, length, tx, ty, tz, rx, ry, rz)
		local newTrigger = {}
		newTrigger.name = id
		newTrigger.node = I3DUtil.getChildByName(triggersRootNode, id)
		if newTrigger.node then
			link(spec.loadVolume.rootNode, newTrigger.node)
			addTrigger(newTrigger.node, callback, self)
			spec.triggers[id] = newTrigger
			-- UniversalAutoload.debugPrint("  created " .. newTrigger.name)
			
			if width and height and length then
				local trigger = newTrigger
				local d = 2*UniversalAutoload.TRIGGER_DELTA
				setScale(trigger.node, width-d, height-d, length-d)
				setRotation(trigger.node, rx or 0, ry or 0, rz or 0)
				setTranslation(trigger.node, tx or 0, ty or 0, tz or 0)
				
				local sx, sy, sz = getScale(trigger.node)
				trigger.sizeX = width
				trigger.sizeY = height
				trigger.sizeZ = length
				trigger.width = width/sx
				trigger.height = height/sy
				trigger.length = length/sz
				trigger.offset = {tx or 0, ty or 0, tz or 0}
				trigger.rotation = {rx or 0, ry or 0, rz or 0}
			end
		end
	end


	-- local width = 1.66*self.size.width
	-- local height = 1.66*self.size.height
	-- local length = self.size.length+self.size.width/2
	-- local tx, ty, tz = 1.1*(width+self.size.width)/2, 0, 0
	-- doCreateTrigger("leftPickupTrigger", "ualLoadingTrigger_Callback", width, height, length, tx, ty, tz)
	-- doCreateTrigger("rightPickupTrigger", "ualLoadingTrigger_Callback", width, height, length, -tx, ty, tz)

	doCreateTrigger("unloadingTrigger", "ualUnloadingTrigger_Callback")
	doCreateTrigger("playerTrigger", "ualPlayerTrigger_Callback")
	doCreateTrigger("leftPickupTrigger", "ualLoadingTrigger_Callback")
	doCreateTrigger("rightPickupTrigger", "ualLoadingTrigger_Callback")
	doCreateTrigger("rearPickupTrigger", "ualLoadingTrigger_Callback")
	doCreateTrigger("frontPickupTrigger", "ualLoadingTrigger_Callback")
	doCreateTrigger("rearAutoTrigger", "ualAutoLoadingTrigger_Callback")
	doCreateTrigger("leftAutoTrigger", "ualAutoLoadingTrigger_Callback")
	doCreateTrigger("rightAutoTrigger", "ualAutoLoadingTrigger_Callback")

	delete(triggersRootNode)
	
end

function UniversalAutoload:updateLoadAreaTransformGroups()
	local spec = self.spec_universalAutoload
	
	if not spec.loadArea or #spec.loadArea == 0 then
		UniversalAutoload.debugPrint("LoadArea NOT created")
		return
	end
	
	if not spec.loadVolume then
		UniversalAutoload.debugPrint("LoadVolume NOT created")
		return
	end

	local x0, y0, z0 = math.huge, math.huge, math.huge
	local x1, y1, z1 = -math.huge, -math.huge, -math.huge

	for i, loadArea in pairs(spec.loadArea) do
		-- create bounding box for loading area
		local offset = loadArea.offset
		local loadAreaRoot = spec.loadVolume.transformGroup
		-- if spec.loadArea[i].offsetRoot then
			-- local otherOffset = self.i3dMappings[spec.loadArea[i].offsetRoot]
			-- if otherOffset then
				-- loadAreaRoot = otherOffset.nodeId or loadAreaRoot
			-- end
		-- end
		loadArea.rootNode = createTransformGroup("LoadAreaCentre")
		link(loadAreaRoot, loadArea.rootNode)
		setTranslation(loadArea.rootNode, offset[1], offset[2], offset[3])

		loadArea.startNode = createTransformGroup("LoadAreaStart")
		link(loadAreaRoot, loadArea.startNode)
		setTranslation(loadArea.startNode, offset[1], offset[2], offset[3]+(loadArea.length/2))

		loadArea.endNode = createTransformGroup("LoadAreaEnd")
		link(loadAreaRoot, loadArea.endNode)
		setTranslation(loadArea.endNode, offset[1], offset[2], offset[3]-(loadArea.length/2))

		-- measure bounding box for all loading areas
		if x0 > offset[1]-(loadArea.width/2) then x0 = offset[1]-(loadArea.width/2) end
		if x1 < offset[1]+(loadArea.width/2) then x1 = offset[1]+(loadArea.width/2) end
		if y0 > offset[2] then y0 = offset[2] end
		if y1 < offset[2]+(loadArea.height) then y1 = offset[2]+(loadArea.height) end
		if z0 > offset[3]-(loadArea.length/2) then z0 = offset[3]-(loadArea.length/2) end
		if z1 < offset[3]+(loadArea.length/2) then z1 = offset[3]+(loadArea.length/2) end
	end
	
	if x0 == math.huge or y0 == math.huge or z0 == math.huge or
		x1 == -math.huge or y1 == -math.huge or z1 == -math.huge then
		UniversalAutoload.debugPrint("LoadArea size could not be calculated")
		return
	end
	
	spec.loadVolume.width = x1-x0
	spec.loadVolume.height = y1-y0
	spec.loadVolume.length = z1-z0
	
	local offsetX, offsetY, offsetZ = (x0+x1)/2, y0, (z0+z1)/2

	setTranslation(spec.loadVolume.rootNode, offsetX, offsetY, offsetZ)
	setTranslation(spec.loadVolume.startNode, offsetX, offsetY, offsetZ+(spec.loadVolume.length/2))
	setTranslation(spec.loadVolume.endNode, offsetX, offsetY, offsetZ-(spec.loadVolume.length/2))
	
	if self.spec_tensionBelts then
		if self.spec_tensionBelts.defaultHeight < spec.loadVolume.height then
			UniversalAutoload.debugPrint("UAL - set tension belt height: " .. tostring(spec.loadVolume.height))
			self.spec_tensionBelts.defaultHeight = spec.loadVolume.height
		end
	end

end

function UniversalAutoload:updateLoadingTriggers()
	local spec = self.spec_universalAutoload
	
	local function doRemoveTrigger(id)	
		local trigger = spec.triggers[id]
		if trigger then
			-- UniversalAutoload.debugPrint("  remove " .. trigger.name)
			removeTrigger(trigger.node)
			spec.triggers[id] = nil
			trigger = nil
		end
	end
	
	local function doUpdateTrigger(id, width, height, length, tx, ty, tz, rx, ry, rz)	
		local trigger = spec.triggers[id]
		if trigger then
			-- UniversalAutoload.debugPrint("  update " .. trigger.name)
			local d = 2*UniversalAutoload.TRIGGER_DELTA
			setScale(trigger.node, width-d, height-d, length-d)
			setRotation(trigger.node, rx or 0, ry or 0, rz or 0)
			setTranslation(trigger.node, tx or 0, ty or 0, tz or 0)

			local sx, sy, sz = getScale(trigger.node)
			trigger.sizeX = width
			trigger.sizeY = height
			trigger.sizeZ = length
			trigger.width = width/sx
			trigger.height = height/sy
			trigger.length = length/sz
			trigger.offset = {tx or 0, ty or 0, tz or 0}
			trigger.rotation = {rx or 0, ry or 0, rz or 0}
		end
	end
	
	-- create triggers
	local sideBoundary = 3.50 * UniversalAutoload.TRIGGER_DELTA
	local rearBoundary = 1.00 * UniversalAutoload.TRIGGER_DELTA
	if spec.enableSideLoading then
		sideBoundary = spec.loadVolume.width/4
	end
	if spec.enableRearLoading then
		rearBoundary = spec.loadVolume.width/4
	end

	local unloadingTrigger = spec.triggers["unloadingTrigger"]
	if unloadingTrigger then
		local width = spec.loadVolume.width-sideBoundary
		local height = spec.loadVolume.height
		local length = spec.loadVolume.length-rearBoundary
		local tx, ty, tz = 0, spec.loadVolume.height/2, rearBoundary/2
		doUpdateTrigger("unloadingTrigger", width, height, length, tx, ty, tz)
	end
	
	local playerTrigger = spec.triggers["playerTrigger"]
	if playerTrigger then
		local width = 5*spec.loadVolume.width
		local height = 2*spec.loadVolume.height
		local length = spec.loadVolume.length+2*spec.loadVolume.width
		local tx, ty, tz = 0, spec.loadVolume.height/2, 0
		doUpdateTrigger("playerTrigger", width, height, length, tx, ty, tz)
	end

	local leftPickupTrigger = spec.triggers["leftPickupTrigger"]
	local rightPickupTrigger = spec.triggers["rightPickupTrigger"]
	if leftPickupTrigger and rightPickupTrigger then
		local width = (spec.extendPickupRange and 3 or 1.66) * spec.loadVolume.width
		local height = 3*spec.loadVolume.height
		local length = spec.loadVolume.length+spec.loadVolume.width/2
		local tx, ty, tz = 1.1*(width+spec.loadVolume.width)/2, 0, 0
		doUpdateTrigger("leftPickupTrigger", width, height, length, tx, ty, tz)
		doUpdateTrigger("rightPickupTrigger", width, height, length, -tx, ty, tz)
	end

	if spec.rearUnloadingOnly or spec.extendPickupRange then
		local width = spec.loadVolume.length+spec.loadVolume.width
		local height = 3*spec.loadVolume.height
		local length = 0.8*width
		if spec.extendPickupRange then width = math.max(width, 7.4 * spec.loadVolume.width) end
		local tx, ty, tz = 0, 0, -0.5*(length+spec.loadVolume.length+spec.loadVolume.width/2)
		doUpdateTrigger("rearPickupTrigger", width, height, length, tx, ty, tz)
	else
		doRemoveTrigger("rearPickupTrigger")
	end
	
	if spec.frontUnloadingOnly or spec.extendPickupRange then
		local width = spec.loadVolume.length+spec.loadVolume.width
		local height = 3*spec.loadVolume.height
		local length = 0.8*width
		if spec.extendPickupRange then width = math.max(width, 7.4 * spec.loadVolume.width) end
		local tx, ty, tz = 0, 0, 0.5*(length+spec.loadVolume.length+spec.loadVolume.width/2)
		doUpdateTrigger("frontPickupTrigger", width, height, length, tx, ty, tz)
	else
		doRemoveTrigger("frontPickupTrigger")
	end

	if spec.enableRearLoading then
		local depth = 0.05
		local recess = spec.loadVolume.width/4
		local boundary = spec.loadVolume.width/4
		
		local width, height, length = spec.loadVolume.width-boundary, spec.loadVolume.height, depth
		local tx, ty, tz = 0, spec.loadVolume.height/2, recess-(spec.loadVolume.length/2)-depth
		doUpdateTrigger("rearAutoTrigger", width, height, length, tx, ty, tz)
	else
		doRemoveTrigger("rearAutoTrigger")
	end
	
	if spec.enableSideLoading then
		local depth = 0.05
		local recess = spec.loadVolume.width/7
		local boundary = 2*spec.loadVolume.width/3
		local width, height, length = depth, spec.loadVolume.height, spec.loadVolume.length-boundary
		local tx, ty, tz = 2*depth+(spec.loadVolume.width/2)-recess, spec.loadVolume.height/2, 0
			
		doUpdateTrigger("leftAutoTrigger", width, height, length, tx, ty, tz)
		doUpdateTrigger("rightAutoTrigger", width, height, length, -tx, ty, tz)
	else
		doRemoveTrigger("leftAutoTrigger")
		doRemoveTrigger("rightAutoTrigger")
	end
	
end


-- MAIN "ON LOAD" INITIALISATION FUNCTION
function UniversalAutoload:onLoad(savegame)
	
	self.spec_universalAutoload = self[UniversalAutoload.specName]
	local spec = self.spec_universalAutoload

	UniversalAutoload.debugPrint("onLoad START: " .. tostring(netGetTime()), debugVehicles)
	if UniversalAutoloadManager.getIsValidForAutoload(self) then
		if self:getFullName() == 'SugarBeet Wagon' and string.find(self.configFileName, "wagonTimber") then
			self.getName = Utils.overwrittenFunction(self.getName, function(self, superFunc) return "Timber Wagon" end)
		end
		
		if UniversalAutoloadManager.handleNewVehicleCreation(self) then
			UniversalAutoload.debugPrint(self:getFullName() .. ": UAL ACTIVATED", debugVehicles)
		elseif self.propertyState ~= VehiclePropertyState.SHOP_CONFIG then
			UniversalAutoload.debugPrint(self:getFullName() .. ": SETTINGS NOT AVAILABLE (autoload disabled)", debugVehicles)
			spec.autoloadDisabled = true
		end
		spec.isAutoloadAvailable = true
		UniversalAutoloadManager.onValidUalShopVehicle(self)
	else	
		UniversalAutoload.debugPrint(self:getFullName() .. ": NOT VALID FOR UAL")
		spec.isAutoloadAvailable = false
		UniversalAutoload.removeEventListeners(self)
		UniversalAutoloadManager.onInvalidUalShopVehicle(self)
		return
	end

	if self.isServer and self.propertyState ~= VehiclePropertyState.SHOP_CONFIG then
		UniversalAutoload.debugPrint("SERVER - INITIALISE REAL UAL VEHICLE (ON LOAD) " ..tostring(self.rootNode))
		
		UniversalAutoload.VEHICLES[self] = true
		if self.addDeleteListener then
			self:addDeleteListener(self, "ualOnDeleteVehicle_Callback")
		end
		
		--initialise server only arrays
		spec.triggers = {}
		spec.loadedObjects = {}
		spec.availableObjects = {}
		spec.autoLoadingObjects = {}

		--create transform groups for triggers
		UniversalAutoload.initialiseTransformGroups(self)
		
		--update size and position
		if spec.loadArea and #spec.loadArea > 0 then
			UniversalAutoload.debugPrint("SERVER - INITIALISE UAL VEHICLE (ON LOAD 2) " ..tostring(self.rootNode))
			UniversalAutoload.updateLoadAreaTransformGroups(self)
			UniversalAutoload.updateLoadingTriggers(self)
			spec.initialised = true
		else
			if not spec.loadAreaMissing then
				spec.loadAreaMissing = true
				print("WARNING: UAL load area missing - check settings file for " .. tostring(self:getFullName()))
				
				local configFileName = UniversalAutoloadManager.cleanConfigFileName(self.configFileName)
				UniversalAutoload.debugPrint("  g_modsDirectory: " .. tostring(g_modsDirectory))
				UniversalAutoload.debugPrint("  cleanConfigFileName: " .. tostring(configFileName))
				
				local configGroup = UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName]
				if UniversalAutoload.showDebug and debugVehicles then
					if configGroup then 
						print("  VEHICLE_CONFIGURATIONS:")
						DebugUtil.printTableRecursively(configGroup, "--", 0, 1)
					else
						print("  VEHICLE_CONFIGURATION group is NIL")
					end
				end
			end
		end
	
		--server only
		spec.isLoading = false
		spec.isUnloading = false
		spec.activeLoading = false
		spec.doPostLoadDelay = false
		spec.doSetTensionBelts = false
		spec.totalAvailableCount = 0
		spec.availableBaleCount = 0
		spec.totalUnloadCount = 0
		spec.validLoadCount = 0
		spec.validUnloadCount = 0
	end

	--client+server
	spec.actionEvents = {}
	spec.playerInTrigger = {}
	spec.currentTipside = "left"
	spec.currentLoadside = "both"
	spec.currentMaterialIndex = 1
	spec.currentContainerIndex = 1
	spec.currentLoadingFilter = false
	spec.autoCollectionMode = false
	spec.useHorizontalLoading = spec.horizontalLoading or false
	
	-- UniversalAutoload.debugPrint("SPEC")
	-- DebugUtil.printTableRecursively(spec, "--", 0, 1)

	UniversalAutoload.debugPrint("onLoad FINISH: " .. tostring(netGetTime()), debugVehicles)
end

-- "ON POST LOAD" CALLED AFTER VEHICLE IS LOADED (not when buying)
function UniversalAutoload:onPostLoad(savegame)
	if self.isServer and savegame then
		local spec = self.spec_universalAutoload
		if not spec then
			UniversalAutoload.debugPrint(self:getFullName() .. ": UAL UNDEFINED - onPostLoad", debugVehicles)
			return
		end
		
		if savegame.resetVehicles or savegame.xmlFile.filename=="" then
			--client+server
			UniversalAutoload.debugPrint("UAL: ON POST LOAD - RESET")
			spec.currentTipside = "left"
			spec.currentLoadside = "both"
			spec.currentMaterialIndex = 1
			spec.currentContainerIndex = 1
			spec.currentLoadingFilter = false
			spec.autoCollectionMode = false
			spec.useHorizontalLoading = spec.horizontalLoading or false
			--server only
			spec.currentLoadWidth = 0
			spec.currentLoadLength = 0
			spec.currentLoadHeight = 0
			spec.currentActualWidth = 0
			spec.currentActualLength = 0
			spec.currentLayerCount = 0
			spec.currentLayerHeight = 0
			spec.nextLayerHeight = 0
			spec.lastAddedLoadLength = 0
			spec.currentLoadAreaIndex = 1
			spec.resetLoadingLayer = false
			spec.resetLoadingPattern = false
		else
			--client+server
			local key = savegame.key .. UniversalAutoload.postLoadKey
			UniversalAutoload.debugPrint("UAL: ON POST LOAD")
			UniversalAutoload.debugPrint("using xml key - " .. key)
			spec.currentTipside = savegame.xmlFile:getValue(key.."#tipside", "left")
			spec.currentLoadside = savegame.xmlFile:getValue(key.."#loadside", "both")
			spec.currentMaterialIndex = savegame.xmlFile:getValue(key.."#materialIndex", 1)
			spec.currentContainerIndex = savegame.xmlFile:getValue(key.."#containerIndex", 1)
			spec.currentLoadingFilter = savegame.xmlFile:getValue(key.."#loadingFilter", false)
			spec.autoCollectionMode = savegame.xmlFile:getValue(key.."#autoCollectionMode", false)
			spec.useHorizontalLoading = savegame.xmlFile:getValue(key.."#useHorizontalLoading", spec.horizontalLoading or false)
			--server only
			spec.currentLoadWidth = savegame.xmlFile:getValue(key.."#loadWidth", 0)
			spec.currentLoadLength = savegame.xmlFile:getValue(key.."#loadLength", 0)
			spec.currentLoadHeight = savegame.xmlFile:getValue(key.."#loadHeight", 0)
			spec.currentActualWidth = savegame.xmlFile:getValue(key.."#actualWidth", 0)
			spec.currentActualLength = savegame.xmlFile:getValue(key.."#actualLength", 0)
			spec.currentLayerCount = savegame.xmlFile:getValue(key.."#layerCount", 0)
			spec.currentLayerHeight = savegame.xmlFile:getValue(key.."#layerHeight", 0)
			spec.nextLayerHeight = savegame.xmlFile:getValue(key.."#nextLayerHeight", 0)
			spec.lastAddedLoadLength = savegame.xmlFile:getValue(key.."#lastLoadLength", 0)
			spec.currentLoadAreaIndex = savegame.xmlFile:getValue(key.."#loadAreaIndex", 1)
			spec.resetLoadingLayer = false
			spec.resetLoadingPattern = false
		end
		
		UniversalAutoload.updateWidthAxis(self)
		UniversalAutoload.updateLengthAxis(self)
		UniversalAutoload.updateHeightAxis(self)
		
		UniversalAutoload.debugPrint("UAL: ON POST LOAD COMPLETE")
	end
end

function UniversalAutoload:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isClient then
		local spec = self.spec_universalAutoload

		if isActiveForInputIgnoreSelection and not isSelected then
			UniversalAutoload.onDraw(self)
		end
		
		if not UniversalAutoload.lowRefreshMode then
			local status, result = pcall(UniversalAutoload.doUpdate, self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

			if not status then
				spec.stopError = true
				spec.result = result
			end
		end
		
	end
end

function UniversalAutoload:onUpdateEnd(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isClient then
		local spec = self.spec_universalAutoload
		
	end
end

-- "SAVE TO XML FILE" CALLED DURING GAME SAVE
function UniversalAutoload:saveToXMLFile(xmlFile, key, usedModNames)

	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - saveToXMLFile", debugVehicles)
		return
	end

	-- UniversalAutoload.debugPrint("UniversalAutoload - saveToXMLFile: "..self:getFullName())
	if spec.autoCollectionMode then
		UniversalAutoload.setAutoCollectionMode(self, false)
		for object, _ in pairs(spec.loadedObjects or {}) do
			if object and object.isRoundbale ~= nil then
				UniversalAutoload.unlinkObject(object)
				UniversalAutoload.addToPhysics(self, object)
			end
		end
	end
	if spec.resetLoadingLayer ~= false then
		UniversalAutoload.resetLoadingLayer(self)
	end
	if spec.resetLoadingPattern ~= false then
		UniversalAutoload.resetLoadingPattern(self)
	end
	
	--UniversalAutoload.savegameStateKey = ".currentState"
	--UniversalAutoload.savegameConfigKey = ".configuration"

	local saveKey = key .. UniversalAutoload.savegameStateKey
	--client+server
	xmlFile:setValue(saveKey.."#tipside", spec.currentTipside or "left")
	xmlFile:setValue(saveKey.."#loadside", spec.currentLoadside or "both")
	xmlFile:setValue(saveKey.."#materialIndex", spec.currentMaterialIndex or 1)
	xmlFile:setValue(saveKey.."#containerIndex", spec.currentContainerIndex or 1)
	xmlFile:setValue(saveKey.."#loadingFilter", spec.currentLoadingFilter or false)
	xmlFile:setValue(saveKey.."#autoCollectionMode", spec.autoCollectionMode or false)
	xmlFile:setValue(saveKey.."#useHorizontalLoading", spec.useHorizontalLoading or false)
	--server only
	xmlFile:setValue(saveKey.."#loadWidth", spec.currentLoadWidth or 0)
	xmlFile:setValue(saveKey.."#loadHeight", spec.currentLoadHeight or 0)
	xmlFile:setValue(saveKey.."#loadLength", spec.currentLoadLength or 0)
	xmlFile:setValue(saveKey.."#actualWidth", spec.currentActualWidth or 0)
	xmlFile:setValue(saveKey.."#actualLength", spec.currentActualLength or 0)
	xmlFile:setValue(saveKey.."#layerCount", spec.currentLayerCount or 0)
	xmlFile:setValue(saveKey.."#layerHeight", spec.currentLayerHeight or 0)
	xmlFile:setValue(saveKey.."#nextLayerHeight", spec.nextLayerHeight or 0)
	xmlFile:setValue(saveKey.."#lastLoadLength", spec.lastAddedLoadLength or 0)
	xmlFile:setValue(saveKey.."#loadAreaIndex", spec.currentLoadAreaIndex or 1)
	
end

-- "ON DELETE" CLEANUP TRIGGER NODES
function UniversalAutoload:onPreDelete()
	-- UniversalAutoload.debugPrint("UniversalAutoload - onPreDelete")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		-- UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - onPreDelete", debugVehicles)
		return
	end
	
	if UniversalAutoload.VEHICLES[self] then
		-- UniversalAutoload.debugPrint("PRE DELETE: " .. self:getFullName() )
		UniversalAutoload.VEHICLES[self] = nil
	end
	if self.isServer then
		if spec.triggers then
			for _, trigger in pairs(spec.triggers or {}) do
				removeTrigger(trigger.node)
			end
		end
	end
end
--
function UniversalAutoload:onDelete()
	local shopVehicle = UniversalAutoloadManager.shopVehicle
	if shopVehicle and self == shopVehicle then
		UniversalAutoload.debugPrint("DELETE SHOP VEHICLE: " .. shopVehicle:getFullName())
		
		-- local vehicle = UniversalAutoloadManager.resetNewVehicle
		-- if vehicle then
			-- UniversalAutoload.debugPrint("RESET VEHICLE: " .. vehicle:getFullName())
			-- UniversalAutoload.debugPrint("shop vehicle: " .. tostring(shopVehicle))
			-- UniversalAutoload.debugPrint("reset vehicle: " .. tostring(vehicle))
			-- g_client:getServerConnection():sendEvent(ResetVehicleEvent.new(vehicle))
			-- UniversalAutoloadManager.resetNewVehicle = nil
		-- end
		
		UniversalAutoloadManager.shopVehicle = nil
	end
	
	-- UniversalAutoload.debugPrint("UniversalAutoload - onDelete")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable then
		-- UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - onDelete", debugVehicles)
		return
	end
	
	if UniversalAutoload.VEHICLES[self] then
		-- UniversalAutoload.debugPrint("DELETE: " .. self:getFullName() )
		UniversalAutoload.VEHICLES[self] = nil
	end
	if self.isServer then
		if spec.triggers then
			for _, trigger in pairs(spec.triggers or {}) do
				removeTrigger(trigger.node)
			end
		end
	end
end

function UniversalAutoload:onPostAttach(attacherVehicle, inputJointDescIndex, jointDescIndex, loadFromSavegame)
	-- UniversalAutoload.debugPrint("UniversalAutoload - onPostAttach")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - onPostAttach", debugVehicles)
		return
	end
	
	if self.isServer then
		-- UniversalAutoload.debugPrint("onPostAttach: "..self:getFullName())
		spec.attachAnimationStarted = true
		UniversalAutoload.updateActionEventText(self)
	end
end

-- SET FOLDING STATE FLAG ON FOLDING STATE CHANGE
function UniversalAutoload:onFoldStateChanged(direction, moveToMiddle)
	-- UniversalAutoload.debugPrint("UniversalAutoload - onFoldStateChanged")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - onFoldStateChanged", debugVehicles)
		return
	end
	
	if self.isServer then
		-- UniversalAutoload.debugPrint("onFoldStateChanged: "..self:getFullName())
		spec.foldAnimationStarted = true
		UniversalAutoload.updateActionEventText(self)
	end
end
--
function UniversalAutoload:onMovingToolChanged(tool, transSpeed, dt)
	-- UniversalAutoload.debugPrint("UniversalAutoload - onMovingToolChanged")
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - onMovingToolChanged", debugVehicles)
		return
	end
	
	if self.isServer and tool.axis and spec.loadVolume then
		-- UniversalAutoload.debugPrint("onMovingToolChanged: "..self:getFullName().." - "..tool.axis)
		UniversalAutoload.updateWidthAxis(self)
		UniversalAutoload.updateLengthAxis(self)
		UniversalAutoload.updateHeightAxis(self)
	end
end
--
function UniversalAutoload:updateWidthAxis()
	local spec = self.spec_universalAutoload
	if not spec.loadVolume then
		return
	end
	
	for i, loadArea in pairs(spec.loadArea or {}) do
		if loadArea.widthAxis and self.spec_cylindered then

			for i, tool in pairs(self.spec_cylindered.movingTools or {}) do
				if tool.axis and loadArea.widthAxis == tool.axis then
			
					local x, y, z = getTranslation(tool.node)
					-- UniversalAutoload.debugPrint(self:getFullName() .." - UPDATE WIDTH AXIS: x="..x..",  y="..y..",  z="..z)
					if loadArea.originalWidth == nil then
						loadArea.originalWidth = loadArea.width
						spec.loadVolume.originalWidth = spec.loadVolume.width
					end
					local direction = loadArea.reverseWidthAxis and -1 or 1
					local extensionWidth = math.abs(x) * direction
					loadArea.width = loadArea.originalWidth + extensionWidth
					spec.loadVolume.width = spec.loadVolume.originalWidth + extensionWidth
				end
			end
		end
	end
end
--
function UniversalAutoload:updateHeightAxis()
	local spec = self.spec_universalAutoload
	if not spec.loadVolume then
		return
	end

	for i, loadArea in pairs(spec.loadArea or {}) do
		if loadArea.heightAxis and self.spec_cylindered then

			for i, tool in pairs(self.spec_cylindered.movingTools or {}) do
				if tool.axis and loadArea.heightAxis == tool.axis then
			
					local x, y, z = getTranslation(tool.node)
					-- UniversalAutoload.debugPrint(self:getFullName() .." - UPDATE HEIGHT AXIS: x="..x..",  y="..y..",  z="..z)
					if loadArea.originalHeight == nil then
						loadArea.originalHeight = loadArea.height
						spec.loadVolume.originalHeight = spec.loadVolume.height
					end
					local direction = loadArea.reverseHeightAxis and -1 or 1
					local extensionHeight = math.abs(y) * direction
					loadArea.height = loadArea.originalHeight + extensionHeight
					spec.loadVolume.height = spec.loadVolume.originalHeight + extensionHeight
					
				end
			end
		end
	end
end
--
function UniversalAutoload:updateLengthAxis()
	local spec = self.spec_universalAutoload
	if not spec.loadVolume then
		return
	end
	
	for i, loadArea in pairs(spec.loadArea or {}) do
		if self.spec_cylindered and (loadArea.lengthAxis or loadArea.offsetFrontAxis or loadArea.offsetRearAxis) then

			for i, tool in pairs(self.spec_cylindered.movingTools or {}) do
				if tool.axis and ((loadArea.lengthAxis == tool.axis) or
					(loadArea.offsetFrontAxis == tool.axis) or (loadArea.offsetRearAxis == tool.axis)) then
					
					local x, y, z = getTranslation(tool.node)
					-- UniversalAutoload.debugPrint(self:getFullName() .." - UPDATE LENGTH AXIS: x="..x..",  y="..y..",  z="..z)
					
					if loadArea.originalLength == nil then
						loadArea.originalLength = loadArea.length
						local X = loadArea.offset[1]
						local Y = loadArea.offset[2]
						local Z = loadArea.offset[3]
						loadArea.X = X
						loadArea.Y = Y
						loadArea.Z = Z
						
						spec.loadVolume.originalLength = spec.loadVolume.length
						local X0, Y0, Z0 = getTranslation(spec.loadVolume.rootNode)
						spec.loadVolume.X = X0
						spec.loadVolume.Y = Y0
						spec.loadVolume.Z = Z0
					end
					
					local offsetEnd = 0
					local offsetRoot = 0
					local offsetStart = 0
					local extensionLength = 0
					
					loadArea.length = loadArea.originalLength
					spec.loadVolume.length = spec.loadVolume.originalLength
					
					local function mapValue(value, inMin, inMax, outMin, outMax)
						return (value - inMin) / (inMax - inMin) * (outMax - outMin) + outMin
					end

					if loadArea.lengthAxis == tool.axis then
						-- UniversalAutoload.debugPrint(self:getFullName() .." EXTEND LENGTH AXIS")
						local direction = loadArea.reverseLengthAxis and -1 or 1
						extensionLength = math.abs(z) * direction
						loadArea.length = loadArea.length + extensionLength
						spec.loadVolume.length = spec.loadVolume.length + extensionLength
						offsetEnd = offsetEnd - extensionLength
						offsetRoot = offsetRoot - (extensionLength/2)
					end

					if loadArea.offsetFrontAxis == tool.axis then
						-- UniversalAutoload.debugPrint(self:getFullName() .." OFFSET FRONT AXIS")
						if tool.rotMin and tool.rotMax then
							local rot = tool.curRot[tool.rotationAxis]
							local range = math.abs(tool.rotMax - tool.rotMin)
							extensionLength = mapValue(rot, tool.rotMin, tool.rotMax, 0, range)
						else
							extensionLength = math.abs(z)
						end
						loadArea.length = loadArea.length - extensionLength
						spec.loadVolume.length = spec.loadVolume.length - extensionLength
						offsetRoot = offsetRoot - (extensionLength/2)
						offsetStart = offsetStart - extensionLength
					end
					
					if loadArea.offsetRearAxis == tool.axis then
						-- UniversalAutoload.debugPrint(self:getFullName() .." OFFSET REAR AXIS")
						if tool.rotMin and tool.rotMax then
							local rot = tool.curRot[tool.rotationAxis]
							local range = math.abs(tool.rotMax - tool.rotMin)
							extensionLength = mapValue(rot, tool.rotMin, tool.rotMax, 0, range)
						else
							extensionLength = math.abs(z)
						end
						loadArea.length = loadArea.length - extensionLength
						spec.loadVolume.length = spec.loadVolume.length - extensionLength
						offsetRoot = offsetRoot + (extensionLength/2)
						offsetEnd = offsetEnd + extensionLength
					end
					
					setTranslation(loadArea.endNode, loadArea.X, loadArea.Y, loadArea.Z-(loadArea.originalLength/2) + offsetEnd)
					setTranslation(loadArea.rootNode, loadArea.X, loadArea.Y, loadArea.Z + offsetRoot)
					setTranslation(loadArea.startNode, loadArea.X, loadArea.Y, loadArea.Z+(loadArea.originalLength/2) + offsetStart)
					setTranslation(spec.loadVolume.rootNode, spec.loadVolume.X, spec.loadVolume.Y, spec.loadVolume.Z + offsetRoot)
					
					if spec.rearTriggerId then
						local depth = 0.05
						local recess = spec.loadVolume.width/4
						setTranslation(spec.rearTriggerId, 0, spec.loadVolume.height/2, recess-(spec.loadVolume.length/2)-depth)
					end
				end

			end
		end
	end
end
--
function UniversalAutoload:ualGetIsFolding()

	local isFolding = false
	if self.spec_foldable then
		for _, foldingPart in pairs(self.spec_foldable.foldingParts or {}) do
			if self:getIsAnimationPlaying(foldingPart.animationName) then
				isFolding = true
			end
		end
	end

	return isFolding
end
--
function UniversalAutoload:ualGetIsAttaching()

	local isAttaching = false
	if self.spec_attachable and not isAttaching then
		for _, animation in pairs(self.spec_attachable.supportAnimations or {}) do
			if self:getIsAnimationPlaying(animation.animationName) then
				isAttaching = true
			end
		end
	end
	return isAttaching
end
--
function UniversalAutoload:ualGetIsCovered()

	if self.spec_cover and self.spec_cover.hasCovers then
		return self.spec_cover.state == 0
	else
		return false
	end
end
--
function UniversalAutoload:ualGetIsFilled()

	local isFilled = false
	if self.spec_fillVolume then
		for _, fillVolume in ipairs(self.spec_fillVolume.volumes or {}) do
			local capacity = self:getFillUnitFillLevel(fillVolume.fillUnitIndex)
			local fillLevel = self:getFillUnitFillLevel(fillVolume.fillUnitIndex)
			if fillLevel > 0 then
				isFilled = true
			end
		end
	end
	return isFilled
end
-- --
function UniversalAutoload:ualGetPalletCanDischargeToTrailer(object)
	local isSupported = false
	if object.spec_dischargeable and object.spec_dischargeable.currentDischargeNode then
		local currentDischargeNode = object.spec_dischargeable.currentDischargeNode
		local fillType = object:getDischargeFillType(currentDischargeNode)
		
		if self.spec_fillVolume then
			for _, fillVolume in ipairs(self.spec_fillVolume.volumes or {}) do
				if self:getFillUnitAllowsFillType(fillVolume.fillUnitIndex, fillType) then
					isSupported = true
				end
			end		
		end
		--UniversalAutoload.debugPrint("fillType: "..tostring(fillType)..": "..g_fillTypeManager:getFillTypeNameByIndex(fillType).." - "..tostring(isSupported))
	end
	return isSupported
end
--
function UniversalAutoload:ualGetIsMoving()
	return self.lastSpeedReal > 0.0005
end


-- NETWORKING FUNCTIONS
function UniversalAutoload:onReadStream(streamId, connection)
	local spec = self.spec_universalAutoload
	
	if streamReadBool(streamId) then
		UniversalAutoload.debugPrint("Universal Autoload Enabled: " .. self:getFullName())
		spec.isAutoloadAvailable = true
		spec.currentTipside = streamReadString(streamId)
		spec.currentLoadside = streamReadString(streamId)
		spec.currentMaterialIndex = streamReadInt32(streamId)
		spec.currentContainerIndex = streamReadInt32(streamId)
		spec.currentLoadingFilter = streamReadBool(streamId)
		spec.useHorizontalLoading = streamReadBool(streamId)
		spec.autoCollectionMode = streamReadBool(streamId)
		spec.isLoading = streamReadBool(streamId)
		spec.isUnloading = streamReadBool(streamId)
		spec.activeLoading = streamReadBool(streamId)
		spec.validLoadCount = streamReadInt32(streamId)
		spec.validUnloadCount = streamReadInt32(streamId)
		spec.isBoxTrailer = streamReadBool(streamId)
		spec.isLogTrailer = streamReadBool(streamId)
		spec.isBaleTrailer = streamReadBool(streamId)
		spec.isCurtainTrailer = streamReadBool(streamId)
		spec.rearUnloadingOnly = streamReadBool(streamId)
		spec.frontUnloadingOnly = streamReadBool(streamId)
		spec.autoloadDisabled = streamReadBool(streamId)
		
		UniversalAutoload.debugPrint("currentTipside: " .. tostring(spec.currentTipside))
		UniversalAutoload.debugPrint("currentLoadside: " .. tostring(spec.currentLoadside))
		UniversalAutoload.debugPrint("currentMaterialIndex: " .. tostring(spec.currentMaterialIndex))
		UniversalAutoload.debugPrint("currentContainerIndex: " .. tostring(spec.currentContainerIndex))
		UniversalAutoload.debugPrint("currentLoadingFilter: " .. tostring(spec.currentLoadingFilter))
		UniversalAutoload.debugPrint("useHorizontalLoading: " .. tostring(spec.useHorizontalLoading))
		UniversalAutoload.debugPrint("autoCollectionMode: " .. tostring(spec.autoCollectionMode))
		UniversalAutoload.debugPrint("isLoading: " .. tostring(spec.isLoading))
		UniversalAutoload.debugPrint("isUnloading: " .. tostring(spec.isUnloading))
		UniversalAutoload.debugPrint("activeLoading: " .. tostring(spec.activeLoading))
		UniversalAutoload.debugPrint("validLoadCount: " .. tostring(spec.validLoadCount))
		UniversalAutoload.debugPrint("validUnloadCount: " .. tostring(spec.validUnloadCount))
		UniversalAutoload.debugPrint("isBoxTrailer: " .. tostring(spec.isBoxTrailer))
		UniversalAutoload.debugPrint("isLogTrailer: " .. tostring(spec.isLogTrailer))
		UniversalAutoload.debugPrint("isBaleTrailer: " .. tostring(spec.isBaleTrailer))
		UniversalAutoload.debugPrint("isCurtainTrailer: " .. tostring(spec.isCurtainTrailer))
		UniversalAutoload.debugPrint("rearUnloadingOnly: " .. tostring(spec.rearUnloadingOnly))
		UniversalAutoload.debugPrint("frontUnloadingOnly: " .. tostring(spec.frontUnloadingOnly))
		UniversalAutoload.debugPrint("autoloadDisabled: " .. tostring(spec.autoloadDisabled))
		
		if self.propertyState ~= VehiclePropertyState.SHOP_CONFIG then
			UniversalAutoload.VEHICLES[self] = true
		end
	else
		UniversalAutoload.debugPrint("Universal Autoload Disabled: " .. self:getFullName())
		spec.isAutoloadAvailable = false
		UniversalAutoload.removeEventListeners(self)
	end
end
--
function UniversalAutoload:onWriteStream(streamId, connection)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable then
		streamWriteBool(streamId, true)
		spec.currentTipside = spec.currentTipside or "left"
		spec.currentLoadside = spec.currentLoadside or "both"
		spec.currentMaterialIndex = spec.currentMaterialIndex or 1
		spec.currentContainerIndex = spec.currentContainerIndex or 1
		spec.currentLoadingFilter = spec.currentLoadingFilter or false
		spec.useHorizontalLoading = spec.useHorizontalLoading or false
		spec.autoCollectionMode = spec.autoCollectionMode or false
		spec.isLoading = spec.isLoading or false
		spec.isUnloading = spec.isUnloading or false
		spec.activeLoading = spec.activeLoading or false
		spec.validLoadCount = spec.validLoadCount or 0
		spec.validUnloadCount = spec.validUnloadCount or 0
		spec.isBoxTrailer = spec.isBoxTrailer or false
		spec.isLogTrailer = spec.isLogTrailer or false
		spec.isBaleTrailer = spec.isBaleTrailer or false
		spec.isCurtainTrailer = spec.isCurtainTrailer or false
		spec.rearUnloadingOnly = spec.rearUnloadingOnly or false
		spec.frontUnloadingOnly = spec.frontUnloadingOnly or false
		spec.autoloadDisabled = spec.autoloadDisabled or false
		
		streamWriteString(streamId, spec.currentTipside)
		streamWriteString(streamId, spec.currentLoadside)
		streamWriteInt32(streamId, spec.currentMaterialIndex)
		streamWriteInt32(streamId, spec.currentContainerIndex)
		streamWriteBool(streamId, spec.currentLoadingFilter)
		streamWriteBool(streamId, spec.useHorizontalLoading)
		streamWriteBool(streamId, spec.autoCollectionMode)
		streamWriteBool(streamId, spec.isLoading)
		streamWriteBool(streamId, spec.isUnloading)
		streamWriteBool(streamId, spec.activeLoading)
		streamWriteInt32(streamId, spec.validLoadCount)
		streamWriteInt32(streamId, spec.validUnloadCount)
		streamWriteBool(streamId, spec.isBoxTrailer)
		streamWriteBool(streamId, spec.isLogTrailer)
		streamWriteBool(streamId, spec.isBaleTrailer)
		streamWriteBool(streamId, spec.isCurtainTrailer)
		streamWriteBool(streamId, spec.rearUnloadingOnly)
		streamWriteBool(streamId, spec.frontUnloadingOnly)
		streamWriteBool(streamId, spec.autoloadDisabled)
	else
		streamWriteBool(streamId, false)
	end
end

function UniversalAutoload:onDraw()
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		return
	end

	if spec.debugError then
		if not spec.printedDebugError then
			spec.printedDebugError = true
			print("UAL - DEBUG ERROR: " .. self:getFullName())
			print(spec.debugResult)
		end
		return
	end
	
	if self.isClient and not g_gui:getIsGuiVisible() then
		if not spec.isInsideShop then
			local status, result = pcall(UniversalAutoload.drawDebugDisplay, self)
			if not status then
				spec.debugError = true
				spec.debugResult = result
			end
		end
	end
end

-- MAIN AUTOLOAD ONUPDATE LOOP
function UniversalAutoload:doUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	-- UniversalAutoload.debugPrint("UniversalAutoload - onUpdate")
	local spec = self.spec_universalAutoload

	if spec.isInsideShop then
		local shopVehicle = UniversalAutoloadManager.shopVehicle
		
		if shopVehicle and self == shopVehicle then
			-- IS THE CURRENT SHOP VEHICLE
			
			if spec.resetToDefault then
				UniversalAutoload.debugPrint("RESET TO DEFAULT")
				spec.resetToDefault = nil
				spec.loadingVolume = nil
				spec.wasResetToDefault = true
			end
			
			if not spec.loadingVolume or spec.loadingVolume.state < LoadingVolume.STATE.SHOP_CONFIG then
				if spec.loadArea and not spec.wasResetToDefault then
					-- UniversalAutoload.debugPrint("resetLoadingVolumeForShopEdit")
					UniversalAutoloadManager.resetLoadingVolumeForShopEdit(self)
				else
					-- UniversalAutoload.debugPrint("createLoadingVolumeInsideShop")
					UniversalAutoloadManager.createLoadingVolumeInsideShop(self)
					if spec.wasResetToDefault then
						local configFileName = spec.configFileName
						local selectedConfigs = spec.selectedConfigs
						if configFileName and selectedConfigs and UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] then
							UniversalAutoload.debugPrint("*** RESET TO DEFAULT CONFIG ***")
							UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName][selectedConfigs] = nil
							spec.loadArea = nil
							spec.wasResetToDefault = nil
						end
					end
				end
			end

			if spec.isAutoloadAvailable and spec.loadingVolume and not spec.autoloadDisabled then
				spec.loadingVolume:draw(true)
				if spec.loadingVolume.state == LoadingVolume.STATE.ERROR then
					print("*** ERROR DETECTING LOADING AREA - ABORTING ***")
					spec.isAutoloadAvailable = false
					return
				end
				if spec.loadingVolume.state == LoadingVolume.STATE.SHOP_CONFIG then
					UniversalAutoloadManager.editLoadingVolumeInsideShop(self)
				end
			end
		end
		return
	end
	
	if self.isServer and not spec.initialised then
		
		if not spec.loadArea or #spec.loadArea == 0 then
			-- print this on the server for debugging (SP or player host)
			if not spec.printedLoadAreaMissingWarning then
				print(tostring(self.rootNode) .. " *** LOAD AREAS MISSING *** " .. self:getFullName())
				spec.printedLoadAreaMissingWarning = true
			end
		end
		
		if spec.isAutoloadAvailable == false then
			UniversalAutoload.debugPrint("Autoload NOT available - REMOVE Event Listeners " ..tostring(self.rootNode))
			UniversalAutoload.removeEventListeners(self)
			spec.initialised = false
		else
			if spec.loadArea and #spec.loadArea > 0 then
				UniversalAutoload.debugPrint("INITIALISE UAL VEHICLE (ON UPDATE) " ..tostring(self.rootNode))
				UniversalAutoload.updateLoadAreaTransformGroups(self)
				UniversalAutoload.updateLoadingTriggers(self)
				spec.initialised = true
				if UniversalAutoload.showDebug then
					DebugUtil.printTableRecursively(spec, "--", 0, 2)
				end
			end
		end
		return
	end

	spec.countedPallets = false
	
	if self.isClient and not g_gui:getIsGuiVisible() and isActiveForInputIgnoreSelection then
		spec.menuDelayTime = spec.menuDelayTime or 0
		if spec.menuDelayTime > UniversalAutoload.loadingSpeed/2 then
			spec.menuDelayTime = 0

			if spec.updateToggleLoading then
				if debugKeys or debugVehicles then
					if not spec.counter then spec.counter = 0 end
					spec.counter = spec.counter + 1
					UniversalAutoload.debugPrint( self:getFullName() .. " - RefreshActionEvents " .. tostring(spec.counter))
				end

				UniversalAutoload.debugPrint("*** clearActionEvents ***", debugKeys)
				UniversalAutoload.clearActionEvents(self)
				UniversalAutoload.updateActionEventKeys(self)
				
				UniversalAutoload.debugPrint("  UPDATE Toggle Loading", debugKeys)
				spec.updateToggleLoading = false
				UniversalAutoload.updateToggleLoadingActionEvent(self)
			end
			if spec.updateCycleMaterial then
				UniversalAutoload.debugPrint("  UPDATE Cycle Material", debugKeys)
				spec.updateCycleMaterial = false
				UniversalAutoload.updateCycleMaterialActionEvent(self)
			end
			if spec.updateCycleContainer then
				UniversalAutoload.debugPrint("  UPDATE Cycle Container", debugKeys)
				spec.updateCycleContainer = false
				UniversalAutoload.updateCycleContainerActionEvent(self)
			end
			if spec.updateToggleDoor then
				UniversalAutoload.debugPrint("  UPDATE Toggle Door", debugKeys)
				spec.updateToggleDoor=false
				UniversalAutoload.updateToggleDoorActionEvent(self)
			end
			if spec.updateToggleCurtain then
				UniversalAutoload.debugPrint("  UPDATE Toggle Curtain", debugKeys)
				spec.updateToggleCurtain=false
				UniversalAutoload.updateToggleCurtainActionEvent(self)
			end
			if spec.updateToggleTipside then
				UniversalAutoload.debugPrint("  UPDATE Toggle Tipside", debugKeys)
				spec.updateToggleTipside=false
				UniversalAutoload.updateToggleTipsideActionEvent(self)
			end
			if spec.updateToggleBelts then
				UniversalAutoload.debugPrint("  UPDATE Toggle Belts", debugKeys)
				spec.updateToggleBelts=false
				UniversalAutoload.updateToggleBeltsActionEvent(self)
			end
			if spec.updateToggleFilter then
				UniversalAutoload.debugPrint("  UPDATE Toggle Filter", debugKeys)
				spec.updateToggleFilter=false
				UniversalAutoload.updateToggleFilterActionEvent(self)
			end
			if spec.updateHorizontalLoading then
				UniversalAutoload.debugPrint("  UPDATE Horizontal Loading", debugKeys)
				spec.updateHorizontalLoading=false
				UniversalAutoload.updateHorizontalLoadingActionEvent(self)
			end
		else
			spec.menuDelayTime = spec.menuDelayTime + dt
		end
	end
	
	if self.isServer then
		
		-- CALCULATE AND APPLY VELOCITY CORRECTION
		UniversalAutoload.updateVelocityCorrection(self)
		
		-- DETECT WHEN ATTACHING STOPS IF IT WAS STARTED
		if spec.attachAnimationStarted then
			if not self:ualGetIsAttaching() then
				-- UniversalAutoload.debugPrint("*** ATTACHING COMPLETE ***")
				spec.attachAnimationStarted = false
				UniversalAutoload.updateActionEventText(self)
			end
		end

		-- DETECT WHEN FOLDING STOPS IF IT WAS STARTED
		if spec.foldAnimationStarted then
			if not self:ualGetIsFolding() then
				-- UniversalAutoload.debugPrint("*** FOLDING COMPLETE ***")
				spec.foldAnimationStarted = false
				UniversalAutoload.updateActionEventText(self)
			end
		end
		
		-- DETECT WHEN COVER STATE CHANGES
		if self.spec_cover and self.spec_cover.hasCovers then
			if spec.lastCoverState ~= self.spec_cover.state then
				-- UniversalAutoload.debugPrint("*** COVERS CHANGED STATE ***")
				spec.lastCoverState = self.spec_cover.state
				UniversalAutoload.updateActionEventText(self)
			end
		end
		
		-- DETECT WHEN STRAPS STATE CHANGES
		if self.spec_tensionBelts then
			if spec.lastStrapState ~= self.spec_tensionBelts.areAllBeltsFastened then
				-- UniversalAutoload.debugPrint("*** STRAPS CHANGED STATE ***")
				spec.lastStrapState = self.spec_tensionBelts.areAllBeltsFastened
				spec.lastStrapStateChanged = true
			end
		end

		-- ALWAYS LOAD THE AUTO LOADING PALLETS
		if spec.autoLoadingObjects then
			for object, _ in pairs(spec.autoLoadingObjects) do
				-- UniversalAutoload.debugPrint("LOADING PALLET FROM AUTO TRIGGER")
				if not UniversalAutoload.getPalletIsSelectedMaterial(self, object) then
					UniversalAutoload.setMaterialTypeIndex(self, 1)
				end
				if not UniversalAutoload.getPalletIsSelectedContainer(self, object) then
					UniversalAutoload.setContainerTypeIndex(self, 1)
				end
				self:setAllTensionBeltsActive(false)
				-- *** Don't set belts as they can grab the pallet forks ***
				-- spec.doSetTensionBelts = true -- spec.doPostLoadDelay = true
				if not UniversalAutoload.loadObject(self, object) then
					--UNABLE_TO_LOAD_OBJECT
					if spec.trailerIsFull then
						UniversalAutoload.showWarningMessage(self, "UNABLE_TO_LOAD_FULL")
					else
						UniversalAutoload.showWarningMessage(self, "UNABLE_TO_LOAD_EMPTY")
					end
					UniversalAutoload.updateActionEventText(self)
				end
				spec.autoLoadingObjects[object] = nil
			end
		end
		
		-- CREATE AND LOAD BALES (IF REQUESTED)
		if spec.spawnBales then
			spec.spawnBalesDelayTime = spec.spawnBalesDelayTime or 0
			if spec.spawnBalesDelayTime > UniversalAutoload.loadingSpeed then
				spec.spawnBalesDelayTime = 0
				
				local failedToLoad = false
				local failedToCreate = false
				if spec.spawnedBale then
					-- UniversalAutoload.debugPrint("LOAD SPAWNED BALE")
					local baleObject = spec.spawnedBale
					if entityExists(baleObject.nodeId) and not UniversalAutoload.loadObject(self, baleObject) then
						baleObject:delete()
						failedToLoad = true
					end
					spec.spawnedBale = nil
				else
					spec.spawnedBale = UniversalAutoload.createBale(self, bale.xmlFile, bale.fillTypeIndex, bale.wrapState)
					failedToCreate = spec.spawnedBale == nil
				end

				if failedToCreate or failedToLoad then
					spec.spawnBales = false
					spec.doPostLoadDelay = true
					spec.doSetTensionBelts = true
					print("..adding bales complete!")
				end
			else
				spec.loadSpeedFactor = spec.loadSpeedFactor or 1
				spec.spawnBalesDelayTime = spec.spawnBalesDelayTime + (spec.loadSpeedFactor*dt)
			end
		end
		
		-- CREATE AND LOAD LOGS (IF REQUESTED)
		if spec.spawnLogs then
			spec.spawnLogsDelayTime = spec.spawnLogsDelayTime or 0
			if spec.spawnLogsDelayTime > UniversalAutoload.loadingSpeed then

				if spec.spawnedLogId == nil then
					if not UniversalAutoload.spawningLog then
						log = spec.logToSpawn
						spec.spawnedLogId = UniversalAutoload.createLog(self, log.length, log.treeType, log.growthState)
						UniversalAutoload.createdLogId = nil
						UniversalAutoload.createdTreeId = spec.spawnedLogId
						if spec.spawnedLogId == nil then
							spec.spawnLogsDelayTime = 0
						end
					end
				else
					if UniversalAutoload.createdLogId and #g_treePlantManager.loadTreeTrunkDatas == 0 then

						local logId = UniversalAutoload.createdLogId
						if entityExists(logId) then
							local logObject = UniversalAutoload.getSplitShapeObject(logId)
							if logObject then
								if not UniversalAutoload.loadObject(self, logObject) then
									delete(logId)
									spec.currentLoadingPlace = nil
									spec.spawnLogs = false
									spec.doPostLoadDelay = true
									spec.doSetTensionBelts = true
									print("..adding logs complete!")
								end
								spec.spawnLogsDelayTime = 0
								spec.spawnedLogId = nil
								UniversalAutoload.spawningLog = false
							end
						end

						if spec.spawnedLogId then
							spec.spawnLogs = false
							spec.spawnedLogId = nil
							UniversalAutoload.spawningLog = false
							UniversalAutoload.createdLogId = nil
							UniversalAutoload.createdTreeId = nil
							print("..error spawning log - aborting!")
						end
					end
				end

			else
				spec.loadSpeedFactor = spec.loadSpeedFactor or 1
				spec.spawnLogsDelayTime = spec.spawnLogsDelayTime + (spec.loadSpeedFactor*dt)
			end
		end
		
		-- CREATE AND LOAD PALLETS (IF REQUESTED)
		if spec.spawnPallets and not spec.spawningPallet then
			spec.spawnPalletsDelayTime = spec.spawnPalletsDelayTime or 0
			if spec.spawnPalletsDelayTime > UniversalAutoload.loadingSpeed then
				spec.spawnPalletsDelayTime = 0
				
				if spec.spawnedPallet then
					-- UniversalAutoload.debugPrint("LOAD SPAWNED PALLET")
					local pallet = spec.spawnedPallet

					if UniversalAutoload.loadObject(self, pallet) then
						spec.spawnPalletsDelayTime = 0
					else
						spec.spawnPalletsDelayTime = UniversalAutoload.loadingSpeed
						pallet:delete()
						
						if spec.palletsToSpawn and #spec.palletsToSpawn>1 then
							for i, name in pairs(spec.palletsToSpawn) do
								if spec.spawningPallet == name then
									UniversalAutoload.debugPrint("removing: " .. tostring(spec.spawningPallet), debugConsole)
									table.remove(spec.palletsToSpawn, i)
									spec.trailerIsFull = false
									break
								end
							end
						end
						if spec.palletsToSpawn and #spec.palletsToSpawn==1 then
							spec.palletsToSpawn = nil
						end
					end
					
					spec.spawnedPallet = nil
					spec.spawningPallet = nil
					
					if spec.trailerIsFull == true or not spec.palletsToSpawn then
						spec.spawnPallets = false
						spec.doPostLoadDelay = true
						spec.doSetTensionBelts = true
						spec.lastSpawnedPallet = nil
						spec.palletsToSpawn = {}
						print(self:getFullName() .. " ..adding pallets complete!")
					end
				end
				
				if not spec.spawnedPallet and spec.palletsToSpawn and #spec.palletsToSpawn > 0 then
					-- UniversalAutoload.debugPrint("CREATE A NEW PALLET")
					local i = math.random(1, #spec.palletsToSpawn)
					pallet = spec.palletsToSpawn[i]
					if spec.lastSpawnedPallet then
						if math.random(1, 100) > 70 then
							pallet = spec.lastSpawnedPallet
						end
					end
					UniversalAutoload.createPallet(self, pallet)
					spec.lastSpawnedPallet = pallet
				end
			else
				spec.loadSpeedFactor = spec.loadSpeedFactor or 1
				spec.spawnPalletsDelayTime = spec.spawnPalletsDelayTime + (spec.loadSpeedFactor*dt)
			end
		end
		
		-- CYCLE THROUGH A FULL TESTING PATTERN
		if UniversalAutoloadManager.runFullTest == true then

			local rootVehicle = self:getRootVehicle(self)
			local currentVehicle = g_localPlayer and g_localPlayer:getCurrentVehicle()
			if currentVehicle and rootVehicle and currentVehicle == rootVehicle then
		
				spec.testStage = spec.testStage or 1
				spec.testDelayTime = spec.testDelayTime or 0
				if spec.spawnPallets~=true and spec.spawnLogs~=true and spec.spawnBales~=true then

					if spec.testDelayTime > 1250 or spec.testStage == 1 then
						spec.testDelayTime = 0
						
						print("TEST STAGE: " .. tostring(spec.testStage) )
						if spec.testStage == 1 then
							UniversalAutoloadManager.originalMode = spec.useHorizontalLoading
							spec.useHorizontalLoading = false
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddPallets("EGG")
						elseif spec.testStage == 2 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddPallets("WOOL")
						elseif spec.testStage == 3 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddPallets("LIQUIDFERTILIZER")
						elseif spec.testStage == 4 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddPallets("LIME")
						elseif spec.testStage == 5 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddPallets()
						elseif spec.testStage == 6 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddPallets()
						elseif spec.testStage == 7 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddRoundBales_125()
						elseif spec.testStage == 8 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddRoundBales_150()
						elseif spec.testStage == 9 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddRoundBales_180()
						elseif spec.testStage == 10 then
							spec.useHorizontalLoading = true
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddRoundBales_125()
						elseif spec.testStage == 11 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddRoundBales_150()
						elseif spec.testStage == 12 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddRoundBales_180()
						elseif spec.testStage == 13 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddSquareBales_180()
						elseif spec.testStage == 14 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddSquareBales_220()
						elseif spec.testStage == 15 then
							spec.testStage = spec.testStage + 1
							UniversalAutoloadManager:consoleAddSquareBales_240()
						elseif spec.testStage == 16 then
							spec.testStage = nil
							UniversalAutoloadManager.runFullTest = false
							UniversalAutoloadManager:consoleClearLoadedObjects()
							spec.useHorizontalLoading = UniversalAutoloadManager.originalMode
							print("FULL TEST COMPLETE!" )
						end
					else
						spec.testDelayTime = spec.testDelayTime + dt
					end
					
				end
			end
		end

		-- CHECK IF ANY PLAYERS ARE ACTIVE ON FOOT
		local playerTriggerActive = false
		for _, playerInTrigger in pairs (spec.playerInTrigger) do
			if playerInTrigger then
				playerTriggerActive = true
				break
			end
		end
		
		-- CHECK IF VEHICLE HAS ACTIVE LOADING REQUIREMENTS
		local isActiveForLoading = spec.isLoading or spec.isUnloading or spec.doPostLoadDelay
		local isAutoloadingActive = spec.baleCollectionModeDeactivated or spec.autoCollectionMode or spec.aiLoadingActive
		
		-- SHOULD UPDATE VEHICLE LOADING (ON SERVER)
		if isActiveForInputIgnoreSelection or isActiveForLoading or isAutoloadingActive or playerTriggerActive then
			
			--if debugVehicles and playerTriggerActive then
			--	UniversalAutoload.testLocation(self)
			--end
			
			if debugLoading and UniversalAutoload.showDebug then
				local line = 0
				renderText(0.55, 0.92-(line*0.015), 0.010, "loadedObjects")
				for object, _ in pairs(spec.loadedObjects or {}) do
					line = line + 1
					renderText(0.45, 0.92-(line*0.015), 0.010, tostring(object.id or object.nodeId))
				end
				
				line = line + 1
				renderText(0.55, 0.92-(line*0.015), 0.010, "availableObjects")
				for object, _ in pairs(spec.availableObjects or {}) do
					line = line + 1
					renderText(0.45, 0.92-(line*0.015), 0.010, tostring(object.id or object.nodeId))
				end	
				
				line = line + 1
				renderText(0.55, 0.92-(line*0.015), 0.010, "sortedObjectsToLoad")
				for i, object in ipairs(spec.sortedObjectsToLoad or {}) do
					line = line + 1
					renderText(0.45, 0.92-(line*0.015), 0.010, tostring(object.id or object.nodeId))
				end
			end
		
			if spec.autoCollectionMode and not isActiveForLoading or spec.aiLoadingActive then
				if spec.totalAvailableCount > 0 and not spec.trailerIsFull then
					UniversalAutoload.startLoading(self)
				end
			end
			
			-- RETURN BALES TO PHYSICS WHEN NOT MOVING
			if spec.baleCollectionModeDeactivated and not self:ualGetIsMoving() then
				-- UniversalAutoload.debugPrint("ADDING BALES BACK TO PHYSICS")
				spec.baleCollectionModeDeactivated = false
				for object, _ in pairs(spec.loadedObjects) do
					if object and object.isRoundbale ~= nil then
						UniversalAutoload.unlinkObject(object)
						UniversalAutoload.addToPhysics(self, object)
					end
				end
				if UniversalAutoload.isUsingAutoStrap(self) then
					self:setAllTensionBeltsActive(false)
					if spec.totalUnloadCount > 0 then
						spec.doSetTensionBelts = true
						spec.doPostLoadDelay = true
					end
				end
				UniversalAutoload.updateActionEventText(self)
			end

			-- LOAD ALL ANIMATION SEQUENCE
			if spec.isLoading then
				spec.loadDelayTime = spec.loadDelayTime or 0
				if spec.loadDelayTime > UniversalAutoload.loadingSpeed then
					local lastObject = nil
					local loadedObject = false
					for index, object in ipairs(spec.sortedObjectsToLoad or {}) do
						if UniversalAutoload.isUsingAutoStrap(self) then
							local vehicle = UniversalAutoload.isStrappedOnOtherVehicle(self, object)
							if vehicle then
								vehicle:setAllTensionBeltsActive(false)
							end
						end
						lastObject = object
						if UniversalAutoload.loadObject(self, object, true) then
							loadedObject = true
							if spec.firstAttemptToLoad then
								spec.firstAttemptToLoad = false
								self:setAllTensionBeltsActive(false)
							end
							spec.loadDelayTime = 0
						end
						table.remove(spec.sortedObjectsToLoad, index)
						break
					end
					if not loadedObject then
						if #spec.sortedObjectsToLoad > 0 and lastObject then
							local i = #spec.sortedObjectsToLoad
							for _ = 1, #spec.sortedObjectsToLoad do
								local nextObject = spec.sortedObjectsToLoad[i]
								local lastObjectType = UniversalAutoload.getContainerType(lastObject)
								local nextObjectType = UniversalAutoload.getContainerType(nextObject)
								local shorterLog = nextObject~=nil and lastObject.isSplitShape and nextObject.isSplitShape and nextObject.sizeY <= lastObject.sizeY
								
								if lastObjectType == nextObjectType and not shorterLog then
									UniversalAutoload.debugPrint("DELETE SAME OBJECT TYPE: "..tostring(lastObjectType.name), debugLoading)
									table.remove(spec.sortedObjectsToLoad, i)
								else
									i = i - 1
								end
							end
						end
						if #spec.sortedObjectsToLoad > 0 then
							if spec.trailerIsFull or (UniversalAutoload.testLoadAreaIsEmpty(self) and not spec.autoCollectionMode) then
								UniversalAutoload.debugPrint("RESET PATTERN to fill in any gaps", debugLoading)
								spec.partiallyUnloaded = true
								spec.resetLoadingPattern = true
							end
						else
							if spec.activeLoading then
								if not spec.trailerIsFull and not self:ualGetIsMoving() then
									-- UniversalAutoload.debugPrint("** ATTEMPT RELOAD **")
									UniversalAutoload.startLoading(self)
								end
							else
							
								if spec.firstAttemptToLoad and not spec.autoCollectionMode and not self:ualGetIsMoving() then
									--UNABLE_TO_LOAD_OBJECT
									if spec.trailerIsFull then
										UniversalAutoload.showWarningMessage(self, "UNABLE_TO_LOAD_FULL")
									else
										UniversalAutoload.showWarningMessage(self, "UNABLE_TO_LOAD_EMPTY")
									end
									spec.partiallyUnloaded = true
									spec.resetLoadingPattern = true
								end
								if spec.lastUnloadCount ~= spec.totalUnloadCount then
									UniversalAutoload.debugPrint("STOP LOADING (items loaded = " .. tostring(spec.totalUnloadCount) .. ")")
								end
								spec.lastUnloadCount = spec.totalUnloadCount
								UniversalAutoload.stopLoading(self)
								
								if spec.totalUnloadCount == 0 then
									UniversalAutoload.debugPrint("** RESET LOADING AREA **")
									UniversalAutoload.resetLoadingArea(self)
								end
							
							end
						end
					end
				else
					spec.loadSpeedFactor = spec.loadSpeedFactor or 1
					spec.loadDelayTime = spec.loadDelayTime + (spec.loadSpeedFactor*dt)
				end
			end
			
			-- DELAY AFTER LOAD/UNLOAD FOR MP POSITION SYNC
			if spec.doPostLoadDelay then
				spec.postLoadDelayTime = spec.postLoadDelayTime or 0
				local logDelay = spec.isLogTrailer and UniversalAutoload.LOG_DELAY or 0
				local mpDelay = g_currentMission.missionDynamicInfo.isMultiplayer and UniversalAutoload.MP_DELAY or 0
				if spec.postLoadDelayTime > UniversalAutoload.loadingSpeed + mpDelay + logDelay then
					UniversalAutoload.resetLoadingState(self)
				else
					spec.postLoadDelayTime = spec.postLoadDelayTime + dt
				end
			end
			
			if spec.lastStrapStateChanged then
				spec.postStrapDelayTime = spec.postStrapDelayTime or 0
				local logDelay = spec.isLogTrailer and UniversalAutoload.LOG_DELAY or 0
				local mpDelay = g_currentMission.missionDynamicInfo.isMultiplayer and UniversalAutoload.MP_DELAY or 0
				if spec.postStrapDelayTime > UniversalAutoload.loadingSpeed + mpDelay + logDelay then
					-- print("DO DELAY AFTER STRAPPING")
					UniversalAutoload.togglePhysicsForLoadedObjects(self)
					spec.postStrapDelayTime = 0
					spec.lastStrapStateChanged = false
				else
					spec.postStrapDelayTime = spec.postStrapDelayTime + dt
				end
			end
			
			if self.delayStartLoading then
				spec.delayStartLoadingTime = spec.delayStartLoadingTime or 0
				if spec.delayStartLoadingTime > UniversalAutoload.loadingSpeed then
					-- print("start loading after delay")
					self.delayStartLoading = false
					spec.delayStartLoadingTime = 0
					UniversalAutoload.startLoading(self)
				else
					spec.delayStartLoadingTime = spec.delayStartLoadingTime + dt
				end
			end

		end
		
		UniversalAutoload.determineTipside(self)
		UniversalAutoload.countActivePallets(self)

	end
	
	-- if spec.wasActivated == true then	
		-- if not spec.doPostLoadDelay then
			
			-- UniversalAutoload.debugPrint("updateToggleLoading: " .. tostring(spec.updateToggleLoading))
			-- UniversalAutoload.debugPrint("doPostLoadDelay: " .. tostring(spec.doPostLoadDelay))
			-- UniversalAutoload.debugPrint("isLoading: " .. tostring(spec.isLoading))
			-- UniversalAutoload.debugPrint("isUnloading: " .. tostring(spec.isUnloading))
			-- UniversalAutoload.debugPrint("validUnloadCount: " .. tostring(spec.validUnloadCount))
			-- UniversalAutoload.debugPrint("currentTipside: " .. tostring(spec.currentTipside))
			
			-- spec.wasActivated = false
			-- UniversalAutoload.clearActionEvents(self)
			-- UniversalAutoload.updateActionEventKeys(self)
		-- end
	-- end
	
end

function UniversalAutoload:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_universalAutoload
	
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		return
	end
	
	if spec.stopError then
		if not spec.printedError then
			spec.printedError = true
			print("UAL - FATAL ERROR: " .. self:getFullName())
			print(spec.result)
		end
		return
	end
	
	if UniversalAutoload.lowRefreshMode then
		local status, result = pcall(UniversalAutoload.doUpdate, self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

		if not status then
			spec.stopError = true
			spec.result = result
		end
	end
end

function UniversalAutoload:ualOnDeleteVehicle_Callback()
	UniversalAutoload.VEHICLES[self] = nil
	UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DELETED", debugVehicles)
end


--
function UniversalAutoload:onActivate(isControlling)
	-- UniversalAutoload.debugPrint("onActivate: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - onActivate", debugVehicles)
		return
	end
	
	if self.isServer then
		UniversalAutoload.debugPrint("*** ACTIVE - "..self:getFullName().." ***", debugVehicles)
		UniversalAutoload.forceRaiseActive(self, true)
		spec.wasActivated = true
	end
	UniversalAutoload.lastClosestVehicle = nil
end
--
function UniversalAutoload:onDeactivate()
	-- UniversalAutoload.debugPrint("onDeactivate: "..self:getFullName())
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - onDeactivate", debugVehicles)
		return
	end
	
	if self.isServer then
		UniversalAutoload.debugPrint("*** NOT ACTIVE - "..self:getFullName().." ***", debugVehicles)
		UniversalAutoload.forceRaiseActive(self, false)
	end
	UniversalAutoload:clearActionEvents(self)
end
--
function UniversalAutoload:determineTipside()
	-- currently only used for the KRONE Profi Liner Curtain Trailer
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - determineTipside", debugVehicles)
		return
	end

	--<trailer tipSideIndex="1" doorState="false" tipAnimationTime="1.000000" tipState="2"/>
	if spec.isCurtainTrailer and self.spec_trailer then
		if self.spec_trailer.tipState == 2 then
			local tipSide = self.spec_trailer.tipSides[self.spec_trailer.currentTipSideIndex]
			
			if spec.currentTipside ~= "left" and string.find(tipSide.animation.name, "Left") then
				-- UniversalAutoload.debugPrint("SET SIDE = LEFT")
				UniversalAutoload.setCurrentTipside(self, "left")
				UniversalAutoload.setCurrentLoadside(self, "left")	
			end
			if spec.currentTipside ~= "right" and string.find(tipSide.animation.name, "Right") then
				-- UniversalAutoload.debugPrint("SET SIDE = RIGHT")
				UniversalAutoload.setCurrentTipside(self, "right")
				UniversalAutoload.setCurrentLoadside(self, "right")	
			end
		else
			if spec.currentTipside ~= "none" then
				-- UniversalAutoload.debugPrint("SET SIDE = NONE")
				UniversalAutoload.setCurrentTipside(self, "none")
				UniversalAutoload.setCurrentLoadside(self, "none")
			end
		end
	end
	
	if spec.rearUnloadingOnly and spec.currentTipside ~= "rear" then
		UniversalAutoload.setCurrentTipside(self, "rear")
		UniversalAutoload.setCurrentLoadside(self, "rear")	
	end
	if spec.frontUnloadingOnly and spec.currentTipside ~= "front" then
		UniversalAutoload.setCurrentTipside(self, "front")
		UniversalAutoload.setCurrentLoadside(self, "front")	
	end
	if not spec.rearUnloadingOnly and not spec.frontUnloadingOnly then
		if spec.currentTipside == "rear" or spec.currentTipside == "front" then
			UniversalAutoload.setCurrentTipside(self, "left")
			UniversalAutoload.setCurrentLoadside(self, "left")	
		end
	end
end
--
function UniversalAutoload:isValidForLoading(object)
	local spec = self.spec_universalAutoload
	local maxLength = UniversalAutoload.getMaxSingleLength(self)
	local minLength = spec.minLogLength or UniversalAutoload.minLogLength or 0
	if minLength > maxLength or not spec.isLogTrailer then
		minLength = 0
	end
	
	if object == nil then
		if debugPallets then
			g_currentMission:addExtraPrintText("object == nil")
		end
		return false
	end
	
	if UniversalAutoload.isPlayerHoldingItem(object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Held by player")
		end
		return false
	end
	
	if UniversalAutoload.disableAutoStrap and UniversalAutoload.isStrappedOnOtherVehicle(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Strapped On Other Vehicle")
		end
		return false
	end
	if object.isSplitShape and UniversalAutoload.isLoadedOnTrain(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Loaded On Train")
		end
		return false
	end
	if spec.autoCollectionMode and UniversalAutoload.isValidForManualLoading(object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Auto Collection Mode - manual loading")
		end
		return false
	end

	if object.isSplitShape and object.sizeY > maxLength + UniversalAutoload.DELTA then
		if debugPallets then
			g_currentMission:addExtraPrintText("Log - too long")
		end
		return false
	end
	if object.isSplitShape and object.sizeY < minLength then
		if debugPallets then
			g_currentMission:addExtraPrintText("Log - too short")
		end
		return false
	end
	if spec.isLogTrailer and not object.isSplitShape then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Log Trailer - not a log")
		end
		return false
	end
	if spec.autoCollectionMode and spec.baleCollectionActive and object.isRoundbale == nil then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Auto Collection Mode - not a bale")
		end
		return false
	end
	if object.isRoundbale ~= nil and object.mountObject then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Object Mounted")
		end
		return false
	end
	if object.spec_umbilicalReelOverload and object.spec_umbilicalReelOverload.isOverloading then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Umbilical Reel - overloading")
		end
		return false
	end
	if UniversalAutoload.ualGetPalletCanDischargeToTrailer(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Pallet Can Discharge To Trailer")
		end
		return false
	end
	
	if not UniversalAutoload.getPalletIsSelectedMaterial(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Pallet NOT Selected Material")
		end
		return false
	end
	if not UniversalAutoload.getPalletIsSelectedContainer(self, object) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "Pallet NOT Selected Container")
		end
		return false
	end
	
	local isBeingManuallyLoaded = spec.autoLoadingObjects[object] ~= nil
	local isValidLoadSide = spec.loadedObjects[object] == nil and UniversalAutoload.getPalletIsSelectedLoadside(self, object)
	if not (isBeingManuallyLoaded or isValidLoadSide) then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "NOT Valid Load Side")
		end
		return false
	end
	
	local isValidLoadFilter = not spec.currentLoadingFilter or (spec.currentLoadingFilter and UniversalAutoload.getPalletIsFull(object))
	if not isValidLoadFilter then
		if debugPallets then
			g_currentMission:addExtraPrintText(object.i3dFilename, "NOT Valid Load Filter")
		end
		return false
	end
	
	--if debugPallets then g_currentMission:addExtraPrintText(object.i3dFilename, "Valid For Loading") end
	return true
end
--
function UniversalAutoload:isValidForUnloading(object)
	local spec = self.spec_universalAutoload

	return UniversalAutoload.getPalletIsSelectedMaterial(self, object) and UniversalAutoload.getPalletIsSelectedContainer(self, object) and spec.autoLoadingObjects[object] == nil
end
--
function UniversalAutoload.isValidForManualLoading(object)
	if object.isSplitShape then
		return false
	end
	if object.mountObject or object.dynamicMountObject then
		return true
	end
end
function UniversalAutoload.isPlayerHoldingItem(object)
	for _, player in pairs(g_currentMission.players) do
		if player and player.hands and player.hands:getIsHoldingItem() then
			local rootObject = UniversalAutoload.getObjectRootNode(object)
			if rootObject and (rootObject == player.hands:getHeldItem()) then
				return true
			end
		end
	end
end
--
function UniversalAutoload:isUsingAutoStrap()
	-- UniversalAutoload.debugPrint("SHOULD USE AUTO STRAP")
	local spec = self.spec_universalAutoload
	
	if spec.disableAutoStrap or UniversalAutoload.disableAutoStrap then
		return false
	else
		return true
	end	
end
--
function UniversalAutoload:isUsingLayerLoading()
	-- UniversalAutoload.debugPrint("SHOULD USE LAYER LOADING?")
	local spec = self.spec_universalAutoload
	
	if (spec.isLogTrailer and spec.currentLayerCount < 2*UniversalAutoload.MAX_LAYER_COUNT)
	or (spec.useHorizontalLoading and spec.currentLayerCount < UniversalAutoload.MAX_LAYER_COUNT) then
		return true
	end	
end
--
function UniversalAutoload:countActivePallets()
	-- UniversalAutoload.debugPrint("COUNT ACTIVE PALLETS")
	local spec = self.spec_universalAutoload
	local isActiveForLoading = spec.isLoading or spec.isUnloading or spec.doPostLoadDelay
	
	if spec.countedPallets then
		return
	end
	spec.countedPallets = true
	
	local totalAvailableCount = 0
	local validLoadCount = 0
	for object, _ in pairs(spec.availableObjects or {}) do
		if object then
			totalAvailableCount = totalAvailableCount + 1
			if UniversalAutoload.isValidForLoading(self, object) then
				validLoadCount = validLoadCount + 1
			end
			if isActiveForLoading then
				UniversalAutoload.raiseObjectDirtyFlags(object)
			end
		end
	end
	if debugLoading then
		g_currentMission:addExtraPrintText(self:getName() .. " Load = " .. validLoadCount .. " / " .. totalAvailableCount)
	end
	
	if totalAvailableCount == 0 then
		if not spec.noAvailableObjects then
			spec.noAvailableObjects = true
			-- UniversalAutoload.debugPrint("NO AVAILABLE OBJECTS..")
			UniversalAutoload.updateActionEventText(self)
		end
	else
		if spec.noAvailableObjects then
			spec.noAvailableObjects = false
			-- UniversalAutoload.debugPrint("FOUND AVAILABLE OBJECTS..")
			UniversalAutoload.updateActionEventText(self)
		end
	end
	
	local totalUnloadCount = 0
	local validUnloadCount = 0
	for object, _ in pairs(spec.loadedObjects or {}) do
		if object then
			totalUnloadCount = totalUnloadCount + 1
			if UniversalAutoload.isValidForUnloading(self, object) then
				validUnloadCount = validUnloadCount + 1
			end
			if isActiveForLoading or spec.autoCollectionMode then
				UniversalAutoload.raiseObjectDirtyFlags(object)
			end
		end
	end
	if debugLoading then
		g_currentMission:addExtraPrintText(self:getName() .. " Unload = " .. validUnloadCount .. " / " .. totalUnloadCount)
	end
	
	if totalUnloadCount == 0 then
		if not spec.noLoadedObjects then
			spec.noLoadedObjects = true
			-- UniversalAutoload.debugPrint("NO OBJECTS TO UNLOAD..")
			UniversalAutoload.resetLoadingArea(self)
			UniversalAutoload.updateActionEventText(self)
		end
	else
		if spec.noLoadedObjects then
			spec.noLoadedObjects = false
			-- UniversalAutoload.debugPrint("FOUND LOADED OBJECTS..")
			UniversalAutoload.updateActionEventText(self)
		end
	end

	if (spec.validLoadCount ~= validLoadCount) or (spec.validUnloadCount ~= validUnloadCount) then
		local refreshMenuText = false
		if spec.validLoadCount ~= validLoadCount then
			UniversalAutoload.debugPrint("validLoadCount: "..tostring(spec.validLoadCount).."/"..validLoadCount, debugKeys)
			if spec.validLoadCount==0 or validLoadCount==0 then
				refreshMenuText = true
			end
			spec.validLoadCount = validLoadCount
		end
		if spec.validUnloadCount ~= validUnloadCount then
			UniversalAutoload.debugPrint("validUnloadCount: "..tostring(spec.validUnloadCount).."/"..validUnloadCount, debugKeys)
			if spec.validUnloadCount==0 or validUnloadCount==0 then
				refreshMenuText = true
			end
			spec.validUnloadCount = validUnloadCount
		end
		if refreshMenuText then
			UniversalAutoload.updateActionEventText(self)
		end
	end

	if debugLoading then
		if spec.totalAvailableCount ~= totalAvailableCount then
			UniversalAutoload.debugPrint("TOTAL AVAILABLE COUNT ERROR: "..tostring(spec.totalAvailableCount).." vs "..tostring(totalAvailableCount))
			spec.totalAvailableCount = totalAvailableCount
		end
		if spec.totalUnloadCount ~= totalUnloadCount then
			UniversalAutoload.debugPrint("TOTAL UNLOAD COUNT ERROR: "..tostring(spec.totalUnloadCount).." vs "..tostring(totalUnloadCount))
			spec.totalUnloadCount = totalUnloadCount
		end
	end
end

-- LOADING AND UNLOADING FUNCTIONS
function UniversalAutoload:loadObject(object, chargeForLoading)
	-- UniversalAutoload.debugPrint("UniversalAutoload - loadObject")
	if object and UniversalAutoload.getIsLoadingVehicleAllowed(self) and UniversalAutoload.isValidForLoading(self, object) then

		local spec = self.spec_universalAutoload
		local containerType = UniversalAutoload.getContainerType(object)

		local loadPlace = UniversalAutoload.getLoadPlace(self, containerType, object)
		if loadPlace then
		
			--ALTERNATE LOG ORIENTATION FOR EACH LAYER
			local rotateLogs = object.isSplitShape and (math.random(0,1) > 0.5);
			if UniversalAutoload.moveObjectNodes(self, object, loadPlace, true, rotateLogs) then
				UniversalAutoload.clearPalletFromAllVehicles(self, object)
				UniversalAutoload.addLoadedObject(self, object)
				
				if chargeForLoading == true then
					if object.isSplitShape then
						if UniversalAutoload.pricePerLog > 0 then
							g_currentMission:addMoney(-UniversalAutoload.pricePerLog, self:getOwnerFarmId(), MoneyType.AI, true, true)
						end
					elseif object.isRoundbale ~= nil then
						if UniversalAutoload.pricePerBale > 0 then
							g_currentMission:addMoney(-UniversalAutoload.pricePerBale, self:getOwnerFarmId(), MoneyType.AI, true, true)
						end
					elseif UniversalAutoload.pricePerPallet > 0 then
						g_currentMission:addMoney(-UniversalAutoload.pricePerPallet, self:getOwnerFarmId(), MoneyType.AI, true, true)
					end
				end
			
				UniversalAutoload.debugPrint(string.format("LOADED TYPE: %s [%.3f, %.3f, %.3f]",
					containerType.name, containerType.sizeX, containerType.sizeY, containerType.sizeZ), debugLoading)
				return true
			end
		end

	end

	return false
end
--
function UniversalAutoload:unloadObject(object, unloadPlace)
	-- UniversalAutoload.debugPrint("UniversalAutoload - unloadObject")
	if object and UniversalAutoload.isValidForUnloading(self, object) then
	
		if UniversalAutoload.moveObjectNodes(self, object, unloadPlace, false, false) then
			UniversalAutoload.clearPalletFromAllVehicles(self, object)
			return true
		end
	end
end
--
function UniversalAutoload.buildObjectsToUnloadTable(vehicle, forceUnloadPosition)
	local spec = vehicle.spec_universalAutoload
	
	spec.objectsToUnload = spec.objectsToUnload or {}
	for k, v in pairs(spec.objectsToUnload) do
		delete(v.node)
		spec.objectsToUnload[k] = nil
	end

	spec.unloadingAreaClear = true
	
	
	local _, HEIGHT, _ = getTranslation(spec.loadVolume.rootNode)
	for object, _ in pairs(spec.loadedObjects) do
		if UniversalAutoload.isValidForUnloading(vehicle, object) then
		
			local node = UniversalAutoload.getObjectPositionNode(object)
			if node then
				x, y, z = localToLocal(node, spec.loadVolume.rootNode, 0, 0, 0)
				rx, ry, rz = localRotationToLocal(node, spec.loadVolume.rootNode, 0, 0, 0)
				
				local unloadPlace = {}
				local containerType = UniversalAutoload.getContainerType(object)
				if containerType then
					local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType, true)
					unloadPlace.sizeX = w
					unloadPlace.sizeY = h
					unloadPlace.sizeZ = l
					if containerType.flipXY then
						unloadPlace.wasFlippedXY = true
					end
					if containerType.flipYZ then
						unloadPlace.wasFlippedYZ = true
					end
					
					local offsetX = 0
					local offsetY = 0
					local offsetZ = 0
					
					if forceUnloadPosition then
						if forceUnloadPosition == "rear" or forceUnloadPosition == "behind" then
							offsetZ = -spec.loadVolume.length - spec.loadVolume.width/2
						elseif forceUnloadPosition == "left" then
							offsetX = 1.5*spec.loadVolume.width
						elseif forceUnloadPosition == "right" then
							offsetX = -1.5*spec.loadVolume.width
						end
					else
						if spec.frontUnloadingOnly then
							offsetZ = spec.loadVolume.length + spec.loadVolume.width/2
						elseif spec.rearUnloadingOnly then
							offsetZ = -spec.loadVolume.length - spec.loadVolume.width/2
						else
							if spec.isLogTrailer then
								offsetX = 2*spec.loadVolume.width
							else
								offsetX = 1.5*spec.loadVolume.width
							end
							if spec.currentTipside == "right" then offsetX = -offsetX end
						end
					end
					
					offsetX = offsetX - containerType.offset.x
					offsetY = offsetY - containerType.offset.y
					offsetZ = offsetZ - containerType.offset.z

					unloadPlace.node = createTransformGroup("unloadPlace")
					link(spec.loadVolume.rootNode, unloadPlace.node)
					setTranslation(unloadPlace.node, x+offsetX, y+offsetY, z+offsetZ)
					setRotation(unloadPlace.node, rx, ry, rz)

					local X, Y, Z = UniversalAutoload.getWorldTranslation(unloadPlace.node)
					local heightAboveGround = DensityMapHeightUtil.getCollisionHeightAtWorldPos(X, Y, Z) + 0.1
					unloadPlace.heightAbovePlace = math.max(0, y)
					unloadPlace.heightAboveGround = math.max(-(HEIGHT+y), heightAboveGround-Y)
					spec.objectsToUnload[object] = unloadPlace
				end
			end
		end
	end
	
	for object, unloadPlace in pairs(spec.objectsToUnload) do
		local thisAreaClear = false
		local x, y, z = getTranslation(unloadPlace.node)
		
		if spec.loadArea and #spec.loadArea > 1 then
			local i = spec.loadedObjects[object] or 1
			local _, offsetY, _ = localToLocal(spec.loadArea[i].rootNode, spec.loadVolume.rootNode, 0, 0, 0)
			y = y - offsetY
		end
		
		for height = unloadPlace.heightAboveGround, 0, 0.1 do
			setTranslation(unloadPlace.node, x, y+height, z)
			if UniversalAutoload.testUnloadLocationIsEmpty(vehicle, unloadPlace) then
				local offset = unloadPlace.heightAbovePlace
				setTranslation(unloadPlace.node, x, y+offset+height, z)
				thisAreaClear = true
				break
			end
		end
		if (not thisAreaClear and not object.isSplitShape) or unloadPlace.heightAboveGround > 0 then
			spec.unloadingAreaClear = false
		end
	end
end
--
function UniversalAutoload.clearPalletFromAllVehicles(self, object)
	for vehicle, _ in pairs(UniversalAutoload.VEHICLES) do
		if vehicle and object then
			local loadedObjectRemoved = UniversalAutoload.removeLoadedObject(vehicle, object)
			local availableObjectRemoved = UniversalAutoload.removeAvailableObject(vehicle, object)
			local autoLoadingObjectRemoved = UniversalAutoload.removeAutoLoadingObject(vehicle, object)
			if loadedObjectRemoved or availableObjectRemoved then
				if not self or self ~= vehicle then
					local SPEC = vehicle.spec_universalAutoload
					if SPEC.totalUnloadCount == 0 then
						UniversalAutoload.debugPrint(" Cleared ALL Pallets from " .. vehicle:getFullName(), debugLoading)
						UniversalAutoload.resetLoadingArea(vehicle)
						vehicle:setAllTensionBeltsActive(false)
					elseif loadedObjectRemoved then
						if vehicle.spec_tensionBelts.areAllBeltsFastened then
							vehicle:setAllTensionBeltsActive(false)
							vehicle:setAllTensionBeltsActive(true)
						end
					end
				end
				UniversalAutoload.forceRaiseActive(vehicle)
			end
		end
	end
end	
--
function UniversalAutoload.isStrappedOnOtherVehicle(self, object)
	for vehicle, _ in pairs(UniversalAutoload.VEHICLES) do
		if vehicle and self ~= vehicle then
			if vehicle.spec_universalAutoload.loadedObjects[object] then
				if vehicle.spec_tensionBelts.areAllBeltsFastened then
					return vehicle
				end
			end
		end
	end
end
--
function UniversalAutoload.isLoadedOnTrain(self, object)
	for vehicle, _ in pairs(UniversalAutoload.VEHICLES) do
		if vehicle and self ~= vehicle then
			if UniversalAutoloadManager.getIsTrainCarriage(vehicle) then
				if vehicle.spec_universalAutoload.loadedObjects[object] then
					return true
				end
			end
		end
	end
end
--
function UniversalAutoload.unmountDynamicMount(object)

	if object.mountObject then
		if object.mountObject.removeMountedObject then
			object.mountObject:removeMountedObject(object, true)
		end
		if object.mountObject.onUnmountObject then
			object.mountObject:onUnmountObject(object)
		end
	end
	
	if object.dynamicMountObject then
		local vehicle = object.dynamicMountObject
		vehicle:removeDynamicMountedObject(object, true)
	end
	
	if object.unmountDynamic then
		if object.dynamicMountType == MountableObject.MOUNT_TYPE_DYNAMIC then
			object:unmountDynamic()
		elseif object.dynamicMountType == MountableObject.MOUNT_TYPE_KINEMATIC then
			object:unmountKinematic()
		end
		object:unmountDynamic(true)

		if object.additionalDynamicMountJointNode then
			delete(object.additionalDynamicMountJointNode)
			object.additionalDynamicMountJointNode = nil
		end
	end
end

function UniversalAutoload:createLoadingPlace(containerType)
	local spec = self.spec_universalAutoload
	
	spec.currentLoadingPlace = nil
	
	spec.currentLoadWidth = spec.currentLoadWidth or 0
	spec.currentLoadLength = spec.currentLoadLength or 0
	
	spec.currentActualWidth = spec.currentActualWidth or 0
	spec.currentActualLength = spec.currentActualLength or 0
	
	local i = spec.currentLoadAreaIndex or 1
	
	--DEFINE CONTAINER SIZES
	local sizeX, sizeY, sizeZ = UniversalAutoload.getContainerTypeDimensions(containerType)
	local loadSizeX = sizeX
	local loadSizeY = sizeY
	local loadSizeZ = sizeZ
	local containerSizeX = sizeX
	local containerSizeY = sizeY
	local containerSizeZ = sizeZ
	local isRoundbale = containerType.isRoundbale
	
	--TEST FOR ROUNDBALE PACKING
	if isRoundbale == true then
		if spec.useHorizontalLoading then
		-- LONGWAYS ROUNDBALE STACKING
			containerSizeY = sizeZ
			containerSizeZ = sizeY
		end
	end
	
	--CALCUATE POSSIBLE ARRAY SIZES
	local width = spec.loadArea[i].width
	local length = spec.loadArea[i].length
	
	--ALTERNATE LOG PACKING FOR EACH LAYER
	if spec.isLogTrailer then
		local spaceWidth = containerSizeZ
		local N = math.floor(width / spaceWidth)
		if N > 1 and spec.currentLayerCount % 2 ~= 0 then
			width = (N-1) * spaceWidth
		end
	end
	
	--CALCULATE PACKING DIMENSIONS
	local N1 = math.floor(width / containerSizeX)
	local M1 = math.floor(length / containerSizeZ)
	local N2 = math.floor(width / containerSizeZ)
	local M2 = math.floor(length / containerSizeX)
	
	--CHOOSE BEST PACKING ORIENTATION
	local N, M, rotation
	local neverRotate = containerType.neverRotate
	local alwaysRotate = containerType.alwaysRotate
	local shouldRotate = ((N2*M2) > (N1*M1)) or (((N2*M2)==(N1*M1)) and (N1>N2) and (N2*M2)>0)
	local doRotate = (alwaysRotate or shouldRotate) and not neverRotate
	
	--ALWAYS ROTATE ROUNDBALES WITH HORIZONTAL LOADING
	if isRoundbale == true and spec.useHorizontalLoading then
		doRotate = true
	end

	if debugLoading then
		UniversalAutoload.debugPrint("-------------------------------")
		UniversalAutoload.debugPrint("width: " .. tostring(width) )
		UniversalAutoload.debugPrint("length: " .. tostring(length) )
		UniversalAutoload.debugPrint(" N1: "..N1.. " ,  M1: "..M1)
		UniversalAutoload.debugPrint(" N2: "..N2.. " ,  M2: "..M2)
		UniversalAutoload.debugPrint("neverRotate: " .. tostring(neverRotate) )
		UniversalAutoload.debugPrint("alwaysRotate: " .. tostring(alwaysRotate) )
		UniversalAutoload.debugPrint("shouldRotate: " .. tostring(shouldRotate) )
		UniversalAutoload.debugPrint("doRotate: " .. tostring(doRotate) )
	end
	
	local N, M = N1, M1
	local rotation = 0
	
	-- APPLY ROTATION
	if doRotate then
		N, M = N2, M2
		rotation = math.pi/2
		loadSizeX = sizeZ
		loadSizeY = sizeY
		loadSizeZ = sizeX
	end
	
	--TEST FOR ROUNDBALE PACKING
	local r = 0.70710678
	local R = ((3/4)+(r/4))
	local roundbaleOffset = 0
	local useRoundbalePacking = nil
	if isRoundbale then
		if spec.useHorizontalLoading then
		-- HORIZONAL ROUNDBALE PACKING
			rotation = math.pi/2
			useRoundbalePacking = false
		else
		-- UPRIGHT ROUNDBALE STACKING
			NR = math.floor(width / (R*sizeX))
			MR = math.floor(length / (R*sizeX))
			if NR > N and width >= (2*R)*sizeX then
				useRoundbalePacking = true
				N, M = NR, MR
				loadSizeX = R*sizeX
			end
		end
	end
	
	--UPDATE NEW PACKING DIMENSIONS
	local addedLoadWidth = loadSizeX
	local addedLoadLength = loadSizeZ
	if useRoundbalePacking == false then
		addedLoadWidth = loadSizeY
	end
	spec.currentLoadHeight = 0
	spec.lastAddedLoadDifference = 0
	local tooWideForSpace = spec.currentLoadWidth + addedLoadWidth > spec.loadArea[i].width
	local shouldStartNewRow = spec.currentLoadWidth == 0 or tooWideForSpace
	if shouldStartNewRow then
		spec.currentLoadWidth = addedLoadWidth
		spec.currentActualWidth = (N * addedLoadWidth)
		spec.currentActualLength = spec.currentLoadLength
		spec.currentLoadLength = spec.currentLoadLength + addedLoadLength
		spec.lastAddedLoadLength = addedLoadLength
		if spec.isLogTrailer and spec.currentActualLength ~= 0 then
			spec.currentLoadLength = spec.currentLoadLength + UniversalAutoload.LOG_SPACE
		end
	else
		spec.currentLoadWidth = spec.currentLoadWidth + addedLoadWidth
		if spec.lastAddedLoadLength and spec.lastAddedLoadLength + UniversalAutoload.DELTA < addedLoadLength then
			local difference = addedLoadLength - spec.lastAddedLoadLength
			spec.currentLoadLength = spec.currentLoadLength + difference
			spec.lastAddedLoadLength = addedLoadLength
			spec.lastAddedLoadDifference = difference
		end
	end

	if spec.currentLoadLength == 0 then
		UniversalAutoload.debugPrint("LOAD LENGTH WAS ZERO")
		spec.currentLoadLength = loadSizeZ
	end
	
	if useRoundbalePacking == false then
		
		local baleEnds = true
		local layerOffset = spec.currentLayerCount * containerSizeX/2
		
		-- FIRST BALE ON A LAYER
		if spec.currentLoadLength == containerSizeX then
			-- if baleEnds and spec.currentLayerCount == 0 then
				-- spec.currentLoadLength = spec.currentLoadLength + containerSizeX
			-- end
			spec.currentLoadLength = spec.currentLoadLength + layerOffset
		end
		
		-- LAST BALE ON A LAYER
		if spec.currentLoadLength > spec.loadArea[i].length - layerOffset then
			spec.currentLoadLength = spec.currentLoadLength + layerOffset + containerSizeX
		end
		
		-- LAST BALE ON FIRST LAYER
		-- if baleEnds and spec.currentLayerCount == 0 and spec.currentLoadLength > spec.loadArea[i].length - containerSizeX then
			-- spec.currentLoadLength = spec.currentLoadLength + containerSizeX
		-- end
		

	elseif useRoundbalePacking == true then
		if (spec.currentLoadWidth/loadSizeX) % 2 == 0 then
			roundbaleOffset = containerSizeZ/2
		end
	end
	
	if debugLoading then
		UniversalAutoload.debugPrint("LoadingAreaIndex: " .. tostring(spec.currentLoadAreaIndex) )
		UniversalAutoload.debugPrint("currentLoadWidth: " .. tostring(spec.currentLoadWidth) )
		UniversalAutoload.debugPrint("currentLoadLength: " .. tostring(spec.currentLoadLength) )
		UniversalAutoload.debugPrint("currentActualWidth: " .. tostring(spec.currentActualWidth) )
		UniversalAutoload.debugPrint("currentActualLength: " .. tostring(spec.currentActualLength) )
		UniversalAutoload.debugPrint("currentLoadHeight: " .. tostring(spec.currentLoadHeight) )
		UniversalAutoload.debugPrint("currentLayerCount: " .. tostring(spec.currentLayerCount) )
		UniversalAutoload.debugPrint("currentLayerHeight: " .. tostring(spec.currentLayerHeight) )
		UniversalAutoload.debugPrint("nextLayerHeight: " .. tostring(spec.nextLayerHeight) )
		UniversalAutoload.debugPrint("-------------------------------")
	end
	
	local d = UniversalAutoload.DELTA
	if spec.currentLoadLength<=spec.loadArea[i].length+d and spec.currentLoadWidth<=spec.currentActualWidth+d then
		-- UniversalAutoload.debugPrint("CREATE NEW LOADING PLACE")
		loadPlace = {}
		loadPlace.node = createTransformGroup("loadPlace")
		loadPlace.sizeX = containerSizeX + d
		loadPlace.sizeY = containerSizeY + d
		loadPlace.sizeZ = containerSizeZ + d
		loadPlace.flipYZ = containerType.flipYZ
		loadPlace.isRoundbale = isRoundbale
		loadPlace.roundbaleOffset = roundbaleOffset
		loadPlace.useRoundbalePacking = useRoundbalePacking
		loadPlace.containerType = containerType
		loadPlace.rotation = rotation
		if useRoundbalePacking == true then
			loadPlace.sizeX = r*containerSizeX
			loadPlace.sizeZ = r*containerSizeZ
		end
		if containerType.isBale then
			loadPlace.baleOffset = containerSizeY/2
		end
		
		--LOAD FROM THE CORRECT SIDE
		local posX = -( spec.currentLoadWidth - (spec.currentActualWidth/2) - (addedLoadWidth/2) )
		local posZ = -( spec.currentLoadLength - (addedLoadLength/2) ) - roundbaleOffset
		if spec.currentLoadside == "left" then posX = -posX end

		--SET POSITION AND ORIENTATION
		loadPlace.offset = {
			x = -containerType.offset.x,
			y = -containerType.offset.y,
			z = -containerType.offset.z,
		}

		local offset = loadPlace.offset
		link(spec.loadArea[i].startNode, loadPlace.node)
		setTranslation(loadPlace.node, posX+offset.x, 0+offset.y, posZ+offset.z)
		setRotation(loadPlace.node, 0, rotation, 0)
		
		--STORE AS CURRENT LOADING PLACE
		spec.currentLoadingPlace = loadPlace
		
		spec.lastLoadAttempt = {
			loadPlace = deepCopy(loadPlace),
			containerType = containerType,
		}

	end
end
--
function UniversalAutoload:resetLoadingPattern()
	local spec = self.spec_universalAutoload
	UniversalAutoload.debugPrint("["..tostring(self.rootNode).."] RESET loading pattern", debugLoading)
	spec.currentLoadWidth = 0
	spec.currentLoadHeight = 0
	spec.currentLoadLength = 0
	spec.currentActualWidth = 0
	spec.currentActualLength = 0
	spec.currentLoadingPlace = nil
	spec.resetLoadingPattern = false
end
--
function UniversalAutoload:resetLoadingLayer()
	local spec = self.spec_universalAutoload
	UniversalAutoload.debugPrint("["..tostring(self.rootNode).."] RESET loading layer", debugLoading)
	spec.nextLayerHeight = 0
	spec.currentLayerCount = 0
	spec.currentLayerHeight = 0
	spec.resetLoadingLayer = false
end
--
function UniversalAutoload:resetLoadingArea()
	local spec = self.spec_universalAutoload
	UniversalAutoload.debugPrint("["..tostring(self.rootNode).."] RESET loading area", debugLoading)
	UniversalAutoload.resetLoadingLayer(self)
	UniversalAutoload.resetLoadingPattern(self)
	spec.trailerIsFull = false
	spec.partiallyUnloaded = false
	spec.lastAddedLoadLength = 0
	spec.currentLoadAreaIndex = 1
	spec.lastLoadAttempt = nil
end
--
function UniversalAutoload:evaluateLoadPlace(containerType, object, thisLoadPlace)
	local spec = self.spec_universalAutoload
	local i = spec.currentLoadAreaIndex or 1
	local maxLoadAreaHeight = spec.maxLoadAreaHeight or spec.loadArea[i].height

	spec.loadSpeedFactor = 1
	local useThisLoadSpace = false
			
	local offset = thisLoadPlace.offset
	local x0,_,z0 = getTranslation(thisLoadPlace.node)
	setTranslation(thisLoadPlace.node, x0, spec.currentLoadHeight+offset.y, z0)

	if spec.isLogTrailer then
		
		UniversalAutoload.debugPrint("LOG TRAILER", debugLoading)
		if not self:ualGetIsMoving() then
			local heightOffset = 0.1
			local logLoadHeight = maxLoadAreaHeight + heightOffset
			if not spec.zonesOverlap then
				logLoadHeight = math.min(spec.currentLayerHeight, maxLoadAreaHeight) + heightOffset
			end
			setTranslation(thisLoadPlace.node, x0, logLoadHeight+offset.y, z0)
			if UniversalAutoload.testLocationIsEmpty(self, thisLoadPlace, object, heightOffset, CollisionFlag.TREE) then
				spec.currentLoadHeight = spec.currentLayerHeight
				local mass = UniversalAutoload.getContainerMass(object)
				local massFactor = math.clamp((1/mass)/2, 0.2, 1)
				local heightFactor = maxLoadAreaHeight/(maxLoadAreaHeight+spec.currentLoadHeight)
				spec.loadSpeedFactor = math.clamp(heightFactor*massFactor, 0.1, 0.5)
				useThisLoadSpace = true
			end
		end

	elseif spec.autoCollectionMode and spec.baleCollectionActive then
		
		UniversalAutoload.debugPrint("AUTO BALE COLLECTION MODE", debugLoading)
		if (containerType.isBale and not spec.zonesOverlap and not spec.partiallyUnloaded) then
			if spec.useHorizontalLoading then
				spec.currentLoadHeight = spec.currentLayerHeight
				setTranslation(thisLoadPlace.node, x0, spec.currentLayerHeight+offset.y, z0)
				UniversalAutoload.debugPrint("useHorizontalLoading: " .. spec.currentLayerHeight, debugLoading)
			end
			spec.loadSpeedFactor = 2
			useThisLoadSpace = true
		else
			UniversalAutoload.debugPrint("NOT A BALE", debugLoading)
			return
		end
		
	else
		
		if not self:ualGetIsMoving() then
			
			local increment = 0.1
			if spec.useHorizontalLoading and not spec.partiallyUnloaded then
				local thisLoadHeight = spec.currentLayerHeight
				while thisLoadHeight+offset.y <= maxLoadAreaHeight - thisLoadPlace.newLoadHeight do
					setTranslation(thisLoadPlace.node, x0, thisLoadHeight+offset.y, z0)
					local placeEmpty = UniversalAutoload.testLocationIsEmpty(self, thisLoadPlace, object)
					local placeBelowFull = UniversalAutoload.testLocationIsFull(self, thisLoadPlace, -thisLoadPlace.newLoadHeight)
					if placeEmpty and (thisLoadHeight<=0 or placeBelowFull) then
						spec.currentLoadHeight = thisLoadHeight
						useThisLoadSpace = true
						break
					end
					thisLoadHeight = thisLoadHeight + increment
				end
			else
				local thisLoadHeight = spec.currentLoadHeight
				while thisLoadHeight+offset.y >= -increment do
					setTranslation(thisLoadPlace.node, x0, thisLoadHeight+offset.y, z0)
					if UniversalAutoload.testLocationIsEmpty(self, thisLoadPlace, object)
					and (thisLoadHeight<=0 or UniversalAutoload.testLocationIsFull(self, thisLoadPlace, -thisLoadPlace.newLoadHeight))
					then
						spec.currentLoadHeight = math.max(0, thisLoadHeight)
						useThisLoadSpace = true
						break
					end
					thisLoadHeight = thisLoadHeight - increment
				end
			end
		end
	end
	return useThisLoadSpace
end
--
function UniversalAutoload:getLoadPlace(containerType, object)
	local spec = self.spec_universalAutoload
	
	if spec.palletsRemovedFromPhysics then
		-- print("getLoadPlace - add pallets back to Physics")
		return
	end
	
	if containerType==nil or (spec.trailerIsFull and not spec.partiallyUnloaded) then
		UniversalAutoload.debugPrint("containerType==nil or trailerIsFull", debugLoading)
		return
	end
	
	if not self:ualGetIsMoving() or (spec.baleCollectionActive and containerType.isBale) then
		if debugLoading then
			UniversalAutoload.debugPrint("")
			UniversalAutoload.debugPrint("===============================")
			UniversalAutoload.debugPrint("["..tostring(self.rootNode).."] FIND LOADING PLACE FOR "..containerType.name)
		end

		local i = spec.currentLoadAreaIndex or 1
		while i <= #spec.loadArea do
			if spec.resetLoadingPattern ~= false then
				UniversalAutoload.resetLoadingPattern(self)
			end
		
			if UniversalAutoload.getIsLoadingAreaAllowed(self, i) then
			
				spec.nextLayerHeight = spec.nextLayerHeight or 0
				spec.currentLoadHeight = spec.currentLoadHeight or 0
				spec.currentLayerCount = spec.currentLayerCount or 0
				spec.currentLayerHeight = spec.currentLayerHeight or 0

				local containerSizeX = containerType.sizeX
				local containerSizeY = containerType.sizeY
				local containerSizeZ = containerType.sizeZ
				local containerFlipYZ = containerType.flipYZ

				--TEST FOR ROUNDBALE PACKING
				if containerType.isBale and containerType.isRoundbale then
					if spec.useHorizontalLoading then
					-- LONGWAYS ROUNDBALE STACKING
						containerSizeY = containerType.sizeZ * UniversalAutoload.ROTATED_BALE_FACTOR + UniversalAutoload.DELTA
						containerSizeZ = containerType.sizeY
					end
				end
				
				local mass = UniversalAutoload.getContainerMass(object)
				local volume = containerSizeX * containerSizeY * containerSizeZ
				local density = math.min(mass/volume, 1.5)
			
				local isFirstLayer = (spec.isLogTrailer or spec.useHorizontalLoading) and spec.currentLayerCount == 0
				local ignoreHeightForContainer = isFirstLayer and not (spec.isCurtainTrailer or spec.isBoxTrailer)
					
				while spec.currentLoadLength <= spec.loadArea[i].length do

					local maxLoadAreaHeight = spec.loadArea[i].height
					if containerType.isBale and spec.loadArea[i].baleHeight then
						maxLoadAreaHeight = spec.loadArea[i].baleHeight
					end
					
					if ignoreHeightForContainer then
						UniversalAutoload.debugPrint("ignoreHeightForContainer", debugLoading)
						maxLoadAreaHeight = math.max(maxLoadAreaHeight, containerSizeY + 0.1)
					else
						if (spec.currentLoadHeight > 0 or spec.useHorizontalLoading) and maxLoadAreaHeight > containerSizeY
						and not spec.disableHeightLimit and not spec.isLogTrailer then
							if density > 0.5 then
								maxLoadAreaHeight = maxLoadAreaHeight * (7-(2*density))/6
							end
							local maxStackHeight = UniversalAutoload.MAX_STACK * (containerSizeY + UniversalAutoload.DELTA)
							if maxLoadAreaHeight > maxStackHeight then
								maxLoadAreaHeight = maxStackHeight
							end
						end
					end
					spec.maxLoadAreaHeight = maxLoadAreaHeight
					
					local loadOverMaxHeight = spec.currentLoadHeight + containerSizeY > maxLoadAreaHeight
					local layerOverMaxHeight = spec.currentLayerHeight + containerSizeY > maxLoadAreaHeight
					
					if spec.currentLoadingPlace and spec.currentLoadHeight==0 and loadOverMaxHeight and not ignoreHeightForContainer then
						UniversalAutoload.debugPrint("CONTAINER IS TOO TALL FOR THIS AREA", debugLoading)
						return
					else
						if spec.currentLoadingPlace and loadOverMaxHeight then
							if ((object.isSplitShape or containerType.isBale) and not spec.zonesOverlap) or
							UniversalAutoload.testLocationIsFull(self, spec.currentLoadingPlace) then
								UniversalAutoload.debugPrint("LOADING PLACE IS FULL - SET TO NIL", debugLoading)
								spec.currentLoadingPlace = nil
							else
								UniversalAutoload.debugPrint("PALLET IS MISSING FROM PREVIOUS PLACE - TRY AGAIN", debugLoading)
							end
						end
						if not spec.currentLoadingPlace or spec.useHorizontalLoading or spec.isLogTrailer then
							local ignoreMaxHeight = spec.isLogTrailer or ignoreHeightForContainer or not layerOverMaxHeight
							if not spec.useHorizontalLoading or (spec.useHorizontalLoading and ignoreMaxHeight) then
								UniversalAutoload.debugPrint(string.format("ADDING NEW PLACE FOR: %s [%.3f, %.3f, %.3f]",
								containerType.name, containerSizeX, containerSizeY, containerSizeZ), debugLoading)
								UniversalAutoload.createLoadingPlace(self, containerType)
							else
								UniversalAutoload.debugPrint("REACHED MAX LAYER HEIGHT", debugLoading)
								spec.currentLoadingPlace = nil
								break
							end
						end
					end

					if containerType.neverStack and (spec.currentLoadHeight > 0 or spec.currentLayerHeight > 0) then
						UniversalAutoload.debugPrint("NEVER STACK", debugLoading)
						spec.currentLoadingPlace = nil
					end

					if spec.currentLoadingPlace then
						UniversalAutoload.debugPrint("TRY NEW LOAD PLACE..", debugLoading)
						local newLoadPlace = spec.currentLoadingPlace
						newLoadPlace.newLoadHeight = containerSizeY + UniversalAutoload.DELTA
					
						local containerFitsInLoadSpace = spec.isLogTrailer or 
							(newLoadPlace.useRoundbalePacking and containerType.isRoundbale) or
							(containerSizeX <= newLoadPlace.sizeX and containerSizeZ <= newLoadPlace.sizeZ)
						local containerStackBelowLimit = (spec.currentLoadHeight == 0) or
							(spec.currentLoadHeight + newLoadPlace.newLoadHeight <= maxLoadAreaHeight)
						if debugLoading then 
							UniversalAutoload.debugPrint("containerFitsInLoadSpace = " .. tostring(containerFitsInLoadSpace))
							UniversalAutoload.debugPrint("containerStackBelowLimit = " .. tostring(containerStackBelowLimit))
							UniversalAutoload.debugPrint("currentLoadHeight = " .. tostring(spec.currentLoadHeight))
						end
						
						if containerFitsInLoadSpace and containerStackBelowLimit then
							if UniversalAutoload.evaluateLoadPlace(self, containerType, object, newLoadPlace) then

								spec.currentLoadHeight = spec.currentLoadHeight + newLoadPlace.newLoadHeight
								spec.nextLayerHeight = math.max(spec.currentLoadHeight, spec.nextLayerHeight)
								
								UniversalAutoload.debugPrint("USING LOAD PLACE - height: " .. tostring(spec.currentLoadHeight), debugLoading)
								return newLoadPlace
							end
						end

						if spec.useHorizontalLoading and spec.nextLayerHeight == 0 then
							UniversalAutoload.debugPrint("SHIFT POSITION " .. tostring(spec.currentLoadLength), debugLoading)
							spec.currentLoadLength = spec.currentLoadLength + UniversalAutoload.DELTA
							spec.currentLoadingPlace = nil
							return UniversalAutoload.getLoadPlace(self, containerType, object)
						end

						UniversalAutoload.debugPrint("DID NOT FIT HERE...", debugLoading)
						spec.currentLoadingPlace = nil
						if spec.lastAddedLoadDifference then
							-- UniversalAutoload.debugPrint("RESET currentLoadLength")
							spec.currentLoadLength = spec.currentLoadLength - spec.lastAddedLoadDifference
							spec.lastAddedLoadDifference = 0
						end
					end
				end
			end

			i = i + 1
			spec.resetLoadingPattern = true
			if #spec.loadArea > 1 and i <= #spec.loadArea then
				UniversalAutoload.debugPrint("TRY NEXT LOADING AREA ("..tostring(i)..")...", debugLoading)
				spec.currentLoadAreaIndex = i
			end
		end
		spec.currentLoadAreaIndex = 1
		if UniversalAutoload.isUsingLayerLoading(self) and
		not (spec.baleCollectionActive and spec.nextLayerHeight == 0) then
			spec.currentLayerCount = spec.currentLayerCount + 1
			spec.currentLoadingPlace = nil
			if not spec.isLogTrailer or (spec.isLogTrailer and spec.nextLayerHeight > 0) then
				spec.currentLayerHeight = spec.nextLayerHeight
				spec.nextLayerHeight = 0
			end
			if debugLoading then
				UniversalAutoload.debugPrint("START NEW LAYER")
				UniversalAutoload.debugPrint("currentLayerCount: " .. spec.currentLayerCount)
				UniversalAutoload.debugPrint("currentLayerHeight: " .. spec.currentLayerHeight)
			end
			return UniversalAutoload.getLoadPlace(self, containerType, object)
		else
			UniversalAutoload.debugPrint("FULL - NO MORE ROOM", debugLoading)
			spec.trailerIsFull = true
			if spec.autoCollectionMode then
				UniversalAutoload.debugPrint("autoCollectionMode: trailerIsFull", debugSpecial)
				UniversalAutoload.setAutoCollectionMode(self, false)
			else
				if UniversalAutoload.testLoadAreaIsEmpty(self) then
					UniversalAutoload.debugPrint("*** FAILED TO LOAD - BUT LOAD AREA WAS EMPTY ***")
					UniversalAutoload.resetLoadingArea(self)
				end
			end
		end
		UniversalAutoload.debugPrint("===============================", debugLoading)
	else
		if not spec.activeLoading and not spec.autoCollectionMode then
			UniversalAutoload.debugPrint("CAN'T LOAD WHEN MOVING...", debugLoading)
			--NO_LOADING_UNLESS_STATIONARY
			UniversalAutoload.showWarningMessage(self, "NO_LOADING_UNLESS_STATIONARY")
		end
	end
end

-- OBJECT PICKUP LOGIC FUNCTIONS
function UniversalAutoload:getIsValidObject(object)
	local spec = self.spec_universalAutoload
	
	if object.isSplitShape then
		if not entityExists(object.nodeId) then
			UniversalAutoload.debugPrint("SplitShape - DOES NOT EXIST..")
			UniversalAutoload.removeSplitShapeObject(self, object)
			return false
		else
			return true
		end
	end
	
	if object.i3dFilename then
		local accessHandler = g_currentMission.accessHandler
		local farmId = self:getActiveFarm()
		local ownerFarmId = object:getOwnerFarmId()
		if ownerFarmId == AccessHandler.NOBODY or accessHandler:canFarmAccess(farmId, object) then
			return UniversalAutoload.getContainerType(object) ~= nil
		end
	end
	
	UniversalAutoload.debugPrint("UAL Invalid Object:", debugPallets)
	UniversalAutoload.debugPrint("   i3d - " .. tostring(object.i3dFilename), debugPallets)
	UniversalAutoload.debugPrint("  type - " .. tostring(object.typeName), debugPallets)
	return false
end

function UniversalAutoload:getIsLoadingKeyAllowed()
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - getIsLoadingKeyAllowed", debugVehicles)
		return
	end

	if spec.doPostLoadDelay or spec.validLoadCount == 0 or spec.currentLoadside == "none" then
		return false
	end
	if spec.trailerIsFull or spec.autoCollectionMode then
		return false
	end
	return UniversalAutoload.getIsLoadingVehicleAllowed(self)
end
--
function UniversalAutoload:getIsUnloadingKeyAllowed()
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - getIsUnloadingKeyAllowed", debugVehicles)
		return
	end
	
	if (spec.doPostLoadDelay or spec.isLoading or spec.isUnloading
	or spec.validUnloadCount == 0 or spec.currentTipside == "none")
	and not spec.autoCollectionMode	then
		return false
	end
	if spec.isBoxTrailer and spec.noLoadingIfFolded and (self:ualGetIsFolding() or not self:getIsUnfolded()) then
		return false
	end
	if spec.isBoxTrailer and spec.noLoadingIfUnfolded and (self:ualGetIsFolding() or self:getIsUnfolded()) then
		return false
	end
	if spec.noLoadingIfCovered and self:ualGetIsCovered() then
		return false
	end
	if spec.noLoadingIfUncovered and not self:ualGetIsCovered() then
		return false
	end
	if spec.baleCollectionActive or spec.baleCollectionModeDeactivated then
		return false
	end
	return true
end
--
function UniversalAutoload:getIsLoadingVehicleAllowed(triggerId)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - getIsLoadingVehicleAllowed", debugVehicles)
		return false
	end
	
	if self:ualGetIsFilled() then
		-- UniversalAutoload.debugPrint("ualGetIsFilled")
		return false
	end
	if self:ualGetIsAttaching() then
		-- UniversalAutoload.debugPrint("ualGetIsAttaching")
		return false
	end
	if spec.noLoadingIfFolded and (self:ualGetIsFolding() or not self:getIsUnfolded()) then
		-- UniversalAutoload.debugPrint("noLoadingIfFolded")
		return false
	end
	if spec.noLoadingIfUnfolded and (self:ualGetIsFolding() or self:getIsUnfolded()) then
		-- UniversalAutoload.debugPrint("noLoadingIfUnfolded")
		return false
	end
	if spec.noLoadingIfCovered and self:ualGetIsCovered() then
		-- UniversalAutoload.debugPrint("noLoadingIfCovered")
		return false
	end
	if spec.noLoadingIfUncovered and not self:ualGetIsCovered() then
		-- UniversalAutoload.debugPrint("noLoadingIfUncovered")
		return false
	end
	
	-- check that curtain trailers have an open curtain
	if spec.isCurtainTrailer and triggerId then
		-- UniversalAutoload.debugPrint("CURTAIN TRAILER")
		local tipState = self:getTipState()
		local doorOpen = self:getIsUnfolded()
		local rearTrigger = triggerId == spec.rearTriggerId
		local curtainsOpen = not (tipState == Trailer.TIPSTATE_CLOSED or tipState == Trailer.TIPSTATE_CLOSING)

		if spec.enableRearLoading and rearTrigger then
			if not doorOpen then
				-- UniversalAutoload.debugPrint("NO LOADING IF DOOR CLOSED")
				return false
			end
		end
		
		if spec.enableSideLoading and not rearTrigger then
			if not curtainsOpen then
				-- UniversalAutoload.debugPrint("NO LOADING IF CURTAIN CLOSED")
				return false
			end
		end
	end

	local node = UniversalAutoload.getObjectPositionNode( self )
	if node == nil then
		-- UniversalAutoload.debugPrint("node == nil")
		return false
	end
	
	if node then
		-- check that the vehicle has not fallen on its side
		local _, y1, _ = UniversalAutoload.getWorldTranslation(node)
		local _, y2, _ = UniversalAutoload.localToWorld(node, 0, 1, 0)
		if y2 - y1 < 0.5 then
			-- UniversalAutoload.debugPrint("NO LOADING IF FALLEN OVER")
			return false
		end
	end
	
	return true
end
--
function UniversalAutoload:getIsLoadingAreaAllowed(i)
	local spec = self.spec_universalAutoload
	if spec==nil or not spec.isAutoloadAvailable or spec.autoloadDisabled then
		UniversalAutoload.debugPrint(self:getFullName() .. ": UAL DISABLED - getIsLoadingAreaAllowed", debugVehicles)
		return false
	end

	if not spec.loadArea or #spec.loadArea == 0 then
		return false
	end
	
	if spec.loadArea[i].noLoadingIfFolded and (self:ualGetIsFolding() or not self:getIsUnfolded()) then
		return false
	end
	if spec.loadArea[i].noLoadingIfUnfolded and (self:ualGetIsFolding() or self:getIsUnfolded()) then
		return false
	end
	if spec.loadArea[i].noLoadingIfCovered and self:ualGetIsCovered() then
		return false
	end
	if spec.loadArea[i].noLoadingIfUncovered and not self:ualGetIsCovered() then
		return false
	end
	return true
end
--
function UniversalAutoload:getIsUnloadingAreaAllowed(i)
	local spec = self.spec_universalAutoload
	
	return true
end
--
function UniversalAutoload:testLocationIsFull(loadPlace, offset)
	local spec = self.spec_universalAutoload
	local r = 0.50
	local sizeX, sizeY, sizeZ = (loadPlace.sizeX/2)*r, (loadPlace.sizeY/2)*r, (loadPlace.sizeZ/2)*r
	local x, y, z = UniversalAutoload.localToWorld(loadPlace.node, 0, offset or 0, 0, spec.velocityCorrection)
	local rx, ry, rz = UniversalAutoload.getWorldRotation(loadPlace.node)
	local dx, dy, dz = UniversalAutoload.localDirectionToWorld(loadPlace.node, 0, sizeY, 0)
	
	if spec.palletsRemovedFromPhysics then
		-- print("Test Location Full: palletsRemovedFromPhysics")
		return false
	end
	
	spec.foundObject = false
	spec.currentObject = self
	
	local collisionMask = UniversalAutoload.MASK.object
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocationOverlap_Callback", self, collisionMask, true, true, true, true)
	
	-- if debugLoading then 
		-- UniversalAutoload.debugPrint(self:getFullName())
		-- UniversalAutoload.debugPrint(" HIT COUNT: " .. tostring(hitCount))
		-- DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
	-- end
	
	return spec.foundObject
end
--
function UniversalAutoload:testLocationIsEmpty(loadPlace, object, offset, mask)
	local spec = self.spec_universalAutoload
	local r = 0.025
	local sizeX, sizeY, sizeZ = (loadPlace.sizeX/2)-r, (loadPlace.sizeY/2)-r, (loadPlace.sizeZ/2)-r
	local x, y, z = UniversalAutoload.localToWorld(loadPlace.node, 0, offset or 0, 0, spec.velocityCorrection)
	local rx, ry, rz = UniversalAutoload.getWorldRotation(loadPlace.node)
	local dx, dy, dz = UniversalAutoload.localDirectionToWorld(loadPlace.node, 0, loadPlace.sizeY/2, 0)
	
	if spec.palletsRemovedFromPhysics then
		-- print("Test Location Empty: palletsRemovedFromPhysics")
		return false
	end
	
	spec.foundObject = false
	spec.currentObject = object

	local collisionMask = mask
	if mask == nil then
		collisionMask = UniversalAutoload.MASK.everything
	end
	
	if loadPlace.isRoundbale and loadPlace.useRoundbalePacking == false then
		dy = dy + (sizeY * (1 - UniversalAutoload.ROTATED_BALE_FACTOR) / 2) + UniversalAutoload.DELTA
		sizeX = sizeX * UniversalAutoload.ROTATED_BALE_FACTOR
		sizeY = sizeY * UniversalAutoload.ROTATED_BALE_FACTOR
		sizeZ = sizeZ * UniversalAutoload.ROTATED_BALE_FACTOR
	end

	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocationOverlap_Callback", self, collisionMask, true, true, true, true)

	-- if debugLoading then 
	--	UniversalAutoload.debugPrint(tostring(self.rootNode) .. " HIT COUNT: " .. tostring(hitCount))
	-- end
	
	if UniversalAutoload.showDebug then
		spec.lastOverlapBox = {
			x = x, y = y, z = z,
			dx = dx, dy = dy, dz = dz,
			rx = rx, ry = ry, rz = rz,
			sizeX = sizeX, sizeY = sizeY, sizeZ = sizeZ,
		}
	end

	return not spec.foundObject
end
--
function UniversalAutoload:ualTestLocationOverlap_Callback(hitObjectId, x, y, z, distance)
	
	if hitObjectId ~= 0 and hitObjectId ~= self.rootNode and getHasClassId(hitObjectId, ClassIds.SHAPE) then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(hitObjectId)

		if object and object ~= self and object ~= spec.currentObject then
			-- UniversalAutoload.debugPrint(object.i3dFilename)
			spec.foundObject = true
		end
	end
end
--
function UniversalAutoload:testLoadAreaIsEmpty()
	local spec = self.spec_universalAutoload
	local i = spec.currentLoadAreaIndex or 1
	
	if not spec.loadArea or #spec.loadArea == 0 then
		return false
	end
	
	if spec.palletsRemovedFromPhysics then
		return false
	end
	
	local sizeX, sizeY, sizeZ = spec.loadArea[i].width/2, spec.loadArea[i].height/2, spec.loadArea[i].length/2
	local x, y, z = UniversalAutoload.localToWorld(spec.loadArea[i].rootNode)
	local rx, ry, rz = UniversalAutoload.getWorldRotation(spec.loadArea[i].rootNode)
	local dx, dy, dz = UniversalAutoload.localDirectionToWorld(spec.loadArea[i].rootNode, 0, sizeY, 0)
	
	spec.foundObject = false
	spec.currentObject = nil

	local collisionMask = UniversalAutoload.MASK.everything
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocationOverlap_Callback", self, collisionMask, true, true, true, true)

	if debugLoading then 
		g_currentMission:addExtraPrintText(" LOADED: " .. tostring(next(spec.loadedObjects) == nil))
		g_currentMission:addExtraPrintText(" IS EMPTY: " .. tostring(not spec.foundObject))
		g_currentMission:addExtraPrintText(" HIT COUNT: " .. tostring(hitCount))
		DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
	end
	
	return not spec.foundObject
end
--
function UniversalAutoload:testUnloadLocationIsEmpty(unloadPlace)

	local spec = self.spec_universalAutoload
	local sizeX, sizeY, sizeZ = unloadPlace.sizeX/2, unloadPlace.sizeY/2, unloadPlace.sizeZ/2
	local x, y, z = UniversalAutoload.localToWorld(unloadPlace.node)
	local rx, ry, rz = UniversalAutoload.getWorldRotation(unloadPlace.node)
	local dx, dy, dz
	if unloadPlace.wasFlippedXY then
		dx, dy, dz = UniversalAutoload.localDirectionToWorld(unloadPlace.node, -sizeY, 0, 0)
	elseif unloadPlace.wasFlippedYZ then
		dx, dy, dz = UniversalAutoload.localDirectionToWorld(unloadPlace.node, 0, 0, -sizeY)
	else
		dx, dy, dz = UniversalAutoload.localDirectionToWorld(unloadPlace.node, 0, sizeY, 0)
	end
	
	spec.hasOverlap = false

	local collisionMask = UniversalAutoload.MASK.everything
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestUnloadLocation_Callback", self, collisionMask, true, true, true, true)
	
	return not spec.hasOverlap
end
--
function UniversalAutoload:ualTestUnloadLocation_Callback(hitObjectId, x, y, z, distance)
	if hitObjectId ~= 0 and hitObjectId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(hitObjectId)
		if object and not spec.loadedObjects[object] then
			if object.spec_objectStorage and object.spec_objectStorage.objectTriggerNode 
			and hitObjectId == object.spec_objectStorage.objectTriggerNode then
				return true
			else
				-- DebugUtil.drawDebugNode(hitObjectId, getName(hitObjectId))
				spec.hasOverlap = true
				return false
			end
		end
	end
	return true
end
--
function UniversalAutoload:testLocation(location, object)
	local spec = self.spec_universalAutoload
	local i = spec.currentLoadAreaIndex or 1
	local r = 0.025
	
	local sizeX, sizeY, sizeZ
	local x, y, z
	local rx, ry, rz
	local dx, dy, dz
	if location == nil then
		if not spec.loadArea or #spec.loadArea == 0 then
			return
		end
		sizeX, sizeY, sizeZ = spec.loadArea[i].width/2, spec.loadArea[i].height/2, spec.loadArea[i].length/2
		x, y, z = UniversalAutoload.localToWorld(spec.loadArea[i].rootNode)
		rx, ry, rz = UniversalAutoload.getWorldRotation(spec.loadArea[i].rootNode)
		dx, dy, dz = UniversalAutoload.localDirectionToWorld(spec.loadArea[i].rootNode, 0, sizeY, 0)
	else
		if not (location.sizeX and location.sizeY and location.sizeZ) then
			return
		end
		sizeX, sizeY, sizeZ = (location.sizeX/2)-r, (location.sizeY/2)-r, (location.sizeZ/2)-r
		x, y, z = UniversalAutoload.localToWorld(location.node)
		rx, ry, rz = UniversalAutoload.getWorldRotation(location.node)
		dx, dy, dz = UniversalAutoload.localDirectionToWorld(location.node) -- no Y offset needed for triggers
	end
	
	spec.target = object
	spec.foundTarget = false
	spec.foundObject = false
		
	local collisionMask = UniversalAutoload.MASK.object
	local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocation_Callback", self, collisionMask, true, true, true, true)

	-- if UniversalAutoload.showDebug then
		-- local FLAGS = {}
		-- for name, value in pairs(CollisionFlag) do
			-- if type(value) == 'number' then
				-- local flag = {}
				-- flag.name = name
				-- flag.value = value
				-- table.insert(FLAGS, flag)
			-- end
		-- end
		-- table.sort(FLAGS, function (a, b) return a.value < b.value end)
	
		-- print(tostring(self:getFullName()))
		-- renderText(0.45, 0.925, 0.015, tostring(self:getFullName()))
	
		-- for i, flag in ipairs(FLAGS) do
			
			-- local collisionMask = flag.value
			-- local hitCount = overlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ, "ualTestLocation_Callback", self, collisionMask, true, true, true, true)
			
			-- print(tostring(flag.name) .. " = " .. tostring(hitCount))
			-- renderText(0.45, 0.92-(i*0.015), 0.010, tostring(flag.name) .. " = " .. tostring(hitCount))
		-- end
	-- end

	if location and UniversalAutoload.showDebug then
		spec.lastOverlapBox = {
			x = x, y = y, z = z,
			dx = dx, dy = dy, dz = dz,
			rx = rx, ry = ry, rz = rz,
			sizeX = sizeX, sizeY = sizeY, sizeZ = sizeZ,
		}
	end

	return spec.foundTarget, spec.foundObject
end
--
function UniversalAutoload:ualTestLocation_Callback(hitObjectId, x, y, z, distance)

	if hitObjectId ~= 0 and getHasClassId(hitObjectId, ClassIds.SHAPE) then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(hitObjectId)

		if object and object ~= self and UniversalAutoload.getIsValidObject(self, object) then
			if debugSpecial then
				if object.isSplitShape then
					UniversalAutoload.debugPrint("  FOUND SPLIT SHAPE")
				else
					UniversalAutoload.debugPrint("  FOUND: " .. tostring(object.i3dFilename))
				end
			end
			spec.foundObject = true
			if spec.target and spec.target == object then
				spec.foundTarget = true
			end
		end
	end
end
--

-- -- OBJECT MOVEMENT FUNCTIONS
function UniversalAutoload.getNodeObject( objectId )
	
	if not entityExists(objectId) then
		UniversalAutoload.debugPrint("object entity NOT exists")
		UniversalAutoload.OBJECTS_LOOKUP[objectId] = nil
		UniversalAutoload.SPLITSHAPES_LOOKUP[objectId] = nil
		return
	end

	return g_currentMission:getNodeObject(objectId) or UniversalAutoload.getSplitShapeObject(objectId)
end
--
function UniversalAutoload.getSplitShapeObject( objectId )

	if not entityExists(objectId) then
		UniversalAutoload.debugPrint("splitshape entity NOT exists")
		UniversalAutoload.SPLITSHAPES_LOOKUP[objectId] = nil
		return
	end
	
	-- UniversalAutoload.debugPrint("RigidBodyType: " .. tostring(getRigidBodyType(objectId)))
	if objectId and getRigidBodyType(objectId) == RigidBodyType.DYNAMIC then
	
		local splitType = g_splitShapeManager:getSplitTypeByIndex(getSplitType(objectId))
		if splitType then

			if UniversalAutoload.SPLITSHAPES_LOOKUP[objectId] == nil then
			
				local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(objectId)
				local xx,xy,xz = UniversalAutoload.localDirectionToWorld(objectId, 1, 0, 0)
				local yx,yy,yz = UniversalAutoload.localDirectionToWorld(objectId, 0, 1, 0)
				local zx,zy,zz = UniversalAutoload.localDirectionToWorld(objectId, 0, 0, 1)
				
				if getChild(objectId, 'positionNode') == 0 then
					local x, y, z = UniversalAutoload.getWorldTranslation(objectId)
					local xBelow, xAbove = getSplitShapePlaneExtents(objectId, x,y,z, xx,xy,xz)
					local yBelow, yAbove = getSplitShapePlaneExtents(objectId, x,y,z, yx,yy,yz)
					local zBelow, zAbove = getSplitShapePlaneExtents(objectId, x,y,z, zx,zy,zz)
					
					local positionNode = createTransformGroup("positionNode")
					link(objectId, positionNode)
					setTranslation(positionNode, (xAbove-xBelow)/2, -yBelow, (zAbove-zBelow)/2)
				end
				
				logObject = {}
				logObject.nodeId = objectId
				logObject.positionNodeId = getChild(objectId, 'positionNode')

				local x, y, z  = UniversalAutoload.getWorldTranslation(logObject.positionNodeId)
				local xBelow, xAbove = getSplitShapePlaneExtents(objectId, x,y,z, xx,xy,xz)
				local yBelow, yAbove = getSplitShapePlaneExtents(objectId, x,y,z, yx,yy,yz)
				local zBelow, zAbove = getSplitShapePlaneExtents(objectId, x,y,z, zx,zy,zz)
				
				logObject.isSplitShape = true
				logObject.sizeX = xBelow + xAbove
				logObject.sizeY = yBelow + yAbove
				logObject.sizeZ = zBelow + zAbove
				logObject.fillType = FillType.WOOD
				
				UniversalAutoload.SPLITSHAPES_LOOKUP[objectId] = logObject
				
			end
			
			return UniversalAutoload.SPLITSHAPES_LOOKUP[objectId]

		end
	end
end
--
--
function UniversalAutoload.getObjectPositionNode( object )
	local node = UniversalAutoload.getObjectRootNode(object)
	if node == nil then
		UniversalAutoload.debugPrint("Object Root Node IS NIL - " .. tostring(object.i3dFilename), debugPallets)
		return nil
	end
	if object.isSplitShape and object.positionNodeId then
		return object.positionNodeId
	else
		return node
	end
end
--
function UniversalAutoload.getObjectRootNode( object )
	local node = nil

	if object.components then
		node = object.components[1].node
	else
		node = object.nodeId
	end
	
	if node == nil or node == 0 or not entityExists(node) then
		return nil
	else
		return node
	end
end
--
function UniversalAutoload.unlinkObject( object )
	local node = UniversalAutoload.getObjectRootNode(object)
	if node then
		local x, y, z = UniversalAutoload.localToWorld(node)
		local rx, ry, rz = UniversalAutoload.getWorldRotation(node)
		link(getRootNode(), node)
		setWorldTranslation(node, x, y, z)
		setWorldRotation(node, rx, ry, rz)
	else
		UniversalAutoload.debugPrint("unlinkObject - node was " .. tostring(node))
	end
end
--
function UniversalAutoload.moveObjectNode( node, p )
	if node then
		if p.x then
			setWorldTranslation(node, p.x, p.y, p.z)
		end
		if p.rx then
			setWorldRotation(node, p.rx, p.ry, p.rz)
		end
	end
end
--
function UniversalAutoload.getPositionNodes( object )
	local nodes = {}
	if object.isSplitShape and object.positionNodeId then
		table.insert(nodes, object.positionNodeId)
	else
		nodes = UniversalAutoload.getRootNodes( object )
	end
	return nodes
end
--
function UniversalAutoload.getRootNodes( object )
	local nodes = {}
	
	if object.components then
		for i = 1, #object.components do
			table.insert(nodes, object.components[i].node)
		end
	else
		table.insert(nodes, object.nodeId)
	end
	return nodes
end
--
function UniversalAutoload.getTransformation( position, nodes )
	local n = {}
	for i = 1, #nodes do
		n[i] = {}
		n[i].x, n[i].y, n[i].z = UniversalAutoload.localToWorld(position.node, 0, position.baleOffset or 0, 0)
		n[i].rx, n[i].ry, n[i].rz = UniversalAutoload.getWorldRotation(position.node)
		if position.flipYZ then
			n[i].rx = n[i].rx + math.pi/2
		end
		if i > 1 then
			local dx, dy, dz = localToLocal(nodes[i], nodes[1], 0, 0, 0)
			n[i].x = n[i].x + dx
			n[i].y = n[i].y + dy
			n[i].z = n[i].z + dz
		end
		n[i].x = n[i].x
		n[i].y = n[i].y
		n[i].z = n[i].z
	end
	return n
end
--
function UniversalAutoload.removeFromPhysics(object)

	if object.isRoundbale ~= nil or object.isSplitShape then
		local node = UniversalAutoload.getObjectRootNode(object)
		if node then
			removeFromPhysics(node)
		end
	elseif object.isAddedToPhysics then
		object:removeFromPhysics()
	end
end
--
function UniversalAutoload:addToPhysics(object)

	if disablePhysicsAfterLoading then
		UniversalAutoload.debugPrint("addToPhysics is DISABLED")
		return
	end
	
	if object.isRoundbale ~= nil or object.isSplitShape then
		local node = UniversalAutoload.getObjectRootNode(object)
		if node then
			addToPhysics(node)
		end
	else
		object:addToPhysics()
	end
	
	local nodes = UniversalAutoload.getRootNodes(object)
	local rootNode = self:getParentComponent(self.rootNode)
	local vx, vy, vz = getLinearVelocity(rootNode)
	for i = 1, #nodes do
		setLinearVelocity(nodes[i], vx or 0, vy or 0, vz or 0)
	end
	if object.raiseActive ~= nil then
		object:raiseActive()
		object.networkTimeInterpolator:reset()
		UniversalAutoload.raiseObjectDirtyFlags(object)
	end
end
--
function UniversalAutoload:addBaleModeBale(node)
	local rootNode = self.spec_universalAutoload.loadVolume.rootNode
	local x, y, z = localToLocal(node, rootNode, 0, 0, 0)
	local rx, ry, rz = localRotationToLocal(node, rootNode, 0, 0, 0)
	
	link(rootNode, node)
	setTranslation(node, x, y, z)
	setRotation(node, rx, ry, rz)
end
--
function UniversalAutoload:moveObjectNodes( object, position, isLoading, rotateLogs )

	local spec = self.spec_universalAutoload
	local rootNodes = UniversalAutoload.getRootNodes(object)
	local node = rootNodes[1]
	if node and node ~= 0 and entityExists(node) then
	
		UniversalAutoload.unmountDynamicMount(object)
		UniversalAutoload.removeFromPhysics(object)

		local n = UniversalAutoload.getTransformation( position, rootNodes )

		-- SPLITSHAPE ROTATION
		if object.isSplitShape then
		
			-- IF OBJECT IS NOT ALREADY LOADED
			if isLoading then
			
				-- if rotateLogs then print("ROTATE") else print("NORMAL") end
			
				local s = rotateLogs and 1 or -1
				local xx,xy,xz = UniversalAutoload.localDirectionToWorld(position.node, s, 0, 0) --length
				local yx,yy,yz = UniversalAutoload.localDirectionToWorld(position.node, 0, 1, 0) --height
				local zx,zy,zz = UniversalAutoload.localDirectionToWorld(position.node, 0, 0, 0) --width
				-- UniversalAutoload.debugPrint(string.format("X %f, %f, %f",xx,xy,xz))
				-- UniversalAutoload.debugPrint(string.format("Y %f, %f, %f",yx,yy,yz))
				-- UniversalAutoload.debugPrint(string.format("Z %f, %f, %f",zx,zy,zz))
			
				local rx, ry, rz = localRotationToWorld(position.node, 0, 0, s*math.pi/2)
				n[1].rx = rx
				n[1].ry = ry
				n[1].rz = rz

				local X = object.sizeY/2
				local Y = object.sizeX/2
				local Z = object.sizeZ/2
				n[1].x = n[1].x + xx*X + yx*Y + zx*Z
				n[1].y = n[1].y + xy*X + yy*Y + zy*Z
				n[1].z = n[1].z + xz*X + yz*Y + zz*Z
			end

		end
		
		-- ROUND BALE ROTATION
		if object.isRoundbale and spec.useHorizontalLoading then
			local rotation = isLoading and math.pi/4 or 0
			local rx,ry,rz = localRotationToWorld(position.node, 0, 0, rotation)
			n[1].rx = rx
			n[1].ry = ry
			n[1].rz = rz
		end
		
		-- SHIPPING CONTAINER ROTATION
		if UniversalAutoload.isShippingContainer(object) and isLoading then
			local rx,ry,rz = localRotationToWorld(position.node, 0, math.pi, 0)
			n[1].rx = rx
			n[1].ry = ry
			n[1].rz = rz
		end
		
		for i = 1, #rootNodes do
			UniversalAutoload.moveObjectNode(rootNodes[i], n[i])
		end
		
		-- SPLITSHAPE TRANSLATION
		if object.isSplitShape then

			local x0, y0, z0 = UniversalAutoload.getWorldTranslation(node)
			local x1, y1, z1 = UniversalAutoload.getWorldTranslation(object.positionNodeId)
			
			local offset = {}
			offset['x'] = x0 - (x1-x0)
			offset['y'] = y0 - (y1-y0)
			offset['z'] = z0 - (z1-z0)

			-- UniversalAutoload.debugPrint(string.format("offset (%f, %f, %f)", offset.x, offset.y, offset.z))
			UniversalAutoload.moveObjectNode(node, offset)

		end

		if spec.autoCollectionMode and spec.baleCollectionActive and object.isRoundbale~=nil then
			UniversalAutoload.addBaleModeBale(self, node)
		else
			UniversalAutoload.addToPhysics(self, object)
		end
		
		return true
	end
end

-- TRIGGER CALLBACK FUNCTIONS
function UniversalAutoload:ualPlayerTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and self.rootNode and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		for _, player in pairs(g_currentMission.players) do
			if otherActorId == player.rootNode then
				
				if g_currentMission.accessHandler:canFarmAccess(player.farmId, self) then
				
					local spec = self.spec_universalAutoload
					local playerId = player.userId
					
					if onEnter then
						UniversalAutoload.updatePlayerTriggerState(self, playerId, true)
						UniversalAutoload.forceRaiseActive(self, true)
					else
						UniversalAutoload.updatePlayerTriggerState(self, playerId, false)
						UniversalAutoload.forceRaiseActive(self, true)
					end

				end
	
			end
		end
	end
end

function UniversalAutoload:ualLoadingTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and self.rootNode and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(otherActorId)
		if object then
			if UniversalAutoload.getIsValidObject(self, object) then
				if onEnter then
					UniversalAutoload.addAvailableObject(self, object)
				elseif onLeave then
					local foundTargetInOtherTrigger = false
					if spec.extendPickupRange then -- not efficient - could store flag for each trigger id
						for _, trigger in pairs(spec.triggers or {}) do
							if trigger.name ~= triggerId and string.find(trigger.name, "PickupTrigger") then
								local foundTarget, _ = UniversalAutoload.testLocation(self, trigger, object)
								if foundTarget then
									foundTargetInOtherTrigger = true
									break
								end
							end
						end
					end
					if not foundTargetInOtherTrigger then
						UniversalAutoload.removeAvailableObject(self, object)
						-- ADD AS LOADED ONLY WHEN OBJECT MOVES ONTO TRAILER
						local isAlreadyLoaded = spec.loadedObjects[object] ~= nil
						if not isAlreadyLoaded then
							local trigger = spec.triggers["unloadingTrigger"]
							local foundTarget, _ = UniversalAutoload.testLocation(self, trigger, object)
							if foundTarget then
								UniversalAutoload.addLoadedObject(self, object)
							end
						end
					end
				end
			end
		end
	end
end
--
function UniversalAutoload:ualUnloadingTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and self.rootNode and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(otherActorId)
		if object then
			if UniversalAutoload.getIsValidObject(self, object) then
				if onEnter then
					
					-- DON'T ADD AS LOADED IF OBJECT INTERSECTS WITH BOTH TRIGGERS
					local isPartiallyLoaded = spec.availableObjects[object] ~= nil
					if not isPartiallyLoaded then
						for _, trigger in pairs(spec.triggers or {}) do
							if string.find(trigger.name, "PickupTrigger") then
								local foundTarget, _ = UniversalAutoload.testLocation(self, trigger, object)
								if foundTarget then
									isPartiallyLoaded = true
									break
								end
							end
						end
						if not isPartiallyLoaded then
							UniversalAutoload.addLoadedObject(self, object)
						end
					end
					
				elseif onLeave then
					UniversalAutoload.removeLoadedObject(self, object)
					
					-- ADD AS AVAILABLE ONLY WHEN OBJECT MOVES FROM TRAILER
					local isAlreadyAvaialble = spec.availableObjects[object] ~= nil
					if not isAlreadyAvaialble then
						for _, trigger in pairs(spec.triggers or {}) do
							if string.find(trigger.name, "PickupTrigger") then
								local foundTarget, _ = UniversalAutoload.testLocation(self, trigger, object)
								if foundTarget then
									UniversalAutoload.addAvailableObject(self, object)
									break
								end
							end
						end
					end
					
				end
			end
		end
	end
end
--
function UniversalAutoload:ualAutoLoadingTrigger_Callback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self and self.rootNode and otherActorId ~= 0 and otherActorId ~= self.rootNode then
		local spec = self.spec_universalAutoload
		local object = UniversalAutoload.getNodeObject(otherActorId)
		if object then
			if UniversalAutoload.getIsValidObject(self, object) then
				if onEnter then
					UniversalAutoload.debugPrint(" AutoLoadingTrigger ENTER: " .. tostring(object.id), debugLoading)
					UniversalAutoload.addAutoLoadingObject(self, object)
				elseif onLeave then
					UniversalAutoload.debugPrint(" AutoLoadingTrigger LEAVE: " .. tostring(object.id), debugLoading)
					UniversalAutoload.removeAutoLoadingObject(self, object)
				end
			end
		end
	end
end

function UniversalAutoload:addLoadedObject(object)
	local spec = self.spec_universalAutoload
	
	if spec.loadedObjects[object] == nil and (not UniversalAutoload.isValidForManualLoading(object)
	or (object.isSplitShape and spec.autoLoadingObjects[object] == nil)) then
		spec.loadedObjects[object] = spec.currentLoadAreaIndex or 1
		spec.totalUnloadCount = spec.totalUnloadCount + 1
		if object.addDeleteListener then
			object:addDeleteListener(self, "ualOnDeleteLoadedObject_Callback")
		end
		UniversalAutoload.debugPrint("ADD Loaded Object: " .. tostring(object.id), debugLoading)
		return true
	end
end
--
function UniversalAutoload:removeLoadedObject(object)
	local spec = self.spec_universalAutoload
	if spec.loadedObjects[object] then
		spec.loadedObjects[object] = nil
		spec.totalUnloadCount = spec.totalUnloadCount - 1
		if object.removeDeleteListener then
			object:removeDeleteListener(self, "ualOnDeleteLoadedObject_Callback")
		end
		if next(spec.loadedObjects) == nil then
			UniversalAutoload.debugPrint("FULLY UNLOADED - RESET LOADING AREA")
			UniversalAutoload.resetLoadingArea(self)
		else
			spec.partiallyUnloaded = true
		end
		UniversalAutoload.debugPrint("REMOVE Loaded Object: " .. tostring(object.id), debugLoading)
		return true
	end
end

function UniversalAutoload:ualOnDeleteLoadedObject_Callback(object)
	UniversalAutoload.removeLoadedObject(self, object)
end
--
function UniversalAutoload:addAvailableObject(object)
	local spec = self.spec_universalAutoload
	
	if object and spec.availableObjects[object] == nil and spec.loadedObjects[object] == nil then
		spec.availableObjects[object] = object
		spec.totalAvailableCount = spec.totalAvailableCount + 1
		if object.isRoundbale ~= nil then
			spec.availableBaleCount = spec.availableBaleCount + 1
		end
		if object.addDeleteListener then
			object:addDeleteListener(self, "ualOnDeleteAvailableObject_Callback")
		end
				
		if spec.autoCollectionMode and spec.baleCollectionActive == nil then
			if object.isRoundbale ~= nil and not spec.isLogTrailer then
				UniversalAutoload.debugPrint("FOUND A BALE - set bale collection mode")
				spec.baleCollectionActive = true
			else
				UniversalAutoload.debugPrint("FOUND A PALLET/LOG - set collection mode")
				spec.baleCollectionActive = false
			end
		end
		
		if spec.isLoading and UniversalAutoload.isValidForLoading(self, object) then
			table.insert(spec.sortedObjectsToLoad, object)
			UniversalAutoload.raiseObjectDirtyFlags(object)
		end
		
		return true
	end
end
--
function UniversalAutoload:removeAvailableObject(object)
	local spec = self.spec_universalAutoload
	local isActiveForLoading = spec.isLoading or spec.isUnloading or spec.doPostLoadDelay
	
	if object and spec.availableObjects[object] then
		spec.availableObjects[object] = nil
		spec.totalAvailableCount = spec.totalAvailableCount - 1
		if object.isRoundbale ~= nil then
			spec.availableBaleCount = spec.availableBaleCount - 1
		end
		if object.removeDeleteListener then
			object:removeDeleteListener(self, "ualOnDeleteAvailableObject_Callback")
		end
		
		if spec.totalAvailableCount == 0 and not isActiveForLoading then
			-- UniversalAutoload.debugPrint("RESETTING MATERIAL AND CONTAINER SELECTIONS")
			if spec.currentMaterialIndex ~= 1 then
				UniversalAutoload.setMaterialTypeIndex(self, 1)
			end
			if spec.currentContainerIndex ~= 1 then
				UniversalAutoload.setContainerTypeIndex(self, 1)
			end
		end
		return true
	end
end
--
function UniversalAutoload:removeFromSortedObjectsToLoad(object)
	local spec = self.spec_universalAutoload
	
	if spec.sortedObjectsToLoad then
		for index, sortedobject in ipairs(spec.sortedObjectsToLoad or {}) do
			if object == sortedobject then
				table.remove(spec.sortedObjectsToLoad, index)
				return true
			end
		end
	end
end
--
function UniversalAutoload:ualOnDeleteAvailableObject_Callback(object)
	UniversalAutoload.removeAvailableObject(self, object)
	UniversalAutoload.removeFromSortedObjectsToLoad(self, object)
end
--
function UniversalAutoload:addAutoLoadingObject(object)
	local spec = self.spec_universalAutoload
	
	if UniversalAutoload.isShippingContainer(object) then
		return false
	end

	if UniversalAutoload.isValidForManualLoading(object) or (object.isSplitShape and self.isLogTrailer) then
		if spec.autoLoadingObjects[object] == nil and spec.loadedObjects[object] == nil then
			spec.autoLoadingObjects[object] = object
			if object.addDeleteListener then
				object:addDeleteListener(self, "ualOnDeleteAutoLoadingObject_Callback")
			end
			local pickedUpObject = UniversalAutoload.getObjectRootNode(object)
			-- HandToolHands.getIsHoldingItem() ??
			-- if pickedUpObject and Player.PICKED_UP_OBJECTS[pickedUpObject] == true then
				-- for _, player in pairs(g_currentMission.players) do
					-- if player.isCarryingObject and player.pickedUpObject == pickedUpObject then
						-- player:pickUpObject(false)
						-- UniversalAutoload.debugPrint("*** DROP OBJECT ***", debugSpecial)
					-- end
				-- end
			-- end
			return true
		end
	end
end
--
function UniversalAutoload:removeAutoLoadingObject(object)
	local spec = self.spec_universalAutoload
	
	if spec.autoLoadingObjects[object] then
		spec.autoLoadingObjects[object] = nil
		if object.removeDeleteListener then
			object:removeDeleteListener(self, "ualOnDeleteAutoLoadingObject_Callback")
		end
		return true
	end
end
--
function UniversalAutoload:ualOnDeleteAutoLoadingObject_Callback(object)
	UniversalAutoload.removeAutoLoadingObject(self, object)
end
--
function UniversalAutoload:removeSplitShapeObject(object)
	UniversalAutoload.removeLoadedObject(self, object)
	UniversalAutoload.removeAvailableObject(self, object)
	UniversalAutoload.removeFromSortedObjectsToLoad(self, object)
	UniversalAutoload.removeAutoLoadingObject(self, object)
	UniversalAutoload.SPLITSHAPES_LOOKUP[object.nodeId] = nil
end
--
function UniversalAutoload:createPallet(xmlFilename)
	local spec = self.spec_universalAutoload
	spec.spawningPallet = xmlFilename

	local function asyncCallbackFunction(_, pallets, palletLoadState, arguments)
		if palletLoadState == VehicleLoadingState.OK then
			local pallet = pallets[1]
			
			local fillTypeIndex = pallet:getFillUnitFirstSupportedFillType(1)
			pallet:addFillUnitFillLevel(1, 1, math.huge, fillTypeIndex, ToolType.UNDEFINED, nil)
			
			spec.spawningPallet = nil
			spec.spawnedPallet = pallet
			return
		end
	end

	local x, y, z = UniversalAutoload.getWorldTranslation(spec.loadVolume.rootNode)
    local farmId = g_currentMission:getFarmId()
	farmId = farmId ~= FarmManager.SPECTATOR_FARM_ID and farmId or 1

    local data = VehicleLoadingData.new()
    data:setFilename(xmlFilename)
    data:setPosition(x, y + 10, z)
    data:setPropertyState(VehiclePropertyState.OWNED)
    data:setOwnerFarmId(farmId)
	
    data:load(asyncCallbackFunction)
	
end
--
function UniversalAutoload:createPallets(pallets)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		if spec.isLogTrailer then
			UniversalAutoload.debugPrint("Log trailer - cannot load pallets")
			return false
		end
		UniversalAutoload.debugPrint("ADD PALLETS: " .. self:getFullName(), debugConsole)
		UniversalAutoload.setMaterialTypeIndex(self, 1)
		UniversalAutoload.setAutoCollectionMode(self, false)
		if palletsOnly then
			UniversalAutoload.setContainerTypeIndex(self, 2)
		else
			UniversalAutoload.setContainerTypeIndex(self, 1)
		end
		UniversalAutoload.clearLoadedObjects(self)
		self:setAllTensionBeltsActive(false)
		spec.spawnPallets = true
		spec.palletsToSpawn = {}

		for _, pallet in pairs(pallets) do
			table.insert(spec.palletsToSpawn, pallet)
		end
		return true
	end
end
--
function UniversalAutoload:createLog(length, treeType, growthState)
	local spec = self.spec_universalAutoload
	
	if UniversalAutoload.spawningLog then
		return nil
	end
	
	UniversalAutoload.spawningLog = true

	local x, y, z = UniversalAutoload.getWorldTranslation(spec.loadVolume.rootNode)
	dirX, dirY, dirZ = UniversalAutoload.localDirectionToWorld(spec.loadVolume.rootNode, 0, 0, 1)
	y = y + 20

	local length = tonumber(length)
	local usage = "gsTreeAdd length [type (available: " .. table.concatKeys(g_treePlantManager.nameToTreeType, " ") .. ")] [growthState] [delimb true/false]"
	if length == nil then
		print("No length given")
		return
	end
	if treeType == nil then
		treeType = "beech"
		growthState = 7
	end
	local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromName(treeType)
	if treeTypeDesc == nil then
		print("Invalid tree type: " .. tostring(treeType))
		return
	end
	local growthState = tonumber(growthState) or #treeTypeDesc.stages
	local growthStateI = math.clamp(growthState, 1, #treeTypeDesc.stages)
	local variationIndex = math.random(1, #treeTypeDesc.stages[growthStateI])
	
	local treeId, splitShapeFileId = g_treePlantManager:loadTreeNode(treeTypeDesc, x, y, z, 0, 0, 0, growthStateI, variationIndex)
	if treeId ~= 0 then
		if getFileIdHasSplitShapes(splitShapeFileId) then
			local tree = {
				["node"] = treeId,
				["growthStateI"] = growthStateI,
				["variationIndex"] = variationIndex,
				["x"] = x,
				["y"] = y,
				["z"] = z,
				["rx"] = 0,
				["ry"] = 0,
				["rz"] = 0,
				["treeType"] = treeTypeDesc.index,
				["splitShapeFileId"] = splitShapeFileId,
				["hasSplitShapes"] = true
			}
			local splitTrees = g_treePlantManager.treesData.splitTrees
			table.insert(splitTrees, tree)
			
			local loadTreeTrunkData = {
				["framesLeft"] = 2,
				["shape"] = treeId + 2,
				["x"] = x,
				["y"] = y,
				["z"] = z,
				["length"] = length,
				["offset"] = 0.5,
				["dirX"] = dirX,
				["dirY"] = dirY,
				["dirZ"] = dirZ,
				["delimb"] = true,
				["useOnlyStump"] = nil,
				["cutTreeTrunkCallback"] = TreePlantManager.cutTreeTrunkCallback
			}
			local loadTreeTrunkDatas = g_treePlantManager.loadTreeTrunkDatas
			table.insert(loadTreeTrunkDatas, loadTreeTrunkData)
			
			return treeId + 2
		end
		delete(treeId)
	end
end
--
function UniversalAutoload:createLogs(length, treeType, growthState)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		UniversalAutoload.debugPrint("ADD LOGS: " .. self:getFullName(), debugConsole)
		UniversalAutoload.setMaterialTypeIndex(self, 1)
		UniversalAutoload.setAutoCollectionMode(self, false)
		UniversalAutoload.setContainerTypeIndex(self, 1)
		UniversalAutoload.clearLoadedObjects(self)		
		self:setAllTensionBeltsActive(false)
		spec.spawnLogs = true
		spec.logToSpawn = {
			length = length,
			treeType = treeType,
			growthState = growthState,
		}
		return true
	end
end
--
function UniversalAutoload:createBale(xmlFilename, fillTypeIndex, wrapState)
	local spec = self.spec_universalAutoload

	local x, y, z = UniversalAutoload.getWorldTranslation(spec.loadVolume.rootNode)
	y = y + 10

	local farmId = g_currentMission:getFarmId()
	farmId = farmId ~= FarmManager.SPECTATOR_FARM_ID and farmId or 1
	local baleObject = Bale.new(g_currentMission:getIsServer(), g_currentMission:getIsClient())
	
	if baleObject:loadFromConfigXML(xmlFilename, x, y, z, 0, 0, 0) then
		baleObject:setFillType(fillTypeIndex, true)
		baleObject:setWrappingState(wrapState)
		baleObject:setOwnerFarmId(farmId, true)
		baleObject:register()
		return baleObject
	end
end
--
function UniversalAutoload:createBales(bale)
	local spec = self.spec_universalAutoload
	
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		if spec.isLogTrailer then
			print("Log trailer - cannot load bales")
			return false
		end
		UniversalAutoload.debugPrint("ADD BALES: " .. self:getFullName(), debugConsole)
		UniversalAutoload.clearLoadedObjects(self)
		UniversalAutoload.setMaterialTypeIndex(self, 1)
		UniversalAutoload.setContainerTypeIndex(self, 1)
		self:setAllTensionBeltsActive(false)
		spec.spawnBales = true
		spec.baleToSpawn = bale
		return true
	end
end
--
function UniversalAutoload:clearLoadedObjects()
	local spec = self.spec_universalAutoload
	local palletCount, balesCount, logCount = 0, 0, 0
	
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled and spec.loadedObjects then
		UniversalAutoload.debugPrint("CLEAR OBJECTS: " .. self:getFullName(), debugLoading or debugConsole)
		self:setAllTensionBeltsActive(false)
		for object, _ in pairs(spec.loadedObjects or {}) do
			if object.isSplitShape then
				UniversalAutoload.removeSplitShapeObject(self, object)
				g_currentMission:removeKnownSplitShape(object.nodeId)
				if entityExists(object.nodeId) then
					delete(object.nodeId)
				end
				logCount = logCount + 1
			elseif object.isRoundbale == nil then
				-- g_currentMission.vehicleSystem:removeVehicle(object, true)
				object:delete()
				palletCount = palletCount + 1
			else
				object:delete()
				balesCount = balesCount + 1
			end
		end
		spec.loadedObjects = {}
		spec.totalUnloadCount = 0
		UniversalAutoload.resetLoadingArea(self)
	end
	return palletCount, balesCount, logCount
end
--
function UniversalAutoload:togglePhysicsForLoadedObjects(force)
	local spec = self.spec_universalAutoload
	local objectCount = 0
	
	local removedFromPhysics = spec.palletsRemovedFromPhysics or false
	local beltState = self.spec_tensionBelts.areAllBeltsFastened
	if beltState == removedFromPhysics and not force then
		return
	end
	
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled and spec.loadedObjects then
		for object, _ in pairs(spec.loadedObjects or {}) do
			if not object.spec_bigBag then
				if removedFromPhysics then
					UniversalAutoload.unlinkObject(object)
					UniversalAutoload.addToPhysics(self, object)
				else
					if UniversalAutoload.removePhysics then
						UniversalAutoload.unmountDynamicMount(object)
						UniversalAutoload.removeFromPhysics(object)
						local node = UniversalAutoload.getObjectRootNode(object)
						UniversalAutoload.addBaleModeBale(self, node)
					end
				end
				objectCount = objectCount + 1
			end
		end
	end
	
	spec.palletsRemovedFromPhysics = UniversalAutoload.removePhysics and not removedFromPhysics
	-- print("palletsRemovedFromPhysics: " .. tostring(spec.palletsRemovedFromPhysics))
	return objectCount
end

-- PALLET IDENTIFICATION AND SELECTION FUNCTIONS
function UniversalAutoload.getObjectNameFromI3d(i3d_path)

	if i3d_path == nil then
		return
	end
	
	local i3d_name = i3d_path:match("[^/]*.i3d$")
	return i3d_name:sub(0, #i3d_name - 4)
end
--
function UniversalAutoload.getObjectNameFromXml(xml_path)

	if xml_path == nil then
		return
	end
	
	local xml_name = xml_path:match("[^/]*.xml$")
	return xml_name:sub(0, #xml_name - 4)
end
--
function UniversalAutoload.getEnvironmentNameFromPath(i3d_path)

	if i3d_path == nil then
		return
	end
	
	local customEnvironment = nil
	if i3d_path:find(g_modsDirectory, 1, true) then
		local temp = i3d_path:sub(#g_modsDirectory + 1)
		customEnvironment, _ = temp:match( "^(.-)/(.+)$" )
	else
		for i = 1, #g_dlcsDirectories do
			local dlcsDirectory = g_dlcsDirectories[i].path
			if dlcsDirectory:find(":") and i3d_path:find(dlcsDirectory, 1, true) then
				local temp = i3d_path:sub(#dlcsDirectory + 1)
				customEnvironment, _ = "pdlc_"..temp:match( "^(.-)/(.+)$" )
			end
		end
	end
	return customEnvironment
end
--
function UniversalAutoload.getContainerTypeName(object)
	local containerType = UniversalAutoload.getContainerType(object)
	return containerType and containerType.type or "NONE"
end
--
function UniversalAutoload.getContainerType(object)

	if object == nil or object.isAddedToPhysics == false then
		-- UniversalAutoload.debugPrint("getContainerType requires an object")
		return nil
	end

	if object.isSplitShape then 
		
		if object.ualConfiguration == nil then
			UniversalAutoload.debugPrint("*** UNIVERSAL AUTOLOAD - FOUND NEW SPLITSHAPE [" .. tostring(object.nodeId) .. "] ***")	
			-- DebugUtil.printTableRecursively(object, "--", 0, 1)
			
			-- UniversalAutoload.debugPrint("POS:", UniversalAutoload.localToWorld(object.nodeId, 0, 0, 0))
			-- UniversalAutoload.debugPrint("ROT:", UniversalAutoload.getWorldRotation(object.nodeId, 0, 0, 0))
			
			-- local boundingBox = BoundingBox.new(object)
			-- --UniversalAutoload.debugPrint("SPLITSHAPE boundingBox:")
			-- local size = boundingBox:getSize()
			-- local offset = boundingBox:getOffset()
			-- local rootNode = boundingBox:getRootNode()
			--DebugUtil.printTableRecursively(size or {}, "  ", 0, 1)
			--DebugUtil.printTableRecursively(offset or {}, "  ", 0, 1)
			--DebugUtil.printTableRecursively(object or {}, "  ", 0, 1)
			
			if sizeX==0 or sizeY==0 or sizeZ==0 then
				UniversalAutoload.INVALID_SPLITSHAPES = UniversalAutoload.INVALID_SPLITSHAPES or {}
				if UniversalAutoload.INVALID_SPLITSHAPES[object.nodeId] == nil then
					UniversalAutoload.debugPrint("ZERO SIZE SPLITSHAPE " .. tostring(object.nodeId))
					UniversalAutoload.INVALID_SPLITSHAPES[object.nodeId] = object
					-- DebugUtil.printTableRecursively(object, "--", 0, 1)
				end
				return nil
			end

			local splitShape = {}
			for k, v in pairs(object) do
				splitShape[k] = v
			end
			
			splitShape.type = "LOGS"
			splitShape.name = "splitShape"
			splitShape.containerIndex = UniversalAutoload.CONTAINERS_LOOKUP["LOGS"] or 1

			splitShape.sizeX = object.sizeY
			splitShape.sizeY = object.sizeX
			splitShape.sizeZ = object.sizeZ
			
			splitShape.offset = {x=0, y=0, z=0}
			splitShape.isBale = false
			splitShape.isRoundbale = false
			splitShape.flipXY = true
			splitShape.flipYZ = false
			splitShape.neverStack = false
			splitShape.neverRotate = false
			splitShape.alwaysRotate = true
			splitShape.width = math.min(splitShape.sizeX, splitShape.sizeZ)
			splitShape.length = math.max(splitShape.sizeX, splitShape.sizeZ)

			object.ualConfiguration = splitShape
		end
		
		return object.ualConfiguration
	end

	local name = object.i3dFilename or object.configFileName or object.xmlFilename
	if name == nil then
		UniversalAutoload.debugPrint("UAL getContainerType - could not identify object")
		return nil
	end

	local objectType = UniversalAutoload.LOADING_TYPES[name]
	UniversalAutoload.OBJECTS_LOOKUP = UniversalAutoload.OBJECTS_LOOKUP or {}
	UniversalAutoload.INVALID_OBJECTS = UniversalAutoload.INVALID_OBJECTS or {}

	local itemIsFull = UniversalAutoload.getPalletIsFull(object)
	UniversalAutoload.PARTIAL_OBJECTS = UniversalAutoload.PARTIAL_OBJECTS or {}
	UniversalAutoload.OBJECT_FILL_LEVEL = UniversalAutoload.OBJECT_FILL_LEVEL or {}
	UniversalAutoload.CONTAINER_FOLD_STATE = UniversalAutoload.CONTAINER_FOLD_STATE or {}
	
	local shouldUpdateSize = objectType == nil and not UniversalAutoload.INVALID_OBJECTS[name]
	
	if UniversalAutoload.isShippingContainer(object) then
		local newFoldState = object:getIsUnfolded()
		local oldFoldState = UniversalAutoload.CONTAINER_FOLD_STATE[object]
		if (oldFoldState == nil) or oldFoldState ~= newFoldState then
			UniversalAutoload.CONTAINER_FOLD_STATE[object] = newFoldState
			shouldUpdateSize = true
		else
			return UniversalAutoload.OBJECTS_LOOKUP[object]
		end
	elseif itemIsFull == false then
		local oldFillLevel = UniversalAutoload.OBJECT_FILL_LEVEL[object]
		local newFillLevel = UniversalAutoload.getPalletFillLevel(object)
		if not oldFillLevel or oldFillLevel ~= newFillLevel then
			UniversalAutoload.OBJECT_FILL_LEVEL[object] = newFillLevel
			shouldUpdateSize = true
		else
			return UniversalAutoload.PARTIAL_OBJECTS[object]
		end
	end
	
	if shouldUpdateSize then

		local size = nil
		local offset = nil
				
		local isBale = object.isRoundbale ~= nil
		local isRoundbale = object.isRoundbale == true
		local isPallet = object.specializationsByName
					 and object.specializationsByName.pallet
					 and object.specializationsByName.fillUnit
					 and object.specializationsByName.tensionBeltObject
		
		if isPallet or isBale then
			local objectIsInitialised = (isPallet and object.updateLoopIndex > 0) or true
			if objectIsInitialised then
				
				local boundingBox = BoundingBox.new(object)
				size = boundingBox:getSize()
				offset = boundingBox:getOffset()
				
				if not size or size.x==0 or size.y==0 or size.z==0 then
					UniversalAutoload.debugPrint("*** UNIVERSAL AUTOLOAD - ZERO SIZE OBJECT: ".. tostring(name).." ***")
					-- UniversalAutoload.INVALID_OBJECTS[name] = true
					return nil
				else
					if debugPallets then
						UniversalAutoload.debugPrint("*** UNIVERSAL AUTOLOAD - FOUND NEW OBJECT TYPE: ".. tostring(name).." ***")
						if UniversalAutoload.OBJECT_FILL_LEVEL[object] then
							UniversalAutoload.debugPrint("  PARTIAL FILL LEVEL: " .. tostring(UniversalAutoload.OBJECT_FILL_LEVEL[object]))
						end
						if isPallet then
							UniversalAutoload.debugPrint("Pallet")
							UniversalAutoload.debugPrint("  width: " .. tostring(object.size.width))
							UniversalAutoload.debugPrint("  height: " .. tostring(object.size.height))
							UniversalAutoload.debugPrint("  length: " .. tostring(object.size.length))
						elseif isBale then
							if isRoundbale then
								UniversalAutoload.debugPrint("Round Bale")
								UniversalAutoload.debugPrint("  width: " .. tostring(object.width))
								UniversalAutoload.debugPrint("  height: " .. tostring(object.diameter))
								UniversalAutoload.debugPrint("  length: " .. tostring(object.diameter))
							else
								UniversalAutoload.debugPrint("Square Bale")
								UniversalAutoload.debugPrint("  width: " .. tostring(object.width))
								UniversalAutoload.debugPrint("  height: " .. tostring(object.height))
								UniversalAutoload.debugPrint("  length: " .. tostring(object.length))
							end
						end
						UniversalAutoload.debugPrint("  size X: " .. tostring(size.x))
						UniversalAutoload.debugPrint("  size Y: " .. tostring(size.y))
						UniversalAutoload.debugPrint("  size Z: " .. tostring(size.z))
						UniversalAutoload.debugPrint("  offset X: " .. tostring(offset.x))
						UniversalAutoload.debugPrint("  offset Y: " .. tostring(offset.y))
						UniversalAutoload.debugPrint("  offset Z: " .. tostring(offset.z))
					end
				end

			else
				-- UniversalAutoload.debugPrint("*** UNIVERSAL AUTOLOAD - OBJECT NOT INITIALISED: ".. tostring(name) .." ***")
				-- if object.size then
					-- size = {x=object.size.width, y=object.size.height, z=object.size.length}
				-- elseif isBale then
					-- if isRoundbale then
						-- size = {x=object.width, y=object.diameter, z=object.diameter}
					-- else
						-- size = {x=object.width, y=object.height, z=object.length}
					-- end
				-- end
				-- DebugUtil.printTableRecursively(object or {}, "  ", 0, 1)
				return nil
			end

			local storeItem = object.loadCallbackFunctionTarget and object.loadCallbackFunctionTarget.storeItem
			local category = (storeItem and storeItem.categoryName) or "unknown"
			-- DebugUtil.printTableRecursively(storeItem or {}, "  ", 0, 1)
	
			local nameUpper = tostring(name):upper()
			local containerType = UniversalAutoload.ALL
			
			if isBale or category == "BALES" then containerType = "BALE"
			elseif category == "IBC" then containerType = "LIQUID_TANK"
			elseif category == "BIGBAGS" then containerType = "BIGBAG"
			elseif category == "PALLETS" then containerType = "EURO_PALLET"
			elseif category == "BIGBAGPALLETS" then containerType = "BIGBAG_PALLET"
			elseif string.find(nameUpper, "IBC") then containerType = "LIQUID_TANK"
			elseif string.find(nameUpper, "LIQUIDTANK") then containerType = "LIQUID_TANK" 
			elseif string.find(nameUpper, "BIGBAG") then containerType = "BIGBAG"
			elseif string.find(nameUpper, "PALLET") then containerType = "EURO_PALLET"
			end

			local containerIndex = UniversalAutoload.CONTAINERS_LOOKUP[containerType] or 1
			local shouldNeverStack = (containerType == "BIGBAG") or (object.spec_treeSaplingPallet ~= nil)

			newType = {}
			newType.name = name
			newType.type = containerType
			newType.containerIndex = containerIndex
			newType.sizeX = size.x
			newType.sizeY = size.y
			newType.sizeZ = size.z
			newType.offset = offset or {x=0, y=0, z=0}
			newType.isBale = isBale
			newType.isRoundbale = isRoundbale
			newType.flipYZ = false
			newType.neverStack = shouldNeverStack or false
			newType.neverRotate = false
			newType.alwaysRotate = false
			
			if containerType == "BIGBAG" then
				newType.sizeX = size.x + UniversalAutoload.BIGBAG_SPACING
				newType.sizeZ = size.z + UniversalAutoload.BIGBAG_SPACING
			end
			if UniversalAutoload.getMaterialTypeName(object) == "PREFABWALL" then
				newType.sizeX = size.x + UniversalAutoload.BIGBAG_SPACING/2
				newType.sizeZ = size.z + UniversalAutoload.BIGBAG_SPACING
			end
			
			if isRoundbale == true then
				-- UniversalAutoload.debugPrint("Round Bale flipYZ")
				newType.flipYZ = true
				newType.sizeY = size.z
				newType.sizeZ = size.y
			end
			
			if isPallet then
				newType.offset.y = -((size.y/2) - newType.offset.y)
			end
			
			newType.width = math.min(newType.sizeX, newType.sizeZ)
			newType.length = math.max(newType.sizeX, newType.sizeZ)
			
			if objectIsInitialised and itemIsFull and not UniversalAutoload.isShippingContainer(object) then
				UniversalAutoload.debugPrint(string.format("  >> %s [%.3f, %.3f, %.3f] - %s", newType.name,
					newType.sizeX, newType.sizeY, newType.sizeZ, containerType ))
				
				UniversalAutoload.LOADING_TYPES[name] = newType
				objectType = UniversalAutoload.LOADING_TYPES[name]
			else
				if itemIsFull == false then
					UniversalAutoload.PARTIAL_OBJECTS[object] = newType
				end
				UniversalAutoload.OBJECTS_LOOKUP[object] = newType
				return newType
			end
			
		else
			-- UniversalAutoload.debugPrint("*** UNIVERSAL AUTOLOAD - FOUND NEW OBJECT TYPE: ".. tostring(name) .." ***")
			-- UniversalAutoload.debugPrint("...new object type was not valid")
			UniversalAutoload.INVALID_OBJECTS[name] = true
		end
		-- DebugUtil.printTableRecursively(object or {}, "--", 0, 1)
	end
	
	return objectType
end
--
function UniversalAutoload.getContainerDimensions(object, doFlip)
	local containerType = UniversalAutoload.getContainerType(object)
	UniversalAutoload.getContainerTypeDimensions(containerType, doFlip)
end
--
function UniversalAutoload.getContainerTypeDimensions(containerType, doFlip)
	if containerType then
		local w, h, l = containerType.sizeX, containerType.sizeY, containerType.sizeZ

		if doFlip and containerType.flipXY then
			w, h = containerType.sizeY, containerType.sizeX
		end
		if doFlip and containerType.flipYZ then
			l, h = containerType.sizeY, containerType.sizeZ
		end
		return w+UniversalAutoload.objectSpacing, h+UniversalAutoload.objectSpacing, l+UniversalAutoload.objectSpacing
	end
end
--
function UniversalAutoload.getContainerMass(object)
	local mass = 1
	if object then
		if object.getTotalMass == nil then
			if object.getMass then
				-- UniversalAutoload.debugPrint("GET BALE MASS")
				mass = object:getMass()
			else
				-- UniversalAutoload.debugPrint("GET SPLITSHAPE MASS")
				if entityExists(object.nodeId) then
					mass = getMass(object.nodeId)
				end
			end
		else
			-- UniversalAutoload.debugPrint("GET OBJECT MASS")
			mass = object:getTotalMass()
		end
	end
	return mass
end
--
function UniversalAutoload.getMaterialType(object)
	if object then
		if object.fillType then
			return object.fillType
		elseif object.spec_fillUnit and next(object.spec_fillUnit.fillUnits) then
			return object.spec_fillUnit.fillUnits[1].fillType
		-- elseif object.spec_umbilicalReelOverload then
			-- return g_fillTypeManager:getFillTypeIndexByName("UMBILICAL_HOSE")
		end
	end
end
--
function UniversalAutoload.getMaterialTypeName(object)
	local fillUnitIndex = UniversalAutoload.getMaterialType(object)
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnitIndex)
	if fillTypeName == nil or fillTypeName == "UNKNOWN" then
		fillTypeName = UniversalAutoload.ALL
	end
	return fillTypeName
end
--
function UniversalAutoload:getSelectedContainerType()
	local spec = self.spec_universalAutoload
	return UniversalAutoload.CONTAINERS[spec.currentContainerIndex]
end
--
function UniversalAutoload:getSelectedContainerText()
	local selectedContainerType = UniversalAutoload.getSelectedContainerType(self)
	
	return g_i18n:getText("universalAutoload_" .. tostring(selectedContainerType))
end
--
function UniversalAutoload:getSelectedMaterialType()
	local spec = self.spec_universalAutoload
	return UniversalAutoload.MATERIALS[spec.currentMaterialIndex] or 1
end
--
function UniversalAutoload:getSelectedMaterialText()
	local materialType = UniversalAutoload.getSelectedMaterialType(self)
	local materialIndex = UniversalAutoload.MATERIALS_INDEX[materialType]
	local fillType = UniversalAutoload.MATERIALS_FILLTYPE[materialIndex]
	return fillType.title
end
--
function UniversalAutoload:getPalletIsSelectedLoadside(object)
	local spec = self.spec_universalAutoload
	
	if spec.currentLoadside == "both" then
		return true
	end
	
	if spec.rearUnloadingOnly and spec.currentLoadside == "rear" then
		return true
	end
	
	if spec.frontUnloadingOnly and spec.currentLoadside == "front" then
		return true
	end
	
	if spec.availableObjects[object] == nil then
		return true
	end

	local node = UniversalAutoload.getObjectPositionNode(object)
	if node == nil then
		return false
	end
	
	if self.rootNode==nil or g_currentMission.nodeToObject[self.rootNode]==nil then
		return false
	end
	
	local x, y, z = localToLocal(node, spec.loadVolume.rootNode, 0, 0, 0)
	if ( x > 0 and spec.currentLoadside == "left") or 
	   ( x < 0 and spec.currentLoadside == "right") then
		return true
	else
		return false
	end
end
--
function UniversalAutoload:getPalletIsSelectedMaterial(object)

	local objectMaterialType = UniversalAutoload.getMaterialTypeName(object)
	local selectedMaterialType = UniversalAutoload.getSelectedMaterialType(self)

	if objectMaterialType~=nil and selectedMaterialType~=nil then
		if selectedMaterialType == UniversalAutoload.ALL then
			return true
		else
			return objectMaterialType == selectedMaterialType
		end
	else
		return false
	end
end
--
function UniversalAutoload:getPalletIsSelectedContainer(object)

	local objectContainerType = UniversalAutoload.getContainerTypeName(object)
	local selectedContainerType = UniversalAutoload.getSelectedContainerType(self)

	if objectContainerType~=nil and selectedContainerType~=nil then
		if selectedContainerType == UniversalAutoload.ALL then
			return true
		else
			return objectContainerType == selectedContainerType
		end
	else
		return false
	end
end
--
function UniversalAutoload.getPalletIsFull(object)
	if object.getFillUnits then
		for k, _ in ipairs(object:getFillUnits() or {}) do
			if object:getFillUnitFillLevelPercentage(k) < 1 then
				return false
			end
		end
	end
	return true
end
--
function UniversalAutoload.getPalletFillLevel(object)
	local total = 0
	if object.getFillUnits then
		for k, _ in ipairs(object:getFillUnits() or {}) do
			total = total + object:getFillUnitFillLevel(k)
		end
	end
	return total
end
--
function UniversalAutoload:getMaxSingleLength()
	local spec = self.spec_universalAutoload

	local maxSingleLength = 0
	for i, loadArea in pairs(spec.loadArea or {}) do
		if loadArea.length > maxSingleLength then
			maxSingleLength = loadArea.length
		end
	end
	return maxSingleLength
end				
--
function UniversalAutoload.isShippingContainer(object)

	return object.spec_woodContainer ~= nil
end
--
function UniversalAutoload.raiseObjectDirtyFlags(object)
	if object.raiseDirtyFlags then
		if object.physicsObjectDirtyFlag then
			object:raiseDirtyFlags(object.physicsObjectDirtyFlag)
			if entityExists(object.nodeId) then
				object.sendPosX, object.sendPosY, object.sendPosZ = UniversalAutoload.getWorldTranslation(object.nodeId)
				object.sendRotX, object.sendRotY, object.sendRotZ = UniversalAutoload.getWorldRotation(object.nodeId)
			end
		elseif object.vehicleDirtyFlag then
			object:raiseDirtyFlags(object.vehicleDirtyFlag)
		end
	end
end

-- DRAW DEBUG PALLET FUNCTIONS
function UniversalAutoload:drawDebugDisplay()
	local spec = self.spec_universalAutoload

	if (UniversalAutoload.showLoading or UniversalAutoload.showDebug) and not g_gui:getIsGuiVisible() then
		-- g_currentMission:addExtraPrintText("ACTIVE - " .. tostring(self:getName()))
		
		local RED     = { 1.0, 0.1, 0.1 }
		local GREEN   = { 0.1, 1.0, 0.1 }
		local YELLOW  = { 1.0, 1.0, 0.1 }
		local CYAN    = { 0.1, 1.0, 1.0 }
		local MAGENTA = { 1.0, 0.1, 1.0 }
		local GREY    = { 0.2, 0.2, 0.2 }
		local WHITE   = { 1.0, 1.0, 1.0 }
		
		local isActiveForInput = self:getIsActiveForInput()
		if not (isActiveForInput or spec.autoCollectionMode or self==UniversalAutoload.lastClosestVehicle) then
			RED = GREY
			GREEN = GREY
			YELLOW = GREY
			CYAN = GREY
			MAGENTA = GREY
			WHITE = GREY
		end
		
		if spec.currentLoadingPlace then
			local place = spec.currentLoadingPlace
			UniversalAutoload.DrawDebugPallet( place.node, place.sizeX, place.sizeY, place.sizeZ, true, false, GREY)
		end

		if UniversalAutoload.showDebug then
			for _, trigger in pairs(spec.triggers or {}) do
				local w, h, l = trigger.width or 1, trigger.height or 1, trigger.length or 1
				if trigger.name == "rearAutoTrigger" or trigger.name == "leftAutoTrigger" or trigger.name == "rightAutoTrigger" then
					--DebugUtil.drawDebugCube(trigger.node, 1,1,1, unpack(GREY))
					UniversalAutoload.DrawDebugPallet(trigger.node, w, h, l, true, false, YELLOW, h/2)
				elseif trigger.name == "leftPickupTrigger" or trigger.name == "rightPickupTrigger"
					or trigger.name == "rearPickupTrigger" or trigger.name == "frontPickupTrigger"
					or (debugLoading and trigger.name == "unloadingTrigger") then
					--DebugUtil.drawDebugCube(trigger.node, 1,1,1, unpack(GREY))
					UniversalAutoload.DrawDebugPallet(trigger.node, w, h, l, true, false, MAGENTA, h/2)
				end
			end
		end
	
		for object, _ in pairs(spec.availableObjects or {}) do
			if object then
				local node = UniversalAutoload.getObjectPositionNode(object)
				if node then
					local containerType = UniversalAutoload.getContainerType(object)
					if containerType ~= nil then
						local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType, true)
						local offset = 0 if containerType.isBale then offset = h/2 end
						if UniversalAutoload.isValidForLoading(self, object) then
							UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREEN, offset )
						else
							UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREY, offset )
						end
					end
				end
			end
		end
		
		for object, _ in pairs(spec.loadedObjects or {}) do
			if object then
				local node = UniversalAutoload.getObjectPositionNode(object)
				if node then
					local containerType = UniversalAutoload.getContainerType(object)
					if containerType ~= nil then
						local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType, true)
						local offset = 0 if containerType.isBale then offset = h/2 end
						if UniversalAutoload.isValidForUnloading(self, object) then 
							UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREEN, offset, spec.velocityCorrection )
						else
							UniversalAutoload.DrawDebugPallet( node, w, h, l, true, false, GREY, offset, spec.velocityCorrection )
						end
					end
				end
			end
		end
		
		if self.isServer then

			UniversalAutoload.debugRefreshTime = (UniversalAutoload.debugRefreshTime or 0) + g_currentDt
			
			if UniversalAutoload.getIsUnloadingKeyAllowed(self) == true then
				if spec.objectsToUnload == nil or UniversalAutoload.debugRefreshTime > UniversalAutoload.loadingSpeed then
					UniversalAutoload.debugRefreshTime = 0
					UniversalAutoload.buildObjectsToUnloadTable(self)
					spec.objectsToUnload = spec.objectsToUnload or {}
				end
				
				for object, unloadPlace in pairs(spec.objectsToUnload or {}) do
					local containerType = UniversalAutoload.getContainerType(object)
					if containerType ~= nil then
						local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType, true)
						local offset = 0 if containerType.isBale then offset = h/2 end
						if spec.unloadingAreaClear then
							UniversalAutoload.DrawDebugPallet( unloadPlace.node, w, h, l, true, false, CYAN, offset )
						else
							UniversalAutoload.DrawDebugPallet( unloadPlace.node, w, h, l, true, false, RED, offset )
						end
					end
				end
			end
			
			if UniversalAutoload.showDebug then
				local W, H, L = spec.loadVolume.width, spec.loadVolume.height, spec.loadVolume.length
				UniversalAutoload.DrawDebugPallet( spec.loadVolume.rootNode, W, H, L, true, false, MAGENTA )
				
				if spec.boundingBox then
					local W, H, L = spec.boundingBox.width, spec.boundingBox.height, spec.boundingBox.length
					UniversalAutoload.DrawDebugPallet( spec.boundingBox.rootNode, W, H, L, true, false, RED )
				end
			end
			
			for i, loadArea in pairs(spec.loadArea or {}) do
				local W, H, L = loadArea.width, loadArea.height, loadArea.length
				if not UniversalAutoload.showDebug then H = 0 end
				
				if UniversalAutoload.getIsLoadingAreaAllowed(self, i) then
					UniversalAutoload.DrawDebugPallet( loadArea.rootNode,  W, H, L, true, false, WHITE )
					UniversalAutoload.DrawDebugPallet( loadArea.startNode, W, 0, 0, true, false, GREEN )
					UniversalAutoload.DrawDebugPallet( loadArea.endNode,   W, 0, 0, true, false, RED )
					
					if UniversalAutoload.showDebug and loadArea.baleHeight then
						H = loadArea.baleHeight
						UniversalAutoload.DrawDebugPallet( loadArea.rootNode, W, H, L, true, false, YELLOW )
					end
				else
					UniversalAutoload.DrawDebugPallet( loadArea.rootNode,  W, H, L, true, false, GREY )
					if UniversalAutoload.showDebug and loadArea.baleHeight then
						H = loadArea.baleHeight
						UniversalAutoload.DrawDebugPallet( loadArea.rootNode, W, H, L, true, false, GREY )
					end
				end
			end
			
		end
		
		if spec.lastLoadAttempt then
			local place = spec.lastLoadAttempt.loadPlace
			local x, y, z = place.sizeX, place.sizeY, place.sizeZ 
			
			local containerType = spec.lastLoadAttempt.containerType
			if containerType ~= nil then
				local w, h, l = UniversalAutoload.getContainerTypeDimensions(containerType)
				UniversalAutoload.DrawDebugPallet( place.node, x, y, z, true, false, GREY )
				UniversalAutoload.DrawDebugPallet( place.node, w, h, l, true, false, MAGENTA )
			end
		end
		
		if debugLoading and spec.lastOverlapBox then
			local b = spec.lastOverlapBox
			local x, y, z = b.x, b.y, b.z
			local dx, dy, dz = b.dx, b.dy, b.dz
			local rx, ry, rz = b.rx, b.ry, b.rz
			local sizeX, sizeY, sizeZ = b.sizeX, b.sizeY, b.sizeZ
			DebugUtil.drawOverlapBox(x+dx, y+dy, z+dz, rx, ry, rz, sizeX, sizeY, sizeZ)
		end

		-- for id, object in pairs(UniversalAutoload.SPLITSHAPES_LOOKUP or {}) do
			-- DebugUtil.drawDebugNode(id, getName(id))
			-- DebugUtil.drawDebugNode(object.positionNodeId, getName(object.positionNodeId))
		-- end
	
		g_currentMission:addExtraPrintText(tostring(self:getName() .. " # " .. (spec.validUnloadCount or "-") .. " / " .. (spec.totalAvailableCount or "-")
			.. ((spec.useHorizontalLoading and " : L" .. (spec.currentLayerCount or "-")  .. "") or "" )))
		
	end
end
--
function UniversalAutoload.DrawDebugPallet( node, w, h, l, showCube, showAxis, colour, offset, velocityCorrection )

	if node and node ~= 0 and entityExists(node) then
		-- colour for square
		colour = colour or WHITE
		local r, g, b = unpack(colour)
		local w, h, l = (w or 1), (h or 1), (l or 1)
		local offset = offset or 0

		local xx,xy,xz = UniversalAutoload.localDirectionToWorld(node, w,0,0)
		local yx,yy,yz = UniversalAutoload.localDirectionToWorld(node, 0,h,0)
		local zx,zy,zz = UniversalAutoload.localDirectionToWorld(node, 0,0,l)
		
		local x0,y0,z0 = UniversalAutoload.localToWorld(node, -w/2, -offset, -l/2, velocityCorrection)
		drawDebugLine(x0,y0,z0,r,g,b,x0+xx,y0+xy,z0+xz,r,g,b)
		drawDebugLine(x0,y0,z0,r,g,b,x0+zx,y0+zy,z0+zz,r,g,b)
		drawDebugLine(x0+xx,y0+xy,z0+xz,r,g,b,x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b)
		drawDebugLine(x0+zx,y0+zy,z0+zz,r,g,b,x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b)

		if showCube then			
			local x1,y1,z1 = UniversalAutoload.localToWorld(node, -w/2, h-offset, -l/2, velocityCorrection)
			drawDebugLine(x1,y1,z1,r,g,b,x1+xx,y1+xy,z1+xz,r,g,b)
			drawDebugLine(x1,y1,z1,r,g,b,x1+zx,y1+zy,z1+zz,r,g,b)
			drawDebugLine(x1+xx,y1+xy,z1+xz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
			drawDebugLine(x1+zx,y1+zy,z1+zz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
			
			drawDebugLine(x0,y0,z0,r,g,b,x1,y1,z1,r,g,b)
			drawDebugLine(x0+zx,y0+zy,z0+zz,r,g,b,x1+zx,y1+zy,z1+zz,r,g,b)
			drawDebugLine(x0+xx,y0+xy,z0+xz,r,g,b,x1+xx,y1+xy,z1+xz,r,g,b)
			drawDebugLine(x0+xx+zx,y0+xy+zy,z0+xz+zz,r,g,b,x1+xx+zx,y1+xy+zy,z1+xz+zz,r,g,b)
		end
		
		if showAxis then
			local x,y,z = UniversalAutoload.localToWorld(node, 0, (h/2)-offset, 0, velocityCorrection)
			Utils.renderTextAtWorldPosition(x-xx/2,y-xy/2,z-xz/2, "-x", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x+xx/2,y+xy/2,z+xz/2, "+x", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x-yx/2,y-yy/2,z-yz/2, "-y", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x+yx/2,y+yy/2,z+yz/2, "+y", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x-zx/2,y-zy/2,z-zz/2, "-z", getCorrectTextSize(0.012), 0)
			Utils.renderTextAtWorldPosition(x+zx/2,y+zy/2,z+zz/2, "+z", getCorrectTextSize(0.012), 0)
			drawDebugLine(x-xx/2,y-xy/2,z-xz/2,1,1,1,x+xx/2,y+xy/2,z+xz/2,1,1,1)
			drawDebugLine(x-yx/2,y-yy/2,z-yz/2,1,1,1,x+yx/2,y+yy/2,z+yz/2,1,1,1)
			drawDebugLine(x-zx/2,y-zy/2,z-zz/2,1,1,1,x+zx/2,y+zy/2,z+zz/2,1,1,1)
		end
	
	end

end

-- ADD CUSTOM STRINGS FROM ModDesc.xml TO GLOBAL g_i18n
function UniversalAutoload.AddCustomStrings()
	-- UniversalAutoload.debugPrint("  ADD custom strings from ModDesc.xml to g_i18n")
	local i = 0
	local xmlFile = loadXMLFile("modDesc", g_currentModDirectory.."modDesc.xml")
	while true do
		local key = string.format("modDesc.l10n.text(%d)", i)
		
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		
		local name = getXMLString(xmlFile, key.."#name")
		local text = getXMLString(xmlFile, key.."."..g_languageShort)
		
		if name then
			g_i18n:setText(name, text)
			UniversalAutoload.debugPrint("  "..tostring(name)..": "..tostring(text))
		end
		
		i = i + 1
	end
end
UniversalAutoload.AddCustomStrings()

-- Courseplay event listeners.
function UniversalAutoload:onAIImplementStart()
	--- TODO: Unfolding or opening cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		UniversalAutoload.debugPrint("UAL/CP - ACTIVATE BALE COLLECTION MODE (onAIImplementStart)")
		UniversalAutoload.setAutoCollectionMode(self, true)
		spec.aiLoadingActive = true
	end
end
--
function UniversalAutoload:onAIImplementEnd()
	--- TODO: Folding or closing cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled and spec.aiLoadingActive then
		UniversalAutoload.debugPrint("UAL/CP - DEACTIVATE BALE COLLECTION MODE (onAIImplementEnd)")
		UniversalAutoload.setAutoCollectionMode(self, false)
		spec.aiLoadingActive = false
	end
end
--
function UniversalAutoload:onAIFieldWorkerStart()
	--- TODO: Unfolding or opening cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		UniversalAutoload.debugPrint("UAL/CP - ACTIVATE BALE COLLECTION MODE (onAIFieldWorkerStart)")
		UniversalAutoload.setAutoCollectionMode(self, true)
		spec.aiLoadingActive = true
	end
end
--
function UniversalAutoload:onAIFieldWorkerEnd()
	--- TODO: Folding or closing cover, if needed!
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled and spec.aiLoadingActive then
		UniversalAutoload.debugPrint("UAL/CP - DEACTIVATE BALE COLLECTION MODE (onAIFieldWorkerEnd)")
		UniversalAutoload.setAutoCollectionMode(self, false)
		spec.aiLoadingActive = false
	end
end  

-- CoursePlay interface functions.
function UniversalAutoload:ualIsFull()
	local spec = self.spec_universalAutoload
	return (spec and spec.isAutoloadAvailable and not spec.autoloadDisabled) and spec.trailerIsFull
end
--
function UniversalAutoload:ualGetLoadedBales()
	local spec = self.spec_universalAutoload
	return (spec and spec.isAutoloadAvailable and not spec.autoloadDisabled) and spec.loadedObjects
end
--
function UniversalAutoload:ualHasLoadedBales()
	UniversalAutoload.debugPrint("UAL/CP - ualHasLoadedBales")
	local spec = self.spec_universalAutoload
	return (spec and spec.isAutoloadAvailable and not spec.autoloadDisabled) and spec.totalUnloadCount > 0
end
--
function UniversalAutoload:ualIsObjectLoadable(object)
	local spec = self.spec_universalAutoload
	UniversalAutoload.debugPrint("UAL/CP - ualIsObjectLoadable")
	--- TODO: Returns true, if the given object is loadable.
	--- For CP, the given object is of the class Bale.
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		UniversalAutoload.debugPrint("UAL/CP - IS BALE = ".. tostring(UniversalAutoload.getContainerTypeName(object) == "BALE"))
		UniversalAutoload.debugPrint("UAL/CP - IS VALID = ".. tostring(UniversalAutoload.isValidForLoading(self, object)))
		return UniversalAutoload.getContainerTypeName(object) == "BALE" and UniversalAutoload.isValidForLoading(self, object)
	end
	return false
end

-- AutoDrive interface functions.
function UniversalAutoload:ualStartLoad()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		-- UniversalAutoload.debugPrint("UAL/AD - START AUTOLOAD")
		UniversalAutoload.startLoading(self, true)
	end
end
function UniversalAutoload:ualStopLoad()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		-- UniversalAutoload.debugPrint("UAL/AD - STOP AUTOLOAD")
		UniversalAutoload.stopLoading(self, true)
	end
end

function UniversalAutoload:ualUnload()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		-- UniversalAutoload.debugPrint("UAL/AD - UNLOAD")
		UniversalAutoload.startUnloading(self, true)
	end
end

function UniversalAutoload:ualSetUnloadPosition(unloadPosition)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		-- UniversalAutoload.debugPrint("UAL/AD - SET UNLOAD POSITION: " .. tostring(unloadPosition))
		spec.forceUnloadPosition = unloadPosition
	end
end


--[[
	TODO:
	Is spec.validUnloadCount the correct value to get the fill level?
	Add a better calculation for getFillUnitCapacity, for the moment it returns always 1 more than spec.validUnloadCount
	
	NOTE:
	I don't think it is possible to do better than this..
	We will never know if there is enough space for a pallet until we try to load it.
]]
function UniversalAutoload:ualGetFillUnitCapacity(fillUnitIndex)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		return (spec.totalUnloadCount and (spec.totalUnloadCount + 1)) or 0
	else
		return 0
	end
end

function UniversalAutoload:ualGetFillUnitFillLevel(fillUnitIndex)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		return (spec.totalUnloadCount and spec.totalUnloadCount) or 0
	else
		return 0
	end
end

-- return 0 if trailer is fully loaded / no capacity left
function UniversalAutoload:ualGetFillUnitFreeCapacity(fillUnitIndex)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		if spec.trailerIsFull then
			return 0
		else
			return self:ualGetFillUnitCapacity(fillUnitIndex) - self:ualGetFillUnitFillLevel(fillUnitIndex)
		end
	else
		return 0
	end
end

function UniversalAutoload:ualSetMaterialTypeIndex(typeIndex)
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		UniversalAutoload.setMaterialTypeIndex(self, typeIndex)
	end
end

function UniversalAutoload:ualGetTotalAvailableCount()
	local spec = self.spec_universalAutoload
	if spec and spec.isAutoloadAvailable and not spec.autoloadDisabled then
		return spec.totalAvailableCount
	else
		return 0
	end
end
