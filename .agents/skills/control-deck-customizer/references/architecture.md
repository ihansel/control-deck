# Architecture

- `InputMappingModels.swift`: actions, profiles, pointer and gesture defaults.
- `ExpandedProfileCatalog.swift`: app-specific layouts and action categories.
- `ProfileStore.swift`: persistence and foreground-app switching.
- `AppModel.swift`: event routing, hybrid dictation, feedback and screenshots.
- `ShiftLayerModels.swift`: Options-layer skill slots and stepped reasoning.
- `ControllerOverlayController.swift`: non-activating radial/context overlays.
- `DualSenseControllerService.swift`: normalized input and DualSense hardware.
- `PointerService.swift`: pointer, clicks, scrolling and screenshot drag.
- `DashboardView.swift`: mappings, profiles, setup and Codex customization.

Use MCP for profile and shift-layer skill-slot changes. New executable actions,
controller protocols, audio behavior or interface features require source
changes and verification.
