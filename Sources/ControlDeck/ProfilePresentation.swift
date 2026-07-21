import AppKit
import SwiftUI

@MainActor
enum ProfileIconResolver {
    private static var cache: [ProfileKind: NSImage] = [:]
    private static var attempted: Set<ProfileKind> = []

    static func icon(for profile: ControllerProfile) -> NSImage? {
        if let cached = cache[profile.kind] { return cached }
        guard !attempted.contains(profile.kind) else { return nil }
        attempted.insert(profile.kind)

        for bundleIdentifier in profile.bundleIdentifiers
        where !bundleIdentifier.contains("*") {
            guard let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
            ) else { continue }
            let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
            cache[profile.kind] = icon
            return icon
        }
        return nil
    }
}

struct ProfileLogoView: View {
    let profile: ControllerProfile
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let icon = ProfileIconResolver.icon(for: profile) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: profile.kind.systemImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(.primary)
                    .background(
                        Color.white.opacity(0.9),
                        in: RoundedRectangle(
                            cornerRadius: size * 0.23,
                            style: .continuous
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
