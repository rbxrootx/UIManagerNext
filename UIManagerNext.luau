-- UIManagerNext (ModuleScript)

local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService") -- For waiting for camera if needed

local UIManagerNext = {}
UIManagerNext.__index = UIManagerNext

-- Internal State
local _isInitialized = false
local _config = {}
local _activeUIs = {} -- { [uiName: string]: { priority: number, closeFunc: () -> (), openFunc: () -> () } }
local _uiControllers = {} -- { [uiName: string]: { open: () -> (), close: () -> (), toggle: () -> () } }
local _currentDeviceType = "PC" -- Default

-- Signals
local _deviceChangedSignalCallbacks = {}

-- Helper: Simple Signal Emitter
local function fireDeviceChangedSignal(newDevice, oldDevice)
	for _, callback in ipairs(_deviceChangedSignalCallbacks) do
		task.spawn(callback, newDevice, oldDevice)
	end
end

-- Helper: Close UIs with lower priority
local function _closeLowerPriorityUIs(priorityToKeep: number)
	for uiName, data in pairs(_activeUIs) do
		if data.priority < priorityToKeep then
			if data.closeFunc then
				pcall(data.closeFunc) -- Protect against errors in user's close function
			end
			_activeUIs[uiName] = nil
		end
	end
end

-- Helper: Get Viewport Size
local function _getViewportSize(): Vector2
	if _config and _config.getViewportSize then
		return _config.getViewportSize()
	end

	-- Default implementation
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	-- Fallback for ScreenGuis if camera isn't ready (e.g., very early init)
	local player = Players.LocalPlayer
	if player and player.PlayerGui then
		local mainScreenGui = player.PlayerGui:FindFirstChildOfClass("ScreenGui") -- Or a specific one
		if mainScreenGui then
			return mainScreenGui.AbsoluteSize
		end
	end
	return Vector2.new(1920, 1080) -- Absolute fallback
end


--[[
	PRIVATE: Updates elements tagged with config.deviceVisibilityTag
	Handles visibility of elements based on device type and element attributes.
	- TextLabel: Visible on PC, hidden on Controller/Mobile/Hybrid.
	- ImageLabel (with ControllerButton attribute): Visible on Controller, hidden otherwise.
	  Updates image based on ControllerButton attribute.
]]
local function _updateDeviceVisibilityElements(deviceType)
	if not _config.deviceVisibilityTag then return end

	local elements = CollectionService:GetTagged(_config.deviceVisibilityTag)
	for _, element in ipairs(elements) do
		if deviceType == "Controller" then
			if element:IsA("ImageLabel") then
				local buttonType = element:GetAttribute("ControllerButton")
				if buttonType and _config.controllerButtonMappings[buttonType] then
					local keyCode = _config.controllerButtonMappings[buttonType]
					local buttonImage = UserInputService:GetImageForKeyCode(keyCode)
					if buttonImage then
						element.Image = buttonImage
						element.Visible = true
					else
						element.Visible = false -- No image for this button
					end
				else
					element.Visible = false -- Not a configured controller button element
				end
			elseif element:IsA("TextLabel") then
				element.Visible = false
			else
				-- Handle other types or default visibility if needed
				-- For now, non-specified types with this tag might remain visible or follow parent
			end
		elseif deviceType == "Mobile" or deviceType == "Hybrid" then
			element.Visible = false -- General rule: hide these tagged elements on mobile/hybrid
		else -- PC
			if element:IsA("TextLabel") then
				element.Visible = true
			elseif element:IsA("ImageLabel") and element:GetAttribute("ControllerButton") then
				element.Visible = false -- Hide controller button images on PC
			else
				-- Handle other types
			end
		end
	end
end

