import Combine
import Foundation

enum SkillDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case up
    case right
    case down
    case left

    var id: String { rawValue }

    var label: String {
        switch self {
        case .up: "Up"
        case .right: "Right"
        case .down: "Down"
        case .left: "Left"
        }
    }

    var arrow: String {
        switch self {
        case .up: "↑"
        case .right: "→"
        case .down: "↓"
        case .left: "←"
        }
    }

    var input: ControllerInput {
        switch self {
        case .up: .dpadUp
        case .right: .dpadRight
        case .down: .dpadDown
        case .left: .dpadLeft
        }
    }

    init?(input: ControllerInput) {
        switch input {
        case .dpadUp: self = .up
        case .dpadRight: self = .right
        case .dpadDown: self = .down
        case .dpadLeft: self = .left
        default: return nil
        }
    }
}

struct CodexSkillSlot: Codable, Equatable, Identifiable, Sendable {
    var direction: SkillDirection
    var title: String
    var prompt: String

    var id: String { direction.rawValue }

    static let defaults: [CodexSkillSlot] = [
        .init(
            direction: .up,
            title: "Review changes",
            prompt: "Review the current changes. Prioritise correctness, regressions, security, and missing tests."
        ),
        .init(
            direction: .right,
            title: "Debug",
            prompt: "Investigate the current problem, identify the root cause, and implement and verify the fix."
        ),
        .init(
            direction: .down,
            title: "Write tests",
            prompt: "Add focused tests for the current work, covering important behavior and likely regressions, then run them."
        ),
        .init(
            direction: .left,
            title: "Refactor",
            prompt: "Refactor the current implementation for clarity and maintainability without changing its behavior, then verify it."
        )
    ]
}

enum ShiftFaceCommand: String, CaseIterable, Identifiable, Sendable {
    case approve
    case decline
    case send
    case fastMode

    var id: String { rawValue }

    var input: ControllerInput {
        switch self {
        case .approve: .cross
        case .decline: .circle
        case .send: .square
        case .fastMode: .triangle
        }
    }

    var title: String {
        switch self {
        case .approve: "Approve"
        case .decline: "Decline"
        case .send: "Send"
        case .fastMode: "Fast mode"
        }
    }

    var action: MappedAction {
        switch self {
        case .approve: .codexApprove
        case .decline: .codexDecline
        case .send: .codexSend
        case .fastMode: .codexFastMode
        }
    }

    init?(input: ControllerInput) {
        guard let command = Self.allCases.first(where: { $0.input == input })
        else {
            return nil
        }
        self = command
    }
}

@MainActor
final class ShiftLayerStore: ObservableObject {
    @Published private(set) var slots: [CodexSkillSlot]

    static let storageKey = "shiftLayerSettings.v1"

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(
               [CodexSkillSlot].self,
               from: data
           ) {
            slots = Self.merged(decoded)
        } else {
            slots = CodexSkillSlot.defaults
        }
        persist(to: defaults)
    }

    func slot(for direction: SkillDirection) -> CodexSkillSlot {
        slots.first(where: { $0.direction == direction }) ??
            CodexSkillSlot.defaults.first(where: {
                $0.direction == direction
            })!
    }

    func updateTitle(_ title: String, for direction: SkillDirection) {
        update(direction) { $0.title = title }
    }

    func updatePrompt(_ prompt: String, for direction: SkillDirection) {
        update(direction) { $0.prompt = prompt }
    }

    func reset() {
        slots = CodexSkillSlot.defaults
        persist()
    }

    func reloadExternalChanges() {
        UserDefaults.standard.synchronize()
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(
                  [CodexSkillSlot].self,
                  from: data
              )
        else {
            return
        }
        let merged = Self.merged(decoded)
        guard merged != slots else { return }
        slots = merged
    }

    private func update(
        _ direction: SkillDirection,
        change: (inout CodexSkillSlot) -> Void
    ) {
        guard let index = slots.firstIndex(where: {
            $0.direction == direction
        }) else {
            return
        }
        change(&slots[index])
        persist()
    }

    private func persist(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func merged(
        _ saved: [CodexSkillSlot]
    ) -> [CodexSkillSlot] {
        SkillDirection.allCases.map { direction in
            saved.first(where: { $0.direction == direction }) ??
                CodexSkillSlot.defaults.first(where: {
                    $0.direction == direction
                })!
        }
    }
}

enum ReasoningStep: Equatable, Sendable {
    case smarter
    case faster

    var title: String {
        switch self {
        case .smarter: "Smarter"
        case .faster: "Faster"
        }
    }
}

struct SteppedStickGate: Sendable {
    private(set) var armed = true
    let activationThreshold: Float
    let neutralThreshold: Float

    init(
        activationThreshold: Float = 0.62,
        neutralThreshold: Float = 0.28
    ) {
        self.activationThreshold = activationThreshold
        self.neutralThreshold = neutralThreshold
    }

    mutating func update(y: Float) -> ReasoningStep? {
        if abs(y) <= neutralThreshold {
            armed = true
            return nil
        }
        guard armed, abs(y) >= activationThreshold else { return nil }
        armed = false
        return y > 0 ? .smarter : .faster
    }

    mutating func reset() {
        armed = true
    }
}

enum TaskSelection {
    static func adjacentID(
        in tasks: [RecentCodexTask],
        selectedID: String?,
        offset: Int
    ) -> String? {
        guard !tasks.isEmpty else { return nil }
        guard let selectedID,
              let current = tasks.firstIndex(where: { $0.id == selectedID })
        else {
            return tasks[0].id
        }
        let count = tasks.count
        return tasks[(current + offset + count) % count].id
    }
}
