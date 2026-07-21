import AppKit
import SwiftUI

struct ControllerOverlayTask {
    let title: String
    let state: CodexTaskState
}

struct ControllerOverlayItem: Identifiable {
    let input: ControllerInput
    let title: String
    let detail: String
    let systemImage: String

    var id: String { input.rawValue }
}

@MainActor
final class ControllerOverlayController {
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func showRadial(
        profile: ControllerProfile,
        task: ControllerOverlayTask?,
        slots: [CodexSkillSlot],
        selectedInput: ControllerInput? = nil
    ) {
        hideWorkItem?.cancel()
        let items = radialItems(slots: slots)
        let view = RadialControllerOverlay(
            profileName: profile.name,
            task: task,
            items: items,
            selectedInput: selectedInput
        )
        show(
            AnyView(view),
            size: NSSize(width: 680, height: 680)
        )
    }

    func showReasoning(
        profile: ControllerProfile,
        task: ControllerOverlayTask?,
        step: ReasoningStep? = nil
    ) {
        hideWorkItem?.cancel()
        let view = ReasoningControllerOverlay(
            profileName: profile.name,
            task: task,
            step: step
        )
        show(
            AnyView(view),
            size: NSSize(width: 460, height: 250)
        )
    }

    func showContext(
        profile: ControllerProfile,
        task: ControllerOverlayTask?,
        slots: [CodexSkillSlot]
    ) {
        hideWorkItem?.cancel()
        let view = ContextControllerOverlay(
            profile: profile,
            task: task,
            slots: slots
        )
        show(
            AnyView(view),
            size: NSSize(width: 590, height: 470)
        )
        scheduleHide(after: 4)
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func radialItems(
        slots: [CodexSkillSlot]
    ) -> [ControllerOverlayItem] {
        let skillItems: [ControllerOverlayItem] =
            SkillDirection.allCases.compactMap { direction in
            guard let slot = slots.first(where: {
                $0.direction == direction
            }) else {
                return nil
            }
            return ControllerOverlayItem(
                input: direction.input,
                title: slot.title,
                detail: "Custom skill",
                systemImage: "sparkles"
            )
        }
        let faceItems = ShiftFaceCommand.allCases.map { command in
            ControllerOverlayItem(
                input: command.input,
                title: command.title,
                detail: "Codex",
                systemImage: systemImage(for: command)
            )
        }
        return skillItems + faceItems
    }

    private func systemImage(for command: ShiftFaceCommand) -> String {
        switch command {
        case .approve: "checkmark"
        case .decline: "xmark"
        case .send: "paperplane.fill"
        case .fastMode: "bolt.fill"
        }
    }

    private func show(_ view: AnyView, size: NSSize) {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.setContentSize(size)
        panel.contentView = NSHostingView(rootView: view)
        position(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 1
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 680),
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
        panel.ignoresMouseEvents = true
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouse, $0.frame, false)
        }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - panel.frame.width / 2,
                y: visible.midY - panel.frame.height / 2
            )
        )
    }

    private func scheduleHide(after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

private struct OverlaySurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 32, y: 16)
            .padding(26)
    }
}

private struct RadialControllerOverlay: View {
    let profileName: String
    let task: ControllerOverlayTask?
    let items: [ControllerOverlayItem]
    let selectedInput: ControllerInput?

    var body: some View {
        OverlaySurface {
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.12))
                        .frame(width: 410, height: 410)
                    Circle()
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                        .frame(width: 410, height: 410)

                    center