--[[
	PRIVATE: Updates elements tagged with config.mobileScaleTag
	Scales UI elements down on mobile devices.
	Looks for a UIScale child and adjusts its Scale property.
	Stores original scale in "OriginalUIScale" attribute on the tagged element.
]]
local function _updateMobileScalingElements(deviceType)
	if not _config.mobileScaleTag then return end

	local elements = CollectionService:GetTagged(_config.mobileScaleTag)
	local viewportSize = _getViewportSize()

	for _, element in ipairs(elements) do
		local uiScaleInstance = element:FindFirstChildWhichIsA("UIScale")
		if not uiScaleInstance then
			-- Fallback: Try searching recursively if not a direct child (though direct is preferred for performance)
			uiScaleInstance = element:FindFirstChildWhichIsA("UIScale", true)
			if not uiScaleInstance then
				warn("[UIManagerNext] Element tagged with '".._config.mobileScaleTag.."' has no UIScale child:", element:GetFullName())
				continue
			end
		end

		local originalScale = element:GetAttribute("OriginalUIScale")
		if originalScale == nil then
			originalScale = uiScaleInstance.Scale
			element:SetAttribute("OriginalUIScale", originalScale)
		end

		if deviceType == "Mobile" then
			local currentWidth = viewportSize.X
			local dynamicFactor = _config.mobileScaling.targetFactorAtReferenceWidth
			if currentWidth > 0 then -- Avoid division by zero
				dynamicFactor = math.clamp(
					_config.mobileScaling.targetFactorAtReferenceWidth * (_config.mobileScaling.referenceViewportWidth / currentWidth),
					_config.mobileScaling.minScaleFactor,
					_config.mobileScaling.maxScaleFactor
				)
			end
			uiScaleInstance.Scale = originalScale / dynamicFactor
		else
			-- Restore original size if not mobile
			if uiScaleInstance.Scale ~= originalScale then
				uiScaleInstance.Scale = originalScale
			end
		end
	end
end


-- PUBLIC API

