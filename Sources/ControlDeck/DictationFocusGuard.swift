import AppKit
import Foundation
import OSLog

/// Keeps macOS controller system gestures from stealing the dictation target.
///
/// DualSense Bluetooth microphone packets share the controller input report
/// channel. On affected macOS versions a packet can be misread by the system as
/// the Home/PS gesture and launch Games even though ControlDeck disabled every
/// GameController system gesture. The input service still suppresses corrupted
/// app events; this guard also restores the application that owned text focus.
@MainActor
final class DictationFocusGuard {
    private let blockedBundleIdentifiers = Set(["com.apple.games"])
    private let logger = Logger(
        subsystem: "com.ianhansel.controldeck",
        category: "dictation-focus"
    )
    private var targetApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    func begin(targetApplication: NSRunningApplication?) {
        end()
        guard let targetApplication else { return }
        self.targetApplication = targetApplication
        activationObserver =
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.applicationActivated(notification)
                }
            }
    }

    func end() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                activationObserver
            )
        }
        activationObserver = nil
        targetApplication = nil
    }

    private func applicationActivated(_ notification: Notification) {
        guard let activated = notification.userInfo?[
            NSWorkspace.applicationUserInfoKey
        ] as? NSRunningApplication,
        let bundleIdentifier = activated.bundleIdentifier,
        blockedBundleIdentifiers.contains(bundleIdentifier),
        let targetApplication,
        !targetApplication.isTerminated,
        targetApplication.bundleIdentifier != bundleIdentifier
        else { return }

        _ = activated.hide()
        _ = targetApplication.activate(options: [.activateAllWindows])
        logger.error(
            "Blocked a spurious macOS Games activation during dictation and restored \(targetApplication.localizedName ?? "the text application", privacy: .public)"
        )
    }
}
