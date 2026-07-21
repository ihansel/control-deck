# ControlDeck

<p align="center">
  <img src="Design/Brand/previews/control-deck-logo-horizontal.png" alt="ControlDeck logo: square, triangle, cross and ChatGPT knot" width="560">
</p>

<p align="center">
  <strong>Turn the controller already on your desk into a tactile command deck for Codex and macOS.</strong>
</p>

<p align="center">
  Speak prompts, move between tasks, review changes, control the pointer and
  feel your agent's state through lights and haptics—without breaking your flow.
</p>

<p align="center">
  <img alt="macOS 14.2 or later" src="https://img.shields.io/badge/macOS-14.2%2B-111111?logo=apple&logoColor=white">
  <img alt="Swift 6.2 or later" src="https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white">
  <img alt="MIT licensed" src="https://img.shields.io/badge/license-MIT-c9ff3d?labelColor=111111">
  <img alt="Built with Codex" src="https://img.shields.io/badge/built%20with-Codex-64f4ff?labelColor=111111">
</p>

<p align="center">
  <a href="https://github.com/ihansel/control-deck/archive/refs/heads/main.zip"><strong>Download the source</strong></a>
  · <a href="#build-it-yourself">Build it yourself</a>
  · <a href="#meet-your-new-coding-loop">Explore the controls</a>
  · <a href="Docs/BluetoothMicrophone.md">Bluetooth microphone</a>
</p>

<p align="center">
  <img src="Sources/ControlDeck/Resources/dualsense-hero.png" alt="A DualSense controller ready to use with ControlDeck" width="900">
</p>

ControlDeck is a native macOS app that makes a compatible game controller feel
like a purpose-built interface for Codex. Buttons become agent actions, sticks
become pointer and navigation controls, the touchpad scrolls, and the controller
responds to your work with light, haptics, adaptive triggers and optional sound.

It is useful beyond Codex, too. ControlDeck automatically switches layouts as
you move between apps, giving Finder, browsers, meetings, presentations,
creative tools, media apps, terminals and code editors controls that make sense
in their own context.

> [!NOTE]
> ControlDeck is an independent open-source project built with Codex and
> GPT-5.6. It is not affiliated with or endorsed by OpenAI or Sony Interactive
> Entertainment.

## Why you might love it

| Stay in flow | Use the whole controller | Make it yours |
| --- | --- | --- |
| Create tasks, dictate prompts, stop runs, review changes and jump between work without hunting for shortcuts. | Use analogue pointer control, smooth scrolling, touch gestures, click-and-drag, screenshots and tactile feedback. | Remap every input, tune acceleration and dead zones, add custom skills and let profiles follow the foreground app. |

### A few favourite details

- **Tap or hold L2 to talk.** Tap for hands-free capture, or hold it like a
  walkie-talkie and release when you are done.
- **The controller reflects Codex state.** Light and haptics make thinking,
  completion and attention states feel immediate.
- **Options is a real command layer.** Hold it for Approve, Decline, Send, Fast
  mode and four editable skill slots without crowding the everyday controls.
- **The pointer can replace a mouse.** Move across multiple displays, scroll in
  two axes, drag windows, highlight text and right-click.
- **Profiles follow your work.** Move from Codex to Terminal, a meeting or a
  creative app and ControlDeck changes with you.

## Meet your new coding loop

The supplied Codex profile is designed around a simple physical vocabulary:

| What you want to do | Controller action |
| --- | --- |
| Point, click and drag | Left stick + Cross |
| Scroll vertically or horizontally | Right stick or touchpad |
| Speak a prompt | Tap or hold L2 |
| Send / stop / review / plan | D-pad Up / Circle / Square / Triangle |
| Move between tasks | L1 / R1 |
| Start a new task | Create |
| Capture a selected area | Hold R2 and move the left stick |
| Open quick chat / terminal | L3 / R3 |
| Focus Codex | PS button |
| Show the current profile and mappings | Touchpad click |
| Toggle hands-free dictation | Microphone button |

Hold **Options** for the command layer:

- D-pad: four editable Codex skill slots
- Cross / Circle: Approve / Decline
- Square / Triangle: Send / toggle Fast mode
- Create + right stick: step reasoning smarter or faster

Everything can be changed in the mapping editor and is saved immediately.

## The undocumented Bluetooth microphone

One of the most interesting parts of ControlDeck started with a missing device:
macOS recognized the Bluetooth DualSense as a controller, but did not expose its
built-in microphone as a normal audio input.

**Codex found the undocumented wireless audio path—and built the bridge.**

```text
DualSense microphone → wireless audio → decode and buffer
                     → macOS input “DualSense Microphone” → Codex
```

ControlDeck publishes the result as a stable, selectable 48 kHz microphone. It
works with Codex's normal capture and transcription, does not permanently
replace the Mac's default microphone, and carefully separates audio packets
from controller input so speech cannot become phantom button presses.

USB uses the controller's physical audio device. Bluetooth uses the userspace
bridge and requires no administrator installation or custom audio driver.

[Read how the Bluetooth microphone works →](Docs/BluetoothMicrophone.md)

## App-aware profiles

ControlDeck includes sixteen curated profile groups covering Codex, Claude,
everyday macOS navigation, communication, presentations, creative work, media,
terminals and development tools.

<details>
<summary><strong>See the included app coverage</strong></summary>

