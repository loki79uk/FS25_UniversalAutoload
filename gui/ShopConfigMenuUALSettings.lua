ShopConfigMenuUALSettings = {}
local ShopConfigMenuUALSettings_mt = Class(ShopConfigMenuUALSettings, TabbedMenuFrameElement)

function ShopConfigMenuUALSettings.register()
	local shopCongfigMenu = ShopConfigMenuUALSettings.new()
	g_gui:loadGui(UniversalAutoload.path .. "gui/ShopConfigMenuUALSettings.xml", "ShopConfigMenuUALSettings", shopCongfigMenu)
	return shopCongfigMenu
end

function ShopConfigMenuUALSettings.new(vehicle, subclass_mt)
	
	local self = ShopConfigMenuUALSettings:superClass().new(nil, subclass_mt or ShopConfigMenuUALSettings_mt)

    self.name = "ShopConfigMenuUALSettings"
	self.vehicle = vehicle
    self.i18n = l18n or g_i18n
    self.inputBinding = inputBinding or g_inputBinding
    self.messageCenter = messageCenter or g_messageCenter
	
	return self
end

function ShopConfigMenuUALSettings:setNewVehicle(vehicle)
	self.vehicle = vehicle
	local name = vehicle and ("  -  " .. vehicle:getFullName()) or ""
	self.guiTitle:setText(g_i18n:getText("ui_config_settings_ual") .. name)
	self:updateSettings()
end

function ShopConfigMenuUALSettings:updateSettings()
	
	local vehicle = self.vehicle and self.vehicle.spec_universalAutoload
	local settings = self.ualShopConfigSettingsLayout
	
	local isValid = vehicle ~= nil
	local isEnabled = vehicle and vehicle.autoloadDisabled ~= true
	for _, item in pairs(settings.elements) do
		if item.name ~= "enableAutoload" then
			item:setVisible(isEnabled)
		end
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
	
	if isValid then
		print("SET ALL")
		setChecked('enableAutoloadCheckBox', not vehicle.autoloadDisabled)
		setChecked('horizontalLoadingCheckBox', vehicle.horizontalLoading)
		setChecked('disableAutoStrapCheckBox', not vehicle.disableAutoStrap)
		setChecked('disableHeightLimitCheckBox', not vehicle.disableHeightLimit)
		setChecked('enableSideLoadingCheckBox', vehicle.enableSideLoading)
		setChecked('enableRearLoadingCheckBox', vehicle.enableRearLoading)
		
		if vehicle.isBaleTrailer then
			setValue('trailerTypeListBox', 2)
		elseif vehicle.isLogTrailer then
			setValue('trailerTypeListBox', 3)
		elseif vehicle.isBoxTrailer then
			setValue('trailerTypeListBox', 4)
		elseif vehicle.isCurtainTrailer then
			setValue('trailerTypeListBox', 5)
		else
			setValue('trailerTypeListBox', 1)
		end
		
		if vehicle.rearUnloadingOnly then
			setValue('unloadingTypeListBox', 2)
		elseif vehicle.frontUnloadingOnly then
			setValue('unloadingTypeListBox', 3)
		else
			setValue('unloadingTypeListBox', 1)
		end
		
		if vehicle.noLoadingIfFolded then
			setValue('noLoadingFoldedListBox', 2)
		elseif vehicle.noLoadingIfUnfolded then
			setValue('noLoadingFoldedListBox', 3)
		else
			setValue('noLoadingFoldedListBox', 1)
		end
		
		if vehicle.noLoadingIfCovered then
			setValue('noLoadingCoveredListBox', 2)
		elseif vehicle.noLoadingIfUncovered then
			setValue('noLoadingCoveredListBox', 3)
		else
			setValue('noLoadingCoveredListBox', 1)
		end

	--minLogLength
	
	--zonesOverlap
	--offsetRoot
	
		local spec = vehicle.spec_universalAutoload
		local numberAreas = spec.loadingVolume and #spec.loadingVolume.bbs or 1
		setValue('addRemoveAreasListBox', numberAreas)
	
	end
	
end

function ShopConfigMenuUALSettings:onCreate()
	print("ShopConfigMenu: onCreate")
	
	local settings = self.ualShopConfigSettingsLayout
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

function ShopConfigMenuUALSettings:onCreateTrailerType(control)
	control.texts = {
		g_i18n:getText("configuration_valueDefault"),
		g_i18n:getText("ui_option_isBaleTrailer"),
		g_i18n:getText("ui_option_isLogTrailer"),
		g_i18n:getText("ui_option_isBoxTrailer"),
		g_i18n:getText("ui_option_isCurtainTrailer"),
	}
end
function ShopConfigMenuUALSettings:onCreateUnloadingType(control)
	control.texts = {
		g_i18n:getText("configuration_valueDefault"),
		g_i18n:getText("ui_option_rearOnly"),
		g_i18n:getText("ui_option_frontOnly")
	}
end
function ShopConfigMenuUALSettings:onCreateNoLoadingFolded(control)
	control.texts = {
		g_i18n:getText("configuration_valueNone"),
		g_i18n:getText("ui_option_folded"),
		g_i18n:getText("ui_option_unfolded")
	}
