---
name: control-deck-customizer
description: Customize ControlDeck mappings, pointer settings, touch gestures, app assignments, feedback, and controller behavior. Use when a user asks Codex to inspect, remap, tune, troubleshoot, or extend their game-controller interface for Codex or macOS.
---

# PS5 Controller Customizer

Use the `control-deck` MCP tools for profile and custom skill-slot changes.
Edit the app source only when the user explicitly requests behavior that the
preference schema cannot represent.

## Workflow

1. Call `list_profiles`, or `get_shift_layer` for an Options + D-pad skill.
2. Call `get_profile` for every profile that may change.
3. Explain the proposed mapping in one concise sentence.
4. Use the narrowest mutation tool:
   - `set_button_mapping` for one button.
   - `set_pointer` for the pointer stick or tracking values.
   - `assign_profile_apps` for foreground-app switching.
   - `set_skill_slot` for one Options + D-pad title and prompt.
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
- “Map Triangle to open the browser address bar.”
- “Use my 8BitDo controller with the General profile.”
- “Make Options + D-pad Up run my release-check skill.”
- “Add a new controller action.” This requires a source change because MCP
  profile tools can select behavior but cannot define executable behavior.