- Codex and Claude
- Finder and general macOS navigation
- Safari, Chrome and other browsers
- Zoom, Microsoft Teams and Google Meet
- Keynote, PowerPoint and Google Slides
- Slack and Mail
- Photos, Spotify and media apps
- Figma
- Final Cut Pro, Premiere Pro and DaVinci Resolve
- Logic Pro
- Terminal, iTerm, Warp and Ghostty
- Xcode and common code editors

Native apps are matched by bundle identifier. Browser-hosted tools such as
Google Meet, Slides and Figma can also switch from the active window title.

</details>

Claude follows the same pointer-first vocabulary as Codex wherever equivalent
actions exist. The Terminal profile keeps consequential commands deliberate:
navigation, history, tabs, search, copy/paste, dictation and screenshots are
easy to reach, while interrupt and split-pane operations remain optional
remappings.

## Supported controllers

**DualSense provides the complete experience:** buttons, sticks, touchpad,
battery state, light bar, haptics, adaptive triggers, microphone, microphone
LED and app-generated speaker cues.

DualShock 4, Switch Pro, Switch 2 Pro, 8BitDo and compatible extended gamepads
also work through normalized buttons, sticks, app profiles and any haptics the
controller exposes. Hardware-specific features simply stay unavailable rather
than breaking the rest of the profile.

## Build it yourself

### What you need

- macOS 14.2 or later
- Swift 6.2 or newer through Xcode or the Xcode Command Line Tools
- A compatible controller connected by USB or Bluetooth
- The Codex desktop app for Codex-specific actions and task feedback
- An internet connection for the first build to download the pinned official
  Opus audio-codec source archive

### Build in three commands

```bash
git clone https://github.com/ihansel/control-deck.git
cd control-deck
./scripts/build-app.sh
```

The finished app is written to `dist/ControlDeck.app`. Open it with:

```bash
open dist/ControlDeck.app
```

For the everyday development loop, build and launch in one command:

```bash
./script/build_and_run.sh
```

The local bundle is ad-hoc signed for development on the Mac that built it.
Public downloads must use Developer ID signing and Apple notarization; the
release process deliberately fails closed instead of asking users to bypass
Gatekeeper. See [the distribution guide](Docs/Distribution.md).

## First-time setup

1. Connect a controller by USB or Bluetooth.
2. Launch ControlDeck and open **Setup**.
3. Grant Accessibility permission for pointer and keyboard automation.
4. Run the safe hardware self-test: one gentle haptic and one short tone.
5. Open **Button Mapping**, **Touchpad** or **Pointer** and make the controller
   feel like yours.

To pair a DualSense wirelessly, disconnect USB and hold **Create + PS** until
the light bar flashes rapidly. Select **DualSense Wireless Controller** in
macOS Bluetooth settings.

For wireless controller dictation, prepare the microphone from **Setup**, then
choose **DualSense Microphone** once in Codex Settings → General.

## Customize it by talking to Codex

ControlDeck ships with a `control-deck-customizer` skill and a deliberately
narrow local MCP server. Open **Customize with Codex**, install the readable
local workspace and describe the change you want:

> “Make R3 open Quick Chat in Codex, and use Options + D-pad Left for my PR
> review skill.”

The customization server can only read and update ControlDeck profiles and the
four custom skill slots. It exposes no general shell, filesystem, network,
permission or download tool.

## Privacy and safety

- No network requests are made by the running app.
- No privileged helper or login item is installed.
- Gatekeeper is never disabled and quarantine attributes are never removed.
- Accessibility is used only for controller-driven pointer, keyboard and
  semantic interface actions.
- Recent Codex task identifiers, titles, timestamps and terminal states are
  read locally for feedback; prompts and responses are not stored.
- The wireless microphone bridge taps only its own private muted audio source,
  not other apps or the system mix.

## Development and verification

Run the framework-free logic, protocol and security checks:

```bash
./scripts/test.sh
```

Run a full debug build:

```bash
swift build -c debug
```

The suite covers default mappings, shift layers, gesture classification,
pointer behaviour, task-state inference, profile persistence, Bluetooth audio
framing and the customization security boundary.

### Project structure

- `Sources/ControlDeck`: SwiftUI application, controller engine and resources
- `Tests/ControlDeckTests`: framework-free logic and protocol checks
- `Docs`: Bluetooth microphone and safe-distribution documentation
- `.agents/skills/control-deck-customizer`: bundled customization skill
- `Drivers/DualSenseMicrophone`: retained Core Audio driver prototype; not used
  by the normal application

## Frequently asked questions

<details>
<summary><strong>Do I need a DualSense?</strong></summary>

No. DualSense has the richest hardware integration, but compatible extended
controllers still get normalized input, pointer control, remapping and app
profiles.

</details>

<details>
<summary><strong>Does the Bluetooth controller microphone really work?</strong></summary>

Yes. ControlDeck decodes the controller's undocumented wireless audio stream
and publishes it as a normal macOS input named **DualSense Microphone**. It
requires macOS 14.2 or later.

</details>

<details>
<summary><strong>Does ControlDeck send my work anywhere?</strong></summary>

No. The running app makes no network requests. Codex task metadata used for
local feedback remains on the Mac, and prompts and responses are not stored by
ControlDeck.

</details>

<details>
<summary><strong>Can I change every mapping?</strong></summary>

Yes. Use the visual mapping editor, or ask Codex to update a profile through
the bundled constrained customization workspace.

</details>

## Licence and credits

ControlDeck is available under the [MIT License](LICENSE). Opus and Apple
sample-derived components retain their notices in `Resources/ThirdPartyLicenses`
and `Drivers/DualSenseMicrophone`.

Built by [@ihansel](https://x.com/ihansel) with Codex and a real controller on
the desk.
