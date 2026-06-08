// swift-tools-version: 5.9

import Foundation
import PackageDescription

let optionalLocalExcludes = [
    ".codex",
    "Pasted Graphic.png",
    "codex_prompt_macos_lan_scanner.md",
    "roadmap_macos_lan_scanner.md"
].filter { FileManager.default.fileExists(atPath: $0) }

let package = Package(
    name: "LanScopeMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LanScopeMac", targets: ["LanScopeMac"])
    ],
    targets: [
        .executableTarget(
            name: "LanScopeMac",
            path: ".",
            exclude: [
                "docs",
                "dist",
                "script",
                "Tests",
                "CONTRIBUTING.md",
                "CHANGELOG.md",
                "INSTALL.md",
                "LICENSE",
                "README.md",
                "ROADMAP.md",
                "PRIVACY.md",
                "SECURITY.md"
            ] + optionalLocalExcludes,
            sources: [
                "App",
                "Features",
                "Core",
                "Models",
                "Persistence",
                "Utilities"
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation")
            ]
        ),
        .testTarget(
            name: "LanScopeMacTests",
            dependencies: ["LanScopeMac"],
            path: "Tests/LanScopeMacTests"
        )
    ]
)
