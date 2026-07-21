import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class AppModel: ObservableObject {
    let controller = DualSenseControllerService()
    let audio = AudioDeviceService()
    let bluetoothMicrophone = BluetoothMicrophoneService()
    let automation = CodexAutomation()
    let taskMonitor = CodexTaskMonitor()
    let profiles: ProfileStore
    let shiftLayer: ShiftLayerStore
    let tutorial: QuickTutorialStore
    let screenCapturePreferences: ScreenCapturePreferences
    let screenshotEditor: ScreenshotEditorController
    let pointer = PointerService()
    let touchpad = TouchpadGestureEngine()
    let codexExtension = CodexExtensionService()
    let gyroTelemetry = GyroTelemetry()

    @Published private(set) var currentState: CodexTaskState = .disconnected
    @Published private(set) var recentTasks: [RecentCodexTask] = []
    @Published private(set) var selectedTaskID: String?
    @Published private(set) var lastAction = "Ready"
    @Published private(set) var pushToTalkActive = false
    @Published var soundTheme = ControllerPreferences.soundTheme {
        didSet { ControllerPreferences.soundTheme = soundTheme }
    }
    @Published var statusHaptics = ControllerPreferences.statusHaptics {
        didSet { ControllerPreferences.statusHaptics = statusHaptics }
    }
    @Published private(set) var selfTestRunning = false
    @Published private(set) var microphoneDiagnosticRunning = false
    @Published private(set) var microphoneDiagnosticResult =
        "Controller microphone has not been tested yet"
    @Published private(set) var installationResult =
        "Run from Applications for the smoothest startup experience."
    @Published private(set) var lastGyroGesture: GyroGesture?
    @Published private(set) var gyroGameActive = false

    private let hud = HUDController()
    private let controllerOverlay = ControllerOverlayController()
    private var started = false
    private var lastStates: [String: CodexTaskState] = [:]
    private var accessibilityObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var voiceCaptureMode: VoiceCaptureMode?
    private var voiceCaptureTransport: ControllerTransport?
    private var voiceStopPending = false
    private var voiceStopGeneration = 0
    private var selfTestGeneration = 0
    private var microphoneDiagnosticGeneration = 0
    private var hybridDictationGeneration = 0
    private var hybridDictationPressed = false
    private var soundGeneration = 0
    private var heldMouseInputs: [ControllerInput: CGMouseButton] = [:]
    private var screenshotEditorCapturedInputs: Set<ControllerInput> = []
    private var tutorialCapturedInputs: Set<ControllerInput> = []
    private var optionsPressed = false
    private var optionsLayerActive = false
    private var optionsLayerUsed = false
    private var optionsGeneration = 0
    private var profileWheelSelector = RadialProfileSelector()
    private var createPressed = false
    private var createLayerUsed = false
    private var reasoningControlOpen = false
    private var reasoningControlReady = false
    private var pendingReasoningSteps: [ReasoningStep] = []
    private var reasoningGeneration = 0
    private var reasoningGate = SteppedStickGate()
    private var gyroEngine = GyroGestureEngine()
    private var telemetryRateLimiter = TelemetryRateLimiter(
        minimumInterval: 1.0 / 30.0
    )
    private var cancellables: Set<AnyCancellable> = []
    private let logger = Logger(
        subsystem: "com.ianhansel.controldeck",
        category: "app"
    )

    init() {
        let capturePreferences = ScreenCapturePreferences()
        screenCapturePreferences = capturePreferences
        screenshotEditor = ScreenshotEditorController(
            preferences: capturePreferences
        )
        tutorial = QuickTutorialStore()
        profiles = ProfileStore()
        shiftLayer = ShiftLayerStore()
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    func start() {
        guard !started else { return }
        started = true

        controller.onEvent = { [weak self] event in
            self?.handle(event)
        }
        controller.onBluetoothMicrophonePacket = { [weak self] packet in
            self?.bluetoothMicrophone.ingest(packet)
        }
        controller.onBluetoothMicrophoneRecoveryRequired = { [weak self] message in
            self?.feedbackFailure(message)
        }
        controller.onTransportChanged = { [weak self] transport in
            self?.controllerTransportChanged(transport)
        }
        touchpad.onPointerDelta = { [weak self] deltaX, deltaY in
            self?.pointer.moveImmediately(deltaX: deltaX, deltaY: deltaY)
        }
        touchpad.onScrollDelta = { [weak self] deltaX, deltaY in
            self?.pointer.scroll(deltaX: deltaX, deltaY: deltaY)
        }
        touchpad.onGesture = { [weak self] gesture in
            guard let self else { return }
            let action = self.profiles.activeProfile.touchpad.action(for: gesture)
            self.execute(action, source: gesture.label)
        }
        pointer.onScreenshotCaptured = { [weak self] image in
            self?.screenshotCaptured(image)
        }
        pointer.onScreenshotCaptureFailed = { [weak self] message in
            self?.feedbackFailure(message)
        }
        screenshotEditor.onDone = { [weak self] copied in
            guard let self else { return }
            self.lastAction = copied
                ? "Edited screenshot copied to clipboard"
                : "Screenshot editor closed"
            self.hud.show(
                copied ? "Copied to clipboard" : "Screenshot editor closed",
                detail: copied
                    ? "The current image and markup are ready to paste"
                    : "The clipboard was not changed",
                color: copied ? .systemGreen : .systemGray
            )
            self.controller.playHaptic(copied ? .success : .selection)
        }
        taskMonitor.onTasksChanged = { [weak self] tasks in
            self?.tasksChanged(tasks)
        }
        profiles.$activeKind
            .combineLatest(profiles.$profiles)
            .sink { [weak self] kind, profiles in
                guard let self else { return }
                let enabled = profiles.first(where: { $0.kind == kind })?
                    .gyro.enabled ?? true
                self.controller.setMotionSensorsActive(
                    enabled || self.gyroGameActive
                )
            }
            .store(in: &cancellables)

        automation.refreshAccessibility()
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.automation.refreshAccessibility()
                self?.profiles.refreshActiveProfile()
                self?.shiftLayer.reloadExternalChanges()
            }
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.shutdown()
            }
        }

        // Clear a process tap left behind by an unclean prior termination
        // before publishing whichever microphone matches this connection.
        bluetoothMicrophone.teardown()
        audio.refresh()
        if audio.controllerAudioAvailable {
            _ = audio.ensureCodexMicrophone()
        }
        controller.start()
        taskMonitor.start()
        updateState(.idle)
        logger.notice(
            "ControlDeck started; controllerAudio=\(self.audio.controllerAudioAvailable) accessibility=\(self.automation.accessibilityTrusted)"
        )

        if CommandLine.arguments.contains("--self-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.runSelfTest()
            }
        }
        if CommandLine.arguments.contains("--wireless-mic-self-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.audio.removeCodexMicrophone()
                self?.bluetoothMicrophone.runAudioBridgeSelfTest()
            }
        }
        if CommandLine.arguments.contains("--wireless-mic-hardware-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                [weak self] in
                self?.runWirelessMicrophoneDiagnostic()
            }
        }
    }

    func requestAccessibility() {
        automation.requestAccessibility()
        if !automation.accessibilityTrusted,
           let url = URL(
               string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
           ) {
            NSWorkspace.shared.open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.automation.refreshAccessibility()
        }
    }

    func openBluetoothSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.BluetoothSettings"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    func installInApplications() {
        let fileManager = FileManager.default
        let source = Bundle.main.bundleURL
        let applications = URL(
            fileURLWithPath: "/Applications",
            isDirectory: true
        )
        if source.deletingLastPathComponent() == applications {
            installationResult = "ControlDeck is already installed."
            return
        }
        let destination = applications.appendingPathComponent(
            source.lastPathComponent,
            isDirectory: true
        )
        guard !fileManager.fileExists(atPath: destination.path) else {
            installationResult =
                "An existing copy is already in Applications."
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            return
        }
        do {
            try fileManager.copyItem(at: source, to: destination)
            installationResult =
                "Installed in Applications. You can keep this window open."
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            installationResult =
                "Drag the app into Applications: \(error.localizedDescription)"
            NSWorkspace.shared.open(applications)
        }
    }

    func openAudioCapturePrivacySettings() {
        let destinations = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ]
        if let url = destinations.compactMap(URL.init(string:)).first {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophonePrivacySettings() {
        let destinations = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ]
        if let url = destinations.compactMap(URL.init(string:)).first {
            NSWorkspace.shared.open(url)
        }
    }

    func openCodexMicrophoneSettings() {
        if controller.transport == .bluetooth {
            _ = bluetoothMicrophone.prepare()
        } else if controller.transport == .usb {
            audio.refresh()
            if audio.controllerAudioAvailable {
                _ = audio.ensureCodexMicrophone()
            }
        }
        _ = automation.openSettings()
        lastAction =
            "Choose DualSense Microphone in Codex Settings → General"
    }

    func runSelfTest() {
        guard !selfTestRunning else { return }
        guard controller.isConnected else {
            feedbackFailure("Connect the DualSense before running the test")
            return
        }
        guard !pushToTalkActive,
              !voiceStopPending,
              !microphoneDiagnosticRunning
        else {
            feedbackFailure(
                "Finish the microphone session before running the self-test"
            )
            return
        }
        selfTestGeneration += 1
        let generation = selfTestGeneration
        selfTestRunning = true
        pointer.stop()
        touchpad.cancel()
        lastAction = "Testing one haptic, then one speaker tone"
        hud.show(
            "Safe DualSense self-test",
            detail: "One gentle haptic · one short tone",
            color: .systemCyan
        )
        controller.runSafeHapticSelfTest { [weak self] in
            guard let self,
                  self.selfTestRunning,
                  self.selfTestGeneration == generation
            else {
                return
            }
            if self.controller.transport == .bluetooth {
                self.lastAction = "Playing one Bluetooth speaker tone"
                let started = self.controller.playBluetoothSpeakerTone(
                    frequency: 660,
                    duration: 0.10,
                    volume: 0.07
                ) { [weak self] speakerResult in
                    self?.completeSelfTest(
                        generation: generation,
                        result: speakerResult.localizedCaseInsensitiveContains(
                            "played"
                        ) ? nil : speakerResult
                    )
                }
                guard started else {
                    self.completeSelfTest(
                        generation: generation,
                        result: self.controller.lastBluetoothSpeakerResult
                    )
                    return
                }
            } else if self.controller.transport == .usb,
                      self.audio.controllerAudioAvailable {
                self.lastAction = "Playing one controller speaker tone"
                _ = self.audio.playControllerTone(
                    frequency: 660,
                    duration: 0.10,
                    volume: 0.07
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    [weak self] in
                    self?.completeSelfTest(generation: generation)
                }
            } else {
                self.completeSelfTest(generation: generation)
            }
        }
    }

    func runWirelessMicrophoneDiagnostic() {
        guard !microphoneDiagnosticRunning else { return }
        guard controller.transport == .bluetooth else {
            feedbackFailure(
                "Connect the DualSense over Bluetooth before testing its mic"
            )
            return
        }
        guard !pushToTalkActive, !voiceStopPending, !selfTestRunning else {
            feedbackFailure("Finish the current test or dictation first")
            return
        }

        microphoneDiagnosticGeneration += 1
        let generation = microphoneDiagnosticGeneration
        microphoneDiagnosticRunning = true
        microphoneDiagnosticResult = "Speak into the controller now…"
        pointer.stop()
        touchpad.cancel()
        audio.removeCodexMicrophone()
        guard bluetoothMicrophone.startCapture() else {
            microphoneDiagnosticRunning = false
            feedbackFailure(bluetoothMicrophone.lastResult)
            return
        }
        guard controller.setBluetoothMicrophoneCapture(true) else {
            bluetoothMicrophone.stopCapture()
            microphoneDiagnosticRunning = false
            feedbackFailure(controller.lastBluetoothMicrophoneResult)
            return
        }

        lastAction = "Speak into the controller for three seconds"
        hud.show(
            "Testing wireless microphone",
            detail: "Speak now · no Codex actions will be triggered",
            color: .systemCyan
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            [weak self] in
            guard let self,
                  self.microphoneDiagnosticRunning,
                  self.microphoneDiagnosticGeneration == generation
            else {
                return
            }
            _ = self.controller.setBluetoothMicrophoneCapture(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                [weak self] in
                self?.completeWirelessMicrophoneDiagnostic(
                    generation: generation
                )
            }
        }
    }

    func perform(_ action: ControllerAction) {
        let succeeded = automation.run(action)
        finish(action.label, succeeded: succeeded)
    }

    func perform(_ action: MappedAction) {
        execute(action, source: "ControlDeck")
    }

    func toggleVoiceCapture() {
        toggleVoiceCapture(initiator: nil)
    }

    func prepareBluetoothMicrophone() {
        audio.removeCodexMicrophone()
        if bluetoothMicrophone.prepare() {
            lastAction = "Wireless DualSense Microphone is ready"
        } else {
            feedbackFailure(bluetoothMicrophone.lastResult)
        }
    }

    private func handle(_ event: ControllerEvent) {
        // Diagnostics are output-only. Reports arriving during a hardware test
        // must never execute mouse, keyboard, Codex, browser or media actions.
        if selfTestRunning || microphoneDiagnosticRunning {
            return
        }
        if voiceStopPending {
            return
        }
        if controller.isBluetoothMicrophoneInputSuppressed,
           !isVoiceStopEvent(event) {
            // Bluetooth audio shares report 0x31 with controller state. Only
            // validated raw-HID stop controls are allowed while GameController
            // input is suppressed and the stream drains.
            return
        }

        switch event {
        case let .button(input, pressed):
            handleButton(input, pressed: pressed)
        case let .stick(stick, x, y):
            if screenshotEditor.isPresented {
                guard stick == .left else { return }
                pointer.updateStick(
                    .left,
                    x: x,
                    y: y,
                    settings: Self.screenshotEditorPointerSettings
                )
                return
            }
            if stick == .left, optionsPressed {
                if !optionsLayerActive,
                   sqrt((x * x) + (y * y)) >= 0.28 {
                    activateOptionsLayer()
                }
                if optionsLayerActive {
                    handleProfileWheelStick(x: x, y: y)
                }
                return
            }
            if stick == .right, createPressed {
                handleReasoningStick(y: y)
                return
            }
            let pointerSettings = profiles.activeProfile.pointer
            pointer.updateStick(
                stick,
                x: x,
                y: y,
                settings: pointerSettings
            )
            pointer.updateScrollStick(
                stick,
                x: x,
                y: y,
                settings: pointerSettings,
                pointerSource: pointerSettings.source
            )
        case let .touch(finger, x, y, active):
            touchpad.settings = profiles.activeProfile.touchpad
            touchpad.update(finger: finger, x: x, y: y, active: active)
        case let .action(action):
            perform(action)
        case let .pushToTalk(active):
            setPushToTalk(
                active,
                mode: active ? .hold(.l2) : nil
            )
        case .microphoneButton:
            toggleVoiceCapture(initiator: .microphone)
        case let .motion(sample):
            handleMotion(sample)
        }
    }

    func setGyroGameActive(_ active: Bool) {
        gyroGameActive = active
        gyroEngine.reset()
        controller.setMotionSensorsActive(
            active || profiles.activeProfile.gyro.enabled
        )
        if active {
            lastAction = "Gyro mini-game active · normal motion actions paused"
        }
    }

    func gyroGameDidReachGoal() {
        controller.playHaptic(.success)
        lastAction = "Gyro course complete"
    }

    func gyroGameDidFall() {
        controller.playHaptic(.warning)
        lastAction = "Gyro ball recovered · two-second penalty"
    }

    func gyroGameDidCollectToken() {
        controller.playHaptic(.selection)
        lastAction = "Gyro time token · one second recovered"
    }

    private func handleMotion(_ sample: ControllerMotionSample) {
        if telemetryRateLimiter.shouldPublish(at: sample.timestamp) {
            gyroTelemetry.update(sample)
        }
        guard !gyroGameActive else { return }
        let settings = profiles.activeProfile.gyro
        guard let gesture = gyroEngine.update(sample, settings: settings) else {
            return
        }
        lastGyroGesture = gesture
        let action = settings.action(for: gesture)
        guard action != .none else {
            lastAction = "\(gesture.label) detected · no action assigned"
            return
        }
        if gesture == .shake {
            controller.playHaptic(.warning)
        } else {
            controller.playHaptic(.selection)
        }
        execute(action, source: gesture.label)
    }

    private func handleButton(_ input: ControllerInput, pressed: Bool) {
        if !pressed, screenshotEditorCapturedInputs.remove(input) != nil {
            if input == .cross {
                pointer.setButton(.left, pressed: false)
            }
            return
        }
        if !pressed, tutorialCapturedInputs.remove(input) != nil {
            return
        }
        if screenshotEditor.isPresented {
            if pressed { screenshotEditorCapturedInputs.insert(input) }
            if input == .cross {
                pointer.setButton(.left, pressed: pressed)
                if pressed { controller.playHaptic(.selection) }
                return
            }
            guard pressed else { return }
            if let editorAction = screenshotEditor.handleControllerButton(input) {
                handleScreenshotEditorAction(editorAction)
            }
            return
        }
        if tutorial.isPresented {
            if pressed { tutorialCapturedInputs.insert(input) }
            guard pressed else { return }
            if let result = tutorial.handleControllerButton(input) {
                switch result {
                case .changedStep:
                    lastAction = "Tutorial · \(tutorial.currentStep.title)"
                    controller.playHaptic(.selection)
                case .completed:
                    lastAction = "Quick tutorial complete"
                    controller.playHaptic(.success)
                case .skipped:
                    lastAction = "Tutorial skipped · replay it from Setup"
                    controller.playHaptic(.selection)
                }
            }
            return
        }
        if input == .options {
            handleOptionsButton(pressed: pressed)
            return
        }
        if input == .create {
            handleCreateButton(pressed: pressed)
            return
        }
        if optionsPressed {
            if pressed { optionsLayerUsed = true }
            return
        }

        let action = profiles.activeProfile.action(for: input)
        if !pressed, let button = heldMouseInputs.removeValue(forKey: input) {
            pointer.setButton(button, pressed: false)
            lastAction = "\(action.label) released"
            return
        }
        if pressed, let button = mouseButton(for: action) {
            heldMouseInputs[input] = button
            pointer.setButton(button, pressed: true)
            lastAction = "\(action.label) · hold and move to drag"
            controller.playHaptic(.selection)
            return
        }
        if action == .meetingPushToTalk {
            let succeeded = automation.setMeetingPushToTalk(pressed)
            lastAction = succeeded
                ? (pressed ? "Meeting push to talk" : "Meeting microphone muted")
                : automation.lastResult
            if pressed && succeeded {
                controller.playHaptic(.selection)
            } else if !succeeded {
                feedbackFailure(automation.lastResult)
            }
            return
        }
        if action == .codexDictation {
            if input == .l2 {
                handleHybridDictation(input: input, pressed: pressed)
            } else if pressed {
                toggleVoiceCapture(initiator: input)
            }
            return
        }
        if action == .screenshotSelection {
            if pressed {
                pointer.keepScreenshotOnClipboard =
                    screenCapturePreferences.copyOriginalToClipboard ||
                    !screenCapturePreferences.openEditorAfterCapture
                if pointer.beginScreenshotSelection() {
                    lastAction =
                        "Drag with the left stick, then release \(input.label)"
                    hud.show(
                        "Select a screenshot area",
                        detail: "Move with the left stick · release to capture",
                        color: .systemBlue
                    )
                    controller.playHaptic(.selection)
                } else {
                    feedbackFailure(
                        "Accessibility is required for screenshot selection"
                    )
                }
            } else if pointer.isSelectingScreenshot {
                pointer.endScreenshotSelection()
                lastAction = "Finishing screen capture"
                controller.playHaptic(.success)
            }
            return
        }
        guard pressed else { return }
        execute(action, source: input.label)
    }

    private func mouseButton(for action: MappedAction) -> CGMouseButton? {
        switch action {
        case .mouseLeftClick: .left
        case .mouseRightClick: .right
        case .mouseMiddleClick: .center
        default: nil
        }
    }

    private func screenshotCaptured(_ image: NSImage) {
        pointer.stop()
        if screenCapturePreferences.openEditorAfterCapture {
            screenshotEditor.present(image: image)
            lastAction = screenCapturePreferences.copyOriginalToClipboard
                ? "Screenshot copied · editor open"
                : "Screenshot editor open"
            hud.show(
                "Screen capture ready",
                detail: "Edit with the controller or dismiss with Circle",
                color: .systemCyan
            )
        } else {
            lastAction = "Screenshot copied to clipboard"
            hud.show(
                "Screenshot copied",
                detail: "Ready to paste",
                color: .systemGreen
            )
        }
        controller.playHaptic(.success)
    }

    private func handleScreenshotEditorAction(
        _ action: ScreenshotEditorControllerAction
    ) {
        switch action {
        case let .tool(tool):
            lastAction = "Screenshot tool · \(tool)"
            controller.playHaptic(.selection)
        case .undo:
            lastAction = "Screenshot edit undone"
            controller.playHaptic(.selection)
        case .redo:
            lastAction = "Screenshot edit redone"
            controller.playHaptic(.selection)
        case .copied:
            lastAction = "Edited screenshot copied"
            controller.playHaptic(.success)
        case .saved:
            lastAction = "Edited screenshot saved"
            controller.playHaptic(.success)
        case .dismissed:
            lastAction = "Screenshot editor dismissed · original kept"
            controller.playHaptic(.selection)
        case .done:
            break
        }
    }

    private static var screenshotEditorPointerSettings: StickPointerSettings {
        StickPointerSettings(
            source: .left,
            speed: 1_050,
            acceleration: 1.65,
            deadZone: 0.12,
            scrollSource: .off,
            scrollSpeed: 0,
            scrollAcceleration: 1,
            scrollDeadZone: 0.2
        )
    }

    private func handleOptionsButton(pressed: Bool) {
        if pressed {
            guard !optionsPressed else { return }
            optionsPressed = true
            optionsLayerActive = false
            optionsLayerUsed = false
            profileWheelSelector.reset()
            optionsGeneration += 1
            let generation = optionsGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                [weak self] in
                guard let self,
                      self.optionsPressed,
                      self.optionsGeneration == generation,
                      !self.optionsLayerActive
                else {
                    return
                }
                self.activateOptionsLayer()
            }
            return
        }

        guard optionsPressed else { return }
        optionsPressed = false
        optionsGeneration += 1
        let selectedIndex = profileWheelSelector.selectedIndex
        let shouldRunTapAction = !optionsLayerActive && !optionsLayerUsed
        optionsLayerActive = false
        profileWheelSelector.reset()
        controllerOverlay.hide()
        if let selectedIndex {
            let slot = shiftLayer.slot(at: selectedIndex)
            let profile = profiles.profile(for: slot.profileKind)
            profiles.setActiveProfileFromWheel(slot.profileKind)
            lastAction = "Profile switched · \(profile.name)"
            hud.show(
                profile.name,
                detail: "Controller profile selected",
                color: .systemCyan
            )
            controller.playHaptic(.success)
            return
        }
        if shouldRunTapAction {
            execute(
                profiles.activeProfile.action(for: .options),
                source: ControllerInput.options.label
            )
        }
    }

    private func activateOptionsLayer() {
        optionsLayerActive = true
        controllerOverlay.showProfileWheel(
            profiles: profiles.profiles,
            slots: shiftLayer.profileSlots,
            activeKind: profiles.activeKind,
            selectedIndex: profileWheelSelector.selectedIndex
        )
        lastAction = "Profile wheel · choose with the left stick"
        controller.playHaptic(.selection)
    }

    private func handleProfileWheelStick(x: Float, y: Float) {
        let previous = profileWheelSelector.selectedIndex
        let selected = profileWheelSelector.update(x: x, y: y)
        guard selected != previous else { return }
        controllerOverlay.showProfileWheel(
            profiles: profiles.profiles,
            slots: shiftLayer.profileSlots,
            activeKind: profiles.activeKind,
            selectedIndex: selected
        )
        if let selected {
            let profile = profiles.profile(
                for: shiftLayer.slot(at: selected).profileKind
            )
            lastAction = "Profile wheel · \(profile.name)"
            controller.playHaptic(.selection)
        }
    }

    private func handleCreateButton(pressed: Bool) {
        if pressed {
            guard !createPressed else { return }
            createPressed = true
            createLayerUsed = false
            reasoningControlOpen = false
            reasoningControlReady = false
            pendingReasoningSteps.removeAll()
            reasoningGate.reset()
            reasoningGeneration += 1
            return
        }

        guard createPressed else { return }
        createPressed = false
        reasoningGate.reset()
        controllerOverlay.hide()
        if createLayerUsed {
            if reasoningControlOpen, reasoningControlReady {
                automation.finishReasoningAdjustment()
                reasoningControlOpen = false
                reasoningControlReady = false
            }
        } else {
            execute(
                profiles.activeProfile.action(for: .create),
                source: ControllerInput.create.label
            )
        }
    }

    private func handleReasoningStick(y: Float) {
        guard let step = reasoningGate.update(y: y) else { return }
        createLayerUsed = true
        controllerOverlay.showReasoning(
            profile: profiles.activeProfile,
            task: overlayTask,
            step: step
        )
        lastAction = "Reasoning · \(step.title)"
        controller.playHaptic(.selection)

        if reasoningControlOpen {
            if reasoningControlReady {
                _ = automation.adjustReasoning(step)
            } else {
                pendingReasoningSteps.append(step)
            }
            return
        }

        reasoningControlOpen = true
        reasoningControlReady = false
        pendingReasoningSteps = [step]
        reasoningGeneration += 1
        let generation = reasoningGeneration
        let started = automation.beginReasoningAdjustment {
            [weak self] in
            guard let self, self.reasoningGeneration == generation else {
                return
            }
            if self.createPressed {
                self.reasoningControlReady = true
                for pendingStep in self.pendingReasoningSteps {
                    _ = self.automation.adjustReasoning(pendingStep)
                }
                self.pendingReasoningSteps.removeAll()
            } else {
                self.automation.finishReasoningAdjustment()
                self.reasoningControlOpen = false
                self.reasoningControlReady = false
                self.pendingReasoningSteps.removeAll()
            }
        }
        if !started {
            reasoningControlOpen = false
            reasoningControlReady = false
            pendingReasoningSteps.removeAll()
            feedbackFailure(automation.lastResult)
        }
    }

    private func handleHybridDictation(
        input: ControllerInput,
        pressed: Bool
    ) {
        if pressed {
            hybridDictationPressed = true
            hybridDictationGeneration += 1
            let generation = hybridDictationGeneration

            if pushToTalkActive,
               voiceCaptureMode == .toggle(input) {
                setPushToTalk(false, handsFree: true)
                return
            }
            guard !pushToTalkActive else { return }
            setPushToTalk(
                true,
                mode: .pendingTapOrHold(input)
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                [weak self] in
                guard let self,
                      self.hybridDictationPressed,
                      self.hybridDictationGeneration == generation,
                      self.voiceCaptureMode == .pendingTapOrHold(input)
                else {
                    return
                }
                self.voiceCaptureMode = .hold(input)
                self.lastAction = "Release \(input.label) to stop dictation"
            }
            return
        }

        hybridDictationPressed = false
        hybridDictationGeneration += 1
        switch voiceCaptureMode {
        case .pendingTapOrHold(input):
            voiceCaptureMode = .toggle(input)
            lastAction = "Hands-free dictation · tap \(input.label) to stop"
            hud.show(
                "Hands-free Codex dictation",
                detail: "Tap \(input.label) again to stop and insert",
                color: CodexTaskState.listening.color
            )
            controller.playHaptic(.selection)
        case .hold(input):
            setPushToTalk(false)
        default:
            break
        }
    }

    private func execute(_ action: MappedAction, source: String) {
        guard action != .none else {
            lastAction = "\(source) has no assigned action"
            return
        }

        switch action {
        case .mouseLeftClick:
            pointer.click(.left)
            finish(action.label, succeeded: true)
        case .mouseRightClick:
            pointer.click(.right)
            finish(action.label, succeeded: true)
        case .mouseMiddleClick:
            pointer.click(.center)
            finish(action.label, succeeded: true)
        case .codexDictation:
            toggleVoiceCapture()
        case .codexPreviousTask:
            selectAdjacentTask(offset: -1)
        case .codexNextTask:
            selectAdjacentTask(offset: 1)
        case .showControllerOverlay:
            showControllerContext()
        case .deleteTextWithConfirmation:
            let deleted = automation.confirmDeleteFocusedText()
            lastAction = automation.lastResult
            if deleted {
                hud.show("Text deleted", color: .systemGreen)
                controller.playHaptic(.success)
            } else if automation.lastResult == "Delete cancelled" {
                controller.playHaptic(.selection)
            } else {
                feedbackFailure(automation.lastResult)
            }
        default:
            finish(action.label, succeeded: automation.run(action))
        }
    }

    var selectedTask: RecentCodexTask? {
        guard let selectedTaskID else { return nil }
        return recentTasks.first(where: { $0.id == selectedTaskID })
    }

    func selectTask(_ id: String) {
        guard let task = recentTasks.first(where: { $0.id == id }) else {
            return
        }
        selectedTaskID = id
        updateAggregateState()
        let succeeded = automation.openThread(id)
        lastAction = succeeded
            ? "Selected · \(task.shortTitle)"
            : automation.lastResult
        if succeeded {
            hud.show(
                "Selected task",
                detail: task.shortTitle,
                color: task.state.color
            )
            controller.playHaptic(.selection)
        } else {
            feedbackFailure(automation.lastResult)
        }
    }

    private func selectAdjacentTask(offset: Int) {
        guard let id = TaskSelection.adjacentID(
            in: recentTasks,
            selectedID: selectedTaskID,
            offset: offset
        ) else {
            finish(
                offset < 0 ? "Previous task" : "Next task",
                succeeded: automation.run(
                    offset < 0 ? .codexPreviousTask : .codexNextTask
                )
            )
            return
        }
        selectTask(id)
    }

    private func showControllerContext() {
        controllerOverlay.showContext(
            profile: profiles.activeProfile,
            task: overlayTask,
            profiles: profiles.profiles,
            slots: shiftLayer.profileSlots
        )
        lastAction = "Controller overlay"
        controller.playHaptic(.selection)
    }

    private var overlayTask: ControllerOverlayTask? {
        selectedTask.map {
            ControllerOverlayTask(title: $0.shortTitle, state: $0.state)
        }
    }

    private func finish(_ label: String, succeeded: Bool) {
        lastAction = succeeded ? label : automation.lastResult
        if succeeded {
            hud.show(label, color: currentState.color)
            controller.playHaptic(.selection)
        } else {
            feedbackFailure(automation.lastResult)
        }
    }

    private func toggleVoiceCapture(initiator: ControllerInput?) {
        guard !voiceStopPending else {
            lastAction = "Finishing the current dictation"
            return
        }
        if pushToTalkActive {
            setPushToTalk(false, handsFree: true)
        } else {
            setPushToTalk(
                true,
                handsFree: true,
                mode: .toggle(initiator)
            )
        }
    }

    private func setPushToTalk(
        _ active: Bool,
        handsFree: Bool = false,
        mode: VoiceCaptureMode? = nil
    ) {
        guard !voiceStopPending else { return }
        guard active != pushToTalkActive else { return }

        if active {
            // Game Controller will be gated while Bluetooth audio is flowing;
            // clear motion that would otherwise continue on an existing timer.
            pointer.stop()
            touchpad.cancel()
            let requestedTransport = controller.transport
            if requestedTransport == .usb, audio.controllerAudioAvailable {
                lastAction = "Preparing DualSense microphone"
                guard audio.ensureCodexMicrophone() else {
                    failNativeDictation(
                        audio.lastAudioResult,
                        transport: requestedTransport
                    )
                    return
                }
            } else if requestedTransport == .bluetooth {
                lastAction = "Preparing Bluetooth DualSense microphone"
                audio.removeCodexMicrophone()
                guard bluetoothMicrophone.startCapture() else {
                    failNativeDictation(
                        bluetoothMicrophone.lastResult,
                        transport: requestedTransport
                    )
                    return
                }
                guard controller.setBluetoothMicrophoneCapture(true) else {
                    bluetoothMicrophone.stopCapture()
                    failNativeDictation(
                        controller.lastBluetoothMicrophoneResult,
                        transport: requestedTransport
                    )
                    return
                }
            }
            guard automation.startDictation() else {
                failNativeDictation(
                    automation.lastResult,
                    transport: requestedTransport
                )
                return
            }

            voiceCaptureTransport = requestedTransport
            voiceCaptureMode = mode ?? .toggle(nil)
            pushToTalkActive = true
            updateState(.listening)
            if requestedTransport == .usb {
                controller.setMicrophoneLED(.off)
            }
            controller.playHaptic(.listeningStart)
            playFeedbackSound(.listeningStart)
            lastAction = "Codex is listening"
            hud.show(
                handsFree ? "Hands-free Codex dictation" : "Codex is listening",
                detail: requestedTransport == .bluetooth
                    ? "Using the wireless DualSense Microphone input"
                    : requestedTransport == .usb
                        ? "Using the selected DualSense Microphone input"
                        : "Using Codex's selected Mac microphone",
                color: CodexTaskState.listening.color
            )
        } else {
            let completedTransport =
                voiceCaptureTransport ?? controller.transport
            pushToTalkActive = false
            voiceCaptureMode = nil
            voiceCaptureTransport = nil
            controller.playHaptic(.listeningStop)
            playFeedbackSound(.listeningStop)
            if completedTransport == .bluetooth,
               controller.transport == .bluetooth,
               bluetoothMicrophone.isCapturing {
                beginBluetoothVoiceStop()
                return
            }
            guard automation.stopDictationAndInsert() else {
                failNativeDictation(
                    automation.lastResult,
                    transport: completedTransport
                )
                return
            }
            stopVoiceCaptureResources(for: completedTransport)
            showTranscribingState()
        }
    }

    private func beginBluetoothVoiceStop() {
        voiceStopGeneration += 1
        let generation = voiceStopGeneration
        voiceStopPending = true

        // Stop the HID uplink first, but leave the decoder and AVAudioSourceNode
        // alive long enough to render the 50 ms jitter buffer and final packet.
        _ = controller.setBluetoothMicrophoneCapture(false)
        lastAction = "Finishing Bluetooth dictation"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            [weak self] in
            guard let self,
                  self.voiceStopPending,
                  self.voiceStopGeneration == generation
            else {
                return
            }
            self.voiceStopPending = false
            let stopped = self.automation.stopDictationAndInsert()
            self.bluetoothMicrophone.stopCapture()
            guard stopped else {
                self.feedbackFailure(self.automation.lastResult)
                self.updateAggregateState()
                return
            }
            self.showTranscribingState()
        }
    }

    private func showTranscribingState() {
        updateState(.processingVoice)
        lastAction = "Codex is transcribing"
        hud.show(
            "Codex is transcribing",
            detail: "Using Codex's native transcription",
            color: .white
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            [weak self] in
            self?.updateAggregateState()
        }
    }

    private func completeSelfTest(
        generation: Int,
        result: String? = nil
    ) {
        guard selfTestRunning, selfTestGeneration == generation else {
            return
        }
        selfTestRunning = false
        lastAction = result ?? "Safe hardware self-test complete"
        hud.show(
            "Self-test complete",
            detail: result ?? "One haptic and one speaker tone completed",
            color: .systemGreen
        )
        updateAggregateState()
    }

    private func completeWirelessMicrophoneDiagnostic(generation: Int) {
        guard microphoneDiagnosticRunning,
              microphoneDiagnosticGeneration == generation
        else {
            return
        }
        let packets = bluetoothMicrophone.receivedPacketCount
        let frames = bluetoothMicrophone.decodedFrameCount
        let peak = bluetoothMicrophone.peakInputLevel
        bluetoothMicrophone.stopCapture()
        microphoneDiagnosticRunning = false

        if packets > 0, frames > 0 {
            let percent = Int((peak * 100).rounded())
            microphoneDiagnosticResult =
                "Passed · \(packets) packets · voice peak \(percent)%"
            lastAction =
                "Wireless mic passed: \(packets) packets, peak \(percent)%"
            hud.show(
                "Wireless microphone works",
                detail: "\(packets) packets decoded · peak \(percent)%",
                color: .systemGreen
            )
        } else {
            microphoneDiagnosticResult =
                "Failed · no usable Bluetooth audio was received"
            feedbackFailure(
                "No usable Bluetooth microphone audio was received"
            )
        }
    }

    private func failNativeDictation(
        _ message: String,
        transport: ControllerTransport? = nil
    ) {
        let failedTransport =
            transport ?? voiceCaptureTransport ?? controller.transport
        pushToTalkActive = false
        voiceCaptureMode = nil
        voiceCaptureTransport = nil
        stopVoiceCaptureResources(for: failedTransport)
        feedbackFailure(message)
        updateAggregateState()
    }

    private func controllerTransportChanged(_ transport: ControllerTransport) {
        if selfTestRunning {
            selfTestGeneration += 1
            selfTestRunning = false
            lastAction = "Hardware self-test cancelled after connection change"
        }
        if microphoneDiagnosticRunning, transport != .bluetooth {
            microphoneDiagnosticGeneration += 1
            microphoneDiagnosticRunning = false
            bluetoothMicrophone.stopCapture()
            lastAction = "Wireless microphone test cancelled after disconnect"
        }
        if pushToTalkActive,
           let capturedTransport = voiceCaptureTransport,
           capturedTransport != transport {
            cancelActiveVoiceCapture(
                capturedTransport: capturedTransport,
                reason: "Controller connection changed"
            )
        }

        switch transport {
        case .usb:
            bluetoothMicrophone.teardown()
            audio.refresh()
            if audio.controllerAudioAvailable {
                _ = audio.ensureCodexMicrophone()
            }
        case .bluetooth:
            audio.removeCodexMicrophone()
            if bluetoothMicrophone.prepare() {
                lastAction = "Wireless DualSense Microphone is ready"
            } else {
                lastAction = bluetoothMicrophone.lastResult
            }
        case .unknown:
            bluetoothMicrophone.teardown()
            audio.removeCodexMicrophone()
        }
        logger.notice(
            "Controller transport changed to \(transport.rawValue, privacy: .public)"
        )
    }

    private func isVoiceStopEvent(_ event: ControllerEvent) -> Bool {
        guard pushToTalkActive,
              case let .button(input, pressed) = event
        else {
            return false
        }
        if input == .microphone, pressed {
            return true
        }
        switch voiceCaptureMode {
        case let .pendingTapOrHold(initiator):
            return input == initiator && !pressed
        case let .hold(initiator):
            return input == initiator && !pressed
        case let .toggle(initiator):
            return input == initiator && pressed
        case nil:
            return false
        }
    }

    private func stopVoiceCaptureResources(
        for transport: ControllerTransport
    ) {
        switch transport {
        case .usb:
            if controller.transport == .usb {
                controller.setMicrophoneLED(.on)
            }
        case .bluetooth:
            if controller.transport == .bluetooth {
                _ = controller.setBluetoothMicrophoneCapture(false)
            }
            bluetoothMicrophone.stopCapture()
        case .unknown:
            break
        }
    }

    private func cancelActiveVoiceCapture(
        capturedTransport: ControllerTransport,
        reason: String
    ) {
        guard pushToTalkActive else { return }
        pushToTalkActive = false
        voiceCaptureMode = nil
        voiceCaptureTransport = nil
        stopVoiceCaptureResources(for: capturedTransport)
        let stopped = automation.stopDictationAndInsert()
        lastAction = stopped
            ? "\(reason); dictation stopped"
            : "\(reason); \(automation.lastResult)"
        updateAggregateState()
        logger.error(
            "Cancelled dictation after transport change from \(capturedTransport.rawValue, privacy: .public); automationStopped=\(stopped, privacy: .public)"
        )
    }

    private func shutdown() {
        voiceStopGeneration += 1
        selfTestGeneration += 1
        microphoneDiagnosticGeneration += 1
        selfTestRunning = false
        microphoneDiagnosticRunning = false
        if voiceStopPending {
            voiceStopPending = false
            _ = automation.stopDictationAndInsert()
            if controller.transport == .bluetooth {
                _ = controller.setBluetoothMicrophoneCapture(false)
            }
            bluetoothMicrophone.stopCapture()
        }
        if pushToTalkActive {
            cancelActiveVoiceCapture(
                capturedTransport:
                    voiceCaptureTransport ?? controller.transport,
                reason: "ControlDeck is closing"
            )
        }
        controller.stop()
        bluetoothMicrophone.teardown()
        audio.removeCodexMicrophone()
    }

    private func tasksChanged(_ tasks: [RecentCodexTask]) {
        let previous = lastStates
        recentTasks = tasks
        if !tasks.contains(where: { $0.id == selectedTaskID }) {
            selectedTaskID = tasks.first?.id
        }
        lastStates = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.state) })
        updateAggregateState()

        for task in tasks {
            guard let old = previous[task.id], old != task.state else { continue }
            switch task.state {
            case .complete:
                if statusHaptics {
                    controller.playHaptic(.success)
                }
                hud.show("Task complete", detail: task.shortTitle, color: task.state.color)
                playFeedbackSound(.complete)
            case .needsInput:
                if statusHaptics {
                    controller.playHaptic(.warning)
                }
                hud.show("Task needs input", detail: task.shortTitle, color: task.state.color)
                playFeedbackSound(.needsInput)
            case .error:
                if statusHaptics {
                    controller.playHaptic(.error)
                }
                hud.show("Task error", detail: task.shortTitle, color: task.state.color)
                playFeedbackSound(.error)
            default:
                break
            }
        }
    }

    private func updateAggregateState() {
        guard !pushToTalkActive, !voiceStopPending else { return }
        updateState(
            selectedTask?.state ??
                CodexTaskState.aggregate(recentTasks.map(\.state))
        )
    }

    private func updateState(_ state: CodexTaskState) {
        currentState = controller.isConnected ? state : .disconnected
        controller.setState(currentState)
    }

    private func feedbackFailure(_ message: String) {
        lastAction = message
        controller.playHaptic(.error)
        hud.show("Action unavailable", detail: message, color: .systemRed)
    }

    func previewSoundTheme() {
        playFeedbackSound(.complete)
    }

    private func playFeedbackSound(_ cue: FeedbackSoundCue) {
        let tones = soundTheme.tones(for: cue)
        guard !tones.isEmpty, controller.isConnected else { return }
        soundGeneration += 1
        playFeedbackTone(
            tones,
            index: 0,
            generation: soundGeneration
        )
    }

    private func playFeedbackTone(
        _ tones: [FeedbackTone],
        index: Int,
        generation: Int
    ) {
        guard generation == soundGeneration, tones.indices.contains(index)
        else {
            return
        }
        let tone = tones[index]
        let next = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + tone.pauseAfter
            ) {
                self.playFeedbackTone(
                    tones,
                    index: index + 1,
                    generation: generation
                )
            }
        }
        if controller.transport == .bluetooth {
            _ = controller.playBluetoothSpeakerTone(
                frequency: tone.frequency,
                duration: tone.duration,
                volume: tone.volume
            ) { _ in
                next()
            }
        } else if controller.transport == .usb {
            guard audio.playControllerTone(
                frequency: tone.frequency,
                duration: tone.duration,
                volume: tone.volume
            ) else {
                return
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + tone.duration
            ) {
                next()
            }
        }
    }
}

private enum VoiceCaptureMode: Equatable {
    case pendingTapOrHold(ControllerInput)
    case hold(ControllerInput)
    case toggle(ControllerInput?)
}
