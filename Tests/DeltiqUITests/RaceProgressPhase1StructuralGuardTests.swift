#if canImport(SwiftUI)
import XCTest

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Abschnitte 4/5/6): strukturelle Garantien per Quelltext-Pruefung statt
/// Verhaltens-Annahme - gleiches Prinzip wie `CardioFeasibilityChoiceTests.
/// swift:110` in diesem Repo. Prueft NUR die dedizierten, in diesem Plan neu
/// eingefuehrten Dateien - nicht geteilte Bestandsdateien
/// (`DashboardView.swift`, `ExerciseLog.swift`), die legitim anderen,
/// unverwandten Funktionen dienen und bei einem pauschalen Scan faelschlich
/// anschlagen wuerden.
final class RaceProgressPhase1StructuralGuardTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
    }

    private let phase1Files: [String] = [
        "Sources/DeltiqCore/Analytics/CardioVolumeOverTimePoint.swift",
        "Sources/DeltiqCore/Analytics/CardioVolumeOverTimeAggregator.swift",
        "Sources/DeltiqData/CardioHistoryExtractor.swift",
        "Sources/DeltiqCore/Analytics/RaceProgressAssessment.swift",
        "Sources/DeltiqData/RaceProgressDueCalculator.swift",
        "Sources/DeltiqUI/Cardio/RaceProgressCardModel.swift",
        "Sources/DeltiqUI/Cardio/RaceProgressDetailView.swift",
        "Sources/DeltiqCore/Analytics/HeartRateZoneCalculator.swift",
    ]

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Bugfix-Regression (CI-Fund auf echtem macOS-Runner): ein
    /// `source.contains(term)`-Check trifft auch auf eine erklaerende
    /// Doc-Kommentar-Zeile, die den verbotenen Begriff selbst nennt, um zu
    /// begruenden warum er NICHT verwendet wird - exakt der Fall, den
    /// `CoachAdjustmentInsertionUITests.withoutLineComments` in diesem Repo
    /// bereits kennt. Strippt `//`-Zeilenkommentare vor jedem Check.
    private func withoutLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                if let commentRange = line.range(of: "//") {
                    return line[line.startIndex..<commentRange.lowerBound]
                }
                return line
            }
            .joined(separator: "\n")
    }

    /// Abschnitt 5: Phase 1 hat schlicht keinen Schreibpfad auf
    /// `TrainingPlan`/`TrainingDay` - keine der neuen Dateien darf
    /// Plan-Mutationsfunktionen aufrufen oder neue Tage/Plaene anlegen.
    func testPhase1NeverImportsPlanMutationAPIs() throws {
        let forbidden = [
            "PlanGeneratorInstantiator",
            "applyCoachCardioAdjustment",
            "insertCoachCardioDays",
            "RunCoachPlanAdjustment",
            "TrainingDay(",
            "TrainingPlan(",
        ]
        for file in phase1Files {
            let source = withoutLineComments(try contents(of: file))
            for term in forbidden {
                XCTAssertFalse(
                    source.contains(term),
                    "\(file) darf '\(term)' nicht verwenden - Phase 1 hat keinen Schreibpfad auf den aktiven Plan"
                )
            }
        }
    }

    /// Abschnitt 6/Ticket-Testfall 14: Phase 1 ist komplett lokal - keine
    /// Netzwerk-Frameworks in irgendeiner neuen Datei.
    func testPhase1NeverImportsNetworkingFrameworks() throws {
        let forbidden = ["URLSession", "import Network", "URLRequest"]
        for file in phase1Files {
            let source = withoutLineComments(try contents(of: file))
            for term in forbidden {
                XCTAssertFalse(source.contains(term), "\(file) darf '\(term)' nicht verwenden - Phase 1 ist strikt lokal/offline")
            }
        }
    }

    /// Abschnitt 4: Schutz vor stale Werten - `UserBodyProfile.weeklyBaseVolumeKm`
    /// darf in der Bewertungslogik nirgends gelesen werden.
    func testNeverReadsStaleOnboardingWeeklyVolume() throws {
        let filesThatMustNotReadStaleVolume = [
            "Sources/DeltiqCore/Analytics/RaceProgressAssessment.swift",
            "Sources/DeltiqUI/Cardio/RaceProgressCardModel.swift",
        ]
        for file in filesThatMustNotReadStaleVolume {
            let source = withoutLineComments(try contents(of: file))
            // Bugfix-Regression (CI-Fund): die bare Kennung
            // "weeklyBaseVolumeKm" allein ist zu grob - `RaceProgressAssessment.
            // swift` reicht `input.currentWeeklyVolumeKm` legitim an
            // `CardioFeasibilityCalculator.evaluate(weeklyBaseVolumeKm:)`
            // weiter (ein FREMDER Funktions-Parametername, keine
            // `profile`-Eigenschaft). Nur ein PUNKT-praefixierter Zugriff
            // (".weeklyBaseVolumeKm", z.B. "profile.weeklyBaseVolumeKm")
            // beweist ein tatsaechliches Lesen der stale Onboarding-
            // Eigenschaft - ein Funktionsargument-Label (gefolgt von ":")
            // trifft das nicht.
            XCTAssertFalse(
                source.contains(".weeklyBaseVolumeKm"),
                "\(file) darf profile.weeklyBaseVolumeKm (stale Onboarding-Schnappschuss) nicht lesen - currentWeeklyVolumeKm muss frisch aus der echten Wochenserie stammen"
            )
        }
    }

    /// Running Coach - Herzfrequenz-Trainingszonen-Ticket: seit diesem
    /// Ticket liest `RaceProgressCardModel.swift` `profile.maxHeartRateBpm`
    /// LEGITIM, als manuelle HFmax-Quelle fuer `HeartRateZoneContextBuilder.
    /// make(maxHeartRateBpm:measuredAverageBpm:)` - dort bewusst
    /// ausgenommen. Alle anderen Phase-1-Dateien duerfen diesen rein
    /// deskriptiven Profilwert (DEL-250) weiterhin nicht lesen oder als
    /// Ersatz fuer gemessene Herzfrequenzdaten verwenden.
    func testNeverReadsProfileMaxHeartRateOutsideTheExplicitZoneWiring() throws {
        let allowedFile = "Sources/DeltiqUI/Cardio/RaceProgressCardModel.swift"
        for file in phase1Files where file != allowedFile {
            let source = withoutLineComments(try contents(of: file))
            XCTAssertFalse(
                source.contains("maxHeartRateBpm"),
                "\(file) darf maxHeartRateBpm (rein deskriptiver Profilwert) nicht lesen - Phase 1 hat keine gemessene HF-Datenquelle"
            )
        }
    }

    /// Die eine erlaubte Lesestelle darf den Wert NUR an den
    /// `maxHeartRateBpm:`-Parameter weiterreichen, niemals an
    /// `measuredAverageBpm:` - sonst wuerde die HFmax selbst als gemessener
    /// Trainingspuls durchgereicht.
    func testMaxHeartRateIsNeverPassedAsAMeasuredAverageBpm() throws {
        let source = withoutLineComments(try contents(of: "Sources/DeltiqUI/Cardio/RaceProgressCardModel.swift"))
        XCTAssertFalse(
            source.contains("measuredAverageBpm: profile.maxHeartRateBpm"),
            "profile.maxHeartRateBpm darf nie als measuredAverageBpm: durchgereicht werden"
        )
        XCTAssertTrue(
            source.contains("maxHeartRateBpm: profile.maxHeartRateBpm"),
            "die legitime Weitergabe an den maxHeartRateBpm:-Parameter muss weiterhin vorhanden sein"
        )
    }

    /// Abschnitt 6: keine KI-/externen Dienste in Phase 1.
    func testPhase1HasNoAIOrExternalServiceCode() throws {
        let forbidden = ["DeltiqAI", "import FoundationModels"]
        for file in phase1Files {
            let source = withoutLineComments(try contents(of: file))
            for term in forbidden {
                XCTAssertFalse(source.contains(term), "\(file) darf '\(term)' nicht verwenden - Phase 1 ist deterministisch, keine KI")
            }
        }
    }
}
#endif
