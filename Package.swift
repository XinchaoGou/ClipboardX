// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardX",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClipboardX",
            path: "Sources/ClipboardX",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
