// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Emmaus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Emmaus",
            path: "Sources/Emmaus",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
