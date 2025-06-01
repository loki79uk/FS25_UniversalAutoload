GlobalSettingsMenuUALSettings = {}
local GlobalSettingsMenuUALSettings_mt = Class(GlobalSettingsMenuUALSettings, TabbedMenuFrameElement)

function GlobalSettingsMenuUALSettings.register()
	local globalSettingsMenu = GlobalSettingsMenuUALSettings.new()
	g_gui:loadGui(UniversalAutoload.path .. "gui/GlobalSettingsMenuUALSettings.xml", "GlobalSettingsMenuUALSettings", globalSettingsMenu)
	return globalSettingsMenu
end

function GlobalSettingsMenuUALSettings.new(vehicle, subclass_mt)
	
	local self = GlobalSettingsMenuUALSettings:superClass().new(nil, subclass_mt or GlobalSettingsMenuUALSettings_mt)

    self.name = "GlobalSettingsMenuUALSettings"
	self.vehicle = vehicle
    self.i18n = l18n or g_i18n
    self.inputBinding = inputBinding or g_inputBinding
    self.messageCenter = messageCenter or g_messageCenter
	
	return self
end

function GlobalSettingsMenuUALSettings:setNewVehicle(vehicle)
	UniversalAutoload.debugPrint("SET VEHICLE: " .. tostring(vehicle:getFullName()), debugMenus)
	self.vehicle = vehicle
	-- local name = vehicle and ("  -  " .. vehicle:getFullName()) or ""
	-- self.guiTitle:setText(g_i18n:getText("ui_global_settings_ual") .. name)
	-- self:updateSettings()
end

function GlobalSettingsMenuUALSettings:updateSettings()
	
	local vehicle = self.vehicle
	local settings = self.ualGlobalSettingsLayout
	
	for _, item in pairs(settings.elements) do
		item:setVisible(true)
	end
	settings:invalidateLayout()

	local function setChecked(controlId, checked)
		local control = self[controlId]
		if control then
			control:setIsChecked(checked or false, true)
		end
	end
	local function setValue(controlId, value)
		local control = self[controlId]
		if control then
			control:setState(value or 1, true)
		end
	end
	local function setClosestValue(controlId, value)
		local control = self[controlId]
		if control then
			local index = 1
			local initialdiff = math.huge
			for i, v in pairs(control.values or {}) do
				local currentdiff = math.abs(v - value)
				if currentdiff < initialdiff then
					initialdiff = currentdiff
					index = i
				end 
			end
			control:setState(index, true)
		end
	end
	
	UniversalAutoload.debugPrint("GlobalSettingsMenu: SET GLOBAL", debugMenus)
	UniversalAutoload.debugPrint(" showDebug: " .. tostring(UniversalAutoload.showDebug), debugMenus)
	UniversalAutoload.debugPrint(" highPriority: " .. tostring(UniversalAutoload.highPriority), debugMenus)
	UniversalAutoload.debugPrint(" lowRefreshMode: " .. tostring(UniversalAutoload.lowRefreshMode), debugMenus)
	UniversalAutoload.debugPrint(" disableAutoStrap: " .. tostring(UniversalAutoload.disableAutoStrap), debugMenus)
	setChecked('showDebugCheckBox', UniversalAutoload.showDebug)
	setChecked('highPriorityCheckBox', UniversalAutoload.highPriority)
	setChecked('lowRefreshModeCheckBox', UniversalAutoload.lowRefreshMode)
	setChecked('disableAutoStrapCheckBox', not UniversalAutoload.disableAutoStrap)
	
	self.pricePerLogTextInput:setText(tostring(UniversalAutoload.pricePerLog))
	self.pricePerBaleTextInput:setText(tostring(UniversalAutoload.pricePerBale))
	self.pricePerPalletTextInput:setText(tostring(UniversalAutoload.pricePerPallet))

	setClosestValue('minLogLengthListBox', UniversalAutoload.minLogLength)
	setClosestValue('loadingSpeedListBox', UniversalAutoload.loadingSpeed)
	setClosestValue('objectSpacingListBox', UniversalAutoload.objectSpacing)
	
end

