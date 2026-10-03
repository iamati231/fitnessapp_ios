// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitnessApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "FitnessAppCore",       targets: ["FitnessAppCore"]),
        .library(name: "FitnessAppData",       targets: ["FitnessAppData"]),
        .library(name: "FitnessAppHealth",     targets: ["FitnessAppHealth"]),
        .library(name: "FitnessAppActivities", targets: ["FitnessAppActivities"]),
        .library(name: "FitnessAppUI",         targets: ["FitnessAppUI"])
    ],
    // DEL-173: ZIPFoundation für on-device ZIP-Erstellung beim CSV-Export.
    // Pure-Swift, MIT-Lizenz, weit verbreitet — wird nur von FitnessAppData
    // referenziert (kein UI-Layer-Bloat). Version-Range hält uns auf 0.9.x
    // (aktuell stabile Linie), 1.0 kann später als bewusster Bump folgen.
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "FitnessAppCore",
            path: "Sources/FitnessAppCore"
        ),
        .target(
            name: "FitnessAppData",
            dependencies: [
                "FitnessAppCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/FitnessAppData"
        ),
        .target(
            name: "FitnessAppHealth",
            path: "Sources/FitnessAppHealth"
        ),
        .target(
            name: "FitnessAppActivities",
            path: "Sources/FitnessAppActivities"
        ),
        .target(
            name: "FitnessAppUI",
            dependencies: ["FitnessAppCore", "FitnessAppData",
                           "FitnessAppHealth", "FitnessAppActivities"],
            path: "Sources/FitnessAppUI",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FitnessAppCoreTests",
            dependencies: ["FitnessAppCore"],
            path: "Tests/FitnessAppCoreTests"
        ),
        .testTarget(
            // Zustandslogik der Health-Berechtigungen (plattformneutrale Typen). Der
            // HealthKit-Teil selbst laesst sich nur auf dem Geraet pruefen.
            name: "FitnessAppHealthTests",
            dependencies: ["FitnessAppHealth"],
            path: "Tests/FitnessAppHealthTests"
        ),
        .testTarget(
            // Integration tests for SwiftData-backed sync logic (PersonalRecordSync etc).
            // All test bodies are #if canImport(SwiftData)-gated so the file compiles
            // empty on Windows where SwiftData isn't available; on Codemagic-Mac the
            // tests actually run against an in-memory ModelContainer.
            name: "FitnessAppDataTests",
            dependencies: ["FitnessAppData", "FitnessAppCore"],
            path: "Tests/FitnessAppDataTests"
        )
    ]
)
