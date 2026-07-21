import Combine
import Foundation
import SwiftUI

enum QuickTutorialStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome
    case pointer
    case voiceAndCapture
    case profiles
    case advanced
    case ready

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Meet ControlDeck"
        case .pointer: "Move naturally around your Mac"
        case .voiceAndCapture: "Speak and capture without leaving your work"
        case .profiles: "Let the controls follow the app"
        case .advanced: "Fine-tune it when you are ready"
        case .ready: "You are ready"
        }
    }

    var detail: String {
        switch self {
        case .welcome:
            "Your controller has a calm everyday layer for pointing, clicking, scrolling and speaking. Hold controls reveal extra power only when you need it."
        case .pointer:
            "The default layout is designed to replace a mouse for everyday work. Clicking and dragging behave like a real mouse, including text selection and moving windows."
        case .voiceAndCapture:
            "Dictate short or long prompts with L2. R2 selects part of the screen, copies it, and opens the annotation editor so you can highlight what matters."
        case .profiles:
            "ControlDeck automatically chooses a layout for Codex, Chrome, Spotify, Claude and other popular apps. You can also switch explicitly with the profile wheel."
        case .advanced:
            "Everything below is optional. The defaults are ready to use, and these areas remain here when you want more control."
        case .ready:
            "Start with the everyday controls and change only what gets in your way. You can replay this tutorial from Setup whenever you like."
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "gamecontroller.fill"
        case .pointer: "cursorarrow.motionlines"
        case .voiceAndCapture: "mic.and.signal.meter.fill"
        case .profiles: "circle.hexagongrid.fill"
        case .advanced: "slider.horizontal.3"
        case .ready: "checkmark.seal.fill"
        }
    }
}

struct QuickTutorialControl: Identifiable, Sendable {
    let control: String
    let action: String
    let detail: String

    var id: String { control + action }
}

enum QuickTutorialDestination: String, CaseIterable, Identifiable, Sendable {
    case buttonMapping
    case touchpad
    case pointer
    case screenCapture
    case shiftLayer
    case profiles
    case gyro
    case customize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buttonMapping: "Button Mapping"
        case .touchpad: "Touchpad"
        case .pointer: "Pointer"
        case .screenCapture: "Screen Capture"
        case .shiftLayer: "Shift Layer"
        case .profiles: "Profiles"
        case .gyro: "Gyro"
        case .customize: "Customize with Codex"
        }
    }

    var detail: String {
        switch self {
        case .buttonMapping: "Change what every button does"
        case .touchpad: "Tune scrolling and gestures"
        case .pointer: "Adjust stick speed and acceleration"
        case .screenCapture: "Choose editor and clipboard defaults"
        case .shiftLayer: "Edit the eight-profile wheel"
        case .profiles: "Manage layouts for different apps"
        case .gyro: "Enable optional motion gestures"
        case .customize: "Ask Codex to make a change for you"
        }
    }

    var systemImage: String {
        switch self {
        case .buttonMapping: "gamecontroller"
        case .touchpad: "hand.draw"
        case .pointer: "cursorarrow.motionlines"
        case .screenCapture: "viewfinder.rectangular"
        case .shiftLayer: "circle.hexagongrid.fill"
        case .profiles: "square.stack.3d.up"
        case .gyro: "gyroscope"
        case .customize: "sparkles"
        }
    }
}

enum QuickTutorialNavigationResult: Equatable, Sendable {
    case changedStep
    case completed
    case skipped
}

@MainActor
final class QuickTutorialStore: ObservableObject {
    @Published private(set) var isPresented = false
    @Published private(set) var currentStep: QuickTutorialStep = .welcome
    @Published private(set) var hasCompleted: Bool
    @Published private(set) var hasBeenOffered: Bool