function GlobalSettingsMenuUALSettings:onCreate()
	UniversalAutoload.debugPrint("GlobalSettingsMenu: onCreate", debugMenus)

	local settings = self.ualGlobalSettingsLayout
	-- for _, item in pairs(settings.elements) do
		-- if item.name ~= "sectionHeader" and item:getIsVisible() then
			-- local c = InGameMenuSettingsFrame.COLOR_ALTERNATING[true]
			-- item:setImageColor(GuiOverlay.STATE_NORMAL, c[1], c[2], c[3], 0)
		-- end
	-- end
	
    local toggle = true
	for _, item in pairs(settings.elements) do
		if item.name == "sectionHeader" or not item.setImageColor then
			toggle = true
		elseif item:getIsVisible() then
			local c = InGameMenuSettingsFrame.COLOR_ALTERNATING[toggle]
			item:setImageColor(GuiOverlay.STATE_NORMAL, unpack(c))
			toggle = not toggle
		end
	end
	
	if g_currentMission.missionDynamicInfo.isMultiplayer then
		self.disableAutoStrapCheckBox:setDisabled(true)
		self.minLogLengthListBox:setDisabled(true)
		self.loadingSpeedListBox:setDisabled(true)
		self.objectSpacingListBox:setDisabled(true)
		self.pricePerLogTextInput:setDisabled(true)
		self.pricePerBaleTextInput:setDisabled(true)
		self.pricePerPalletTextInput:setDisabled(true)
	end
	
	
	local function getIsUnicodeAllowed(self, unicode)
		if self:getText() == "0" then
			self:setText("")
		end
		if unicode == 13 or unicode == 10 then
			return false
		elseif getCanRenderUnicode(unicode) and ((unicode >= 48 and unicode <= 57) or (unicode >= 256 and unicode <= 265)) then
			return Utils.getNoNil(self:raiseCallback("onIsUnicodeAllowedCallback", unicode), true)
		else
			return false
		end
	end
	self.pricePerLogTextInput.getIsUnicodeAllowed = getIsUnicodeAllowed
	self.pricePerBaleTextInput.getIsUnicodeAllowed = getIsUnicodeAllowed
	self.pricePerPalletTextInput.getIsUnicodeAllowed = getIsUnicodeAllowed
	
end

function GlobalSettingsMenuUALSettings:onCreateMinLogLength(control)
	control.texts = {
		'0.0',
		'1.0',
		'2.0',
		'3.0',
		'4.0',
		'5.0',
		'6.0',
		'7.0',
		'8.0'
	}
	control.values = {
		0.0,
		1.0,
		2.0,
		3.0,
		4.0,
		5.0,
		6.0,
		7.0,
		8.0
	}
end

function GlobalSettingsMenuUALSettings:onCreateLoadingSpeed(control)
	control.texts = {
		'50',
		'100',
		'150',
		'200',
		'250',
		'500',
		'750',
		'1000',
		'2000'
	}
	control.values = {
		50,
		100,
		150,
		200,
		250,
		500,
		750,
		1000,
		2000
	}
end

function GlobalSettingsMenuUALSettings:onCreateObjectSpacing(control)
	control.texts = {
		'0.000',
		'0.005',
		'0.010',
		'0.025',
		'0.050',
		'0.075',
		'0.100',
		'0.125'
	}
	control.values = {
		0.000,
		0.005,
		0.010,
		0.025,
		0.050,
		0.075,
		0.100,
		0.125
	}
end

function GlobalSettingsMenuUALSettings:onClickBinaryOption(id, control, direction)
	UniversalAutoload.debugPrint("CLICKED GLOBAL " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")", debugMenus)

	if control == self.showDebugCheckBox then
		UniversalAutoload.showDebug = not direction
		UniversalAutoload.debugPrint(" showDebug: " .. tostring(UniversalAutoload.showDebug), debugMenus)
	elseif control == self.highPriorityCheckBox then
		UniversalAutoload.highPriority = not direction
		UniversalAutoload.debugPrint(" highPriority: " .. tostring(UniversalAutoload.highPriority), debugMenus)
	elseif control == self.lowRefreshModeCheckBox then
		UniversalAutoload.lowRefreshMode = not direction
		UniversalAutoload.debugPrint(" lowRefreshMode: " .. tostring(UniversalAutoload.lowRefreshMode), debugMenus)
	elseif control == self.disableAutoStrapCheckBox then
		UniversalAutoload.disableAutoStrap = direction
		UniversalAutoload.debugPrint(" disableAutoStrap: " .. tostring(UniversalAutoload.disableAutoStrap), debugMenus)
	end

