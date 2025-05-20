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
	
	self:initConfigListBoxes()
	self:setUseConfigName()
	self:updateSettings()
end

function ShopConfigMenuUALSettings:initConfigListBoxes()
	if self.vehicle and self.useConfigNameListBox and self.useConfigIndexListBox then
		local vehicle = self.vehicle
		if self.selectedConfigsListBox then		
			local texts = {g_i18n:getText("universalAutoload_ALL")}
			local spec = vehicle and vehicle.spec_universalAutoload
			if spec and spec.configId and spec.configId ~= UniversalAutoload.ALL then
				table.insert(texts, tostring(spec.configId))
				self.selectedConfigsListBox.state = #texts
			end
			self.selectedConfigsListBox:setTexts(texts)
		end

		if self.useConfigNameListBox then
			local texts = {"-"}
			if vehicle then
				local spec = self.vehicle and self.vehicle.spec_universalAutoload
				
				if spec.useConfigName then
					texts = {spec.useConfigName}
				else
					for config, id in pairs(vehicle.configurations or {}) do
						table.insert(texts, tostring(config))
						-- if spec.useConfigName and spec.useConfigName == config then
							-- self.useConfigNameListBox.state = #texts
						-- end
					end
				end
			end
			self.useConfigNameListBox:setTexts(texts)
		end
		
		if self.useConfigIndexListBox then
			local texts = {"-"}
			self.useConfigIndexListBox:setTexts(texts)
		end
	end
end

function ShopConfigMenuUALSettings:setUseConfigName(id)
	if self.vehicle and self.useConfigNameListBox and self.useConfigIndexListBox then
		local id = id or self.useConfigNameListBox.state
		local config = self.useConfigNameListBox.texts[id]
		local index = self.vehicle.configurations[config] or "-"
		local texts = {tostring(index)}
		self.useConfigIndexListBox:setTexts(texts)
	end
end

function ShopConfigMenuUALSettings:updateSettings()
	
	local spec = self.vehicle and self.vehicle.spec_universalAutoload
	local settings = self.ualShopConfigSettingsLayout
	
	local isValid = spec ~= nil
	local isEnabled = spec and spec.autoloadDisabled ~= true
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
		UniversalAutoload.debugPrint("ShopConfigMenu: SET ALL", debugMenus)
		setChecked('enableAutoloadCheckBox', not spec.autoloadDisabled)
		setChecked('horizontalLoadingCheckBox', spec.horizontalLoading)
		setChecked('disableAutoStrapCheckBox', not spec.disableAutoStrap)
		setChecked('disableHeightLimitCheckBox', not spec.disableHeightLimit)
		setChecked('enableSideLoadingCheckBox', spec.enableSideLoading)
		setChecked('enableRearLoadingCheckBox', spec.enableRearLoading)
		
		if spec.isBaleTrailer then
			setValue('trailerTypeListBox', 2)
		elseif spec.isLogTrailer then
			setValue('trailerTypeListBox', 3)
		elseif spec.isBoxTrailer then
			setValue('trailerTypeListBox', 4)
		elseif spec.isCurtainTrailer then
			setValue('trailerTypeListBox', 5)
		else
			setValue('trailerTypeListBox', 1)
		end
		
		if spec.rearUnloadingOnly then
			setValue('unloadingTypeListBox', 2)
		elseif spec.frontUnloadingOnly then
			setValue('unloadingTypeListBox', 3)
		else
			setValue('unloadingTypeListBox', 1)
		end
		
		if spec.noLoadingIfFolded then
			setValue('noLoadingFoldedListBox', 2)
		elseif spec.noLoadingIfUnfolded then
			setValue('noLoadingFoldedListBox', 3)
		else
			setValue('noLoadingFoldedListBox', 1)
		end
		
		if spec.noLoadingIfCovered then
			setValue('noLoadingCoveredListBox', 2)
		elseif spec.noLoadingIfUncovered then
			setValue('noLoadingCoveredListBox', 3)
		else
			setValue('noLoadingCoveredListBox', 1)
		end

	--minLogLength
	
	--zonesOverlap
	--offsetRoot
	
		local numberAreas = spec.loadingVolume and #spec.loadingVolume.bbs or 1
		setValue('addRemoveAreasListBox', numberAreas)

	end
	
end

function ShopConfigMenuUALSettings:onCreate()
	UniversalAutoload.debugPrint("ShopConfigMenu: onCreate", debugMenus)
	
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
	control.texts = {}
	for n = 1, UniversalAutoload.MAX_AREAS do
		table.insert(control.texts, tostring(n))
	end
end

function ShopConfigMenuUALSettings:onCreateSelectedArea(control)
	control.texts = {g_i18n:getText("universalAutoload_ALL")}
end

function ShopConfigMenuUALSettings:onCreateSelectedConfigs(control)
	control.texts = {"-"}
end	

