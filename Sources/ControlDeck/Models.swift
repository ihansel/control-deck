import AppKit
import Foundation

enum ControllerFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case dualSense
    case dualShock4
    case switchPro
    case switchPro2
    case eightBitDo
    case generic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dualSense: "DualSense"
        case .dualShock4: "DualShock 4"
        case .switchPro: "Switch Pro"
        case .switchPro2: "Switch 2 Pro"
        case .eightBitDo: "8BitDo"
        case .generic: "Game controller"
        }
    }

    var isDualSense: Bool { self == .dualSense }

    static func identify(vendorName: String?, productCategory: String) -> Self {
        let identity = "\(vendorName ?? "") \(productCategory)".lowercased()
        if identity.contains("dualsense") || identity.contains("ps5") {
            return .dualSense
        }
        if identity.contains("dualshock") || identity.contains("ps4") {
            return .dualShock4
        }
        if identity.contains("8bitdo") {
            return .eightBitDo
        }
        if identity.contains("switch 2") {
            return .switchPro2
        }
        if identity.contains("switch") || identity.contains("nintendo") {
            return .switchPro
        }
        return .generic
    }
}

enum CodexTaskState: String, Codable, CaseIterable, Sendable {
    case disconnected
    case idle
    case thinking
    case complete
    case needsInput
    case error
    case listening
    case processingVoice

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .idle: "Idle"
        case .thinking: "Thinking"
        case .complete: "Complete"
        case .needsInput: "Needs input"
        case .error: "Error"
        case .listening: "Listening"
        case .processingVoice: "Processing voice"
        }
    }

    var color: NSColor {
        switch self {
        case .disconnected: .systemGray
        case .idle: NSColor(red: 0.08, green: 0.35, blue: 1, alpha: 1)
        case .thinking: NSColor(red: 0.58, green: 0.22, blue: 1, alpha: 1)
        case .complete: NSColor(red: 0.05, green: 0.82, blue: 0.35, alpha: 1)
        case .needsInput: NSColor(red: 1, green: 0.58, blue: 0.05, alpha: 1)
        case .error: NSColor(red: 1, green: 0.12, blue: 0.12, alpha: 1)
        case .listening: NSColor(red: 0, green: 0.88, blue: 0.82, alpha: 1)
        case .processingVoice: .white
        }
    }

    static func aggregate(_ states: [CodexTaskState]) -> CodexTaskState {
        if states.contains(.needsInput) { return .needsInput }
        if states.contains(.error) { return .error }
        if states.contains(.thinking) { return .thinking }
        if states.contains(.complete) { return .complete }
        return states.isEmpty ? .idle : states[0]
    }
}

