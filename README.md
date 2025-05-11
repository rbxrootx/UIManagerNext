
# UIManagerNext - Roblox UI Management Library

UIManagerNext is a standalone Roblox library designed to simplify common UI management tasks, including:

*   Automatic device detection (PC, Mobile, Controller, Hybrid).
*   UI prioritization system (e.g., ensuring dialogs appear over settings).
*   Tag-based automatic UI adjustments for different devices.
*   Dynamic UI scaling for mobile devices.
*   A clean API for registering and controlling UI visibility.

## Features

*   **Device Detection:** Automatically detects if the player is using PC (Keyboard/Mouse), Mobile (Touch), Controller, or Hybrid (e.g., Touch + Keyboard).
*   **UI Prioritization:** Register UIs with priorities to control which UIs close when a higher-priority one opens.
*   **Tag-Based Device Visibility:** Tag `GuiObject` instances (like `TextLabel`, `ImageLabel`) to automatically show/hide them or change their appearance based on the current device.
*   **Tag-Based Mobile Scaling:** Tag `GuiObject` instances (that have a `UIScale` child) to automatically apply responsive scaling on mobile devices.
*   **Event-Driven:** Exposes a `DeviceChangedSignal` to allow custom logic when the input device changes.
*   **Configurable:** Customize tags, scaling parameters, and default UI priorities during initialization.

## Installation

1.  Create a `ModuleScript` in your Roblox game (e.g., in `ReplicatedStorage` or `StarterPlayerScripts`).
2.  Name it `UIManagerNext`.
3.  Copy and paste the `UIManagerNext` code into this ModuleScript.

## Getting Started

### 1. Initialization

First, require and initialize the UIManagerNext module. This is typically done in a local script that runs once for the player (e.g., a script in `StarterPlayerScripts`).

```lua
-- In a LocalScript (e.g., MyGameClient > UIInitializer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIManagerNext = require(ReplicatedStorage.UIManagerNext) -- Adjust path if needed

-- Optional: Define custom configuration
local customConfig = {
    uiPriorities = {
        MAIN_MENU = 10,
        POPUP = 20,
        LOADING_SCREEN = 100,
    },
    mobileScaleTag = "MyCustomMobileScaleTag" -- If you want to use a different tag
}

UIManagerNext.init(customConfig) -- Pass nil or omit if using defaults

print("UIManagerNext initialized. Current device:", UIManagerNext.getCurrentDeviceType())
```

### 2. Using Tags for Automatic Adjustments

#### a. Device-Specific Visibility (deviceVisibilityTag)

Tag GuiObject instances with the configured deviceVisibilityTag (default: "DeviceContext") to have them automatically update.

**TextLabels:**
- Visible on PC.
- Hidden on Controller, Mobile, Hybrid.

**ImageLabels with "ControllerButton" Attribute:**
- Visible on Controller. The image will be automatically set using UserInputService:GetImageForKeyCode() based on the ControllerButton attribute's value (e.g., "A", "L1", "DPadUp"). See config.controllerButtonMappings for available keys.
- Hidden on PC, Mobile, Hybrid.

**Example:**
- Create a TextLabel for a PC keybind hint: "Press E to Interact".
- Add a tag "DeviceContext" to this TextLabel using the Tag Editor or CollectionService:AddTag().
- Create an ImageLabel for a controller button hint.
- Add a tag "DeviceContext" to this ImageLabel.
- Add a String Attribute named "ControllerButton" to the ImageLabel with a value like "X".

The TextLabel will show on PC, and the ImageLabel (displaying the Xbox X button) will show on Controller. Both will be hidden on Mobile.

#### b. Mobile Scaling (mobileScaleTag)

Tag GuiObject instances (e.g., a Frame or BillboardGui) with the configured mobileScaleTag (default: "MobileScale") to enable automatic scaling on mobile devices.

The tagged element must have a UIScale instance as a direct child. The library will adjust the UIScale.Scale property.

**Example:**
- You have a BillboardGui that you want to scale down on smaller mobile screens.
- Add a UIScale instance as a child of this BillboardGui.
- Add a tag "MobileScale" to the BillboardGui.
- (Optional) The library will automatically store the UIScale's initial scale in an attribute named "OriginalUIScale" on the BillboardGui.

On mobile devices, the UIScale.Scale will be dynamically adjusted based on the screen width, making the UI smaller. On PC/Controller, it will revert to its original scale.

### 3. Registering and Managing UI Windows

Manage the visibility and layering of your UI windows (Frames, ScreenGuis, etc.).

```lua
-- In a LocalScript managing your Inventory UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIManagerNext = require(ReplicatedStorage.UIManagerNext)

local inventoryFrame = script.Parent -- Assuming this script is a child of the Inventory Frame

local PRIORITIES = UIManagerNext.getPriorities() -- Get default or custom priorities

local inventoryController = UIManagerNext.registerUI("Inventory", {
    priority = PRIORITIES.DEFAULT, -- Or your custom priority, e.g., UIManagerNext.getConfig().uiPriorities.MAIN_MENU
    openFunc = function()
        inventoryFrame.Visible = true
        print("Inventory Opened")
    end,
    closeFunc = function()
        inventoryFrame.Visible = false
        print("Inventory Closed")
    end
})
```

### 4. Listening to Device Changes

You can react to device changes for custom UI logic (like your original "Tutorial" UI example).

```lua
-- In a LocalScript managing a tutorial UI

local UIManagerNext = require(ReplicatedStorage.UIManagerNext) -- Adjust path

local tutorialSurfaceGui = workspace.SomePart.TutorialSurfaceGui -- Example
local pcTutorialFrame = tutorialSurfaceGui.PCHints
local mobileTutorialFrame = tutorialSurfaceGui.MobileHints
local controllerTutorialFrame = tutorialSurfaceGui.ControllerHints

local function updateTutorialVisibility(deviceType)
    pcTutorialFrame.Visible = (deviceType == "PC")
    mobileTutorialFrame.Visible = (deviceType == "Mobile" or deviceType == "Hybrid")
    controllerTutorialFrame.Visible = (deviceType == "Controller")
end

updateTutorialVisibility(UIManagerNext.getCurrentDeviceType())

UIManagerNext.DeviceChangedSignal:Connect(function(newDevice, oldDevice)
    updateTutorialVisibility(newDevice)
end)
```

## API Reference

### Initialization

```lua
UIManagerNext.init(userConfig?: table)
```

### Core Functions

```lua
UIManagerNext.refreshUIState()
UIManagerNext.getCurrentDeviceType()
UIManagerNext.getPriorities()
UIManagerNext.getConfig()
```

### UI Window Management

```lua
UIManagerNext.registerUI(uiName: string, options: table): table_controller
UIManagerNext.getController(uiName: string): table_controller | nil
UIManagerNext.openUI(uiName: string)
UIManagerNext.closeUI(uiName: string)
UIManagerNext.toggleUI(uiName: string)
UIManagerNext.isUIOpen(uiName: string): boolean
UIManagerNext.closeAllUIs()
```

### Events

```lua
UIManagerNext.DeviceChangedSignal:Connect(callback: function): Connection
```

### Configuration Options (Defaults)

```lua
{
    deviceVisibilityTag = "DeviceContext",
    mobileScaleTag = "MobileScale",
    mobileScaling = {
        referenceViewportWidth = 414,
        targetFactorAtReferenceWidth = 2.5,
        minScaleFactor = 1.0,
        maxScaleFactor = 3.5,
    },
    uiPriorities = {
        LOW = 1, DEFAULT = 5, IMPORTANT = 10, OVERLAY = 20, CRITICAL = 100,
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
}
```
