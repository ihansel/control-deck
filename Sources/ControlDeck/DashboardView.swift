import AppKit
import SwiftUI

private enum DashboardSection: String, CaseIterable, Identifiable {
    case dashboard
    case controller
    case touchpad
    case gyro
    case pointer
    case screenCapture
    case shiftLayer
    case profiles
    case customize
    case setup

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "ControlDeck"
        case .controller: "Button Mapping"
        case .touchpad: "Touchpad"
        case .gyro: "Gyro"
        case .pointer: "Pointer"
        case .screenCapture: "Screen Capture"
        case .shiftLayer: "Shift Layer"
        case .profiles: "Profiles"
        case .customize: "Customize with Codex"
        case .setup: "Setup"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "rectangle.grid.2x2"
        case .controller: "gamecontroller"
        case .touchpad: "hand.draw"
        case .gyro: "gyroscope"
        case .pointer: "cursorarrow.motionlines"
        case .screenCapture: "viewfinder.rectangular"
        case .shiftLayer: "circle.hexagongrid.fill"
        case .profiles: "square.stack.3d.up"
        case .customize: "sparkles"
        case .setup: "checklist"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var profiles: ProfileStore
    @ObservedObject private var controller: DualSenseControllerService
    @ObservedObject private var audio: AudioDeviceService
    @ObservedObject private var bluetoothMicrophone: BluetoothMicrophoneService
    @ObservedObject private var automation: CodexAutomation
    @ObservedObject private var codexExtension: CodexExtensionService
    @ObservedObject private var shiftLayer: ShiftLayerStore
    @ObservedObject private var screenCapture: ScreenCapturePreferences
    @ObservedObject private var tutorial: QuickTutorialStore
    @State private var section: DashboardSection = .dashboard
    @State private var selectedInput: ControllerInput = .cross
    @State private var customizationRequest =
        "Make the controller feel better for the app I use most."

    init(model: AppModel) {
        self.model = model
        _profiles = ObservedObject(wrappedValue: model.profiles)
        _controller = ObservedObject(wrappedValue: model.controller)
        _audio = ObservedObject(wrappedValue: model.audio)
        _bluetoothMicrophone = ObservedObject(
            wrappedValue: model.bluetoothMicrophone
        )
        _automation = ObservedObject(wrappedValue: model.automation)
        _codexExtension = ObservedObject(
            wrappedValue: model.codexExtension
        )
        _shiftLayer = ObservedObject(wrappedValue: model.shiftLayer)
        _screenCapture = ObservedObject(
            wrappedValue: model.screenCapturePreferences
        )
        _tutorial = ObservedObject(wrappedValue: model.tutorial)
    }

    var body: some View {
        functionalShell
        .frame(
            minWidth: 1_320,
            idealWidth: 1_565,
            maxWidth: .infinity,
            minHeight: 820,
            idealHeight: 1_005,
            maxHeight: .infinity
        )
        .preferredColorScheme(.light)
        .sheet(
            isPresented: Binding(
                get: { tutorial.isPresented },
                set: { presented in
                    if !presented, tutorial.isPresented { tutorial.skip() }
                }
            )
        ) {
            QuickTutorialView(store: tutorial) { destination in
                openTutorialDestination(destination)
            }
        }
    }

    private var availableSections: [DashboardSection] {
        DashboardSection.allCases
    }

