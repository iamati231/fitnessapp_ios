import XCTest

/// Regression guard: the 5 exercise localization keys that were missing from
/// Localizable.xcstrings must all be present. Without them the UI shows raw key
/// strings (e.g. "exercise.name.bodyweightSquat") instead of translated names.
final class ExerciseLocalizationKeysPresenceTests: XCTestCase {

    private var xcstringsContent: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // DeltiqUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    func testMissingLocalizationKeysAreNowPresent() throws {
        let content = try xcstringsContent
        let requiredKeys = [
            "exercise.name.bodyweightSquat",
            "exercise.name.pikePushup",
            "exercise.name.bodyweightHipThrust",
            "exercise.name.lyingLegRaise",
            "exercise.name.nordicCurls"
        ]
        for key in requiredKeys {
            XCTAssertTrue(content.contains("\"\(key)\""),
                "Localizable.xcstrings is missing key: \(key)")
        }
    }

    func testLocalizationKeysHaveDeEnTrEntries() throws {
        let content = try xcstringsContent
        let requiredKeys = [
            ("exercise.name.bodyweightSquat", "Kniebeuge (BW)", "Bodyweight Squat"),
            ("exercise.name.pikePushup", "Pike Liegestütze", "Pike Push-up"),
            ("exercise.name.bodyweightHipThrust", "Hip Thrust (BW)", "Bodyweight Hip Thrust"),
            ("exercise.name.lyingLegRaise", "Beinheben (liegend)", "Lying Leg Raise"),
            ("exercise.name.nordicCurls", "Nordic Curls", "Nordic Curls")
        ]
        for (key, deValue, enValue) in requiredKeys {
            XCTAssertTrue(content.contains("\"\(key)\""),
                "xcstrings missing key: \(key)")
            XCTAssertTrue(content.contains(deValue),
                "xcstrings missing DE value '\(deValue)' for \(key)")
            XCTAssertTrue(content.contains(enValue),
                "xcstrings missing EN value '\(enValue)' for \(key)")
        }
    }
}
