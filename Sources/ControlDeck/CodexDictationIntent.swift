import Foundation

enum CodexDictationIntent: Equatable {
    case start
    case stopAndInsert

    var keyDown: Bool {
        switch self {
        case .start:
            true
        case .stopAndInsert:
            false
        }
    }

    var successMessage: String {
        switch self {
        case .start:
            "Held Codex dictation shortcut"
        case .stopAndInsert:
            "Released Codex dictation shortcut and requested transcript insertion"
        }
    }
}