    private var functionalShell: some View {
        GeometryReader { proxy in
            let sidebarWidth = proxy.size.width * (324.0 / 1_565.0)

            HStack(spacing: 0) {
                dashboardSidebar
                    .frame(width: sidebarWidth)
                Divider()

                VStack(spacing: 0) {
                    dashboardToolbar
                    Divider()

                    if section == .controller {
                        buttonMappings
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            detailSurface
                                .padding(32)
                        }
                        .background(PS5Palette.canvas)
                    }
                }
            }
        }
        .background(Color.white)
    }

    private var dashboardSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectRasterImage(name: "control-deck-logo-horizontal")
                .scaledToFit()
                .frame(width: 150, height: 40)
                .accessibilityLabel("ControlDeck")
                .padding(.horizontal, 28)
                .padding(.top, 72)

            VStack(spacing: 8) {
                ForEach(availableSections) { item in
                    Button {
                        section = item
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 19, weight: .regular))
                                .frame(width: 24)
                            Text(item.label)
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 56)
                        .contentShape(
                            RoundedRectangle(
                                cornerRadius: 10,
                                style: .continuous
                            )
                        )
                        .background(
                            section == item
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            if section == item {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 50)

            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
    }

    private var dashboardToolbar: some View {
        HStack(spacing: 10) {
            Spacer()

            Image(systemName: "gamecontroller")
                .font(.system(size: 18, weight: .medium))

            Text(controller.isConnected ? "Connected" : "Offline")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    controller.isConnected
                        ? PS5Palette.acid
                        : Color.secondary.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            Divider()
                .frame(height: 32)

            Text(controller.transport.label)
                .font(.system(size: 13, weight: .medium))
            Text("·")
                .foregroundStyle(.secondary)
            Text(controller.isConnected ? "\(Int(controller.batteryLevel * 100))%" : "—")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()

            Image(systemName: "battery.75percent")
                .font(.system(size: 20, weight: .medium))
            if controller.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 46)
        .background(Color.white)
    }

    private var detailSurface: some View {
        Group {
            if section == .dashboard {
                FunctionalDashboardContent(model: model) {
                    section = .controller
                }
            } else if section != .controller {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: section.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 46, height: 46)
                            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.label)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                            Text(sectionSupport)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    detail
                }
            }
        }
    }

    private var sectionSupport: String {
        switch section {
        case .dashboard: "Controller status and shortcuts."
        case .controller: "Select a control on the photo, then choose exactly what it should do."
        case .touchpad: "Tune pointer tracking, scrolling and gestures."
        case .gyro: "Configure motion gestures and test controller tilt."
        case .pointer: "Adjust analogue stick pointer behaviour."
        case .screenCapture: "Control clipboard and annotation editor behaviour."
        case .shiftLayer: "Configure the Options profile wheel and reasoning control."
        case .profiles: "Switch and customise mappings by application."
        case .customize: "Ask Codex to change profiles or extend controller behaviour."
        case .setup: "Connect, grant permissions and test your controller."
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .dashboard:
            EmptyView()
        case .controller:
            buttonMappings
        case .touchpad:
            touchpadSettings
        case .gyro:
            gyroSettings
        case .pointer:
            pointerSettings
        case .screenCapture:
            screenCaptureSettings
        case .shiftLayer:
            shiftLayerSettings
        case .profiles:
            profileSettings
        case .customize:
            customizationSettings
        case .setup:
            setup
        }
    }


    private var buttonMappings: some View {
        ControllerMappingView(
            selectedInput: $selectedInput,
            profileKind: profiles.editingKind,
            actionForInput: { profiles.editingProfile.action(for: $0) },
            setAction: { action, input in
                profiles.setAction(action, for: input)
            },
            resetSelected: {
                let original = ControllerProfile.defaults
                    .first(where: { $0.kind == profiles.editingKind })
                profiles.setAction(
                    original?.action(for: selectedInput) ?? .none,
                    for: selectedInput
                )
            }
        )
    }

    private var touchpadSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            profileStrip

            GroupBox {
                HStack(spacing: 24) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(.blue.gradient)
                        .frame(width: 100)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scroll-first touchpad")
                            .font(.title3.weight(.semibold))
                        Text("One or two fingers scroll by default. Taps still click, and pointer mode remains available per profile.")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 18) {
                            Label("1-finger scroll", systemImage: "hand.draw")
                            Label("2-finger scroll", systemImage: "hand.draw")
                            Label("Tap to click", systemImage: "cursorarrow.click")
                        }
                        .font(.caption)
                    }
                    Spacer()
                }
                .padding(10)
            }

            GroupBox("Tracking") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker(
                        "One-finger movement",
                        selection: Binding(
                            get: {
                                profiles.editingProfile.touchpad.oneFingerMode
                            },
                            set: { profiles.updateOneFingerMode($0) }
                        )
                    ) {
                        ForEach(TouchpadMotionMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    if profiles.editingProfile.touchpad.oneFingerMode ==
                        .pointer {
                        LabeledSlider(
                            label: "Pointer sensitivity",
                            value: Binding(
                                get: {
                                    profiles.editingProfile.touchpad.pointerSensitivity
                                },
                                set: {
                                    profiles.updateTouchPointerSensitivity($0)
                                }
                            ),
                            range: 0.35...2.2
                        )
                    }
                    Toggle(
                        "Two fingers scroll",
                        isOn: Binding(
                            get: {
                                profiles.editingProfile.touchpad.twoFingerScroll
                            },
                            set: { profiles.updateTwoFingerScroll($0) }
                        )
                    )
                    LabeledSlider(
                        label: "Scroll sensitivity",
                        value: Binding(
                            get: {
                                profiles.editingProfile.touchpad.scrollSensitivity
                            },
                            set: { profiles.updateTouchScrollSensitivity($0) }
                        ),
                        range: 0.35...2.2
                    )
                }
                .padding(8)
            }

            GroupBox("Gesture actions") {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    ForEach(TouchGesture.allCases) { gesture in
                        HStack {
                            Text(gesture.label)
                                .lineLimit(1)
                            Spacer()
                            ActionPicker(
                                selection: Binding(
                                    get: {
                                        profiles.editingProfile.touchpad.action(
                                            for: gesture
                                        )
                                    },
                                    set: {
                                        profiles.setGestureAction($0, for: gesture)
                                    }
                                )
                            )
                            .frame(width: 205)
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var pointerSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            profileStrip
            GroupBox {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "cursorarrow.motionlines")
                            .font(.system(size: 42))
                            .foregroundStyle(.blue.gradient)
                        VStack(alignment: .leading) {
                            Text("Analogue sticks")
                                .font(.title3.weight(.semibold))
                            Text("Use one stick for the pointer and the other for smooth two-axis scrolling.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Picker(
                        "Pointer stick",
                        selection: Binding(
                            get: { profiles.editingProfile.pointer.source },
                            set: { profiles.updatePointerSource($0) }
                        )
                    ) {
                        ForEach(ControllerStick.allCases) { stick in
                            Text(stick.label).tag(stick)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledSlider(
                        label: "Speed",
                        value: Binding(
                            get: { profiles.editingProfile.pointer.speed },
                            set: { profiles.updatePointerSpeed($0) }
                        ),
                        range: 300...1_600,
                        valueText: { "\(Int($0)) px/s" }
                    )
                    LabeledSlider(
                        label: "Acceleration",
                        value: Binding(
                            get: { profiles.editingProfile.pointer.acceleration },
                            set: { profiles.updatePointerAcceleration($0) }
                        ),
                        range: 1...2.6
                    )
                    LabeledSlider(
                        label: "Dead zone",
                        value: Binding(
                            get: { profiles.editingProfile.pointer.deadZone },
                            set: { profiles.updateDeadZone($0) }
                        ),
                        range: 0.05...0.35,
                        valueText: { "\(Int($0 * 100))%" }
                    )

                    Divider()

                    Picker(
                        "Scroll stick",
                        selection: Binding(
                            get: {
                                profiles.editingProfile.pointer.scrollSource
                            },
                            set: { profiles.updateScrollSource($0) }
                        )
                    ) {
                        ForEach(ControllerStick.allCases) { stick in
                            Text(stick.label).tag(stick)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(
                        profiles.editingProfile.pointer.scrollSource ==
                            profiles.editingProfile.pointer.source
                            ? "Choose different sticks for pointer and scrolling. Pointer takes priority."
                            : "Push vertically or horizontally to scroll in that direction."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    LabeledSlider(
                        label: "Scroll speed",
                        value: Binding(
                            get: {
                                profiles.editingProfile.pointer.scrollSpeed
                            },
                            set: { profiles.updateScrollSpeed($0) }
                        ),
                        range: 300...1_800,
                        valueText: { "\(Int($0)) px/s" }
                    )
                    LabeledSlider(
                        label: "Scroll acceleration",
                        value: Binding(
                            get: {
                                profiles.editingProfile.pointer
                                    .scrollAcceleration
                            },
                            set: {
                                profiles.updateScrollAcceleration($0)
                            }
                        ),
                        range: 1...2.6
                    )
                    LabeledSlider(
                        label: "Scroll dead zone",
                        value: Binding(
                            get: {
                                profiles.editingProfile.pointer.scrollDeadZone
                            },
                            set: { profiles.updateScrollDeadZone($0) }
                        ),
                        range: 0.05...0.35,
                        valueText: { "\(Int($0 * 100))%" }
                    )
                }
                .padding(10)
            }
        }
    }

    private var gyroSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            profileStrip

            GroupBox {
                HStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(Color.indigo.opacity(0.13))
                            .frame(width: 92, height: 92)
                        Image(systemName: "gyroscope")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(Color.indigo)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Motion controls")
                            .font(.title3.weight(.semibold))
                        Text(
                            "A deliberate hard shake asks before clearing the " +
                            "focused text field. Every other motion gesture is " +
                            "available but unassigned by default."
                        )
                        .foregroundStyle(.secondary)
                        Label(
                            controller.motionAvailable
                                ? "Motion sensors connected"
                                : "This controller is not reporting motion",
                            systemImage: controller.motionAvailable
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            controller.motionAvailable ? Color.green : Color.orange
                        )
                    }
                    Spacer()
                }
                .padding(10)
            }

            GroupBox("Detection") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(
                        "Enable gyro gestures for this profile",
                        isOn: Binding(
                            get: { profiles.editingProfile.gyro.enabled },
                            set: { profiles.updateGyroEnabled($0) }
                        )
                    )
                    LabeledSlider(
                        label: "Shake force",
                        value: Binding(
                            get: {
                                profiles.editingProfile.gyro.shakeThreshold
                            },
                            set: { profiles.updateShakeThreshold($0) }
                        ),
                        range: 1.4...3.6,
                        valueText: { String(format: "%.2f g", $0) }
                    )
                    LabeledSlider(
                        label: "Tilt angle",
                        value: Binding(
                            get: {
                                profiles.editingProfile.gyro.tiltThreshold
                            },
                            set: { profiles.updateTiltThreshold($0) }
                        ),
                        range: 0.45...0.88,
                        valueText: {
                            "\(Int(asin(min($0, 1)) * 180 / .pi))°"
                        }
                    )
                    LabeledSlider(
                        label: "Twist speed",
                        value: Binding(
                            get: {
                                profiles.editingProfile.gyro.rotationThreshold
                            },
                            set: { profiles.updateRotationThreshold($0) }
                        ),
                        range: 1.5...6.0,
                        valueText: { String(format: "%.1f rad/s", $0) }
                    )

                    GyroTelemetryMeters(telemetry: model.gyroTelemetry)
                }
                .padding(8)
            }

            GroupBox("Gesture actions") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(
                            "Suggested mappings are optional. Reset restores " +
                            "the single shake-to-delete default."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Spacer()
                        Button("Apply suggested set") {
                            profiles.applySuggestedGyroMappings()
                        }
                        Button("Reset to shake only") {
                            profiles.resetGyroToShakeOnly()
                        }
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(GyroGesture.allCases) { gesture in
                            HStack(spacing: 10) {
                                Image(systemName: gesture.systemImage)
                                    .foregroundStyle(Color.indigo)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(gesture.label)
                                        .lineLimit(1)
                                    Text("Suggested: \(gesture.suggestedAction.label)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                ActionPicker(
                                    selection: Binding(
                                        get: {
                                            profiles.editingProfile.gyro.action(
                                                for: gesture
                                            )
                                        },
                                        set: {
                                            profiles.setGyroAction($0, for: gesture)
                                        }
                                    )
                                )
                                .frame(width: 205)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Motion playground") {
                GyroMiniGameView(model: model)
            }
        }
    }

    private var screenCaptureSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                HStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.cyan.opacity(0.13))
                            .frame(width: 112, height: 88)
                        Image(systemName: "viewfinder.rectangular")
                            .font(.system(size: 45, weight: .medium))
                            .foregroundStyle(Color.cyan)
                        Image(systemName: "highlighter")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.yellow)
                            .offset(x: 34, y: 27)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Capture, copy, then annotate")
                            .font(.title3.weight(.semibold))
                        Text(
                            "Hold R2 and move the left stick to select an " +
                            "area. The original is copied immediately, then " +
                            "the editor opens with controller-friendly tools."
                        )
                        .foregroundStyle(.secondary)
                        Label(
                            "Circle dismisses instantly without changing the original",
                            systemImage: "circle"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
            }

            GroupBox("After capture") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(
                        "Copy the original image to the clipboard",
                        isOn: $screenCapture.copyOriginalToClipboard
                    )
                    Toggle(
                        "Open the annotation editor immediately",
                        isOn: $screenCapture.openEditorAfterCapture
                    )
                    Toggle(
                        "Copy the edited image when I choose Done",
                        isOn: $screenCapture.copyEditedImageOnDone
                    )
                    .disabled(!screenCapture.openEditorAfterCapture)
                    Toggle(
                        "Keep the editor above other windows",
                        isOn: $screenCapture.editorStaysOnTop
                    )
                    .disabled(!screenCapture.openEditorAfterCapture)
                    Toggle(
                        "Return to the previous app after closing the editor",
                        isOn: $screenCapture.returnToPreviousApp
                    )
                    .disabled(!screenCapture.openEditorAfterCapture)

                    if !screenCapture.openEditorAfterCapture &&
                        !screenCapture.copyOriginalToClipboard {
                        Label(
                            "With the editor disabled, ControlDeck still copies " +
                            "the capture so it is not lost.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }

            GroupBox("Editor defaults") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 20) {
                        Picker(
                            "Starting tool",
                            selection: $screenCapture.defaultTool
                        ) {
                            ForEach(ScreenshotEditorTool.allCases) { tool in
                                Label(tool.label, systemImage: tool.systemImage)
                                    .tag(tool)
                            }
                        }
                        Picker(
                            "Line size",
                            selection: $screenCapture.defaultStrokeSize
                        ) {
                            ForEach(ScreenshotStrokeSize.allCases) { size in
                                Text(size.label).tag(size)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Text("Starting colour")
                            .frame(width: 110, alignment: .leading)
                        ForEach(ScreenshotAnnotationColor.allCases) { color in
                            Button {
                                screenCapture.defaultColor = color
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Circle().stroke(
                                            screenCapture.defaultColor == color
                                                ? Color.accentColor
                                                : Color.primary.opacity(0.18),
                                            lineWidth:
                                                screenCapture.defaultColor == color
                                                ? 3 : 1
                                        )
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(color.label)
                        }
                    }

                    HStack {
                        Text(
                            "Highlight, draw, add arrows, boxes or text, and " +
                            "redact sensitive areas. Undo, redo, copy and save " +
                            "are always available."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore defaults") {
                            screenCapture.reset()
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Controller shortcuts in the editor") {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    captureShortcut("Left stick", "Move pointer")
                    captureShortcut("Cross", "Draw or place")
                    captureShortcut("L1 / R1", "Previous / next tool")
                    captureShortcut("Square / Triangle", "Undo / redo")
                    captureShortcut("Touchpad click", "Copy edited image")
                    captureShortcut("Create", "Save PNG")
                    captureShortcut("Options", "Done")
                    captureShortcut("Circle", "Dismiss")
                }
                .padding(8)
            }
        }
    }

    private func captureShortcut(_ control: String, _ action: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(control)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text(action)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }

    private var shiftLayerSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                HStack(spacing: 22) {
                    ProfileWheelSettingsPreview(
                        profiles: profiles.profiles,
                        slots: shiftLayer.profileSlots
                    )
                    .frame(width: 178, height: 178)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Hold Options for the profile wheel")
                            .font(.title3.weight(.semibold))
                        Text(
                            "Move the left stick toward one of eight app " +
                            "profiles, then release Options to switch. Each " +
                            "step has a light haptic so it works by feel."
                        )
                        .foregroundStyle(.secondary)
                        Text(
                            "A quick Options tap still performs its normal " +
                            "mapped action."
                        )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
            }

            GroupBox("Profile wheel slots") {
                VStack(spacing: 14) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 12
                    ) {
                        ForEach(shiftLayer.profileSlots) { slot in
                            let profile = profiles.profile(
                                for: slot.profileKind
                            )
                            HStack(spacing: 12) {
                                Text("\(slot.position + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Color.primary.opacity(0.06),
                                        in: Circle()
                                    )
                                ProfileLogoView(profile: profile, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text(slot.positionLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Picker(
                                    "Profile for \(slot.positionLabel)",
                                    selection: Binding(
                                        get: { slot.profileKind },
                                        set: {
                                            shiftLayer.setProfile(
                                                $0,
                                                at: slot.position
                                            )
                                        }
                                    )
                                ) {
                                    ForEach(profiles.profiles) { candidate in
                                        Label(
                                            candidate.name,
                                            systemImage:
                                                candidate.kind.systemImage
                                        )
                                        .tag(candidate.kind)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 130)
                            }
                            .padding(12)
                            .background(
                                Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(
                                    cornerRadius: 13,
                                    style: .continuous
                                )
                            )
                        }
                    }
                    HStack {
                        Text(
                            "Choosing a profile already on the wheel swaps " +
                            "the two slots. The wheel always stays at eight."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset popular apps") {
                            shiftLayer.reset()
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Reasoning and context") {
                VStack(alignment: .leading, spacing: 14) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Capture + right stick")
                                .font(.headline)
                            Text(
                                "Hold Create/Capture, then flick the right " +
                                "stick up for smarter or down for faster. " +
                                "Each step has a light haptic."
                            )
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "dial.medium")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    Divider()
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Touchpad click")
                                .font(.headline)
                            Text(
                                "Shows the active profile, selected Codex " +
                                "task, primary mappings, and profile wheel."
                            )
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "rectangle.and.hand.point.up.left")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(8)
            }
        }
    }

    private var profileSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(
                        "Automatically switch for the foreground app",
                        isOn: $profiles.autoSwitchEnabled
                    )
                    Text("ControlDeck switches among 16 curated layouts, including Codex, Claude, meetings, creative tools and terminals. Browser tabs such as Meet, Slides and Figma are recognised by context.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 14
            ) {
                ForEach(profiles.profiles) { profile in
                    Button {
                        profiles.setActiveProfile(profile.kind)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: profile.kind.systemImage)
                                .font(.title2)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profileSummary(profile))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if profiles.activeKind == profile.kind {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 82)
                        .background(
                            profiles.activeKind == profile.kind
                                ? Color.accentColor.opacity(0.12)
                                : Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Select a profile, then edit its buttons, touchpad and pointer settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset \(profiles.editingProfile.name)") {
                    profiles.resetEditingProfile()
                }
            }
        }
    }

    private var customizationSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue.gradient)
                        .frame(width: 76)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Describe the controller you want")
                            .font(.title3.weight(.semibold))
                        Text(
                            "Codex can safely remap profiles through local MCP " +
                                "tools. In a developer checkout it can also add " +
                                "new actions or controller behaviour and run the tests."
                        )
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
            }

            GroupBox("Codex connection") {
                HStack(spacing: 14) {
                    Image(
                        systemName: codexExtension.isInstalled
                            ? "checkmark.seal.fill"
                            : "shippingbox"
                    )
                    .font(.title2)
                    .foregroundStyle(
                        codexExtension.isInstalled ? .green : .blue
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            codexExtension.isInstalled
                                ? "Controller tools installed"
                                : "Install controller tools"
                        )
                        .font(.headline)
                        Text(codexExtension.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if codexExtension.isInstalled {
                        Button("Show Files") {
                            codexExtension.revealInstalledFiles()
                        }
                        Button("Open Skills") {
                            codexExtension.openCodexSkills()
                        }
                    } else {
                        Button("Install for Codex") {
                            codexExtension.install()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(8)
            }

            GroupBox("Ask Codex") {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $customizationRequest)
                        .font(.body)
                        .frame(minHeight: 96)
                        .padding(8)
                        .background(
                            Color(nsColor: .textBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(PS5Palette.border, lineWidth: 1)
                        }

                    HStack(spacing: 8) {
                        suggestionButton(
                            "Tune Chrome",
                            prompt:
                                "Make the browser profile ideal for reading, tabs and forms."
                        )
                        suggestionButton(
                            "Remap a button",
                            prompt:
                                "Inspect my Codex profile and suggest a better mapping for Triangle."
                        )
                        suggestionButton(
                            "Add behaviour",
                            prompt:
                                "Add a useful controller action for my daily Codex workflow."
                        )
                        Spacer()
                        Button(
                            codexExtension.isRunning
                                ? "Codex is working…"
                                : "Open task in Codex"
                        ) {
                            codexExtension.runCustomization(
                                customizationRequest
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            codexExtension.isRunning ||
                                !codexExtension.isInstalled ||
                                customizationRequest
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                    .isEmpty
                        )
                    }

                    if !codexExtension.lastOutput.isEmpty {
                        ScrollView {
                            Text(codexExtension.lastOutput)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }
                        .frame(maxHeight: 180)
                        .padding(10)
                        .background(
                            Color.black.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                    }
                }
                .padding(8)
            }

            Text(
                "Profile tools can only read and update ControlDeck settings. " +
                    "They do not expose a shell, personal files, Bluetooth, " +
                    "microphone permissions or other Mac settings."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func suggestionButton(
        _ title: String,
        prompt: String
    ) -> some View {
        Button(title) {
            customizationRequest = prompt
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.16), lineWidth: 7)
                        Circle()
                            .trim(
                                from: 0,
                                to: CGFloat(setupCompletionCount) / 5
                            )
                            .stroke(
                                Color.accentColor,
                                style: StrokeStyle(
                                    lineWidth: 7,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))
                        Text("\(setupCompletionCount)/5")
                            .font(.headline.monospacedDigit())
                    }
                    .frame(width: 66, height: 66)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ready in a few minutes")
                            .font(.title3.weight(.semibold))
                        Text(
                            "Install, pair, grant access, choose a profile " +
                                "and connect Codex. Completed steps update here."
                        )
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if setupCompletionCount == 5 {
                        Label("Ready", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                    }
                }
                .padding(10)
            }

            SetupStep(
                number: 1,
                title: "Install in Applications",
                detail: model.installationResult
            ) {
                Button("Install in Applications") {
                    model.installInApplications()
                }
            }
            SetupStep(
                number: 2,
                title: "Connect the controller",
                detail:
                    "DualSense: hold Create + PS until the light bar flashes. " +
                    "Other controllers use their pairing button. Then select " +
                    "the controller in Bluetooth Settings, or connect by USB."
            ) {
                if controller.isConnected {
                    Label(
                        controller.controllerName,
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                } else {
                    Button("Open Bluetooth Settings") {
                        model.openBluetoothSettings()
                    }
                }
            }
            SetupStep(
                number: 3,
                title: "Allow controller actions",
                detail: "Accessibility lets the app move the pointer and send keyboard shortcuts. The app never requests this repeatedly; use this button if the permission is missing."
            ) {
                if automation.accessibilityTrusted {
                    Label("Enabled", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant Accessibility") {
                        model.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            SetupStep(
                number: 4,
                title: "Choose a profile",
                detail:
                    "Automatic switching is on for Codex, browsers, music, " +
                    "Claude and editors. Every button, gesture and pointer " +
                    "setting remains editable."
            ) {
                Button("View controls") {
                    section = .controller
                }
            }
            SetupStep(
                number: 5,
                title: "Connect Codex customization",
                detail:
                    "Install the local skill and MCP tools so Codex can inspect " +
                    "and safely change controller profiles."
            ) {
                if codexExtension.isInstalled {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Install Codex tools") {
                        codexExtension.install()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            GroupBox("Optional · about 3 minutes") {
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 68, height: 68)
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 31, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text("Take the quick controller tutorial")
                                .font(.headline)
                            if tutorial.hasCompleted {
                                Label(
                                    "Completed",
                                    systemImage: "checkmark.circle.fill"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                            }
                        }
                        Text(
                            "Learn pointer, scrolling, dictation, screen " +
                            "capture and profile switching, then see where " +
                            "the optional advanced controls live."
                        )
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(tutorial.hasCompleted ? "Replay tutorial" : "Start tutorial") {
                        tutorial.start()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
            }

            SetupStep(
                number: 6,
                title: "Wireless controller microphone",
                detail: !controller.controllerFamily.isDualSense
                    ? "Microphone, speaker, lights and adaptive triggers are DualSense-only. Buttons, sticks and app profiles still work."
                    : controller.transport == .bluetooth
                    ? bluetoothMicrophone.lastResult
                    : "Connect over Bluetooth to publish “DualSense Microphone.” Select it in Codex; the first recording may ask to allow Codex under Microphone and Screen & System Audio Recording."
            ) {
                if bluetoothMicrophone.isPublished {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Label("DualSense Microphone available", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            if bluetoothMicrophone.isCapturing {
                                ProgressView(
                                    value: Double(bluetoothMicrophone.inputLevel)
                                )
                                .frame(width: 90)
                            }
                        }
                        Text(model.microphoneDiagnosticResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button(
                                model.microphoneDiagnosticRunning
                                    ? "Testing microphone…"
                                    : "Test wireless mic (3 seconds)"
                            ) {
                                model.runWirelessMicrophoneDiagnostic()
                            }
                            .disabled(
                                model.microphoneDiagnosticRunning ||
                                    model.selfTestRunning
                            )
                            Button("Audio recording privacy") {
                                model.openAudioCapturePrivacySettings()
                            }
                            Button("Microphone privacy") {
                                model.openMicrophonePrivacySettings()
                            }
                            Button("Open Codex microphone settings") {
                                model.openCodexMicrophoneSettings()
                            }
                        }
                        .buttonStyle(.link)
                        Text(
                            "Choose DualSense Microphone in Codex Settings → " +
                                "General. ControlDeck keeps this input published " +
                                "while Bluetooth is connected and does not " +
                                "change the Mac’s system-default microphone."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else if controller.transport == .bluetooth {
                    Button("Prepare wireless microphone") {
                        model.prepareBluetoothMicrophone()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            GroupBox("Supported controllers") {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    ControllerSupportCard(
                        title: "DualSense",
                        detail: "All features",
                        icon: "gamecontroller.fill",
                        highlighted: true
                    )
                    ControllerSupportCard(
                        title: "DualShock 4",
                        detail: "Buttons, sticks, haptics",
                        icon: "gamecontroller"
                    )
                    ControllerSupportCard(
                        title: "Switch Pro / 2",
                        detail: "Buttons and sticks",
                        icon: "gamecontroller"
                    )
                    ControllerSupportCard(
                        title: "8BitDo",
                        detail: "Buttons and sticks",
                        icon: "gamecontroller"
                    )
                    ControllerSupportCard(
                        title: "MFi controllers",
                        detail: "Extended gamepads",
                        icon: "gamecontroller"
                    )
                    ControllerSupportCard(
                        title: "More devices",
                        detail: "Automatic fallback",
                        icon: "plus.circle"
                    )
                }
                .padding(8)
            }

            GroupBox("DualSense feature availability") {
                VStack(spacing: 0) {
                    FeatureRow(
                        feature: "Buttons, sticks and touchpad",
                        usb: true,
                        bluetooth: true
                    )
                    FeatureRow(
                        feature: "Light bar, haptics and adaptive triggers",
                        usb: true,
                        bluetooth: true
                    )
                    FeatureRow(
                        feature: "Controller microphone and mic LED",
                        usb: true,
                        bluetooth: true
                    )
                    FeatureRow(
                        feature: "Controller speaker",
                        usb: true,
                        bluetooth: true
                    )
                }
                .padding(8)
            }

            if controller.isConnected {
                Button("Run safe hardware self-test") {
                    model.runSelfTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.selfTestRunning ||
                        model.microphoneDiagnosticRunning
                )
            }
        }
        .onAppear {
            if setupCompletionCount == 5 {
                tutorial.offerIfNeeded()
            }
        }
        .onChange(of: setupCompletionCount) { _, completed in
            if completed == 5 {
                tutorial.offerIfNeeded()
            }
        }
    }

    private func openTutorialDestination(
        _ destination: QuickTutorialDestination
    ) {
        switch destination {
        case .buttonMapping: section = .controller
        case .touchpad: section = .touchpad
        case .pointer: section = .pointer
        case .screenCapture: section = .screenCapture
        case .shiftLayer: section = .shiftLayer
        case .profiles: section = .profiles
        case .gyro: section = .gyro
        case .customize: section = .customize
        }
    }

    private var setupCompletionCount: Int {
        var completed = 1
        if controller.isConnected { completed += 1 }
        if automation.accessibilityTrusted { completed += 1 }
        if profiles.autoSwitchEnabled { completed += 1 }
        if codexExtension.isInstalled { completed += 1 }
        return completed
    }

    private var profileStrip: some View {
        HStack {
            Text("Editing")
                .foregroundStyle(.secondary)
            Picker(
                "Profile",
                selection: Binding(
                    get: { profiles.editingKind },
                    set: { profiles.setActiveProfile($0) }
                )
            ) {
                ForEach(profiles.profiles) { profile in
                    Label(profile.name, systemImage: profile.kind.systemImage)
                        .tag(profile.kind)
                }
            }
            .labelsHidden()
            .frame(width: 240)
            Spacer()
            Button("Reset profile") {
                profiles.resetEditingProfile()
            }
        }
    }

    private func profileSummary(_ profile: ControllerProfile) -> String {
        switch profile.kind {
        case .codex: "Tasks, review, approvals and dictation"
        case .general: "Pointer, windows and system navigation"
        case .chrome: "Tabs, navigation, find and address bar"
        case .spotify: "Playback, tracks and volume"
        case .claude: "Chat, navigation, dictation and screenshots"
        case .xcode: "Pointer, navigation and Codex shortcuts"
        case .finder: "Files, Quick Look, tabs, copy and paste"
        case .meetings: "Push to talk, camera, chat, sharing and hand raise"
        case .presentations: "Start, advance, notes, pointer and blank screen"
        case .slack: "Conversations, unread messages, threads and huddles"
        case .mail: "Archive, reply, read state and dictation"
        case .photos: "Browse, favourite, edit, rotate and zoom"
        case .figma: "Canvas pointer, tools, undo, redo and zoom"
        case .videoEditing: "J-K-L playback, marks and edit navigation"
        case .logic: "Playback, record, transport and volume"
        case .terminal: "Tabs, history, cursor movement, copy and paste"
        }
    }
}

private struct ActionPicker: View {
    @Binding var selection: MappedAction

    var body: some View {
        Picker("Action", selection: $selection) {
            ForEach(ActionCategory.allCases) { category in
                Section(category.label) {
                    ForEach(
                        MappedAction.allCases.filter { $0.category == category }
                    ) { action in
                        Text(action.label).tag(action)
                    }
                }
            }
        }
        .labelsHidden()
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: (Double) -> String

    init(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: @escaping (Double) -> String = {
            String(format: "%.2f×", $0)
        }
    ) {
        self.label = label
        _value = value
        self.range = range
        self.valueText = valueText
    }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 140, alignment: .leading)
            Slider(value: $value, in: range)
            Text(valueText(value))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PermissionCard: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "accessibility")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility permission required")
                    .font(.headline)
                Text("Required for pointer control, shortcuts and visible approval buttons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Grant access", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SetupStep<Accessory: View>: View {
    let number: Int
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.blue, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 18)
            accessory
        }
        .padding(16)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

private struct ProfileWheelSettingsPreview: View {
    let profiles: [ControllerProfile]
    let slots: [ProfileWheelSlot]

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) * 0.36
            ZStack {
                Circle()
                    .fill(
                        Color(red: 0.07, green: 0.1, blue: 0.13)
                            .opacity(0.94)
                    )
                Circle()
                    .stroke(Color.accentColor.opacity(0.42), lineWidth: 2)
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(
                        width: proxy.size.width * 0.32,
                        height: proxy.size.height * 0.32
                    )
                    .overlay {
                        Image(systemName: "l.joystick.tilt.up")
                            .foregroundStyle(Color.accentColor)
                    }

                ForEach(slots) { slot in
                    if let profile = profiles.first(where: {
                        $0.kind == slot.profileKind
                    }) {
                        let radians = (-90 + Double(slot.position * 45)) *
                            .pi / 180
                        ProfileLogoView(profile: profile, size: 27)
                            .offset(
                                x: cos(radians) * radius,
                                y: sin(radians) * radius
                            )
                    }
                }
            }
            .padding(6)
        }
        .accessibilityLabel("Eight-slot profile wheel preview")
    }
}

private struct ControllerSupportCard: View {
    let title: String
    let detail: String
    let icon: String
    var highlighted = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    highlighted ? Color.accentColor : Color.secondary
                )
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            highlighted
                ? Color.accentColor.opacity(0.08)
                : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 11)
        )
    }
}

private struct FeatureRow: View {
    let feature: String
    let usb: Bool
    let bluetooth: Bool

    var body: some View {
        HStack {
            Text(feature)
            Spacer()
            AvailabilityLabel(title: "USB", available: usb)
                .frame(width: 100)
            AvailabilityLabel(title: "Bluetooth", available: bluetooth)
                .frame(width: 130)
        }
        .padding(.vertical, 8)
    }
}

private struct AvailabilityLabel: View {
    let title: String
    let available: Bool

    var body: some View {
        Label(
            title,
            systemImage: available ? "checkmark.circle.fill" : "minus.circle"
        )
        .foregroundStyle(available ? .green : .secondary)
    }
}

private struct StatePill: View {
    let state: CodexTaskState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(nsColor: state.color))
                .frame(width: 8, height: 8)
            Text(state.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: state.color).opacity(0.13), in: Capsule())
    }
}
