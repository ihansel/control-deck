import ApplicationServices
import AppKit
import Carbon.HIToolbox
import Foundation
import OSLog

/// Captures the application that owned keyboard focus when dictation began.
///
/// Some editors, notably Sublime Text, intentionally expose their editor as an
/// accessibility-opaque window rather than an AXTextArea. Requiring a named AX
/// text role therefore rejects a real, focused editor. ControlDeck keeps the
/// exact editable element when one is available and otherwise uses a protected
/// paste into the captured application, matching normal keyboard input.
@MainActor
final class SpeechTextInsertionTarget {
    private static let logger = Logger(
        subsystem: "com.ianhansel.controldeck",
        category: "speech-target"
    )
    private let application: NSRunningApplication
    private var element: AXUIElement?

    var targetApplication: NSRunningApplication {
        application
    }

    private init(
        application: NSRunningApplication,
        element: AXUIElement?
    ) {
        self.application = application
        self.element = element
    }

    static func capture() -> SpeechTextInsertionTarget? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let focused = focusedUIElement()
        let editable = focused.flatMap { candidate -> AXUIElement? in
            guard pid(of: candidate) == frontmost.processIdentifier,
                  isEditableTextInput(candidate)
            else { return nil }
            return candidate
        }
        let bundleIdentifier = frontmost.bundleIdentifier
        guard bundleIdentifier != "com.apple.games",
              bundleIdentifier != "com.apple.loginwindow",
              bundleIdentifier != Bundle.main.bundleIdentifier ||
                editable != nil
        else { return nil }
        let target = SpeechTextInsertionTarget(
            application: frontmost,
            element: editable
        )
        logger.notice(
            "Captured dictation target app=\(frontmost.localizedName ?? "Unknown", privacy: .public) directAccessibility=\(editable != nil, privacy: .public)"
        )
        return target
    }

    func insert(
        _ text: String
    ) -> AppleSpeechTranscriptionResult.InsertionMethod? {
        if let target = currentEditableElement(),
           replaceSelection(in: target, with: text) {
            return .accessibility
        }

        restoreApplicationFocus()
        guard paste(text) else { return nil }
        Self.logger.notice(
            "Inserted dictation with protected paste into \(self.application.localizedName ?? "the captured application", privacy: .public)"
        )
        return .pasteboard
    }

    func restoreApplicationFocus() {
        guard !application.isTerminated else { return }
        _ = application.activate(options: [.activateAllWindows])
        if let element {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            )
        }
    }

    private func currentEditableElement() -> AXUIElement? {
        if let focused = Self.focusedUIElement(),
           Self.pid(of: focused) == application.processIdentifier,
           Self.isEditableTextInput(focused) {
            element = focused
            return focused
        }
        guard let element,
              Self.pid(of: element) == application.processIdentifier,
              Self.isEditableTextInput(element)
        else { return nil }
        restoreApplicationFocus()
        return element
    }

    private static func isEditableTextInput(_ element: AXUIElement) -> Bool {
        var selectedTextSettable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextSettable
        ) == .success,
           selectedTextSettable.boolValue {
            return true
        }

        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        ) == .success,
        let role = roleValue as? String,
        [
            kAXTextAreaRole as String,
            kAXTextFieldRole as String,
            kAXComboBoxRole as String,
            "AXSearchField"
        ].contains(role)
        else { return false }

        var valueSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueSettable
        ) == .success && valueSettable.boolValue
    }

    private func replaceSelection(
        in element: AXUIElement,
        with text: String
    ) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        ) == .success,
        settable.boolValue
        else { return false }
        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        ) == .success
    }

    private func paste(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let snapshot = (pasteboard.pasteboardItems ?? []).map { source in
            let copy = NSPasteboardItem()
            for type in source.types {
                if let data = source.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string),
              postPaste()
        else {
            Self.restorePasteboard(pasteboard, snapshot: snapshot)
            return false
        }
        let changeCount = pasteboard.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if pasteboard.changeCount == changeCount {
                Self.restorePasteboard(pasteboard, snapshot: snapshot)
            }
        }
        return true
    }

    private func postPaste() -> Bool {
        guard let down = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        ),
        let up = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        )
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private static func focusedUIElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success
        else { return nil }
        return value as! AXUIElement?
    }

    private static func pid(of element: AXUIElement) -> pid_t {
        var value: pid_t = 0
        AXUIElementGetPid(element, &value)
        return value
    }

    private static func restorePasteboard(
        _ pasteboard: NSPasteboard,
        snapshot: [NSPasteboardItem]
    ) {
        pasteboard.clearContents()
        if !snapshot.isEmpty {
            pasteboard.writeObjects(snapshot)
        }
    }
}