end
function ShopConfigMenuUALSettings:onCreateNoLoadingCovered(control)
	control.texts = {
		g_i18n:getText("configuration_valueNone"),
		g_i18n:getText("ui_option_covered"),
		g_i18n:getText("ui_option_uncovered")
	}
end

function ShopConfigMenuUALSettings:onCreateAddRemoveAreas(control)
	control.texts = {"1", "2", "3"}
end
function ShopConfigMenuUALSettings:onCreateSelectedArea(control)
	control.texts = {g_i18n:getText("universalAutoload_ALL")}
end

function ShopConfigMenuUALSettings:onClickMultiOption(id, control, direction)
	print("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")")
		
	local vehicle = self.vehicle and self.vehicle.spec_universalAutoload
	if not vehicle then
		return
	end
	
	if control == self.trailerTypeListBox then
		vehicle.isBaleTrailer = false
		vehicle.isLogTrailer = false
		vehicle.isBoxTrailer = false
		vehicle.isCurtainTrailer = false
		if id == 2 then
			vehicle.isBaleTrailer = true
		elseif id == 3 then
			vehicle.isLogTrailer = true
		elseif id == 4 then
			vehicle.isBoxTrailer = true
		elseif id == 5 then
			vehicle.isCurtainTrailer = true
		end
	end
	
	if control == self.unloadingTypeListBox then
		vehicle.rearUnloadingOnly = false
		vehicle.frontUnloadingOnly = false
		if id == 2 then
			vehicle.rearUnloadingOnly = true
		elseif id == 3 then
			vehicle.frontUnloadingOnly = true
		end
	end
	
	if control == self.noLoadingFoldedListBox then
		vehicle.noLoadingIfFolded = false
		vehicle.noLoadingIfUnfolded = false
		if id == 2 then
			vehicle.noLoadingIfFolded = true
		elseif id == 3 then
			vehicle.noLoadingIfUnfolded = true
		end
	end
	
	if control == self.noLoadingCoveredListBox then
		vehicle.noLoadingIfCovered = false
		vehicle.noLoadingIfUncovered = false
		if id == 2 then
			vehicle.noLoadingIfCovered = true
		elseif id == 3 then
			vehicle.noLoadingIfUncovered = true
		end
	end
	
end

function ShopConfigMenuUALSettings:onClickAreaMultiOption(id, control, direction)
	print("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")")
		
	local vehicle = self.vehicle and self.vehicle.spec_universalAutoload
	if not vehicle then
		return
	end

	if control == self.addRemoveAreasListBox then
		local spec = vehicle.spec_universalAutoload
		local numberAreas = spec.loadingVolume and #spec.loadingVolume.bbs or 1
		local newNumberAreas = self.addRemoveAreasListBox.state or 1
		
		if numberAreas ~= newNumberAreas then
			if UniversalAutoloadManager.shopConfig then
				UniversalAutoloadManager.shopConfig.enableEditing = true
			end
			
			if newNumberAreas < numberAreas then
				print("REMOVE LOAD AREA #" .. numberAreas)
				spec.loadingVolume:removeBoundingBox()
			else
				print("ADD LOAD AREA #" .. newNumberAreas)
				spec.loadingVolume:addBoundingBox()
			end

		end
	
	
		-- local texts = {g_i18n:getText("universalAutoload_ALL")}
		-- if id > 1 then
			-- for i = 1, id do
				-- table.insert(texts, "#" .. tostring(i))
			-- end
		-- end
		-- self.selectedAreaListBox:setTexts(texts)
	end
	
	if control == self.selectedAreaListBox then
	end
	
end

function ShopConfigMenuUALSettings:onClickBinaryOption(id, control, direction)
	print("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")")
	
	local vehicle = self.vehicle and self.vehicle.spec_universalAutoload
	if not vehicle then
		return
	end
	
	if control == self.enableAutoloadCheckBox then
		vehicle.autoloadDisabled = direction
		self:updateSettings()
	elseif control == self.horizontalLoadingCheckBox then
		vehicle.horizontalLoading = not direction
	elseif control == self.enableSideLoadingCheckBox then
		vehicle.enableSideLoading = not direction
	elseif control == self.enableRearLoadingCheckBox then
		vehicle.enableRearLoading = not direction
	elseif control == self.disableAutoStrapCheckBox then
		vehicle.disableAutoStrap = direction
	elseif control == self.disableHeightLimitCheckBox then
		vehicle.disableHeightLimit = direction
	end

end

function ShopConfigMenuUALSettings.inputEvent(self, action, value, direction)
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

function ShopConfigMenuUALSettings:onOpen()
	print("ShopConfigMenu: onOpen")
	self:updateSettings()
	self.isActive = true
end

function ShopConfigMenuUALSettings:onClose()
	print("ShopConfigMenu: onClose")
	self.isActive = false
end

function ShopConfigMenuUALSettings:onClickSave()
	print("CLICKED SAVE")
	g_inputBinding:setShowMouseCursor(true)
	self:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
	local text = g_i18n:getText("ui_confirm_save_config_ual")
	local callback = function(self, yes)
		if yes == true then
			UniversalAutoloadManager.exportVehicleConfigToServer()
		end
	end
	YesNoDialog.show(callback, self, text)
end

function ShopConfigMenuUALSettings:onClickClose()
	print("CLICKED CLOSE")
	g_gui:closeDialogByName("ShopConfigMenuUALSettings")
end
