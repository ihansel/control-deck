// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ControlDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "control-deck", targets: ["ControlDeck"])
    ],
    targets: [
        .systemLibrary(
            name: "COpus",
            path: "Sources/COpus",
            pkgConfig: "opus",
            providers: [
                .brew(["opus"])
            ]
        ),
        .executableTarget(
            name: "ControlDeck",
            dependencies: ["COpus"],
            path: "Sources/ControlDeck",
            resources: [
                .process("Resources")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
