# Architecture

- `InputMappingModels.swift`: actions, profiles, pointer and gesture defaults.
- `ExpandedProfileCatalog.swift`: app-specific layouts and action categories.
- `GyroModels.swift`: motion samples, settings and gesture recognition.
- `GyroMiniGameView.swift`: isolated tilt-ball calibration playground.
- `ProfileStore.swift`: persistence and foreground-app switching.
- `ProfileTransfer.swift`: versioned JSON import/export and strict validation.
- `AppModel.swift`: event routing, hybrid dictation, feedback and screenshots.
- `ShiftLayerModels.swift`: eight-slot profile wheel and stepped reasoning.
- `ControllerOverlayController.swift`: non-activating radial/context overlays.
- `ScreenshotEditorModels.swift`: capture preferences and annotation state.
- `ScreenshotEditorController.swift`: editor window, canvas and controller UI.
- `QuickTutorial.swift`: optional setup walkthrough and controller navigation.
- `DualSenseControllerService.swift`: normalized input and DualSense hardware.
- `PointerService.swift`: pointer, clicks, scrolling and screenshot drag.
- `DashboardView.swift`: mappings, profiles, setup and Codex customization.

Use MCP for profile and profile-wheel changes. New executable actions,
controller protocols, audio behavior or interface features require source
changes and verification.