function ShopConfigMenuUALSettings:onClickSelectedConfigs(id, control, direction)
	-- UniversalAutoload.debugPrint("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")", debugMenus)
		
	local spec = self.vehicle and self.vehicle.spec_universalAutoload
	if not spec then
		return
	end
	
	if control == self.useConfigNameListBox then
		self:setUseConfigName(id)
	end

	local useConfigName = nil
	local selectedConfigs = nil
	
	if self.selectedConfigsListBox then
		local id = self.selectedConfigsListBox.state
		local text = self.selectedConfigsListBox.texts[id]
		if text == g_i18n:getText("universalAutoload_ALL") then
			selectedConfigs = UniversalAutoload.ALL
			spec.configId = UniversalAutoload.ALL
		else
			selectedConfigs = text
			spec.configId = text
		end
	end
	if self.useConfigNameListBox then
		local id = self.useConfigNameListBox.state
		local text = self.useConfigNameListBox.texts[id]
		useConfigName = text ~= "-" and text or nil
	end
	if self.useConfigIndexListBox and useConfigName then
		local id = self.useConfigIndexListBox.state
		local text = self.useConfigIndexListBox.texts[id]
		if text ~= "-" then
			selectedConfigs = selectedConfigs .. "|" .. text
		else
			UniversalAutoload.debugPrint("WARNING: useConfigIndex was not set", debugMenus)
		end
	end

	if selectedConfigs then
		UniversalAutoload.debugPrint("selectedConfigs: " .. tostring(selectedConfigs), debugMenus)
		UniversalAutoload.debugPrint("useConfigName: " .. tostring(useConfigName), debugMenus)
		
		spec.useConfigName = useConfigName
		spec.selectedConfigs = selectedConfigs
	else
		UniversalAutoload.debugPrint("WARNING: selectedConfigs was not set", debugMenus)
	end
	
end

function ShopConfigMenuUALSettings:onClickMultiOption(id, control, direction)
	-- UniversalAutoload.debugPrint("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")", debugMenus)
		
	local spec = self.vehicle and self.vehicle.spec_universalAutoload
	if not spec then
		return
	end
	
	if control == self.trailerTypeListBox then
		spec.isBaleTrailer = false
		spec.isLogTrailer = false
		spec.isBoxTrailer = false
		spec.isCurtainTrailer = false
		if id == 2 then
			spec.isBaleTrailer = true
		elseif id == 3 then
			spec.isLogTrailer = true
		elseif id == 4 then
			spec.isBoxTrailer = true
		elseif id == 5 then
			spec.isCurtainTrailer = true
		end
	end
	
	if control == self.unloadingTypeListBox then
		spec.rearUnloadingOnly = false
		spec.frontUnloadingOnly = false
		if id == 2 then
			spec.rearUnloadingOnly = true
		elseif id == 3 then
			spec.frontUnloadingOnly = true
		end
	end
	
	if control == self.noLoadingFoldedListBox then
		spec.noLoadingIfFolded = false
		spec.noLoadingIfUnfolded = false
		if id == 2 then
			spec.noLoadingIfFolded = true
		elseif id == 3 then
			spec.noLoadingIfUnfolded = true
		end
	end
	
	if control == self.noLoadingCoveredListBox then
		spec.noLoadingIfCovered = false
		spec.noLoadingIfUncovered = false
		if id == 2 then
			spec.noLoadingIfCovered = true
		elseif id == 3 then
			spec.noLoadingIfUncovered = true
		end
	end
	
end

function ShopConfigMenuUALSettings:onClickAreaMultiOption(id, control, direction)
	-- UniversalAutoload.debugPrint("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")", debugMenus)
		
	local spec = self.vehicle and self.vehicle.spec_universalAutoload
	if not spec then
		return
	end

	if control == self.addRemoveAreasListBox then
		local numberAreas = spec.loadingVolume and #spec.loadingVolume.bbs or 1
		local newNumberAreas = self.addRemoveAreasListBox.state or 1
		
		if numberAreas ~= newNumberAreas then
			if UniversalAutoloadManager.shopConfig then
				UniversalAutoloadManager.shopConfig.enableEditing = true
			end
			if newNumberAreas < numberAreas then
				UniversalAutoload.debugPrint("REMOVE LOAD AREA #" .. numberAreas, debugMenus)
				spec.loadingVolume:removeBoundingBox()
			else
				UniversalAutoload.debugPrint("ADD LOAD AREA #" .. newNumberAreas, debugMenus)
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
	-- UniversalAutoload.debugPrint("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")", debugMenus)
	
	local spec = self.vehicle and self.vehicle.spec_universalAutoload
	if not spec then
		return
	end
	
	if control == self.enableAutoloadCheckBox then
		spec.autoloadDisabled = direction
		self:updateSettings()
	elseif control == self.horizontalLoadingCheckBox then
		spec.horizontalLoading = not direction
	elseif control == self.enableSideLoadingCheckBox then
		spec.enableSideLoading = not direction
	elseif control == self.enableRearLoadingCheckBox then
		spec.enableRearLoading = not direction
	elseif control == self.disableAutoStrapCheckBox then
		spec.disableAutoStrap = direction
	elseif control == self.disableHeightLimitCheckBox then
		spec.disableHeightLimit = direction
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
	-- UniversalAutoload.debugPrint("action: " .. tostring(action), debugMenus)
end

function ShopConfigMenuUALSettings:onOpen()
	UniversalAutoload.debugPrint("ShopConfigMenu: onOpen", debugMenus)
	self:updateSettings()
	self.isActive = true
end

function ShopConfigMenuUALSettings:onClose()
	UniversalAutoload.debugPrint("ShopConfigMenu: onClose", debugMenus)
	self.isActive = false
end

function ShopConfigMenuUALSettings:onClickSave()
	UniversalAutoload.debugPrint("CLICKED SAVE", debugMenus)
	g_inputBinding:setShowMouseCursor(true)
	self:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
	local text = g_i18n:getText("ui_confirm_save_config_ual") .. "\n" .. g_i18n:getText("ui_confirm_save_config2_ual")
	local callback = function(self, yes)
		if yes == true then
			UniversalAutoloadManager.exportVehicleConfigToServer()
		end
	end
	YesNoDialog.show(callback, self, text)
	self:initConfigListBoxes()
	self:setUseConfigName()
end

function ShopConfigMenuUALSettings:onClickClose()
	UniversalAutoload.debugPrint("CLICKED CLOSE", debugMenus)
	g_gui:closeDialogByName("ShopConfigMenuUALSettings")
end
