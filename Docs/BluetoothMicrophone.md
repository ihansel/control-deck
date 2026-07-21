# DualSense Bluetooth Microphone

## What works

ControlDeck can present the microphone built into a
Bluetooth-connected DualSense as a selectable macOS Core Audio input named
**DualSense Microphone**.

This is not Bluetooth HFP, A2DP or a macOS-provided controller audio endpoint.
Sony carries the microphone signal in vendor-defined Bluetooth HID reports. The
app opens that stream over IOHID, decodes its Opus payloads and republishes the
PCM through a Core Audio process tap. The result behaves like an ordinary
microphone input. It is not the system default while idle.

The wireless microphone path requires macOS 14.2 or later. Buttons, touchpad,
sticks, light bar, haptics, adaptive triggers, microphone and microphone LED
work over Bluetooth. App-generated controller speaker tones also work over
Bluetooth through the same vendor HID transport.

## Feature boundaries

| Feature | USB | Bluetooth | Implementation note |
| --- | --- | --- | --- |
| Buttons, sticks and touchpad | Yes | Yes | Apple's Game Controller framework |
| Light bar, haptics and adaptive triggers | Yes | Yes | Capability-gated by what Game Controller exposes for the connected controller |
| Microphone and orange mic LED | Yes | Yes | USB Core Audio/report `0x02`; Bluetooth Opus-over-HID/report `0x31` |
| Controller speaker cues | Yes | Yes | USB Core Audio; Bluetooth 48 kHz stereo Opus in paced HID report `0x36` |
| Headset jack | Not managed | Not managed | Outside the current bridge |

While wireless capture is active, mapped pointer/button actions pause except for
L2 release and the microphone button. The DualSense reuses enhanced report
`0x31` for microphone audio; this guard prevents encoded speech from producing
phantom controls. Normal mappings resume as soon as capture stops.

## Setup

1. Disconnect USB. Hold **Create + PS** until the light bar flashes rapidly,
   then connect **DualSense Wireless Controller** in macOS Bluetooth settings.
2. Launch ControlDeck and open **Setup**. It should report
   **DualSense Microphone available** shortly after the transport changes to
   Bluetooth. If it does not, select **Prepare wireless microphone**.
3. Choose **DualSense Microphone** in Codex Settings → General, then start a
   capture once by holding L2 or pressing the microphone button. Allow
   **Codex** under both **System Settings → Privacy & Security → Microphone**
   and **Screen & System Audio Recording**. The second permission name refers
   to the Core Audio process tap behind this input; the bridge taps only its own
   muted audio source, not other applications or the system mix.
4. If macOS separately prompts for ControlDeck, allow the
   controller app as the owner of the private bridge.
5. ControlDeck keeps **DualSense Microphone** published while Bluetooth is
   connected and never changes the Mac's system-default microphone.

L2 provides push-to-talk with the supplied Codex profile. The microphone button
toggles hands-free capture. While idle, the controller is muted and its orange
microphone light is solid. The light turns off while capture is active. On
release, the app closes the controller stream and invokes Codex's normal native
transcription flow.

## Data path

```text
DualSense internal microphone
  → Bluetooth Classic HID input report 0x31
  → 71-byte Opus frame (48 kHz mono, 480 samples / 10 ms)
  → persistent libopus decoder
  → 50 ms PCM jitter buffer
  → private, muted AVAudioEngine source
  → Core Audio process tap
  → public aggregate input "DualSense Microphone"
  → stable selectable DualSense Microphone input
  → Codex native microphone capture and transcription
```

The speaker path runs in the opposite direction:

```text
App cue PCM (48 kHz stereo)
  → constant-bitrate 10 ms Opus frames (200 bytes)
  → audio route/state + silent haptics + speaker section
  → Bluetooth HID output report 0x36 (398 bytes, paced every 10 ms)
  → DualSense built-in speaker
```

The app sends a short silent lead-in and tail around each cue to prime and
drain the controller's wireless audio buffer. Speaker packets preserve the
current microphone state, allowing a cue and wireless dictation routing to
share the HID connection safely.

