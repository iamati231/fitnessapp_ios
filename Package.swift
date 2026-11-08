// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Deltiq",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "DeltiqCore",       targets: ["DeltiqCore"]),
        .library(name: "DeltiqData",       targets: ["DeltiqData"]),
        .library(name: "DeltiqHealth",     targets: ["DeltiqHealth"]),
        .library(name: "DeltiqActivities", targets: ["DeltiqActivities"]),
        .library(name: "DeltiqUI",         targets: ["DeltiqUI"]),
        .library(name: "DeltiqAI",         targets: ["DeltiqAI"]),
        .library(name: "DeltiqFoodLookup", targets: ["DeltiqFoodLookup"])
    ],
    // DEL-173: ZIPFoundation für on-device ZIP-Erstellung beim CSV-Export.
    // Pure-Swift, MIT-Lizenz, weit verbreitet — wird nur von DeltiqData
    // referenziert (kein UI-Layer-Bloat). Version-Range hält uns auf 0.9.x
    // (aktuell stabile Linie), 1.0 kann später als bewusster Bump folgen.
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "DeltiqCore",
            path: "Sources/DeltiqCore",
            resources: [.process("Resources")]
        ),
        .target(
            name: "DeltiqData",
            dependencies: [
                "DeltiqCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/DeltiqData"
        ),
        .target(
            // Haengt von Core ab wegen Double.rounded(toDecimals:) (Fix
            // "70,050003"-Bug: WeightReading rundet Health-Gewichtswerte an
            // der Quelle statt den Fehler bis zur UI durchzureichen).
            name: "DeltiqHealth",
            dependencies: ["DeltiqCore"],
            path: "Sources/DeltiqHealth"
        ),
        .target(
            // Haengt von Core ab, weil die Live Activity der Zeitformate
            // `TimedLiveContent` (reine Logik, auf Linux testbar) als Inhalt traegt.
            name: "DeltiqActivities",
            dependencies: ["DeltiqCore"],
            path: "Sources/DeltiqActivities"
        ),
        .target(
            name: "DeltiqUI",
            dependencies: ["DeltiqCore", "DeltiqData",
                           "DeltiqHealth", "DeltiqActivities",
                           // Task E: AddMealView calls NutritionAIService/MealTextExtractor
                           // directly. Still a one-way dependency — DeltiqAI itself
                           // depends on nothing, so a broken AI layer can't break Core/Data.
                           "DeltiqAI",
                           // Task 4: AddMealView's online food search talks to
                           // OnlineFoodSearching/OpenFoodFactsSearchClient directly.
                           "DeltiqFoodLookup"],
            path: "Sources/DeltiqUI",
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
        .target(
            // Optional on-device AI (Foundation Models, iOS/macOS 26+). No
            // dependencies on purpose: Core/Data/manual entry must never need it.
            // FoundationModels is imported only here, behind canImport/#available.
            name: "DeltiqAI",
            path: "Sources/DeltiqAI"
        ),
        .target(
            // Only network-capable module in the app (Open Food Facts search).
            // Depends on Core only, never on DeltiqAI and vice versa — a
            // reviewer should be able to tell from the module graph alone that
            // exactly this target makes network calls.
            name: "DeltiqFoodLookup",
            dependencies: ["DeltiqCore"],
            path: "Sources/DeltiqFoodLookup"
        ),
        .testTarget(
            name: "DeltiqAITests",
            dependencies: ["DeltiqAI"],
            path: "Tests/DeltiqAITests"
        ),
        .testTarget(
            name: "DeltiqCoreTests",
            dependencies: ["DeltiqCore"],
            path: "Tests/DeltiqCoreTests"
        ),
        .testTarget(
            // Zustandslogik der Health-Berechtigungen (plattformneutrale Typen). Der
            // HealthKit-Teil selbst laesst sich nur auf dem Geraet pruefen.
            name: "DeltiqHealthTests",
            dependencies: ["DeltiqHealth"],
            path: "Tests/DeltiqHealthTests"
        ),
        .testTarget(
            // Integration tests for SwiftData-backed sync logic (PersonalRecordSync etc).
            // All test bodies are #if canImport(SwiftData)-gated so the file compiles
            // empty on Windows where SwiftData isn't available; on Codemagic-Mac the
            // tests actually run against an in-memory ModelContainer.
            name: "DeltiqDataTests",
            dependencies: ["DeltiqData", "DeltiqCore"],
            path: "Tests/DeltiqDataTests"
        ),
        .testTarget(
            // Bundle-Resource-Checks fuer DeltiqUI (z.B. Uebungs-GIFs
            // tatsaechlich ueber Bundle.module erreichbar) — auf Windows/Linux
            // compiliert das SwiftUI-abhaengige DeltiqUI leer, diese Tests
            // beruehren nur Foundation und laufen echt auf Codemagic-Mac.
            name: "DeltiqUITests",
            dependencies: ["DeltiqUI", "DeltiqCore", "DeltiqData", "DeltiqAI", "DeltiqFoodLookup"],
            path: "Tests/DeltiqUITests"
        ),
        .testTarget(
            // Pure URLSession+Foundation, no SwiftData/UIKit — runs locally on
            // Windows too, unlike most of the other test targets here.
            name: "DeltiqFoodLookupTests",
            dependencies: ["DeltiqFoodLookup"],
            path: "Tests/DeltiqFoodLookupTests"
        ),
        .executableTarget(
            // WP1 step-1: creates the coaching-era SQLite stub — only the
            // UserBodyProfile entity with 15 coaching-era properties.
            // DeltiqCore-only so this target compiles on Windows (SwiftData
            // unavailable) as a no-op.
            // Run before CoachingEraFixtureEnricher in CI.
            name: "CoachingEraFixtureGenerator",
            dependencies: ["DeltiqCore"],
            path: "Sources/CoachingEraFixtureGenerator"
        ),
        .executableTarget(
            // WP1 step-2: enriches the stub produced by CoachingEraFixtureGenerator
            // with representative records for all 17 SwiftData entities (all current
            // DeltiqData entities except UserBodyProfile stay on the current schema;
            // only the local UserBodyProfile shadow keeps the historic coaching columns).
            // Depends on DeltiqData (and therefore ZIPFoundation); SwiftData-dependent
            // code is #if canImport(SwiftData)-gated — Windows compilation falls through
            // to the no-op else branch without running any enrichment.
            // Run after CoachingEraFixtureGenerator in CI before swift test.
            name: "CoachingEraFixtureEnricher",
            dependencies: ["DeltiqData", "DeltiqCore"],
            path: "Sources/CoachingEraFixtureEnricher"
        )
    ]
)
