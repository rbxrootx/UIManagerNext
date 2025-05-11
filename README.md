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
