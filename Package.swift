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
            // Haengt von Core ab wegen Double.rounded(toDecimals:) (Fix
            // "70,050003"-Bug: WeightReading rundet Health-Gewichtswerte an
            // der Quelle statt den Fehler bis zur UI durchzureichen).
            name: "FitnessAppHealth",
            dependencies: ["FitnessAppCore"],
            path: "Sources/FitnessAppHealth"
        ),
        .target(
            // Haengt von Core ab, weil die Live Activity der Zeitformate
            // `TimedLiveContent` (reine Logik, auf Linux testbar) als Inhalt traegt.
            name: "FitnessAppActivities",
            dependencies: ["FitnessAppCore"],
            path: "Sources/FitnessAppActivities"
        ),
        .target(
            name: "FitnessAppUI",
            dependencies: ["FitnessAppCore", "FitnessAppData",
                           "FitnessAppHealth", "FitnessAppActivities"],
            path: "Sources/FitnessAppUI",
            // ExerciseGifs liegt bewusst NICHT unter Resources/: `.process()`
            // flacht verschachtelte Ordner ab (alle Dateien landen direkt im
            // Bundle-Root, ohne Unterordner) — `Bundle.module.url(…,
            // subdirectory: "ExerciseGifs")` liefe damit ins Leere. `.copy()`
            // auf einem eigenen, nicht ueberlappenden Pfad behaelt die
            // Ordnerstruktur im Bundle bei. SPM verbietet zudem ueberlappende
            // Resource-Regeln fuer denselben Pfad (`.process("Resources")`
            // + `.copy("Resources/ExerciseGifs")` schlaegt mit "duplicate
            // resource rule" fehl), daher der eigene Top-Level-Ordner statt
            // eines Unterordners von Resources/.
            resources: [
                .process("Resources"),
                .copy("ExerciseGifs")
            ]
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
        ),
        .testTarget(
            // Bundle-Resource-Checks fuer FitnessAppUI (z.B. Uebungs-GIFs
            // tatsaechlich ueber Bundle.module erreichbar) — auf Windows/Linux
            // compiliert das SwiftUI-abhaengige FitnessAppUI leer, diese Tests
            // beruehren nur Foundation und laufen echt auf Codemagic-Mac.
            name: "FitnessAppUITests",
            dependencies: ["FitnessAppUI", "FitnessAppCore"],
            path: "Tests/FitnessAppUITests"
        )
    ]
)