--- Initializes the UIManagerNext. Must be called before other functions.
-- @param userConfig (Optional) Table: Configuration options.
-- @return UIManagerNext
function UIManagerNext.init(userConfig)
	if _isInitialized then
		warn("[UIManagerNext] Already initialized.")
		return UIManagerNext
	end

	-- Default Configuration
	_config = {
		deviceVisibilityTag = "DeviceContext", -- Tag for elements whose visibility depends on device
		mobileScaleTag = "MobileScale",       -- Tag for UI elements to be scaled on mobile

		mobileScaling = {
			referenceViewportWidth = 414, -- Reference width (e.g., iPhone 8 Plus)
			targetFactorAtReferenceWidth = 2.5, -- Desired scaling factor AT the reference width
			minScaleFactor = 1.0,          -- Minimum scaling factor (no scaling down)
			maxScaleFactor = 3.5,          -- Maximum scaling factor (for very small screens)
		},

		uiPriorities = { -- Default priorities, can be overridden
			LOW = 1,
			DEFAULT = 5,
			IMPORTANT = 10,
			OVERLAY = 20,
			CRITICAL = 100,
		},

		controllerButtonMappings = {
			L2 = Enum.KeyCode.ButtonL2, R2 = Enum.KeyCode.ButtonR2,
			L1 = Enum.KeyCode.ButtonL1, R1 = Enum.KeyCode.ButtonR1,
			A = Enum.KeyCode.ButtonA,   B = Enum.KeyCode.ButtonB,
			X = Enum.KeyCode.ButtonX,   Y = Enum.KeyCode.ButtonY,
			L3 = Enum.KeyCode.ButtonL3, R3 = Enum.KeyCode.ButtonR3,
			Start = Enum.KeyCode.ButtonStart, Select = Enum.KeyCode.ButtonSelect,
			DPadUp = Enum.KeyCode.DPadUp, DPadDown = Enum.KeyCode.DPadDown,
			DPadLeft = Enum.KeyCode.DPadLeft, DPadRight = Enum.KeyCode.DPadRight,
		},
		-- Optional: provide a custom function to get viewport size if default isn't suitable
		-- getViewportSize = function() return workspace.CurrentCamera.ViewportSize end,
	}

	-- Merge user config with defaults
	if userConfig then
		for key, value in pairs(userConfig) do
			if type(value) == "table" and type(_config[key]) == "table" then
				for subKey, subValue in pairs(value) do
					_config[key][subKey] = subValue
				end
			else
				_config[key] = value
			end
		end
	end

	-- Initial device detection
	local isMobile = UserInputService.TouchEnabled
	local isKeyboard = UserInputService.KeyboardEnabled
	local isMouse = UserInputService.MouseEnabled
	local connectedGamepads = UserInputService:GetConnectedGamepads()
	local isGamepad = #connectedGamepads > 0 and table.find(connectedGamepads, Enum.UserInputType.Gamepad1) ~= nil

	if isGamepad then -- Prioritize gamepad if connected at init
		_currentDeviceType = "Controller"
	elseif isMobile then
		_currentDeviceType = (isKeyboard and isMouse) and "Hybrid" or "Mobile"
	else
		_currentDeviceType = "PC"
	end

	-- Listeners
	UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
		local oldDeviceType = _currentDeviceType
		local newDeviceType = oldDeviceType

		if lastInputType == Enum.UserInputType.Gamepad1 then
			newDeviceType = "Controller"
		elseif lastInputType == Enum.UserInputType.Touch then
			-- If touch is last input, check if keyboard/mouse also enabled for Hybrid
			newDeviceType = (UserInputService.KeyboardEnabled and UserInputService.MouseEnabled) and "Hybrid" or "Mobile"
		elseif lastInputType == Enum.UserInputType.Keyboard or lastInputType == Enum.UserInputType.MouseButton1 or lastInputType == Enum.UserInputType.MouseMovement then
			-- If KBM is last input, check if touch also enabled for Hybrid
            newDeviceType = UserInputService.TouchEnabled and "Hybrid" or "PC"
		end

		if _currentDeviceType ~= newDeviceType then
			_currentDeviceType = newDeviceType
			UIManagerNext.refreshUIState()
			fireDeviceChangedSignal(_currentDeviceType, oldDeviceType)
		end
	end)

	local function gamepadConnectionChanged()
		local oldDeviceType = _currentDeviceType
		local anyGamepadConnected = #UserInputService:GetConnectedGamepads() > 0

		if anyGamepadConnected and _currentDeviceType ~= "Controller" then
			-- If a gamepad connects and we weren't in controller mode, switch if it's the primary gamepad
			if table.find(UserInputService:GetConnectedGamepads(), Enum.UserInputType.Gamepad1) then
				_currentDeviceType = "Controller"
			end
		elseif not anyGamepadConnected and _currentDeviceType == "Controller" then
			-- If all gamepads disconnect and we were in controller mode, fallback
			if UserInputService.TouchEnabled then
				_currentDeviceType = (UserInputService.KeyboardEnabled and UserInputService.MouseEnabled) and "Hybrid" or "Mobile"
			else
				_currentDeviceType = "PC"
			end
		end
		
		if _currentDeviceType ~= oldDeviceType then
			UIManagerNext.refreshUIState()
			fireDeviceChangedSignal(_currentDeviceType, oldDeviceType)
		end
	end

	UserInputService.GamepadConnected:Connect(gamepadConnectionChanged)
	UserInputService.GamepadDisconnected:Connect(gamepadConnectionChanged)

	_isInitialized = true
	UIManagerNext.refreshUIState() -- Initial refresh
	fireDeviceChangedSignal(_currentDeviceType, nil) -- Fire initial device state

	return UIManagerNext
end

--- Refreshes UI elements based on the current device type.
-- Called automatically on device changes, but can be called manually if needed.
function UIManagerNext.refreshUIState()
	if not _isInitialized then warn("[UIManagerNext] Not initialized. Call init() first."); return end

	local deviceType = _currentDeviceType
	_updateDeviceVisibilityElements(deviceType)
	_updateMobileScalingElements(deviceType)
	-- Users can connect to DeviceChangedSignal to update their own specific UIs (like the tutorial example)
end

--- Gets the currently detected device type.
-- @return string "PC", "Mobile", "Controller", or "Hybrid"
function UIManagerNext.getCurrentDeviceType()
	return _currentDeviceType
end

