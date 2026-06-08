// swift-tools-version: 5.9

import PackageDescription

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
                ".codex",
                "dist",
                "script",
                "Tests",
                "CONTRIBUTING.md",
                "INSTALL.md",
                "LICENSE",
                "README.md",
                "ROADMAP.md",
                "PRIVACY.md",
                "SECURITY.md",
                "Pasted Graphic.png",
                "codex_prompt_macos_lan_scanner.md",
                "roadmap_macos_lan_scanner.md"
            ],
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
            ]
        ),
        .testTarget(
            name: "LanScopeMacTests",
            dependencies: ["LanScopeMac"],
            path: "Tests/LanScopeMacTests"
        )
    ]
)
