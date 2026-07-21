import AppKit

@MainActor
final class HUDController {
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func show(_ message: String, detail: String? = nil, color: NSColor) {
        hideWorkItem?.cancel()

        let panel = panel ?? makePanel()
        self.panel = panel
        guard let content = panel.contentView,
              let title = content.viewWithTag(100) as? NSTextField,
              let subtitle = content.viewWithTag(101) as? NSTextField,
              let dot = content.subviews.first(where: {
                  $0.identifier == NSUserInterfaceItemIdentifier("state-dot")
              })
        else { return }

        title.stringValue = message
        subtitle.stringValue = detail ?? ""
        subtitle.isHidden = detail?.isEmpty != false
        dot.layer?.backgroundColor = color.cgColor
        position(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self, weak panel] in
            guard let self, let panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
            self.hideWorkItem = nil
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45, execute: workItem)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.hasShadow = true

        let effect = NSVisualEffectView(frame: panel.contentView!.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true

        let dot = NSView(frame: NSRect(x: 20, y: 29, width: 20, height: 20))
        dot.identifier = NSUserInterfaceItemIdentifier("state-dot")
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 10
        effect.addSubview(dot)

        let title = NSTextField(labelWithString: "")
        title.tag = 100
        title.frame = NSRect(x: 54, y: 38, width: 254, height: 22)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor
        effect.addSubview(title)

        let subtitle = NSTextField(labelWithString: "")
        subtitle.tag = 101
        subtitle.frame = NSRect(x: 54, y: 17, width: 254, height: 18)
        subtitle.font = .systemFont(ofSize: 11.5, weight: .medium)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        effect.addSubview(subtitle)

        panel.contentView = effect
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: visible.maxX - panel.frame.width - 22,
                y: visible.maxY - panel.frame.height - 22
            )
        )
    }
}
