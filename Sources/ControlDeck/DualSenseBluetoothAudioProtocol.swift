import Foundation

struct DualSenseBluetoothControlFrame: Equatable {
    let leftTrigger: UInt8
    let buttons0: UInt8
    let buttons1: UInt8
    let buttons2: UInt8
}

/// The small, vendor-defined part of the DualSense Bluetooth audio protocol.
///
/// Wireless audio is transported over the controller's normal HID connection.
/// Report 0x32 enables or disables the microphone stream, report 0x31 updates
/// audio routing/mute state, incoming 0x31 audio payloads contain one 10 ms
/// microphone Opus frame, and outgoing 0x36 reports contain speaker Opus.
enum DualSenseBluetoothAudioProtocol {
    static let microphoneSampleRate = 48_000
    static let microphoneFrameCount = 480
    static let microphoneOpusByteCount = 71
    static let bluetoothInputReportByteCount = 78
    static let speakerSampleRate = 48_000
    static let speakerChannelCount = 2
    static let speakerFrameCount = 480
    static let speakerOpusByteCount = 200
    static let speakerReportByteCount = 398

    private static let stateReportByteCount = 78
    private static let microphoneReportByteCount = 142
    private static let controllerStateByteCount = 63

    static func microphoneStateReport(
        active: Bool,
        muted: Bool,
        sequence: UInt8,
        speakerActive: Bool = false
    ) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: stateReportByteCount)
        report[0] = 0x31
        report[1] = (sequence & 0x0f) << 4
        report[2] = 0x10

        let stateOffset = 3
        let state = controllerAudioState(
            microphoneActive: active && !muted,
            speakerActive: speakerActive,
            explicitlySetMicrophoneMute: true
        )
        for index in state.indices {
            report[stateOffset + index] = state[index]
        }

        fillOutputCRC(&report)
        return report
    }

    static func microphoneStreamReport(
        active: Bool,
        sequence: UInt8
    ) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: microphoneReportByteCount)
        report[0] = 0x32
        report[1] = (sequence & 0x0f) << 4
        report[2] = 0x91
        report[3] = 0x07
        report[4] = active ? 0xff : 0xfe
        report[5] = 0x40
        report[6] = 0x40
        report[7] = 0x40
        report[8] = 0x40
        report[9] = 0x40
        report[10] = sequence & 0x0f
        report[11] = 0x92
        report[12] = 0x40

        fillOutputCRC(&report)
        return report
    }

    /// Initializes the tagged Bluetooth audio-section transport. The state
    /// block only marks audio fields as valid, so it does not take ownership
    /// of lights, triggers, or rumble.
    static func audioInitializationReport(
        microphoneActive: Bool,
        speakerActive: Bool
    ) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: microphoneReportByteCount)
        report[0] = 0x32
        report[1] = 0x10
        report[2] = 0x90
        report[3] = UInt8(controllerStateByteCount)
        let state = controllerAudioState(
            microphoneActive: microphoneActive,
            speakerActive: speakerActive,
            explicitlySetMicrophoneMute: false
        )
        for index in state.indices {
            report[4 + index] = state[index]
        }
        fillOutputCRC(&report)
        return report
    }

    /// Builds one paced 10 ms speaker packet. The packet also carries a
    /// zero-valued haptics section: keeping that section present is required by
    /// the controller's audio framing, but it produces no vibration.
    static func speakerAudioReport(
        opusFrame: [UInt8],
        reportSequence: UInt8,
        packetSequence: UInt8,
        microphoneActive: Bool
    ) -> [UInt8]? {
        guard opusFrame.count == speakerOpusByteCount else { return nil }

        var report = [UInt8](repeating: 0, count: speakerReportByteCount)
        report[0] = 0x36
        report[1] = (reportSequence & 0x0f) << 4
        report[2] = 0x91
        report[3] = 0x07
        // Bit zero enables the microphone uplink. Never enable it merely to
        // play a speaker cue: unsolicited Opus input can otherwise reach
        // Apple's controller parser while normal actions are still enabled.
        report[4] = microphoneActive ? 0xff : 0xfe
        for index in 5...9 {
            report[index] = 0x40
        }
        report[10] = packetSequence

        report[11] = 0x90
        report[12] = UInt8(controllerStateByteCount)
        let state = controllerAudioState(
            microphoneActive: microphoneActive,
            speakerActive: true,
            explicitlySetMicrophoneMute: false
        )
        for index in state.indices {
            report[13 + index] = state[index]
        }

        report[76] = 0x92
        report[77] = 64
        // Bytes 78...141 are intentionally silent haptics.
        report[142] = 0x93 // Tagged controller-speaker section.
        report[143] = UInt8(speakerOpusByteCount)
        for index in opusFrame.indices {
            report[144 + index] = opusFrame[index]
        }

        fillOutputCRC(&report)
        return report
    }

    /// Extracts the 71-byte Opus frame from an IOHID input callback.
    ///
    /// IOHID implementations differ on whether the report ID is also present
    /// at byte zero, so both callback layouts are accepted.
    static func microphoneOpusPayload(
        reportID: UInt32,
        bytes: [UInt8]
    ) -> Data? {
        guard reportID == 0x31, !bytes.isEmpty else { return nil }

        let includesReportID = inputBufferIncludesReportID(
            reportID: reportID,
            bytes: bytes
        )
        let typeOffset = includesReportID ? 1 : 0
        let opusOffset = includesReportID ? 3 : 2
        guard bytes.indices.contains(typeOffset),
              (bytes[typeOffset] & 0x0f) == 0x02,
              bytes.count >= opusOffset + microphoneOpusByteCount
        else {
            return nil
        }

        let payload = bytes[opusOffset..<(opusOffset + microphoneOpusByteCount)]
        // 0xD4 is the TOC byte used by current controller firmware. Accept
        // other valid Opus TOCs as well so a firmware bitrate change does not
        // unnecessarily break capture.
        guard !payload.isEmpty else { return nil }
        return Data(payload)
    }

    /// IOHID normally includes the report ID in its callback buffer, but some
    /// backends strip it. Length is authoritative for the fixed-size enhanced
    /// report: a stripped sequence header can itself equal 0x31.
    static func inputBufferIncludesReportID(
        reportID: UInt32,
        bytes: [UInt8]
    ) -> Bool {
        if bytes.count == bluetoothInputReportByteCount {
            return bytes.first == UInt8(truncatingIfNeeded: reportID)
        }
        if bytes.count == bluetoothInputReportByteCount - 1 {
            return false
        }
        return bytes.first == UInt8(truncatingIfNeeded: reportID)
    }

    /// Extracts only a validated type-1 enhanced controller-state report.
    /// Type-2 report 0x31 packets contain Opus and must never be interpreted
    /// using these offsets.
    static func bluetoothControlFrame(
        reportID: UInt32,
        bytes: [UInt8]
    ) -> DualSenseBluetoothControlFrame? {
        guard reportID == 0x31, !bytes.isEmpty else { return nil }
        let includesReportID = inputBufferIncludesReportID(
            reportID: reportID,
            bytes: bytes
        )
        let typeOffset = includesReportID ? 1 : 0
        let stateOffset = includesReportID ? 2 : 1
        guard bytes.indices.contains(typeOffset),
              (bytes[typeOffset] & 0x0f) == 0x01,
              bytes.count >= stateOffset + 10
        else {
            return nil
        }
        return DualSenseBluetoothControlFrame(
            leftTrigger: bytes[stateOffset + 4],
            buttons0: bytes[stateOffset + 7],
            buttons1: bytes[stateOffset + 8],
            buttons2: bytes[stateOffset + 9]
        )
    }

    static func outputCRC(for bytesWithoutChecksum: [UInt8]) -> UInt32 {
        // Sony's Bluetooth output CRC is standard CRC-32 over an implicit
        // HIDP output prefix (0xA2) followed by the report.
        var crc: UInt32 = 0xffff_ffff
        for byte in [UInt8(0xa2)] + bytesWithoutChecksum {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(bitPattern: -Int32(crc & 1))
                crc = (crc >> 1) ^ (0xedb8_8320 & mask)
            }
        }
        return ~crc
    }

    private static func controllerAudioState(
        microphoneActive: Bool,
        speakerActive: Bool,
        explicitlySetMicrophoneMute: Bool
    ) -> [UInt8] {
        var state = [UInt8](repeating: 0, count: controllerStateByteCount)

        state[0] = 0x80 // Audio control is valid.
        if speakerActive {
            state[0] |= 0x20 // Speaker volume is valid.
            state[1] |= 0x80 // Audio control 2 is valid.
            state[5] = 0x64
            state[37] = 0x01
        }
        if microphoneActive || explicitlySetMicrophoneMute {
            state[0] |= 0x40 // Microphone volume is valid.
            // Mic LED, power saving and audio-control-2 are valid.
            state[1] |= 0x83
            state[6] = microphoneActive ? 0x08 : 0
            state[8] = microphoneActive ? 0 : 1
            state[9] = microphoneActive ? 0 : 0x10
            state[37] = 0x01
        }

        // 0x09 selects the internal microphone with voice processing.
        // Output-path bits 5:4 select the built-in speaker while streaming.
        state[7] = speakerActive ? 0x39 : 0x09
        return state
    }

    private static func fillOutputCRC(_ report: inout [UInt8]) {
        guard report.count >= 4 else { return }
        let checksumOffset = report.count - 4
        let checksum = outputCRC(for: Array(report[..<checksumOffset]))
        report[checksumOffset + 0] = UInt8(truncatingIfNeeded: checksum)
        report[checksumOffset + 1] = UInt8(truncatingIfNeeded: checksum >> 8)
        report[checksumOffset + 2] = UInt8(truncatingIfNeeded: checksum >> 16)
        report[checksumOffset + 3] = UInt8(truncatingIfNeeded: checksum >> 24)
    }
}