The process tap selects only the controller app's own audio process. Its
`muted` behavior prevents the microphone bridge from playing through the Mac's
speakers. The aggregate device is public so Electron/Chromium applications such
as Codex can enumerate it. Its stable UID is
`com.ianhansel.controldeck.controller-microphone`. USB and Bluetooth reuse this
same identity and swap only its backing source, so a Codex selection can
survive a transport change.

The bridge initially buffers 2,400 samples, or 50 ms at 48 kHz, before rendering
audio. It renders silence after an underrun instead of replaying old speech. If
a suspended consumer allows the queue to grow excessively, stale frames are
dropped back to a small working set so delayed speech is not inserted into a
later dictation.

No HAL driver, administrator installation or Audio Server restart is required.
The system-default input changes only for the active Codex dictation session
and is restored on stop, cancellation, disconnect and shutdown. A separate
virtual audio driver prototype exists under `Drivers/DualSenseMicrophone`, but
it is a fallback and is not used by the normal app.

## HID protocol

The implementation lives in
`Sources/ControlDeck/DualSenseBluetoothAudioProtocol.swift` and
`Sources/ControlDeck/DualSenseHIDService.swift`.

### Opening and closing capture

Two Bluetooth HID output reports are sent when capture changes:

| Report | Bytes | Purpose |
| --- | ---: | --- |
| `0x31` | 78 | Select the internal processed microphone, set mute/power state and control the orange mic LED |
| `0x32` | 142 | Open (`0xFF`) or close (`0xFE`) the wireless microphone stream |

Speaker playback additionally uses:

| Report | Bytes | Purpose |
| --- | ---: | --- |
| `0x32` | 142 | Initialize the tagged wireless audio-section transport |
| `0x31` | 78 | Select the built-in speaker route while preserving the current microphone state |
| `0x36` | 398 | Carry one 10 ms, 200-byte stereo Opus speaker frame plus the required state and silent-haptics sections |

Report `0x36` is paced at the audio frame interval instead of being sent in a
burst. The controller-speaker section is tagged `0x93`; the packet retains the
microphone route fields whenever capture is active. Speaker-only packets set
the audio-section mask to `0xFE`; bit zero is reserved for the microphone
uplink and must never be enabled by a speaker test.

Both reports contain a four-bit sequence and end with Sony's Bluetooth output
checksum. The checksum is standard reflected CRC-32 (polynomial `0xEDB88320`)
over an implicit HIDP output prefix byte `0xA2` followed by every report byte
before the four-byte checksum. It is written little-endian.

For stream report `0x32`, the current controller-compatible body is:

```text
32 [sequence << 4] 91 07 [FF=open | FE=close]
40 40 40 40 40 [sequence] 92 40 ...
```

### Receiving audio

Wireless microphone audio arrives with report ID `0x31`. The low nibble of the
vendor type byte is `0x02`, followed by exactly 71 bytes of Opus data. Each
payload decodes to 480 mono samples at 48 kHz: one 10 ms audio frame.

The full on-wire report is 78 bytes: the report ID, two vendor header bytes, the
71-byte Opus frame and a four-byte checksum. Some IOHID callback paths strip the
report ID and therefore deliver 77 bytes to the application.

IOHID callbacks can include the report ID at byte zero or provide it separately.
The parser accepts both layouts, taking the Opus payload at offset 3 or 2
respectively. Once an audio payload is recognized it returns immediately;
encoded Opus bytes must never fall through to the controller-state parser,
where they could otherwise look like random button or pointer events.
Game Controller callbacks are also suppressed at their entry while capture is
open. Stop controls come only from validated type-1 raw HID state reports.
After a close command, the app retries at 100 and 250 ms and waits for both a
real control report and at least 100 ms without audio before re-enabling normal
controller input.

The decoder produces mono PCM. The audio source copies each sample into both
channels of the public 48 kHz aggregate input for broad application
compatibility.

## Connection and reconnection

On a Bluetooth connection the app detaches the physical USB source from the
stable aggregate, starts its silent audio source and attaches the process tap.
Publishing the input and opening the controller stream are separate operations:
the input can remain visible and silent while no dictation is active.

If the controller disconnects or changes transport during capture, the app
stops Codex dictation, clears the decoder and renders silence instead of
stranding an active voice session. Reconnect by pressing PS, wait for the
status card to return to **Bluetooth**, then start L2 capture again; the app
resets the Opus decoder and jitter buffer before reopening report `0x32`.

