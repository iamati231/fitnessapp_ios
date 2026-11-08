import XCTest
@testable import DeltiqCore

/// Verifies that a CSV export from the coaching era (before the rollback on
/// branch claude/great-dewdney-af8974) can be parsed without errors and that
/// non-coaching user data survives.
///
/// Background: The rollback removed 16 coaching properties from UserBodyProfile
/// and 2 enum cases from DashboardWidgetType. This test operates at the CSV-
/// parsing layer (no SwiftData required) and covers:
///
/// 1. A coaching-era profile.csv with extra coaching columns is parsed cleanly.
/// 2. Essential non-coaching fields (birth_date, height_cm, etc.) are readable.
/// 3. Coaching columns that the import no longer requests are simply ignored.
/// 4. dashboard_widgets entries for removed widget types are silently filtered
///    by the DashboardWidgetType(rawValue:) compactMap — no crash, no corrupt state.
///
/// Limitation: actual on-disk SwiftData schema migration (opening an old .sqlite
/// written when coaching properties existed) cannot be tested on Windows because
/// SwiftData requires an iOS Simulator or macOS runtime. The safety guarantee at
/// the SwiftData level rests on all 16 removed properties being lightweight-
/// migration-compatible (all were optional or had a primitive default value).
final class CoachingRollbackCSVCompatibilityTests: XCTestCase {

    // MARK: - Coaching-era profile CSV fixture

    /// A profile.csv header as it would have appeared in an export made while
    /// the AI coaching feature was live.  The coaching columns are:
    ///   cardio_coaching_enabled, cardio_goal, cardio_race_date,
    ///   current_5k_reference_seconds, weekly_base_volume_km, max_heart_rate_bpm,
    ///   cardio_feasibility_dismissed_fingerprint
    private static let coachingEraProfileCSV = """
    id,birth_date,height_cm,profile,goal_weight_kg,environment,first_name,coaching_tone,training_goal,equipment_preferences,dashboard_widgets,hero_metric_slots,weekly_workout_goal,experience_track,cardio_coaching_enabled,cardio_goal,cardio_race_date,current_5k_reference_seconds,weekly_base_volume_km,max_heart_rate_bpm,cardio_feasibility_dismissed_fingerprint
    1,1990-01-15,178.0,male,80.0,gym,Max,analytical,hybrid,,nextWorkout|runCoachCard|cardioPace|raceProgressCard|coachingInsight,weight|bodyFat,3,intermediate,true,race,2027-04-30T00:00:00Z,1800,25.0,185,
    """

    func testCoachingEraCSVParsesWithoutError() throws {
        let reader = try CSVReader(Self.coachingEraProfileCSV)
        // Header must parse; CSVReader throws on malformed CSV.
        let rows = reader.rows()
        XCTAssertEqual(rows.count, 1)
    }

    func testEssentialProfileFieldsSurviveCoachingEraCSV() throws {
        let reader = try CSVReader(Self.coachingEraProfileCSV)
        guard let row = reader.rows().first else {
            XCTFail("profile row fehlt")
            return
        }
        // Non-coaching fields that must survive an import of this CSV.
        XCTAssertEqual(row["profile"], "male")
        XCTAssertEqual(row.double("height_cm"), 178.0)
        XCTAssertEqual(row.double("goal_weight_kg"), 80.0)
        XCTAssertEqual(row["environment"], "gym")
        XCTAssertEqual(row.optionalString("first_name"), "Max")
        XCTAssertEqual(row.optionalString("coaching_tone"), "analytical")
        XCTAssertEqual(row.optionalString("training_goal"), "hybrid")
        XCTAssertEqual(row.int("weekly_workout_goal"), 3)
        XCTAssertEqual(row.optionalString("experience_track"), "intermediate")
        XCTAssertNotNil(row.date("birth_date"), "birth_date muss parsebar sein")
    }

    func testCoachingColumnsArePresentButSilentlyIgnoredByImportLogic() throws {
        let reader = try CSVReader(Self.coachingEraProfileCSV)
        guard let row = reader.rows().first else {
            XCTFail("profile row fehlt")
            return
        }
        // The import code (DataImportService.importProfile) simply never reads
        // these keys — they are silently ignored.  Confirm they parse to their
        // expected values so a future reader can verify the fixture is realistic.
        XCTAssertEqual(row.bool("cardio_coaching_enabled"), true)
        XCTAssertEqual(row.optionalString("cardio_goal"), "race")
        XCTAssertEqual(row.int("current_5k_reference_seconds"), 1800)
        XCTAssertEqual(row.double("weekly_base_volume_km"), 25.0)
        XCTAssertEqual(row.int("max_heart_rate_bpm"), 185)
        // Not-present key (cardio_feasibility_dismissed_fingerprint is empty):
        XCTAssertNil(row.optionalString("cardio_feasibility_dismissed_fingerprint"))
    }

    // MARK: - DashboardWidgetType filtering

    /// A coaching-era dashboard_widgets value includes runCoachCard and
    /// raceProgressCard.  After the rollback these enum cases no longer exist.
    /// The typed accessor uses compactMap — unknown raw values are silently
    /// dropped instead of crashing.
    func testRemovedDashboardWidgetTypesAreFilteredFromRawValue() throws {
        let reader = try CSVReader(Self.coachingEraProfileCSV)
        guard let row = reader.rows().first else {
            XCTFail("profile row fehlt")
            return
        }
        // Simulate what DataImportService does: split the multi-value column.
        let rawWidgets = row["dashboard_widgets"].split(separator: "|").map(String.init)
        XCTAssertTrue(rawWidgets.contains("runCoachCard"),
                      "Fixture muss runCoachCard enthalten")
        XCTAssertTrue(rawWidgets.contains("raceProgressCard"),
                      "Fixture muss raceProgressCard enthalten")

        let typed = rawWidgets.compactMap { DashboardWidgetType(rawValue: $0) }
        XCTAssertFalse(typed.map(\.rawValue).contains("runCoachCard"),
                       "runCoachCard darf nicht im typisierten Array auftauchen")
        XCTAssertFalse(typed.map(\.rawValue).contains("raceProgressCard"),
                       "raceProgressCard darf nicht im typisierten Array auftauchen")
        // Known widgets must still be present.
        XCTAssertTrue(typed.contains(.nextWorkout))
        XCTAssertTrue(typed.contains(.cardioPace))
        XCTAssertTrue(typed.contains(.coachingInsight))
    }

    /// Verifies that GenerationSource.cardioCoach (intentionally kept after rollback
    /// — it identifies plans created by the now-removed coach) still exists and
    /// round-trips through its rawValue.
    func testGenerationSourceCardioCoachEnumCaseIsPreserved() {
        let source = GenerationSource.cardioCoach
        XCTAssertEqual(GenerationSource(rawValue: source.rawValue), .cardioCoach)
    }
}