--- Registers a UI with the manager.
-- @param uiName string: A unique name for this UI.
-- @param options table:
--    - priority (number): The priority level (higher means it stays open over lower priority UIs).
--                         Uses values from config.uiPriorities (e.g., _config.uiPriorities.DEFAULT).
--    - openFunc (function): Function to call to make the UI visible.
--    - closeFunc (function): Function to call to make the UI hidden.
-- @return table Controller for this UI with open(), close(), toggle() methods.
function UIManagerNext.registerUI(uiName, options)
	if not _isInitialized then warn("[UIManagerNext] Not initialized. Call init() first."); return nil end
	assert(type(uiName) == "string", "uiName must be a string")
	assert(type(options) == "table", "options must be a table")
	assert(type(options.priority) == "number", "options.priority must be a number")
	assert(type(options.openFunc) == "function", "options.openFunc must be a function")
	assert(type(options.closeFunc) == "function", "options.closeFunc must be a function")

	if _uiControllers[uiName] then
		warn("[UIManagerNext] UI already registered:", uiName)
		return _uiControllers[uiName]
	end

	local controller = {}

	function controller:open()
		if _activeUIs[uiName] then return end -- Already open

		_closeLowerPriorityUIs(options.priority)
		pcall(options.openFunc)
		_activeUIs[uiName] = {
			priority = options.priority,
			closeFunc = options.closeFunc,
			openFunc = options.openFunc, -- Store for toggle
		}
	end

	function controller:close()
		if _activeUIs[uiName] then
			pcall(options.closeFunc)
			_activeUIs[uiName] = nil
		end
	end

	function controller:toggle()
		if _activeUIs[uiName] then
			self:close()
		else
			self:open()
		end
	end
	
	function controller:isOpen()
		return _activeUIs[uiName] ~= nil
	end

	_uiControllers[uiName] = controller
	return controller
end

--- Gets the controller for a registered UI.
-- @param uiName string: The name of the UI.
-- @return table|nil The UI controller or nil if not found.
function UIManagerNext.getController(uiName)
	if not _isInitialized then warn("[UIManagerNext] Not initialized. Call init() first."); return nil end
	return _uiControllers[uiName]
end

--- Opens a registered UI by name.
-- @param uiName string: The name of the UI to open.
function UIManagerNext.openUI(uiName)
    local controller = UIManagerNext.getController(uiName)
    if controller then
        controller:open()
    else
        warn("[UIManagerNext] No UI registered with name:", uiName)
    end
end

--- Closes a registered UI by name.
-- @param uiName string: The name of the UI to close.
function UIManagerNext.closeUI(uiName)
    local controller = UIManagerNext.getController(uiName)
    if controller then
        controller:close()
    else
        warn("[UIManagerNext] No UI registered with name:", uiName)
    end
end

--- Toggles a registered UI by name.
-- @param uiName string: The name of the UI to toggle.
function UIManagerNext.toggleUI(uiName)
    local controller = UIManagerNext.getController(uiName)
    if controller then
        controller:toggle()
    else
        warn("[UIManagerNext] No UI registered with name:", uiName)
    end
end

--- Checks if a specific UI is currently open.
-- @param uiName string: The name of the UI.
-- @return boolean True if open, false otherwise.
function UIManagerNext.isUIOpen(uiName)
    if not _isInitialized then warn("[UIManagerNext] Not initialized. Call init() first."); return false end
    return _activeUIs[uiName] ~= nil
end

--- Closes all currently active UIs.
function UIManagerNext.closeAllUIs()
	if not _isInitialized then warn("[UIManagerNext] Not initialized. Call init() first."); return end
	for uiName, data in pairs(_activeUIs) do
		if data.closeFunc then
			pcall(data.closeFunc)
		end
	end
	table.clear(_activeUIs)
end

--- Gets the configured UI priority levels.
-- @return table
function UIManagerNext.getPriorities()
	if not _isInitialized then warn("[UIManagerNext] Not initialized. Call init() first."); return {} end
	return _config.uiPriorities
end

--- Connects a callback function to the DeviceChangedSignal.
-- The callback will receive `(newDeviceType: string, oldDeviceType: string | nil)`.
-- @param callback function
-- @return table Connection object with a `Disconnect` method.
function UIManagerNext.DeviceChangedSignal:Connect(callback)
	assert(type(callback) == "function", "Callback must be a function")
	table.insert(_deviceChangedSignalCallbacks, callback)
	return {
		Disconnect = function()
			for i, cb in ipairs(_deviceChangedSignalCallbacks) do
				if cb == callback then
					table.remove(_deviceChangedSignalCallbacks, i)
					break
				end
			end
		end
	}
end


return UIManagerNext