struct RecentCodexTask: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let latestMessage: String
    let rolloutPath: String
    let updatedAt: Date
    let state: CodexTaskState

    init(
        id: String,
        title: String,
        latestMessage: String? = nil,
        rolloutPath: String,
        updatedAt: Date,
        state: CodexTaskState
    ) {
        self.id = id
        self.title = title
        let trimmedMessage = latestMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedMessage, !trimmedMessage.isEmpty {
            self.latestMessage = trimmedMessage
        } else {
            self.latestMessage = title
        }
        self.rolloutPath = rolloutPath
        self.updatedAt = updatedAt
        self.state = state
    }

    var shortTitle: String {
        shortened(title, limit: 64)
    }

    var shortMessage: String {
        shortened(latestMessage, limit: 140)
    }

    var hasDistinctTitle: Bool {
        normalized(title) != normalized(latestMessage)
    }

    private func shortened(_ value: String, limit: Int) -> String {
        let trimmed = normalized(value)
        if trimmed.count <= limit { return trimmed }
        return String(trimmed.prefix(limit - 1)) + "…"
    }

    private func normalized(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

enum ControllerEvent: Equatable, Sendable {
    case button(ControllerInput, pressed: Bool)
    case stick(ControllerStick, x: Float, y: Float)
    case touch(TouchFinger, x: Float, y: Float, active: Bool)
    case action(ControllerAction)
    case pushToTalk(Bool)
    case microphoneButton
    case motion(ControllerMotionSample)
}

enum ControllerAction: String, CaseIterable, Codable, Sendable {
    case sendMessage
    case interrupt
    case toggleReview
    case togglePlan
    case newTask
    case commandMenu
    case focusCodex
    case previousTask
    case nextTask
    case back
    case forward
    case toggleSidebar
    case quickChat
    case toggleTerminal
    case approve
    case decline
    case continueInNewTask
    case toggleFastMode
    case reasoning

    var label: String {
        switch self {
        case .sendMessage: "Send message"
        case .interrupt: "Stop"
        case .toggleReview: "Review changes"
        case .togglePlan: "Toggle Plan mode"
        case .newTask: "New task"
        case .commandMenu: "Command menu"
        case .focusCodex: "Focus Codex"
        case .previousTask: "Previous task"
        case .nextTask: "Next task"
        case .back: "Back"
        case .forward: "Forward"
        case .toggleSidebar: "Toggle sidebar"
        case .quickChat: "Quick chat"
        case .toggleTerminal: "Toggle terminal"
        case .approve: "Approve"
        case .decline: "Decline"
        case .continueInNewTask: "Continue in new task"
        case .toggleFastMode: "Toggle Fast mode"
        case .reasoning: "Reasoning effort"
        }
    }
}

enum HapticCue: Sendable {
    case connect
    case success
    case selection
    case warning
    case error
    case listeningStart
    case listeningStop
}

enum FeedbackSoundCue: Sendable {
    case complete
    case needsInput
    case error
    case listeningStart
    case listeningStop
}

struct FeedbackTone: Sendable {
    let frequency: Float
    let duration: TimeInterval
    let volume: Float
    let pauseAfter: TimeInterval
}

enum SoundTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case playful
    case soft
    case arcade

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .playful: "Playful"
        case .soft: "Soft"
        case .arcade: "Arcade"
        }
    }

    var detail: String {
        switch self {
        case .off: "Haptics only"
        case .playful: "Bright, short and friendly"
        case .soft: "Warm and understated"
        case .arcade: "Crisp retro chirps"
        }
    }

    func tones(for cue: FeedbackSoundCue) -> [FeedbackTone] {
        guard self != .off else { return [] }
        switch (self, cue) {
        case (.playful, .complete):
            return [
                .init(frequency: 587, duration: 0.07, volume: 0.055, pauseAfter: 0.018),
                .init(frequency: 784, duration: 0.08, volume: 0.060, pauseAfter: 0.018),
                .init(frequency: 1_047, duration: 0.11, volume: 0.052, pauseAfter: 0)
            ]
        case (.playful, .needsInput):
            return [
                .init(frequency: 740, duration: 0.07, volume: 0.045, pauseAfter: 0.035),
                .init(frequency: 740, duration: 0.07, volume: 0.045, pauseAfter: 0)
            ]
        case (.playful, .error):
            return [
                .init(frequency: 330, duration: 0.09, volume: 0.050, pauseAfter: 0.025),
                .init(frequency: 247, duration: 0.12, volume: 0.045, pauseAfter: 0)
            ]
        case (.playful, .listeningStart):
            return [.init(frequency: 880, duration: 0.07, volume: 0.040, pauseAfter: 0)]
        case (.playful, .listeningStop):
            return [.init(frequency: 659, duration: 0.07, volume: 0.038, pauseAfter: 0)]
        case (.soft, .complete):
            return [
                .init(frequency: 523, duration: 0.11, volume: 0.035, pauseAfter: 0.025),
                .init(frequency: 659, duration: 0.16, volume: 0.035, pauseAfter: 0)
            ]
        case (.soft, .needsInput):
            return [.init(frequency: 587, duration: 0.12, volume: 0.030, pauseAfter: 0)]
        case (.soft, .error):
            return [.init(frequency: 294, duration: 0.16, volume: 0.032, pauseAfter: 0)]
        case (.soft, .listeningStart):
            return [.init(frequency: 698, duration: 0.08, volume: 0.027, pauseAfter: 0)]
        case (.soft, .listeningStop):
            return [.init(frequency: 523, duration: 0.08, volume: 0.025, pauseAfter: 0)]
        case (.arcade, .complete):
            return [
                .init(frequency: 660, duration: 0.045, volume: 0.050, pauseAfter: 0.012),
                .init(frequency: 990, duration: 0.045, volume: 0.050, pauseAfter: 0.012),
                .init(frequency: 1_320, duration: 0.08, volume: 0.045, pauseAfter: 0)
            ]
        case (.arcade, .needsInput):
            return [
                .init(frequency: 880, duration: 0.045, volume: 0.045, pauseAfter: 0.025),
                .init(frequency: 880, duration: 0.045, volume: 0.045, pauseAfter: 0)
            ]
        case (.arcade, .error):
            return [
                .init(frequency: 440, duration: 0.05, volume: 0.048, pauseAfter: 0.015),
                .init(frequency: 220, duration: 0.09, volume: 0.045, pauseAfter: 0)
            ]
        case (.arcade, .listeningStart):
            return [.init(frequency: 1_100, duration: 0.045, volume: 0.040, pauseAfter: 0)]
        case (.arcade, .listeningStop):
            return [.init(frequency: 550, duration: 0.045, volume: 0.038, pauseAfter: 0)]
        case (.off, _):
            return []
        }
    }
}

struct ControllerPreferences {
    private enum Key {
        static let soundTheme = "soundTheme.v2"
        static let statusHaptics = "statusHaptics"
    }

    static var soundTheme: SoundTheme {
        get {
            guard let value = UserDefaults.standard.string(
                forKey: Key.soundTheme
            ) else {
                return .off
            }
            return SoundTheme(rawValue: value) ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Key.soundTheme)
        }
    }

    static var statusHaptics: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.statusHaptics) == nil { return true }
            return UserDefaults.standard.bool(forKey: Key.statusHaptics)
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.statusHaptics) }
    }
}
