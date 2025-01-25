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
	print("SET VEHICLE: " .. tostring(vehicle:getFullName()))
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
	
	print("SET GLOBAL")
	print(" showDebug: " .. tostring(UniversalAutoload.showDebug))
	print(" highPriority: " .. tostring(UniversalAutoload.highPriority))
	print(" disableAutoStrap: " .. tostring(UniversalAutoload.disableAutoStrap))
	setChecked('showDebugCheckBox', UniversalAutoload.showDebug)
	setChecked('highPriorityCheckBox', UniversalAutoload.highPriority)
	setChecked('disableAutoStrapCheckBox', not UniversalAutoload.disableAutoStrap)
	
end

function GlobalSettingsMenuUALSettings:onCreate()
	print("GlobalSettingsMenu: onCreate")

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

end

function GlobalSettingsMenuUALSettings:onClickBinaryOption(id, control, direction)
	print("CLICKED GLOBAL " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")")

	if control == self.showDebugCheckBox then
		UniversalAutoload.showDebug = not direction
		print(" showDebug: " .. tostring(UniversalAutoload.showDebug))
	elseif control == self.highPriorityCheckBox then
		UniversalAutoload.highPriority = not direction
		print(" highPriority: " .. tostring(UniversalAutoload.highPriority))
	elseif control == self.disableAutoStrapCheckBox then
		UniversalAutoload.disableAutoStrap = direction
		print(" disableAutoStrap: " .. tostring(UniversalAutoload.disableAutoStrap))
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
	-- print("action: " .. tostring(action))
end

function GlobalSettingsMenuUALSettings:onOpen()
	print("GlobalSettingsMenu: onOpen")
	self:updateSettings()
	self.isActive = true
	g_inputBinding:setShowMouseCursor(true)
end

function GlobalSettingsMenuUALSettings:onClose()
	print("GlobalSettingsMenu: onClose")
	self.isActive = false
	g_inputBinding:setShowMouseCursor(false)
	if self.vehicle then
		UniversalAutoload.clearActionEvents(self.vehicle)
		UniversalAutoload.updateActionEventKeys(self.vehicle)
	end
end

function GlobalSettingsMenuUALSettings:onClickClose()
	print("CLICKED CLOSE")
	g_gui:closeDialogByName("GlobalSettingsMenuUALSettings")
end