If the controller reconnects over USB, the Bluetooth tap is torn down and the
app switches **DualSense Microphone** back to the controller's physical USB
audio endpoint. Codex can continue using the same displayed device name,
although reopening Codex may be needed if its cached Core Audio object changed.

## Troubleshooting

### Codex shows only System Default

- Confirm ControlDeck says **DualSense Microphone available**, then close and
  reopen the microphone menu in Codex Settings → General. Codex enumerates the
  inputs when the menu opens, so the bridge must already be published.
- Confirm the controller status says **Bluetooth**, not USB or disconnected.
- In the app's Setup page, use **Prepare wireless microphone** and wait for
  **DualSense Microphone available**.
- Check **System Settings → Privacy & Security → Screen & System Audio
  Recording** and **Microphone** for Codex. If macOS previously prompted for
  ControlDeck as the bridge owner, check that entry too.
- Run `system_profiler SPAudioDataType` in Terminal. A working published bridge
  appears as an input device named `DualSense Microphone` at 48 kHz.

### The device is visible but silent

- Select **DualSense Microphone** in Codex.
- Hold L2 while speaking, or press the microphone button for hands-free mode.
  The controller sends audio only while the app has opened its HID stream.
- Watch the Setup level meter. No movement together with “No microphone packets
  yet” normally means the controller is still connected by USB, reconnected on
  a different transport, or needs to be disconnected and paired again.
- Recheck Screen & System Audio Recording permission. The device can be
  enumerated before macOS allows its process tap to deliver samples.

### The orange microphone light flashes

The intended bridge states are solid orange while muted/idle and off while
capturing. A continuing flash means the controller did not accept or retain the
microphone state report. Stop capture, disconnect USB, reconnect the controller
over Bluetooth and try L2 again. If the stream still does not open, power-cycle
the controller and check for a controller firmware update before retesting.

### Controls move by themselves during capture

Input report `0x31` is shared by enhanced controller state and microphone
audio. Current builds identify the audio subtype before parsing controls,
suppress Game Controller callbacks before they enqueue work, and use only
validated type-1 raw HID reports for the release/toggle that stops capture.
Run the current build and `./scripts/test.sh` if this behavior appears.

### The controller speaker is silent over Bluetooth

- Confirm the app status says **Bluetooth**, then run **Safe hardware
  self-test**. It performs only one gentle haptic and one short tone.
- Keep the controller close to the Mac during the test; speaker packets arrive
  every 10 ms and severe radio congestion can cause audible gaps.
- Disconnect USB before testing the wireless path. A cable reconnect switches
  cues back to the controller's physical Core Audio output.
- Power-cycle the controller if the speaker route did not recover after another
  app used its headset or audio features.

The wireless implementation currently carries app-generated cues. It does not
publish the controller as a general macOS output device, so the controller will
not appear in the system Sound output selector.

## Verification

Run the logic and protocol tests:

```bash
./scripts/test.sh
```

They verify microphone and speaker report sizes, section offsets, route-state
preservation, open/close values, CRC vectors, both IOHID callback layouts and
rejection of non-audio reports.

For a physical Bluetooth pass:

1. Disconnect USB and confirm the app reports **Bluetooth**.
2. Confirm Setup reports **DualSense Microphone available**.
3. Select **DualSense Microphone** in Codex.
4. Hold L2, speak and confirm the Setup meter moves and the orange mic light
   turns off.
5. Release L2 and confirm Codex transcribes through its native transcription
   path, the orange light returns and the Mac's default input is unchanged.
6. Repeat with the microphone button's hands-free toggle.
7. Power off the controller during capture, reconnect with PS and repeat steps
   4–5 to verify decoder/buffer reset and stream reopening.
8. Run the safe Bluetooth hardware self-test and confirm exactly one haptic
   followed by one controller-speaker tone. It intentionally does not modify
   lights, triggers or microphone state.

## Primary references

- Apple, [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- hurryman2212, [vDS](https://github.com/hurryman2212/vds), a modern
  userspace DualSense audio implementation
- awalol, [DS5Dongle](https://github.com/awalol/DS5Dongle), including DualSense
  wireless microphone stream control and Opus framing