end

function GlobalSettingsMenuUALSettings:onClickMultiOption(id, control, direction)
	-- UniversalAutoload.debugPrint("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")", debugMenus)
		
	local spec = self.vehicle and self.vehicle.spec_universalAutoload
	if not spec then
		return
	end
	
	if control == self.minLogLengthListBox then
		UniversalAutoload.minLogLength = control.values[id]
		UniversalAutoload.debugPrint(" minLogLength: " .. tostring(UniversalAutoload.minLogLength), debugMenus)	
	end
	
	if control == self.loadingSpeedListBox then
		UniversalAutoload.loadingSpeed = control.values[id]
		UniversalAutoload.debugPrint(" loadingSpeed: " .. tostring(UniversalAutoload.loadingSpeed), debugMenus)	
	end
	
	if control == self.objectSpacingListBox then
		UniversalAutoload.objectSpacing = control.values[id]
		UniversalAutoload.debugPrint(" objectSpacing: " .. tostring(UniversalAutoload.objectSpacing), debugMenus)	
	end
	
end

function GlobalSettingsMenuUALSettings:onClickTextInputOption(id)
	UniversalAutoload.debugPrint("CLICKED GLOBAL VALUE " .. tostring(id) .. " = " .. tostring(id.text), debugMenus)
	local focusedElement = FocusManager:getFocusedElement()
end

function GlobalSettingsMenuUALSettings:onEnterTextInputOption(id)
	UniversalAutoload.debugPrint("ENTERED GLOBAL VALUE " .. tostring(id) .. " = " .. tostring(id.text), debugMenus)
	local numericValue = tonumber(id.text)
	if not numericValue or type(numericValue) ~= "number" then
		id:setText("0")
		numericValue = 0
	end
	if id == self.pricePerLogTextInput then
		UniversalAutoload.pricePerLog = numericValue
		UniversalAutoload.debugPrint(" pricePerLog: " .. tostring(UniversalAutoload.pricePerLog), debugMenus)	
	end
	if id == self.pricePerBaleTextInput then
		UniversalAutoload.pricePerBale = numericValue
		UniversalAutoload.debugPrint(" pricePerBale: " .. tostring(UniversalAutoload.pricePerBale), debugMenus)	
	end
	if id == self.pricePerPalletTextInput then
		UniversalAutoload.pricePerPallet = numericValue
		UniversalAutoload.debugPrint(" pricePerPallet: " .. tostring(UniversalAutoload.pricePerPallet), debugMenus)	
	end
end

function GlobalSettingsMenuUALSettings.inputEvent(self, action, value, direction)
	if action == InputAction.MENU_BACK then
		self:onClickClose()
		return true
	end
	if action == InputAction.MENU_ACCEPT then
		self:onClickSave()
		return true
	end
	-- UniversalAutoload.debugPrint("action: " .. tostring(action), debugMenus)
end

function GlobalSettingsMenuUALSettings:onOpen()
	UniversalAutoload.debugPrint("GlobalSettingsMenu: onOpen", debugMenus)
	self:updateSettings()
	self.isActive = true
	g_inputBinding:setShowMouseCursor(true)
end

function GlobalSettingsMenuUALSettings:onClose()
	UniversalAutoload.debugPrint("GlobalSettingsMenu: onClose", debugMenus)
	self.isActive = false
	g_inputBinding:setShowMouseCursor(false)
	if self.vehicle then
		UniversalAutoload.clearActionEvents(self.vehicle)
		UniversalAutoload.updateActionEventKeys(self.vehicle)
	end
	UniversalAutoloadManager.exportGlobalSettings()
end

function GlobalSettingsMenuUALSettings:onClickClose()
	UniversalAutoload.debugPrint("CLICKED CLOSE", debugMenus)
	g_gui:closeDialogByName("GlobalSettingsMenuUALSettings")
end