                    ForEach(Array(items.enumerated()), id: \.element.id) {
                        index, item in
                        let angle = angle(for: item.input)
                        let radius = min(proxy.size.width, proxy.size.height) *
                            0.36
                        itemView(item)
                            .offset(
                                x: cos(angle) * radius,
                                y: sin(angle) * radius
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var center: some View {
        VStack(spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 27, weight: .semibold))
            Text("OPTIONS")
                .font(.caption2.weight(.bold))
                .tracking(1.5)
            Text(profileName)
                .font(.headline)
            if let task {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(nsColor: task.state.color))
                        .frame(width: 7, height: 7)
                    Text(task.title)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 180)
            }
        }
        .frame(width: 210, height: 145)
        .background(.regularMaterial, in: Circle())
    }

    private func itemView(_ item: ControllerOverlayItem) -> some View {
        let selected = selectedInput == item.input
        return VStack(spacing: 5) {
            HStack(spacing: 7) {
                Text(item.input.shortLabel)
                    .font(.caption.weight(.bold))
                    .frame(minWidth: 24)
                Image(systemName: item.systemImage)
                    .font(.caption.weight(.semibold))
            }
            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(selected ? .black : .primary)
        .padding(.horizontal, 12)
        .frame(width: 132, height: 64)
        .background(
            selected ? Color.accentColor : Color.white.opacity(0.88),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    selected ? .white.opacity(0.8) : .white.opacity(0.35),
                    lineWidth: selected ? 2 : 1
                )
        }
        .scaleEffect(selected ? 1.08 : 1)
        .animation(.easeOut(duration: 0.1), value: selected)
    }

    private func angle(for input: ControllerInput) -> Double {
        switch input {
        case .dpadUp: -.pi / 2
        case .triangle: -.pi / 4
        case .dpadRight: 0
        case .circle: .pi / 4
        case .dpadDown: .pi / 2
        case .cross: .pi * 3 / 4
        case .dpadLeft: .pi
        case .square: .pi * 5 / 4
        default: 0
        }
    }
}

private struct ReasoningControllerOverlay: View {
    let profileName: String
    let task: ControllerOverlayTask?
    let step: ReasoningStep?

    var body: some View {
        OverlaySurface {
            VStack(spacing: 15) {
                HStack {
                    Label("Reasoning effort", systemImage: "dial.medium")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("CREATE + R STICK")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
                    choice("Faster", icon: "chevron.down", active: step == .faster)
                    choice("Smarter", icon: "chevron.up", active: step == .smarter)
                }
                HStack {
                    Text(profileName)
                    Spacer()
                    if let task {
                        Text(task.title).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func choice(
        _ title: String,
        icon: String,
        active: Bool
    ) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                active ? Color.accentColor : Color.white.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .foregroundStyle(active ? .black : .primary)
    }
}

private struct ContextControllerOverlay: View {
    let profile: ControllerProfile
    let task: ControllerOverlayTask?
    let slots: [CodexSkillSlot]

    var body: some View {
        OverlaySurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 13) {
                    Image(systemName: profile.kind.systemImage)
                        .font(.system(size: 23, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(
                            Color.accentColor.opacity(0.16),
                            in: RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.title3.weight(.semibold))
                        Text("Current controller profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let task {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(task.title).lineLimit(1)
                            Label(
                                task.state.label,
                                systemImage: "circle.fill"
                            )
                            .foregroundStyle(Color(nsColor: task.state.color))
                        }
                        .font(.caption)
                        .frame(maxWidth: 190, alignment: .trailing)
                    }
                }

                Divider()
                Text("PRIMARY CONTROLS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 8
                ) {
                    mapping(.cross)
                    mapping(.circle)
                    mapping(.l1)
                    mapping(.r1)
                    mapping(.l2)
                    mapping(.r2)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Hold Options")
                            .font(.headline)
                        Text("Four custom skills + Approve, Decline, Send and Fast mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(slots) { slot in
                            Text(slot.direction.arrow)
                                .font(.caption.weight(.bold))
                                .frame(width: 28, height: 28)
                                .background(
                                    .white.opacity(0.6),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                    }
                }
                Text("Hold Create + move the right stick to adjust reasoning")
                    .font(.caption.weight(.medium))
            }
        }
    }

    private func mapping(_ input: ControllerInput) -> some View {
        HStack(spacing: 9) {
            Text(input.shortLabel)
                .font(.caption.weight(.bold))
                .frame(width: 36, height: 28)
                .background(
                    .white.opacity(0.68),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            Text(profile.action(for: input).label)
                .font(.caption)
                .lineLimit(1)
            Spacer()
        }
    }
}
