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
    targets: [
        .target(
            name: "FitnessAppCore",
            path: "Sources/FitnessAppCore"
        ),
        .target(
            name: "FitnessAppData",
            dependencies: ["FitnessAppCore"],
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
        )
    ]
)