    private let defaults: UserDefaults
    private static let completedKey = "quickTutorial.completed.v1"
    private static let offeredKey = "quickTutorial.offered.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompleted = defaults.bool(forKey: Self.completedKey)
        hasBeenOffered = defaults.bool(forKey: Self.offeredKey)
    }

    var stepNumber: Int { currentStep.rawValue + 1 }
    var stepCount: Int { QuickTutorialStep.allCases.count }
    var isFirstStep: Bool { currentStep == .welcome }
    var isLastStep: Bool { currentStep == .ready }

    func offerIfNeeded() {
        guard !hasCompleted, !hasBeenOffered else { return }
        hasBeenOffered = true
        defaults.set(true, forKey: Self.offeredKey)
        start()
    }

    func start() {
        currentStep = .welcome
        isPresented = true
    }

    @discardableResult
    func next() -> QuickTutorialNavigationResult {
        guard !isLastStep,
              let next = QuickTutorialStep(rawValue: currentStep.rawValue + 1)
        else {
            complete()
            return .completed
        }
        currentStep = next
        return .changedStep
    }

    @discardableResult
    func previous() -> QuickTutorialNavigationResult {
        guard !isFirstStep,
              let previous = QuickTutorialStep(
                  rawValue: currentStep.rawValue - 1
              )
        else { return .changedStep }
        currentStep = previous
        return .changedStep
    }

    func complete() {
        hasCompleted = true
        hasBeenOffered = true
        defaults.set(true, forKey: Self.completedKey)
        defaults.set(true, forKey: Self.offeredKey)
        isPresented = false
    }

    func skip() {
        hasBeenOffered = true
        defaults.set(true, forKey: Self.offeredKey)
        isPresented = false
    }

    func handleControllerButton(
        _ input: ControllerInput
    ) -> QuickTutorialNavigationResult? {
        switch input {
        case .cross, .r1, .dpadRight, .options:
            return next()
        case .l1, .dpadLeft:
            return previous()
        case .circle:
            skip()
            return .skipped
        default:
            return nil
        }
    }
}

struct QuickTutorialView: View {
    @ObservedObject var store: QuickTutorialStore
    let openDestination: (QuickTutorialDestination) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 880, height: 650)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("QUICK TUTORIAL")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(QuickTutorialStep.allCases) { step in
                    Capsule()
                        .fill(
                            step.rawValue <= store.currentStep.rawValue
                                ? Color.accentColor
                                : Color.secondary.opacity(0.2)
                        )
                        .frame(width: step == store.currentStep ? 30 : 9, height: 7)
                }
            }
            Spacer()
            Text("\(store.stepNumber) of \(store.stepCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button("Skip tutorial") {
                store.skip()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
    }

    @ViewBuilder
    private var content: some View {
        if store.currentStep == .advanced {
            advancedContent
        } else {
            standardContent
        }
    }

    private var standardContent: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: store.currentStep.systemImage)
                    .font(.system(size: 49, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 8) {
                Text(store.currentStep.title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(store.currentStep.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 660)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !controls.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(controls) { control in
                        tutorialControl(control)
                    }
                }
                .frame(maxWidth: 680)
            }
        }
        .padding(34)
    }

    private var advancedContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 7) {
                Image(systemName: store.currentStep.systemImage)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Text(store.currentStep.title)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                Text(store.currentStep.detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 11
            ) {
                ForEach(QuickTutorialDestination.allCases) { destination in
                    Button {
                        store.complete()
                        openDestination(destination)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: destination.systemImage)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                            Text(destination.title)
                                .font(.headline)
                            Text(destination.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
                        .padding(13)
                        .background(
                            Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(26)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Back") {
                _ = store.previous()
            }
            .disabled(store.isFirstStep)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Text("Controller: L1 / R1 to move · Circle to skip")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(store.isLastStep ? "Finish" : "Next") {
                _ = store.next()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 24)
        .frame(height: 66)
    }

    private var controls: [QuickTutorialControl] {
        switch store.currentStep {
        case .welcome:
            [
                .init(control: "Everyday", action: "Point and work", detail: "The controls you use constantly stay simple."),
                .init(control: "Hold controls", action: "Reveal more", detail: "Advanced actions stay out of the way until needed.")
            ]
        case .pointer:
            [
                .init(control: "Left stick", action: "Move pointer", detail: "Cross clicks; hold Cross and move to drag or highlight."),
                .init(control: "Right stick / touchpad", action: "Scroll", detail: "Scroll vertically or horizontally with analogue control.")
            ]
        case .voiceAndCapture:
            [
                .init(control: "L2", action: "Dictate", detail: "Tap to toggle a longer recording, or hold for push-to-talk."),
                .init(control: "R2", action: "Capture", detail: "Select an area, copy it, then annotate or dismiss immediately.")
            ]
        case .profiles:
            [
                .init(control: "Automatic", action: "Follow the foreground app", detail: "Curated profiles match popular apps without extra work."),
                .init(control: "Hold Options + left stick", action: "Choose a profile", detail: "Release Options on one of the eight app-logo slots.")
            ]
        case .ready:
            [
                .init(control: "Touchpad click", action: "Show context", detail: "See the current profile and important mappings at any time."),
                .init(control: "Setup", action: "Replay tutorial", detail: "This walkthrough always remains available here.")
            ]
        case .advanced:
            []
        }
    }

    private func tutorialControl(_ item: QuickTutorialControl) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(item.control)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 125, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.action)
                    .font(.headline)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}
