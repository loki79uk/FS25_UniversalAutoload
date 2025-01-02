ModSettingsMenu = {}
local ModSettingsMenu_mt = Class(ModSettingsMenu, TabbedMenuFrameElement)
ModSettingsMenu.SUB_CATEGORY = {
	["MOD1"] = 1,
	["MOD2"] = 2,
	["MOD3"] = 3,
	["MOD4"] = 4,
	["MOD5"] = 5
}

local function NO_CALLBACK()
end

function ModSettingsMenu.register()
	local modSettings = ModSettingsMenu.new()
	g_gui:loadGui(UniversalAutoload.path .. "gui/ModSettingsMenu.xml", "ModSettingsMenu", modSettings, true)
	return modSettings
end

function ModSettingsMenu.new(target, subclass_mt)
	local self = ModSettingsMenu:superClass().new(target, subclass_mt or ModSettingsMenu_mt)

	self.isOpening = false
	self.hasCustomMenuButtons = true
	self.binaryOptionMapping = {}
	self.optionMapping = {}
	self.controlsController = nil
	self.controlsData = {}
	self.controlsMessageText = ""
	self.userChangedInput = false
	self.currentFocusCell = nil
	self.dataRowOffset = 0
	
	return self
end

function InGameMenuSettingsFrame:initModPages()
	local subCategories = {}
	for index, button in pairs(self.subCategoryTabs) do
		button:getDescendantByName("background").getIsSelected = function()
			return index == tonumber(self.subCategoryPaging.texts[self.subCategoryPaging:getState()])
		end
		function button.getIsSelected()
			return index == tonumber(self.subCategoryPaging.texts[self.subCategoryPaging:getState()])
		end
		local mission = g_currentMission
		if index == InGameMenuSettingsFrame.SUB_CATEGORY.CONTROLS and not Platform.canChangeControls then
			button:setVisible(false)
		elseif index == InGameMenuSettingsFrame.SUB_CATEGORY.GRAPHIC_SETTINGS then
			button:setVisible(false)
		elseif index == InGameMenuSettingsFrame.SUB_CATEGORY.SERVER_SETTINGS and not (self.hasMasterRights and mission.missionDynamicInfo.isMultiplayer) then
			button:setVisible(false)
		else
			button:setVisible(true) 
			table.insert(subCategories, tostring(index))
		end
	end
	self.subCategoryBox:invalidateLayout()
	self.subCategoryPaging:setTexts(subCategories)
	self.subCategoryPaging:setSize(self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX)
end

function ModSettingsMenu:onFrameOpen()
	print("ModSettingsMenu:onFrameOpen")
	ModSettingsMenu:superClass().onFrameOpen(self)

	-- self:initModPages()
	-- self.isOpening = true
end

function ModSettingsMenu:updateButtons()
	print("ModSettingsMenu:updateButtons")

	-- self:setMenuButtonInfoDirty()
end

function ModSettingsMenu:onClickBinaryOption(id, control, direction)
	print("CLICKED " .. tostring(control.id) .. " = " .. tostring(not direction) .. " (" .. tostring(id) .. ")")
end
