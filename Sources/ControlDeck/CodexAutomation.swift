import ApplicationServices
import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class CodexAutomation: ObservableObject {
    @Published private(set) var accessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var lastResult = "Ready"

    private let codexBundleIdentifier = "com.openai.codex"
    private var dictationShortcutHeld = false
    private var meetingPushToTalkHeld = false

    private enum MeetingCommand {
        case mute, video, chat, participants, share, raiseHand
    }

    private enum PresentationCommand {
        case start
    }

    func refreshAccessibility() {
        accessibilityTrusted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        if !accessibilityTrusted {
            lastResult = "Accessibility permission is required for controller actions"
        }
    }

    @discardableResult
    func run(_ action: ControllerAction) -> Bool {
        switch action {
        case .sendMessage:
            return key(kVK_Return)
        case .interrupt:
            return key(kVK_Escape)
        case .toggleReview:
            return key(kVK_ANSI_B, flags: [.maskCommand, .maskAlternate])
        case .togglePlan:
            return command(named: "Plan mode")
        case .newTask:
            return key(kVK_ANSI_N, flags: .maskCommand)
        case .commandMenu:
            return key(kVK_ANSI_P, flags: [.maskCommand, .maskShift])
        case .focusCodex:
            return activate()
        case .previousTask:
            return key(kVK_ANSI_LeftBracket, flags: [.maskCommand, .maskShift])
        case .nextTask:
            return key(kVK_ANSI_RightBracket, flags: [.maskCommand, .maskShift])
        case .back:
            return key(kVK_ANSI_LeftBracket, flags: .maskCommand)
        case .forward:
            return key(kVK_ANSI_RightBracket, flags: .maskCommand)
        case .toggleSidebar:
            return key(kVK_ANSI_B, flags: .maskCommand)
        case .quickChat:
            return key(kVK_ANSI_N, flags: [.maskCommand, .maskAlternate])
        case .toggleTerminal:
            return key(kVK_ANSI_Grave, flags: .maskControl)
        case .approve:
            return performSemanticButton(
                exact: ["Approve", "Allow", "Run", "Accept"],
                prefixes: ["Approve ", "Allow ", "Run ", "Accept "]
            )
        case .decline:
            return performSemanticButton(
                exact: ["Decline", "Deny", "Reject"],
                prefixes: ["Decline ", "Deny ", "Reject "]
            )
        case .continueInNewTask:
            return command(named: "Continue in new chat")
        case .toggleFastMode:
            return command(named: "Fast mode")
        case .reasoning:
            return command(named: "Reasoning effort")
        }
    }

    @discardableResult
    func run(_ action: MappedAction) -> Bool {
        switch action {
        case .none:
            lastResult = "No action assigned"
            return true
        case .codexSend: return run(.sendMessage)
        case .codexStop: return run(.interrupt)
        case .codexReview: return run(.toggleReview)
        case .codexPlan: return run(.togglePlan)
        case .codexNewTask: return run(.newTask)
        case .codexCommandMenu: return run(.commandMenu)
        case .codexFocus: return run(.focusCodex)
        case .codexPreviousTask: return run(.previousTask)
        case .codexNextTask: return run(.nextTask)
        case .codexBack: return run(ControllerAction.back)
        case .codexForward: return run(ControllerAction.forward)
        case .codexSidebar: return run(.toggleSidebar)
        case .codexQuickChat: return run(.quickChat)
        case .codexTerminal: return run(.toggleTerminal)
        case .codexApprove: return run(.approve)
        case .codexDecline: return run(.decline)
        case .codexDictation: return toggleDictation()
        case .codexFastMode: return run(.toggleFastMode)
        case .codexContinueInNewTask: return run(.continueInNewTask)

        case .claudeNewChat:
            return key(kVK_ANSI_N, flags: .maskCommand, focusCodex: false)
        case .claudeSidebar:
            return semanticInFrontmostApp(
                exact: ["Open sidebar", "Close sidebar", "Toggle sidebar"]
            )
        case .claudeCode:
            return semanticInFrontmostApp(exact: ["Code"])
        case .claudeProjects:
            return semanticInFrontmostApp(exact: ["Projects"])

        case .meetingMute: return meetingShortcut(.mute)
        case .meetingPushToTalk:
            lastResult = "Hold L2 for push to talk"
            return true
        case .meetingVideo: return meetingShortcut(.video)
        case .meetingChat: return meetingShortcut(.chat)
        case .meetingParticipants: return meetingShortcut(.participants)
        case .meetingShare: return meetingShortcut(.share)
        case .meetingRaiseHand: return meetingShortcut(.raiseHand)

        case .presentationStart: return presentationShortcut(.start)
        case .presentationNext:
            return key(kVK_RightArrow, focusCodex: false)
        case .presentationPrevious:
            return key(kVK_LeftArrow, focusCodex: false)
        case .presentationBlackScreen:
            return key(kVK_ANSI_B, focusCodex: false)
        case .presentationPointer:
            return key(kVK_ANSI_C, focusCodex: false)
        case .presentationNotesUp:
            return key(kVK_ANSI_U, focusCodex: false)
        case .presentationNotesDown:
            return key(kVK_ANSI_D, focusCodex: false)
        case .presentationExit:
            return key(kVK_Escape, focusCodex: false)

        case .slackJumpConversation:
            return key(kVK_ANSI_K, flags: .maskCommand, focusCodex: false)
        case .slackPreviousUnread:
            return key(kVK_UpArrow, flags: [.maskAlternate, .maskShift], focusCodex: false)
        case .slackNextUnread:
            return key(kVK_DownArrow, flags: [.maskAlternate, .maskShift], focusCodex: false)
        case .slackThreads:
            return key(kVK_ANSI_T, flags: [.maskCommand, .maskShift], focusCodex: false)
        case .slackActivity:
            return key(kVK_ANSI_M, flags: [.maskCommand, .maskShift], focusCodex: false)
        case .slackHuddle:
            return key(kVK_ANSI_H, flags: [.maskCommand, .maskShift], focusCodex: false)

        case .mailArchive:
            return key(kVK_ANSI_A, flags: [.maskControl, .maskCommand], focusCodex: false)
        case .mailReply:
            return key(kVK_ANSI_R, flags: .maskCommand, focusCodex: false)
        case .mailUnread:
            return key(kVK_ANSI_U, flags: [.maskCommand, .maskShift], focusCodex: false)

        case .photosFavorite:
            return key(kVK_ANSI_Period, focusCodex: false)
        case .photosEdit:
            return key(kVK_Return, focusCodex: false)
        case .photosRotate:
            return key(kVK_ANSI_R, flags: .maskCommand, focusCodex: false)
        case .photosInfo:
            return key(kVK_ANSI_I, flags: .maskCommand, focusCodex: false)

        case .timelinePlayPause:
            return key(kVK_Space, focusCodex: false)
        case .timelineReverse:
            return key(kVK_ANSI_J, focusCodex: false)
        case .timelinePause:
            return key(kVK_ANSI_K, focusCodex: false)
        case .timelineForward:
            return key(kVK_ANSI_L, focusCodex: false)
        case .timelineMarkIn:
            return key(kVK_ANSI_I, focusCodex: false)
        case .timelineMarkOut:
            return key(kVK_ANSI_O, focusCodex: false)
        case .timelinePreviousEdit:
            return key(kVK_UpArrow, focusCodex: false)
        case .timelineNextEdit:
            return key(kVK_DownArrow, focusCodex: false)
        case .timelineRecord:
            return key(kVK_ANSI_R, focusCodex: false)
        case .timelineRewind:
            return key(kVK_ANSI_Comma, focusCodex: false)
        case .timelineFastForward:
            return key(kVK_ANSI_Period, focusCodex: false)

        case .figmaComment:
            return key(kVK_ANSI_C, focusCodex: false)
        case .figmaFrame:
            return key(kVK_ANSI_F, focusCodex: false)
        case .figmaHand:
            return key(kVK_ANSI_H, focusCodex: false)
        case .figmaDevMode:
            return key(kVK_ANSI_D, flags: .maskShift, focusCodex: false)

        case .terminalNewTab:
            return key(kVK_ANSI_T, flags: .maskCommand, focusCodex: false)
        case .terminalCloseTab:
            return key(kVK_ANSI_W, flags: .maskCommand, focusCodex: false)
        case .terminalNextTab:
            return key(kVK_Tab, flags: .maskControl, focusCodex: false)
        case .terminalPreviousTab:
            return key(kVK_Tab, flags: [.maskControl, .maskShift], focusCodex: false)
        case .terminalClear:
            return key(kVK_ANSI_L, flags: .maskCommand, focusCodex: false)
        case .terminalInterrupt:
            return key(kVK_ANSI_Period, flags: .maskCommand, focusCodex: false)
        case .terminalSearchHistory:
            return key(kVK_ANSI_R, flags: .maskControl, focusCodex: false)
        case .terminalSplitPane:
            return key(kVK_ANSI_D, flags: .maskCommand, focusCodex: false)
        case .terminalClosePane:
            return key(kVK_ANSI_D, flags: [.maskCommand, .maskShift], focusCodex: false)

        case .mouseLeftClick, .mouseRightClick, .mouseMiddleClick,
             .screenshotSelection:
            lastResult = "Mouse action"
            return true
        case .back:
            return key(
                kVK_ANSI_LeftBracket,
                flags: .maskCommand,
                focusCodex: false
            )
        case .forward:
            return key(
                kVK_ANSI_RightBracket,
                flags: .maskCommand,
                focusCodex: false
            )
        case .missionControl:
            return key(
                kVK_UpArrow,
                flags: .maskControl,
                focusCodex: false
            )
        case .showDesktop:
            return key(kVK_F11, focusCodex: false)
        case .appSwitcher:
            return key(kVK_Tab, flags: .maskCommand, focusCodex: false)
        case .returnKey:
            return key(kVK_Return, focusCodex: false)
        case .escapeKey:
            return key(kVK_Escape, focusCodex: false)
        case .spaceKey:
            return key(kVK_Space, focusCodex: false)
        case .tabKey:
            return key(kVK_Tab, focusCodex: false)
        case .copy:
            return key(kVK_ANSI_C, flags: .maskCommand, focusCodex: false)
        case .paste:
            return key(kVK_ANSI_V, flags: .maskCommand, focusCodex: false)
        case .cut:
            return key(kVK_ANSI_X, flags: .maskCommand, focusCodex: false)
        case .selectAll:
            return key(kVK_ANSI_A, flags: .maskCommand, focusCodex: false)
        case .undo:
            return key(kVK_ANSI_Z, flags: .maskCommand, focusCodex: false)
        case .redo:
            return key(kVK_ANSI_Z, flags: [.maskCommand, .maskShift], focusCodex: false)
        case .zoomIn:
            return key(kVK_ANSI_Equal, flags: .maskCommand, focusCodex: false)
        case .zoomOut:
            return key(kVK_ANSI_Minus, flags: .maskCommand, focusCodex: false)
        case .arrowUp:
            return key(kVK_UpArrow, focusCodex: false)
        case .arrowDown:
            return key(kVK_DownArrow, focusCodex: false)
        case .arrowLeft:
            return key(kVK_LeftArrow, focusCodex: false)
        case .arrowRight:
            return key(kVK_RightArrow, focusCodex: false)
        case .browserAddress:
            return key(kVK_ANSI_L, flags: .maskCommand, focusCodex: false)
        case .browserNewTab:
            return key(kVK_ANSI_T, flags: .maskCommand, focusCodex: false)
        case .browserCloseTab:
            return key(kVK_ANSI_W, flags: .maskCommand, focusCodex: false)
        case .browserReopenTab:
            return key(
                kVK_ANSI_T,
                flags: [.maskCommand, .maskShift],
                focusCodex: false
            )
        case .browserReload:
            return key(kVK_ANSI_R, flags: .maskCommand, focusCodex: false)
        case .browserFind:
            return key(kVK_ANSI_F, flags: .maskCommand, focusCodex: false)
        case .browserNextTab:
            return key(
                kVK_RightArrow,
                flags: [.maskCommand, .maskAlternate],
                focusCodex: false
            )
        case .browserPreviousTab:
            return key(
                kVK_LeftArrow,
                flags: [.maskCommand, .maskAlternate],
                focusCodex: false
            )
        case .mediaPlayPause:
            return mediaKey(16)
        case .mediaNext:
            return mediaKey(17)
        case .mediaPrevious:
            return mediaKey(18)
        case .volumeUp:
            return mediaKey(0)
        case .volumeDown:
            return mediaKey(1)
        case .volumeMute:
            return mediaKey(7)
        case .openCodex:
            return activate()
        case .openChrome:
            return activate(
                bundleIdentifier: "com.google.Chrome",
                fallbackPath: "/Applications/Google Chrome.app"
            )
        case .openSpotify:
            return activate(
                bundleIdentifier: "com.spotify.client",
                fallbackPath: "/Applications/Spotify.app"
            )
        case .openClaude:
            return activate(
                bundleIdentifier: "com.anthropic.claudefordesktop",
                fallbackPath: "/Applications/Claude.app"
            )
        case .systemDictation:
            return systemDictation()
        case .showControllerOverlay:
            lastResult = "Controller overlay"
            return true
        case .deleteTextWithConfirmation:
            return confirmDeleteFocusedText()
        }
    }

    @discardableResult
    func confirmDeleteFocusedText() -> Bool {
        guard accessibilityTrusted || AXIsProcessTrusted() else {
            requestAccessibility()
            return false
        }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focused = focusedValue as! AXUIElement?
        else {
            lastResult = "Focus a text field before shaking"
            return false
        }

        let role = stringAttribute(focused, kAXRoleAttribute)
        let textRoles = [kAXTextAreaRole, kAXTextFieldRole, kAXComboBoxRole]
        guard let role, textRoles.contains(role) else {
            lastResult = "Shake to delete only works in a focused text field"
            return false
        }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            focused,
            kAXValueAttribute as CFString,
            &settable
        ) == .success,
        settable.boolValue
        else {
            lastResult = "This text field does not allow safe clearing"
            return false
        }
        var value: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            &value
        )
        guard let text = value as? String, !text.isEmpty else {
            lastResult = "The focused text field is already empty"
            return false
        }

        var processIdentifier: pid_t = 0
        AXUIElementGetPid(focused, &processIdentifier)
        let app = NSRunningApplication(processIdentifier: processIdentifier)
        let appName = app?.localizedName ?? "the current app"

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete all text?"
        alert.informativeText =
            "This will clear the focused text field in \(appName). " +
            "The action cannot be undone by ControlDeck."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else {
            _ = app?.activate(options: [.activateAllWindows])
            lastResult = "Delete cancelled"
            return false
        }
        let result = AXUIElementSetAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            "" as CFString
        )
        _ = app?.activate(options: [.activateAllWindows])
        lastResult = result == .success
            ? "Text deleted"
            : "The text field changed before it could be cleared"
        return result == .success
    }

    @discardableResult
    func runPrompt(_ prompt: String) -> Bool {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            lastResult = "This skill slot has no prompt"
            return false
        }
        guard key(kVK_ANSI_N, flags: .maskCommand) else { return false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            [weak self] in
            self?.type(prompt)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                _ = self?.key(kVK_Return)
            }
        }
        lastResult = "Started custom skill"
        return true
    }

    @discardableResult
    func beginReasoningAdjustment(
        completion: @escaping @MainActor () -> Void
    ) -> Bool {
        guard command(named: "Reasoning effort") else { return false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            completion()
        }
        return true
    }

    @discardableResult
    func adjustReasoning(_ step: ReasoningStep) -> Bool {
        key(
            step == .smarter ? kVK_RightArrow : kVK_LeftArrow,
            focusCodex: false
        )
    }

    func finishReasoningAdjustment() {
        _ = key(kVK_Return, focusCodex: false)
    }

    @discardableResult
    func setMeetingPushToTalk(_ active: Bool) -> Bool {
        guard active != meetingPushToTalkHeld else { return true }
        let bundleID = frontmostBundleIdentifier
        let succeeded: Bool
        if bundleID == "us.zoom.xos" {
            succeeded = postKeyState(
                kVK_Space,
                keyDown: active
            )
        } else if bundleID == "com.microsoft.teams2" ||
                    bundleID == "com.microsoft.teams" {
            succeeded = postKeyState(
                kVK_Space,
                flags: .maskAlternate,
                keyDown: active
            )
        } else {
            // Google Meet supports Space as native push to talk when enabled.
            succeeded = postKeyState(kVK_Space, keyDown: active)
        }
        if succeeded {
            meetingPushToTalkHeld = active
            lastResult = active ? "Meeting microphone open" : "Meeting microphone muted"
        }
        return succeeded
    }

    @discardableResult
    func toggleDictation() -> Bool {
        dictationShortcutHeld
            ? stopDictationAndInsert()
            : startDictation()
    }

    @discardableResult
    func startDictation() -> Bool {
        guard activate() else { return false }
        guard postDictationShortcut(.start) else { return false }
        dictationShortcutHeld = true
        return true
    }

    @discardableResult
    func stopDictationAndInsert() -> Bool {
        guard activate() else { return false }
        guard postDictationShortcut(.stopAndInsert) else { return false }
        dictationShortcutHeld = false
        return true
    }

    func openThread(_ id: String) -> Bool {
        guard let url = URL(string: "codex://threads/\(id)") else {
            lastResult = "Invalid task identifier"
            return false
        }
        let result = NSWorkspace.shared.open(url)
        lastResult = result ? "Opened task" : "Could not open task"
        return result
    }

    @discardableResult
    func openSettings() -> Bool {
        guard let url = URL(string: "codex://settings") else {
            lastResult = "Could not create the Codex settings link"
            return false
        }
        let result = NSWorkspace.shared.open(url)
        lastResult = result
            ? "Opened Codex settings"
            : "Could not open Codex settings"
        return result
    }

    private func activate() -> Bool {
        activate(
            bundleIdentifier: codexBundleIdentifier,
            fallbackPath: "/Applications/ChatGPT.app"
        )
    }

    private func activate(
        bundleIdentifier: String,
        fallbackPath: String
    ) -> Bool {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first else {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: fallbackPath),
                configuration: NSWorkspace.OpenConfiguration()
            )
            lastResult = "Launching application"
            return true
        }
        let result = app.activate(options: [.activateAllWindows])
        lastResult = result ? "Application focused" : "Could not focus application"
        return result
    }

    private func key(
        _ code: Int,
        flags: CGEventFlags = [],
        focusCodex: Bool = true
    ) -> Bool {
        guard accessibilityTrusted || AXIsProcessTrusted() else {
            requestAccessibility()
            return false
        }
        if focusCodex {
            _ = activate()
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: false)
        else {
            lastResult = "Unable to create keyboard event"
            return false
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        lastResult = "Sent shortcut"
        return true
    }

    private func systemDictation() -> Bool {
        guard key(kVK_Function, focusCodex: false) else { return false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            _ = self?.key(kVK_Function, focusCodex: false)
        }
        lastResult = "System dictation"
        return true
    }

    private var frontmostBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func meetingShortcut(_ command: MeetingCommand) -> Bool {
        let bundleID = frontmostBundleIdentifier
        if bundleID == "us.zoom.xos" {
            let code: Int
            let flags: CGEventFlags
            switch command {
            case .mute: (code, flags) = (kVK_ANSI_A, [.maskCommand, .maskShift])
            case .video: (code, flags) = (kVK_ANSI_V, [.maskCommand, .maskShift])
            case .chat: (code, flags) = (kVK_ANSI_H, [.maskCommand, .maskShift])
            case .participants: (code, flags) = (kVK_ANSI_U, .maskCommand)
            case .share: (code, flags) = (kVK_ANSI_S, [.maskCommand, .maskShift])
            case .raiseHand: (code, flags) = (kVK_ANSI_Y, .maskAlternate)
            }
            return key(code, flags: flags, focusCodex: false)
        }
        if bundleID == "com.microsoft.teams2" ||
            bundleID == "com.microsoft.teams" {
            switch command {
            case .mute:
                return key(kVK_ANSI_M, flags: [.maskCommand, .maskShift], focusCodex: false)
            case .video:
                return key(kVK_ANSI_O, flags: [.maskCommand, .maskShift], focusCodex: false)
            case .share:
                return key(kVK_ANSI_E, flags: [.maskCommand, .maskShift], focusCodex: false)
            case .raiseHand:
                return key(kVK_ANSI_K, flags: [.maskControl, .maskShift], focusCodex: false)
            case .chat:
                return semanticInFrontmostApp(exact: ["Chat", "Show conversation"])
            case .participants:
                return semanticInFrontmostApp(exact: ["People", "Participants", "Show participants"])
            }
        }

        // Browser-hosted Google Meet uses its documented macOS shortcuts.
        switch command {
        case .mute:
            return key(kVK_ANSI_D, flags: .maskCommand, focusCodex: false)
        case .video:
            return key(kVK_ANSI_E, flags: .maskCommand, focusCodex: false)
        case .chat:
            return key(kVK_ANSI_C, flags: [.maskControl, .maskCommand], focusCodex: false)
        case .participants:
            return key(kVK_ANSI_P, flags: [.maskControl, .maskCommand], focusCodex: false)
        case .share:
            return key(kVK_ANSI_T, flags: [.maskControl, .maskCommand], focusCodex: false)
        case .raiseHand:
            return key(kVK_ANSI_H, flags: [.maskControl, .maskCommand], focusCodex: false)
        }
    }

    private func presentationShortcut(_ command: PresentationCommand) -> Bool {
        switch command {
        case .start:
            if frontmostBundleIdentifier == "com.apple.iWork.Keynote" {
                return key(kVK_ANSI_P, flags: [.maskAlternate, .maskCommand], focusCodex: false)
            }
            if frontmostBundleIdentifier == "com.microsoft.Powerpoint" {
                return key(kVK_Return, flags: [.maskCommand, .maskShift], focusCodex: false)
            }
            return key(kVK_Return, flags: [.maskCommand, .maskShift], focusCodex: false)
        }
    }

    private func semanticInFrontmostApp(exact: [String]) -> Bool {
        guard let bundleID = frontmostBundleIdentifier else {
            lastResult = "No foreground application"
            return false
        }
        return performSemanticButton(
            bundleIdentifier: bundleID,
            exact: exact,
            prefixes: exact.map { "\($0) " }
        )
    }

    private func postKeyState(
        _ code: Int,
        flags: CGEventFlags = [],
        keyDown: Bool
    ) -> Bool {
        guard accessibilityTrusted || AXIsProcessTrusted() else {
            requestAccessibility()
            return false
        }
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(code),
            keyDown: keyDown
        ) else {
            lastResult = "Unable to create keyboard event"
            return false
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
        return true
    }

    private func mediaKey(_ key: Int32) -> Bool {
        guard accessibilityTrusted || AXIsProcessTrusted() else {
            requestAccessibility()
            return false
        }
        let keyDownFlags = NSEvent.ModifierFlags(rawValue: 0xA00)
        let keyUpFlags = NSEvent.ModifierFlags(rawValue: 0xB00)
        let keyDownData = Int((key << 16) | (0xA << 8))
        let keyUpData = Int((key << 16) | (0xB << 8))

        let down = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: keyDownFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: keyDownData,
            data2: -1
        )
        let up = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: keyUpFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: keyUpData,
            data2: -1
        )
        down?.cgEvent?.post(tap: .cghidEventTap)
        up?.cgEvent?.post(tap: .cghidEventTap)
        lastResult = "Sent media key"
        return down != nil && up != nil
    }

    private func command(named query: String) -> Bool {
        guard key(kVK_ANSI_P, flags: [.maskCommand, .maskShift]) else { return false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.type(query)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                _ = self?.key(kVK_Return)
            }
        }
        lastResult = query
        return true
    }

    private func type(_ text: String) {
        let utf16 = Array(text.utf16)
        for start in stride(from: 0, to: utf16.count, by: 20) {
            let end = min(start + 20, utf16.count)
            let chunk = Array(utf16[start..<end])
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            else { continue }
            chunk.withUnsafeBufferPointer {
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: $0.baseAddress!)
                up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: $0.baseAddress!)
            }
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func performSemanticButton(
        bundleIdentifier: String? = nil,
        exact: [String],
        prefixes: [String]
    ) -> Bool {
        guard accessibilityTrusted || AXIsProcessTrusted() else {
            requestAccessibility()
            return false
        }
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier ?? codexBundleIdentifier
        ).first else {
            lastResult = "Application is not running"
            return false
        }

        let root = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            root,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        ) == .success,
        let focusedWindow = focusedWindowValue as! AXUIElement?,
        let match = findButton(
            in: focusedWindow,
            exact: exact,
            prefixes: prefixes,
            depth: 0
        ) {
            let result = AXUIElementPerformAction(
                match,
                kAXPressAction as CFString
            )
            lastResult =
                result == .success ? exact[0] : "Could not press \(exact[0])"
            return result == .success
        }

        if let match = findButton(in: root, exact: exact, prefixes: prefixes, depth: 0) {
            let result = AXUIElementPerformAction(match, kAXPressAction as CFString)
            lastResult = result == .success ? exact[0] : "Could not press \(exact[0])"
            return result == .success
        }

        lastResult = "No \(exact[0].lowercased()) request is visible"
        return false
    }

    private func postDictationShortcut(
        _ intent: CodexDictationIntent
    ) -> Bool {
        guard accessibilityTrusted || AXIsProcessTrusted() else {
            requestAccessibility()
            return false
        }
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_ANSI_D),
            keyDown: intent.keyDown
        ) else {
            lastResult = "Unable to create the Codex dictation event"
            return false
        }
        event.flags = [.maskControl, .maskShift]
        event.post(tap: .cghidEventTap)
        lastResult = intent.successMessage
        return true
    }

    private func findButton(
        in element: AXUIElement,
        exact: [String],
        prefixes: [String],
        depth: Int
    ) -> AXUIElement? {
        guard depth < 24 else { return nil }

        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String

        if role == kAXButtonRole {
            let candidates = [
                stringAttribute(element, kAXTitleAttribute),
                stringAttribute(element, kAXDescriptionAttribute),
                stringAttribute(element, kAXHelpAttribute),
                stringAttribute(element, "AXIdentifier")
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

            if candidates.contains(where: { value in
                exact.contains(where: { value.caseInsensitiveCompare($0) == .orderedSame }) ||
                    prefixes.contains(where: { value.lowercased().hasPrefix($0.lowercased()) })
            }) {
                return element
            }
        }

        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenValue
        ) == .success,
        let children = childrenValue as? [AXUIElement]
        else { return nil }

        for child in children {
            if let result = findButton(in: child, exact: exact, prefixes: prefixes, depth: depth + 1) {
                return result
            }
        }
        return nil
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
