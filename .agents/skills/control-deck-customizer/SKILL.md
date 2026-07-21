---
name: control-deck-customizer
description: Customize ControlDeck mappings, pointer settings, touch gestures, app assignments, feedback, and controller behavior. Use when a user asks Codex to inspect, remap, tune, troubleshoot, or extend their game-controller interface for Codex or macOS.
---

# PS5 Controller Customizer

Use the `control-deck` MCP tools for profile and profile-wheel changes.
Edit the app source only when the user explicitly requests behavior that the
preference schema cannot represent.

## Workflow

1. Call `list_profiles`, or `get_profile_wheel` for the eight Options-wheel
   slots.
2. Call `get_profile` for every profile that may change.
3. Explain the proposed mapping in one concise sentence.
4. Use the narrowest mutation tool:
   - `set_button_mapping` for one button.
   - `set_pointer` for the pointer stick or tracking values.
   - `set_gyro` for motion thresholds and enablement.
   - `set_gyro_mapping` for one shake, tilt, or twist gesture.
   - `assign_profile_apps` for foreground-app switching.
   - `set_profile_wheel_slot` to assign or swap one of eight profiles.
5. Read the changed profile again and report the exact result.
6. Tell the user to return to ControlDeck so the running app reloads settings.

## Safety

- Preserve unrelated mappings.
- Never pass an undocumented input name.
- Prefer reversible profile changes over source edits.
- Do not change macOS accessibility, privacy, microphone, or Bluetooth settings.
- Do not run broad shell commands through an MCP tool; this server intentionally
  exposes none.
- For source-code changes, inspect `references/architecture.md` first and run
  `./scripts/test.sh` plus `swift build -c debug`.

## Common requests

- “Make the left stick control the cursor in Claude.”
- “Map Terminal R3 to interrupt instead of clear.”
- “Put raise hand on Triangle in my Meetings profile.”
- “Map a clockwise gyro twist to the next browser tab.”
- “Map Triangle to open the browser address bar.”
- “Use my 8BitDo controller with the General profile.”
- “Put Xcode in slot 4 of my Options profile wheel.”
- “Add a new controller action.” This requires a source change because MCP
  profile tools can select behavior but cannot define executable behavior.
