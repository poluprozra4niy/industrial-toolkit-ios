// swift-tools-version: 6.0
import PackageDescription

// Builds only the UI-free calculation core, so formulas and parsers can be tested
// with `swift test` on Windows/Linux. The iOS app itself is generated from project.yml on a Mac.
let package = Package(
    name: "IndustrialToolkitCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(
            name: "IndustrialToolkit",
            path: "IndustrialToolkit",
            sources: [
                "Core/Utils/NumberParser.swift",
                "Core/Utils/Formatting.swift",
                "Features/Signals/SignalScale.swift",
                "Features/IEEE754/Float32Word.swift",
            ]
        ),
        .testTarget(
            name: "IndustrialToolkitTests",
            dependencies: ["IndustrialToolkit"],
            path: "IndustrialToolkitTests"
        ),
    ]
)
