# DualSense Microphone virtual audio driver

This is a macOS `AudioServerPlugIn` derived from Apple’s MIT-licensed
NullAudio sample. The original license is preserved in `LICENSE.txt`, and the
unmodified Apple sample overview is preserved in `APPLE_SAMPLE_README.md`.

The driver publishes one virtual device:

- name: `DualSense Microphone`
- UID: `com.ianhansel.controldeck.dualsense-microphone.virtual`
- format: 48,000 Hz, two-channel, interleaved 32-bit Float PCM
- input terminal: microphone
- output terminal: speaker/feed

Audio written to the output stream is copied into a lock-free ring buffer keyed
by the HAL device sample time. The matching frames are returned from the input
stream. Frames that were not written, wrapped out of the ring, or raced with a
writer are returned as silence. ControlDeck can therefore decode the
controller’s mono Opus stream, duplicate each mono sample into the two Float32
channels, and write that PCM to this device’s output side. Codex and other
microphone clients read the same signal from its input side.

## Build and verify

From the repository root:

```sh
./scripts/build-audio-driver.sh
```

This produces:

```text
Drivers/DualSenseMicrophone/build/DualSenseMicrophone.driver
```

The script compiles a universal macOS bundle, validates its property list,
ad-hoc signs it for local development, verifies the signature, and checks the
exported CoreAudio factory symbol. It also loads the built plug-in in a smoke
test and verifies exact sample-time loopback across the ring boundary plus
silence for unwritten frames. It does not install the driver or restart any
system service.

The local artifact is intentionally ad-hoc signed because this development Mac
has no valid code-signing identity. `codesign --verify --strict` succeeds, while
Gatekeeper distribution assessment rejects an ad-hoc signature as expected.
For release outside local development, sign with a valid Developer ID
Application identity and complete Apple’s notarization workflow.

## Safe local installation plan

Installation changes CoreAudio’s plug-in set, so quit audio applications first.
The system-wide location is preferred because CoreAudio reliably discovers HAL
plug-ins there:

```sh
sudo ditto \
  Drivers/DualSenseMicrophone/build/DualSenseMicrophone.driver \
  "/Library/Audio/Plug-Ins/HAL/DualSenseMicrophone.driver"
sudo chown -R root:wheel \
  "/Library/Audio/Plug-Ins/HAL/DualSenseMicrophone.driver"
```

Then reboot the Mac. A reboot is the safest activation path; forcibly killing
`coreaudiod` can interrupt every running audio application. After reboot, verify
that `DualSense Microphone` appears as both an input and an output in Audio MIDI
Setup before connecting the app’s PCM writer.

For iterative development, a per-user copy can be tested at
`~/Library/Audio/Plug-Ins/HAL/DualSenseMicrophone.driver`, but discovery of
per-user HAL plug-ins varies across macOS releases. Do not keep copies in both
locations because they share one bundle identifier and device UID.

## Safe uninstall plan

Remove only the exact bundle installed above:

```sh
sudo rm -rf "/Library/Audio/Plug-Ins/HAL/DualSenseMicrophone.driver"
```

Then reboot. If a per-user copy was used instead, remove only:

```sh
rm -rf "$HOME/Library/Audio/Plug-Ins/HAL/DualSenseMicrophone.driver"
```

Never remove the containing `HAL` directory or unrelated `.driver` bundles.
