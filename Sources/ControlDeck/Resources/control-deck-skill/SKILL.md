---
name: control-deck-customizer
description: Customize ControlDeck mappings, pointer settings, app assignments and behavior. Use when a user asks Codex to inspect, remap, tune, troubleshoot, or extend their controller interface.
---

# PS5 Controller Customizer

1. Call `list_profiles` and `get_profile`, or `get_shift_layer` for skill slots.
2. Use the narrowest `control-deck` MCP mutation tool.
3. Preserve unrelated mappings and never invent input names.
4. Read the changed profile again and report the exact result.
5. Tell the user to return to ControlDeck to reload external changes.

Use MCP for profile and custom skill-slot changes. Source-code changes are
appropriate only when the requested behavior cannot be represented by a
mapping, pointer setting, skill slot, or app assignment.

Examples include remapping Terminal interrupt or moving Meetings raise hand to
a preferred button. App-specific actions are valid wherever a profile accepts
a normal button mapping.
